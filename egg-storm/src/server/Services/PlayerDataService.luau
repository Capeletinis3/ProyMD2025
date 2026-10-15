--!strict
-- PlayerDataService: los datos de cada jugador (plata, mascotas, mejoras, huevos incubando)
-- y su guardado con DataStore.
--
-- Cuándo se guarda:
--   - al salir del juego
--   - cada Config.Data.AutosaveInterval segundos (autoguardado)
--   - cuando el servidor se apaga (game:BindToClose)
-- Cada lectura/escritura usa pcall y se reintenta varias veces si Roblox falla.
--
-- MUY IMPORTANTE: si no pudimos LEER los datos de alguien, nunca le guardamos encima
-- (si no, un error de Roblox le borraría el progreso). En el juego publicado lo sacamos para que reintente;
-- en Studio lo dejamos jugar sin guardar (ver "Enable Studio Access to API Services" en el README).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Creatures = require(ReplicatedStorage.Shared.Creatures)

export type CreatureData = {
	CreatureId: string,
	Slot: number, -- en qué pad de mascotas está
}

export type IncubatingData = {
	Slot: number, -- en qué incubadora
	RarityId: string,
	Remaining: number, -- segundos que le faltaban al salir (el tiempo no corre mientras no estás)
}

export type Profile = {
	Coins: number,
	IncubationSpeedLevel: number,
	IncubatorCount: number,
	WalkSpeedLevel: number,
	BaseLevel: number, -- 2 = tiene el segundo piso ("Base Floor")
	Creatures: { CreatureData },
	Incubating: { IncubatingData }, -- se llena al salir (mientras jugás, los huevos viven en IncubatorService)
}

local DATA_VERSION = 1 -- si algún día cambia la forma de los datos, sirve para convertir los viejos

local PlayerDataService = {}

local profiles: { [Player]: Profile } = {}
local canSave: { [Player]: boolean } = {} -- false si no pudimos leer sus datos (nunca le guardamos encima)
local savingUsers: { [number]: boolean } = {} -- para que dos guardados del mismo jugador no se pisen
local pendingSaves = 0
local incubatingProvider: ((Player) -> { IncubatingData })? = nil

local store: DataStore? = nil

local function getStore(): DataStore
	if not store then
		store = DataStoreService:GetDataStore(Config.Data.StoreName)
	end
	return store :: DataStore
end

local function keyFor(userId: number): string
	return `Player_{userId}`
end

local function newProfile(): Profile
	return {
		Coins = Config.Economy.StartingCoins,
		IncubationSpeedLevel = 1,
		IncubatorCount = Config.Upgrades.StartingIncubators,
		WalkSpeedLevel = 1,
		BaseLevel = 1,
		Creatures = {},
		Incubating = {},
	}
end

-- Ejecuta fn con pcall y la reintenta si falla (esperando un poco más cada vez).
local function withRetries(label: string, fn: () -> any, maxAttempts: number?): (boolean, any)
	local attempts = maxAttempts or Config.Data.MaxAttempts
	local lastError: any = nil
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		warn(`[PlayerData] {label} failed (attempt {attempt}/{attempts}): {result}`)
		if attempt < attempts then
			task.wait(Config.Data.RetryDelay * attempt)
		end
	end
	return false, lastError
end

-- ===== Revisar lo que viene del DataStore =====
-- Los datos guardados podrían estar incompletos o rotos: nos quedamos solo con valores válidos.

local function cleanNumber(value: any, default: number, min: number, max: number): number
	if typeof(value) ~= "number" or value ~= value then -- value ~= value detecta NaN
		return default
	end
	return math.clamp(math.floor(value), min, max)
end

-- Un número de lugar (pad o incubadora) válido: entero entre 1 y max. Si no, nil (se descarta, no se "acomoda").
local function validSlot(value: any, max: number): number?
	if typeof(value) ~= "number" or value ~= math.floor(value) or value < 1 or value > max then
		return nil
	end
	return value
end

local function profileFromData(data: any): Profile
	local profile = newProfile()
	if typeof(data) ~= "table" then
		return profile
	end
	local up = Config.Upgrades
	profile.Coins = cleanNumber(data.Coins, profile.Coins, 0, 1e15)
	profile.IncubationSpeedLevel = cleanNumber(data.IncubationSpeedLevel, 1, 1, #up.IncubationSpeed)
	profile.IncubatorCount = cleanNumber(data.IncubatorCount, up.StartingIncubators, 1, up.MaxIncubators)
	profile.WalkSpeedLevel = cleanNumber(data.WalkSpeedLevel, 1, 1, #up.WalkSpeed)
	profile.BaseLevel = cleanNumber(data.BaseLevel, 1, 1, 2)

	-- Mascotas: que existan y que no haya dos en el mismo pad
	local usedSlots: { [number]: boolean } = {}
	if typeof(data.Creatures) == "table" then
		for _, entry in data.Creatures do
			if typeof(entry) == "table" and typeof(entry.CreatureId) == "string" and Creatures.Get(entry.CreatureId) then
				local slot = validSlot(entry.Slot, 1000)
				if slot and not usedSlots[slot] then
					usedSlots[slot] = true
					table.insert(profile.Creatures, { CreatureId = entry.CreatureId, Slot = slot })
				end
			end
		end
	end

	-- Huevos incubando: rareza válida, incubadora que tenga, una sola vez cada una
	local usedIncubators: { [number]: boolean } = {}
	if typeof(data.Incubating) == "table" then
		for _, entry in data.Incubating do
			if typeof(entry) == "table" and typeof(entry.RarityId) == "string" and Config.GetRarity(entry.RarityId) then
				local slot = validSlot(entry.Slot, profile.IncubatorCount)
				if slot and not usedIncubators[slot] then
					usedIncubators[slot] = true
					local remaining = if typeof(entry.Remaining) == "number" and entry.Remaining == entry.Remaining then math.max(0, entry.Remaining) else 0
					table.insert(profile.Incubating, { Slot = slot, RarityId = entry.RarityId, Remaining = remaining })
				end
			end
		end
	end
	return profile
end

-- Copia del perfil lista para guardar (tablas simples: números, textos y listas)
local function dataFromProfile(profile: Profile, incubating: { IncubatingData }): { [string]: any }
	local creatures = {}
	for _, c in profile.Creatures do
		table.insert(creatures, { CreatureId = c.CreatureId, Slot = c.Slot })
	end
	local eggs = {}
	for _, e in incubating do
		table.insert(eggs, { Slot = e.Slot, RarityId = e.RarityId, Remaining = math.floor(e.Remaining * 10) / 10 })
	end
	return {
		Version = DATA_VERSION,
		Coins = profile.Coins,
		IncubationSpeedLevel = profile.IncubationSpeedLevel,
		IncubatorCount = profile.IncubatorCount,
		WalkSpeedLevel = profile.WalkSpeedLevel,
		BaseLevel = profile.BaseLevel,
		Creatures = creatures,
		Incubating = eggs,
		SavedAt = os.time(),
	}
end

-- ===== Guardar =====

local function writeData(userId: number, data: { [string]: any }): boolean
	-- Si ya se está guardando este jugador, esperamos (así el guardado más nuevo siempre llega último)
	while savingUsers[userId] do
		task.wait(0.1)
	end
	savingUsers[userId] = true
	local ok = withRetries(`Save {userId}`, function()
		getStore():UpdateAsync(keyFor(userId), function()
			return data
		end)
		return true
	end)
	savingUsers[userId] = nil
	return ok
end

-- Guarda en segundo plano y lleva la cuenta de los guardados pendientes (para BindToClose).
local function saveInBackground(userId: number, data: { [string]: any })
	pendingSaves += 1
	task.spawn(function()
		writeData(userId, data)
		pendingSaves -= 1
	end)
end

-- Guarda a un jugador que sigue en el juego (autoguardado / cierre del servidor).
local function saveOnline(player: Player)
	local profile = profiles[player]
	if not profile or not canSave[player] then
		return
	end
	local incubating = if incubatingProvider then incubatingProvider(player) else profile.Incubating
	saveInBackground(player.UserId, dataFromProfile(profile, incubating))
end

-- ===== Plata y niveles visibles =====

-- La tabla "leaderstats" hace que la plata se vea en la lista de jugadores de Roblox.
local function createLeaderstats(player: Player, coins: number)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coinsValue = Instance.new("NumberValue")
	coinsValue.Name = "Coins"
	coinsValue.Value = coins
	coinsValue.Parent = leaderstats
	leaderstats.Parent = player
end

local function syncCoins(player: Player, profile: Profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsValue = leaderstats and leaderstats:FindFirstChild("Coins")
	if coinsValue and coinsValue:IsA("NumberValue") then
		coinsValue.Value = profile.Coins
	end
	player:SetAttribute("Coins", profile.Coins) -- para la interfaz
end

-- Copia los niveles de mejoras a atributos del jugador, para que el panel del cliente los pueda leer.
local function syncLevels(player: Player, profile: Profile)
	player:SetAttribute("IncubationSpeedLevel", profile.IncubationSpeedLevel)
	player:SetAttribute("IncubatorCount", profile.IncubatorCount)
	player:SetAttribute("WalkSpeedLevel", profile.WalkSpeedLevel)
	player:SetAttribute("BaseLevel", profile.BaseLevel)
end

-- ===== API pública =====

-- Lee los datos del jugador (puede tardar un poco: espera al DataStore).
-- Devuelve nil si el jugador se fue mientras cargaba o si hubo que sacarlo.
function PlayerDataService.Load(player: Player): Profile?
	local existing = profiles[player]
	if existing then
		return existing
	end

	-- En Studio probamos una sola vez: si no está activado el acceso a la API, no tiene sentido esperar reintentos
	local ok, data = withRetries(`Load {player.UserId}`, function()
		return getStore():GetAsync(keyFor(player.UserId))
	end, if RunService:IsStudio() then 1 else nil)

	if not player:IsDescendantOf(Players) then
		return nil -- se fue mientras cargábamos
	end

	local profile: Profile
	if ok then
		profile = profileFromData(data)
		canSave[player] = true
	elseif RunService:IsStudio() then
		warn("[PlayerData] Couldn't load data. Playing WITHOUT saving. In Studio, turn on Game Settings > Security > 'Enable Studio Access to API Services'.")
		profile = newProfile()
		canSave[player] = false
	else
		-- En el juego publicado: mejor que reintente a que juegue y le borremos el progreso
		player:Kick("We couldn't load your data. Please rejoin in a moment!")
		return nil
	end

	profiles[player] = profile
	createLeaderstats(player, profile.Coins)
	syncCoins(player, profile)
	syncLevels(player, profile)
	return profile
end

function PlayerDataService.Get(player: Player): Profile?
	return profiles[player]
end

-- Cuando el jugador se va: guarda (en segundo plano) y suelta sus datos.
-- Para entonces IncubatorService ya pasó los huevos a profile.Incubating.
function PlayerDataService.Unload(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	if canSave[player] then
		saveInBackground(player.UserId, dataFromProfile(profile, profile.Incubating))
	end
	canSave[player] = nil
end

-- IncubatorService le dice a este servicio cómo sacar la foto de los huevos que se están incubando
-- (para el autoguardado mientras el jugador sigue jugando).
function PlayerDataService.SetIncubatingProvider(provider: (Player) -> { IncubatingData })
	incubatingProvider = provider
end

-- Hay que llamarlo después de cambiar un nivel de mejora en el perfil.
function PlayerDataService.SyncLevels(player: Player)
	local profile = profiles[player]
	if profile then
		syncLevels(player, profile)
	end
end

function PlayerDataService.AddCoins(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or amount <= 0 then
		return
	end
	profile.Coins += amount
	syncCoins(player, profile)
end

-- Cobra si alcanza la plata. Devuelve true si pudo cobrar. (Lo usan las mejoras.)
function PlayerDataService.SpendCoins(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or amount < 0 or profile.Coins < amount then
		return false
	end
	profile.Coins -= amount
	syncCoins(player, profile)
	return true
end

-- Guarda a todos los que están jugando (lo usan el autoguardado y el cierre del servidor).
function PlayerDataService.SaveAll()
	for player in profiles do
		saveOnline(player)
	end
end

function PlayerDataService.Init()
	Players.PlayerRemoving:Connect(function(player)
		-- Por si el jugador se va sin haber tenido base (servidor lleno): no queda nada colgado
		task.defer(function()
			if profiles[player] then
				PlayerDataService.Unload(player)
			end
			canSave[player] = nil
		end)
	end)

	-- Autoguardado
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			PlayerDataService.SaveAll()
		end
	end)

	-- Cuando el servidor se apaga: guardamos a todos y esperamos a que terminen (Roblox da ~30 s)
	game:BindToClose(function()
		PlayerDataService.SaveAll()
		local started = os.clock()
		while pendingSaves > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService

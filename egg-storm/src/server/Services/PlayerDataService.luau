--!strict
-- PlayerDataService: los datos de cada jugador (plata, mascotas, mejoras, huevos incubando).
-- Por ahora viven solo en memoria mientras el jugador está en el servidor.
-- En la fase 7 se guardan con DataStore: Load y Unload son los lugares donde se va a leer y escribir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type CreatureData = {
	CreatureId: string,
	Slot: number, -- en qué pad de mascotas está
}

export type IncubatingData = {
	Slot: number, -- en qué incubadora
	RarityId: string,
	Remaining: number, -- segundos que le faltaban al salir (para restaurarlo al volver a entrar)
}

export type Profile = {
	Coins: number,
	IncubationSpeedLevel: number,
	IncubatorCount: number,
	WalkSpeedLevel: number,
	BaseLevel: number, -- pisos extra de la base ("mejorar base", fase 4)
	Creatures: { CreatureData },
	Incubating: { IncubatingData }, -- solo se llena al guardar/salir
}

local PlayerDataService = {}

local profiles: { [Player]: Profile } = {}

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
	player:SetAttribute("Coins", profile.Coins) -- para la interfaz de la fase 6
end

-- Copia los niveles de mejoras a atributos del jugador, para que el panel del cliente los pueda leer.
local function syncLevels(player: Player, profile: Profile)
	player:SetAttribute("IncubationSpeedLevel", profile.IncubationSpeedLevel)
	player:SetAttribute("IncubatorCount", profile.IncubatorCount)
	player:SetAttribute("WalkSpeedLevel", profile.WalkSpeedLevel)
	player:SetAttribute("BaseLevel", profile.BaseLevel)
end

-- ===== API pública =====

function PlayerDataService.Load(player: Player): Profile
	local existing = profiles[player]
	if existing then
		return existing
	end
	local profile = newProfile() -- fase 7: acá se lee del DataStore
	profiles[player] = profile
	createLeaderstats(player, profile.Coins)
	syncCoins(player, profile)
	syncLevels(player, profile)
	return profile
end

function PlayerDataService.Get(player: Player): Profile?
	return profiles[player]
end

function PlayerDataService.Unload(player: Player)
	-- fase 7: acá se guarda en el DataStore antes de borrar
	profiles[player] = nil
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

-- Cobra si alcanza la plata. Devuelve true si pudo cobrar. (Lo usan las mejoras de la fase 4.)
function PlayerDataService.SpendCoins(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or amount < 0 or profile.Coins < amount then
		return false
	end
	profile.Coins -= amount
	syncCoins(player, profile)
	return true
end

function PlayerDataService.Init()
	Players.PlayerRemoving:Connect(function(player)
		-- Por si el jugador se va sin haber tenido base (servidor lleno)
		task.defer(function()
			profiles[player] = nil
		end)
	end)
end

return PlayerDataService

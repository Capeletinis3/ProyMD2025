--!strict
-- EggService: los huevos del cañón. Aparecen en puntos fijos de cada zona y los jugadores los agarran y los llevan.
-- Cada huevo es un objeto del servidor (tabla Egg) con su rareza, su variante, su Part y su estado.
-- El cliente nunca dice "agarré un huevo": solo aprieta el ProximityPrompt y el servidor decide si vale.
--
-- Qué sale y dónde:
--   - Cada zona del cañón (Config.Zones) da huevos de SU rareza, o con poca chance de la siguiente.
--   - Cada zona tiene sus puntos de aparición (Workspace.EggSpawns.ZoneN, los arma MapBuilder), un máximo
--     de huevos a la vez y un tiempo de reaparición.
--   - Aparte de la rareza, cada huevo puede tener una variante (Silver, Golden, Emerald...).
--   - Los eventos (EventService) cambian estas chances, y en "Meteor Shower" caen meteoritos.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)
local TutorialService = require(script.Parent.TutorialService)
local EventService = require(script.Parent.EventService)

type Rarity = Config.Rarity
type Variant = Config.Variant

export type EggState = "Falling" | "Ground" | "Carried"

export type Egg = {
	Id: number,
	Rarity: Rarity,
	Variant: Variant,
	Part: BasePart,
	Prompt: ProximityPrompt,
	State: EggState,
	Carrier: Player?,
	Zone: number?, -- zona y punto de aparición donde nació (nil para los meteoritos)
	Spot: number?,
}

export type SpawnOptions = {
	Rarity: Rarity?,
	Variant: Variant?,
	Position: Vector3?,
	Meteor: boolean?,
	Zone: number?,
	Spot: number?,
}

-- Puntos de aparición de una zona y qué huevo hay en cada uno
type ZoneState = {
	Spots: { Vector3 },
	Occupied: { [number]: Egg },
	Active: number,
}

-- Efectos visuales por rareza (no son balance, por eso no están en Config).
type Visual = {
	LightBrightness: number,
	Sparkles: number, -- partículas por segundo (0 = sin partículas)
	Beacon: boolean, -- columna de luz cuando está en el piso, para verlo de lejos
}

local VISUALS: { [string]: Visual } = {
	Common = { LightBrightness = 0.8, Sparkles = 0, Beacon = false },
	Rare = { LightBrightness = 1.2, Sparkles = 3, Beacon = false },
	Epic = { LightBrightness = 2, Sparkles = 8, Beacon = false },
	Legendary = { LightBrightness = 3, Sparkles = 15, Beacon = true },
	Mythic = { LightBrightness = 3, Sparkles = 20, Beacon = true },
	Secret = { LightBrightness = 3, Sparkles = 25, Beacon = true },
}

local EGG_SIZE = Config.Eggs.Size
local FLOOR_Y = Config.Map.FloorY
local POP_HEIGHT = 8 -- los huevos de los puntos aparecen cayendo desde un poquito más arriba
local POP_TIME = 0.5
local METEOR_FALL_TIME = 1.6

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 255, 100)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 80, 255)),
})

local EggService = {}

local random = Random.new()
local eggsFolder: Folder
local eggs: { [number]: Egg } = {}
local zones: { ZoneState } = {}
local carriedByPlayer: { [Player]: { Egg } } = {} -- los huevos que lleva cada uno (el VIP puede llevar 2)
local lastGrabAttempt: { [Player]: number } = {}
local nextEggId = 0

local notifyRemote = Remotes.Event("Notify")

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

local function eggName(rarity: Rarity, variant: Variant): string
	return Config.WithVariant(variant, `{rarity.DisplayName} Egg`)
end

-- ===== Sorteos =====

-- Rareza de un huevo de esta zona: la de la zona, o la siguiente con poca chance (más en Lucky Storm).
function EggService.RollZoneRarity(zone: Config.Zone): Rarity
	local nextRarity = zone.NextRarityId and Config.GetRarity(zone.NextRarityId)
	local chance = math.min(1, zone.NextChance * EventService.NextChanceMultiplier())
	if nextRarity and random:NextNumber() < chance then
		return nextRarity
	end
	return Config.GetRarity(zone.RarityId) or Config.Rarities[1]
end

local function rollMeteorRarity(): Rarity
	local weights = Config.Events.MeteorRarityWeights
	local total = 0
	for _, rarity in Config.Rarities do
		total += weights[rarity.Id] or 0
	end
	local roll = random:NextNumber(0, total)
	for _, rarity in Config.Rarities do
		local weight = weights[rarity.Id] or 0
		roll -= weight
		if weight > 0 and roll <= 0 then
			return rarity
		end
	end
	return Config.Rarities[#Config.Rarities]
end

local function rollVariant(): Variant
	local function weightOf(variant: Variant): number
		return variant.Weight * EventService.VariantMultiplier(variant.Id)
	end
	local total = 0
	for _, variant in Config.Variants do
		total += weightOf(variant)
	end
	local roll = random:NextNumber(0, total)
	for _, variant in Config.Variants do
		roll -= weightOf(variant)
		if roll <= 0 then
			return variant
		end
	end
	return Config.Variants[1]
end

-- Un punto al azar en cualquier parte del cañón (para los meteoritos)
local function randomCanyonPosition(): Vector3
	local map = Config.Map
	local halfWidth = map.CanyonWidth / 2 - map.SpawnWallMargin
	local x = random:NextNumber(map.CanyonStartX + 20, map.CanyonStartX + map.CanyonLength - 10)
	return Vector3.new(x, FLOOR_Y, random:NextNumber(-halfWidth, halfWidth))
end

-- ===== Armado del huevo =====

-- Color con el que se ve un huevo (la variante manda sobre la rareza).
local function eggColor(rarity: Rarity, variant: Variant): Color3
	return if variant.Id ~= "Normal" then variant.Color else rarity.Color
end

local function isRainbow(rarity: Rarity, variant: Variant): boolean
	return rarity.Id == "Secret" or variant.Id == "Rainbow"
end

-- Pinta una Part como huevo de esta rareza y variante. También lo usa la incubadora.
function EggService.DecorateEgg(part: BasePart, rarity: Rarity, variant: Variant)
	-- (si ya estaba decorado, por ejemplo cuando la suerte lo sube de rareza, sacamos lo viejo)
	for _, child in part:GetChildren() do
		if child:IsA("SpecialMesh") or child:IsA("PointLight") or child.Name == "Sparkles" then
			child:Destroy()
		end
	end
	local special = variant.Id ~= "Normal"
	part.Color = eggColor(rarity, variant)
	part.Material = if special then variant.Material
		elseif rarity.Id == "Secret" then Enum.Material.Glass
		else Enum.Material.SmoothPlastic

	-- Un SpecialMesh esférico estira la Part y le da forma de huevo.
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part

	local visual = VISUALS[rarity.Id] or VISUALS.Common
	local light = Instance.new("PointLight")
	light.Color = if isRainbow(rarity, variant) then Color3.new(1, 1, 1) else part.Color
	light.Brightness = visual.LightBrightness + (if special then 1.5 else 0)
	light.Range = 8
	light.Parent = part

	local sparkleRate = math.max(visual.Sparkles, if special then 10 else 0)
	if sparkleRate > 0 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Color = if isRainbow(rarity, variant) then RAINBOW else ColorSequence.new(part.Color)
		sparkles.LightEmission = 1
		sparkles.Rate = sparkleRate
		sparkles.Lifetime = NumberRange.new(0.8, 1.5)
		sparkles.Speed = NumberRange.new(1, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.4, 0)
		sparkles.Parent = part
	end
end

local function createEggPart(id: number, rarity: Rarity, variant: Variant): (BasePart, ProximityPrompt)
	local part = Instance.new("Part")
	part.Name = `{rarity.Id}Egg`
	part.Size = EGG_SIZE
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part:SetAttribute("EggId", id)
	part:SetAttribute("Rarity", rarity.Id)
	part:SetAttribute("Variant", variant.Id)
	EggService.DecorateEgg(part, rarity, variant)

	-- Explosión de partículas al tocar el piso (Rate 0: solo sale cuando la disparamos con :Emit)
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "LandingBurst"
	burst.Color = if isRainbow(rarity, variant) then RAINBOW else ColorSequence.new(part.Color)
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.4, 0.8)
	burst.Speed = NumberRange.new(10, 18)
	burst.SpreadAngle = Vector2.new(80, 80)
	burst.Size = NumberSequence.new(0.6, 0)
	burst.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = eggName(rarity, variant)
	prompt.HoldDuration = Config.Eggs.GrabHoldTime
	prompt.MaxActivationDistance = Config.Eggs.GrabDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- se habilita cuando aterriza
	prompt.Parent = part

	return part, prompt
end

-- Círculo en el piso que avisa dónde va a caer un meteorito.
local function createLandingMarker(position: Vector3, color: Color3, size: number): Part
	local marker = Instance.new("Part")
	marker.Name = "LandingMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.1, size, size)
	marker.CFrame = CFrame.new(position.X, FLOOR_Y + 0.15, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	marker.Color = color
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.5
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Parent = eggsFolder
	return marker
end

-- Columna de luz para los huevos muy buenos (Legendary o mejor, o variante Emerald o mejor).
local function needsBeacon(egg: Egg): boolean
	return (VISUALS[egg.Rarity.Id] or VISUALS.Common).Beacon or egg.Variant.Multiplier >= 5
end

local function addBeacon(egg: Egg)
	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(80, 1.5, 1.5)
	-- Cilindro parado: el eje X apunta para arriba
	beacon.CFrame = CFrame.new(egg.Part.Position + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Color = if isRainbow(egg.Rarity, egg.Variant) then Color3.new(1, 1, 1) else egg.Part.Color
	beacon.Material = Enum.Material.Neon
	beacon.Transparency = 0.6
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanTouch = false
	beacon.CanQuery = false
	beacon.Parent = egg.Part
end

-- Mancha quemada que deja un meteorito (se borra sola).
local function addScorch(position: Vector3)
	local scorch = createLandingMarker(position, Color3.fromRGB(45, 35, 30), 14)
	scorch.Name = "Scorch"
	scorch.Material = Enum.Material.SmoothPlastic
	scorch.Transparency = 0.2
	TweenService:Create(scorch, TweenInfo.new(6), { Transparency = 1 }):Play()
	task.delay(6, function()
		scorch:Destroy()
	end)
end

-- ===== Ciclo de vida =====

-- Libera el punto de aparición que ocupaba este huevo (así puede salir otro ahí)
local function freeSpot(egg: Egg)
	local zone = egg.Zone and zones[egg.Zone]
	if zone and egg.Spot and zone.Occupied[egg.Spot] == egg then
		zone.Occupied[egg.Spot] = nil
		zone.Active -= 1
	end
	egg.Zone = nil
	egg.Spot = nil
end

-- Publica para el cliente el próximo huevo que va a entregar (el primero que agarró) y cuántos lleva
local function syncCarried(player: Player)
	local list = carriedByPlayer[player]
	local first = list and list[1]
	player:SetAttribute("CarriedEggRarity", if first then first.Rarity.Id else nil)
	player:SetAttribute("CarriedEggVariant", if first then first.Variant.Id else nil)
	player:SetAttribute("CarriedEggCount", if list and #list > 0 then #list else nil)
end

local function destroyEgg(egg: Egg)
	eggs[egg.Id] = nil
	freeSpot(egg)
	local carrier = egg.Carrier
	if carrier then
		local list = carriedByPlayer[carrier]
		local index = list and table.find(list, egg)
		if list and index then
			table.remove(list, index)
			if #list == 0 then
				carriedByPlayer[carrier] = nil
			end
		end
		egg.Carrier = nil
		syncCarried(carrier)
	end
	egg.Part:Destroy()
end

local function onLanded(egg: Egg, marker: Part?, meteor: boolean)
	if marker then
		marker:Destroy()
	end
	if eggs[egg.Id] ~= egg or egg.State ~= "Falling" then
		return -- lo borraron mientras caía
	end
	egg.State = "Ground"
	egg.Prompt.Enabled = true
	-- Gira despacio y flota un poco: lo anima cada cliente (EggAnimator), el servidor no lo mueve
	egg.Part:SetAttribute("Spin", 45)
	egg.Part:SetAttribute("Bob", 0.4)
	CollectionService:AddTag(egg.Part, "Spinning")

	local burst = egg.Part:FindFirstChild("LandingBurst")
	if burst and burst:IsA("ParticleEmitter") then
		burst:Emit(if meteor then 80 else 20)
	end
	if meteor then
		local fire = egg.Part:FindFirstChild("MeteorFire")
		if fire then
			fire:Destroy()
		end
		addScorch(egg.Part.Position)
	end
	if needsBeacon(egg) then
		addBeacon(egg)
	end
end

-- Hace aparecer un huevo. Con Zone y Spot: en ese punto de aparición. Con Meteor: cae del cielo en llamas.
function EggService.SpawnEgg(options: SpawnOptions?): Egg
	local opts: SpawnOptions = options or {}
	local meteor = opts.Meteor == true
	local zoneIndex = opts.Zone
	local zoneInfo = if zoneIndex then Config.Zones[zoneIndex] else nil
	local target = opts.Position or randomCanyonPosition()
	local landing = Vector3.new(target.X, FLOOR_Y + EGG_SIZE.Y / 2 + 0.3, target.Z)
	local rarity = opts.Rarity
		or (if meteor then rollMeteorRarity() elseif zoneInfo then EggService.RollZoneRarity(zoneInfo) else Config.Rarities[1])
	local variant = opts.Variant or rollVariant()

	nextEggId += 1
	local part, prompt = createEggPart(nextEggId, rarity, variant)
	local egg: Egg = {
		Id = nextEggId,
		Rarity = rarity,
		Variant = variant,
		Part = part,
		Prompt = prompt,
		State = "Falling",
		Carrier = nil,
		Zone = nil,
		Spot = nil,
	}
	eggs[egg.Id] = egg
	local zone = if zoneIndex then zones[zoneIndex] else nil
	if zone and opts.Spot then
		egg.Zone = zoneIndex
		egg.Spot = opts.Spot
		zone.Occupied[opts.Spot] = egg
		zone.Active += 1
	end

	local spin = CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	local fallTime = POP_TIME
	local marker: Part? = nil
	if meteor then
		-- El meteorito entra en diagonal (desde el lado del volcán), prendido fuego y rápido
		part.CFrame = CFrame.new(landing + Vector3.new(80, Config.Eggs.FallHeight, 30)) * spin
		local fire = Instance.new("Fire")
		fire.Name = "MeteorFire"
		fire.Size = 10
		fire.Heat = 20
		fire.Color = Color3.fromRGB(255, 120, 40)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
		fire.Parent = part
		marker = createLandingMarker(landing, Color3.fromRGB(255, 60, 40), 12)
		fallTime = METEOR_FALL_TIME
	else
		part.CFrame = CFrame.new(landing + Vector3.new(0, POP_HEIGHT, 0)) * spin
	end
	part.Parent = eggsFolder

	prompt.Triggered:Connect(function(player)
		EggService.TryGrab(player, egg)
	end)

	-- Caída: acelera hacia el final (Quad In), como si fuera gravedad.
	local tween = TweenService:Create(
		part,
		TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(landing) * spin }
	)
	tween.Completed:Connect(function()
		onLanded(egg, marker, meteor)
	end)
	tween:Play()
	return egg
end

-- Un huevo nuevo en un punto libre de la zona (si no está llena). Devuelve el huevo o nil.
function EggService.SpawnInZone(zoneIndex: number): Egg?
	local zone = zones[zoneIndex]
	local info = Config.Zones[zoneIndex]
	if not zone or not info or zone.Active >= info.MaxActive then
		return nil
	end
	local free: { number } = {}
	for spot = 1, #zone.Spots do
		if not zone.Occupied[spot] then
			table.insert(free, spot)
		end
	end
	if #free == 0 then
		return nil
	end
	local spot = free[random:NextInteger(1, #free)]
	return EggService.SpawnEgg({ Zone = zoneIndex, Spot = spot, Position = zone.Spots[spot] })
end

-- Cuántos huevos hay ahora en una zona (en el piso o cayendo)
function EggService.CountInZone(zoneIndex: number): number
	local zone = zones[zoneIndex]
	return if zone then zone.Active else 0
end

-- Dónde se lleva el huevo: el 1.º en la mano derecha y el 2.º (VIP) en la izquierda (R15 o R6).
-- Si no hay manos, arriba de la cabeza (uno arriba del otro).
local function holdPoint(character: Model, index: number): (BasePart?, CFrame)
	local hand = if index == 1
		then character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		else character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	if hand and hand:IsA("BasePart") then
		-- Adelante de la mano, como si lo llevara agarrado
		return hand, CFrame.new(0, -hand.Size.Y / 2 - 0.4, -EGG_SIZE.Z / 2 - 0.2)
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head, CFrame.new(0, head.Size.Y / 2 + EGG_SIZE.Y * (index - 0.5) + 0.5, 0)
	end
	return nil, CFrame.new()
end

local function attachToCharacter(egg: Egg, character: Model, index: number): boolean
	local holder, offset = holdPoint(character, index)
	if not holder then
		return false
	end

	local beacon = egg.Part:FindFirstChild("Beacon")
	if beacon then
		beacon:Destroy()
	end
	egg.Prompt.Enabled = false
	CollectionService:RemoveTag(egg.Part, "Spinning")

	local part = egg.Part
	part.CFrame = holder.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = holder
	weld.Part1 = part
	weld.Parent = part
	part.Massless = true -- que no pese ni cambie cómo camina el personaje
	part.CanQuery = false
	part.Anchored = false
	return true
end

-- ===== API pública =====

-- Lo llama el ProximityPrompt. Valida TODO en el servidor antes de dar el huevo.
function EggService.TryGrab(player: Player, egg: Egg)
	if eggs[egg.Id] ~= egg or egg.State ~= "Ground" then
		return
	end

	-- Anti-spam
	local now = os.clock()
	if now - (lastGrabAttempt[player] or 0) < Config.Eggs.GrabCooldown then
		return
	end
	lastGrabAttempt[player] = now

	local carried = carriedByPlayer[player] or {}
	local capacity = Config.CarryCapacity(player)
	if #carried >= capacity then
		notify(player, if capacity == 1 then "You can only carry 1 egg at a time!" else `You can only carry {capacity} eggs at a time!`)
		return
	end
	if not BaseService.GetBase(player) then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	-- Distancia: un margen extra por el lag, pero nada de agarrar desde lejos.
	if (root.Position - egg.Part.Position).Magnitude > Config.Eggs.GrabDistance + 5 then
		return
	end

	if not attachToCharacter(egg, character, #carried + 1) then
		return
	end
	egg.State = "Carried"
	egg.Carrier = player
	table.insert(carried, egg)
	carriedByPlayer[player] = carried
	freeSpot(egg) -- el punto queda libre para que salga otro huevo
	syncCarried(player) -- para que el cliente pueda mostrarlo
	-- Suerte: puede subir una rareza
	local upgraded = false
	if random:NextNumber() < Config.LuckChance(player, egg.Rarity.Id) then
		local better = Config.Rarities[Config.RarityRank(egg.Rarity.Id) + 1]
		if better then
			egg.Rarity = better
			egg.Part.Name = `{better.Id}Egg`
			egg.Part:SetAttribute("Rarity", better.Id)
			EggService.DecorateEgg(egg.Part, better, egg.Variant)
			syncCarried(player)
			upgraded = true
		end
	end
	if upgraded then
		notify(player, `🍀 Lucky! It became a {eggName(egg.Rarity, egg.Variant)}! Bring it to your base.`)
	else
		notify(player, `You grabbed a {eggName(egg.Rarity, egg.Variant)}! Bring it to your base.`)
	end
	TutorialService.OnEvent(player, "Grabbed")
end

-- El próximo huevo que entregaría (el primero que agarró), o nil si no lleva ninguno
function EggService.GetCarriedEgg(player: Player): Egg?
	local list = carriedByPlayer[player]
	return list and list[1]
end

function EggService.GetCarriedCount(player: Player): number
	local list = carriedByPlayer[player]
	return if list then #list else 0
end

-- El jugador entrega un huevo (el primero que agarró), por ejemplo a una incubadora. Devuelve su rareza y variante.
function EggService.TakeCarriedEgg(player: Player): (Rarity?, Variant?)
	local egg = EggService.GetCarriedEgg(player)
	if not egg then
		return nil, nil
	end
	local rarity, variant = egg.Rarity, egg.Variant
	destroyEgg(egg)
	return rarity, variant
end

-- El jugador pierde los huevos que lleva (lo agarró la ola, se murió, se fue del juego).
function EggService.LoseCarriedEgg(player: Player)
	local list = carriedByPlayer[player]
	if list then
		for _, egg in table.clone(list) do
			destroyEgg(egg)
		end
	end
end

-- Borra todos los huevos del piso (los puntos quedan libres y se vuelven a llenar solos).
function EggService.ClearWorldEggs()
	for _, egg in eggs do
		if egg.State ~= "Carried" then
			destroyEgg(egg)
		end
	end
	for _, child in eggsFolder:GetChildren() do
		if child.Name == "LandingMarker" then
			child:Destroy()
		end
	end
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			EggService.LoseCarriedEgg(player)
		end)
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
	player.CharacterRemoving:Connect(function()
		EggService.LoseCarriedEgg(player)
	end)
end

-- Lee los puntos de aparición que armó MapBuilder (Workspace.EggSpawns.ZoneN)
local function loadSpots()
	local root = Workspace:FindFirstChild("EggSpawns")
	for index in Config.Zones do
		local spots: { Vector3 } = {}
		local zoneFolder = root and root:FindFirstChild(`Zone{index}`)
		if zoneFolder then
			for _, child in zoneFolder:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(spots, child.Position)
				end
			end
		end
		zones[index] = { Spots = spots, Occupied = {}, Active = 0 }
	end
end

function EggService.Init()
	eggsFolder = Instance.new("Folder")
	eggsFolder.Name = "Eggs"
	eggsFolder.Parent = Workspace
	loadSpots()

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		EggService.LoseCarriedEgg(player)
		lastGrabAttempt[player] = nil
	end)

	-- Cada zona arranca llena y después repone un huevo cada Respawn segundos (más rápido en Golden Rain)
	for index, info in Config.Zones do
		for _ = 1, info.MaxActive do
			EggService.SpawnInZone(index)
		end
		task.spawn(function()
			while true do
				task.wait(info.Respawn * EventService.RespawnMultiplier())
				EggService.SpawnInZone(index)
			end
		end)
	end

	-- Meteoritos (solo con el evento Meteor Shower)
	task.spawn(function()
		while true do
			task.wait(Config.Events.MeteorInterval)
			if EventService.IsActive("MeteorShower") then
				EggService.SpawnEgg({ Meteor = true })
			end
		end
	end)
end

return EggService

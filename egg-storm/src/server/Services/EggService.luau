--!strict
-- EggService: hace caer huevos en el pasillo y deja que los jugadores los agarren y los lleven.
-- Cada huevo es un objeto del servidor (tabla Egg) con su rareza, su variante, su Part y su estado.
-- El cliente nunca dice "agarré un huevo": solo aprieta el ProximityPrompt y el servidor decide si vale.
--
-- Dónde y qué cae:
--   - Cualquier rareza puede caer en cualquier parte del pasillo, pero cuanto más lejos, más chance de
--     las mejores (Config.Rarities[].FarBonus).
--   - Aparte de la rareza, cada huevo puede tener una variante (Silver, Golden, Emerald...).
--   - Los eventos de tormenta (EventService) cambian estas chances, y en "Meteor Shower" caen meteoritos.

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
}

export type SpawnOptions = {
	Rarity: Rarity?,
	Variant: Variant?,
	Position: Vector3?,
	Meteor: boolean?,
}

-- Efectos visuales por rareza (no son balance, por eso no están en Config).
type Visual = {
	LightBrightness: number,
	LightRange: number,
	Sparkles: number, -- partículas por segundo (0 = sin partículas)
	Beacon: boolean, -- columna de luz cuando está en el piso, para verlo de lejos
}

local VISUALS: { [string]: Visual } = {
	Common = { LightBrightness = 0.5, LightRange = 6, Sparkles = 0, Beacon = false },
	Rare = { LightBrightness = 1, LightRange = 10, Sparkles = 3, Beacon = false },
	Epic = { LightBrightness = 2, LightRange = 14, Sparkles = 8, Beacon = false },
	Legendary = { LightBrightness = 3, LightRange = 18, Sparkles = 15, Beacon = true },
	Secret = { LightBrightness = 3, LightRange = 20, Sparkles = 25, Beacon = true },
}

local EGG_SIZE = Vector3.new(3, 4, 3)
local FLOOR_Y = Config.Map.FloorY
local MIN_DISTANCE = 25 -- los huevos no caen pegados a la línea segura
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
local carriedByPlayer: { [Player]: Egg } = {}
local lastGrabAttempt: { [Player]: number } = {}
local nextEggId = 0
local raining = false

local notifyRemote = Remotes.Event("Notify")

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

local function eggName(rarity: Rarity, variant: Variant): string
	return Config.WithVariant(variant, `{rarity.DisplayName} Egg`)
end

-- ===== Sorteos =====

-- Sorteo con pesos: cuanto más peso, más chance.
local function pickRarity(weightOf: (Rarity) -> number): Rarity
	local total = 0
	for _, rarity in Config.Rarities do
		total += weightOf(rarity)
	end
	local roll = random:NextNumber(0, total)
	for _, rarity in Config.Rarities do
		local weight = weightOf(rarity)
		roll -= weight
		if weight > 0 and roll <= 0 then
			return rarity
		end
	end
	return Config.Rarities[1]
end

-- Peso de una rareza según qué tan lejos cae (distance: 0 = entrada del pasillo, 1 = fondo)
-- y el evento activo. Público para poder probarlo.
function EggService.RarityWeight(rarity: Rarity, distance: number): number
	return rarity.Weight * (1 + rarity.FarBonus * distance) * EventService.RarityMultiplier(rarity.Id)
end

local function rollRarity(distance: number): Rarity
	return pickRarity(function(rarity)
		return EggService.RarityWeight(rarity, distance)
	end)
end

local function rollMeteorRarity(): Rarity
	return pickRarity(function(rarity)
		return Config.Events.MeteorRarityWeights[rarity.Id] or 0
	end)
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

-- Un punto al azar en cualquier parte del pasillo (lejos de las paredes y de la línea segura).
local function randomLandingPosition(): Vector3
	local map = Config.Map
	local halfWidth = map.CorridorWidth / 2 - map.EggSideMargin
	local x = random:NextNumber(-halfWidth, halfWidth)
	local z = random:NextNumber(MIN_DISTANCE, map.CorridorLength - 5)
	return Vector3.new(x, FLOOR_Y + EGG_SIZE.Y / 2, z)
end

local function countEggsInWorld(): number
	local count = 0
	for _, egg in eggs do
		if egg.State ~= "Carried" then
			count += 1
		end
	end
	return count
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
	light.Range = visual.LightRange + (if special then 4 else 0)
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

-- Círculo en el piso que avisa dónde va a caer el huevo.
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

-- Columna de luz para los huevos muy buenos (Legendary, Secret o variante Emerald o mejor).
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

local function destroyEgg(egg: Egg)
	eggs[egg.Id] = nil
	if egg.Carrier then
		carriedByPlayer[egg.Carrier] = nil
		egg.Carrier:SetAttribute("CarriedEggRarity", nil)
		egg.Carrier:SetAttribute("CarriedEggVariant", nil)
		egg.Carrier = nil
	end
	egg.Part:Destroy()
end

local function onLanded(egg: Egg, marker: Part, meteor: boolean)
	marker:Destroy()
	if eggs[egg.Id] ~= egg or egg.State ~= "Falling" then
		return -- lo borró la ola mientras caía
	end
	egg.State = "Ground"
	egg.Prompt.Enabled = true

	local burst = egg.Part:FindFirstChild("LandingBurst")
	if burst and burst:IsA("ParticleEmitter") then
		burst:Emit(if meteor then 80 else 25)
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

-- Hace caer un huevo. Sin opciones: lugar, rareza y variante al azar (con las reglas de arriba).
-- Devuelve el huevo, o nil si ya hay demasiados en el piso.
function EggService.SpawnEgg(options: SpawnOptions?): Egg?
	local opts: SpawnOptions = options or {}
	local meteor = opts.Meteor == true
	if not meteor and countEggsInWorld() >= Config.Eggs.MaxOnGround then
		return nil
	end

	local landing = opts.Position or randomLandingPosition()
	local distance = math.clamp(landing.Z / Config.Map.CorridorLength, 0, 1)
	local rarity = opts.Rarity or (if meteor then rollMeteorRarity() else rollRarity(distance))
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
	}
	eggs[egg.Id] = egg

	local spin = CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	local fallTime = Config.Eggs.FallTime
	local marker: Part
	if meteor then
		-- El meteorito entra en diagonal, prendido fuego y más rápido
		part.CFrame = CFrame.new(landing + Vector3.new(50, Config.Eggs.FallHeight, 80)) * spin
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
		part.CFrame = CFrame.new(landing + Vector3.new(0, Config.Eggs.FallHeight, 0)) * spin
		marker = createLandingMarker(landing, part.Color, 6)
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

local function attachToCharacter(egg: Egg, character: Model): boolean
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return false
	end

	local beacon = egg.Part:FindFirstChild("Beacon")
	if beacon then
		beacon:Destroy()
	end
	egg.Prompt.Enabled = false

	local part = egg.Part
	part.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + Config.Eggs.CarryHeight, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
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

	if carriedByPlayer[player] then
		notify(player, "You can only carry 1 egg at a time!")
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

	if not attachToCharacter(egg, character) then
		return
	end
	egg.State = "Carried"
	egg.Carrier = player
	carriedByPlayer[player] = egg
	-- Para que el cliente pueda mostrarlo
	player:SetAttribute("CarriedEggRarity", egg.Rarity.Id)
	player:SetAttribute("CarriedEggVariant", egg.Variant.Id)
	notify(player, `You grabbed a {eggName(egg.Rarity, egg.Variant)}! Bring it to your base.`)
	TutorialService.OnEvent(player, "Grabbed")
end

function EggService.GetCarriedEgg(player: Player): Egg?
	return carriedByPlayer[player]
end

-- El jugador entrega el huevo que lleva (por ejemplo, a una incubadora). Devuelve su rareza y variante.
function EggService.TakeCarriedEgg(player: Player): (Rarity?, Variant?)
	local egg = carriedByPlayer[player]
	if not egg then
		return nil, nil
	end
	local rarity, variant = egg.Rarity, egg.Variant
	destroyEgg(egg)
	return rarity, variant
end

-- El jugador pierde el huevo que lleva (muerte, ola, salida del juego).
function EggService.LoseCarriedEgg(player: Player)
	local egg = carriedByPlayer[player]
	if egg then
		destroyEgg(egg)
	end
end

-- Borra los huevos que están en el piso o cayendo.
function EggService.ClearWorldEggs()
	for _, egg in eggs do
		if egg.State ~= "Carried" then
			destroyEgg(egg)
		end
	end
	-- Los círculos de aviso de huevos que estaban cayendo
	for _, child in eggsFolder:GetChildren() do
		if child.Name == "LandingMarker" then
			child:Destroy()
		end
	end
end

-- Borra los huevos del piso que la ola ya alcanzó (los que están en Z >= frontZ).
function EggService.ClearWorldEggsBeyond(frontZ: number)
	for _, egg in eggs do
		if egg.State ~= "Carried" and egg.Part.Position.Z >= frontZ then
			destroyEgg(egg)
		end
	end
	for _, child in eggsFolder:GetChildren() do
		if child.Name == "LandingMarker" and child:IsA("BasePart") and child.Position.Z >= frontZ then
			child:Destroy()
		end
	end
end

-- Prende/apaga la lluvia de huevos (lo maneja el ciclo de tormenta).
function EggService.SetRaining(on: boolean)
	raining = on
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

function EggService.Init()
	eggsFolder = Instance.new("Folder")
	eggsFolder.Name = "Eggs"
	eggsFolder.Parent = Workspace

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		EggService.LoseCarriedEgg(player)
		lastGrabAttempt[player] = nil
	end)

	-- Lluvia normal de huevos
	task.spawn(function()
		while true do
			task.wait(Config.Eggs.SpawnInterval)
			if raining then
				EggService.SpawnEgg()
			end
		end
	end)

	-- Meteoritos (solo con el evento Meteor Shower)
	task.spawn(function()
		while true do
			task.wait(Config.Events.MeteorInterval)
			if raining and EventService.IsActive("MeteorShower") then
				EggService.SpawnEgg({ Meteor = true })
			end
		end
	end)
end

return EggService

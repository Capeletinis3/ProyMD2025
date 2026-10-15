--!strict
-- EggService: hace caer huevos en la zona de peligro y deja que los jugadores los agarren y los lleven.
-- Cada huevo es un objeto del servidor (tabla Egg) con su rareza, su Part y su estado.
-- El cliente nunca dice "agarré un huevo": solo aprieta el ProximityPrompt y el servidor decide si vale.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)

type Rarity = Config.Rarity

export type EggState = "Falling" | "Ground" | "Carried"

export type Egg = {
	Id: number,
	Rarity: Rarity,
	Part: BasePart,
	Prompt: ProximityPrompt,
	State: EggState,
	Carrier: Player?,
}

-- Efectos visuales por rareza (no son balance, por eso no están en Config).
type Visual = {
	LightBrightness: number,
	LightRange: number,
	Sparkles: number, -- partículas por segundo (0 = sin partículas)
	Beacon: boolean, -- columna de luz cuando está en el piso, para verlo de lejos
	Rainbow: boolean,
}

local VISUALS: { [string]: Visual } = {
	Common = { LightBrightness = 0.5, LightRange = 6, Sparkles = 0, Beacon = false, Rainbow = false },
	Rare = { LightBrightness = 1, LightRange = 10, Sparkles = 3, Beacon = false, Rainbow = false },
	Epic = { LightBrightness = 2, LightRange = 14, Sparkles = 8, Beacon = false, Rainbow = false },
	Legendary = { LightBrightness = 3, LightRange = 18, Sparkles = 15, Beacon = true, Rainbow = false },
	Secret = { LightBrightness = 3, LightRange = 20, Sparkles = 25, Beacon = true, Rainbow = true },
}

local EGG_SIZE = Vector3.new(3, 4, 3)
local FLOOR_Y = Config.Map.FloorY

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

-- ===== Sorteo de rareza y posición =====

local function rollRarity(): Rarity
	local total = 0
	for _, rarity in Config.Rarities do
		total += rarity.Weight
	end
	local roll = random:NextNumber(0, total)
	for _, rarity in Config.Rarities do
		roll -= rarity.Weight
		if roll <= 0 then
			return rarity
		end
	end
	return Config.Rarities[1]
end

-- Un punto al azar dentro del tramo del pasillo que le toca a esta rareza.
local function randomLandingPosition(rarity: Rarity): Vector3
	local map = Config.Map
	local halfWidth = map.CorridorWidth / 2 - map.EggSideMargin
	local x = random:NextNumber(-halfWidth, halfWidth)
	local z = random:NextNumber(rarity.ZoneStart, rarity.ZoneEnd) * map.CorridorLength
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

local function createEggPart(egg: { Id: number, Rarity: Rarity }): (BasePart, ProximityPrompt)
	local rarity = egg.Rarity
	local visual = VISUALS[rarity.Id] or VISUALS.Common

	local part = Instance.new("Part")
	part.Name = `{rarity.Id}Egg`
	part.Size = EGG_SIZE
	part.Color = rarity.Color
	part.Material = if rarity.Id == "Secret" then Enum.Material.Glass else Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part:SetAttribute("EggId", egg.Id)
	part:SetAttribute("Rarity", rarity.Id)

	-- Un SpecialMesh esférico estira la Part y le da forma de huevo.
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part

	local light = Instance.new("PointLight")
	light.Color = if visual.Rainbow then Color3.new(1, 1, 1) else rarity.Color
	light.Brightness = visual.LightBrightness
	light.Range = visual.LightRange
	light.Parent = part

	if visual.Sparkles > 0 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Color = if visual.Rainbow then RAINBOW else ColorSequence.new(rarity.Color)
		sparkles.LightEmission = 1
		sparkles.Rate = visual.Sparkles
		sparkles.Lifetime = NumberRange.new(0.8, 1.5)
		sparkles.Speed = NumberRange.new(1, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.4, 0)
		sparkles.Parent = part
	end

	-- Explosión de partículas al tocar el piso (Rate 0: solo sale cuando la disparamos con :Emit)
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "LandingBurst"
	burst.Color = if visual.Rainbow then RAINBOW else ColorSequence.new(rarity.Color)
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.4, 0.8)
	burst.Speed = NumberRange.new(10, 18)
	burst.SpreadAngle = Vector2.new(80, 80)
	burst.Size = NumberSequence.new(0.6, 0)
	burst.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = `{rarity.DisplayName} Egg`
	prompt.HoldDuration = Config.Eggs.GrabHoldTime
	prompt.MaxActivationDistance = Config.Eggs.GrabDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- se habilita cuando aterriza
	prompt.Parent = part

	return part, prompt
end

-- Círculo en el piso que avisa dónde va a caer el huevo.
local function createLandingMarker(position: Vector3, color: Color3): Part
	local marker = Instance.new("Part")
	marker.Name = "LandingMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.1, 6, 6)
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

local function addBeacon(egg: Egg)
	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(80, 1.5, 1.5)
	-- Cilindro parado: el eje X apunta para arriba
	beacon.CFrame = CFrame.new(egg.Part.Position + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Color = if egg.Rarity.Id == "Secret" then Color3.new(1, 1, 1) else egg.Rarity.Color
	beacon.Material = Enum.Material.Neon
	beacon.Transparency = 0.6
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanTouch = false
	beacon.CanQuery = false
	beacon.Parent = egg.Part
end

-- ===== Ciclo de vida =====

local function destroyEgg(egg: Egg)
	eggs[egg.Id] = nil
	if egg.Carrier then
		carriedByPlayer[egg.Carrier] = nil
		egg.Carrier:SetAttribute("CarriedEggRarity", nil)
		egg.Carrier = nil
	end
	egg.Part:Destroy()
end

local function onLanded(egg: Egg, marker: Part)
	marker:Destroy()
	if eggs[egg.Id] ~= egg or egg.State ~= "Falling" then
		return -- lo borró la ola mientras caía
	end
	egg.State = "Ground"
	egg.Prompt.Enabled = true

	local burst = egg.Part:FindFirstChild("LandingBurst")
	if burst and burst:IsA("ParticleEmitter") then
		burst:Emit(25)
	end
	if (VISUALS[egg.Rarity.Id] or VISUALS.Common).Beacon then
		addBeacon(egg)
	end
end

local function spawnEgg()
	if countEggsInWorld() >= Config.Eggs.MaxOnGround then
		return
	end

	nextEggId += 1
	local rarity = rollRarity()
	local part, prompt = createEggPart({ Id = nextEggId, Rarity = rarity })
	local egg: Egg = {
		Id = nextEggId,
		Rarity = rarity,
		Part = part,
		Prompt = prompt,
		State = "Falling",
		Carrier = nil,
	}
	eggs[egg.Id] = egg

	local landing = randomLandingPosition(rarity)
	local spin = CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	part.CFrame = CFrame.new(landing + Vector3.new(0, Config.Eggs.FallHeight, 0)) * spin
	part.Parent = eggsFolder
	local marker = createLandingMarker(landing, rarity.Color)

	prompt.Triggered:Connect(function(player)
		EggService.TryGrab(player, egg)
	end)

	-- Caída: acelera hacia el final (Quad In), como si fuera gravedad.
	local tween = TweenService:Create(
		part,
		TweenInfo.new(Config.Eggs.FallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(landing) * spin }
	)
	tween.Completed:Connect(function()
		onLanded(egg, marker)
	end)
	tween:Play()
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
	player:SetAttribute("CarriedEggRarity", egg.Rarity.Id) -- para que el cliente pueda mostrarlo
	notify(player, `You grabbed a {egg.Rarity.DisplayName} Egg! Bring it to your base.`)
end

function EggService.GetCarriedEgg(player: Player): Egg?
	return carriedByPlayer[player]
end

-- El jugador entrega el huevo que lleva (por ejemplo, a una incubadora). Devuelve su rareza.
function EggService.TakeCarriedEgg(player: Player): Rarity?
	local egg = carriedByPlayer[player]
	if not egg then
		return nil
	end
	local rarity = egg.Rarity
	destroyEgg(egg)
	return rarity
end

-- El jugador pierde el huevo que lleva (muerte, ola, salida del juego).
function EggService.LoseCarriedEgg(player: Player)
	local egg = carriedByPlayer[player]
	if egg then
		destroyEgg(egg)
	end
end

-- Borra los huevos que están en el piso o cayendo (lo va a usar la ola en la fase 5).
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

-- Prende/apaga la lluvia de huevos (el ciclo de tormenta de la fase 5 va a usar esto).
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

	task.spawn(function()
		while true do
			task.wait(Config.Eggs.SpawnInterval)
			if raining then
				spawnEgg()
			end
		end
	end)
end

return EggService

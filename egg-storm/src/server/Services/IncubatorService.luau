--!strict
-- IncubatorService: las incubadoras de cada base.
-- El jugador llega con un huevo, aprieta "Incubate", el huevo queda adentro con una cuenta regresiva
-- y al terminar se abre: sale una mascota que va a un pad libre de la base.
--
-- Cada huevo incubando es un objeto del servidor (IncubatingEgg) con su dueño, rareza y tiempo.
-- Así más adelante es fácil agregar el robo: alcanza con sacar el IncubatingEgg de una incubadora.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EggService = require(script.Parent.EggService)
local CreatureService = require(script.Parent.CreatureService)

type Base = BaseService.Base
type Rarity = Config.Rarity

export type IncubatingEgg = {
	Id: number,
	Owner: Player,
	Rarity: Rarity,
	TotalTime: number, -- segundos que tarda en total (con la mejora de velocidad aplicada)
	HatchAt: number, -- os.clock() en el que se abre
	Part: BasePart,
}

export type Incubator = {
	Owner: Player,
	Base: Base,
	Slot: number,
	Model: Model,
	Root: BasePart,
	Dome: BasePart,
	Prompt: ProximityPrompt,
	Title: TextLabel,
	Timer: TextLabel,
	Egg: IncubatingEgg?,
}

local IncubatorService = {}

local incubatorsByPlayer: { [Player]: { Incubator } } = {}
local lockedSignsByPlayer: { [Player]: { [number]: Instance } } = {}
local lastAttempt: { [Player]: number } = {}
local nextEggId = 0

local notifyRemote = Remotes.Event("Notify")
local hatchedRemote = Remotes.Event("Hatched")

local METAL = Color3.fromRGB(90, 95, 110)
local GLOW = Color3.fromRGB(255, 170, 60)

-- ===== Ayudantes visuales =====

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Parent = parent
	return p
end

-- Cilindro parado apoyado en "bottom"
local function makeDisc(name: string, height: number, diameter: number, bottom: Vector3, color: Color3, parent: Instance): Part
	local p = makePart(name, Vector3.new(height, diameter, diameter), CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function makeLabel(name: string, parent: Instance, y: number, height: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromScale(1, height)
	label.Position = UDim2.fromScale(0, y)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	return label
end

local function formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- ===== Armado de una incubadora =====

local function padTop(pad: BasePart): Vector3
	-- El pad es un cilindro acostado: su grosor es Size.X
	return pad.Position + Vector3.new(0, pad.Size.X / 2, 0)
end

local function buildIncubator(player: Player, base: Base, slot: number): Incubator
	local pad = base.IncubatorSlots[slot]
	local bottom = padTop(pad)

	local model = Instance.new("Model")
	model.Name = `Incubator{slot}`

	local root = makeDisc("Base", 1.6, 8, bottom, METAL, model)
	local ring = makeDisc("Ring", 0.4, 8.4, bottom + Vector3.new(0, 1.6, 0), GLOW, model)
	ring.Material = Enum.Material.Neon
	local dome = makePart("Dome", Vector3.new(6.5, 6.5, 6.5), CFrame.new(bottom + Vector3.new(0, 4.6, 0)), Color3.fromRGB(200, 240, 255), model)
	dome.Shape = Enum.PartType.Ball
	dome.Material = Enum.Material.Glass
	dome.Transparency = 0.6
	dome.CanCollide = false
	model.PrimaryPart = root

	local gui = Instance.new("BillboardGui")
	gui.Name = "Display"
	gui.Size = UDim2.fromScale(7, 2.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.2, 0)
	gui.MaxDistance = 80
	gui.Parent = dome
	local title = makeLabel("Title", gui, 0, 0.5, Color3.new(1, 1, 1))
	local timer = makeLabel("Timer", gui, 0.5, 0.5, Color3.fromRGB(255, 230, 120))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Incubate"
	prompt.ObjectText = "Incubator"
	prompt.HoldDuration = Config.Incubators.HoldTime
	prompt.MaxActivationDistance = Config.Incubators.Distance
	prompt.RequiresLineOfSight = false
	-- El cliente muestra este prompt solo en su propia base y solo si lleva un huevo (ver IncubatorPrompts).
	prompt:SetAttribute("BaseId", base.Id)
	prompt:SetAttribute("Available", true)
	CollectionService:AddTag(prompt, "IncubatorPrompt")
	prompt.Parent = root

	model.Parent = base.Model

	local incubator: Incubator = {
		Owner = player,
		Base = base,
		Slot = slot,
		Model = model,
		Root = root,
		Dome = dome,
		Prompt = prompt,
		Title = title,
		Timer = timer,
		Egg = nil,
	}
	prompt.Triggered:Connect(function(who)
		IncubatorService.TryIncubate(who, incubator)
	end)
	return incubator
end

local function showEmpty(incubator: Incubator)
	incubator.Title.Text = "Empty"
	incubator.Title.TextColor3 = Color3.new(1, 1, 1)
	incubator.Timer.Text = "Bring an egg!"
	incubator.Prompt:SetAttribute("Available", true)
end

-- Cartel "LOCKED" sobre los pads de incubadoras que todavía no se compraron (fase 4).
local function addLockedSign(player: Player, base: Base, slot: number)
	local pad = base.IncubatorSlots[slot]
	local holder = Instance.new("Part")
	holder.Name = `LockedSlot{slot}`
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(padTop(pad) + Vector3.new(0, 3, 0))
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 1.5)
	gui.MaxDistance = 60
	gui.Parent = holder
	local label = makeLabel("Locked", gui, 0, 1, Color3.fromRGB(200, 200, 200))
	label.Text = "LOCKED"

	holder.Parent = base.Model
	local signs = lockedSignsByPlayer[player]
	if not signs then
		signs = {}
		lockedSignsByPlayer[player] = signs
	end
	signs[slot] = holder
end

-- ===== Huevos dentro de la incubadora =====

local function getIncubators(player: Player): { Incubator }
	return incubatorsByPlayer[player] or {}
end

local function countIncubating(player: Player): number
	local count = 0
	for _, incubator in getIncubators(player) do
		if incubator.Egg then
			count += 1
		end
	end
	return count
end

local function speedLevel(player: Player): number
	local profile = PlayerDataService.Get(player)
	return if profile then profile.IncubationSpeedLevel else 1
end

local function startIncubation(incubator: Incubator, rarity: Rarity, remaining: number?)
	local total = Config.GetIncubationTime(rarity, speedLevel(incubator.Owner))
	local left = math.clamp(remaining or total, 0, total)

	local eggPart = makePart("Egg", Vector3.new(2.4, 3.2, 2.4), CFrame.new(incubator.Dome.Position), rarity.Color, incubator.Model)
	eggPart.CanCollide = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = eggPart
	local light = Instance.new("PointLight")
	light.Color = if rarity.Id == "Secret" then Color3.new(1, 1, 1) else rarity.Color
	light.Range = 8
	light.Parent = eggPart

	nextEggId += 1
	incubator.Egg = {
		Id = nextEggId,
		Owner = incubator.Owner,
		Rarity = rarity,
		TotalTime = total,
		HatchAt = os.clock() + left,
		Part = eggPart :: BasePart,
	}
	incubator.Title.Text = `{rarity.DisplayName} Egg`
	incubator.Title.TextColor3 = if rarity.Id == "Secret" then Color3.fromRGB(230, 230, 230) else rarity.Color
	incubator.Timer.Text = formatTime(left)
	incubator.Prompt:SetAttribute("Available", false)
end

local function burst(position: Vector3, color: Color3, parent: Instance)
	local holder = Instance.new("Part")
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(position)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(12, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Parent = holder
	holder.Parent = parent
	emitter:Emit(40)
	task.delay(1.5, function()
		holder:Destroy()
	end)
end

local function hatch(incubator: Incubator)
	local egg = incubator.Egg
	if not egg then
		return
	end
	local player = incubator.Owner

	local creature = CreatureService.RollCreature(egg.Rarity.Id)
	if not creature then
		warn(`[IncubatorService] No creatures defined for rarity {egg.Rarity.Id}`)
		return
	end
	local slot = CreatureService.AddCreature(player, creature)
	if not slot then
		-- No hay lugar para la mascota: el huevo espera y reintenta en un rato
		egg.HatchAt = os.clock() + 2
		incubator.Timer.Text = "No room!"
		return
	end

	burst(egg.Part.Position, egg.Rarity.Color, incubator.Model)
	egg.Part:Destroy()
	incubator.Egg = nil
	showEmpty(incubator)

	-- Aviso al dueño (en la fase 6 esto dispara la animación de apertura)
	hatchedRemote:FireClient(player, creature.DisplayName, egg.Rarity.Id)
end

-- ===== API pública =====

-- Lo llama el ProximityPrompt "Incubate". Valida TODO en el servidor.
function IncubatorService.TryIncubate(player: Player, incubator: Incubator)
	local now = os.clock()
	if now - (lastAttempt[player] or 0) < Config.Incubators.Cooldown then
		return
	end
	lastAttempt[player] = now

	if incubator.Owner ~= player then
		notifyRemote:FireClient(player, "This isn't your base!")
		return
	end
	if incubator.Egg then
		return
	end
	if not EggService.GetCarriedEgg(player) then
		notifyRemote:FireClient(player, "Grab an egg first!")
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - incubator.Root.Position).Magnitude > Config.Incubators.Distance + 5 then
		return
	end

	-- Cada huevo necesita un pad libre para su mascota (contando los que ya se están incubando)
	if CreatureService.GetFreeSlotCount(player) - countIncubating(player) <= 0 then
		notifyRemote:FireClient(player, "Your creature spots are full!")
		return
	end

	local rarity = EggService.TakeCarriedEgg(player)
	if not rarity then
		return
	end
	startIncubation(incubator, rarity)
end

-- Cuando el jugador recibe su base: arma sus incubadoras y restaura los huevos que tenía.
function IncubatorService.SetupBase(player: Player, base: Base)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	local maxSlots = math.min(Config.Upgrades.MaxIncubators, #base.IncubatorSlots)
	local owned = math.clamp(profile.IncubatorCount, 1, maxSlots)

	local list: { Incubator } = {}
	incubatorsByPlayer[player] = list
	for slot = 1, owned do
		local incubator = buildIncubator(player, base, slot)
		showEmpty(incubator)
		table.insert(list, incubator)
	end
	for slot = owned + 1, maxSlots do
		addLockedSign(player, base, slot)
	end

	-- Huevos que estaban incubando cuando se fue (fase 7)
	for _, data in profile.Incubating do
		local incubator = list[data.Slot]
		local rarity = Config.GetRarity(data.RarityId)
		if incubator and rarity and not incubator.Egg then
			startIncubation(incubator, rarity, data.Remaining)
		end
	end
	profile.Incubating = {}
end

-- Foto de los huevos que se están incubando, para guardarla (fase 7).
function IncubatorService.GetSnapshot(player: Player): { PlayerDataService.IncubatingData }
	local snapshot = {}
	local now = os.clock()
	for _, incubator in getIncubators(player) do
		local egg = incubator.Egg
		if egg then
			table.insert(snapshot, { Slot = incubator.Slot, RarityId = egg.Rarity.Id, Remaining = math.max(0, egg.HatchAt - now) })
		end
	end
	return snapshot
end

-- Cuando el jugador se va: guarda los huevos en su perfil y limpia la base.
function IncubatorService.ClearBase(player: Player)
	local profile = PlayerDataService.Get(player)
	if profile then
		profile.Incubating = IncubatorService.GetSnapshot(player)
	end
	for _, incubator in getIncubators(player) do
		incubator.Model:Destroy()
	end
	local signs = lockedSignsByPlayer[player]
	if signs then
		for _, sign in signs do
			sign:Destroy()
		end
	end
	incubatorsByPlayer[player] = nil
	lockedSignsByPlayer[player] = nil
	lastAttempt[player] = nil
end

-- Suma una incubadora (la compra la hace la fase 4). Devuelve true si se pudo.
function IncubatorService.AddIncubator(player: Player): boolean
	local base = BaseService.GetBase(player)
	local profile = PlayerDataService.Get(player)
	local list = incubatorsByPlayer[player]
	if not base or not profile or not list then
		return false
	end
	local slot = #list + 1
	if slot > math.min(Config.Upgrades.MaxIncubators, #base.IncubatorSlots) then
		return false
	end
	local signs = lockedSignsByPlayer[player]
	if signs and signs[slot] then
		signs[slot]:Destroy()
		signs[slot] = nil
	end
	local incubator = buildIncubator(player, base, slot)
	showEmpty(incubator)
	table.insert(list, incubator)
	profile.IncubatorCount = #list
	return true
end

-- Recalcula los tiempos cuando cambia el nivel de "Incubation Speed" (fase 4).
-- Se conserva el progreso: si iba por la mitad, sigue por la mitad del tiempo nuevo.
function IncubatorService.RecalculateTimes(player: Player)
	local now = os.clock()
	for _, incubator in getIncubators(player) do
		local egg = incubator.Egg
		if egg then
			local progress = 1 - math.max(0, egg.HatchAt - now) / egg.TotalTime
			local newTotal = Config.GetIncubationTime(egg.Rarity, speedLevel(player))
			egg.TotalTime = newTotal
			egg.HatchAt = now + newTotal * (1 - progress)
		end
	end
end

function IncubatorService.Init()
	-- Reloj de las incubadoras: actualiza las cuentas regresivas y abre los huevos que terminaron.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, list in incubatorsByPlayer do
				for _, incubator in list do
					local egg = incubator.Egg
					if egg then
						local remaining = egg.HatchAt - now
						if remaining <= 0 then
							hatch(incubator)
						else
							incubator.Timer.Text = formatTime(remaining)
						end
					end
				end
			end
		end
	end)
end

return IncubatorService

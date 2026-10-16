--!strict
-- IncubatorService: los 3 nidos-incubadora que hay ADELANTE de cada base.
--   Empty      → "EMPTY". Si llevás un huevo, aparece "Place Egg".
--   Incubating → el huevo está en el nido, con la luz y las chispitas de su rareza y la cuenta regresiva.
--   Ready      → el huevo se agrieta, dice "READY!" y aparece "Open". Al abrirlo sale la mascota
--                y va al primer estante libre de la torre.
-- Los nidos que todavía no compraste (mejora "Extra Incubator") dicen LOCKED.
-- Solo el dueño de la base puede usar sus incubadoras.
--
-- Cada huevo incubando es un objeto del servidor (IncubatingEgg) con su dueño, rareza, variante y tiempo.
-- Así más adelante es fácil agregar el robo: alcanza con sacar el IncubatingEgg de una incubadora.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EggService = require(script.Parent.EggService)
local CreatureService = require(script.Parent.CreatureService)
local TutorialService = require(script.Parent.TutorialService)
local Creatures = require(ReplicatedStorage.Shared.Creatures)

type Base = BaseService.Base
type Rarity = Config.Rarity
type Variant = Config.Variant

export type IncubatorState = "Empty" | "Incubating" | "Ready" | "Hatching"

export type IncubatingEgg = {
	Id: number,
	Owner: Player,
	Rarity: Rarity,
	Variant: Variant,
	TotalTime: number, -- segundos que tarda en total (con la mejora de velocidad aplicada)
	HatchAt: number, -- os.clock() en el que queda listo
	Part: BasePart,
}

export type Incubator = {
	Owner: Player,
	Base: Base,
	Slot: number,
	Pedestal: BasePart,
	EggSlot: Attachment, -- donde se apoya el huevo
	Light: PointLight,
	Sparkles: ParticleEmitter,
	Prompt: ProximityPrompt,
	Board: Frame, -- cartelito de arriba (cambia de color según el estado)
	Label: TextLabel,
	Parts: { Instance }, -- todo lo que agregamos al nido (se borra cuando el dueño se va)
	State: IncubatorState,
	Egg: IncubatingEgg?,
}

local IncubatorService = {}

local incubatorsByPlayer: { [Player]: { Incubator } } = {}
local lockedSignsByPlayer: { [Player]: { [number]: Instance } } = {}
local lastAttempt: { [Player]: number } = {}
local nextEggId = 0

local notifyRemote = Remotes.Event("Notify")
local hatchedRemote = Remotes.Event("Hatched")

local EGG_SIZE = Vector3.new(2.4, 3.2, 2.4)
local EGG_HEIGHT = 3.5 -- el huevo va 3.5 studs arriba del centro del pedestal (sobre el nido)
local BOARD_COLORS: { [string]: Color3 } = {
	Empty = Color3.fromRGB(90, 90, 95),
	Incubating = Color3.fromRGB(10, 31, 77),
	Ready = Color3.fromRGB(201, 138, 0),
	Hatching = Color3.fromRGB(201, 138, 0),
}
local FULL_MESSAGE = "Your shelves are full! Sell a creature (hold E on it) to make room."

-- ===== Ayudantes visuales =====

local function formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", s // 60, s % 60)
end

local function setBoard(incubator: Incubator, text: string)
	incubator.Board.BackgroundColor3 = BOARD_COLORS[incubator.State] or BOARD_COLORS.Empty
	incubator.Label.Text = text
end

local function setState(incubator: Incubator, state: IncubatorState)
	incubator.State = state
	incubator.Prompt:SetAttribute("State", state) -- el cliente decide si mostrar el botón (IncubatorPrompts)
	incubator.Prompt.ActionText = if state == "Ready" then "Open" else "Place Egg"
	local egg = incubator.Egg
	local color = if egg then (if egg.Rarity.Id == "Secret" then Color3.new(1, 1, 1) else egg.Part.Color) else Color3.new(1, 1, 1)
	incubator.Light.Enabled = state ~= "Empty"
	incubator.Light.Color = color
	incubator.Sparkles.Enabled = state == "Incubating"
	incubator.Sparkles.Color = ColorSequence.new(color)
end

-- Cartelito flotante con fondo de color (BillboardGui)
local function makeBoard(adornee: Attachment, parent: Instance): (BillboardGui, Frame, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "TimerGui"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(6, 2)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 90
	gui.Parent = parent
	local board = Instance.new("Frame")
	board.Size = UDim2.fromScale(1, 1)
	board.BackgroundColor3 = BOARD_COLORS.Empty
	board.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = board
	return gui, board, label
end

-- ===== Armado de una incubadora (sobre el nido que armó MapBuilder) =====

local function buildIncubator(player: Player, base: Base, slot: number): Incubator
	local pedestal = base.IncubatorSlots[slot]
	local parts: { Instance } = {}

	local eggSlot = Instance.new("Attachment")
	eggSlot.Name = "EggSlot"
	eggSlot.Position = Vector3.new(0, EGG_HEIGHT, 0)
	eggSlot.Parent = pedestal
	table.insert(parts, eggSlot)

	local light = Instance.new("PointLight")
	light.Name = "GlowLight"
	light.Range = 10
	light.Brightness = 2
	light.Enabled = false
	light.Parent = pedestal
	table.insert(parts, light)

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Rate = 5
	sparkles.LightEmission = 1
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.3, 0)
	sparkles.Enabled = false
	sparkles.Parent = eggSlot

	local gui, board, label = makeBoard(eggSlot, pedestal)
	table.insert(parts, gui)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Place Egg"
	prompt.ObjectText = "Incubator"
	prompt.HoldDuration = Config.Incubators.HoldTime
	prompt.MaxActivationDistance = Config.Incubators.Distance
	prompt.RequiresLineOfSight = false
	-- El cliente muestra este botón solo en su propia base y cuando sirve (ver IncubatorPrompts).
	prompt:SetAttribute("BaseId", base.Id)
	CollectionService:AddTag(prompt, "IncubatorPrompt")
	prompt.Parent = pedestal
	table.insert(parts, prompt)

	local incubator: Incubator = {
		Owner = player,
		Base = base,
		Slot = slot,
		Pedestal = pedestal,
		EggSlot = eggSlot,
		Light = light,
		Sparkles = sparkles,
		Prompt = prompt,
		Board = board,
		Label = label,
		Parts = parts,
		State = "Empty",
		Egg = nil,
	}
	prompt.Triggered:Connect(function(who)
		if incubator.State == "Ready" then
			IncubatorService.TryOpen(who, incubator)
		else
			IncubatorService.TryIncubate(who, incubator)
		end
	end)
	return incubator
end

local function showEmpty(incubator: Incubator)
	incubator.Egg = nil
	setState(incubator, "Empty")
	setBoard(incubator, "EMPTY")
end

-- Cartel "LOCKED" sobre los nidos que todavía no se compraron.
local function addLockedSign(player: Player, base: Base, slot: number)
	local pedestal = base.IncubatorSlots[slot]
	local gui = Instance.new("BillboardGui")
	gui.Name = "LockedGui"
	gui.Size = UDim2.fromScale(6, 1.6)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 70
	gui.Parent = pedestal
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(210, 210, 210)
	label.Text = "🔒 LOCKED"
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label

	local signs = lockedSignsByPlayer[player]
	if not signs then
		signs = {}
		lockedSignsByPlayer[player] = signs
	end
	signs[slot] = gui
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

-- El huevo se agrieta: unas rayitas oscuras sobre la cáscara
local function crackEgg(egg: IncubatingEgg)
	for i, offset in { Vector3.new(0, 0.4, -1.15), Vector3.new(0.5, -0.1, -1.1), Vector3.new(-0.4, 0.8, -1.05) } do
		local crack = Instance.new("Part")
		crack.Name = "Crack"
		crack.Size = Vector3.new(0.15, 0.9, 0.1)
		crack.CFrame = egg.Part.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 35 else -35))
		crack.Color = Color3.fromRGB(40, 30, 25)
		crack.Material = Enum.Material.SmoothPlastic
		crack.Anchored = true
		crack.CanCollide = false
		crack.CanQuery = false
		crack.CanTouch = false
		crack.Parent = egg.Part
	end
end

local function setReady(incubator: Incubator)
	local egg = incubator.Egg
	if not egg then
		return
	end
	setState(incubator, "Ready")
	setBoard(incubator, "READY!")
	crackEgg(egg)
end

local function startIncubation(incubator: Incubator, rarity: Rarity, variant: Variant, remaining: number?)
	local total = Config.GetIncubationTime(rarity, speedLevel(incubator.Owner))
	local left = math.clamp(remaining or total, 0, total)

	local eggPart = Instance.new("Part")
	eggPart.Name = "Egg"
	eggPart.Size = EGG_SIZE
	eggPart.CFrame = CFrame.new(incubator.EggSlot.WorldPosition)
	eggPart.Anchored = true
	eggPart.CanCollide = false
	eggPart.CanQuery = false
	EggService.DecorateEgg(eggPart, rarity, variant) -- mismo color, material y brillo que en el cañón
	eggPart.Parent = incubator.Pedestal.Parent

	nextEggId += 1
	incubator.Egg = {
		Id = nextEggId,
		Owner = incubator.Owner,
		Rarity = rarity,
		Variant = variant,
		TotalTime = total,
		HatchAt = os.clock() + left,
		Part = eggPart :: BasePart,
	}
	setState(incubator, "Incubating")
	setBoard(incubator, formatTime(left))
	if left <= 0 then
		setReady(incubator)
	end
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
	-- Confeti del color de la rareza
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.5
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(14, 24)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Size = NumberSequence.new(0.6, 0.3)
	emitter.Parent = holder
	holder.Parent = parent
	emitter:Emit(60)
	task.delay(2, function()
		holder:Destroy()
	end)
end

-- Final de la apertura: sale la mascota y la incubadora queda libre.
local function finishHatch(incubator: Incubator, egg: IncubatingEgg, creature: Creatures.Creature)
	-- Si el dueño se fue durante la animación, no hacemos nada (el huevo quedó guardado en su perfil)
	if incubator.Egg ~= egg or not table.find(getIncubators(incubator.Owner), incubator) then
		return
	end
	local slot = CreatureService.AddCreature(incubator.Owner, creature, egg.Variant)
	if not slot then
		-- Se llenó mientras se abría: el huevo vuelve a quedar listo
		setReady(incubator)
		notifyRemote:FireClient(incubator.Owner, FULL_MESSAGE)
		return
	end
	burst(egg.Part.Position, egg.Part.Color, incubator.Pedestal.Parent :: Instance)
	egg.Part:Destroy()
	showEmpty(incubator)
	PlayerDataService.RecordHatch(incubator.Owner)
	TutorialService.OnEvent(incubator.Owner, "Hatched")
end

-- ===== API pública =====

local function canUse(player: Player, incubator: Incubator): boolean
	local now = os.clock()
	if now - (lastAttempt[player] or 0) < Config.Incubators.Cooldown then
		return false
	end
	lastAttempt[player] = now
	if incubator.Owner ~= player then
		notifyRemote:FireClient(player, "This isn't your base!")
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - incubator.Pedestal.Position).Magnitude <= Config.Incubators.Distance + 5
end

-- "Place Egg": pone el huevo que llevás en el nido. Valida TODO en el servidor.
function IncubatorService.TryIncubate(player: Player, incubator: Incubator)
	if not canUse(player, incubator) or incubator.State ~= "Empty" then
		return
	end
	if not EggService.GetCarriedEgg(player) then
		notifyRemote:FireClient(player, "Grab an egg in the canyon first!")
		return
	end
	-- Cada huevo necesita un estante libre para su mascota (contando los que ya se están incubando)
	if CreatureService.GetFreeSlotCount(player) - countIncubating(player) <= 0 then
		notifyRemote:FireClient(player, FULL_MESSAGE)
		return
	end
	local rarity, variant = EggService.TakeCarriedEgg(player)
	if not rarity or not variant then
		return
	end
	startIncubation(incubator, rarity, variant)
	TutorialService.OnEvent(player, "Incubated")
end

-- Pone un huevo directamente en el primer nido libre (por ejemplo, uno comprado al Comerciante).
-- Devuelve true si se pudo; si no, false y el motivo (en inglés, para mostrárselo al jugador).
function IncubatorService.CanPlaceEgg(player: Player): (boolean, string?)
	local free = false
	for _, incubator in getIncubators(player) do
		if incubator.State == "Empty" then
			free = true
			break
		end
	end
	if not free then
		return false, "You need an empty incubator in your base!"
	end
	if CreatureService.GetFreeSlotCount(player) - countIncubating(player) <= 0 then
		return false, FULL_MESSAGE
	end
	return true, nil
end

function IncubatorService.PlaceEgg(player: Player, rarity: Rarity, variant: Variant): (boolean, string?)
	local ok, reason = IncubatorService.CanPlaceEgg(player)
	if not ok then
		return false, reason
	end
	for _, incubator in getIncubators(player) do
		if incubator.State == "Empty" then
			startIncubation(incubator, rarity, variant)
			return true, nil
		end
	end
	return false, "You need an empty incubator in your base!"
end

-- "Open": abre un huevo listo. La pantalla del dueño hace temblar y explotar el huevo,
-- y unos segundos después sale la mascota (así no aparece antes de la animación).
function IncubatorService.TryOpen(player: Player, incubator: Incubator)
	if not canUse(player, incubator) or incubator.State ~= "Ready" then
		return
	end
	local egg = incubator.Egg
	if not egg then
		return
	end
	if CreatureService.GetFreeSlotCount(player) <= 0 then
		notifyRemote:FireClient(player, FULL_MESSAGE)
		return
	end
	local creature = CreatureService.RollCreature(egg.Rarity.Id)
	if not creature then
		warn(`[IncubatorService] No creatures defined for rarity {egg.Rarity.Id}`)
		return
	end
	setState(incubator, "Hatching")
	setBoard(incubator, "OPENING!")
	hatchedRemote:FireClient(player, creature.DisplayName, egg.Rarity.Id, egg.Part, egg.Variant.Id)
	task.delay(Config.Effects.HatchAnimationTime, finishHatch, incubator, egg, creature)
end

-- Cuando el jugador recibe su base: prepara sus nidos y restaura los huevos que tenía.
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

	-- Huevos que estaban incubando cuando se fue (el tiempo no corre mientras no estás)
	for _, data in profile.Incubating do
		local incubator = list[data.Slot]
		local rarity = Config.GetRarity(data.RarityId)
		if incubator and rarity and not incubator.Egg then
			startIncubation(incubator, rarity, Config.GetVariant(data.Variant), data.Remaining)
		end
	end
	profile.Incubating = {}
end

-- Foto de los huevos de las incubadoras, para guardarla (los listos se guardan con 0 segundos).
function IncubatorService.GetSnapshot(player: Player): { PlayerDataService.IncubatingData }
	local snapshot = {}
	local now = os.clock()
	for _, incubator in getIncubators(player) do
		local egg = incubator.Egg
		if egg then
			table.insert(snapshot, {
				Slot = incubator.Slot,
				RarityId = egg.Rarity.Id,
				Variant = egg.Variant.Id,
				Remaining = if incubator.State == "Incubating" then math.max(0, egg.HatchAt - now) else 0,
			})
		end
	end
	return snapshot
end

-- El estado de un nido (para el cliente del tutorial y las pruebas)
function IncubatorService.GetIncubators(player: Player): { Incubator }
	return getIncubators(player)
end

-- Cuando el jugador se va: guarda los huevos en su perfil y deja los nidos vacíos.
function IncubatorService.ClearBase(player: Player)
	local profile = PlayerDataService.Get(player)
	if profile then
		profile.Incubating = IncubatorService.GetSnapshot(player)
	end
	for _, incubator in getIncubators(player) do
		if incubator.Egg then
			incubator.Egg.Part:Destroy()
		end
		for _, instance in incubator.Parts do
			instance:Destroy()
		end
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

-- Suma una incubadora (mejora "Extra Incubator"). Devuelve true si se pudo.
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

-- Recalcula los tiempos cuando cambia el nivel de "Incubation Speed".
-- Se conserva el progreso: si iba por la mitad, sigue por la mitad del tiempo nuevo.
function IncubatorService.RecalculateTimes(player: Player)
	local now = os.clock()
	for _, incubator in getIncubators(player) do
		local egg = incubator.Egg
		if egg and incubator.State == "Incubating" then
			local progress = 1 - math.max(0, egg.HatchAt - now) / egg.TotalTime
			local newTotal = Config.GetIncubationTime(egg.Rarity, speedLevel(player))
			egg.TotalTime = newTotal
			egg.HatchAt = now + newTotal * (1 - progress)
		end
	end
end

function IncubatorService.Init()
	-- Reloj de las incubadoras: actualiza las cuentas regresivas y marca los huevos que terminaron.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, list in incubatorsByPlayer do
				for _, incubator in list do
					local egg = incubator.Egg
					if egg and incubator.State == "Incubating" then
						local remaining = egg.HatchAt - now
						if remaining <= 0 then
							setReady(incubator)
						else
							setBoard(incubator, formatTime(remaining))
						end
					end
				end
			end
		end
	end)
end

return IncubatorService

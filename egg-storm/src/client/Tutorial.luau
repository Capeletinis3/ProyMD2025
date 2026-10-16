--!strict
-- Tutorial: el cartel de arriba con el paso actual (STEP 1/4, título, qué hacer, distancia o tiempo, "Skip tutorial"),
-- una flecha de luz desde tu personaje hasta el objetivo, y el cartel "STEP COMPLETE! +100 coins" al terminar cada paso.
-- El paso lo decide el servidor (atributo "TutorialStep", ver TutorialService). Este módulo solo lo dibuja.
-- Si viene la ola y estás en el cañón, el tutorial te lleva a la cueva-refugio más cercana.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local actionRemote = Remotes.Event("TutorialAction")
local C = UIKit.Colors

local Tutorial = {}

-- Mismos números que TutorialService.Steps
local GRAB_EGG, RUN_BACK, HATCH_IT, GET_RICH, DONE = 1, 2, 3, 4, 5
local STEP_COUNT = 4
local WIDTH, HEIGHT = 600, 96
local STUDS_TO_METERS = 0.28
local HIGHLIGHT = "#FFC828"

type Goal = {
	Step: number,
	Icon: string,
	Color: Color3,
	Title: string,
	Text: string, -- con <font> para resaltar (RichText)
	Target: Vector3?,
	Metric: string?, -- "distance", "wave" o "coins"
}

local STEP_COLORS = {
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(170, 100, 255),
	Color3.fromRGB(80, 200, 90),
}

local banner: Frame
local iconLabel: TextLabel
local stepPill: TextLabel
local dashes: { Frame } = {}
local titleLabel: TextLabel
local textLabel: TextLabel
local metricLabel: TextLabel
local toast: TextLabel
local toastUntil = 0
local beam: Beam
local targetAttachment: Attachment
local marker: Part
local markerGui: BillboardGui
local lastSearch = 0
local cachedEgg: BasePart? = nil
local caveSpots: { Vector3 }? = nil

local function hl(text: string): string
	return `<font color="{HIGHLIGHT}">{text}</font>`
end

local function step(): number
	local value = player:GetAttribute("TutorialStep")
	return if typeof(value) == "number" then value else DONE
end

local function myBase(): Model?
	local baseId = player:GetAttribute("BaseId")
	local map = Workspace:FindFirstChild("Map")
	local bases = map and map:FindFirstChild("Bases")
	local base = bases and bases:FindFirstChild(`Base{baseId}`)
	return if base and base:IsA("Model") then base else nil
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- El huevo del piso más cercano (se busca cada medio segundo, no en cada frame)
local function nearestEgg(from: Vector3): BasePart?
	if os.clock() - lastSearch < 0.5 and cachedEgg and cachedEgg.Parent then
		return cachedEgg
	end
	lastSearch = os.clock()
	cachedEgg = nil
	local eggs = Workspace:FindFirstChild("Eggs")
	if not eggs then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, child in eggs:GetChildren() do
		local prompt = child:FindFirstChildOfClass("ProximityPrompt")
		if child:IsA("BasePart") and prompt and prompt.Enabled then
			local distance = (child.Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = child, distance
			end
		end
	end
	cachedEgg = best
	return best
end

local function findPart(root: Instance?, path: { string }): BasePart?
	local current: Instance? = root
	for _, name in path do
		current = current and current:FindFirstChild(name)
	end
	return if current and current:IsA("BasePart") then current else nil
end

-- El primer nido vacío de tu base (o el primero, si están todos ocupados)
local function freeNest(base: Model?): BasePart?
	local first: BasePart? = nil
	for i = 1, Config.Upgrades.MaxIncubators do
		local pedestal = findPart(base, { "IncubatorSlots", `Nest{i}`, "Pedestal" })
		if pedestal then
			first = first or pedestal
			local prompt = pedestal:FindFirstChildOfClass("ProximityPrompt")
			if prompt and prompt:GetAttribute("State") == "Empty" then
				return pedestal
			end
		end
	end
	return first
end

-- La cueva-refugio más cercana (las comunes; la VIP no, porque no todos pueden entrar)
local function nearestCave(from: Vector3): Vector3?
	if not caveSpots then
		local found: { Vector3 } = {}
		local map = Workspace:FindFirstChild("Map")
		local canyon = map and map:FindFirstChild("Canyon")
		local caves = canyon and canyon:FindFirstChild("Caves")
		if caves then
			for _, cave in caves:GetChildren() do
				local zone = cave:FindFirstChild("SafeZone")
				if zone and zone:IsA("BasePart") and not cave:GetAttribute("Vip") then
					table.insert(found, zone.Position)
				end
			end
		end
		if #found == 0 then
			return nil
		end
		caveSpots = found
	end
	local best: Vector3? = nil
	local bestDistance = math.huge
	local spots: { Vector3 } = caveSpots or {}
	for _, spot in spots do
		local distance = (spot - from).Magnitude
		if distance < bestDistance then
			best, bestDistance = spot, distance
		end
	end
	return best
end

-- La mejora más barata que podés comprar ahora
local function cheapestUpgrade(): number?
	local function level(name: string, default: number): number
		local value = player:GetAttribute(name)
		return if typeof(value) == "number" then value else default
	end
	local state: Upgrades.State = {
		IncubationSpeedLevel = level("IncubationSpeedLevel", 1),
		IncubatorCount = level("IncubatorCount", Config.Upgrades.StartingIncubators),
		WalkSpeedLevel = level("WalkSpeedLevel", 1),
		LuckLevel = level("LuckLevel", 1),
		CarryLevel = level("CarryLevel", 1),
	}
	local best: number? = nil
	for _, id in Upgrades.Order do
		local cost = Upgrades.GetNextCost(id, state)
		if cost and (not best or cost < best) then
			best = cost
		end
	end
	return best
end

-- Qué mostrar ahora
local function currentGoal(root: BasePart): Goal?
	local s = step()
	if s >= DONE then
		return nil
	end
	local inCanyon = root.Position.X > Config.Map.CanyonStartX
	local portal = Vector3.new(Config.Map.CanyonStartX, 3, 0)

	-- Si viene la ola y estás en el cañón: ¡a una cueva!
	local phase = Workspace:GetAttribute("WavePhase")
	if (phase == "Warning" or phase == "Wave") and inCanyon then
		return { Step = s, Icon = "🌊", Color = C.Red, Title = "HIDE IN A CAVE!", Text = `The {hl("wave")} is coming! Get inside a cave`, Target = nearestCave(root.Position), Metric = "wave" }
	end

	local carrying = player:GetAttribute("CarriedEggRarity") ~= nil
	if s == GRAB_EGG or (s == RUN_BACK and not carrying) then
		local egg = if inCanyon then nearestEgg(root.Position) else nil
		local target = if egg then egg.Position else portal
		if s == RUN_BACK then
			return { Step = s, Icon = "🥚", Color = STEP_COLORS[1], Title = "GRAB ANOTHER EGG!", Text = `You lost it! Go back into the {hl("canyon")}`, Target = target, Metric = "distance" }
		end
		return { Step = s, Icon = "🥚", Color = STEP_COLORS[1], Title = "GRAB AN EGG!", Text = `Go through the {hl("tiki portal")} into the canyon`, Target = target, Metric = "distance" }
	elseif s == RUN_BACK then
		local nest = freeNest(myBase())
		local target = if inCanyon or not nest then portal else nest.Position
		return { Step = s, Icon = "🏃", Color = STEP_COLORS[2], Title = "RUN BACK!", Text = `Hide in a {hl("cave")} if the wave comes`, Target = target, Metric = "wave" }
	elseif s == HATCH_IT then
		local nest = freeNest(myBase())
		return { Step = s, Icon = "🐣", Color = STEP_COLORS[3], Title = "HATCH IT!", Text = `Put the egg in one of your {hl("3 nests")}`, Target = if carrying and nest then nest.Position elseif carrying then nil else portal, Metric = "distance" }
	elseif s == GET_RICH then
		local map = Workspace:FindFirstChild("Map")
		local shop = findPart(map and map:FindFirstChild("Stalls", true), { "UpgradeShop", "Counter" })
		return { Step = s, Icon = "💰", Color = STEP_COLORS[4], Title = "GET RICH!", Text = `Buy your first upgrade at the {hl("shop")}`, Target = if shop then shop.Position else nil, Metric = "coins" }
	end
	return nil
end

local function metricText(goal: Goal, root: BasePart): string
	if goal.Metric == "wave" then
		local endsAt = Workspace:GetAttribute("PhaseEndsAt")
		local left = if typeof(endsAt) == "number" then math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow())) else 0
		return string.format("⏱ %02d:%02d", left // 60, left % 60)
	elseif goal.Metric == "coins" then
		local cost = cheapestUpgrade()
		return if cost then `💰 {Format.Number(cost)}` else "💰"
	end
	local target = goal.Target
	if not target then
		return ""
	end
	return `➜ {math.floor((target - root.Position).Magnitude * STUDS_TO_METERS)}m`
end

-- ===== Armado =====

local function buildBanner()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 20, 0, 114) -- abajo del cartel de la ola
	banner.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	banner.BackgroundColor3 = Color3.fromRGB(24, 30, 58)
	banner.Visible = false
	banner.Parent = gui
	UIKit.Corner(banner, 20)
	UIKit.Stroke(banner, 3, Color3.fromRGB(10, 12, 24))
	UIKit.FitToScreen(banner, Vector2.new(WIDTH + 60, HEIGHT), Vector2.new(24, 0))

	-- Círculo con el ícono del paso (sale un poco por la izquierda)
	iconLabel = UIKit.Label(banner, "🥚", UDim2.fromOffset(88, 88), UDim2.fromOffset(-40, 4), 44)
	iconLabel.TextXAlignment = Enum.TextXAlignment.Center
	iconLabel.BackgroundTransparency = 0
	UIKit.Corner(iconLabel, 44)
	UIKit.Stroke(iconLabel, 3, Color3.fromRGB(10, 12, 24))

	stepPill = UIKit.Label(banner, "STEP 1/4", UDim2.fromOffset(76, 22), UDim2.fromOffset(60, 10), 14, Color3.fromRGB(30, 30, 30))
	stepPill.TextXAlignment = Enum.TextXAlignment.Center
	stepPill.BackgroundTransparency = 0
	UIKit.Corner(stepPill, 11)
	for i = 1, STEP_COUNT do
		local dash = Instance.new("Frame")
		dash.Size = UDim2.fromOffset(24, 8)
		dash.Position = UDim2.fromOffset(144 + (i - 1) * 30, 17)
		dash.BorderSizePixel = 0
		dash.Parent = banner
		UIKit.Corner(dash, 4)
		table.insert(dashes, dash)
	end

	titleLabel = UIKit.Label(banner, "", UDim2.fromOffset(390, 34), UDim2.fromOffset(60, 34), 30)
	UIKit.Stroke(titleLabel, 2.5)
	textLabel = UIKit.Label(banner, "", UDim2.fromOffset(400, 22), UDim2.fromOffset(60, 68), 16, C.SubText)
	textLabel.RichText = true

	metricLabel = UIKit.Label(banner, "", UDim2.fromOffset(110, 34), UDim2.fromOffset(WIDTH - 126, 16), 20, Color3.fromRGB(130, 255, 130))
	metricLabel.TextXAlignment = Enum.TextXAlignment.Center
	metricLabel.BackgroundTransparency = 0
	metricLabel.BackgroundColor3 = Color3.fromRGB(10, 12, 24)
	UIKit.Corner(metricLabel, 10)

	local skip = Instance.new("TextButton")
	skip.Size = UDim2.fromOffset(110, 22)
	skip.Position = UDim2.fromOffset(WIDTH - 126, 58)
	skip.BackgroundTransparency = 1
	skip.Font = UIKit.Font
	skip.TextSize = 15
	skip.TextColor3 = Color3.fromRGB(150, 170, 230)
	skip.RichText = true
	skip.Text = "<u>Skip tutorial</u>"
	skip.Parent = banner
	skip.Activated:Connect(function()
		actionRemote:FireServer("Skip")
	end)

	-- "STEP COMPLETE! +100 coins"
	toast = UIKit.Label(gui, "", UDim2.fromOffset(460, 64), UDim2.new(0.5, -230, 0.62, 0), 26)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.BackgroundTransparency = 0
	toast.BackgroundColor3 = Color3.fromRGB(70, 160, 50)
	toast.RichText = true
	toast.Visible = false
	UIKit.Corner(toast, 18)
	UIKit.Stroke(toast, 3, Color3.fromRGB(20, 50, 20)).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	UIKit.FitToScreen(toast, Vector2.new(460, 64), Vector2.new(24, 0))
end

local function buildArrow()
	-- La flecha es un Beam entre un punto en tu personaje y un punto en el objetivo
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "TutorialTarget"
	targetAttachment.Parent = Workspace.Terrain

	beam = Instance.new("Beam")
	beam.Name = "TutorialBeam"
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(UIKit.Colors.Accent)
	beam.Transparency = NumberSequence.new(0.2, 0.5)
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 20
	beam.CurveSize0 = 6 -- un poco curva, hacia arriba
	beam.CurveSize1 = -6
	beam.Enabled = false
	beam.Parent = Workspace.Terrain

	-- Marca que salta arriba del objetivo
	marker = Instance.new("Part")
	marker.Name = "TutorialMarker"
	marker.Size = Vector3.new(1, 1, 1)
	marker.Transparency = 1
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Parent = Workspace
	markerGui = Instance.new("BillboardGui")
	markerGui.Size = UDim2.fromOffset(60, 60)
	markerGui.AlwaysOnTop = true
	markerGui.Enabled = false
	markerGui.Parent = marker
	local arrow = UIKit.Label(markerGui, "▼", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 48, UIKit.Colors.Accent)
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.Stroke(arrow, 3)
end

-- El extremo de la flecha que sale de tu personaje (hay que rehacerlo cada vez que reaparecés)
local function attachToCharacter()
	local root = rootPart()
	if not root then
		return
	end
	local existing = root:FindFirstChild("TutorialSource")
	local source = if existing and existing:IsA("Attachment") then existing else Instance.new("Attachment")
	source.Name = "TutorialSource"
	source.Parent = root
	beam.Attachment0 = source
end

-- Muestra un objetivo en el cartel (lo usan también las vistas previas)
function Tutorial.Show(goal: Goal?, metric: string?)
	banner.Visible = goal ~= nil
	if not goal then
		return
	end
	iconLabel.Text = goal.Icon
	iconLabel.BackgroundColor3 = goal.Color
	local shown = math.clamp(goal.Step, 1, STEP_COUNT)
	stepPill.Text = `STEP {shown}/{STEP_COUNT}`
	stepPill.BackgroundColor3 = goal.Color
	for i, dash in dashes do
		dash.BackgroundColor3 = if i <= shown then goal.Color else Color3.fromRGB(60, 66, 100)
	end
	titleLabel.Text = goal.Title
	textLabel.Text = goal.Text
	metricLabel.Text = metric or ""
	metricLabel.Visible = metric ~= nil and metric ~= ""
end

function Tutorial.ShowStepComplete(coins: number)
	toast.Text = `✅ STEP COMPLETE!  <font color="#FFE27A">+{Format.Number(coins)} coins</font>`
	toast.Visible = true
	toastUntil = os.clock() + 2.5
end

local function update()
	local root = rootPart()
	local goal = if root then currentGoal(root) else nil
	Tutorial.Show(goal, if goal and root then metricText(goal, root) else nil)
	if toast.Visible and os.clock() > toastUntil then
		toast.Visible = false
	end

	local target = goal and goal.Target
	local showArrow = target ~= nil and root ~= nil and beam.Attachment0 ~= nil
	beam.Enabled = showArrow
	markerGui.Enabled = showArrow
	if target and showArrow then
		targetAttachment.WorldPosition = target
		-- La marca sube y baja arriba del objetivo
		marker.CFrame = CFrame.new(target + Vector3.new(0, 5 + math.sin(os.clock() * 4) * 0.8, 0))
	end
end

function Tutorial.Start()
	buildBanner()
	buildArrow()
	actionRemote.OnClientEvent:Connect(function(kind: unknown, _step: unknown, coins: unknown)
		if kind == "StepComplete" and typeof(coins) == "number" then
			Tutorial.ShowStepComplete(coins)
		end
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		attachToCharacter()
	end)
	attachToCharacter()
	RunService.RenderStepped:Connect(update)
end

return Tutorial

--!strict
-- Tutorial: muestra qué hacer ahora (cartel arriba) y una flecha de luz desde tu personaje hasta el objetivo.
-- El paso lo decide el servidor (atributo "TutorialStep", ver TutorialService). Este módulo solo lo dibuja.
-- Si viene la ola y estás en el cañón, el tutorial te lleva a la cueva-refugio más cercana.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local actionRemote = Remotes.Event("TutorialAction")

local Tutorial = {}

-- Mismos números que TutorialService.Steps
local GRAB_EGG, INCUBATE, WAIT_HATCH, OPEN_UPGRADES, DONE = 1, 2, 3, 4, 5

local TEXTS: { [string]: string } = {
	Grab = "🥚 Go through the tiki portal and grab an egg in the canyon!",
	Incubate = "🏠 Bring the egg to an incubator in front of your base!",
	Wait = "⏳ Your egg is incubating! When it says READY!, open it.",
	Open = "🐣 Your egg is READY! Open it!",
	Upgrades = "🪙 Your creature makes coins! Visit the Upgrades shop on the island.",
	Danger = "🌊 THE WAVE IS COMING! Hide in a cave!",
}

local WIDTH, HEIGHT = 600, 64

local banner: Frame
local bannerText: TextLabel
local beam: Beam
local targetAttachment: Attachment
local marker: Part
local markerGui: BillboardGui
local lastSearch = 0
local cachedEgg: BasePart? = nil
local caveSpots: { Vector3 }? = nil

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

-- Decide qué texto mostrar y a dónde apunta la flecha
local function currentGoal(root: BasePart): (string?, Vector3?)
	local s = step()
	if s >= DONE then
		return nil, nil
	end
	local base = myBase()

	-- Si viene la ola y estás en el cañón: ¡a una cueva!
	local phase = Workspace:GetAttribute("WavePhase")
	if (phase == "Warning" or phase == "Wave") and root.Position.X > Config.Map.CanyonStartX then
		return TEXTS.Danger, nearestCave(root.Position)
	end

	local carrying = player:GetAttribute("CarriedEggRarity") ~= nil
	local incubator = findPart(base, { "IncubatorSlots", "Nest1", "Pedestal" })
	if s == GRAB_EGG or (s == INCUBATE and not carrying) then
		local egg = nearestEgg(root.Position)
		-- Si no ves ninguno cerca, apuntamos al portal tiki (la entrada del cañón)
		return TEXTS.Grab, if egg then egg.Position else Vector3.new(Config.Map.CanyonStartX, 3, 0)
	elseif s == INCUBATE then
		return TEXTS.Incubate, if incubator then incubator.Position else nil
	elseif s == WAIT_HATCH then
		local prompt = incubator and incubator:FindFirstChildOfClass("ProximityPrompt")
		if prompt and prompt:GetAttribute("State") == "Ready" then
			return TEXTS.Open, incubator and incubator.Position
		end
		return TEXTS.Wait, nil
	elseif s == OPEN_UPGRADES then
		local map = Workspace:FindFirstChild("Map")
		local shop = findPart(map and map:FindFirstChild("Stalls", true), { "UpgradeShop", "Counter" })
		return TEXTS.Upgrades, if shop then shop.Position else nil
	end
	return nil, nil
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
	banner.Position = UDim2.new(0.5, 0, 0, 116) -- abajo del cartel de la tormenta
	banner.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	banner.BackgroundColor3 = UIKit.Colors.Panel
	banner.BackgroundTransparency = 0.1
	banner.Visible = false
	banner.Parent = gui
	UIKit.Corner(banner, 16)
	UIKit.Stroke(banner, 3, UIKit.Colors.Accent)
	UIKit.FitToScreen(banner, Vector2.new(WIDTH, HEIGHT), Vector2.new(24, 0))

	bannerText = UIKit.Label(banner, "", UDim2.fromOffset(WIDTH - 110, HEIGHT - 8), UDim2.fromOffset(16, 4), 20)
	bannerText.TextWrapped = true
	bannerText.TextTruncate = Enum.TextTruncate.None

	local skip = UIKit.Button(banner, "Skip", UDim2.fromOffset(76, 40), UDim2.fromOffset(WIDTH - 88, 12), 18, UIKit.Colors.Gray)
	skip.Activated:Connect(function()
		actionRemote:FireServer("Skip")
	end)
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

local function update()
	local root = rootPart()
	local text, target = nil, nil
	if root then
		text, target = currentGoal(root)
	end

	banner.Visible = text ~= nil
	if text then
		bannerText.Text = text
	end

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
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		attachToCharacter()
	end)
	attachToCharacter()
	RunService.RenderStepped:Connect(update)
end

return Tutorial

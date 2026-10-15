--!strict
-- UpgradePanel: la ventana de mejoras que se abre desde el panel de tu base.
-- Ventana ancha de tamaño fijo (680x500) que se achica entera en pantallas chicas (UIKit.FitToScreen),
-- con columnas separadas para que los textos nunca se pisen:
--   [ícono] [nombre]        [Lv 2/5]            [  Buy 500  ]
--           [descripción de qué cambia...]
-- El botón "Buy" solo PIDE la compra: el servidor decide si se puede (ver UpgradeService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Format = require(ReplicatedStorage.Shared.Format)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local buyRemote = Remotes.Event("BuyUpgrade")
local tutorialRemote = Remotes.Event("TutorialAction")
local C = UIKit.Colors

local UpgradePanel = {}

local CLOSE_DISTANCE = 20 -- si te alejás más que esto del panel, la ventana se cierra sola
local WIDTH, HEIGHT = 680, 500
local ROW_HEIGHT, ROW_GAP, HEADER = 88, 12, 84

local ICONS: { [string]: string } = {
	IncubationSpeed = "⏩",
	ExtraIncubator = "🥚",
	WalkSpeed = "👟",
	BaseFloor = "🏠",
}
local ICON_COLORS: { [string]: Color3 } = {
	IncubationSpeed = Color3.fromRGB(255, 150, 60),
	ExtraIncubator = Color3.fromRGB(90, 190, 255),
	WalkSpeed = Color3.fromRGB(120, 220, 120),
	BaseFloor = Color3.fromRGB(200, 130, 255),
}

type Row = { Level: TextLabel, Description: TextLabel, Button: TextButton }

local gui: ScreenGui
local coinsLabel: TextLabel
local rows: { [string]: Row } = {}
local openPanelPart: BasePart? = nil
local lastClick = 0

local function currentState(): Upgrades.State
	local function attr(name: string): number
		local value = player:GetAttribute(name)
		return if typeof(value) == "number" then value else 1
	end
	return {
		IncubationSpeedLevel = attr("IncubationSpeedLevel"),
		IncubatorCount = attr("IncubatorCount"),
		WalkSpeedLevel = attr("WalkSpeedLevel"),
		BaseLevel = attr("BaseLevel"),
	}
end

local function refresh()
	local coins = player:GetAttribute("Coins")
	local coinValue = if typeof(coins) == "number" then coins else 0
	coinsLabel.Text = Format.Number(coinValue)

	local state = currentState()
	for id, row in rows do
		local current, max = Upgrades.GetLevel(id, state)
		local cost = Upgrades.GetNextCost(id, state)
		row.Level.Text = `Lv {current}/{max}`
		row.Description.Text = Upgrades.Describe(id, state)
		if cost == nil then
			row.Button.Text = "MAX"
			row.Button.BackgroundColor3 = C.Gray
			row.Button.AutoButtonColor = false
		else
			row.Button.Text = `Buy  {Format.Number(cost)}`
			local canAfford = coinValue >= cost
			row.Button.BackgroundColor3 = if canAfford then C.Green else C.Red
			row.Button.AutoButtonColor = canAfford
		end
	end
end

local function close()
	gui.Enabled = false
	openPanelPart = nil
end

local function open(panelPart: BasePart)
	openPanelPart = panelPart
	refresh()
	gui.Enabled = true
	-- Paso 4 del tutorial: "abrí el panel de mejoras"
	if player:GetAttribute("TutorialStep") == 4 then
		tutorialRemote:FireServer("OpenedUpgrades")
	end
end

local function buildRow(parent: Instance, index: number, id: string)
	local rowWidth = WIDTH - 48
	local row = Instance.new("Frame")
	row.Size = UDim2.fromOffset(rowWidth, ROW_HEIGHT)
	row.Position = UDim2.fromOffset(24, HEADER + (index - 1) * (ROW_HEIGHT + ROW_GAP))
	row.BackgroundColor3 = C.Row
	row.Parent = parent
	UIKit.Corner(row, 14)

	-- Ícono
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromOffset(64, 64)
	icon.Position = UDim2.fromOffset(12, 12)
	icon.BackgroundColor3 = ICON_COLORS[id] or C.Gray
	icon.Text = ICONS[id] or "?"
	icon.TextSize = 34
	icon.Font = UIKit.Font
	icon.Parent = row
	UIKit.Corner(icon, 12)

	-- Columna de textos (de x=88 a x=448): nombre + nivel arriba, descripción abajo
	UIKit.Label(row, Upgrades.DisplayNames[id], UDim2.fromOffset(250, 34), UDim2.fromOffset(88, 10), 26)

	local level = UIKit.Label(row, "Lv 1/1", UDim2.fromOffset(84, 28), UDim2.fromOffset(346, 13), 18, C.Accent)
	level.TextXAlignment = Enum.TextXAlignment.Center
	level.BackgroundTransparency = 0
	level.BackgroundColor3 = Color3.fromRGB(30, 32, 48)
	UIKit.Corner(level, 14)

	local description = UIKit.Label(row, "", UDim2.fromOffset(354, 28), UDim2.fromOffset(88, 48), 18, C.SubText)

	-- Botón (de x=460 a x=620)
	local button = UIKit.Button(row, "", UDim2.fromOffset(160, 60), UDim2.fromOffset(rowWidth - 172, 14), 22, C.Green)
	button.Activated:Connect(function()
		-- Pequeña pausa entre clics para no mandar 20 pedidos al servidor
		if os.clock() - lastClick < 0.3 then
			return
		end
		lastClick = os.clock()
		buyRemote:FireServer(id)
	end)

	rows[id] = { Level = level, Description = description, Button = button }
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "UpgradePanel"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	frame.BackgroundColor3 = C.Panel
	frame.Parent = gui
	UIKit.Corner(frame, 20)
	UIKit.Stroke(frame, 4, C.Accent)
	UIKit.FitToScreen(frame, Vector2.new(WIDTH, HEIGHT))

	-- Encabezado: título a la izquierda, plata a la derecha, X en la esquina
	UIKit.Label(frame, "UPGRADES", UDim2.fromOffset(300, 50), UDim2.fromOffset(28, 18), 40, C.Accent)

	local coinsPill = Instance.new("Frame")
	coinsPill.Size = UDim2.fromOffset(210, 44)
	coinsPill.Position = UDim2.fromOffset(WIDTH - 210 - 84, 21)
	coinsPill.BackgroundColor3 = Color3.fromRGB(22, 24, 38)
	coinsPill.Parent = frame
	UIKit.Corner(coinsPill, 22)
	local coinIcon = UIKit.Label(coinsPill, "🪙", UDim2.fromOffset(36, 36), UDim2.fromOffset(8, 4), 26)
	coinIcon.TextXAlignment = Enum.TextXAlignment.Center
	coinsLabel = UIKit.Label(coinsPill, "0", UDim2.fromOffset(156, 44), UDim2.fromOffset(46, 0), 24, C.Gold)

	local closeButton = UIKit.Button(frame, "X", UDim2.fromOffset(52, 52), UDim2.fromOffset(WIDTH - 70, 17), 28, C.Red)
	closeButton.Activated:Connect(close)

	for i, id in Upgrades.Order do
		buildRow(frame, i, id)
	end
end

-- El prompt "Open" solo se ve en tu propia base
local function setupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local function updateVisibility()
		prompt.Enabled = prompt:GetAttribute("BaseId") == player:GetAttribute("BaseId")
	end
	updateVisibility()
	player:GetAttributeChangedSignal("BaseId"):Connect(updateVisibility)
	prompt.Triggered:Connect(function()
		local part = prompt.Parent
		if prompt.Enabled and part and part:IsA("BasePart") then
			open(part)
		end
	end)
end

function UpgradePanel.Start()
	build()

	for _, prompt in CollectionService:GetTagged("UpgradePrompt") do
		setupPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("UpgradePrompt"):Connect(setupPrompt)

	for _, name in { "Coins", "IncubationSpeedLevel", "IncubatorCount", "WalkSpeedLevel", "BaseLevel" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if gui.Enabled then
				refresh()
			end
		end)
	end

	-- Si te alejás del panel, se cierra
	RunService.Heartbeat:Connect(function()
		local part = openPanelPart
		if not gui.Enabled or not part then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - part.Position).Magnitude > CLOSE_DISTANCE then
			close()
		end
	end)
end

return UpgradePanel

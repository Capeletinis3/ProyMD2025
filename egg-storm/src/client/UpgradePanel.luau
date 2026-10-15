--!strict
-- UpgradePanel: la ventana de mejoras que se abre desde el panel de tu base.
-- Muestra cada mejora con su nivel, qué cambia y cuánto cuesta. El botón "Buy" solo PIDE la compra:
-- el servidor decide si se puede (ver UpgradeService). La ventana se actualiza sola cuando cambian
-- tus niveles o tu plata (el servidor los publica como atributos del jugador).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local buyRemote = Remotes.Event("BuyUpgrade")

local UpgradePanel = {}

local CLOSE_DISTANCE = 20 -- si te alejás más que esto del panel, la ventana se cierra sola
local FONT = Enum.Font.FredokaOne

type Row = { Level: TextLabel, Description: TextLabel, Button: TextButton }

local gui: ScreenGui
local coinsLabel: TextLabel
local rows: { [Upgrades.UpgradeId]: Row } = {}
local openPanelPart: BasePart? = nil
local lastClick = 0

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

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
	coinsLabel.Text = `Coins: {Format.Number(coinValue)}`

	local state = currentState()
	for id, row in rows do
		local current, max = Upgrades.GetLevel(id, state)
		local cost = Upgrades.GetNextCost(id, state)
		row.Level.Text = `Lv {current}/{max}`
		row.Description.Text = Upgrades.Describe(id, state)
		if cost == nil then
			row.Button.Text = "MAX"
			row.Button.BackgroundColor3 = Color3.fromRGB(110, 110, 120)
			row.Button.AutoButtonColor = false
		else
			row.Button.Text = `Buy: {Format.Number(cost)}`
			local canAfford = coinValue >= cost
			row.Button.BackgroundColor3 = if canAfford then Color3.fromRGB(70, 200, 90) else Color3.fromRGB(200, 80, 80)
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
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "UpgradePanel"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.9, 0.75)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	frame.Parent = gui
	corner(frame, 16)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 220, 80)
	stroke.Parent = frame
	-- En pantallas grandes no pasa de este tamaño
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 440)
	limit.Parent = frame

	label(frame, "UPGRADES", UDim2.fromScale(0.5, 0.11), UDim2.fromScale(0.04, 0.03), Color3.fromRGB(255, 220, 80))
	coinsLabel = label(frame, "Coins: 0", UDim2.fromScale(0.36, 0.07), UDim2.fromScale(0.5, 0.05), Color3.fromRGB(120, 255, 120), Enum.TextXAlignment.Right)

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.fromScale(0.08, 0.1)
	closeButton.Position = UDim2.fromScale(0.89, 0.03)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
	closeButton.Font = FONT
	closeButton.TextScaled = true
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Text = "X"
	closeButton.Parent = frame
	corner(closeButton, 8)
	closeButton.Activated:Connect(close)

	for i, id in Upgrades.Order do
		local row = Instance.new("Frame")
		row.Size = UDim2.fromScale(0.92, 0.18)
		row.Position = UDim2.fromScale(0.04, 0.17 + (i - 1) * 0.205)
		row.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
		row.Parent = frame
		corner(row, 10)

		label(row, Upgrades.DisplayNames[id], UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0.03, 0.06), Color3.new(1, 1, 1))
		local level = label(row, "Lv 1/1", UDim2.fromScale(0.16, 0.4), UDim2.fromScale(0.5, 0.08), Color3.fromRGB(180, 180, 255))
		local description = label(row, "", UDim2.fromScale(0.62, 0.36), UDim2.fromScale(0.03, 0.56), Color3.fromRGB(200, 200, 200))

		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(0.3, 0.7)
		button.Position = UDim2.fromScale(0.68, 0.15)
		button.Font = FONT
		button.TextScaled = true
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Parent = row
		corner(button, 8)
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

--!strict
-- UpgradePanel: la ventana de mejoras (techo de paja, postes de bambú y tarjetas de papel).
-- Se abre con el botón "Shop" del costado o con "Open" en el puesto de mejoras del lobby.
-- Cada tarjeta: ícono redondo, nombre, nivel, qué hace, puntitos de nivel, "ahora → después" y el botón de comprar.
-- Arriba se elige comprar de a 1, de a 10 o el MÁXIMO que alcance.
-- El botón solo PIDE la compra: el servidor decide si se puede (ver UpgradeService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Format = require(ReplicatedStorage.Shared.Format)
local Config = require(ReplicatedStorage.Shared.Config)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)

local player = Players.LocalPlayer
local buyRemote = Remotes.Event("BuyUpgrade")

local UpgradePanel = {}

local SIZE = Vector2.new(920, 660)
local CARD = Vector2.new(400, 150)
local CLOSE_DISTANCE = 24 -- si la abriste en el puesto y te alejás, se cierra
local DARK = Color3.fromRGB(42, 22, 8)
local PAPER = Color3.fromRGB(255, 241, 208)
local MAX_PIPS = 10

local STYLE: { [string]: { Icon: string, Color: Color3, Shadow: Color3 } } = {
	WalkSpeed = { Icon = "👟", Color = Color3.fromRGB(255, 90, 77), Shadow = Color3.fromRGB(184, 50, 42) },
	Carry = { Icon = "🥚", Color = Color3.fromRGB(255, 159, 26), Shadow = Color3.fromRGB(184, 106, 0) },
	IncubationSpeed = { Icon = "⏳", Color = Color3.fromRGB(178, 107, 255), Shadow = Color3.fromRGB(122, 58, 194) },
	Luck = { Icon = "🍀", Color = Color3.fromRGB(67, 193, 82), Shadow = Color3.fromRGB(42, 138, 53) },
	ExtraIncubator = { Icon = "🪺", Color = Color3.fromRGB(63, 180, 240), Shadow = Color3.fromRGB(30, 120, 180) },
}

type Card = {
	Level: TextLabel,
	Pips: { Frame },
	Values: TextLabel,
	Button: TextButton,
	MaxStamp: TextLabel,
}

local gui: ScreenGui
local coinsLabel: TextLabel
local modeButtons: { [number]: TextButton } = {}
local cards: { [string]: Card } = {}
local mode = 1 -- 1, 10 o 100 (= MÁX)
local openPart: BasePart? = nil
local lastClick = 0

local function number(name: string, default: number): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function currentState(): Upgrades.State
	return {
		IncubationSpeedLevel = number("IncubationSpeedLevel", 1),
		IncubatorCount = number("IncubatorCount", Config.Upgrades.StartingIncubators),
		WalkSpeedLevel = number("WalkSpeedLevel", 1),
		LuckLevel = number("LuckLevel", 1),
		CarryLevel = number("CarryLevel", 1),
	}
end

local function stroked(label: TextLabel, thickness: number?): TextLabel
	UIKit.Stroke(label, thickness or 2.5, DARK)
	return label
end

local function refresh()
	local state = currentState()
	local coins = number("Coins", 0)
	coinsLabel.Text = `💰 {Format.Compact(coins)}`
	for value, button in modeButtons do
		local on = value == mode
		button.BackgroundColor3 = if on then Color3.fromRGB(255, 194, 26) else Color3.fromRGB(107, 62, 28)
		button.TextColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(217, 185, 138)
	end
	for _, id in Upgrades.Order do
		local card = cards[id]
		local current, max = Upgrades.GetLevel(id, state)
		local maxed = current >= max
		card.Level.Text = `Lv {current}/{max}`
		for i, pip in card.Pips do
			pip.Visible = i <= max
			pip.BackgroundColor3 = if i <= current then STYLE[id].Color else Color3.fromRGB(233, 210, 166)
		end
		card.Values.Text = if maxed
			then Upgrades.ValueText(id, current)
			else `{Upgrades.ValueText(id, current)}  ➜  {Upgrades.ValueText(id, current + 1)}`
		card.MaxStamp.Visible = maxed
		card.Button.Visible = not maxed
		if not maxed then
			local count, total = Upgrades.Plan(id, state, coins, mode)
			if count == 0 then
				local nextCost = Upgrades.GetNextCost(id, state) or 0
				card.Button.Text = `💰 {Format.Compact(nextCost)}`
				card.Button.BackgroundColor3 = UIKit.Colors.Red
			else
				card.Button.Text = if count > 1 then `x{count} · {Format.Compact(total)}` else `💰 {Format.Compact(total)}`
				card.Button.BackgroundColor3 = Color3.fromRGB(76, 209, 55)
			end
		end
	end
end

local function close()
	gui.Enabled = false
	openPart = nil
end

-- Abre la ventana. Si viene de un puesto, se cierra sola cuando te alejás.
function UpgradePanel.Open(part: BasePart?)
	openPart = part
	refresh()
	gui.Enabled = true
end

local function buildCard(frame: Frame, index: number, id: string)
	local style = STYLE[id]
	local col = (index - 1) % 2
	local row = (index - 1) // 2
	local x = if index == #Upgrades.Order and #Upgrades.Order % 2 == 1 then (SIZE.X - CARD.X) / 2 else 48 + col * (CARD.X + 24)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	card.Position = UDim2.fromOffset(x, 196 + row * (CARD.Y + 14))
	card.BackgroundColor3 = PAPER
	card.Parent = frame
	UIKit.Corner(card, 18)
	UIKit.Stroke(card, 4, DARK)

	local icon = UIKit.Label(card, style.Icon, UDim2.fromOffset(78, 78), UDim2.fromOffset(-16, 14), 40)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.BackgroundTransparency = 0
	icon.BackgroundColor3 = style.Color
	UIKit.Corner(icon, 39)
	UIKit.Stroke(icon, 4, DARK)

	local left = 74
	local name = stroked(UIKit.Label(card, Upgrades.DisplayNames[id], UDim2.fromOffset(200, 28), UDim2.fromOffset(left, 8), 24, style.Color), 3)
	name.TextTruncate = Enum.TextTruncate.None
	local level = UIKit.Label(card, "", UDim2.fromOffset(100, 22), UDim2.fromOffset(CARD.X - 116, 10), 15, Color3.fromRGB(138, 90, 43))
	level.TextXAlignment = Enum.TextXAlignment.Right
	UIKit.Label(card, Upgrades.Descriptions[id], UDim2.fromOffset(CARD.X - left - 16, 20), UDim2.fromOffset(left, 38), 14, Color3.fromRGB(107, 74, 42))

	local pips: { Frame } = {}
	for i = 1, MAX_PIPS do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(13, 17)
		pip.Position = UDim2.fromOffset(left + (i - 1) * 17, 64)
		pip.Parent = card
		UIKit.Corner(pip, 7)
		UIKit.Stroke(pip, 1.5, DARK)
		table.insert(pips, pip)
	end

	local values = stroked(UIKit.Label(card, "", UDim2.fromOffset(170, 44), UDim2.fromOffset(left, 92), 20), 2.5)
	values.TextXAlignment = Enum.TextXAlignment.Center
	values.BackgroundTransparency = 0
	values.BackgroundColor3 = DARK
	UIKit.Corner(values, 12)

	local button = UIKit.Button(card, "", UDim2.fromOffset(140, 46), UDim2.fromOffset(CARD.X - 156, 91), 19, Color3.fromRGB(76, 209, 55))
	UIKit.Stroke(button, 2.5, DARK).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	button.Activated:Connect(function()
		if os.clock() - lastClick < 0.3 then
			return
		end
		lastClick = os.clock()
		buyRemote:FireServer(id, mode)
	end)
	local stamp = stroked(UIKit.Label(card, "MAX!", UDim2.fromOffset(140, 46), UDim2.fromOffset(CARD.X - 156, 91), 26, Color3.fromRGB(255, 194, 26)), 3)
	stamp.TextXAlignment = Enum.TextXAlignment.Center
	stamp.BackgroundTransparency = 0
	stamp.BackgroundColor3 = Color3.fromRGB(255, 231, 160)
	stamp.Rotation = -4
	UIKit.Corner(stamp, 14)

	cards[id] = { Level = level, Pips = pips, Values = values, Button = button, MaxStamp = stamp }
end

local function build()
	local frame
	gui, frame = UIKit.Window("UpgradePanel", "", SIZE, 6)
	frame.BackgroundColor3 = Color3.fromRGB(107, 62, 28)
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = DARK
	end
	-- Postes de bambú a los costados
	for _, px in { -10, SIZE.X - 20 } do
		local post = Instance.new("Frame")
		post.Size = UDim2.fromOffset(30, SIZE.Y + 10)
		post.Position = UDim2.fromOffset(px, -5)
		post.BackgroundColor3 = Color3.fromRGB(217, 178, 90)
		post.Parent = frame
		UIKit.Corner(post, 15)
		UIKit.Stroke(post, 3, DARK)
	end
	-- Techo de paja
	local roof = Instance.new("Frame")
	roof.Size = UDim2.fromOffset(SIZE.X + 60, 70)
	roof.Position = UDim2.fromOffset(-30, -36)
	roof.BackgroundColor3 = Color3.fromRGB(217, 164, 65)
	roof.Parent = frame
	UIKit.Corner(roof, 22)
	UIKit.Stroke(roof, 4, DARK)
	local plaque = stroked(UIKit.Label(frame, "UPGRADES", UDim2.fromOffset(380, 70), UDim2.fromOffset((SIZE.X - 380) / 2, -12), 44, Color3.fromRGB(255, 231, 176)), 4)
	plaque.TextXAlignment = Enum.TextXAlignment.Center
	plaque.BackgroundTransparency = 0
	plaque.BackgroundColor3 = Color3.fromRGB(160, 102, 46)
	UIKit.Corner(plaque, 12)
	UIKit.Stroke(plaque, 4, DARK).ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	-- Plata y cantidad (x1 / x10 / MÁX)
	coinsLabel = stroked(UIKit.Label(frame, "", UDim2.fromOffset(220, 44), UDim2.fromOffset(48, 116), 26, Color3.fromRGB(255, 225, 77)), 3)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Center
	coinsLabel.BackgroundTransparency = 0
	coinsLabel.BackgroundColor3 = DARK
	UIKit.Corner(coinsLabel, 22)
	for i, value in { 1, 10, 100 } do
		local button = UIKit.Button(frame, if value == 100 then "MAX" else `x{value}`, UDim2.fromOffset(80, 44), UDim2.fromOffset(SIZE.X - 48 - (4 - i) * 86, 116), 22, Color3.fromRGB(107, 62, 28))
		UIKit.Stroke(button, 2.5, DARK).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		button.Activated:Connect(function()
			mode = value
			refresh()
		end)
		modeButtons[value] = button
	end

	for index, id in Upgrades.Order do
		buildCard(frame, index, id)
	end
end

local function setupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local function updateVisibility()
		prompt.Enabled = player:GetAttribute("BaseId") ~= nil
	end
	updateVisibility()
	player:GetAttributeChangedSignal("BaseId"):Connect(updateVisibility)
	prompt.Triggered:Connect(function()
		local part = prompt.Parent
		if prompt.Enabled then
			UpgradePanel.Open(if part and part:IsA("BasePart") then part else nil)
		end
	end)
end

function UpgradePanel.Start()
	build()

	for _, prompt in CollectionService:GetTagged("UpgradePrompt") do
		setupPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("UpgradePrompt"):Connect(setupPrompt)
	SideMenu.Bind("Upgrades", function()
		UpgradePanel.Open(nil)
	end)

	for _, name in { "Coins", "IncubationSpeedLevel", "IncubatorCount", "WalkSpeedLevel", "LuckLevel", "CarryLevel" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if gui.Enabled then
				refresh()
			end
		end)
	end

	RunService.Heartbeat:Connect(function()
		local part = openPart
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

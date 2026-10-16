--!strict
-- RebirthPanel: la ventana de renacimiento (se abre con el botón "Rebirth" del costado).
-- Muestra el nivel (0 → 1), qué ganás, qué perdés, qué conservás, cuánta plata te falta y el botón para renacer.
-- El botón solo PIDE renacer: el servidor decide si se puede (ver RebirthService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)

local player = Players.LocalPlayer
local rebirthRemote = Remotes.Event("Rebirth")
local C = UIKit.Colors

local RebirthPanel = {}

local SIZE = Vector2.new(560, 520)
local ORANGE = Color3.fromRGB(255, 140, 40)
local DARK = Color3.fromRGB(38, 26, 24)
local CARD = Color3.fromRGB(56, 38, 34)
local ROW = Color3.fromRGB(74, 52, 46)
local GREEN = Color3.fromRGB(80, 200, 90)
local RED = Color3.fromRGB(230, 80, 80)
local BLUE = Color3.fromRGB(80, 160, 240)

local gui: ScreenGui
local levelLabel: TextLabel
local bonusLabel: TextLabel
local bonusNote: TextLabel
local coinsLabel: TextLabel
local barFill: Frame
local button: TextButton
local priceLabel: TextLabel
local lastClick = 0

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function centered(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3?): TextLabel
	local label = UIKit.Label(parent, text, size, position, textSize, color)
	label.TextXAlignment = Enum.TextXAlignment.Center
	return label
end

-- Etiqueta redondeada ("pastilla")
local function pill(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3, textSize: number): TextLabel
	local label = centered(parent, text, size, position, textSize)
	label.BackgroundTransparency = 0
	label.BackgroundColor3 = color
	UIKit.Corner(label, 14)
	return label
end

local function refresh()
	local rebirths = number("Rebirths")
	local cost = Config.RebirthCost(rebirths)
	local coins = number("Coins")
	levelLabel.Text = `{rebirths} → {rebirths + 1}`
	bonusLabel.Text = string.format("X%.2f → X%.2f", Config.RebirthMultiplier(rebirths), Config.RebirthMultiplier(rebirths + 1))
	bonusNote.Text = string.format("+%.2f every rebirth", Config.Rebirth.IncomeBonus)
	bonusNote.TextColor3 = C.SubText
	local ready = coins >= cost
	local nextOne = Format.Number(Config.RebirthCost(rebirths + 1))
	coinsLabel.Text = `{Format.Number(math.min(coins, cost))} / {Format.Number(cost)}` .. (if ready then " Ready!" else "") .. ` · Next one: {nextOne}`
	coinsLabel.TextColor3 = if ready then GREEN else C.SubText
	barFill.Size = UDim2.fromScale(math.clamp(coins / cost, 0, 1), 1)
	priceLabel.Text = `💰 {Format.Number(cost)}`
	button.BackgroundColor3 = if ready then ORANGE else Color3.fromRGB(120, 90, 80)
end

function RebirthPanel.Open()
	refresh()
	gui.Enabled = true
end

-- Tarjeta con su título en una pastilla arriba
local function card(frame: Frame, title: string, color: Color3, x: number): Frame
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(160, 192)
	box.Position = UDim2.fromOffset(x, 168)
	box.BackgroundColor3 = CARD
	box.Parent = frame
	UIKit.Corner(box, 14)
	UIKit.Stroke(box, 2, color:Lerp(Color3.new(0, 0, 0), 0.4))
	local header = pill(box, title, UDim2.fromOffset(112, 26), UDim2.fromOffset(24, -13), color, 17)
	UIKit.Stroke(header, 1.5)
	return box
end

-- Fila con un circulito de color y un texto (para "perdés" y "conservás")
local function row(box: Frame, index: number, icon: string, iconColor: Color3, text: string)
	local line = Instance.new("Frame")
	line.Size = UDim2.fromOffset(144, 46)
	line.Position = UDim2.fromOffset(8, 24 + (index - 1) * 54)
	line.BackgroundColor3 = ROW
	line.Parent = box
	UIKit.Corner(line, 10)
	local dot = pill(line, icon, UDim2.fromOffset(28, 28), UDim2.fromOffset(8, 9), iconColor, 16)
	UIKit.Corner(dot, 14)
	local label = UIKit.Label(line, text, UDim2.fromOffset(100, 40), UDim2.fromOffset(42, 3), 16)
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
end

function RebirthPanel.Start()
	local frame
	gui, frame = UIKit.Window("RebirthPanel", "", SIZE, 6)
	frame.BackgroundColor3 = DARK
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = ORANGE
	end

	-- Encabezado: huevo en llamas, título y frase
	centered(frame, "🔥", UDim2.fromOffset(90, 90), UDim2.fromOffset(SIZE.X / 2 - 45, -52), 72)
	centered(frame, "🥚", UDim2.fromOffset(50, 50), UDim2.fromOffset(SIZE.X / 2 - 25, -18), 40)
	local title = centered(frame, "REBIRTH", UDim2.fromOffset(300, 50), UDim2.fromOffset(SIZE.X / 2 - 150, 34), 46, ORANGE)
	UIKit.Stroke(title, 3, Color3.fromRGB(90, 30, 10))
	centered(frame, "Rise from the lava, stronger than before", UDim2.fromOffset(SIZE.X - 40, 24), UDim2.fromOffset(20, 86), 18, C.SubText)

	-- Nivel
	local levelTitle = UIKit.Label(frame, "REBIRTH LEVEL", UDim2.fromOffset(150, 30), UDim2.fromOffset(78, 118), 18, C.Text)
	levelTitle.TextXAlignment = Enum.TextXAlignment.Right
	levelLabel = pill(frame, "0 → 1", UDim2.fromOffset(100, 30), UDim2.fromOffset(240, 118), Color3.fromRGB(24, 18, 16), 20)
	pill(frame, "∞ UNLIMITED", UDim2.fromOffset(130, 30), UDim2.fromOffset(352, 118), ORANGE, 17)

	-- Qué ganás
	local get = card(frame, "YOU GET", GREEN, 24)
	local getText = UIKit.Label(get, "💰 Your creatures make more coins forever", UDim2.fromOffset(144, 56), UDim2.fromOffset(8, 18), 15)
	getText.TextWrapped = true
	getText.TextTruncate = Enum.TextTruncate.None
	local bonusBox = Instance.new("Frame")
	bonusBox.Size = UDim2.fromOffset(144, 104)
	bonusBox.Position = UDim2.fromOffset(8, 80)
	bonusBox.BackgroundColor3 = Color3.fromRGB(30, 50, 34)
	bonusBox.Parent = get
	UIKit.Corner(bonusBox, 10)
	centered(bonusBox, "Coin bonus", UDim2.fromOffset(144, 22), UDim2.fromOffset(0, 6), 15, C.SubText)
	bonusLabel = centered(bonusBox, "X1.00 → X1.25", UDim2.fromOffset(144, 36), UDim2.fromOffset(0, 28), 19, C.Gold)
	UIKit.Stroke(bonusLabel, 1.5)
	bonusNote = centered(bonusBox, "", UDim2.fromOffset(136, 36), UDim2.fromOffset(4, 64), 13, C.SubText)
	bonusNote.TextWrapped = true
	bonusNote.TextTruncate = Enum.TextTruncate.None

	-- Qué perdés y qué conservás
	local lose = card(frame, "YOU LOSE", RED, 198)
	row(lose, 1, "⊘", RED, "Your coins")
	row(lose, 2, "⊘", Color3.fromRGB(150, 90, 230), "Incubation speed")
	row(lose, 3, "⊘", RED, "Walk speed")
	local keep = card(frame, "YOU KEEP", BLUE, 372)
	row(keep, 1, "✓", GREEN, "Your creatures")
	row(keep, 2, "✓", C.Gold, "Your eggs")
	row(keep, 3, "✓", BLUE, "Your incubators")

	-- Plata y barra
	UIKit.Label(frame, "Your coins", UDim2.fromOffset(120, 24), UDim2.fromOffset(28, 374), 16, C.SubText)
	coinsLabel = UIKit.Label(frame, "", UDim2.fromOffset(380, 24), UDim2.fromOffset(152, 374), 15, C.SubText)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromOffset(SIZE.X - 56, 18)
	bar.Position = UDim2.fromOffset(28, 402)
	bar.BackgroundColor3 = Color3.fromRGB(24, 18, 16)
	bar.Parent = frame
	UIKit.Corner(bar, 9)
	barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = ORANGE
	barFill.Parent = bar
	UIKit.Corner(barFill, 9)

	-- Botón grande
	button = UIKit.Button(frame, "", UDim2.fromOffset(400, 62), UDim2.fromOffset((SIZE.X - 400) / 2, 436), 30, ORANGE)
	local buttonText = UIKit.Label(button, "↻ REBIRTH", UDim2.fromOffset(200, 62), UDim2.fromOffset(24, 0), 30)
	UIKit.Stroke(buttonText, 2.5)
	priceLabel = pill(button, "💰 100,000", UDim2.fromOffset(150, 36), UDim2.fromOffset(232, 13), Color3.fromRGB(70, 36, 20), 20)
	priceLabel.TextColor3 = C.Gold
	button.Activated:Connect(function()
		if os.clock() - lastClick < 0.5 then
			return
		end
		lastClick = os.clock()
		rebirthRemote:FireServer("Rebirth")
	end)

	for _, name in { "Coins", "Rebirths" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if gui.Enabled then
				refresh()
			end
		end)
	end
	SideMenu.Bind("Rebirth", RebirthPanel.Open)
	local function updateButton()
		SideMenu.SetText("Rebirth", `Rebirth [{number("Rebirths")}]`)
		-- Si ya alcanza la plata, el botón avisa
		SideMenu.SetBadge("Rebirth", if number("Coins") >= Config.RebirthCost(number("Rebirths")) then "READY!" else nil, Color3.fromRGB(108, 255, 77))
	end
	player:GetAttributeChangedSignal("Rebirths"):Connect(updateButton)
	player:GetAttributeChangedSignal("Coins"):Connect(updateButton)
	updateButton()
	-- Cualquier botón con la etiqueta "RebirthPrompt" en el mapa también abre esta ventana
	local function setupPrompt(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(RebirthPanel.Open)
		end
	end
	for _, prompt in CollectionService:GetTagged("RebirthPrompt") do
		setupPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("RebirthPrompt"):Connect(setupPrompt)
end

return RebirthPanel

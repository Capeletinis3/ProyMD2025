--!strict
-- SpinPanel: la ventana de la ruleta (botón SPIN del HUD).
-- La ruleta tiene los premios de Config.Spin.Prizes. "SPIN!" le PIDE al servidor un giro: el servidor elige el premio,
-- lo da y contesta cuál fue; acá solo la hacemos girar hasta caer en ese premio (ver SpinService).
-- Muestra si tenés el giro gratis del día (o cuánto falta), cuántos giros extra tenés y el botón para comprar uno.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)
local Notifier = require(script.Parent.Notifier)

local player = Players.LocalPlayer
local spinRemote = Remotes.Event("Spin")
local C = UIKit.Colors

local SpinPanel = {}

local SIZE = Vector2.new(620, 640)
local WHEEL = 340
local PINK = Color3.fromRGB(255, 95, 162)
local DARK = Color3.fromRGB(42, 10, 26)

local gui: ScreenGui
local wheel: Frame
local statusLabel: TextLabel
local tokensLabel: TextLabel
local resultLabel: TextLabel
local spinButton: TextButton
local spinning = false
local waiting = false -- pedimos un giro y el servidor todavía no contestó
local lastClick = 0

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function freeIn(): number
	return math.max(0, number("NextFreeSpinAt") - Workspace:GetServerTimeNow())
end

local function canSpin(): boolean
	return freeIn() <= 0 or number("SpinTokens") > 0
end

local function clock(seconds: number): string
	local s = math.ceil(seconds)
	return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
end

local function refresh()
	local free = freeIn() <= 0
	statusLabel.Text = if free then "🎁 FREE SPIN READY!" else `Next free spin in {clock(freeIn())}`
	statusLabel.TextColor3 = if free then Color3.fromRGB(108, 255, 77) else C.SubText
	tokensLabel.Text = `Extra spins: {number("SpinTokens")}`
	spinButton.BackgroundColor3 = if canSpin() and not spinning then C.Green else C.Gray
	spinButton.Text = if spinning then "..." else "SPIN!"
	SideMenu.SetBadge("Spin", if free then "FREE!" elseif number("SpinTokens") > 0 then `x{number("SpinTokens")}` else nil)
end

-- Hace girar la ruleta hasta que el premio "index" quede abajo de la flechita de arriba
local function spinTo(index: number, text: string)
	local count = #Config.Spin.Prizes
	local segment = 360 / count
	local center = (index - 0.5) * segment
	local current = wheel.Rotation % 360
	local target = -center + math.random(-segment * 0.3, segment * 0.3)
	local turns = 360 * 5
	local finalRotation = current + turns + ((target - current) % 360)
	wheel.Rotation = current
	local tween = TweenService:Create(wheel, TweenInfo.new(Config.Spin.SpinTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = finalRotation })
	tween.Completed:Connect(function()
		spinning = false
		resultLabel.Text = text
		resultLabel.Visible = true
		Notifier.Show(text, 5)
		refresh()
	end)
	tween:Play()
end

function SpinPanel.Open()
	resultLabel.Visible = false
	refresh()
	gui.Enabled = true
end

function SpinPanel.Start()
	local frame
	gui, frame = UIKit.Window("SpinPanel", "", SIZE, 7)
	frame.BackgroundColor3 = Color3.fromRGB(58, 20, 46)
	local border = frame:FindFirstChildOfClass("UIStroke")
	if border then
		border.Color = PINK
	end
	local title = UIKit.Outlined(frame, "SPIN THE WHEEL", UDim2.fromOffset(SIZE.X - 140, 50), UDim2.fromOffset(40, 16), 40, PINK, 3.5)
	local titleStroke = title:FindFirstChildOfClass("UIStroke")
	if titleStroke then
		titleStroke.Color = DARK
	end

	-- La ruleta con los premios (las etiquetas giran con ella)
	local colors = {}
	for _, prize in Config.Spin.Prizes do
		table.insert(colors, prize.Color)
	end
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromOffset(WHEEL, WHEEL)
	holder.Position = UDim2.fromOffset((SIZE.X - WHEEL) / 2, 96)
	holder.BackgroundTransparency = 1
	holder.Parent = frame
	wheel = UIKit.Wheel(holder, WHEEL, colors)
	local segment = 360 / #Config.Spin.Prizes
	for i, prize in Config.Spin.Prizes do
		local angle = math.rad((i - 0.5) * segment - 90) -- 0° = arriba, en el sentido del reloj
		local r = WHEEL * 0.32
		local label = UIKit.Outlined(wheel, `{prize.Icon}\n{prize.DisplayName}`, UDim2.fromOffset(110, 46), UDim2.new(0.5, math.cos(angle) * r - 55, 0.5, math.sin(angle) * r - 23), 15, nil, 2)
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None
		label.Rotation = (i - 0.5) * segment
		label.ZIndex = 2
	end
	local pointer = UIKit.Outlined(frame, "▼", UDim2.fromOffset(60, 52), UDim2.fromOffset(SIZE.X / 2 - 30, 64), 44, Color3.fromRGB(229, 57, 53), 3)
	pointer.ZIndex = 6

	resultLabel = UIKit.Outlined(frame, "", UDim2.fromOffset(SIZE.X - 60, 34), UDim2.fromOffset(30, 446), 20, Color3.fromRGB(255, 225, 77), 2.5)
	resultLabel.TextWrapped = true
	resultLabel.Visible = false
	statusLabel = UIKit.Outlined(frame, "", UDim2.fromOffset(SIZE.X - 60, 30), UDim2.fromOffset(30, 482), 22, nil, 2.5)
	tokensLabel = UIKit.Label(frame, "", UDim2.fromOffset(200, 30), UDim2.fromOffset(40, 520), 18, C.SubText)

	spinButton = UIKit.Button(frame, "SPIN!", UDim2.fromOffset(250, 64), UDim2.fromOffset(40, 556), 34, C.Green)
	spinButton.Activated:Connect(function()
		if spinning or os.clock() - lastClick < 0.5 or not canSpin() then
			return
		end
		lastClick = os.clock()
		spinning = true
		waiting = true
		resultLabel.Visible = false
		refresh()
		spinRemote:FireServer("Spin")
		-- Si el servidor no contesta (por ejemplo, no te quedaban giros), destrabamos el botón
		task.delay(3, function()
			if waiting then
				waiting = false
				spinning = false
				refresh()
			end
		end)
	end)
	local buy = UIKit.Button(frame, `Buy 1 spin · R${Config.Spin.PriceRobux}`, UDim2.fromOffset(250, 64), UDim2.fromOffset(SIZE.X - 290, 556), 22, Color3.fromRGB(255, 159, 26))
	buy.Activated:Connect(function()
		if os.clock() - lastClick >= 0.5 then
			lastClick = os.clock()
			spinRemote:FireServer("Buy")
		end
	end)

	spinRemote.OnClientEvent:Connect(function(action: unknown, index: unknown, text: unknown)
		if action == "Result" and typeof(index) == "number" and typeof(text) == "string" and Config.Spin.Prizes[index] then
			waiting = false
			spinning = true
			if not gui.Enabled then
				SpinPanel.Open()
			end
			spinTo(index, text)
		end
	end)
	for _, name in { "NextFreeSpinAt", "SpinTokens" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	SideMenu.Bind("Spin", SpinPanel.Open)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 then
			elapsed = 0
			refresh()
		end
	end)
	refresh()
end

return SpinPanel

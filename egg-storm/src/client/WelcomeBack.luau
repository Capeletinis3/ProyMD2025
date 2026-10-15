--!strict
-- WelcomeBack: el cartel "Welcome back!" que muestra cuánto ganaron tus mascotas mientras no estabas.
-- La plata ya la sumó el servidor al cargar tus datos (ver PlayerDataService); este cartel solo lo cuenta.
-- Lee los atributos del jugador "OfflineCoins" y "OfflineSeconds".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local C = UIKit.Colors

local WelcomeBack = {}

local WIDTH, HEIGHT = 500, 300
local shown = false

-- 8100 segundos -> "2h 15m"
local function formatDuration(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local hours = minutes // 60
	minutes = minutes % 60
	if hours > 0 and minutes > 0 then
		return `{hours}h {minutes}m`
	elseif hours > 0 then
		return `{hours}h`
	end
	return `{math.max(1, minutes)}m`
end

local function show(coins: number, seconds: number)
	if shown then
		return
	end
	shown = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "WelcomeBack"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.45)
	frame.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	frame.BackgroundColor3 = C.Panel
	frame.Parent = gui
	UIKit.Corner(frame, 22)
	UIKit.Stroke(frame, 4, C.Gold)
	UIKit.FitToScreen(frame, Vector2.new(WIDTH, HEIGHT))

	local function centered(text: string, y: number, height: number, size: number, color: Color3): TextLabel
		local label = UIKit.Label(frame, text, UDim2.fromOffset(WIDTH - 40, height), UDim2.fromOffset(20, y), size, color)
		label.TextXAlignment = Enum.TextXAlignment.Center
		return label
	end
	centered("Welcome back!", 22, 46, 38, C.Accent)
	centered("While you were away, your creatures made", 76, 28, 20, C.SubText)
	local amount = centered(`🪙 +{Format.Number(coins)}`, 108, 64, 52, C.Gold)
	UIKit.Stroke(amount, 3)
	local percent = math.round(Config.Economy.OfflineRate * 100)
	centered(`Away for {formatDuration(seconds)} · {percent}% speed · max {Config.Economy.OfflineMaxHours}h`, 176, 26, 17, C.SubText)

	local button = UIKit.Button(frame, "Collect!", UDim2.fromOffset(200, 56), UDim2.fromOffset((WIDTH - 200) / 2, 218), 26, C.Green)

	-- Entra con un "pop"
	local pop = frame:FindFirstChildOfClass("UIScale")
	local fit = if pop then pop.Scale else 1
	if pop then
		pop.Scale = 0
		TweenService:Create(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
	end

	button.Activated:Connect(function()
		gui:Destroy()
	end)
end

local function check()
	local coins = player:GetAttribute("OfflineCoins")
	local seconds = player:GetAttribute("OfflineSeconds")
	if typeof(coins) == "number" and coins > 0 and typeof(seconds) == "number" then
		show(coins, seconds)
	end
end

function WelcomeBack.Start()
	player:GetAttributeChangedSignal("OfflineCoins"):Connect(check)
	check()
end

return WelcomeBack

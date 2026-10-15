--!strict
-- Hud: lo que siempre está en pantalla.
--   Abajo a la izquierda: tu plata (salta cuando sube) y cuánto ganás por segundo.
--   Arriba de la plata: qué huevo estás llevando (con el color de su rareza).
-- Lee los atributos que publica el servidor: Coins, Income y CarriedEggRarity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local C = UIKit.Colors

local Hud = {}

local coinsLabel: TextLabel
local incomeLabel: TextLabel
local coinsScale: UIScale
local carryPill: Frame
local carryLabel: TextLabel
local lastCoins = 0

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function onCoinsChanged()
	local coins = number("Coins")
	coinsLabel.Text = Format.Number(coins)
	-- Saltito cuando sube la plata
	if coins > lastCoins then
		coinsScale.Scale = 1.12
		TweenService:Create(coinsScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	lastCoins = coins
end

local function onIncomeChanged()
	incomeLabel.Text = `+{Format.Number(number("Income"))} / sec`
end

local function onCarryChanged()
	local rarityId = player:GetAttribute("CarriedEggRarity")
	local rarity = if typeof(rarityId) == "string" then Config.GetRarity(rarityId) else nil
	carryPill.Visible = rarity ~= nil
	if rarity then
		carryLabel.Text = `🥚 Carrying: {rarity.DisplayName} Egg`
		carryLabel.TextColor3 = if rarity.Id == "Secret" then Color3.fromRGB(230, 200, 255) else rarity.Color
	end
end

function Hud.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Contenedor abajo a la izquierda (tamaño fijo, se achica en pantallas chicas)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, 16, 1, -16)
	holder.Size = UDim2.fromOffset(320, 130)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	UIKit.FitToScreen(holder, Vector2.new(320, 130), Vector2.new(400, 300))

	-- Plata
	local coinsPill = Instance.new("Frame")
	coinsPill.AnchorPoint = Vector2.new(0, 1)
	coinsPill.Position = UDim2.fromScale(0, 1)
	coinsPill.Size = UDim2.fromOffset(280, 76)
	coinsPill.BackgroundColor3 = C.Panel
	coinsPill.BackgroundTransparency = 0.1
	coinsPill.Parent = holder
	UIKit.Corner(coinsPill, 18)
	UIKit.Stroke(coinsPill, 3, C.Gold)
	coinsScale = Instance.new("UIScale")
	coinsScale.Parent = coinsPill

	local icon = UIKit.Label(coinsPill, "🪙", UDim2.fromOffset(56, 56), UDim2.fromOffset(10, 10), 40)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	coinsLabel = UIKit.Label(coinsPill, "0", UDim2.fromOffset(200, 40), UDim2.fromOffset(70, 6), 34, C.Gold)
	UIKit.Stroke(coinsLabel, 2)
	incomeLabel = UIKit.Label(coinsPill, "+0 / sec", UDim2.fromOffset(200, 24), UDim2.fromOffset(72, 46), 20, Color3.fromRGB(130, 255, 130))

	-- Huevo que estás llevando
	carryPill = Instance.new("Frame")
	carryPill.AnchorPoint = Vector2.new(0, 1)
	carryPill.Position = UDim2.new(0, 0, 1, -86)
	carryPill.Size = UDim2.fromOffset(320, 40)
	carryPill.BackgroundColor3 = C.Panel
	carryPill.BackgroundTransparency = 0.1
	carryPill.Visible = false
	carryPill.Parent = holder
	UIKit.Corner(carryPill, 14)
	carryLabel = UIKit.Label(carryPill, "", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), 20)
	UIKit.Stroke(carryLabel, 1.5)

	player:GetAttributeChangedSignal("Coins"):Connect(onCoinsChanged)
	player:GetAttributeChangedSignal("Income"):Connect(onIncomeChanged)
	player:GetAttributeChangedSignal("CarriedEggRarity"):Connect(onCarryChanged)
	lastCoins = number("Coins")
	onCoinsChanged()
	onIncomeChanged()
	onCarryChanged()
end

return Hud

--!strict
-- ShopPanel: la Tienda (botón "Shop" del HUD): lo que se compra con Robux.
--   * Lucky Spin: un giro extra de la ruleta (Developer Product, ver SpinService)
--   * VIP Pass y Gift VIP: abren la ventana del VIP (ver VipPanel)
-- Los botones solo PIDEN la compra: Roblox cobra y el servidor entrega.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)
local VipPanel = require(script.Parent.VipPanel)

local spinRemote = Remotes.Event("Spin")
local C = UIKit.Colors

local ShopPanel = {}

local SIZE = Vector2.new(720, 400)
local CARD = Vector2.new(208, 270)

local gui: ScreenGui
local opened = false

local function card(parent: Frame, index: number, icon: string, title: string, description: string, price: string, color: Color3, onBuy: () -> ())
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	frame.Position = UDim2.fromOffset(24 + (index - 1) * (CARD.X + 20), 92)
	frame.BackgroundColor3 = C.Row
	frame.Parent = parent
	UIKit.Corner(frame, 16)
	UIKit.Stroke(frame, 3, color)
	local emoji = UIKit.Label(frame, icon, UDim2.fromOffset(CARD.X, 80), UDim2.fromOffset(0, 10), 60)
	emoji.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.Outlined(frame, title, UDim2.fromOffset(CARD.X - 16, 30), UDim2.fromOffset(8, 94), 24, color, 2.5)
	local text = UIKit.Label(frame, description, UDim2.fromOffset(CARD.X - 24, 60), UDim2.fromOffset(12, 126), 15, C.SubText)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextWrapped = true
	text.TextTruncate = Enum.TextTruncate.None
	local button = UIKit.Button(frame, price, UDim2.fromOffset(CARD.X - 32, 52), UDim2.fromOffset(16, CARD.Y - 68), 22, C.Green)
	button.Activated:Connect(onBuy)
end

function ShopPanel.Open()
	if not opened then
		opened = true
		SideMenu.SetBadge("Shop", nil)
	end
	gui.Enabled = true
end

function ShopPanel.Start()
	local frame
	gui, frame = UIKit.Window("ShopPanel", "🛍️ SHOP", SIZE, 6)
	card(frame, 1, "🎡", "Lucky Spin", "One extra spin of the wheel: coins, potions or eggs!", `R$ {Config.Spin.PriceRobux}`, Color3.fromRGB(255, 95, 162), function()
		spinRemote:FireServer("Buy")
	end)
	card(frame, 2, "👑", "VIP Pass", "x2 coins, faster hatching, a daily egg and +1 egg to carry.", `R$ {Config.Vip.PriceRobux}`, Color3.fromRGB(255, 194, 26), function()
		gui.Enabled = false
		VipPanel.Open()
	end)
	card(frame, 3, "🎁", "Gift VIP", "Give VIP to a friend in this server.", "Choose friend", Color3.fromRGB(77, 210, 255), function()
		gui.Enabled = false
		VipPanel.OpenGift()
	end)
	SideMenu.Bind("Shop", ShopPanel.Open)
	SideMenu.SetBadge("Shop", "NEW!")
end

return ShopPanel

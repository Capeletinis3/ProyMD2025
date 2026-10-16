--!strict
-- MerchantPanel: la ventana del Comerciante misterioso (se abre con "Open" en su puesto del lobby).
-- Muestra las ofertas de esta tanda (las publica el servidor en Workspace.MerchantOffers),
-- cuánto falta para la próxima y cuáles ya compraste. "Buy" solo PIDE la compra (ver MerchantService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local merchantRemote = Remotes.Event("Merchant")
local C = UIKit.Colors

local MerchantPanel = {}

local SIZE = Vector2.new(760, 430)
local CARD = Vector2.new(220, 300)
local CLOSE_DISTANCE = 22

type Card = { Frame: Frame, Egg: Frame, Name: TextLabel, Income: TextLabel, Button: TextButton }
type Offer = { RarityId: string, VariantId: string, Price: number }

local gui: ScreenGui
local timerLabel: TextLabel
local cards: { Card } = {}
local openPart: BasePart? = nil
local lastClick = 0

local function parseOffers(): { Offer }
	local text = Workspace:GetAttribute("MerchantOffers")
	local result: { Offer } = {}
	if typeof(text) ~= "string" then
		return result
	end
	for _, chunk in string.split(text, ";") do
		local fields = string.split(chunk, ":")
		local price = tonumber(fields[3])
		if #fields == 3 and price then
			table.insert(result, { RarityId = fields[1], VariantId = fields[2], Price = price })
		end
	end
	return result
end

local function boughtSet(): { [number]: boolean }
	local text = player:GetAttribute("MerchantBought")
	local set: { [number]: boolean } = {}
	if typeof(text) == "string" then
		for _, n in string.split(text, ",") do
			local index = tonumber(n)
			if index then
				set[index] = true
			end
		end
	end
	return set
end

local function refresh()
	local offers = parseOffers()
	local sold = boughtSet()
	local coinsValue = player:GetAttribute("Coins")
	local coins = if typeof(coinsValue) == "number" then coinsValue else 0
	for i, card in cards do
		local offer = offers[i]
		card.Frame.Visible = offer ~= nil
		if offer then
			local rarity = Config.GetRarity(offer.RarityId)
			local variant = Config.GetVariant(offer.VariantId)
			if rarity then
				card.Egg.BackgroundColor3 = if variant.Id ~= "Normal" then variant.Color else rarity.Color
				card.Name.Text = Config.WithVariant(variant, rarity.DisplayName .. " Egg")
				card.Name.TextColor3 = if variant.Id ~= "Normal" then variant.Color elseif rarity.Id == "Secret" then C.Text else rarity.Color
				card.Income.Text = `Creature: +{Format.Compact(Config.GetIncome(rarity, variant))}/s`
			end
			if sold[i] then
				card.Button.Text = "SOLD"
				card.Button.BackgroundColor3 = C.Gray
			else
				card.Button.Text = `Buy  {Format.Compact(offer.Price)}`
				card.Button.BackgroundColor3 = if coins >= offer.Price then C.Green else C.Red
			end
		end
	end
end

local function updateTimer()
	local at = Workspace:GetAttribute("MerchantRestockAt")
	local left = if typeof(at) == "number" then math.max(0, at - Workspace:GetServerTimeNow()) else 0
	local s = math.ceil(left)
	timerLabel.Text = string.format("New stock in %d:%02d", s // 60, s % 60)
end

function MerchantPanel.Open(part: BasePart?)
	openPart = part
	refresh()
	updateTimer()
	gui.Enabled = true
end

local function buildCard(frame: Frame, index: number): Card
	local x = 28 + (index - 1) * (CARD.X + 16)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	card.Position = UDim2.fromOffset(x, 106)
	card.BackgroundColor3 = C.Row
	card.Parent = frame
	UIKit.Corner(card, 16)

	-- "Huevo" de color (un óvalo)
	local egg = Instance.new("Frame")
	egg.AnchorPoint = Vector2.new(0.5, 0)
	egg.Position = UDim2.fromOffset(CARD.X / 2, 18)
	egg.Size = UDim2.fromOffset(84, 108)
	egg.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = egg
	UIKit.Stroke(egg, 3, Color3.fromRGB(20, 20, 30))

	local name = UIKit.Label(card, "", UDim2.fromOffset(CARD.X - 16, 56), UDim2.fromOffset(8, 134), 22)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextWrapped = true
	name.TextTruncate = Enum.TextTruncate.None
	UIKit.Stroke(name, 1.5)
	local income = UIKit.Label(card, "", UDim2.fromOffset(CARD.X - 16, 28), UDim2.fromOffset(8, 192), 20, Color3.fromRGB(130, 255, 130))
	income.TextXAlignment = Enum.TextXAlignment.Center

	local button = UIKit.Button(card, "Buy", UDim2.fromOffset(CARD.X - 32, 50), UDim2.fromOffset(16, CARD.Y - 66), 24, C.Green)
	button.Activated:Connect(function()
		if os.clock() - lastClick < 0.4 then
			return
		end
		lastClick = os.clock()
		merchantRemote:FireServer("Buy", index)
	end)
	return { Frame = card, Egg = egg, Name = name, Income = income, Button = button }
end

local function setupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function()
		local part = prompt.Parent
		MerchantPanel.Open(if part and part:IsA("BasePart") then part else nil)
	end)
end

function MerchantPanel.Start()
	local frame
	gui, frame = UIKit.Window("MerchantPanel", "MYSTERY MERCHANT", SIZE, 6)
	timerLabel = UIKit.Label(frame, "", UDim2.fromOffset(400, 30), UDim2.fromOffset(28, 66), 22, C.SubText)
	for i = 1, Config.Merchant.OfferCount do
		table.insert(cards, buildCard(frame, i))
	end

	for _, prompt in CollectionService:GetTagged("MerchantPrompt") do
		setupPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("MerchantPrompt"):Connect(setupPrompt)

	Workspace:GetAttributeChangedSignal("MerchantOffers"):Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
	for _, name in { "Coins", "MerchantBought" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if gui.Enabled then
				refresh()
			end
		end)
	end
	RunService.Heartbeat:Connect(function()
		if not gui.Enabled then
			return
		end
		updateTimer()
		-- Si te alejás del puesto, se cierra
		local part = openPart
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if part and (not root or not root:IsA("BasePart") or (root.Position - part.Position).Magnitude > CLOSE_DISTANCE) then
			gui.Enabled = false
		end
	end)
end

return MerchantPanel

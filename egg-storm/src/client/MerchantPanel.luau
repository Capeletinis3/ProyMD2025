--!strict
-- MerchantPanel: la ventana del Comerciante misterioso v2 (ícono MYSTERY MERCHANT del HUD o "Open" en su puesto).
-- Fondo de noche con estrellas, el comerciante que te habla, cuánto falta para las ofertas nuevas, el botón "Renew"
-- y 2 estantes con 3 ofertas cada uno (huevos, huevo misterioso y pociones), con su stock y el sello SOLD OUT.
-- Lee lo que publica el servidor (Player.MerchantOffers, MerchantRenewPrice y Workspace.MerchantRestockAt).
-- "Buy" y "Renew" solo PIDEN: el servidor revisa todo (ver MerchantService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)

local player = Players.LocalPlayer
local merchantRemote = Remotes.Event("Merchant")
local C = UIKit.Colors

local MerchantPanel = {}

local SIZE = Vector2.new(960, 600)
local CARD = Vector2.new(282, 196)
local NIGHT = Color3.fromRGB(28, 16, 54)
local PURPLE = Color3.fromRGB(176, 38, 255)
local LILAC = Color3.fromRGB(199, 125, 255)
local SHELF = Color3.fromRGB(139, 90, 43)
local CLOSE_DISTANCE = 22
local MYSTERY_COLOR = Color3.fromRGB(176, 38, 255)

type Card = {
	Frame: Frame, Tag: TextLabel, Icon: Frame, IconText: TextLabel, Image: ImageLabel, Name: TextLabel, Description: TextLabel,
	Button: TextButton, Left: TextLabel, SoldOut: TextLabel,
}
type Offer = { Kind: string, Id: string, VariantId: string, Price: number, Left: number }

local gui: ScreenGui
local timerLabel: TextLabel
local renewButton: TextButton
local cards: { Card } = {}
local openPart: BasePart? = nil
local lastClick = 0

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function parseOffers(): { Offer }
	local text = player:GetAttribute("MerchantOffers")
	local result: { Offer } = {}
	if typeof(text) ~= "string" then
		return result
	end
	for _, chunk in string.split(text, ";") do
		local fields = string.split(chunk, ":")
		local price, left = tonumber(fields[4]), tonumber(fields[5])
		if #fields == 5 and price and left then
			table.insert(result, { Kind = fields[1], Id = fields[2], VariantId = fields[3], Price = price, Left = left })
		end
	end
	return result
end

local function rarityColor(rarity: Config.Rarity): Color3
	return if rarity.Id == "Secret" then Color3.fromRGB(163, 91, 255) else rarity.Color
end

local function showOffer(card: Card, offer: Offer, coins: number)
	local tagText, tagColor, iconColor, iconText, name, description
	if offer.Kind == "Potion" then
		local info = (Config.Potions :: any)[offer.Id]
		tagText, tagColor = "Potion", Color3.fromRGB(22, 163, 74)
		iconColor, iconText = info.Color, info.Icon
		name, description = info.DisplayName, info.Description
		if offer.Id == "FastNest" then
			tagColor = Color3.fromRGB(37, 99, 235)
		end
	elseif offer.Kind == "Mystery" then
		tagText, tagColor = "???", Color3.fromRGB(123, 47, 208)
		iconColor, iconText = MYSTERY_COLOR, "?"
		name, description = "Mystery Egg", "Could be any rarity"
	else
		local rarity = Config.GetRarity(offer.Id) or Config.Rarities[2]
		local variant = Config.GetVariant(offer.VariantId)
		local info = Config.Merchant.EggNames[rarity.Id]
		tagText, tagColor = rarity.DisplayName, rarityColor(rarity)
		iconColor = if variant.Id ~= "Normal" then variant.Color else rarityColor(rarity)
		iconText = ""
		name = Config.WithVariant(variant, if info then info.Name else rarity.DisplayName .. " Egg")
		description = if info then info.Description else ""
		if variant.Id ~= "Normal" then
			description = `{description} · x{variant.Multiplier} coins`
		end
	end
	card.Tag.Text = tagText
	card.Tag.BackgroundColor3 = tagColor
	card.Icon.BackgroundColor3 = iconColor
	card.IconText.Text = iconText
	-- Si ya subiste las imágenes del diseño, se ve la imagen (el huevo y la poción se pintan del color de la oferta)
	local imageKey = if offer.Kind == "Potion" then "Potion" elseif offer.Kind == "Mystery" then "MysteryEgg" else "Egg"
	local imageId = UIKit.ImageId(imageKey)
	card.Image.Visible = imageId ~= nil
	card.Icon.Visible = imageId == nil
	if imageId then
		card.Image.Image = imageId
		card.Image.ImageColor3 = if offer.Kind == "Mystery" then Color3.new(1, 1, 1) else iconColor
	end
	card.Name.Text = name
	card.Description.Text = description
	local soldOut = offer.Left <= 0
	card.SoldOut.Visible = soldOut
	card.Left.Text = `Left {math.max(0, offer.Left)}`
	card.Left.TextColor3 = if soldOut then C.Red else C.SubText
	card.Button.Text = `💰 {Format.Compact(offer.Price)}`
	card.Button.BackgroundColor3 = if soldOut then C.Gray elseif coins >= offer.Price then C.Green else C.Red
	card.Frame.BackgroundTransparency = if soldOut then 0.35 else 0
end

local function refresh()
	local offers = parseOffers()
	local coins = number("Coins")
	for i, card in cards do
		local offer = offers[i]
		card.Frame.Visible = offer ~= nil
		if offer then
			showOffer(card, offer, coins)
		end
	end
	local renew = number("MerchantRenewPrice")
	renewButton.Text = `↻ Renew · {Format.Compact(renew)}`
	renewButton.BackgroundColor3 = if coins >= renew then Color3.fromRGB(255, 159, 26) else C.Gray
end

local function updateTimer()
	local at = Workspace:GetAttribute("MerchantRestockAt")
	local left = if typeof(at) == "number" then math.max(0, at - Workspace:GetServerTimeNow()) else 0
	local s = math.ceil(left)
	timerLabel.Text = string.format("New offers in %d:%02d", s // 60, s % 60)
end

local function clicked(): boolean
	if os.clock() - lastClick < 0.3 then
		return false
	end
	lastClick = os.clock()
	return true
end

-- Tarjeta de una oferta (va arriba de un estante de madera)
local function buildCard(parent: Frame, index: number): Card
	local column = (index - 1) % 3
	local row = (index - 1) // 3
	local frame = Instance.new("Frame")
	frame.Name = `Offer{index}`
	frame.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	frame.Position = UDim2.fromOffset(24 + column * (CARD.X + 21), 158 + row * (CARD.Y + 30))
	frame.BackgroundColor3 = Color3.fromRGB(46, 30, 86)
	frame.Parent = parent
	UIKit.Corner(frame, 14)
	UIKit.Stroke(frame, 2.5, LILAC:Lerp(Color3.new(0, 0, 0), 0.4))

	local tag = UIKit.Outlined(frame, "", UDim2.fromOffset(110, 24), UDim2.fromOffset(12, -10), 15, nil, 2)
	tag.BackgroundTransparency = 0
	UIKit.Corner(tag, 12)
	local icon = Instance.new("Frame")
	icon.Size = UDim2.fromOffset(62, 78)
	icon.Position = UDim2.fromOffset(16, 26)
	icon.Parent = frame
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = icon
	UIKit.Stroke(icon, 3, Color3.new(1, 1, 1))
	local iconText = UIKit.Outlined(icon, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 34, nil, 2.5)
	local image = Instance.new("ImageLabel")
	image.Name = "OfferImage"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromOffset(72, 86)
	image.Position = UDim2.fromOffset(11, 22)
	image.ScaleType = Enum.ScaleType.Fit
	image.Visible = false
	image.Parent = frame
	local name = UIKit.Label(frame, "", UDim2.fromOffset(CARD.X - 104, 30), UDim2.fromOffset(92, 28), 21)
	UIKit.Stroke(name, 2, Color3.fromRGB(17, 17, 17))
	local description = UIKit.Label(frame, "", UDim2.fromOffset(CARD.X - 104, 44), UDim2.fromOffset(92, 58), 14, C.SubText)
	description.TextWrapped = true
	description.TextTruncate = Enum.TextTruncate.None
	description.TextYAlignment = Enum.TextYAlignment.Top
	local button = UIKit.Button(frame, "", UDim2.fromOffset(150, 44), UDim2.fromOffset(16, CARD.Y - 62), 21, C.Green)
	local left = UIKit.Label(frame, "", UDim2.fromOffset(96, 44), UDim2.fromOffset(176, CARD.Y - 62), 16, C.SubText)
	left.TextXAlignment = Enum.TextXAlignment.Center
	local soldOut = UIKit.Outlined(frame, "SOLD OUT", UDim2.fromOffset(200, 44), UDim2.fromOffset((CARD.X - 200) / 2, 64), 34, Color3.fromRGB(255, 59, 59), 3)
	soldOut.Rotation = -12
	soldOut.Visible = false
	soldOut.ZIndex = 5
	button.Activated:Connect(function()
		if clicked() then
			merchantRemote:FireServer("Buy", index)
		end
	end)
	return {
		Frame = frame, Tag = tag, Icon = icon, IconText = iconText, Image = image, Name = name, Description = description,
		Button = button, Left = left, SoldOut = soldOut,
	}
end

local function close()
	gui.Enabled = false
	openPart = nil
end

function MerchantPanel.Open(part: BasePart?)
	openPart = part
	refresh()
	updateTimer()
	gui.Enabled = true
end

local function setupPrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function()
			local part = prompt.Parent
			MerchantPanel.Open(if part and part:IsA("BasePart") then part else nil)
		end)
	end
end

function MerchantPanel.Start()
	local frame
	gui, frame = UIKit.Window("MerchantPanel", "", SIZE, 6)
	frame.BackgroundColor3 = NIGHT
	local border = frame:FindFirstChildOfClass("UIStroke")
	if border then
		border.Color = PURPLE
	end
	-- Estrellitas
	local starRng = Random.new(7)
	for _ = 1, 26 do
		local star = Instance.new("Frame")
		local size = starRng:NextInteger(2, 5)
		star.Size = UDim2.fromOffset(size, size)
		star.Position = UDim2.fromOffset(starRng:NextInteger(10, SIZE.X - 10), starRng:NextInteger(10, SIZE.Y - 10))
		star.BackgroundColor3 = Color3.fromRGB(255, 240, 200)
		star.BackgroundTransparency = starRng:NextNumber(0.2, 0.6)
		star.BorderSizePixel = 0
		star.Parent = frame
	end
	-- Título con la carpa
	local tent = UIKit.Label(frame, "🎪", UDim2.fromOffset(70, 70), UDim2.fromOffset(20, 8), 52)
	tent.TextXAlignment = Enum.TextXAlignment.Center
	local title = UIKit.Label(frame, "MYSTERY MERCHANT", UDim2.fromOffset(520, 50), UDim2.fromOffset(96, 14), 40, LILAC)
	UIKit.Stroke(title, 3, Color3.fromRGB(42, 10, 77))
	-- El comerciante habla
	local merchant = UIKit.Label(frame, "🧙", UDim2.fromOffset(60, 60), UDim2.fromOffset(24, 80), 46)
	merchant.TextXAlignment = Enum.TextXAlignment.Center
	local bubble = UIKit.Label(frame, "Psst... I have eggs you won't find in the canyon.", UDim2.fromOffset(470, 44), UDim2.fromOffset(92, 88), 19)
	bubble.TextXAlignment = Enum.TextXAlignment.Center
	bubble.BackgroundTransparency = 0
	bubble.BackgroundColor3 = Color3.fromRGB(255, 247, 230)
	bubble.TextColor3 = Color3.fromRGB(42, 22, 8)
	UIKit.Corner(bubble, 16)
	-- Reloj y botón Renew
	timerLabel = UIKit.Label(frame, "", UDim2.fromOffset(220, 26), UDim2.fromOffset(SIZE.X - 260, 76), 18, C.SubText)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Center
	renewButton = UIKit.Button(frame, "↻ Renew", UDim2.fromOffset(220, 40), UDim2.fromOffset(SIZE.X - 260, 104), 19, Color3.fromRGB(255, 159, 26))
	renewButton.Activated:Connect(function()
		if clicked() then
			merchantRemote:FireServer("Renew")
		end
	end)
	-- 2 estantes de madera con 3 ofertas cada uno
	for row = 0, 1 do
		local shelf = Instance.new("Frame")
		shelf.Size = UDim2.fromOffset(SIZE.X - 24, 14)
		shelf.Position = UDim2.fromOffset(12, 158 + row * (CARD.Y + 30) + CARD.Y - 4)
		shelf.BackgroundColor3 = SHELF
		shelf.Parent = frame
		UIKit.Corner(shelf, 4)
		UIKit.Stroke(shelf, 2, Color3.fromRGB(74, 44, 18))
	end
	for i = 1, 6 do
		table.insert(cards, buildCard(frame, i))
	end

	for _, name in { "Coins", "MerchantOffers", "MerchantRenewPrice" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if gui.Enabled then
				refresh()
			end
		end)
	end
	for _, prompt in CollectionService:GetTagged("MerchantPrompt") do
		setupPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("MerchantPrompt"):Connect(setupPrompt)
	SideMenu.Bind("Merchant", function()
		MerchantPanel.Open(nil)
	end)

	RunService.Heartbeat:Connect(function()
		if not gui.Enabled then
			return
		end
		updateTimer()
		-- Si la abriste en el puesto y te alejás, se cierra sola (desde el HUD queda abierta)
		local part = openPart
		if part then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") or (root.Position - part.Position).Magnitude > CLOSE_DISTANCE then
				close()
			end
		end
	end)
end

return MerchantPanel

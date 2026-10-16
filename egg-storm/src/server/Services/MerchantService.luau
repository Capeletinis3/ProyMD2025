--!strict
-- MerchantService: el Comerciante misterioso del lobby.
-- Cada Config.Merchant.RestockInterval segundos trae ofertas nuevas: huevos especiales (Rare a Secret,
-- a veces con variante) que van directo a un nido libre de tu base. Cada jugador puede comprar cada
-- oferta una vez por tanda.
--
-- Para el cliente se publica:
--   Workspace "MerchantOffers"  = "Rareza:Variante:Precio;..."   y   "MerchantRestockAt" (hora del servidor)
--   Player    "MerchantBought"  = "1,3" (qué ofertas ya compró en esta tanda)
-- El cliente solo pide "Buy" con el número de oferta: el servidor revisa todo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local IncubatorService = require(script.Parent.IncubatorService)

export type Offer = { RarityId: string, VariantId: string, Price: number }

local MerchantService = {}

local random = Random.new()
local offers: { Offer } = {}
local bought: { [Player]: { [number]: boolean } } = {}
local lastAttempt: { [Player]: number } = {}
local counter: BasePart? = nil

local notifyRemote = Remotes.Event("Notify")
local merchantRemote = Remotes.Event("Merchant")

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

-- Precio de un huevo: lo que daría su mascota en PriceSeconds segundos
function MerchantService.PriceOf(rarity: Config.Rarity, variant: Config.Variant): number
	return math.floor(Config.GetIncome(rarity, variant) * Config.Merchant.PriceSeconds)
end

local function rollOffer(): Offer
	local weights = Config.Merchant.RarityWeights
	local total = 0
	for _, rarity in Config.Rarities do
		total += weights[rarity.Id] or 0
	end
	local roll = random:NextNumber(0, total)
	local chosen = Config.Rarities[2]
	for _, rarity in Config.Rarities do
		local weight = weights[rarity.Id] or 0
		roll -= weight
		if weight > 0 and roll <= 0 then
			chosen = rarity
			break
		end
	end
	local variant = Config.Variants[1]
	if random:NextNumber() < Config.Merchant.VariantChance then
		-- Una variante al azar (sin contar Normal), según sus pesos
		local vTotal = 0
		for i = 2, #Config.Variants do
			vTotal += Config.Variants[i].Weight
		end
		local vRoll = random:NextNumber(0, vTotal)
		for i = 2, #Config.Variants do
			vRoll -= Config.Variants[i].Weight
			if vRoll <= 0 then
				variant = Config.Variants[i]
				break
			end
		end
	end
	return { RarityId = chosen.Id, VariantId = variant.Id, Price = MerchantService.PriceOf(chosen, variant) }
end

local function publishBought(player: Player)
	local list = {}
	local mine: { [number]: boolean } = bought[player] or {}
	for index in mine do
		table.insert(list, tostring(index))
	end
	table.sort(list)
	player:SetAttribute("MerchantBought", table.concat(list, ","))
end

-- Trae ofertas nuevas (y todos pueden volver a comprar)
function MerchantService.Restock()
	offers = {}
	local parts = {}
	for i = 1, Config.Merchant.OfferCount do
		local offer = rollOffer()
		offers[i] = offer
		table.insert(parts, `{offer.RarityId}:{offer.VariantId}:{offer.Price}`)
	end
	Workspace:SetAttribute("MerchantOffers", table.concat(parts, ";"))
	Workspace:SetAttribute("MerchantRestockAt", Workspace:GetServerTimeNow() + Config.Merchant.RestockInterval)
	bought = {}
	for _, player in Players:GetPlayers() do
		publishBought(player)
	end
end

function MerchantService.GetOffers(): { Offer }
	return offers
end

local function isNearCounter(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not counter or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - counter.Position).Magnitude <= Config.Merchant.Distance + 5
end

function MerchantService.TryBuy(player: Player, index: number)
	local now = os.clock()
	if now - (lastAttempt[player] or 0) < Config.Merchant.Cooldown then
		return
	end
	lastAttempt[player] = now

	local offer = offers[index]
	local profile = PlayerDataService.Get(player)
	if not offer or not profile or not isNearCounter(player) then
		return
	end
	local mine = bought[player] or {}
	bought[player] = mine
	if mine[index] then
		notify(player, "You already bought this one! New stock soon.")
		return
	end
	local rarity = Config.GetRarity(offer.RarityId)
	local variant = Config.GetVariant(offer.VariantId)
	if not rarity then
		return
	end
	local canPlace, reason = IncubatorService.CanPlaceEgg(player)
	if not canPlace then
		notify(player, reason or "You can't buy this right now.")
		return
	end
	if not PlayerDataService.SpendCoins(player, offer.Price) then
		notify(player, `Not enough coins! You need {Format.Number(offer.Price)}.`)
		return
	end
	local placed = IncubatorService.PlaceEgg(player, rarity, variant)
	if not placed then
		PlayerDataService.AddCoins(player, offer.Price, true) -- devolución
		return
	end
	mine[index] = true
	publishBought(player)
	notify(player, `You bought a {Config.WithVariant(variant, rarity.DisplayName .. " Egg")}! It's incubating in your base.`)
end

function MerchantService.Init(map: Folder)
	local stalls = map:FindFirstChild("Stalls", true)
	local stall = stalls and stalls:FindFirstChild("Merchant")
	local part = stall and stall:FindFirstChild("Counter")
	if part and part:IsA("BasePart") then
		counter = part
	end

	merchantRemote.OnServerEvent:Connect(function(player: Player, action: unknown, index: unknown)
		-- Lo que manda el cliente no es confiable: revisamos tipo y rango
		if action == "Buy" and typeof(index) == "number" and index == math.floor(index) and index >= 1 and index <= #offers then
			MerchantService.TryBuy(player, index)
		end
	end)
	Players.PlayerAdded:Connect(publishBought)
	Players.PlayerRemoving:Connect(function(player)
		bought[player] = nil
		lastAttempt[player] = nil
	end)

	MerchantService.Restock()
	task.spawn(function()
		while true do
			task.wait(Config.Merchant.RestockInterval)
			MerchantService.Restock()
		end
	end)
end

return MerchantService

--!strict
-- MerchantService: el Comerciante misterioso v2 (se abre desde el HUD o en su puesto del lobby).
-- Cada jugador tiene sus 6 ofertas, cada una con su stock ("Left 3"; con 0 queda SOLD OUT):
--   [1] huevo  [2] huevo misterioso  [3] huevo  /  [4] poción Luck x2  [5] poción Fast Nests  [6] huevo
-- Los huevos (Rare a Secret, a veces con variante) van directo a un nido libre de tu hábitat; el misterioso
-- puede ser de cualquier rareza. Las pociones las maneja PotionService.
-- Cada Config.Merchant.RestockInterval segundos todos reciben ofertas nuevas; también se pueden renovar pagando ("Renew").
--
-- Para el cliente se publica:
--   Workspace "MerchantRestockAt" (hora del servidor de la próxima tanda)
--   Player    "MerchantOffers" = "Tipo:Rareza/Poción:Variante:Precio:Quedan;..." (6 ofertas)
--   Player    "MerchantRenewPrice" (lo que cuesta renovar ahora)
-- El cliente solo pide "Buy" con el número de oferta o "Renew": el servidor revisa todo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local IncubatorService = require(script.Parent.IncubatorService)
local CreatureService = require(script.Parent.CreatureService)
local PotionService = require(script.Parent.PotionService)

export type OfferKind = "Egg" | "Mystery" | "Potion"
export type Offer = {
	Kind: OfferKind,
	RarityId: string, -- en las pociones: "Luck" o "FastNest"
	VariantId: string,
	Price: number,
	Left: number,
}

local MerchantService = {}

local OFFER_COUNT = 6
local random = Random.new()
local offersByPlayer: { [Player]: { Offer } } = {}
local lastAttempt: { [Player]: number } = {}

local notifyRemote = Remotes.Event("Notify")
local merchantRemote = Remotes.Event("Merchant")

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

local function weighted(weights: { [string]: number }): Config.Rarity
	local total = 0
	for _, rarity in Config.Rarities do
		total += weights[rarity.Id] or 0
	end
	local roll = random:NextNumber(0, total)
	for _, rarity in Config.Rarities do
		local weight = weights[rarity.Id] or 0
		roll -= weight
		if weight > 0 and roll <= 0 then
			return rarity
		end
	end
	return Config.Rarities[2]
end

local function rollVariant(): Config.Variant
	if random:NextNumber() >= Config.Merchant.VariantChance then
		return Config.Variants[1]
	end
	-- Una variante al azar (sin contar Normal), según sus pesos
	local total = 0
	for i = 2, #Config.Variants do
		total += Config.Variants[i].Weight
	end
	local roll = random:NextNumber(0, total)
	for i = 2, #Config.Variants do
		roll -= Config.Variants[i].Weight
		if roll <= 0 then
			return Config.Variants[i]
		end
	end
	return Config.Variants[2]
end

-- Precio de un huevo: lo que daría su mascota en PriceSeconds segundos
function MerchantService.PriceOf(rarity: Config.Rarity, variant: Config.Variant): number
	return math.floor(Config.GetIncome(rarity, variant) * Config.Merchant.PriceSeconds)
end

-- Precio de una poción o de renovar: lo que ganás en "seconds" (con un mínimo)
local function incomePrice(player: Player, seconds: number, minimum: number): number
	return math.max(minimum, math.floor(CreatureService.GetIncomePerSecond(player) * seconds))
end

function MerchantService.RenewPrice(player: Player): number
	return incomePrice(player, Config.Merchant.RenewPriceSeconds, Config.Merchant.RenewMinPrice)
end

local function eggOffer(): Offer
	local rarity = weighted(Config.Merchant.RarityWeights)
	local variant = rollVariant()
	return { Kind = "Egg", RarityId = rarity.Id, VariantId = variant.Id, Price = MerchantService.PriceOf(rarity, variant), Left = Config.Merchant.Stock[rarity.Id] or 1 }
end

local function potionOffer(player: Player, id: string): Offer
	local info = (Config.Potions :: any)[id]
	return { Kind = "Potion", RarityId = id, VariantId = "Normal", Price = incomePrice(player, info.PriceSeconds, info.MinPrice), Left = Config.Merchant.Stock[id] or 1 }
end

local function publish(player: Player)
	local offers = offersByPlayer[player]
	if not offers then
		return
	end
	local parts = {}
	for _, offer in offers do
		table.insert(parts, `{offer.Kind}:{offer.RarityId}:{offer.VariantId}:{offer.Price}:{offer.Left}`)
	end
	player:SetAttribute("MerchantOffers", table.concat(parts, ";"))
	player:SetAttribute("MerchantRenewPrice", MerchantService.RenewPrice(player))
end

-- Ofertas nuevas para este jugador
function MerchantService.Reroll(player: Player)
	offersByPlayer[player] = {
		eggOffer(),
		{ Kind = "Mystery", RarityId = "Mystery", VariantId = "Normal", Price = Config.Merchant.MysteryPrice, Left = Config.Merchant.Stock.Mystery or 1 },
		eggOffer(),
		potionOffer(player, "Luck"),
		potionOffer(player, "FastNest"),
		eggOffer(),
	}
	publish(player)
end

-- Tanda nueva para todos
function MerchantService.Restock()
	Workspace:SetAttribute("MerchantRestockAt", Workspace:GetServerTimeNow() + Config.Merchant.RestockInterval)
	for _, player in Players:GetPlayers() do
		MerchantService.Reroll(player)
	end
end

function MerchantService.GetOffers(player: Player): { Offer }
	return offersByPlayer[player] or {}
end

local function placeEgg(player: Player, offer: Offer, rarity: Config.Rarity, variant: Config.Variant): boolean
	if not PlayerDataService.SpendCoins(player, offer.Price) then
		notify(player, `Not enough coins! You need {Format.Number(offer.Price)}.`)
		return false
	end
	if not IncubatorService.PlaceEgg(player, rarity, variant) then
		PlayerDataService.AddCoins(player, offer.Price, true) -- devolución
		return false
	end
	return true
end

function MerchantService.TryBuy(player: Player, index: number)
	local now = os.clock()
	if now - (lastAttempt[player] or 0) < Config.Merchant.Cooldown then
		return
	end
	lastAttempt[player] = now

	local offers = offersByPlayer[player]
	local offer = offers and offers[index]
	if not offer or not PlayerDataService.Get(player) then
		return
	end
	if offer.Left <= 0 then
		notify(player, "Sold out! New offers soon.")
		return
	end

	if offer.Kind == "Potion" then
		local info = (Config.Potions :: any)[offer.RarityId]
		if PotionService.TimeLeft(player, offer.RarityId :: any) + info.Duration > Config.Potions.MaxTime then
			notify(player, `You already have plenty of {info.DisplayName}!`)
			return
		end
		if not PlayerDataService.SpendCoins(player, offer.Price) then
			notify(player, `Not enough coins! You need {Format.Number(offer.Price)}.`)
			return
		end
		PotionService.Add(player, offer.RarityId :: any)
		notify(player, `{info.Icon} {info.DisplayName} is active! ({info.Description})`)
	else
		local canPlace, reason = IncubatorService.CanPlaceEgg(player)
		if not canPlace then
			notify(player, reason or "You can't buy this right now.")
			return
		end
		local rarity: Config.Rarity?, variant: Config.Variant
		if offer.Kind == "Mystery" then
			rarity = weighted(Config.Merchant.MysteryWeights)
			variant = rollVariant()
		else
			rarity = Config.GetRarity(offer.RarityId)
			variant = Config.GetVariant(offer.VariantId)
		end
		if not rarity then
			return
		end
		local chosen: Config.Rarity = rarity
		if not placeEgg(player, offer, chosen, variant) then
			return
		end
		local eggName = Config.WithVariant(variant, chosen.DisplayName .. " Egg")
		notify(player, if offer.Kind == "Mystery"
			then `🎲 The Mystery Egg was a {eggName}! It's incubating in your habitat.`
			else `You bought a {eggName}! It's incubating in your habitat.`)
	end
	offer.Left -= 1
	publish(player)
end

-- Ofertas nuevas ya, pagando
function MerchantService.TryRenew(player: Player)
	local now = os.clock()
	if now - (lastAttempt[player] or 0) < Config.Merchant.Cooldown or not PlayerDataService.Get(player) then
		return
	end
	lastAttempt[player] = now
	local price = MerchantService.RenewPrice(player)
	if not PlayerDataService.SpendCoins(player, price) then
		notify(player, `Not enough coins! You need {Format.Number(price)}.`)
		return
	end
	MerchantService.Reroll(player)
	notify(player, "The merchant brought new offers!")
end

function MerchantService.Init(_map: Folder)
	merchantRemote.OnServerEvent:Connect(function(player: Player, action: unknown, index: unknown)
		-- Lo que manda el cliente no es confiable: revisamos tipo y rango
		if action == "Buy" and typeof(index) == "number" and index == math.floor(index) and index >= 1 and index <= OFFER_COUNT then
			MerchantService.TryBuy(player, index)
		elseif action == "Renew" then
			MerchantService.TryRenew(player)
		end
	end)
	Players.PlayerAdded:Connect(MerchantService.Reroll)
	Players.PlayerRemoving:Connect(function(player)
		offersByPlayer[player] = nil
		lastAttempt[player] = nil
	end)
	-- El precio de renovar y de las pociones depende de lo que ganás: lo actualizamos cuando cambia
	local function watchIncome(player: Player)
		player:GetAttributeChangedSignal("Income"):Connect(function()
			local offers = offersByPlayer[player]
			if offers then
				for _, offer in offers do
					if offer.Kind == "Potion" then
						local info = (Config.Potions :: any)[offer.RarityId]
						offer.Price = incomePrice(player, info.PriceSeconds, info.MinPrice)
					end
				end
				publish(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchIncome)
	for _, player in Players:GetPlayers() do
		watchIncome(player)
	end

	MerchantService.Restock()
	task.spawn(function()
		while true do
			task.wait(Config.Merchant.RestockInterval)
			MerchantService.Restock()
		end
	end)
end

return MerchantService

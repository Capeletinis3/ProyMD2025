local C = __mod("Config")
C.Events.Chance = 0
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6
C.Merchant.RestockInterval = 60
--@@MAIN
local Config = __mod("Config")
local PDS = __mod("PlayerDataService")
local BaseService = __mod("BaseService")
local Eggs = __mod("EggService")
local Inc = __mod("IncubatorService")
local Remotes = __mod("Remotes")
local Workspace = game:GetService("Workspace")
local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
local function lastNotify(p)
	for i = #REMOTE_LOG, 1, -1 do
		local e = REMOTE_LOG[i]
		if e.player == p and e.remote == "Notify" then return e.args[1] end
	end
end
-- Un huevo del piso (de una zona, si se pide)
local function groundEgg(zoneIndex)
	for _, child in Workspace.Eggs:GetChildren() do
		local prompt = child:FindFirstChild("ProximityPrompt")
		if prompt and prompt.Enabled then
			local ok = true
			if zoneIndex then
				local x0, x1 = Config.ZoneRange(zoneIndex)
				ok = child.Position.X >= x0 and child.Position.X < x1
			end
			if ok then return child end
		end
	end
end
local function grab(p, zoneIndex)
	local egg = groundEgg(zoneIndex)
	if not egg then return nil end
	MOVE_TO(p, egg.Position); egg.ProximityPrompt.Triggered:Fire(p); ADVANCE(0.6)
	return egg
end
local function nest(p, slot) return BaseService.GetBase(p).IncubatorSlots[slot or 1] end
local function nestState(p, slot)
	local prompt = nest(p, slot):FindFirstChild("ProximityPrompt")
	return prompt and prompt:GetAttribute("State")
end
local function nestText(p, slot)
	local gui = nest(p, slot):FindFirstChild("TimerGui")
	return gui and gui:FindFirstChildOfClass("Frame"):FindFirstChildOfClass("TextLabel").Text
end
local function useNest(p, slot)
	local ped = nest(p, slot)
	MOVE_TO(p, ped.Position); ADVANCE(0.6)
	local prompt = ped:FindFirstChild("ProximityPrompt")
	if prompt then prompt.Triggered:Fire(p) end
	ADVANCE(0.2)
end
local function shopCounter() return Workspace.Map.Lobby.Stalls.UpgradeShop.Counter end
local function goToShop(p) MOVE_TO(p, shopCounter().Position + Vector3.new(4, 0, 0)); ADVANCE(0.4) end
local function key(id) return "Player_" .. id end
local function done() print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails)) end

local Merchant = __mod("MerchantService")
local Potions = __mod("PotionService")
local remote = Remotes.Event("Merchant")
ADVANCE(0.5)
local alice = ADD_PLAYER("Alice", 1101); SPAWN_CHARACTER(alice); ADVANCE(1)
local profile = PDS.Get(alice)
profile.TutorialStep = 5
local offers = Merchant.GetOffers(alice)
check(#offers == 6 and offers[1].Kind == "Egg" and offers[2].Kind == "Mystery" and offers[3].Kind == "Egg"
	and offers[4].Kind == "Potion" and offers[4].RarityId == "Luck" and offers[5].RarityId == "FastNest" and offers[6].Kind == "Egg", "6 offers: 3 eggs, a mystery egg and 2 potions")
local text = alice:GetAttribute("MerchantOffers")
local count = 0
for _ in string.gmatch(text or "", "[^;]+") do count += 1 end
check(count == 6 and Workspace:GetAttribute("MerchantRestockAt") ~= nil, "the offers are published for the client (" .. tostring(text) .. ")")
local okOffers = true
for _, o in offers do
	if o.Kind == "Egg" then
		local r = Config.GetRarity(o.RarityId)
		if Config.RarityRank(o.RarityId) < 2 or o.Price ~= math.floor(Config.GetIncome(r, Config.GetVariant(o.VariantId)) * Config.Merchant.PriceSeconds) or o.Left ~= Config.Merchant.Stock[o.RarityId] then okOffers = false end
	end
end
check(okOffers, "eggs are Rare or better, price = income × 600 s, stock by rarity")
-- Muchas tandas: aparecen todas las rarezas y algunas variantes
local seen, variants, eggCount = {}, 0, 0
for _ = 1, 300 do
	Merchant.Reroll(alice)
	for _, o in Merchant.GetOffers(alice) do
		if o.Kind == "Egg" then
			eggCount += 1
			seen[o.RarityId] = true
			if o.VariantId ~= "Normal" then variants += 1 end
		end
	end
end
check(seen.Rare and seen.Epic and seen.Legendary and seen.Mythic and seen.Secret and not seen.Common, "rerolls bring Rare to Secret eggs")
check(variants > eggCount * 0.25 and variants < eggCount * 0.45, "about 35% of eggs have a variant (" .. variants .. "/" .. eggCount .. ")")

-- Comprar un huevo (desde cualquier lado: el HUD tiene el botón)
offers = Merchant.GetOffers(alice)
local price = offers[1].Price
PDS.AddCoins(alice, price * 10 + 1e6)
MOVE_TO(alice, Vector3.new(0, 3, 22)); ADVANCE(0.2)
local coins = profile.Coins
remote.OnServerEvent:Fire(alice, "Buy", 1); remote.OnServerEvent:Fire(alice, "Buy", 1); ADVANCE(0.6)
check(nestState(alice, 1) == "Incubating" and profile.Coins == coins - price, "buying an egg puts it in a nest and charges once")
local snap = Inc.GetSnapshot(alice)[1]
check(snap.RarityId == offers[1].RarityId and snap.Variant == offers[1].VariantId, "it's the egg that was offered")
check(Merchant.GetOffers(alice)[1].Left == Config.Merchant.Stock[offers[1].RarityId] - 1, "the stock goes down")
remote.OnServerEvent:Fire(alice, "Buy", 3); ADVANCE(0.6)
check(lastNotify(alice) == "You need an empty incubator in your base!", "no free nest: can't buy an egg (and nothing is charged)")
-- Pociones
coins = profile.Coins
local luckPrice = Merchant.GetOffers(alice)[4].Price
check(Config.LuckChance(alice, "Common") == 0, "without the Luck upgrade there's no luck")
remote.OnServerEvent:Fire(alice, "Buy", 4); ADVANCE(0.6)
check(profile.Coins == coins - luckPrice and profile.LuckPotion > Config.Potions.Luck.Duration - 2 and alice:GetAttribute("LuckBoost") == 2, "Luck x2 potion: 10 minutes")
check(Config.LuckChance(alice, "Common") > 0, "the Luck potion works even without the upgrade")
remote.OnServerEvent:Fire(alice, "Buy", 5); ADVANCE(0.6)
local before = Inc.GetSnapshot(alice)[1].Remaining
ADVANCE(4)
local after = Inc.GetSnapshot(alice)[1].Remaining
check(profile.FastNestPotion > 0 and before - after > 7, string.format("Fast Nests: the nest hatches 2x faster (%.1f s in 4 s)", before - after))
Potions.Tick(Config.Potions.Luck.Duration)
check(profile.LuckPotion == 0 and alice:GetAttribute("LuckBoost") == nil and alice:GetAttribute("LuckPotion") == 0, "potions run out")
-- Stock agotado
local offer6 = Merchant.GetOffers(alice)[5]
offer6.Left = 0
remote.OnServerEvent:Fire(alice, "Buy", 5); ADVANCE(0.6)
check(lastNotify(alice) == "Sold out! New offers soon.", "SOLD OUT")
-- Huevo misterioso
Inc.ClearBase(alice); profile.Incubating = {}; Inc.SetupBase(alice, BaseService.GetBase(alice))
remote.OnServerEvent:Fire(alice, "Buy", 2); ADVANCE(0.6)
check(nestState(alice, 1) == "Incubating" and (lastNotify(alice) or ""):find("Mystery Egg was a") ~= nil, "mystery egg: " .. tostring(lastNotify(alice)))
-- Renovar pagando
local renew = alice:GetAttribute("MerchantRenewPrice")
coins = profile.Coins
remote.OnServerEvent:Fire(alice, "Renew"); ADVANCE(0.6)
check(profile.Coins == coins - renew and Merchant.GetOffers(alice)[5].Left == Config.Merchant.Stock.FastNest and lastNotify(alice) == "The merchant brought new offers!", "Renew: pay to get new offers and full stock")
-- Basura
remote.OnServerEvent:Fire(alice, "Buy", 99); remote.OnServerEvent:Fire(alice, "Buy", 1.5); remote.OnServerEvent:Fire(alice, "Steal", 1); ADVANCE(0.6)
check(lastNotify(alice) == "The merchant brought new offers!", "junk requests are ignored")
-- Sin plata
PDS.SpendCoins(alice, profile.Coins)
Inc.ClearBase(alice); profile.Incubating = {}; Inc.SetupBase(alice, BaseService.GetBase(alice))
remote.OnServerEvent:Fire(alice, "Buy", 6); ADVANCE(0.6)
check(profile.Coins == 0 and (lastNotify(alice) or ""):find("Not enough coins") ~= nil, "not enough coins")
-- Se guardan las pociones
PDS.AddCoins(alice, 1e6)
remote.OnServerEvent:Fire(alice, "Buy", 4); ADVANCE(0.6)
REMOVE_PLAYER(alice); ADVANCE(1)
local saved = STORE_DATA[key(1101)]
check(saved and saved.LuckPotion > 500, "potions are saved (time left: " .. tostring(saved and saved.LuckPotion) .. ")")
-- Tanda nueva para todos
local bob = ADD_PLAYER("Bob", 1102); SPAWN_CHARACTER(bob); ADVANCE(1)
Merchant.GetOffers(bob)[1].Left = 0
ADVANCE(Config.Merchant.RestockInterval)
check(Merchant.GetOffers(bob)[1].Left > 0, "a new restock brings fresh stock")

done()

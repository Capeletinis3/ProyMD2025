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
local remote = Remotes.Event("Merchant")
ADVANCE(0.5)
local offers = Merchant.GetOffers()
check(#offers == 3 and Workspace:GetAttribute("MerchantOffers") ~= nil, "3 offers are published")
local okOffers = true
for _, o in offers do
	local r = Config.GetRarity(o.RarityId)
	if Config.RarityRank(o.RarityId) < 2 or o.Price ~= math.floor(Config.GetIncome(r, Config.GetVariant(o.VariantId)) * Config.Merchant.PriceSeconds) then okOffers = false end
end
check(okOffers, "offers are Rare or better, price = income × 600 s")
-- Muchas tandas: aparecen todas las rarezas y algunas variantes
local seen, variants = {}, 0
for _ = 1, 300 do
	Merchant.Restock()
	for _, o in Merchant.GetOffers() do
		seen[o.RarityId] = true
		if o.VariantId ~= "Normal" then variants += 1 end
	end
end
check(seen.Rare and seen.Epic and seen.Legendary and seen.Mythic and seen.Secret and not seen.Common, "restocks bring Rare to Secret eggs")
check(variants > 900 * 0.25 and variants < 900 * 0.45, "about 35% of offers have a variant (" .. variants .. "/900)")

local alice = ADD_PLAYER("Alice", 1101); SPAWN_CHARACTER(alice); ADVANCE(1)
local profile = PDS.Get(alice)
local counter = Workspace.Map.Lobby.Stalls.Merchant.Counter
local price = Merchant.GetOffers()[1].Price
PDS.AddCoins(alice, price * 10)
remote.OnServerEvent:Fire(alice, "Buy", 1); ADVANCE(0.6)
check(nestState(alice, 1) == "Empty", "can't buy away from the merchant")
MOVE_TO(alice, counter.Position + Vector3.new(0, 0, 4)); ADVANCE(0.1)
local coins = profile.Coins
remote.OnServerEvent:Fire(alice, "Buy", 1); remote.OnServerEvent:Fire(alice, "Buy", 1); ADVANCE(0.6)
local offer = Merchant.GetOffers()[1]
check(nestState(alice, 1) == "Incubating" and profile.Coins == coins - price, "buying puts the egg in a nest and charges once")
local snap = Inc.GetSnapshot(alice)[1]
check(snap.RarityId == offer.RarityId and snap.Variant == offer.VariantId, "it's the egg that was offered")
check(alice:GetAttribute("MerchantBought") == "1", "the client knows offer 1 was bought")
remote.OnServerEvent:Fire(alice, "Buy", 1); ADVANCE(0.6)
check(lastNotify(alice) == "You already bought this one! New stock soon.", "each offer once per restock")
remote.OnServerEvent:Fire(alice, "Buy", 2); ADVANCE(0.6)
check(lastNotify(alice) == "You need an empty incubator in your base!", "no free incubator: can't buy (and nothing is charged)")
remote.OnServerEvent:Fire(alice, "Buy", 99); remote.OnServerEvent:Fire(alice, "Buy", 1.5); remote.OnServerEvent:Fire(alice, "Steal", 1); ADVANCE(0.6)
check(lastNotify(alice) == "You need an empty incubator in your base!", "junk requests are ignored")
-- Sin plata
PDS.SpendCoins(alice, profile.Coins)
Inc.ClearBase(alice) -- (vacía los nidos para la prueba)
profile.Incubating = {}
Inc.SetupBase(alice, BaseService.GetBase(alice))
local before = profile.Coins
remote.OnServerEvent:Fire(alice, "Buy", 3); ADVANCE(0.6)
check(profile.Coins == before and (lastNotify(alice) or ""):find("Not enough coins") ~= nil, "not enough coins")
-- Nueva tanda
ADVANCE(Config.Merchant.RestockInterval)
check(alice:GetAttribute("MerchantBought") == "", "a new restock lets you buy again")

done()

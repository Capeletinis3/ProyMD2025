local C = __mod("Config")
C.Events.Chance = 0 -- sin eventos (salvo que la prueba los prenda a mano)
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6 -- sin olas
C.Spin.ProductId = 777
for _, r in C.Rarities do r.BaseIncubationTime = 100 end
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

local Spin = __mod("SpinService")
local remote = Remotes.Event("Spin")
local market = game:GetService("MarketplaceService")
local function lastSpin(p)
	for i = #REMOTE_LOG, 1, -1 do
		local e = REMOTE_LOG[i]
		if e.player == p and e.remote == "Spin" then return e.args end
	end
end
local alice = ADD_PLAYER("Alice", 1501); SPAWN_CHARACTER(alice); ADVANCE(1)
local profile = PDS.Get(alice)
profile.TutorialStep = 5
check(Spin.HasFreeSpin(alice) and alice:GetAttribute("NextFreeSpinAt") <= Workspace:GetServerTimeNow() + 1, "a new player has a free spin")
remote.OnServerEvent:Fire(alice, "Spin"); ADVANCE(0.2)
local result = lastSpin(alice)
check(result and result[1] == "Result" and Config.Spin.Prizes[result[2]] ~= nil and typeof(result[3]) == "string", "spinning gives a prize: " .. tostring(result and result[3]))
check(not Spin.HasFreeSpin(alice) and alice:GetAttribute("NextFreeSpinAt") > Workspace:GetServerTimeNow() + Config.Spin.FreeInterval - 5, "the next free spin is tomorrow")
ADVANCE(1.2)
remote.OnServerEvent:Fire(alice, "Spin"); ADVANCE(0.2)
check(lastNotify(alice) == "No spins left! Come back later or buy a spin.", "no spins left: nothing happens")
-- Comprar un giro con Robux
ADVANCE(1.2)
remote.OnServerEvent:Fire(alice, "Buy"); ADVANCE(0.2)
check(#PRODUCT_PROMPTS == 1 and PRODUCT_PROMPTS[1][2] == 777, "Buy opens the spin product purchase")
local function receipt(r)
	local out
	task.spawn(function() out = market.ProcessReceipt(r) end)
	ADVANCE(1)
	return out
end
local decision = receipt({ PlayerId = alice.UserId, ProductId = 777, PurchaseId = "s1" })
check(decision == Enum.ProductPurchaseDecision.PurchaseGranted and profile.SpinTokens == 1 and alice:GetAttribute("SpinTokens") == 1, "after paying, you get 1 spin")
check(STORE_DATA[key(1501)] and STORE_DATA[key(1501)].SpinTokens == 1, "the bought spin is saved right away")
decision = receipt({ PlayerId = alice.UserId, ProductId = 777, PurchaseId = "s1" })
check(decision == Enum.ProductPurchaseDecision.PurchaseGranted and profile.SpinTokens == 1, "the same payment twice doesn't give 2 spins")
check(receipt({ PlayerId = 999999, ProductId = 777, PurchaseId = "s2" }) == Enum.ProductPurchaseDecision.NotProcessedYet, "unknown buyer: not granted yet (Roblox retries)")
check(receipt({ PlayerId = alice.UserId, ProductId = 12345, PurchaseId = "s3" }) == Enum.ProductPurchaseDecision.NotProcessedYet, "an unknown product isn't granted")
ADVANCE(1.2)
remote.OnServerEvent:Fire(alice, "Spin"); ADVANCE(0.2)
check(profile.SpinTokens == 0 and lastSpin(alice)[2] ~= nil, "the bought spin can be used")
-- Muchos giros: salen todos los premios y se entregan
local counts = {}
for _ = 1, 300 do
	profile.LastFreeSpin = 0
	Inc.ClearBase(alice); profile.Incubating = {}; Inc.SetupBase(alice, BaseService.GetBase(alice))
	ADVANCE(1.05)
	local index = Spin.TrySpin(alice)
	if index then counts[index] = (counts[index] or 0) + 1 end
end
local all = true
for i in Config.Spin.Prizes do if not counts[i] then all = false end end
check(all, "every prize comes up")
check(profile.LuckPotion > 0 and profile.FastNestPotion > 0, "potion prizes are given")
-- Huevo sin nido libre: monedas
profile.LastFreeSpin = 0
grab(alice, 1); useNest(alice, 1)
local eggPrize
for i, prize in Config.Spin.Prizes do if prize.RarityId then eggPrize = i end end
local coins = profile.Coins
local oldWeights = {}
for i, prize in Config.Spin.Prizes do oldWeights[i] = prize.Weight; prize.Weight = if i == eggPrize then 1 else 0 end
ADVANCE(1.1)
Spin.TrySpin(alice)
for i, prize in Config.Spin.Prizes do prize.Weight = oldWeights[i] end
check(profile.Coins > coins and tostring(lastSpin(alice)[3]):find("No free nest") ~= nil, "an egg prize with no free nest gives coins instead")
-- Junk
ADVANCE(1.2)
local lastFree, tokens, spins = profile.LastFreeSpin, profile.SpinTokens, 0
for _, e in REMOTE_LOG do if e.remote == "Spin" then spins += 1 end end
remote.OnServerEvent:Fire(alice, 123); remote.OnServerEvent:Fire(alice, "Cheat"); remote.OnServerEvent:Fire(alice, { "Spin" }); ADVANCE(0.2)
local after = 0
for _, e in REMOTE_LOG do if e.remote == "Spin" then after += 1 end end
check(profile.LastFreeSpin == lastFree and profile.SpinTokens == tokens and after == spins, "junk requests are ignored")

done()

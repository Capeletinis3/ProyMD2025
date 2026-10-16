local C = __mod("Config")
C.Events.Chance = 0
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6
C.Vip.GamePassId = 777
C.Vip.TestUserIds = { 4242 }
C.Vip.GiftProductId = 888
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



local Vip = __mod("VipService")
local Creatures = __mod("Creatures")
local CreatureService = __mod("CreatureService")
local Eggs = __mod("EggService")
local remote = Remotes.Event("Vip")
local market = game:GetService("MarketplaceService")
local cave
for _, c in Workspace.Map:GetDescendants() do
	if c:GetAttribute("Vip") then cave = c end
end
local barrier = cave and cave:FindFirstChild("VipBarrier")
check(barrier ~= nil and barrier.CanCollide ~= false and barrier.CollisionGroup == "VipBarrier", "the VIP cave has a solid barrier in the VipBarrier group")
check(COLLIDABLE["VipBarrier|VipPlayers"] == false, "VIP players don't collide with the barrier")
local prompt = barrier:FindFirstChildOfClass("ProximityPrompt")
check(prompt and prompt.ActionText == "Get VIP", "the cave has a Get VIP button (it opens the VIP window)")

PASS_OWNERS["5001:777"] = true
local owner = ADD_PLAYER("Owner", 5001); SPAWN_CHARACTER(owner)
local normal = ADD_PLAYER("Normal", 5002); SPAWN_CHARACTER(normal)
local tester = ADD_PLAYER("Tester", 4242); SPAWN_CHARACTER(tester)
ADVANCE(1)
check(Vip.IsVip(owner) and owner:GetAttribute("VIP") == true, "owning the Game Pass makes you VIP")
check(owner.Character.HumanoidRootPart.CollisionGroup == "VipPlayers" and owner.Character.Head.CollisionGroup == "VipPlayers", "VIP character parts can pass the barrier")
check(not Vip.IsVip(normal) and normal:GetAttribute("VIP") == nil and normal.Character.HumanoidRootPart.CollisionGroup == nil, "a normal player is not VIP and can't pass")
check(Vip.IsVip(tester), "Config.Vip.TestUserIds are VIP for free")
check(owner.Character.Head:FindFirstChild("VipCrown") and not normal.Character.Head:FindFirstChild("VipCrown"), "gold crown over the VIP's head")
local char = SPAWN_CHARACTER(owner); ADVANCE(0.1)
check(char.HumanoidRootPart.CollisionGroup == "VipPlayers" and char.Head:FindFirstChild("VipCrown"), "after respawning: still passes and has the crown")
local extra = Instance.new("Part"); extra.Parent = char; char.DescendantAdded:Fire(extra)
check(extra.CollisionGroup == "VipPlayers", "parts added later (accessories) too")

-- Huevo diario (Rare dorado) directo a un nido
ADVANCE(1)
check(nestState(owner, 1) == "Incubating", "VIP daily egg goes straight to a nest")
local snap = Inc.GetSnapshot(owner)[1]
check(snap and snap.RarityId == "Rare" and snap.Variant == "Golden", "it's a Golden Rare egg")
local profile = PDS.Get(owner)
check(math.abs(profile.LastDailyEgg - os.time()) < 5 and owner:GetAttribute("NextDailyEgg") == profile.LastDailyEgg + 86400, "next one in 24 hours")
check(nestState(tester, 1) == "Incubating", "(the tester gets one too)")
ADVANCE(20)
local incubating = 0
for _, s in Inc.GetSnapshot(owner) do incubating += 1 end
check(incubating == 1, "only one per day")
-- Incuba 20% más rápido
local rareTime = Config.GetRarity("Rare").BaseIncubationTime
check(math.abs(snap.Remaining - rareTime * 0.8) < 3, "VIP nests hatch 20% faster (" .. math.floor(snap.Remaining) .. " s left)")
-- x2 de plata
CreatureService.AddCreature(owner, Creatures.Get("GoldenDragon"))
CreatureService.AddCreature(normal, Creatures.Get("GoldenDragon"))
ADVANCE(0.1)
check(owner:GetAttribute("Income") == normal:GetAttribute("Income") * 2, "VIP creatures make x2 coins")
-- Un huevo más para llevar
local e1 = grab(owner, 1); local e2 = grab(owner, 1)
check(e1 and e2 and Eggs.GetCarriedCount(owner) == 2 and owner:GetAttribute("CarriedEggCount") == 2, "VIP carries 2 eggs")
grab(owner, 1)
check(Eggs.GetCarriedCount(owner) == 2 and lastNotify(owner) == "You can only carry 2 eggs at a time!", "but not 3")
grab(normal, 1); grab(normal, 1)
check(Eggs.GetCarriedCount(normal) == 1 and lastNotify(normal) == "You can only carry 1 egg at a time!", "normal players carry 1")
Eggs.TakeCarriedEgg(owner)
check(Eggs.GetCarriedCount(owner) == 1 and owner:GetAttribute("CarriedEggRarity") ~= nil, "giving one away keeps the other")
Eggs.LoseCarriedEgg(owner)
check(Eggs.GetCarriedCount(owner) == 0 and owner:GetAttribute("CarriedEggRarity") == nil and owner:GetAttribute("CarriedEggCount") == nil, "the wave takes all of them")

-- Comprar
ADVANCE(3)
remote.OnServerEvent:Fire(normal, "Buy"); ADVANCE(0.1)
check(#PURCHASE_PROMPTS == 1 and PURCHASE_PROMPTS[1][1] == normal and PURCHASE_PROMPTS[1][2] == 777, "Buy opens the Game Pass purchase")
remote.OnServerEvent:Fire(normal, "Buy"); ADVANCE(0.1)
check(#PURCHASE_PROMPTS == 1, "no spamming the purchase window")
market.PromptGamePassPurchaseFinished:Fire(normal, 777, false); ADVANCE(0.1)
check(not Vip.IsVip(normal), "closing the window without buying does nothing")
market.PromptGamePassPurchaseFinished:Fire(normal, 123, true); ADVANCE(0.1)
check(not Vip.IsVip(normal), "buying another pass doesn't give VIP")
market.PromptGamePassPurchaseFinished:Fire(normal, 777, true); ADVANCE(0.1)
check(Vip.IsVip(normal) and normal.Character.HumanoidRootPart.CollisionGroup == "VipPlayers", "buying it gives VIP right away")
check(normal:GetAttribute("Income") == owner:GetAttribute("Income"), "and x2 coins right away")
ADVANCE(3)
remote.OnServerEvent:Fire(owner, "Buy"); ADVANCE(0.1)
check(#PURCHASE_PROMPTS == 1 and lastNotify(owner) == "You're already VIP! Enjoy your perks.", "VIP players aren't asked to buy again")

-- Regalar
local friend = ADD_PLAYER("Friend", 5010); SPAWN_CHARACTER(friend); ADVANCE(1)
ADVANCE(3)
remote.OnServerEvent:Fire(owner, "Gift", owner.UserId); ADVANCE(0.1)
check(#PRODUCT_PROMPTS == 0, "can't gift yourself")
remote.OnServerEvent:Fire(owner, "Gift", normal.UserId); ADVANCE(0.1)
check(#PRODUCT_PROMPTS == 0 and lastNotify(owner) == "Normal already has VIP!", "can't gift someone who already has VIP")
ADVANCE(3)
remote.OnServerEvent:Fire(owner, "Gift", friend.UserId); ADVANCE(0.1)
check(#PRODUCT_PROMPTS == 1 and PRODUCT_PROMPTS[1][2] == 888, "Gift opens the gift product purchase")
-- (ProcessReceipt espera al DataStore: lo corremos aparte y dejamos pasar el tiempo)
local function receipt(r)
	local out
	task.spawn(function() out = market.ProcessReceipt(r) end)
	ADVANCE(1)
	return out
end
local result = receipt({ PlayerId = owner.UserId, ProductId = 888, PurchaseId = "p1" })
check(result == Enum.ProductPurchaseDecision.PurchaseGranted and Vip.IsVip(friend), "after paying, the friend is VIP")
check(lastNotify(friend) == "🎁 Owner gifted you VIP! Enjoy your perks!", "the friend is told who gifted it")
check(STORE_DATA["Gift_5010"] and STORE_DATA["Gift_5010"].Gifted == true, "the gift is saved forever")
result = receipt({ PlayerId = owner.UserId, ProductId = 888, PurchaseId = "p1" })
check(result == Enum.ProductPurchaseDecision.NotProcessedYet or result == Enum.ProductPurchaseDecision.PurchaseGranted, "a repeated receipt doesn't break anything")
check(receipt({ PlayerId = 999999, ProductId = 888, PurchaseId = "p2" }) == Enum.ProductPurchaseDecision.NotProcessedYet, "unknown buyer: not granted yet (Roblox retries)")
REMOVE_PLAYER(friend); ADVANCE(1)
local back = ADD_PLAYER("Friend", 5010); SPAWN_CHARACTER(back); ADVANCE(1)
check(Vip.IsVip(back), "a gifted VIP is still VIP after rejoining")
-- Ganancia offline x2 para VIP
REMOVE_PLAYER(owner); ADVANCE(1)
check(STORE_DATA[key(5001)].Vip == true, "VIP is remembered for offline earnings")

-- Roblox falla al preguntar: no rompe nada (y no da VIP)
PASS_FAIL = true
PASS_OWNERS["5003:777"] = true
local unlucky = ADD_PLAYER("Unlucky", 5003); SPAWN_CHARACTER(unlucky)
ADVANCE(15)
check(not Vip.IsVip(unlucky) and Workspace.Map ~= nil, "if Roblox can't be reached, the player just isn't VIP (no crash)")
PASS_FAIL = false

-- Sin pase ni producto configurados
Config.Vip.GamePassId = 0
Config.Vip.GiftProductId = 0
local newbie = ADD_PLAYER("Newbie", 5004); SPAWN_CHARACTER(newbie); ADVANCE(1)
remote.OnServerEvent:Fire(newbie, "Buy"); ADVANCE(0.1)
check(#PURCHASE_PROMPTS == 1 and lastNotify(newbie) == "VIP isn't available yet. Check back soon!", "GamePassId = 0: friendly message, no purchase window")
ADVANCE(3)
remote.OnServerEvent:Fire(newbie, "Gift", unlucky.UserId); ADVANCE(0.1)
check(#PRODUCT_PROMPTS == 1 and lastNotify(newbie) == "Gifting VIP isn't available yet. Check back soon!", "GiftProductId = 0: friendly message")
REMOVE_PLAYER(normal); ADVANCE(0.1)
check(not Vip.IsVip(normal), "leaving clears VIP from memory")

done()

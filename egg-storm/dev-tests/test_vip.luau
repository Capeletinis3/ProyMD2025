local C = __mod("Config")
C.Events.Chance = 0
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6
C.Vip.GamePassId = 777
C.Vip.TestUserIds = { 4242 }
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
check(prompt and prompt.ActionText == "Get VIP", "the cave has a Get VIP button")
check(cave:FindFirstChild("SafeZone") ~= nil, "the VIP cave is a safe zone")

PASS_OWNERS["5001:777"] = true
local owner = ADD_PLAYER("Owner", 5001); SPAWN_CHARACTER(owner)
local normal = ADD_PLAYER("Normal", 5002); SPAWN_CHARACTER(normal)
local tester = ADD_PLAYER("Tester", 4242); SPAWN_CHARACTER(tester)
ADVANCE(1)
check(Vip.IsVip(owner) and owner:GetAttribute("VIP") == true, "owning the Game Pass makes you VIP")
check(owner.Character.HumanoidRootPart.CollisionGroup == "VipPlayers" and owner.Character.Head.CollisionGroup == "VipPlayers", "VIP character parts can pass the barrier")
check(not Vip.IsVip(normal) and normal:GetAttribute("VIP") == nil and normal.Character.HumanoidRootPart.CollisionGroup == nil, "a normal player is not VIP and can't pass")
check(Vip.IsVip(tester), "Config.Vip.TestUserIds are VIP for free")
-- Respawn: sigue pasando
local char = SPAWN_CHARACTER(owner); ADVANCE(0.1)
check(char.HumanoidRootPart.CollisionGroup == "VipPlayers", "after respawning, VIP still passes")
local extra = Instance.new("Part"); extra.Parent = char; char.DescendantAdded:Fire(extra)
check(extra.CollisionGroup == "VipPlayers", "parts added later (accessories) too")

-- Comprar
prompt.Triggered:Fire(normal); ADVANCE(0.1)
check(#PURCHASE_PROMPTS == 1 and PURCHASE_PROMPTS[1][1] == normal and PURCHASE_PROMPTS[1][2] == 777, "Get VIP opens the Game Pass purchase")
prompt.Triggered:Fire(normal); remote.OnServerEvent:Fire(normal, "Buy"); ADVANCE(0.1)
check(#PURCHASE_PROMPTS == 1, "no spamming the purchase window")
market.PromptGamePassPurchaseFinished:Fire(normal, 777, false); ADVANCE(0.1)
check(not Vip.IsVip(normal), "closing the window without buying does nothing")
market.PromptGamePassPurchaseFinished:Fire(normal, 123, true); ADVANCE(0.1)
check(not Vip.IsVip(normal), "buying another pass doesn't give VIP")
market.PromptGamePassPurchaseFinished:Fire(normal, 777, true); ADVANCE(0.1)
check(Vip.IsVip(normal) and normal:GetAttribute("VIP") == true and normal.Character.HumanoidRootPart.CollisionGroup == "VipPlayers", "buying it gives VIP right away")
check(lastNotify(normal) == "Thanks for getting VIP! The VIP cave is open for you.", "thank-you message")
ADVANCE(3)
remote.OnServerEvent:Fire(owner, "Buy"); ADVANCE(0.1)
check(#PURCHASE_PROMPTS == 1 and lastNotify(owner) == "You're VIP! Walk right into the VIP cave.", "VIP players aren't asked to buy again")

-- Roblox falla al preguntar: no rompe nada (y no da VIP)
PASS_FAIL = true
PASS_OWNERS["5003:777"] = true
local unlucky = ADD_PLAYER("Unlucky", 5003); SPAWN_CHARACTER(unlucky)
ADVANCE(15)
check(not Vip.IsVip(unlucky) and Workspace.Map ~= nil, "if Roblox can't be reached, the player just isn't VIP (no crash)")
PASS_FAIL = false

-- Sin pase configurado
Config.Vip.GamePassId = 0
local newbie = ADD_PLAYER("Newbie", 5004); SPAWN_CHARACTER(newbie); ADVANCE(1)
remote.OnServerEvent:Fire(newbie, "Buy"); ADVANCE(0.1)
check(#PURCHASE_PROMPTS == 1 and lastNotify(newbie) == "VIP isn't available yet. Check back soon!", "GamePassId = 0: friendly message, no purchase window")
REMOVE_PLAYER(normal); ADVANCE(0.1)
check(not Vip.IsVip(normal), "leaving clears VIP from memory")

done()

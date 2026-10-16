local C = __mod("Config")
C.Events.Chance = 0
C.Waves.MinInterval = 20; C.Waves.MaxInterval = 20; C.Waves.FastChance = 0
for _, r in C.Rarities do r.BaseIncubationTime = 30 end
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

local buy = Remotes.Event("BuyUpgrade")
local function phase() return Workspace:GetAttribute("WavePhase") end
STORE_FAIL_NEXT = 1 -- DataStore lento: la primera lectura falla
local alice = ADD_PLAYER("Alice", 1001); SPAWN_CHARACTER(alice)
ADVANCE(0.3)
local baseA = BaseService.GetBase(alice)
check(PDS.Get(alice) == nil and baseA and baseA.Id == 1, "Alice gets base 1 while her data is still loading")
ADVANCE(2)
check(PDS.Get(alice) ~= nil and baseA.IncubatorSlots[1]:FindFirstChild("ProximityPrompt") ~= nil, "data loads and her incubator is ready")
local bob = ADD_PLAYER("Bob", 1002); SPAWN_CHARACTER(bob); ADVANCE(1)
check(BaseService.GetBase(bob).Id == 2, "Bob gets base 2")

grab(alice, 1)
useNest(alice, 1)
check(nestState(alice, 1) == "Incubating", "Alice incubates an egg")
grab(bob, 2)
check(Eggs.GetCarriedEgg(bob) ~= nil, "Bob grabs a jungle egg")
MOVE_TO(bob, Vector3.new(450, 3, 0)) -- Bob se queda en el cañón, sin cueva
while phase() ~= "Wave" do ADVANCE(0.1) end
while phase() == "Wave" do ADVANCE(0.1) end
check(Eggs.GetCarriedEgg(bob) == nil and bob.Character.HumanoidRootPart.Position.X < 150, "the wave gets Bob: no egg, back on the island")
ADVANCE(15)
check(nestState(alice, 1) == "Ready", "Alice's egg is ready")
useNest(alice, 1); ADVANCE(Config.Effects.HatchAnimationTime + 0.3)
check(#PDS.Get(alice).Creatures == 1 and alice:GetAttribute("Income") > 0, "Alice opens it: her first creature makes coins")
local coins = PDS.Get(alice).Coins
ADVANCE(10)
check(PDS.Get(alice).Coins > coins, "coins go up by themselves")
PDS.AddCoins(alice, 1000)
goToShop(alice)
buy.OnServerEvent:Fire(alice, "WalkSpeed"); ADVANCE(0.2)
check(alice.Character.Humanoid.WalkSpeed == Config.Upgrades.WalkSpeed[2].Speed, "Alice buys Speed at the shop")
REMOVE_PLAYER(alice); ADVANCE(1)
check(BaseService.GetBase(alice) == nil and baseA.Owner == nil, "base 1 is free after Alice leaves")
local alice2 = ADD_PLAYER("Alice", 1001); SPAWN_CHARACTER(alice2); ADVANCE(1)
check(#PDS.Get(alice2).Creatures == 1 and PDS.Get(alice2).WalkSpeedLevel == 2 and alice2.Character.Humanoid.WalkSpeed == Config.Upgrades.WalkSpeed[2].Speed, "Alice comes back with her creature and upgrades")
task.spawn(CLOSE_FNS[1]); ADVANCE(3)
check(STORE_DATA[key(1002)] ~= nil, "shutdown saves Bob too")

done()

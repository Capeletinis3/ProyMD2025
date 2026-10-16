local C = __mod("Config")
C.Events.Chance = 0 -- sin eventos (salvo que la prueba los prenda a mano)
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6 -- sin olas
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

local Creatures = __mod("Creatures")
local CreatureService = __mod("CreatureService")
local Friends = __mod("FriendService")
local alice = ADD_PLAYER("Alice", 1401); SPAWN_CHARACTER(alice); ADVANCE(1)
local profile = PDS.Get(alice)
profile.TutorialStep = 5
-- Velocidad publicada para el HUD
check(alice:GetAttribute("WalkSpeed") == Config.Upgrades.WalkSpeed[1].Speed, "the HUD knows your walk speed")
-- Nidos: el 1 vacío, el 2 y el 3 con candado
check(alice:GetAttribute("Nest1") == "Empty|EMPTY" and alice:GetAttribute("Nest2") == "Locked|LOCKED" and alice:GetAttribute("Nest3") == "Locked|LOCKED", "nest chips: Nest 1 empty, 2 and 3 locked")
grab(alice, 1); useNest(alice, 1)
local nestText = alice:GetAttribute("Nest1")
check(typeof(nestText) == "string" and nestText:match("^Incubating|%d%d:%d%d$") ~= nil, "nest chip shows the time left: " .. tostring(nestText))
-- Casilleros: con Llevar huevos lleva 2
PDS.AddCoins(alice, 10000)
Remotes.Event("BuyUpgrade").OnServerEvent:Fire(alice, "Carry"); ADVANCE(0.5)
grab(alice, 1); ADVANCE(0.4); grab(alice, 1)
local carried = alice:GetAttribute("CarriedEggs")
local count = 0
for _ in string.gmatch(carried or "", "[^,]+") do count += 1 end
check(count == 2 and carried:match("^%a+/%a+,%a+/%a+$") ~= nil, "the carry slots list both eggs: " .. tostring(carried))
-- Índice
check(alice:GetAttribute("Discovered") == "", "nothing discovered yet")
CreatureService.AddCreature(alice, Creatures.Get("CoralCat"))
CreatureService.AddCreature(alice, Creatures.Get("SandBunny"))
check(alice:GetAttribute("Discovered") == "CoralCat,SandBunny", "the Index fills in as you get creatures")
CreatureService.RemoveCreature(alice, 1)
check(alice:GetAttribute("Discovered") == "CoralCat,SandBunny", "selling or trading doesn't remove it from the Index")
-- Amigos: +10% cada uno, hasta +50%
local income = alice:GetAttribute("Income")
local bob = ADD_PLAYER("Bob", 1402); SPAWN_CHARACTER(bob); ADVANCE(1)
Friends.SetFriends(alice, bob)
check(alice:GetAttribute("FriendBonus") == 0.1 and math.abs(alice:GetAttribute("Income") - income * 1.1) < 1e-6, "a friend in the server: +10% coins")
local others = {}
for i = 1, 6 do
	local p = ADD_PLAYER("Friend" .. i, 1410 + i); ADVANCE(0.2)
	Friends.SetFriends(alice, p)
	table.insert(others, p)
end
check(alice:GetAttribute("FriendBonus") == Config.Friends.MaxBonus and math.abs(alice:GetAttribute("Income") - income * 1.5) < 1e-6, "the friend bonus stops at +50%")
for _, p in others do REMOVE_PLAYER(p) end
ADVANCE(1)
check(alice:GetAttribute("FriendBonus") == 0.1, "when friends leave, the bonus goes back down")
REMOVE_PLAYER(bob); ADVANCE(1)
check(alice:GetAttribute("FriendBonus") == 0 and alice:GetAttribute("Income") == income, "no friends: no bonus")
REMOVE_PLAYER(alice); ADVANCE(1)
local saved = STORE_DATA[key(1401)]
check(saved and #saved.Discovered == 2, "the Index is saved")

done()

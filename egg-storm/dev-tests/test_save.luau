local C = __mod("Config")
C.Events.Chance = 0 -- sin eventos (salvo que la prueba los prenda a mano)
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6 -- sin olas
C.Data.AutosaveInterval = 10
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
local BaseFloors = __mod("BaseFloors")
local buy = Remotes.Event("BuyUpgrade")
local alice = ADD_PLAYER("Alice", 111); SPAWN_CHARACTER(alice); ADVANCE(1)
local base = BaseService.GetBase(alice)
local profile = PDS.Get(alice)
check(profile ~= nil and profile.Coins == 0 and profile.IncubatorCount == 1 and profile.BaseLevel == 1, "new player starts with a fresh profile (1 floor)")
PDS.AddCoins(alice, 6000)
goToShop(alice)
buy.OnServerEvent:Fire(alice, "IncubationSpeed"); ADVANCE(0.5)
profile.BaseLevel = 2; BaseFloors.Apply(base, 2) -- como si hubiera renacido
CreatureService.AddCreature(alice, Creatures.Get("GoldenDragon"))
CreatureService.AddCreature(alice, Creatures.Get("SandBunny"))
grab(alice, 1)
local carried = alice:GetAttribute("CarriedEggRarity")
useNest(alice, 1)
check(nestState(alice, 1) == "Incubating", "Alice is incubating a " .. tostring(carried) .. " egg")
ADVANCE(Config.Data.AutosaveInterval + 1)
local saved = STORE_DATA[key(111)]
check(saved and saved.BaseLevel == 2 and saved.IncubationSpeedLevel == 2 and #saved.Creatures == 2, "autosave has upgrades, floors and creatures")
check(saved and #saved.Incubating == 1 and saved.Incubating[1].RarityId == carried, "autosave includes the egg being incubated")
local before = Inc.GetSnapshot(alice)[1].Remaining
local coinsAtLeave = profile.Coins
REMOVE_PLAYER(alice); ADVANCE(1)
saved = STORE_DATA[key(111)]
check(saved.Coins == coinsAtLeave and math.abs(saved.Incubating[1].Remaining - before) < 1.5, "leaving saves coins and the egg's time left")
ADVANCE(30)
local alice2 = ADD_PLAYER("Alice", 111); SPAWN_CHARACTER(alice2); ADVANCE(1)
local p2 = PDS.Get(alice2)
local base2 = BaseService.GetBase(alice2)
check(p2.Coins >= coinsAtLeave and p2.Coins < coinsAtLeave + 400 and p2.IncubationSpeedLevel == 2 and p2.BaseLevel == 2, "coming back restores coins, upgrades and floors")
check(#base2.Model.Locks:GetChildren() == 1, "floor 2 is open again")
local income = Config.GetRarity("Legendary").CoinsPerSecond + 1
check(alice2:GetAttribute("Income") == income, "creatures back on their shelves (income " .. tostring(alice2:GetAttribute("Income")) .. "/s)")
local snap = Inc.GetSnapshot(alice2)[1]
check(snap and math.abs(snap.Remaining - saved.Incubating[1].Remaining) < 1.5, "the egg keeps incubating where it left off")
check(alice2.leaderstats.Coins.Value == p2.Coins, "leaderstats show the saved coins")
PDS.AddCoins(alice2, 1234)
local expected = p2.Coins
task.spawn(CLOSE_FNS[1]); ADVANCE(2)
check(STORE_DATA[key(111)].Coins == expected, "BindToClose saves everyone's latest data")

STORE_DATA[key(222)] = { Coins = 500 }
STORE_FAIL_NEXT = 2
local bob = ADD_PLAYER("Bob", 222); SPAWN_CHARACTER(bob); ADVANCE(6)
check(PDS.Get(bob) and PDS.Get(bob).Coins == 500, "load succeeds after 2 failed attempts")

STORE_DATA[key(333)] = {
	Coins = "lots", IncubationSpeedLevel = 99, IncubatorCount = -3, BaseLevel = 7,
	Creatures = { { CreatureId = "FakeCreature", Slot = 1 }, { CreatureId = "SandBunny", Slot = 2 }, { CreatureId = "CoralCat", Slot = 2 }, "garbage" },
	Incubating = { { Slot = 3, RarityId = "Rare", Remaining = 10 }, { Slot = 1, RarityId = "Nope", Remaining = 5 } },
}
local carol = ADD_PLAYER("Carol", 333); SPAWN_CHARACTER(carol); ADVANCE(1)
local pc = PDS.Get(carol)
check(pc and pc.Coins <= 2 and pc.IncubationSpeedLevel == 5 and pc.IncubatorCount == 1 and pc.BaseLevel == 3, "broken numbers are fixed")
check(pc and #pc.Creatures == 1 and pc.Creatures[1].CreatureId == "SandBunny", "unknown creatures and duplicate shelves are dropped")
check(#Inc.GetSnapshot(carol) == 0, "eggs in incubators the player doesn't own are dropped")

REMOVE_PLAYER(bob); REMOVE_PLAYER(carol); ADVANCE(1)
STORE_DATA[key(444)] = { Coins = 777 }
STORE_FAIL_ALL = true
local dave = ADD_PLAYER("Dave", 444); SPAWN_CHARACTER(dave); ADVANCE(15)
local kicked = false
for _, k in KICKED do if k[1] == dave then kicked = true end end
check(kicked and PDS.Get(dave) == nil, "live game: player is kicked if data can't load")
REMOVE_PLAYER(dave); ADVANCE(1)
STORE_FAIL_ALL = false
check(STORE_DATA[key(444)].Coins == 777, "...and their saved data is untouched")
STUDIO = true
STORE_FAIL_ALL = true
local erin = ADD_PLAYER("Erin", 444); SPAWN_CHARACTER(erin); ADVANCE(15)
check(PDS.Get(erin) ~= nil, "Studio: player can still play without saving")
PDS.AddCoins(erin, 50)
STORE_FAIL_ALL = false
REMOVE_PLAYER(erin); ADVANCE(1)
check(STORE_DATA[key(444)].Coins == 777, "Studio: nothing is saved over the real data")

done()

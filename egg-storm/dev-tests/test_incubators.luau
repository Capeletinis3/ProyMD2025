local C = __mod("Config")
C.Events.Chance = 0 -- sin eventos (salvo que la prueba los prenda a mano)
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6 -- sin olas
for _, r in C.Rarities do r.BaseIncubationTime = 20 end
C.Upgrades.MinIncubationTime = 1
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
local alice = ADD_PLAYER("Alice", 201); SPAWN_CHARACTER(alice)
local bob = ADD_PLAYER("Bob", 202); SPAWN_CHARACTER(bob)
ADVANCE(1)
local base = BaseService.GetBase(alice)
local profile = PDS.Get(alice)
check(nestState(alice, 1) == "Empty" and nestText(alice, 1) == "EMPTY", "nest 1 is EMPTY")
check(nest(alice, 2):FindFirstChild("LockedGui") ~= nil and nest(alice, 3):FindFirstChild("LockedGui") ~= nil, "nests 2 and 3 say LOCKED")
useNest(alice, 1)
check(lastNotify(alice) == "Grab an egg in the canyon first!", "placing without an egg tells you to grab one")

local egg = grab(alice, 1)
local rarity = alice:GetAttribute("CarriedEggRarity")
useNest(bob, 1) -- Bob se acerca al nido de Alice
local ped = nest(alice, 1)
MOVE_TO(bob, ped.Position); ADVANCE(0.6); ped.ProximityPrompt.Triggered:Fire(bob); ADVANCE(0.2)
check(lastNotify(bob) == "This isn't your base!", "Bob can't use Alice's incubator")
useNest(alice, 1)
check(nestState(alice, 1) == "Incubating" and nestText(alice, 1) == "00:20", "the egg is incubating with a countdown (" .. tostring(nestText(alice, 1)) .. ")")
check(alice:GetAttribute("CarriedEggRarity") == nil, "the egg left Alice's hands")
local snap = Inc.GetSnapshot(alice)[1]
check(snap and snap.RarityId == rarity and snap.Variant ~= nil, "snapshot has the egg (" .. tostring(rarity) .. ")")
ADVANCE(21)
check(nestState(alice, 1) == "Ready" and nestText(alice, 1) == "READY!" and ped.ProximityPrompt.ActionText == "Open", "after the timer: READY! and an Open button")
local hatched = false
for _, e in REMOTE_LOG do if e.remote == "Hatched" then hatched = true end end
check(not hatched and #profile.Creatures == 0, "it doesn't hatch by itself")

-- Listo se guarda y vuelve listo
REMOVE_PLAYER(alice); ADVANCE(1)
check(STORE_DATA[key(201)].Incubating[1].Remaining == 0, "a ready egg is saved as ready")
alice = ADD_PLAYER("Alice", 201); SPAWN_CHARACTER(alice); ADVANCE(1)
profile = PDS.Get(alice)
check(nestState(alice, 1) == "Ready", "coming back: still READY")

useNest(alice, 1)
local args
for _, e in REMOTE_LOG do if e.remote == "Hatched" and e.player == alice then args = e.args end end
check(args and args[2] == rarity and args[4] ~= nil, "opening starts the hatch animation (" .. tostring(args and args[1]) .. ")")
ADVANCE(Config.Effects.HatchAnimationTime + 0.3)
check(#profile.Creatures == 1 and profile.Creatures[1].Slot == 1 and nestState(alice, 1) == "Empty", "the creature goes to shelf 1 and the nest is empty again")
local shelf = BaseService.GetBase(alice).CreatureSlots[1]
local model
for _, c in BaseService.GetBase(alice).Model:GetChildren() do if c:GetAttribute("CreatureId") then model = c end end
check(model and math.abs(model.PrimaryPart.Position.X - shelf.Position.X) < 0.1 and model.PrimaryPart.Position.Y > shelf.Position.Y, "the creature model stands on shelf 1")
check(alice:GetAttribute("Income") == Config.GetRarity(rarity).CoinsPerSecond * Config.GetVariant(profile.Creatures[1].Variant).Multiplier, "income comes from it")

-- Estantes llenos (5 en el piso 1)
for _ = 1, 4 do CreatureService.AddCreature(alice, Creatures.Get("SandBunny")) end
check(CreatureService.GetFreeSlotCount(alice) == 0, "5 creatures fill floor 1")
grab(alice, 1)
useNest(alice, 1)
check(lastNotify(alice) == "Your shelves are full! Sell a creature (hold E on it) to make room.", "full shelves: can't place another egg")

done()

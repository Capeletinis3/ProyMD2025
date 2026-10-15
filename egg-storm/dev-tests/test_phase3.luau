__mod("Config").Storm.RainDuration = 100000 -- en estas pruebas llueve todo el tiempo
--@@MAIN
local Config = __mod("Config")
local PDS = __mod("PlayerDataService")
local Eggs = __mod("EggService")
local Inc = __mod("IncubatorService")
local BaseService = __mod("BaseService")

local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end

local alice = ADD_PLAYER("Alice")
local bob = ADD_PLAYER("Bob")
SPAWN_CHARACTER(alice)
SPAWN_CHARACTER(bob)
ADVANCE(0.5)
local baseA = BaseService.GetBase(alice)
local baseB = BaseService.GetBase(bob)
check(baseA and baseA.Id == 1, "Alice gets base 1")
check(baseB and baseB.Id == 2, "Bob gets base 2")
check(baseA.SignLabel.Text == "Alice's Base", "sign shows owner name")
check((alice.Character.HumanoidRootPart.Position - baseA.SpawnPoint.Position).Magnitude < 6, "Alice teleported to her base")
check(#baseA.IncubatorSlots == 3 and #baseA.CreatureSlots == 8, "base has 3 incubator pads and 8 creature pads")
local profile = PDS.Get(alice)
check(profile ~= nil and profile.Coins == 0 and profile.IncubatorCount == 1, "fresh profile")
local incModel = baseA.Model.Incubator1
check(incModel ~= nil, "incubator 1 built")
check(baseA.Model:FindFirstChild("Incubator2") == nil and baseA.Model:FindFirstChild("LockedSlot2") ~= nil, "slot 2 shows LOCKED")

ADVANCE(12)
local eggsFolder = game:GetService("Workspace").Eggs
local function findGroundEgg(except)
	for _, child in eggsFolder:GetChildren() do
		local prompt = child:FindFirstChild("ProximityPrompt")
		if prompt and prompt.Enabled and child ~= except then
			return child, prompt
		end
	end
	return nil, nil
end
local egg, prompt = findGroundEgg()
check(egg ~= nil, "eggs rain and land")
local count = 0
for _, child in eggsFolder:GetChildren() do if child:GetAttribute("EggId") then count += 1 end end
print("eggs in world after 12s:", count)

MOVE_TO(alice, egg.Position + Vector3.new(100, 0, 0))
prompt.Triggered:Fire(alice); ADVANCE(0.1)
check(alice:GetAttribute("CarriedEggRarity") == nil, "grab from far away is rejected")
ADVANCE(1)
MOVE_TO(alice, egg.Position + Vector3.new(3, 0, 0))
prompt.Triggered:Fire(alice); ADVANCE(0.1)
local rarityId = alice:GetAttribute("CarriedEggRarity")
check(rarityId ~= nil, "Alice grabs the egg (" .. tostring(rarityId) .. ")")
ADVANCE(1)
local egg2, prompt2 = findGroundEgg(egg)
if egg2 then
	MOVE_TO(alice, egg2.Position)
	prompt2.Triggered:Fire(alice); ADVANCE(0.1)
	check(Eggs.GetCarriedEgg(alice).Part == egg, "can't carry 2 eggs")
end

local incPrompt = incModel.Base.ProximityPrompt
ADVANCE(1)
MOVE_TO(bob, incModel.Base.Position)
incPrompt.Triggered:Fire(bob); ADVANCE(0.1)
local bobRejected = false
for _, e in REMOTE_LOG do if e.player == bob and e.args[1] == "This isn't your base!" then bobRejected = true end end
check(bobRejected, "Bob can't use Alice's incubator")
MOVE_TO(alice, incModel.Base.Position + Vector3.new(60, 0, 0))
incPrompt.Triggered:Fire(alice); ADVANCE(0.1)
check(Eggs.GetCarriedEgg(alice) ~= nil, "incubate from far away is rejected")
ADVANCE(1)
MOVE_TO(alice, incModel.Base.Position + Vector3.new(4, 0, 0))
incPrompt.Triggered:Fire(alice); ADVANCE(0.1)
check(Eggs.GetCarriedEgg(alice) == nil and alice:GetAttribute("CarriedEggRarity") == nil, "egg goes into the incubator")
check(incModel:FindFirstChild("Egg") ~= nil, "egg visible inside the incubator")
check(incPrompt:GetAttribute("Available") == false, "incubator marked busy")

local rarity = Config.GetRarity(rarityId)
local total = Config.GetIncubationTime(rarity, 1)
print("timer:", incModel.Dome.Display.Timer.Text, "title:", incModel.Dome.Display.Title.Text, "total:", total)
ADVANCE(total - 3)
check(#PDS.Get(alice).Creatures == 0, "not hatched before its time")
print("timer near end:", incModel.Dome.Display.Timer.Text)
ADVANCE(4)
local hatchedMsg, hatchedEgg
for _, e in REMOTE_LOG do if e.remote == "Hatched" and e.player == alice then hatchedMsg = e.args[1] .. " / " .. e.args[2]; hatchedEgg = e.args[3] end end
check(hatchedMsg ~= nil, "owner gets Hatched message: " .. tostring(hatchedMsg))
check(hatchedEgg ~= nil and hatchedEgg.Name == "Egg", "Hatched message includes the egg to animate")
check(#PDS.Get(alice).Creatures == 0 and incModel.Dome.Display.Timer.Text == "Hatching!", "creature waits for the opening animation")
ADVANCE(Config.Effects.HatchAnimationTime)
check(#PDS.Get(alice).Creatures == 1, "egg hatched into a creature after the animation")
check(incModel.Dome.Display.Title.Text == "Empty" and incPrompt:GetAttribute("Available") == true, "incubator is free again")
local creatureModel
for _, c in baseA.Model:GetChildren() do if c:GetAttribute("CreatureId") then creatureModel = c end end
check(creatureModel ~= nil, "creature model placed on a pad")
if creatureModel then
	local pad = baseA.CreatureSlots[1]
	local d = creatureModel.PrimaryPart.Position - pad.Position
	print(string.format("creature offset from pad 1: (%.1f, %.1f, %.1f)", d.X, d.Y, d.Z))
end

local before = PDS.Get(alice).Coins
ADVANCE(5)
local after = PDS.Get(alice).Coins
check(after - before >= rarity.CoinsPerSecond * 4, string.format("coins grow %d -> %d (%d/s)", before, after, rarity.CoinsPerSecond))
check(alice.leaderstats.Coins.Value == after, "leaderstats Coins synced")
check(alice:GetAttribute("Income") == rarity.CoinsPerSecond, "Income attribute = " .. tostring(alice:GetAttribute("Income")))

-- Speed upgrade recalculation (phase 4 hook)
local egg3, prompt3 = findGroundEgg()
MOVE_TO(alice, egg3.Position); prompt3.Triggered:Fire(alice); ADVANCE(0.1)
local r3 = Config.GetRarity(alice:GetAttribute("CarriedEggRarity"))
MOVE_TO(alice, incModel.Base.Position); ADVANCE(1); incPrompt.Triggered:Fire(alice); ADVANCE(0.1)
local t1 = Config.GetIncubationTime(r3, 1)
ADVANCE(t1 / 2)
local snapBefore = Inc.GetSnapshot(alice)[1]
PDS.Get(alice).IncubationSpeedLevel = 5
Inc.RecalculateTimes(alice)
local snapAfter = Inc.GetSnapshot(alice)[1]
local t5 = Config.GetIncubationTime(r3, 5)
print(string.format("recalc: total %.1f -> %.1f, remaining %.1f -> %.1f", t1, t5, snapBefore.Remaining, snapAfter.Remaining))
check(math.abs(snapAfter.Remaining - t5 * (snapBefore.Remaining / t1)) < 0.2, "remaining time keeps progress after speed upgrade")
check(t5 >= Config.Upgrades.MinIncubationTime, "minimum incubation time respected")

-- Dying while carrying loses the egg
local egg4, prompt4 = findGroundEgg()
MOVE_TO(bob, egg4.Position); prompt4.Triggered:Fire(bob); ADVANCE(0.1)
check(Eggs.GetCarriedEgg(bob) ~= nil, "Bob carries an egg")
bob.Character.Humanoid.Died:Fire(); ADVANCE(0.1)
check(Eggs.GetCarriedEgg(bob) == nil and bob:GetAttribute("CarriedEggRarity") == nil, "dying loses the carried egg")

-- Full creature slots block incubating
for i = 2, 8 do table.insert(PDS.Get(bob).Creatures, { CreatureId = "SandBunny", Slot = i }) end
table.insert(PDS.Get(bob).Creatures, { CreatureId = "SandBunny", Slot = 1 })
ADVANCE(1)
local egg5, prompt5 = findGroundEgg()
MOVE_TO(bob, egg5.Position); prompt5.Triggered:Fire(bob); ADVANCE(0.1)
local incB = baseB.Model.Incubator1
MOVE_TO(bob, incB.Base.Position); ADVANCE(1); incB.Base.ProximityPrompt.Triggered:Fire(bob); ADVANCE(0.1)
local fullMsg = false
for _, e in REMOTE_LOG do if e.player == bob and e.args[1] == "Your creature spots are full! Sell a creature (hold E on it) to make room." then fullMsg = true end end
check(fullMsg and Eggs.GetCarriedEgg(bob) ~= nil, "full creature spots block incubating")

-- Leaving: base is cleaned and freed, eggs in incubator saved to profile
local aliceProfile = PDS.Get(alice)
REMOVE_PLAYER(alice); ADVANCE(0.1)
check(baseA.SignLabel.Text == "Free Base" and baseA.Owner == nil, "base freed when leaving")
check(baseA.Model:FindFirstChild("Incubator1") == nil, "incubators removed")
local leftover = false
for _, c in baseA.Model:GetChildren() do if c:GetAttribute("CreatureId") then leftover = true end end
check(not leftover, "creature models removed")
check(#aliceProfile.Incubating == 1, "incubating egg saved in profile (" .. tostring(aliceProfile.Incubating[1] and aliceProfile.Incubating[1].Remaining) .. "s left)")

-- New player takes base 1 and gets a clean one
local carol = ADD_PLAYER("Carol"); SPAWN_CHARACTER(carol); ADVANCE(0.5)
check(BaseService.GetBase(carol) == baseA and baseA.SignLabel.Text == "Carol's Base", "Carol reuses base 1")
check(#PDS.Get(carol).Creatures == 0 and baseA.Model:FindFirstChild("Incubator1") ~= nil, "Carol starts clean")

print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

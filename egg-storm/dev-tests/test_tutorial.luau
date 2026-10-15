local C = __mod("Config")
C.Storm.RainDuration = 100000
C.Upgrades.MinIncubationTime = 1
for _, r in C.Rarities do r.BaseIncubationTime = 5 end
--@@MAIN
local PDS = __mod("PlayerDataService")
local BaseService = __mod("BaseService")
local Eggs = __mod("EggService")
local Remotes = __mod("Remotes")
local action = Remotes.Event("TutorialAction")
local buy = Remotes.Event("BuyUpgrade")
local Workspace = game:GetService("Workspace")

local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
local function stepOf(p) return p:GetAttribute("TutorialStep") end
local function grab(p)
	for _, child in Workspace.Eggs:GetChildren() do
		local prompt = child:FindFirstChild("ProximityPrompt")
		if prompt and prompt.Enabled then
			MOVE_TO(p, child.Position); prompt.Triggered:Fire(p); ADVANCE(0.6); return
		end
	end
end

STORE_DATA["Player_702"] = { Coins = 900, Creatures = { { CreatureId = "SandBunny", Slot = 1 } } } -- jugador de antes
local newbie = ADD_PLAYER("Newbie", 701); SPAWN_CHARACTER(newbie)
local veteran = ADD_PLAYER("Veteran", 702); SPAWN_CHARACTER(veteran)
ADVANCE(1)
check(stepOf(newbie) == 1, "new player starts the tutorial at step 1 (grab an egg)")
check(stepOf(veteran) == 5, "players from before the tutorial don't see it")

action.OnServerEvent:Fire(newbie, "OpenedUpgrades"); action.OnServerEvent:Fire(newbie, "Hack"); action.OnServerEvent:Fire(newbie, 42); ADVANCE(0.1)
check(stepOf(newbie) == 1, "out-of-order or invalid actions don't skip steps")

ADVANCE(6)
grab(newbie)
check(stepOf(newbie) == 2, "grabbing an egg -> step 2 (bring it to the incubator)")
newbie.Character.Humanoid.Died:Fire(); ADVANCE(0.2)
check(stepOf(newbie) == 2 and Eggs.GetCarriedEgg(newbie) == nil, "losing the egg keeps step 2 (the client shows 'grab an egg' again)")
SPAWN_CHARACTER(newbie); ADVANCE(0.5)
grab(newbie)
local inc = BaseService.GetBase(newbie).Model.Incubator1
MOVE_TO(newbie, inc.Base.Position); ADVANCE(0.6); inc.Base.ProximityPrompt.Triggered:Fire(newbie); ADVANCE(0.2)
check(stepOf(newbie) == 3, "incubating -> step 3 (wait for it to hatch)")
ADVANCE(10)
check(#PDS.Get(newbie).Creatures == 1 and stepOf(newbie) == 4, "first creature hatches -> step 4 (open the upgrades panel)")
action.OnServerEvent:Fire(newbie, "OpenedUpgrades"); ADVANCE(0.1)
check(stepOf(newbie) == 5, "opening the upgrades panel finishes the tutorial")
local done = false
for _, e in REMOTE_LOG do if e.player == newbie and e.args[1] == "Tutorial complete! Good luck in the storm!" then done = true end end
check(done, "player is told the tutorial is complete")

-- Comprar una mejora en el paso 4 también lo termina
local p3 = ADD_PLAYER("Buyer", 703); SPAWN_CHARACTER(p3); ADVANCE(1)
PDS.Get(p3).TutorialStep = 4; PDS.SyncLevels(p3); PDS.AddCoins(p3, 1000)
local base3 = BaseService.GetBase(p3)
MOVE_TO(p3, base3.UpgradePanel.Position + Vector3.new(0, 0, -4)); ADVANCE(0.5)
buy.OnServerEvent:Fire(p3, "WalkSpeed"); ADVANCE(0.1)
check(stepOf(p3) == 5, "buying an upgrade at step 4 also finishes it")

-- Skip
local p4 = ADD_PLAYER("Skipper", 704); SPAWN_CHARACTER(p4); ADVANCE(1)
action.OnServerEvent:Fire(p4, "Skip"); ADVANCE(0.1)
check(stepOf(p4) == 5, "Skip finishes the tutorial")

-- Se guarda
local p5 = ADD_PLAYER("Halfway", 705); SPAWN_CHARACTER(p5); ADVANCE(6)
grab(p5)
REMOVE_PLAYER(p5); ADVANCE(1)
check(STORE_DATA["Player_705"].TutorialStep == 2, "tutorial step is saved (2)")
local p5b = ADD_PLAYER("Halfway", 705); SPAWN_CHARACTER(p5b); ADVANCE(1)
check(stepOf(p5b) == 2, "coming back continues the tutorial where it was")
REMOVE_PLAYER(newbie); ADVANCE(1)
check(STORE_DATA["Player_701"].TutorialStep == 5, "finished tutorial is saved")

print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

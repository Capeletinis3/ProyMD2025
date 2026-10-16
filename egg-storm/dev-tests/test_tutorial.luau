local C = __mod("Config")
C.Events.Chance = 0 -- sin eventos (salvo que la prueba los prenda a mano)
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6 -- sin olas
C.Upgrades.MinIncubationTime = 1
for _, r in C.Rarities do r.BaseIncubationTime = 5 end
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

local action = Remotes.Event("TutorialAction")
local buy = Remotes.Event("BuyUpgrade")
local reward = Config.Tutorial.StepReward
local function stepOf(p) return p:GetAttribute("TutorialStep") end
local function completes(p)
	local n = 0
	for _, e in REMOTE_LOG do if e.player == p and e.remote == "TutorialAction" and e.args[1] == "StepComplete" then n += 1 end end
	return n
end
local function toLobby(p) MOVE_TO(p, Vector3.new(60, 3, 0)); ADVANCE(0.6) end
STORE_DATA["Player_702"] = { Coins = 900, Creatures = { { CreatureId = "SandBunny", Slot = 1 } } } -- jugador de antes
local newbie = ADD_PLAYER("Newbie", 701); SPAWN_CHARACTER(newbie)
local veteran = ADD_PLAYER("Veteran", 702); SPAWN_CHARACTER(veteran)
ADVANCE(1)
local profile = PDS.Get(newbie)
check(stepOf(newbie) == 1, "new player starts the tutorial at step 1 (grab an egg)")
check(stepOf(veteran) == 5, "players from before the tutorial don't see it")
action.OnServerEvent:Fire(newbie, "OpenedUpgrades"); action.OnServerEvent:Fire(newbie, "Hack"); action.OnServerEvent:Fire(newbie, 42); ADVANCE(0.1)
check(stepOf(newbie) == 1, "invalid actions don't skip steps")
local coins = profile.Coins
grab(newbie, 1)
check(stepOf(newbie) == 2, "grabbing an egg -> step 2 (run back)")
check(profile.Coins == coins + reward and completes(newbie) == 1, "STEP COMPLETE! +100 coins")
ADVANCE(1)
check(stepOf(newbie) == 2, "still in the canyon: still step 2")
newbie.Character.Humanoid.Died:Fire(); ADVANCE(0.2)
check(stepOf(newbie) == 2 and Eggs.GetCarriedEgg(newbie) == nil, "losing the egg keeps step 2")
SPAWN_CHARACTER(newbie); ADVANCE(0.5)
toLobby(newbie)
check(stepOf(newbie) == 2, "going back without an egg doesn't count")
grab(newbie, 1)
toLobby(newbie)
check(stepOf(newbie) == 3 and completes(newbie) == 2, "back on the island with the egg -> step 3 (hatch it)")
useNest(newbie, 1)
check(stepOf(newbie) == 4 and completes(newbie) == 3, "egg in a nest -> step 4 (get rich)")
goToShop(newbie)
coins = profile.Coins
buy.OnServerEvent:Fire(newbie, "IncubationSpeed"); ADVANCE(0.2)
check(stepOf(newbie) == 5 and completes(newbie) == 4, "buying the first upgrade finishes the tutorial")
check(profile.Coins == coins - Config.Upgrades.IncubationSpeed[2].Cost + reward, "the last step pays too")
local doneMsg = false
for _, e in REMOTE_LOG do if e.player == newbie and e.args[1] == "Tutorial complete! Good luck in the canyon!" then doneMsg = true end end
check(doneMsg, "player is told the tutorial is complete")
-- Poner el huevo directo (sin pasar por el chequeo de "volver") completa los dos pasos
local p3 = ADD_PLAYER("Quick", 703); SPAWN_CHARACTER(p3); ADVANCE(1)
local c3 = PDS.Get(p3).Coins
grab(p3, 1)
PDS.Get(p3).TutorialStep = 2
useNest(p3, 1)
check(stepOf(p3) == 4 and PDS.Get(p3).Coins == c3 + reward * 3, "incubating at step 2 completes steps 2 and 3 (+200)")
-- Saltear: sin recompensa
local p4 = ADD_PLAYER("Skipper", 704); SPAWN_CHARACTER(p4); ADVANCE(1)
local c4 = PDS.Get(p4).Coins
action.OnServerEvent:Fire(p4, "Skip"); ADVANCE(0.1)
check(stepOf(p4) == 5 and PDS.Get(p4).Coins == c4, "Skip finishes the tutorial (no coins)")
-- Comprar una mejora antes de tiempo no saltea pasos
local p6 = ADD_PLAYER("Early", 706); SPAWN_CHARACTER(p6); ADVANCE(1)
PDS.AddCoins(p6, 1000); goToShop(p6)
buy.OnServerEvent:Fire(p6, "WalkSpeed"); ADVANCE(0.2)
check(stepOf(p6) == 1, "buying an upgrade at step 1 doesn't skip ahead")
-- Se guarda
local p5 = ADD_PLAYER("Halfway", 705); SPAWN_CHARACTER(p5); ADVANCE(1)
grab(p5, 1)
REMOVE_PLAYER(p5); ADVANCE(1)
check(STORE_DATA["Player_705"].TutorialStep == 2, "tutorial step is saved (2)")
local p5b = ADD_PLAYER("Halfway", 705); SPAWN_CHARACTER(p5b); ADVANCE(1)
check(stepOf(p5b) == 2, "coming back continues the tutorial where it was")
REMOVE_PLAYER(newbie); ADVANCE(1)
check(STORE_DATA["Player_701"].TutorialStep == 5, "finished tutorial is saved")

done()

local C = __mod("Config")
C.Events.Chance = 0
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6
C.Data.AutosaveInterval = 1e6
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

local Rebirth = __mod("RebirthService")
local Creatures = __mod("Creatures")
local CreatureService = __mod("CreatureService")
local remote = Remotes.Event("Rebirth")
local buy = Remotes.Event("BuyUpgrade")
local alice = ADD_PLAYER("Alice", 901); SPAWN_CHARACTER(alice); ADVANCE(1)
local profile = PDS.Get(alice)
local base = BaseService.GetBase(alice)
CreatureService.AddCreature(alice, Creatures.Get("GoldenDragon"))
local income = Config.GetRarity("Legendary").CoinsPerSecond
check(alice:GetAttribute("Rebirths") == 0 and alice:GetAttribute("Income") == income, "starts with 0 rebirths")
remote.OnServerEvent:Fire(alice, "Rebirth"); ADVANCE(0.1)
check(profile.Rebirths == 0 and lastNotify(alice) == "You need 100,000 coins to rebirth.", "not enough coins: no rebirth")
PDS.AddCoins(alice, 150000)
goToShop(alice)
buy.OnServerEvent:Fire(alice, "WalkSpeed"); ADVANCE(0.4)
buy.OnServerEvent:Fire(alice, "IncubationSpeed"); ADVANCE(0.4)
buy.OnServerEvent:Fire(alice, "ExtraIncubator"); ADVANCE(0.4)
local earned = profile.TotalEarned
ADVANCE(1.2)
remote.OnServerEvent:Fire(alice, "Rebirth"); remote.OnServerEvent:Fire(alice, "Rebirth"); ADVANCE(0.1)
check(profile.Rebirths == 1, "rebirth 1 (only once, even spamming)")
check(profile.Coins == 0 and profile.WalkSpeedLevel == 1 and profile.IncubationSpeedLevel == 1 and alice.Character.Humanoid.WalkSpeed == 16, "coins and speed upgrades reset")
check(profile.IncubatorCount == 2 and #profile.Creatures == 1, "creatures and incubators are kept")
check(profile.TotalEarned >= earned, "total earned (records) doesn't go down")
check(profile.BaseLevel == 2 and #base.Model.Locks:GetChildren() == 1 and CreatureService.GetFreeSlotCount(alice) == 9, "floor 2 unlocked: 10 shelves")
check(alice:GetAttribute("Income") == income * 1.25, "creatures make +25% (" .. tostring(alice:GetAttribute("Income")) .. "/s)")
check(lastNotify(alice) == "REBIRTH 1! Your creatures now make +25% coins. Floor 2 unlocked!", "message: " .. tostring(lastNotify(alice)))
local before = profile.Coins
ADVANCE(4)
local gained = profile.Coins - before
check(gained >= income * 1.25 * 3.5 and gained <= income * 1.25 * 4.5, "income really is +25% (+" .. gained .. " in 4 s)")
-- Segundo: piso 3
check(Config.RebirthCost(1) == 250000 and Config.RebirthCost(2) == 625000, "each rebirth costs x2.5 (100K, 250K, 625K...)")
PDS.AddCoins(alice, Config.RebirthCost(1)); ADVANCE(1.1)
remote.OnServerEvent:Fire(alice, "Rebirth"); ADVANCE(0.1)
check(profile.Rebirths == 2 and profile.BaseLevel == 3 and #base.Model.Locks:GetChildren() == 0, "rebirth 2 unlocks floor 3")
PDS.AddCoins(alice, Config.RebirthCost(2)); ADVANCE(1.1)
remote.OnServerEvent:Fire(alice, "Rebirth"); ADVANCE(0.1)
check(profile.Rebirths == 3 and profile.BaseLevel == 3 and lastNotify(alice) == "REBIRTH 3! Your creatures now make +75% coins.", "rebirth 3: only the bonus (no more floors)")
remote.OnServerEvent:Fire(alice, "Hack"); remote.OnServerEvent:Fire(alice, { "Rebirth" }); ADVANCE(1.1)
check(profile.Rebirths == 3, "junk requests are ignored")
-- Ilimitado
profile.Rebirths = 12
PDS.AddCoins(alice, Config.RebirthCost(12)); ADVANCE(1.1)
remote.OnServerEvent:Fire(alice, "Rebirth"); ADVANCE(0.1)
check(profile.Rebirths == 13 and alice:GetAttribute("Income") == income * Config.RebirthMultiplier(13), "no max: rebirth 13 works (x" .. Config.RebirthMultiplier(13) .. ")")
profile.Rebirths = 2
-- Se guarda y vuelve
REMOVE_PLAYER(alice); ADVANCE(1)
check(STORE_DATA[key(901)].Rebirths == 2 and STORE_DATA[key(901)].BaseLevel == 3, "rebirths are saved")
STORE_DATA[key(902)] = { Coins = 0, Rebirths = 1, TutorialStep = 5 } -- floors not saved: derived from rebirths
local bob = ADD_PLAYER("Bob", 902); SPAWN_CHARACTER(bob); ADVANCE(1)
check(PDS.Get(bob).BaseLevel == 2 and bob:GetAttribute("Rebirths") == 1, "a player with 1 rebirth always has floor 2")
-- Ganancia offline con el bonus
STORE_DATA[key(903)] = { Coins = 0, Rebirths = 2, TutorialStep = 5, SavedAt = os.time() - 3600, Creatures = { { CreatureId = "GoldenDragon", Slot = 1 } } }
local carol = ADD_PLAYER("Carol", 903); SPAWN_CHARACTER(carol); ADVANCE(1)
check(carol:GetAttribute("OfflineCoins") == math.floor(income * 1.5 * 3600 * 0.5), "offline earnings include the rebirth bonus")

done()

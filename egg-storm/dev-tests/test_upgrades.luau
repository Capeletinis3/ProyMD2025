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

local buy = Remotes.Event("BuyUpgrade")
local alice = ADD_PLAYER("Alice", 401); SPAWN_CHARACTER(alice); ADVANCE(1)
local profile = PDS.Get(alice)
profile.TutorialStep = 5 -- (sin tutorial: así los mensajes y la plata son los de la tienda)
PDS.AddCoins(alice, 100000)
-- Un huevo incubando, para ver que la mejora lo acelera
grab(alice, 1); useNest(alice, 1)
local before = Inc.GetSnapshot(alice)[1].Remaining
MOVE_TO(alice, Vector3.new(0, 3, 22)); ADVANCE(0.4) -- lejos de la tienda: igual se puede comprar (ventana del HUD)
buy.OnServerEvent:Fire(alice, "IncubationSpeed"); ADVANCE(0.4)
check(profile.IncubationSpeedLevel == 2 and lastNotify(alice) == "Hatching upgraded!", "buys Hatching from anywhere")
local after = Inc.GetSnapshot(alice)[1].Remaining
check(after < before * 0.95, string.format("the egg already incubating speeds up (%.1f -> %.1f)", before, after))
buy.OnServerEvent:Fire(alice, "ExtraIncubator"); ADVANCE(0.4)
buy.OnServerEvent:Fire(alice, "ExtraIncubator"); ADVANCE(0.4)
check(profile.IncubatorCount == 3 and nest(alice, 3):FindFirstChild("ProximityPrompt") and not nest(alice, 3):FindFirstChild("LockedGui"), "2 extra nests unlock nests 2 and 3")
buy.OnServerEvent:Fire(alice, "ExtraIncubator"); ADVANCE(0.4)
check(lastNotify(alice) == "Extra Nest is already maxed!", "max 3 nests")
buy.OnServerEvent:Fire(alice, "WalkSpeed"); ADVANCE(0.4)
check(alice.Character.Humanoid.WalkSpeed == Config.Upgrades.WalkSpeed[2].Speed, "Speed changes the walk speed")
-- Varios niveles de una (x10): compra los que alcance
local coins = profile.Coins
buy.OnServerEvent:Fire(alice, "WalkSpeed", 10); ADVANCE(0.4)
local level = profile.WalkSpeedLevel
local spent = 0
for l = 3, level do spent += Config.Upgrades.WalkSpeed[l].Cost end
check(level > 3 and coins - profile.Coins == spent and lastNotify(alice) == `Speed upgraded x{level - 2}!`, `x10 buys several levels at once ({level - 2}, {spent} coins)`)
check(alice.Character.Humanoid.WalkSpeed == Config.Upgrades.WalkSpeed[level].Speed, "the new speed is applied")
-- Suerte y Llevar huevos
buy.OnServerEvent:Fire(alice, "Luck", 2); ADVANCE(0.4)
check(profile.LuckLevel == 3 and alice:GetAttribute("LuckLevel") == 3, "Luck goes up 2 levels (attribute for the client)")
check(math.abs(Config.LuckChance(alice, "Common") - Config.Upgrades.Luck[3].Chance) < 1e-6, "Luck gives its chance for Common eggs")
check(Config.LuckChance(alice, "Mythic") < Config.LuckChance(alice, "Common"), "Luck helps less with rarer eggs")
check(Config.CarryCapacity(alice) == 1, "carries 1 egg at first")
buy.OnServerEvent:Fire(alice, "Carry", 100); ADVANCE(0.4)
check(profile.CarryLevel == 2 and Config.CarryCapacity(alice) == 2 and lastNotify(alice) == "Carry Eggs upgraded!", "Carry Eggs: 2 eggs at once (MAX only buys what's left)")
buy.OnServerEvent:Fire(alice, "Carry"); ADVANCE(0.4)
check(lastNotify(alice) == "Carry Eggs is already maxed!", "Carry Eggs maxes out")
coins = profile.Coins
buy.OnServerEvent:Fire(alice, "BaseFloor"); ADVANCE(0.4)
buy.OnServerEvent:Fire(alice, 123); ADVANCE(0.4)
buy.OnServerEvent:Fire(alice, "Luck", -5); ADVANCE(0.4)
buy.OnServerEvent:Fire(alice, "Luck", "lots"); ADVANCE(0.4)
check(profile.Coins == coins and profile.LuckLevel == 3, "junk is ignored (old Base Floor, bad ids, bad amounts)")
ADVANCE(1)
buy.OnServerEvent:Fire(alice, "Luck", 1e9); ADVANCE(0.4)
check(profile.LuckLevel <= #Config.Upgrades.Luck, "huge amounts are capped")
PDS.SpendCoins(alice, profile.Coins)
local walk = profile.WalkSpeedLevel
buy.OnServerEvent:Fire(alice, "WalkSpeed"); ADVANCE(0.4)
check(profile.WalkSpeedLevel == walk and lastNotify(alice):find("Not enough coins") ~= nil, "not enough coins: nothing happens")
REMOVE_PLAYER(alice); ADVANCE(1)
local saved = STORE_DATA[key(401)]
check(saved and saved.LuckLevel == profile.LuckLevel and saved.CarryLevel == 2 and saved.BaseLevel == nil, "Luck and Carry Eggs are saved")

done()

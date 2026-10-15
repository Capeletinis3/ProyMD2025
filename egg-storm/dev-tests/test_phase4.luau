__mod("Config").Storm.RainDuration = 100000 -- en estas pruebas llueve todo el tiempo
--@@MAIN
local Config = __mod("Config")
local PDS = __mod("PlayerDataService")
local BaseService = __mod("BaseService")
local Creatures = __mod("Creatures")
local CreatureService = __mod("CreatureService")
local Remotes = __mod("Remotes")
local buy = Remotes.Event("BuyUpgrade")

local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
local function lastNotify(p)
	for i = #REMOTE_LOG, 1, -1 do
		local e = REMOTE_LOG[i]
		if e.player == p and e.remote == "Notify" then return e.args[1] end
	end
	return nil
end
local function attempt(p, id)
	ADVANCE(0.5) -- respeta el cooldown entre compras
	buy.OnServerEvent:Fire(p, id)
	ADVANCE(0.1)
end

local alice = ADD_PLAYER("Alice"); SPAWN_CHARACTER(alice); ADVANCE(0.5)
local base = BaseService.GetBase(alice)
local profile = PDS.Get(alice)
check(base.UpgradePanel ~= nil, "base has an upgrade panel")
check(alice:GetAttribute("IncubationSpeedLevel") == 1 and alice:GetAttribute("BaseLevel") == 1, "levels published as attributes")
MOVE_TO(alice, base.UpgradePanel.Position + Vector3.new(0, 0, -4))

attempt(alice, "IncubationSpeed")
check(profile.IncubationSpeedLevel == 1 and lastNotify(alice) == "Not enough coins! You need 100.", "can't buy without coins: " .. tostring(lastNotify(alice)))

PDS.AddCoins(alice, 100000)
MOVE_TO(alice, base.UpgradePanel.Position + Vector3.new(0, 0, -80))
attempt(alice, "IncubationSpeed")
check(profile.IncubationSpeedLevel == 1 and profile.Coins == 100000, "can't buy from far away")
MOVE_TO(alice, base.UpgradePanel.Position + Vector3.new(0, 0, -4))

attempt(alice, "IncubationSpeed")
check(profile.IncubationSpeedLevel == 2 and profile.Coins == 100000 - 100, "Incubation Speed lv2 for 100")
check(alice:GetAttribute("IncubationSpeedLevel") == 2 and alice:GetAttribute("Coins") == 99900, "attributes updated")
check(lastNotify(alice) == "Incubation Speed upgraded!", "success message")
-- spam: dos pedidos seguidos sin esperar
ADVANCE(0.5); buy.OnServerEvent:Fire(alice, "IncubationSpeed"); buy.OnServerEvent:Fire(alice, "IncubationSpeed"); ADVANCE(0.1)
check(profile.IncubationSpeedLevel == 3, "spam only buys once (level " .. profile.IncubationSpeedLevel .. ")")
attempt(alice, "IncubationSpeed"); attempt(alice, "IncubationSpeed")
check(profile.IncubationSpeedLevel == 5, "Incubation Speed reaches level 5")
local coinsAtMax = profile.Coins
attempt(alice, "IncubationSpeed")
check(profile.Coins == coinsAtMax and lastNotify(alice) == "Incubation Speed is already maxed!", "maxed upgrade doesn't charge")
check(100000 - coinsAtMax == 100 + 500 + 2000 + 10000, "total spent on speed = 12,600")

local before = profile.Coins
attempt(alice, "Hack"); attempt(alice, 5); attempt(alice, nil)
check(profile.Coins == before, "invalid upgrade names are ignored")

attempt(alice, "ExtraIncubator")
check(profile.IncubatorCount == 2 and base.Model:FindFirstChild("Incubator2") ~= nil and base.Model:FindFirstChild("LockedSlot2") == nil, "Extra Incubator: incubator 2 built, LOCKED removed")
check(before - profile.Coins == 250, "incubator 2 costs 250")
attempt(alice, "ExtraIncubator")
check(profile.IncubatorCount == 3 and base.Model:FindFirstChild("Incubator3") ~= nil, "incubator 3 built")
local c3 = profile.Coins
attempt(alice, "ExtraIncubator")
check(profile.IncubatorCount == 3 and profile.Coins == c3, "can't go past 3 incubators")

attempt(alice, "WalkSpeed")
check(alice.Character.Humanoid.WalkSpeed == 20, "Walk Speed lv2 = 20")
attempt(alice, "WalkSpeed"); attempt(alice, "WalkSpeed")
check(alice.Character.Humanoid.WalkSpeed == 28 and profile.WalkSpeedLevel == 4, "Walk Speed max = 28")
SPAWN_CHARACTER(alice); ADVANCE(0.5)
check(alice.Character.Humanoid.WalkSpeed == 28, "walk speed kept after respawning")

MOVE_TO(alice, base.UpgradePanel.Position + Vector3.new(0, 0, -4))
local c4 = profile.Coins
attempt(alice, "BaseFloor")
check(profile.BaseLevel == 2 and base.Model:FindFirstChild("Floor2") ~= nil, "Base Floor builds a 2nd floor")
check(c4 - profile.Coins == 5000, "Base Floor costs 5,000")
check(#base.CreatureSlots == 14, "creature spots: 8 -> " .. #base.CreatureSlots)
attempt(alice, "BaseFloor")
check(profile.BaseLevel == 2 and lastNotify(alice) == "Base Floor is already maxed!", "Base Floor is one-time")

-- llenar las 14 mascotas: las últimas tienen que ir arriba
for i = 1, 14 do CreatureService.AddCreature(alice, Creatures.Get("SandBunny")) end
check(#profile.Creatures == 14 and CreatureService.GetFreeSlotCount(alice) == 0, "14 creatures fit")
local highest = 0
for _, c in base.Model:GetChildren() do
	if c:GetAttribute("CreatureId") then highest = math.max(highest, c.PrimaryPart.Position.Y) end
end
check(highest > 12, string.format("some creatures stand on the 2nd floor (y=%.1f)", highest))
check(alice:GetAttribute("Income") == 14, "income counts all 14 creatures")

REMOVE_PLAYER(alice); ADVANCE(0.1)
check(base.Model:FindFirstChild("Floor2") == nil and #base.CreatureSlots == 8, "leaving removes the 2nd floor")
check(base.Model:FindFirstChild("Incubator2") == nil and base.Model:FindFirstChild("Incubator3") == nil, "leaving removes extra incubators")
local bob = ADD_PLAYER("Bob"); SPAWN_CHARACTER(bob); ADVANCE(0.5)
check(BaseService.GetBase(bob) == base and base.Model:FindFirstChild("LockedSlot2") ~= nil and bob.Character.Humanoid.WalkSpeed == 16, "next owner starts from scratch")

print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

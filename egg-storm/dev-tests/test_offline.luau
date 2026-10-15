--@@MAIN
local Config = __mod("Config")
local PDS = __mod("PlayerDataService")
local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
local now = os.time()
local dragon = { { CreatureId = "GoldenDragon", Slot = 1 } } -- 100 coins/s
local function join(id, data)
	STORE_DATA["Player_" .. id] = data
	local p = ADD_PLAYER("P" .. id, id); SPAWN_CHARACTER(p); ADVANCE(0.5)
	return p
end

local a = join(801, { Coins = 1000, Creatures = dragon, SavedAt = now - 3600, TutorialStep = 5 })
check(PDS.Get(a).Coins >= 1000 + 180000 and PDS.Get(a).Coins < 1000 + 180000 + 200, "1 hour away with a 100/s creature at 50% = +180,000 (" .. PDS.Get(a).Coins .. ")")
check(a:GetAttribute("OfflineCoins") == 180000 and a:GetAttribute("OfflineSeconds") == 3600, "client gets the numbers for the welcome-back popup")
check(a.leaderstats.Coins.Value == PDS.Get(a).Coins, "leaderstats include it")

local b = join(802, { Coins = 0, Creatures = dragon, SavedAt = now - 2 * 24 * 3600, TutorialStep = 5 })
check(b:GetAttribute("OfflineSeconds") == Config.Economy.OfflineMaxHours * 3600 and b:GetAttribute("OfflineCoins") == 100 * 8 * 3600 * 0.5, "2 days away is capped at 8 hours (+1,440,000)")

local c = join(803, { Coins = 50, Creatures = dragon, SavedAt = now - 30, TutorialStep = 5 })
check(c:GetAttribute("OfflineCoins") == nil and PDS.Get(c).Coins < 50 + 200, "30 seconds away doesn't count (no popup)")

local d = join(804, { Coins = 50, Creatures = {}, SavedAt = now - 3600, TutorialStep = 5 })
check(d:GetAttribute("OfflineCoins") == nil and PDS.Get(d).Coins == 50, "no creatures = nothing earned")

local e = join(805, { Coins = 50, Creatures = dragon, TutorialStep = 5 })
check(e:GetAttribute("OfflineCoins") == nil, "old data without a save time: nothing (no crash)")

local f = join(806, { Coins = 50, Creatures = dragon, SavedAt = now + 5000, TutorialStep = 5 })
check(f:GetAttribute("OfflineCoins") == nil and PDS.Get(f).Coins < 50 + 200, "a save time in the future (clock skew) gives nothing")

local g = join(807, nil)
check(g:GetAttribute("OfflineCoins") == nil and PDS.Get(g).Coins == 0, "brand-new player: nothing")

-- Al salir se guarda la hora: volver enseguida no da nada extra
REMOVE_PLAYER(a); ADVANCE(1)
check(math.abs(STORE_DATA["Player_801"].SavedAt - os.time()) <= 2, "leaving saves the current time")
local a2 = join(801, STORE_DATA["Player_801"])
check(a2:GetAttribute("OfflineCoins") == nil, "rejoining right away gives no extra coins")

print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

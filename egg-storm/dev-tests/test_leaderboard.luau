for i = 1, 12 do
	ORDERED["EggStorm_TopEarners_v1"] = ORDERED["EggStorm_TopEarners_v1"] or {}
	ORDERED["EggStorm_TopEarners_v1"][tostring(9000 + i)] = i * 10000 -- 10,000 ... 120,000
end
--@@MAIN
local Config = __mod("Config")
local PDS = __mod("PlayerDataService")
local Leaderboard = __mod("LeaderboardService")
local Workspace = game:GetService("Workspace")
local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
local function board(id)
	for _, p in Workspace.Map.Leaderboards:GetChildren() do
		if p:GetAttribute("Board") == id then return p end
	end
end
local function rows(id)
	local gui = board(id):FindFirstChildOfClass("SurfaceGui")
	local out, subtitle = {}, nil
	local labels = 0
	for _, child in gui:GetChildren() do
		if child.ClassName == "TextLabel" then
			labels += 1
			if labels == 2 then subtitle = child.Text end
		elseif child.ClassName == "Frame" then
			local t = {}
			for _, l in child:GetChildren() do if l.ClassName == "TextLabel" then table.insert(t, l.Text) end end
			table.insert(out, t)
		end
	end
	return out, subtitle
end

check(board("TopEarners") ~= nil and board("EggsHatched") ~= nil, "both boards are in the lobby")
local r0 = rows("TopEarners")
check(#r0 == Config.Leaderboard.Size, "boards have 10 rows")

local alice = ADD_PLAYER("Alice", 1); SPAWN_CHARACTER(alice)
local bob = ADD_PLAYER("Bob", 2); SPAWN_CHARACTER(bob)
ADVANCE(1)
PDS.AddCoins(alice, 100000)
PDS.SpendCoins(alice, 60000)
PDS.AddCoins(alice, 500, true) -- devolución
check(PDS.Get(alice).TotalEarned >= 100000 and PDS.Get(alice).TotalEarned < 100100, "spending and refunds don't change total earned")
PDS.AddCoins(bob, 125000)
PDS.RecordHatch(bob); PDS.RecordHatch(bob); PDS.RecordHatch(alice)

ADVANCE(Config.Leaderboard.FirstUpdateDelay + 1)
local r, sub = rows("TopEarners")
check(sub:find("All servers") ~= nil, "subtitle: " .. tostring(sub))
check(r[1][2] == "Bob" and r[1][3] == "125,000 coins", "#1 is Bob from this server: " .. r[1][2] .. " " .. r[1][3])
check(r[2][2] == "User9012" and r[2][3] == "120,000 coins", "#2 comes from another server (name looked up): " .. r[2][2])
local aliceRank
for i, row in r do if row[2] == "Alice" then aliceRank = i end end
check(aliceRank == 4, "Alice is #4 with 100,000 (rank " .. tostring(aliceRank) .. ")")
check(r[10][1] == "#10" and r[10][2] ~= "---", "board shows exactly the top 10")
local h = rows("EggsHatched")
check(h[1][2] == "Bob" and h[1][3] == "2 eggs" and h[2][2] == "Alice", "eggs board: Bob 2, Alice 1")

-- DataStore caído: muestra el ranking de este servidor
ORDERED_FAIL = true
Leaderboard.UpdateNow()
local rl, subl = rows("TopEarners")
check(subl == "This server only (global board unavailable)" and rl[1][2] == "Bob" and rl[2][2] == "Alice" and rl[3][2] == "---", "when the store fails, it shows this server's ranking")
ORDERED_FAIL = false

-- Jugador sin guardado (Studio sin API): no se escribe en el ranking global
STUDIO = true; STORE_FAIL_ALL = true
local carol = ADD_PLAYER("Carol", 3); SPAWN_CHARACTER(carol); ADVANCE(1)
STORE_FAIL_ALL = false
PDS.AddCoins(carol, 999999)
Leaderboard.UpdateNow()
check(ORDERED["EggStorm_TopEarners_v1"]["3"] == nil, "players whose data didn't load aren't written to the global board")

-- Se guarda y se restaura
REMOVE_PLAYER(bob); ADVANCE(1)
check(STORE_DATA["Player_2"].TotalEarned == 125000 and STORE_DATA["Player_2"].EggsHatched == 2, "records are saved")
STORE_DATA["Player_4"] = { Coins = 777, Creatures = { { CreatureId = "SandBunny", Slot = 1 }, { CreatureId = "SandBunny", Slot = 2 } } }
local dave = ADD_PLAYER("Dave", 4); SPAWN_CHARACTER(dave); ADVANCE(1)
check(PDS.Get(dave).TotalEarned >= 777 and PDS.Get(dave).EggsHatched == 2, "older saves start with sensible records (coins, creatures)")

print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

__mod("Config").Storm.RainDuration = 100000
--@@MAIN
local Config = __mod("Config")
local PDS = __mod("PlayerDataService")
local BaseService = __mod("BaseService")
local Creatures = __mod("Creatures")
local CreatureService = __mod("CreatureService")
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
local function creatureAt(base, slot)
	local pad = base.CreatureSlots[slot]
	for _, c in base.Model:GetChildren() do
		if c:GetAttribute("CreatureId") and (c.PrimaryPart.Position - pad.Position).Magnitude < 8 and math.abs(c.PrimaryPart.Position.X - pad.Position.X) < 1 and math.abs(c.PrimaryPart.Position.Z - pad.Position.Z) < 1 then return c end
	end
end

local alice = ADD_PLAYER("Alice", 501); SPAWN_CHARACTER(alice)
local bob = ADD_PLAYER("Bob", 502); SPAWN_CHARACTER(bob)
ADVANCE(1)
local base = BaseService.GetBase(alice)
local profile = PDS.Get(alice)
CreatureService.AddCreature(alice, Creatures.Get("GoldenDragon")) -- pad 1
CreatureService.AddCreature(alice, Creatures.Get("SandBunny"))    -- pad 2
local dragon = creatureAt(base, 1)
local prompt = dragon.Body.ProximityPrompt
check(prompt.ActionText == "Sell" and prompt.ObjectText == "Golden Dragon · 6,000 coins", "sell button shows the price: " .. prompt.ObjectText)
check(prompt.HoldDuration == Config.Economy.SellHoldTimeRare, "rare creatures need a longer hold")
check(creatureAt(base, 2).Body.ProximityPrompt.HoldDuration == Config.Economy.SellHoldTime, "common creatures use the normal hold")
check(prompt:GetAttribute("OwnerUserId") == 501, "button is tagged with the owner (client hides it for others)")

-- Bob intenta vender la mascota de Alice
MOVE_TO(bob, dragon.Body.Position)
prompt.Triggered:Fire(bob); ADVANCE(0.2)
check(#profile.Creatures == 2 and lastNotify(bob) == "That's not your creature!", "Bob can't sell Alice's creature")

-- Alice desde lejos
MOVE_TO(alice, dragon.Body.Position + Vector3.new(0, 0, 80))
prompt.Triggered:Fire(alice); ADVANCE(0.6)
check(#profile.Creatures == 2, "can't sell from far away")

-- Alice cerca: vende
MOVE_TO(alice, dragon.Body.Position + Vector3.new(4, 0, 0))
local coins = profile.Coins
prompt.Triggered:Fire(alice); prompt.Triggered:Fire(alice); ADVANCE(0.2)
check(#profile.Creatures == 1 and profile.Creatures[1].CreatureId == "SandBunny", "Alice sells the Golden Dragon (only once, even spamming)")
check(profile.Coins - coins >= 6000 and profile.Coins - coins < 6010, "she gets 6,000 coins")
check(dragon.Parent == nil, "the creature model disappears")
check(alice:GetAttribute("Income") == 1, "income goes down to 1/s")
check(lastNotify(alice) == "Sold Golden Dragon for 6,000 coins!", "message: " .. tostring(lastNotify(alice)))

-- Pad libre se vuelve a usar
local slot = CreatureService.AddCreature(alice, Creatures.Get("CoralCat"))
check(slot == 1, "the freed pad is reused by the next creature")

-- Base llena: el huevo espera y sale apenas se vende una
for i = 1, 6 do CreatureService.AddCreature(alice, Creatures.Get("SandBunny")) end
check(CreatureService.GetFreeSlotCount(alice) == 0, "all 8 pads full")
ADVANCE(5)
local egg
for _, child in Workspace.Eggs:GetChildren() do
	local p = child:FindFirstChild("ProximityPrompt")
	if p and p.Enabled then egg = child break end
end
MOVE_TO(alice, egg.Position); egg.ProximityPrompt.Triggered:Fire(alice); ADVANCE(0.6)
local inc = base.Model.Incubator1
MOVE_TO(alice, inc.Base.Position); ADVANCE(0.6); inc.Base.ProximityPrompt.Triggered:Fire(alice); ADVANCE(0.2)
check(lastNotify(alice) == "Your creature spots are full! Sell a creature (hold E on it) to make room.", "full base tells you to sell")
-- Vende una para hacer lugar y ahora sí incuba
local bunny = creatureAt(base, 2)
MOVE_TO(alice, bunny.Body.Position); ADVANCE(0.6)
bunny.Body.ProximityPrompt.Triggered:Fire(alice); ADVANCE(0.2)
MOVE_TO(alice, inc.Base.Position); ADVANCE(0.6); inc.Base.ProximityPrompt.Triggered:Fire(alice); ADVANCE(0.2)
check(inc:FindFirstChild("Egg") ~= nil, "after selling, the egg can be incubated")

-- Se guarda
REMOVE_PLAYER(alice); ADVANCE(1)
check(STORE_DATA["Player_501"] and #STORE_DATA["Player_501"].Creatures == 7, "the sale is saved (7 creatures left)")

print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

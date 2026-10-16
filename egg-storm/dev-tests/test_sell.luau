local C = __mod("Config")
C.Events.Chance = 0 -- sin eventos (salvo que la prueba los prenda a mano)
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6 -- sin olas
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
local function creatureAt(base, slot)
	local shelf = base.CreatureSlots[slot]
	for _, c in base.Model:GetChildren() do
		if c:GetAttribute("CreatureId") and math.abs(c.PrimaryPart.Position.X - shelf.Position.X) < 0.5 and math.abs(c.PrimaryPart.Position.Z - shelf.Position.Z) < 0.5 and c.PrimaryPart.Position.Y > shelf.Position.Y then return c end
	end
end
local alice = ADD_PLAYER("Alice", 801); SPAWN_CHARACTER(alice)
local bob = ADD_PLAYER("Bob", 802); SPAWN_CHARACTER(bob)
ADVANCE(1)
local base = BaseService.GetBase(alice)
local profile = PDS.Get(alice)
CreatureService.AddCreature(alice, Creatures.Get("GoldenDragon")) -- estante 1
CreatureService.AddCreature(alice, Creatures.Get("SandBunny"))    -- estante 2
local legendaryPrice = Config.GetSellPrice(Config.GetRarity("Legendary"))
local dragon = creatureAt(base, 1)
local prompt = dragon.Body.ProximityPrompt
check(prompt.ActionText == "Sell" and prompt.ObjectText == "Golden Dragon · 7,200 coins", "sell button shows the price: " .. prompt.ObjectText)
check(prompt.HoldDuration == Config.Economy.SellHoldTimeRare, "rare creatures need a longer hold")
check(creatureAt(base, 2).Body.ProximityPrompt.HoldDuration == Config.Economy.SellHoldTime, "common creatures use the normal hold")
MOVE_TO(bob, dragon.Body.Position)
prompt.Triggered:Fire(bob); ADVANCE(0.2)
check(#profile.Creatures == 2 and lastNotify(bob) == "That's not your creature!", "Bob can't sell Alice's creature")
MOVE_TO(alice, dragon.Body.Position + Vector3.new(0, 0, 80))
prompt.Triggered:Fire(alice); ADVANCE(0.6)
check(#profile.Creatures == 2, "can't sell from far away")
MOVE_TO(alice, dragon.Body.Position + Vector3.new(4, 0, 0))
local coins = profile.Coins
prompt.Triggered:Fire(alice); prompt.Triggered:Fire(alice); ADVANCE(0.2)
check(#profile.Creatures == 1 and profile.Creatures[1].CreatureId == "SandBunny", "Alice sells the Golden Dragon (only once, even spamming)")
check(profile.Coins - coins >= legendaryPrice and profile.Coins - coins < legendaryPrice + 10, "she gets 7,200 coins")
check(dragon.Parent == nil and alice:GetAttribute("Income") == 1, "the model disappears and income goes down")
check(lastNotify(alice) == "Sold Golden Dragon for 7,200 coins!", "message: " .. tostring(lastNotify(alice)))
check(CreatureService.AddCreature(alice, Creatures.Get("CoralCat")) == 1, "the freed shelf is reused")
for _ = 1, 3 do CreatureService.AddCreature(alice, Creatures.Get("SandBunny")) end
check(CreatureService.GetFreeSlotCount(alice) == 0, "5 shelves full")
grab(alice, 1)
useNest(alice, 1)
check(lastNotify(alice) == "Your shelves are full! Sell a creature (hold E on it) to make room.", "full shelves tell you to sell")
local bunny = creatureAt(base, 2)
MOVE_TO(alice, bunny.Body.Position); ADVANCE(0.6)
bunny.Body.ProximityPrompt.Triggered:Fire(alice); ADVANCE(0.2)
useNest(alice, 1)
check(nestState(alice, 1) == "Incubating", "after selling, the egg can be placed")
REMOVE_PLAYER(alice); ADVANCE(1)
check(STORE_DATA[key(801)] and #STORE_DATA[key(801)].Creatures == 4, "the sale is saved (4 creatures left)")

done()

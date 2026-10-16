local C = __mod("Config")
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6
C.Events.Interval = 5; C.Events.Chance = 1; C.Events.Duration = 3
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

local Events = __mod("EventService")
local Creatures = __mod("Creatures")
local CreatureService = __mod("CreatureService")
check(Workspace:GetAttribute("Event") == "" and Workspace:GetAttribute("NextEventAt") ~= nil, "no event at the start; next event time published")
-- Double Coins (a mano, antes de que empiece el primero)
local alice = ADD_PLAYER("Alice", 701); SPAWN_CHARACTER(alice); ADVANCE(0.5)
CreatureService.AddCreature(alice, Creatures.Get("GoldenDragon"))
local income = Config.GetRarity("Legendary").CoinsPerSecond
Events.Set("DoubleCoins", 2)
local before = PDS.Get(alice).Coins
ADVANCE(2)
local gained = PDS.Get(alice).Coins - before
check(gained >= income * 2 * 1.5 and gained <= income * 2 * 2.5, "Double Coins doubles income (+" .. gained .. " in 2 s)")
Events.Set(nil)
local seen = {}
for round = 1, 14 do
	while Workspace:GetAttribute("Event") == "" do ADVANCE(0.1) end
	local id = Workspace:GetAttribute("Event")
	seen[id] = true
	if round == 1 then
		local left = Workspace:GetAttribute("EventEndsAt") - Workspace:GetServerTimeNow()
		check(math.abs(left - 3) < 0.2, "the event lasts its duration")
		local msg
		for _, e in REMOTE_LOG do if e.player == "ALL" then msg = e.args[1] end end
		check(msg and msg:find(Config.GetEvent(id).DisplayName, 1, true), "everyone is told: " .. tostring(msg))
	end
	while Workspace:GetAttribute("Event") ~= "" do ADVANCE(0.1) end
end
check(seen.GoldenRain and seen.LuckyStorm and seen.DoubleCoins and seen.MeteorShower, "all 4 events happen")

done()

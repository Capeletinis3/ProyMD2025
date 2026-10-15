local Config = __mod("Config")
Config.Events.ChancePerStorm = 1 -- todas las tormentas tienen evento
Config.Storm.RainDuration = 5
Config.Storm.WarningDuration = 1
Config.Storm.CalmDuration = 3
--@@MAIN
local Config = __mod("Config")
local Workspace = game:GetService("Workspace")

local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
local alice = ADD_PLAYER("Alice", 701); SPAWN_CHARACTER(alice)
ADVANCE(0.5)
local seen = {}
for round = 1, 12 do
	while Workspace:GetAttribute("StormPhase") ~= "Rain" do ADVANCE(0.1) end
	local id = Workspace:GetAttribute("StormEvent")
	local event = Config.GetEvent(id)
	if round == 1 then
		check(event ~= nil, "storm starts with an event: " .. tostring(id))
		local msg
		for _, e in REMOTE_LOG do if e.remote == "Notify" and e.player == "ALL" then msg = e.args[1] end end
		check(msg ~= nil and string.find(msg, event.DisplayName, 1, true) ~= nil, "everyone is told: " .. tostring(msg))
	end
	if event then seen[event.Id] = true end
	while Workspace:GetAttribute("StormPhase") ~= "Calm" do ADVANCE(0.1) end
	if round == 1 then
		check(Workspace:GetAttribute("StormEvent") == "", "event ends in the calm")
	end
end
check(seen.GoldenRain and seen.LuckyStorm and seen.DoubleCoins and seen.MeteorShower, "all 4 events happen")
print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

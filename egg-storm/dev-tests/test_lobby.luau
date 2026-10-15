__mod("Config").Economy.StartingCoins = 1000
__mod("Config").Storm.RainDuration = 100000
--@@MAIN
local Config = __mod("Config")
local PDS = __mod("PlayerDataService")
local Workspace = game:GetService("Workspace")
local Remotes = __mod("Remotes")
local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
ADVANCE(0.5)
local map = Workspace.Map
local board = map.EventBoard and map.EventBoard:FindFirstChild("Board")
check(board and board:GetAttribute("EventBoard"), "the hanging event board exists")
local guis = 0
for _, g in board:GetChildren() do
	if g.ClassName == "SurfaceGui" and g:FindFirstChild("Line1") and g:FindFirstChild("Line2") then guis += 1 end
end
check(guis == 2, "the board has 2 lines on each side")
local stall = map.UpgradeStalls:FindFirstChild("UpgradeStall")
local counter = stall and stall:FindFirstChild("CounterTop")
local prompt = counter and counter:FindFirstChild("ProximityPrompt")
check(prompt and prompt.ActionText == "Open" and prompt:GetAttribute("Shared") == true, "the lobby stall has a shared Open prompt")
local domes = 0
for _, c in map:GetChildren() do if c.Name == "BubbleDome" then domes += 1 end end
check(domes == 2, "two glass bubble domes in the lobby")

-- Comprar desde el puesto del lobby
local buy = Remotes.Event("BuyUpgrade")
local alice = ADD_PLAYER("Alice", 901); SPAWN_CHARACTER(alice); ADVANCE(1)
local profile = PDS.Get(alice)
MOVE_TO(alice, Vector3.new(0, 3, -25)) -- en el medio del lobby, lejos de todo
buy.OnServerEvent:Fire(alice, "IncubationSpeed"); ADVANCE(0.5)
check(profile.IncubationSpeedLevel == 1, "can't buy from the middle of the lobby")
MOVE_TO(alice, counter.Position + Vector3.new(0, 0, -5))
buy.OnServerEvent:Fire(alice, "IncubationSpeed"); ADVANCE(0.5)
check(profile.IncubationSpeedLevel == 2, "can buy at the lobby upgrade stall")
print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

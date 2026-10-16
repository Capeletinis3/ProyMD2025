local C = __mod("Config")
C.Events.Chance = 0
C.Waves.MinInterval = 3; C.Waves.MaxInterval = 3
C.Waves.FastChance = 0
C.Waves.SuperInterval = 20 -- la segunda ola ya es súper (para probarla)
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

local function phase() return Workspace:GetAttribute("WavePhase") end
local function at(p) return p.Character.HumanoidRootPart.Position end
local smoke = Workspace.Map.Volcano.Crater.VolcanoSmoke
check(phase() == "Calm" and Workspace:GetAttribute("NextSuperAt") ~= nil, "starts calm; super tsunami timer published")
local alice = ADD_PLAYER("Alice", 301); SPAWN_CHARACTER(alice)
local bob = ADD_PLAYER("Bob", 302); SPAWN_CHARACTER(bob)
local carol = ADD_PLAYER("Carol", 303); SPAWN_CHARACTER(carol)
local dave = ADD_PLAYER("Dave", 304); SPAWN_CHARACTER(dave)
ADVANCE(1)
grab(alice, 4)
check(Eggs.GetCarriedEgg(alice) ~= nil, "Alice carries an egg in the basalt zone")
MOVE_TO(alice, Vector3.new(900, 3, 0))
local cave
for _, c in Workspace.Map.Canyon.Caves:GetChildren() do
	if math.abs(c.SafeZone.Position.X - 880) < 1 then cave = c end
end
local bobSpot = cave.SafeZone.Position
MOVE_TO(bob, bobSpot) -- Bob se mete en la cueva
MOVE_TO(carol, Vector3.new(100, 3, 0)) -- Carol en la isla
MOVE_TO(dave, Vector3.new(500, 3, 10))

while phase() ~= "Warning" do ADVANCE(0.05) end
check(Workspace:GetAttribute("WaveKind") == "Normal" and smoke.Rate == 14, "warning: normal wave, the volcano smokes more")
local warnStart = os.clock()
while phase() ~= "Wave" do ADVANCE(0.05) end
check(math.abs(os.clock() - warnStart - Config.Waves.Normal.Warning) < 0.2, "5 seconds of warning")
check(Workspace:GetAttribute("WaveStartX") == 1360 and Workspace:GetAttribute("WaveSpeed") == 60 and Workspace:GetAttribute("WaveHeight") == 50, "wave starts at X = 1360, speed 60, height 50")

local reachAlice = (1360 - 900) / 60
ADVANCE(reachAlice - 0.4)
check((at(alice) - Vector3.new(900, 3, 0)).Magnitude < 0.1, "Alice is fine before the wave reaches her")
ADVANCE(0.6)
check(Eggs.GetCarriedEgg(alice) == nil and at(alice).X < 150, "the wave gets Alice: she loses her egg and goes back to the island")
check(lastNotify(alice) == "The wave got you! You lost your egg.", "Alice is told why")
check((at(bob) - bobSpot).Magnitude < 0.1, "Bob is safe inside the cave")
-- Dave sale detrás de la ola cuando ya pasó: no le hace nada
MOVE_TO(dave, Vector3.new(1000, 3, 10)); ADVANCE(1)
check((at(dave) - Vector3.new(1000, 3, 10)).Magnitude < 0.1, "after the wave passes, it's safe behind it")
MOVE_TO(dave, Vector3.new(400, 3, 10))
while phase() == "Wave" do ADVANCE(0.05) end
check(at(dave).X < 150, "the wave reaches the portal and gets Dave on the way")
check((at(carol) - Vector3.new(100, 3, 0)).Magnitude < 0.1, "the wave never enters the island")
check(phase() == "Calm" and smoke.Rate == 5, "calm again after the wave")

-- Segunda ola: súper tsunami (y después, que no vuelva a tocar súper en esta prueba)
Config.Waves.SuperInterval = 1e6
while phase() ~= "Warning" do ADVANCE(0.05) end
check(Workspace:GetAttribute("WaveKind") == "Super", "super tsunami after its timer")
local announced = false
for _, e in REMOTE_LOG do if e.player == "ALL" and e.args[1] == "SUPER TSUNAMI incoming! Hide in a cave!" then announced = true end end
check(announced, "everyone is told about the super tsunami")
while phase() ~= "Wave" do ADVANCE(0.05) end
check(Workspace:GetAttribute("WaveHeight") == 80 and Workspace:GetAttribute("WaveSpeed") == 90, "super tsunami: height 80, speed 90")
while phase() == "Wave" do ADVANCE(0.1) end

-- Tercera: rápida
Config.Waves.FastChance = 1
while phase() ~= "Warning" do ADVANCE(0.05) end
check(Workspace:GetAttribute("WaveKind") == "Fast", "fast wave")
while phase() ~= "Wave" do ADVANCE(0.05) end
check(Workspace:GetAttribute("WaveSpeed") == 120, "fast wave: speed 120")

done()

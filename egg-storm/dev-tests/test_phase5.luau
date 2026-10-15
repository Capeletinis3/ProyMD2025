local Config = __mod("Config")
Config.Storm.RainDuration = 30 -- acortamos la lluvia para que la prueba sea más corta
--@@MAIN
local Config = __mod("Config")
local Eggs = __mod("EggService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
local function phase() return Workspace:GetAttribute("StormPhase") end
local function worldEggs()
	local list = {}
	for _, child in Workspace.Eggs:GetChildren() do
		if child:GetAttribute("EggId") and child:FindFirstChild("ProximityPrompt") and child.ProximityPrompt.Enabled then table.insert(list, child) end
	end
	return list
end
local function alive(p) return p.Character.Humanoid.Health > 0 end

check(phase() == "Rain", "starts with egg rain")
check(Players.RespawnTime == Config.Storm.RespawnTime, "respawn time set to " .. tostring(Players.RespawnTime))

local alice = ADD_PLAYER("Alice"); SPAWN_CHARACTER(alice)
local bob = ADD_PLAYER("Bob"); SPAWN_CHARACTER(bob)
local carol = ADD_PLAYER("Carol"); SPAWN_CHARACTER(carol)
local dave = ADD_PLAYER("Dave"); SPAWN_CHARACTER(dave)
ADVANCE(4)
check(math.abs(Lighting.Brightness - 0.7) < 0.01 and Lighting.FogEnd == 700, "sky gets dark during the rain")

ADVANCE(16)
local eggs = worldEggs()
check(#eggs > 3, "eggs fell during the rain (" .. #eggs .. ")")
-- Alice agarra un huevo y se queda en el pasillo
local egg = eggs[1]
MOVE_TO(alice, egg.Position); egg.ProximityPrompt.Triggered:Fire(alice); ADVANCE(0.1)
check(Eggs.GetCarriedEgg(alice) ~= nil, "Alice carries an egg")
MOVE_TO(alice, Vector3.new(0, 3, 300))
MOVE_TO(bob, Vector3.new(0, 3, -20))   -- Bob en el lobby
MOVE_TO(carol, Vector3.new(30, 3, 700)) -- Carol lejos, sin huevo
MOVE_TO(dave, Vector3.new(0, 3, -1))   -- Dave justo detrás de la línea segura

while phase() ~= "Warning" do ADVANCE(0.05) end
check(true, "warning phase after the rain")
local function allEggs()
	local n = 0
	for _, child in Workspace.Eggs:GetChildren() do if child:GetAttribute("EggId") then n += 1 end end
	return n
end
local count = allEggs()
ADVANCE(5)
check(allEggs() == count, "no new eggs spawn during the warning")
while phase() ~= "Wave" do ADVANCE(0.05) end
check(true, "the wave starts after the warning")
check(Workspace:GetAttribute("WaveStartZ") == 825 and Workspace:GetAttribute("WaveSpeed") == Config.Storm.WaveSpeed, "wave attributes published")

-- La ola tarda (825 - 700) / 70 = 1.8 s en llegar a Carol
ADVANCE(1.5)
check(alive(carol), "Carol is still alive before the wave reaches her")
-- Huevos: los que están detrás del frente ya no existen, los de adelante sí
local front = 825 - Config.Storm.WaveSpeed * 1.5
local ok = true
for _, e in worldEggs() do if e.Position.Z >= front then ok = false end end
check(ok, string.format("eggs behind the wave front (z>=%.0f) were washed away", front))
ADVANCE(0.5)
check(not alive(carol), "the wave gets Carol at z=700")
check(alive(alice), "Alice (z=300) still alive while the wave is far")
ADVANCE(6.5)
check(not alive(alice), "the wave gets Alice at z=300")
check(Eggs.GetCarriedEgg(alice) == nil and alice:GetAttribute("CarriedEggRarity") == nil, "Alice lost her egg")
local msg
for _, e in REMOTE_LOG do if e.player == alice and e.remote == "Notify" then msg = e.args[1] end end
check(msg == "The wave got you! You lost your egg.", "Alice is told why: " .. tostring(msg))
ADVANCE(5)
check(phase() == "Calm", "calm after the wave")
check(alive(bob), "Bob in the lobby survives")
check(alive(dave), "Dave right behind the safe line survives")
check(#worldEggs() == 0, "no eggs left on the ground after the wave")
ADVANCE(4)
check(Lighting.Brightness == 2 and Lighting.FogEnd == 100000, "sun comes back in the calm")
ADVANCE(Config.Storm.CalmDuration)
check(phase() == "Rain", "the cycle starts again")

print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

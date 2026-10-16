local C = __mod("Config")
C.Events.Chance = 0 -- sin eventos (salvo que la prueba los prenda a mano)
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6 -- sin olas
C.EggRain.Interval = 30; C.EggRain.Duration = 6; C.EggRain.EggLifetime = 20
for _, r in C.Rarities do r.BaseIncubationTime = 100 end
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

local Rain = __mod("EggRainService")
ADVANCE(0.5)
local now = Workspace:GetServerTimeNow()
local nextAt = Workspace:GetAttribute("NextEggRainAt")
check(typeof(nextAt) == "number" and math.abs(nextAt - now - Config.EggRain.Interval) < 2, "the HUD knows when the next egg rain is")
local function rainEggs()
	local list = {}
	for _, egg in Workspace.Eggs:GetChildren() do
		if egg.Position.Y > 0 and (egg:FindFirstChild("ProximityPrompt") ~= nil) then table.insert(list, egg) end
	end
	return list
end
local before = #Workspace.Eggs:GetChildren()
ADVANCE(Config.EggRain.Interval + 0.5)
check(Workspace:GetAttribute("EggRainEndsAt") ~= nil and Rain.IsRaining(), "every 15 minutes (30 s in this test) the egg rain starts")
local allNotified = false
for _, e in REMOTE_LOG do if e.remote == "Notify" and e.player == "ALL" and tostring(e.args[1]):find("EGG RAIN") then allNotified = true end end
check(allNotified, "everyone is told: EGG RAIN!")
ADVANCE(Config.EggRain.Duration + 2)
local after = #Workspace.Eggs:GetChildren()
check(after - before >= Config.EggRain.Duration / Config.EggRain.DropEvery * 0.6, string.format("lots of eggs fall (%d new)", after - before))
check(not Rain.IsRaining() and Workspace:GetAttribute("EggRainEndsAt") == nil, "the rain stops after its duration")
local inCanyon, zoneOk = true, true
for _, egg in Workspace.Eggs:GetChildren() do
	if egg.Position.X < Config.Map.CanyonStartX or math.abs(egg.Position.Z) > Config.Map.CanyonWidth / 2 then inCanyon = false end
end
check(inCanyon, "the eggs land inside the canyon")
ADVANCE(Config.EggRain.EggLifetime + 2)
check(#Workspace.Eggs:GetChildren() <= before + 2, "eggs nobody grabbed disappear after a while (" .. #Workspace.Eggs:GetChildren() .. " left)")
-- Más variantes que lo normal
local Eggs2 = __mod("EggService")
local special = 0
for _ = 1, 400 do
	local egg = Eggs2.SpawnEgg({ Rain = true })
	if egg.Variant.Id ~= "Normal" then special += 1 end
end
check(special > 400 * 0.3, "rain eggs have way more variants (" .. special .. "/400; normal is 15%)")

done()

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

ADVANCE(0.5)
local Lighting = game:GetService("Lighting")
local map = Workspace.Map
local bases = BaseService.GetBases()
check(#bases == 8, "8 bases")
local allGood = true
for _, b in bases do
	local unlocked = 0
	for _, s in b.CreatureSlots do if s:GetAttribute("Unlocked") then unlocked += 1 end end
	local center = b.Model.PrimaryPart.Position
	local nestsInFront = true
	for _, ped in b.IncubatorSlots do
		if ped.Position.Magnitude >= center.Magnitude then nestsInFront = false end
	end
	local look = b.Facing.LookVector
	local toCenter = (Vector3.new(0, 0, 0) - center)
	if not (#b.IncubatorSlots == 3 and #b.CreatureSlots == 15 and unlocked == 5 and nestsInFront and look:Dot(toCenter) > 0 and #b.Model.Locks:GetChildren() == 2) then
		allGood = false
		print("  base", b.Id, #b.IncubatorSlots, #b.CreatureSlots, unlocked, nestsInFront)
	end
end
check(allGood, "every base: faces the altar, 3 incubators in front, 15 shelves (5 open), floors 2-3 locked")
local spawn = map.Lobby.SpawnLocation
check(spawn.ClassName == "SpawnLocation" and (spawn.Position - Vector3.new(0, 2.5, 22)).Magnitude < 0.01, "players spawn next to the altar")
check(map.Lobby.Altar.GoldenEgg:GetAttribute("Spin") == 20, "golden egg on the altar spins")

-- Cañón
local floors = map.Canyon.Floor
local zonesOk = true
for i, zone in Config.Zones do
	local p = floors:FindFirstChild("Zone" .. i)
	local x0, x1 = Config.ZoneRange(i)
	if not p or math.abs(p.Position.X - (x0 + x1) / 2) > 0.01 or p.Size.X ~= 200 or p.Size.Z ~= 80 or p.Color ~= zone.Color then zonesOk = false end
end
check(zonesOk, "6 zone floors, 200 long and 80 wide, with their colors")
local caves = map.Canyon.Caves:GetChildren()
local safeOk, vip = true, 0
for _, cave in caves do
	local zone = cave:FindFirstChild("SafeZone")
	if not zone or zone:GetAttribute("Safe") ~= true or zone.CanCollide ~= false then safeOk = false end
	if cave:GetAttribute("Vip") then
		vip += 1
		if not cave:FindFirstChild("VipBarrier") then safeOk = false end
	end
end
check(#caves == 12 and safeOk and vip == 1, "12 caves with a SafeZone each (1 VIP with a barrier)")
local xs = {}
for _, c in Config.Caves do table.insert(xs, c.X) end
table.sort(xs)
check(xs[2] - xs[1] < xs[#xs] - xs[#xs - 1], "caves are farther apart deeper in the canyon")

-- Puntos de huevos
local spawns = Workspace.EggSpawns
local all = {}
local countsOk = true
for i, zone in Config.Zones do
	local list = spawns["Zone" .. i]:GetChildren()
	if #list ~= zone.SpawnCount then countsOk = false; print("  zone", i, #list) end
	for _, s in list do table.insert(all, s.Position) end
end
check(countsOk, "each zone has its number of egg spawns (16, 14, 12, 10, 8, 6)")
local minDist = math.huge
for i = 1, #all do for j = i + 1, #all do
	local d = Vector3.new(all[i].X - all[j].X, 0, all[i].Z - all[j].Z).Magnitude
	minDist = math.min(minDist, d)
end end
check(minDist >= 15, string.format("egg spawns are at least 15 apart (%.1f)", minDist))
local caveDist = math.huge
for _, s in all do
	for _, c in Config.Caves do
		local half = Config.CaveWidth(c) / 2
		local dx = math.max(0, math.abs(s.X - c.X) - half)
		local dz = math.abs(c.Side * 40 - s.Z)
		caveDist = math.min(caveDist, math.sqrt(dx * dx + dz * dz))
	end
end
check(caveDist >= 6, string.format("egg spawns are at least 6 from any cave (%.1f)", caveDist))

-- Puestos, portal, volcán, luz
local stalls = {}
for _, s in map.Lobby.Stalls:GetChildren() do stalls[s.Name] = s end
check(stalls.UpgradeShop and stalls.Merchant and stalls.Rankings and stalls.Trading, "4 stalls: upgrades, merchant, rankings, trading")
local facing = true
for _, s in map.Lobby.Stalls:GetChildren() do
	local c = s.Counter
	if c.Position.Magnitude >= s.StallBase.Position.Magnitude then facing = false end
end
check(facing, "stalls face the altar (counter on the altar side)")
local totems = 0
for _, p in map.Lobby.Portal:GetChildren() do if p.Name == "Totem" and math.abs(p.Position.X - 150) < 0.01 then totems += 1 end end
check(totems == 2, "tiki portal at the canyon entrance (X = 150)")
check(map.Volcano and (map.Volcano.Crater.Position - Vector3.new(1600, 206, 0)).Magnitude < 1, "volcano at the end of the canyon (lava lake in the crater)")
check(Lighting.ClockTime == 14.5 and Lighting.Brightness == 2.5 and Lighting:FindFirstChildOfClass("Atmosphere") ~= nil, "lighting from the spec")

-- Todo anclado
local loose = 0
for _, p in ALL_PARTS do if p.Parent and p.Anchored ~= true and not p:GetAttribute("EggId") and p.Name ~= "HumanoidRootPart" and p.Name ~= "Head" then loose += 1 end end
check(loose == 0, "all map parts are anchored (" .. loose .. " loose)")

done()

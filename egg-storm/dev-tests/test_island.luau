local C = __mod("Config")
C.Events.Chance = 0
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6
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


local Island = __mod("IslandBuilder")
local I = Config.Island
local map = Workspace.Map
check(Workspace:GetAttribute("IslandReady") == nil, "the terrain is built in the background (server starts right away)")
ADVANCE(30, 0.02)
check(Workspace:GetAttribute("IslandReady") == true and VOXEL_WRITES > 50, "the island terrain finishes (" .. VOXEL_WRITES .. " pieces, " .. VOXEL_COUNT .. " voxels)")

-- El lobby y el cañón nunca quedan tapados
local covered = 0
for x = -148, 148, 4 do for z = -168, 168, 4 do
	if Island.Sample(x, z) > -2 then covered += 1 end
end end
check(covered == 0, "terrain stays under the lobby")
covered = 0
local hx, hz
for x = Config.Map.CanyonStartX, Config.Map.CanyonStartX + Config.Map.CanyonLength, 4 do for z = -58, 58, 2 do
	if Island.Sample(x, z) > -2 then covered += 1; hx, hz = x, z end
end end
check(covered == 0, "terrain stays under the canyon floor, walls and caves " .. tostring(hx) .. "," .. tostring(hz))
-- Alrededor del lobby: plano
local bumpy = 0
for x = -160, 160, 4 do for _, z in { -176, 176 } do
	local h = Island.Sample(x, z)
	if math.abs(h) > 1 then bumpy += 1 end
end end
for z = -176, 176, 4 do
	local h = Island.Sample(-156, z)
	if math.abs(h) > 1 then bumpy += 1 end
end
check(bumpy == 0, "flat ground right around the lobby (" .. bumpy .. " bumps)")
-- Acantilados al lado del cañón
local cliffs, low = 0, 0
for x = 260, 1300, 20 do for _, side in { -1, 1 } do
	local h, kind = Island.Sample(x, side * 66)
	if h > 30 then cliffs += 1 else low += 1 end
end end
check(low == 0, "rock cliffs along both canyon walls (" .. cliffs .. " high, " .. low .. " low)")
-- Volcán
local V = I.Volcano
local peak, peakKind = -math.huge, nil
for x = V.X - 120, V.X + 120, 2 do for z = -120, 120, 2 do
	local h, kind = Island.Sample(x, z)
	if h > peak then peak, peakKind = h, kind end
end end
check(math.abs(peak - V.RimHeight) < 1, "the volcano is 240 high (crater rim): " .. math.floor(peak))
local center = Island.Sample(V.X, V.Z)
check(math.abs(center - (V.RimHeight - V.CraterDepth)) < 0.5, "the crater sinks 38 studs")
check(math.abs(Island.Sample(V.X - 150, 0) - V.Peak * (1 - 150 / V.Radius) ^ V.Power) < V.Peak * 0.15, "the slope follows 330 × (1 − r/380)^1.55")
local h1, h2, h3 = Island.Sample(V.X + 100, 0), Island.Sample(V.X + 200, 0), Island.Sample(V.X + 300, 0)
check(h1 - h2 > h2 - h3, "curved slopes: steep at the top, gentle at the bottom")
local endWall = Island.Sample(Config.Map.CanyonStartX + Config.Map.CanyonLength + 8, 0)
check(endWall > 40, "the canyon ends against the volcano slope (" .. math.floor(endWall) .. ")")
local rivers = 0
for index in I.LavaRivers do
	local r = 150
	local a = Island.RiverAngle(index, r)
	local _, kind = Island.Sample(V.X + math.cos(a) * r, V.Z + math.sin(a) * r)
	if kind == "River" then rivers += 1 end
end
check(rivers == 3, "3 lava rivers carved in the slope")
local _, k1 = Island.Sample(V.X + 300, 40)
check(Island.MaterialFor("Volcano", 200, 0, 0, 0) == Enum.Material.Slate and Island.MaterialFor("Volcano", 120, 0, 0, 0) == Enum.Material.Basalt and Island.MaterialFor("Volcano", 10, 0, 0, 0) == Enum.Material.LeafyGrass, "colors by height: jungle → rock → basalt → dark stone")
check(map.Volcano.Crater:FindFirstChild("VolcanoSmoke") and map.Volcano.Crater:FindFirstChild("VolcanoEmbers"), "smoke and embers")
local lava = 0
for _, p in map.Volcano:GetChildren() do if p.Name == "LavaRiver" then lava += 1 end end
check(lava >= 30, "glowing lava along the rivers (" .. lava .. " pieces)")

-- Costa, mar y arrecifes
local _, kSea = Island.Sample(-900, 0)
check(kSea == "Sea", "deep sea far away")
local reefs = 0
for x = I.MinX, I.MaxX, 16 do for z = I.MinZ, I.MaxZ, 16 do
	local _, kind = Island.Sample(x, z)
	if kind == "Reef" then reefs += 1 end
end end
check(reefs > 30 and reefs < 700, "reefs near the coast (" .. reefs .. ")")
check(#Island.ReefRocks() == I.ReefRocks, "rocks sticking out of the sea")
-- Islas: tamaño de la imagen
local function land(x, z) return Island.CoastDistance(x, z) > 0 end
check(land(-380, 0) and not land(-560, 0), "west point")
check(land(1010, -360) and land(590, 400), "north cove and south peninsula")
check(land(1950, 0) and not land(2120, 0), "the volcano's east coast")
-- Laguna, cascada, faro, barco, muelle
local lh, lk = Island.Sample(I.Lagoon.X, I.Lagoon.Z)
check(lk == "Lagoon" and lh < I.SeaLevel - 3, "the lagoon fills with water")
local fall = map.Island:FindFirstChild("Waterfall")
check(fall and fall.Water.Size.Y > 15, "waterfall into the lagoon (" .. (fall and math.floor(fall.Water.Size.Y) or 0) .. " tall)")
local lighthouse = map.Island:FindFirstChild("Lighthouse")
local base = lighthouse and lighthouse.Base.Position
check(base and base.X < -250 and base.Z < -100 and Island.CoastDistance(base.X, base.Z) > 15, "lighthouse on the north-west point")
local beam = lighthouse and lighthouse.Beam
check(beam and beam:GetAttribute("Spin") > 0, "its light beam spins")
local wreck = map.Island:FindFirstChild("Shipwreck")
check(wreck and Island.CoastDistance(wreck.Hull.Position.X, wreck.Hull.Position.Z) < -20, "shipwreck in the water off the point")
local dock = map.Island:FindFirstChild("Dock")
local deck = dock and dock.Deck
check(deck and Island.CoastDistance(deck.Position.X, deck.Position.Z) < 0 and deck.Position.Z > 300, "dock going out to sea from the south peninsula")
local boats = 0
for _, b in dock:GetChildren() do if b.Name == "Boat" then boats += 1 end end
check(boats == 2, "2 boats at the dock")
-- Decoración sobre el piso (no flota ni está enterrada) y fuera del lobby/cañón
local palms, trees, bad = 0, 0, 0
for _, m in map.Island.Decor:GetChildren() do
	if m.Name == "Palm" then palms += 1 elseif m.Name == "JungleTree" then trees += 1 end
end
for _, p in map.Island.Decor:GetDescendants() do
	if p.Name == "Trunk" and p.Parent.Name == "JungleTree" then
		local h = Island.Sample(p.Position.X, p.Position.Z)
		local bottom = p.Position.Y - p.Size.Y / 2
		if math.abs(bottom - h) > 2 then bad += 1 end
		if math.abs(p.Position.Z) < 75 and p.Position.X > 140 and p.Position.X < 1360 then bad += 1 end
	end
end
check(palms == I.Palms and trees == I.Trees, "palms and jungle trees (" .. palms .. ", " .. trees .. ")")
check(bad == 0, "trees stand on the ground, away from the canyon (" .. bad .. " wrong)")

-- Nadie entra al cañón por arriba ni por atrás
local barriers = map.Canyon:FindFirstChild("Barriers")
local top, back = 0, 0
for _, b in barriers:GetChildren() do
	if b.Name == "TopBarrier" and b.CanCollide ~= false and b.Position.Y - b.Size.Y / 2 <= Config.Map.CanyonWallHeight then top += 1 end
	if b.Name == "EndBarrier" then back += 1 end
end
check(top == 2 and back == 1, "invisible walls above the canyon walls and at its end")
done()

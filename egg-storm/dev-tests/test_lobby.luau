local C = __mod("Config")
C.Events.Chance = 0 -- sin eventos (salvo que la prueba los prenda a mano)
C.Waves.MinInterval = 1e6; C.Waves.MaxInterval = 1e6 -- sin olas
C.Economy.StartingCoins = 1000
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
local map = Workspace.Map
local stalls = map.Lobby.Stalls
local shopPrompt = stalls.UpgradeShop.Counter.ProximityPrompt
check(shopPrompt.ActionText == "Open" and shopPrompt:GetAttribute("Shared") == true, "the Upgrades shop has an Open button for everyone with a base")
local alice = ADD_PLAYER("Alice", 601); SPAWN_CHARACTER(alice); ADVANCE(1)
check(stalls.Merchant.Counter.ProximityPrompt.ObjectText == "Mystery Merchant", "the Mystery Merchant has its Open button (window on the client)")
local before = lastNotify(alice)
stalls.Trading.Counter.ProximityPrompt.Triggered:Fire(alice); ADVANCE(0.1)
check(lastNotify(alice) == before, "Trading opens its own window (no 'coming soon' message)")
local boards = stalls.Rankings.Leaderboards
local ids = {}
for _, m in boards:GetChildren() do ids[m.Board:GetAttribute("Board")] = true end
check(ids.TopEarners and ids.EggsHatched, "Rankings stall has the 2 record boards")
local events = stalls.Rankings.EventBoard.Board
local gui = events:FindFirstChildOfClass("SurfaceGui")
check(events:GetAttribute("EventBoard") and gui.Title and gui.Line1 and gui.Line2 and gui.Line3, "event board with 3 lines (next wave, super tsunami, event)")
-- Aldea de la selva
local village = map.Lobby.Village
local V = Config.Village
local function named(root, name)
	local list = {}
	for _, d in root:GetDescendants() do if d.Name == name then table.insert(list, d) end end
	return list
end
local water = named(village.Moat, "Water")
local wet = true
for _, w in water do
	local r = Vector3.new(w.Position.X, 0, w.Position.Z).Magnitude
	if w.CanCollide or math.abs(r - (V.PlazaRadius + V.MoatWidth / 2)) > 0.5 then wet = false end
end
check(#water == 40 and wet, "the altar plaza is surrounded by a water moat (you can wade through it)")
local bridgesOk = 0
for k = 1, 4 do
	local bridge = village.Moat:FindFirstChild("Bridge" .. k)
	local planks = bridge and named(bridge, "Plank") or {}
	local solid, highest = true, 0
	for _, plank in planks do
		if not plank.CanCollide then solid = false end
		highest = math.max(highest, plank.Position.Y)
	end
	if #planks == 8 and solid and highest > 1.5 and #named(bridge, "Lantern") == 2 then bridgesOk += 1 end
end
check(bridgesOk == 4, "4 arched wooden bridges with lanterns")
local stallsOut = true
for _, s in stalls:GetChildren() do
	local p = s.StallBase.Position
	if Vector3.new(p.X, 0, p.Z).Magnitude < V.PlazaRadius + V.MoatWidth + 7 or math.abs(math.abs(p.X) - math.abs(p.Z)) > 0.1 then stallsOut = false end
end
check(stallsOut, "the 4 stalls are on the diagonals, outside the moat")
local lagoon = village.Lagoon
local stones = named(lagoon, "SteppingStone")
local stonesSolid = true
for _, st in stones do if not st.CanCollide then stonesSolid = false end end
check(lagoon.Waterfall.Mist and #stones == 7 and stonesSolid and #named(lagoon, "Flamingo") == 3 and #named(lagoon, "Bench") == 2, "lagoon: waterfall with mist, stepping stones, flamingos and benches")
local tree = village.GiantTree
local ladder = tree.RopeLadder
local platform = tree.Platform
check(ladder.ClassName == "TrussPart" and ladder.Position.Y + ladder.Size.Y / 2 >= platform.Position.Y + platform.Size.X / 2, "giant tree: a rope ladder you can climb up to the platform")
check(tree.TreeHouse and tree.SwingSeat and #named(tree, "HangingLantern") >= 2 and tree.Fireflies.Fireflies, "treehouse, swing, hanging lanterns and fireflies")
local camp = village.FirePit
check(camp.Bonfire:FindFirstChildOfClass("Fire") and camp.Bonfire.Sparks and #named(camp, "LogSeat") == 18, "tiki fire pit with sparks and 3 rows of logs")
check(camp.Stage.GiantMask and #named(camp.Stage, "Drum") == 3 and camp.Stage.StageFloor.Position.Z < camp.Bonfire.Position.Z, "a stage with a giant tiki mask and drums behind the fire")
local garden = village.EggGarden
local eggsOk = true
for i, rarity in Config.Rarities do
	local nest = garden:FindFirstChild(rarity.Id .. "Nest")
	local egg = nest and nest.GiantEgg
	local glows = Config.RarityRank(rarity.Id) >= Config.RarityRank("Legendary")
	if not egg or egg.Color ~= rarity.Color or (egg.Material == Enum.Material.Neon) ~= glows or (glows and egg:GetAttribute("Spin") == 0) then eggsOk = false end
	if not nest or nest.RaritySign:FindFirstChildOfClass("SurfaceGui"):FindFirstChildOfClass("TextLabel").Text ~= rarity.DisplayName:upper() then eggsOk = false end
end
check(eggsOk and #Config.Rarities == 6 and garden.FlowerArch, "egg garden: the 6 giant rarity eggs with signs (the rare ones glow) and a flower arch")
-- Pasarela hasta cada hábitat
local spursOk = true
for index, b in BaseService.GetBases() do
	local spur = village.Boardwalk:FindFirstChild("Spur" .. index)
	local closest = math.huge
	for _, plank in spur and named(spur, "Plank") or {} do
		closest = math.min(closest, (plank.Position - b.SpawnPoint.Position).Magnitude)
	end
	if closest > 12 then spursOk = false end
end
check(spursOk, "a boardwalk goes from the plaza to every habitat entrance")
-- Nada sólido en el camino (puentes, pasarela y camino al cañón)
local function inPath(x, z)
	local onBoardwalk = math.abs(math.abs(z) - V.BoardwalkZ) < 4 and math.abs(x) < 146
	local toBoardwalk = math.abs(x) < 4 and math.abs(z) > V.PlazaRadius and math.abs(z) < V.BoardwalkZ - 4
	local toCanyon = math.abs(z) < 4 and x > V.PlazaRadius and x < 150
	local west = math.abs(z) < 4 and x < -V.PlazaRadius and x > -V.PlazaRadius - V.MoatWidth - 3
	return onBoardwalk or toBoardwalk or toCanyon or west
end
local blocking = {}
for _, part in village:GetDescendants() do
	if part:IsA("BasePart") and part.CanCollide and part.Name ~= "Plank" then
		local c, sz = part.CFrame, part.Size
		local hx = math.abs(c.RightVector.X) * sz.X / 2 + math.abs(c.UpVector.X) * sz.Y / 2 + math.abs(c.LookVector.X) * sz.Z / 2
		local hz = math.abs(c.RightVector.Z) * sz.X / 2 + math.abs(c.UpVector.Z) * sz.Y / 2 + math.abs(c.LookVector.Z) * sz.Z / 2
		local bottom = c.Position.Y - (math.abs(c.RightVector.Y) * sz.X + math.abs(c.UpVector.Y) * sz.Y + math.abs(c.LookVector.Y) * sz.Z) / 2
		if bottom < 4 then
			for _, dx in { -hx, 0, hx } do for _, dz in { -hz, 0, hz } do
				if inPath(c.Position.X + dx, c.Position.Z + dz) and part.Name ~= "PlazaStone" then blocking[part.Name] = true end
			end end
		end
	end
end
local names = {}
for n in blocking do table.insert(names, n) end
check(#names == 0, "nothing solid blocks the bridges, the boardwalk or the path to the canyon " .. table.concat(names, ","))

local buy = Remotes.Event("BuyUpgrade")
goToShop(alice)
buy.OnServerEvent:Fire(alice, "WalkSpeed"); ADVANCE(0.4)
check(PDS.Get(alice).WalkSpeedLevel == 2, "buying at the Upgrades shop works")

-- Dibujo del lobby (para las vistas)
if PRINT_PARTS then
	for _, p in ALL_PARTS do
		if p.Parent and p.Transparency < 1 and (p:GetFullName():find("Lobby") or p:GetFullName():find("Base")) then
			local c, s, col = p.CFrame, p.Size, p.Color
			print(string.format("PART %s %s %.2f %.2f %.2f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f",
				p.Name, tostring(p.Shape), s.x, s.y, s.z, c.p.x, c.p.y, c.p.z, c.r.x, c.r.y, c.r.z, c.u.x, c.u.y, c.u.z, c.b.x, c.b.y, c.b.z, col.R, col.G, col.B))
		end
	end
end

done()

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

local BaseFloors = __mod("BaseFloors")
local Creatures = __mod("Creatures")
local CreatureService = __mod("CreatureService")
ADVANCE(0.5)
local w = Config.Map.PlotSize.X
local bases = BaseService.GetBases()
local base = bases[1]
local tower = base.Model.Tower
local plot = base.Model.PrimaryPart.CFrame
local model = base.Model
local Builder = __mod("BaseBuilder")
local tops = Builder.FloorTops
local count = 0
for _, d in model:GetDescendants() do if d:IsA("BasePart") then count += 1 end end
check(count > 700, "a very detailed tiki hut (" .. count .. " parts)")
local function localPos(p) return plot:PointToObjectSpace(p.Position) end
-- Escaleras: 2 tramos de 14 escalones, al costado de la torre
local flights, stairsOk = 0, true
for _, f in model.Stairs:GetChildren() do
	if f.Name:match("^Flight") then
		flights += 1
		local steps, top = 0, 0
		for _, p in f:GetChildren() do
			if p.Name == "Step" then
				steps += 1
				top = math.max(top, p.Position.Y + p.Size.Y / 2)
				if math.abs(math.abs(localPos(p).X) - 22.6) > 0.01 then stairsOk = false end
			end
		end
		local target = if f.Name == "Flight1" then tops[2] else tops[3]
		if steps ~= 14 or math.abs(top - target) > 0.05 then stairsOk = false end
	end
end
check(flights == 2 and stairsOk, "2 bamboo staircases outside the tower: floor 1 → 2 → 3")
local thatch = 0
for _, p in model.Roof:GetChildren() do if p.Name:match("^Thatch") then thatch += 1 end end
check(thatch == 6 and model.Roof:FindFirstChild("Flag") and model.Roof:FindFirstChild("StringLights"), "3-layer thatch roof with a flag and string lights")
local floorsOk = true
for f = 1, 3 do
	local floor = model.Tower:FindFirstChild("Floor" .. f)
	local plank = floor and floor:FindFirstChild("Plank")
	if not plank or math.abs(plank.Position.Y + 0.25 - tops[f]) > 0.01 then floorsOk = false end
end
check(floorsOk, "3 plank floors at Y 2 / 14 / 26")
local shelfOk = true
for i, shelf in base.CreatureSlots do
	local floor = math.ceil(i / 5)
	if math.abs(shelf.Position.Y - (tops[floor] + 1.3)) > 0.01 or shelf.Name ~= ("Shelf_" .. floor .. "_" .. ((i - 1) % 5 + 1)) or localPos(shelf).Z < 10 then shelfOk = false end
end
check(#base.CreatureSlots == 15 and shelfOk, "15 shelves named Shelf_<floor>_<n>, 5 per floor, at the back of the tower")
local nestsOk = true
for i, ped in base.IncubatorSlots do
	local lp = localPos(ped)
	if math.abs(lp.Z + 15) > 0.01 or math.abs(math.abs(lp.X) - ({ 14, 0, 14 })[i]) > 0.01 then nestsOk = false end
end
check(#base.IncubatorSlots == 3 and nestsOk, "3 stone nests in the front yard")
check(base.SignLabel.Text == "Free Base" and localPos(base.SignLabel.Parent.Parent).Z < -20, "owner sign on the entrance arch")
check(localPos(base.SpawnPoint).Z < 0 and model.FloorShop and model.Garden and model.Entrance.Fence, "spawn in the front yard, floor sign, garden and fence")

local locks = base.Model.Locks
check(#locks:GetChildren() == 2, "floors 2 and 3 have a barrier with a lock")
local shopRow = model.FloorShop.Paper.ShopGui.Floor2
check(shopRow.Text == "FLOOR 2 · REBIRTH 1" and base.CreatureSlots[6].Lamp.SpotLight.Brightness == 0, "locked floor: sign says Rebirth 1, shelf lamps off")
BaseFloors.Apply(base, 2)
check(#locks:GetChildren() == 1 and base.CreatureSlots[6]:GetAttribute("Unlocked") == true and base.CreatureSlots[11]:GetAttribute("Unlocked") == false, "opening floor 2 removes its barrier and unlocks shelves 6-10")
check(shopRow.Text == "FLOOR 2 ✓ OPEN" and base.CreatureSlots[6].Lamp.SpotLight.Brightness > 0, "the sign and the lamps update")
BaseFloors.Apply(base, 1)
check(#locks:GetChildren() == 2 and base.CreatureSlots[6]:GetAttribute("Unlocked") == false, "closing it puts the barrier back")

-- Un jugador con 2 pisos abiertos (renacimiento) y datos viejos
STORE_DATA[key(501)] = { Coins = 0, BaseLevel = 2, TutorialStep = 5, Creatures = {
	{ CreatureId = "SandBunny", Slot = 1 }, { CreatureId = "SandBunny", Slot = 9 }, { CreatureId = "CoralCat", Slot = 40 },
} }
local alice = ADD_PLAYER("Alice", 501); SPAWN_CHARACTER(alice); ADVANCE(1)
local myBase = BaseService.GetBase(alice)
local profile = PDS.Get(alice)
check(#myBase.Model.Locks:GetChildren() == 1, "her floor 2 opens when she joins")
local slots = {}
for _, c in profile.Creatures do slots[c.CreatureId .. c.Slot] = true end
check(slots.SandBunny1 and slots.SandBunny9 and slots.CoralCat2, "a creature on a shelf that no longer exists moves to a free shelf")
check(CreatureService.GetFreeSlotCount(alice) == 7, "10 shelves open, 3 used: 7 free")
local pad = myBase.CreatureSlots[1]
local creatureModel
for _, c in myBase.Model:GetChildren() do if c:GetAttribute("CreatureId") then
	local lp = pad.CFrame:PointToObjectSpace(c.PrimaryPart.Position)
	if math.abs(c.PrimaryPart.Position.X - pad.Position.X) < 0.5 and math.abs(c.PrimaryPart.Position.Z - pad.Position.Z) < 0.5 then creatureModel = c end
end end
local bottom = creatureModel and (creatureModel.PrimaryPart.Position.Y - creatureModel.PrimaryPart.Size.Y / 2)
check(creatureModel and bottom >= pad.Position.Y and bottom < pad.Position.Y + 3, "creatures sit on the round shelf (not floating)")
for _ = 1, 7 do CreatureService.AddCreature(alice, Creatures.Get("SandBunny")) end
check(CreatureService.AddCreature(alice, Creatures.Get("SandBunny")) == nil, "floor 3 stays locked")
REMOVE_PLAYER(alice); ADVANCE(1)
check(#myBase.Model.Locks:GetChildren() == 2, "when she leaves, the base goes back to 1 floor")

-- Dibujo de las bases 1 y 2
BaseFloors.Apply(bases[2], 2)
for _, id in { 1, 2 } do
	for _, p in ALL_PARTS do
		if p.Parent and p.Transparency < 1 and p:GetFullName():find("Base" .. id .. "%.") then
			local c, s, col = p.CFrame, p.Size, p.Color
			print(string.format("PART %s %s %.2f %.2f %.2f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f",
				p.Name, tostring(p.Shape), s.x, s.y, s.z, c.p.x, c.p.y, c.p.z, c.r.x, c.r.y, c.r.z, c.u.x, c.u.y, c.u.z, c.b.x, c.b.y, c.b.z, col.R, col.G, col.B))
		end
	end
end

done()

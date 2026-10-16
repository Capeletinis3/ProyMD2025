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
local ladders, roofs, ok = 0, 0, true
for _, p in tower:GetChildren() do
	if p.Name == "Ladder" then
		ladders += 1
		local lp = plot:PointToObjectSpace(p.Position)
		local top = p.Position.Y + p.Size.Y / 2
		if p.ClassName ~= "TrussPart" or p.Size.Y % 2 ~= 0 or top < 25 or math.abs(lp.X) - 1 < 20 - 0.01 then ok = false end
	elseif p.Name == "Roof" and p.ClassName == "WedgePart" then
		roofs += 1
	end
end
check(ladders == 2 and ok, "2 ladders (TrussParts) on the side of the tower, up to floor 3")
check(roofs == 2, "thatched roof made of 2 wedges")
check(tower.Floor1 and tower.Floor2 and tower.Floor3 and math.abs(tower.Floor3.Position.Y - 24.5) < 0.01, "3 floors at Y 0.5 / 12.5 / 24.5")
local shelfOk = true
for i, shelf in base.CreatureSlots do
	local floor = math.ceil(i / 5)
	local expectedY = ({ 1.25, 13.25, 25.25 })[floor]
	if math.abs(shelf.Position.Y - expectedY) > 0.01 or shelf.Name ~= ("Shelf_" .. floor .. "_" .. ((i - 1) % 5 + 1)) then shelfOk = false end
end
check(shelfOk, "15 shelves named Shelf_<floor>_<n>, 5 per floor")

local locks = base.Model.Locks
check(#locks:GetChildren() == 2, "floors 2 and 3 have a barrier with a lock")
BaseFloors.Apply(base, 2)
check(#locks:GetChildren() == 1 and base.CreatureSlots[6]:GetAttribute("Unlocked") == true and base.CreatureSlots[11]:GetAttribute("Unlocked") == false, "opening floor 2 removes its barrier and unlocks shelves 6-10")
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

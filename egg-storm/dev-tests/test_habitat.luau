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

local Creatures = __mod("Creatures")
local CreatureService = __mod("CreatureService")
local CollectionService = game:GetService("CollectionService")
ADVANCE(0.5)
local bases = BaseService.GetBases()
local base = bases[1]
local model = base.Model
local plot = model.PrimaryPart.CFrame
local Builder = __mod("HabitatBuilder")
local inner = Builder.InnerRadius
local count = 0
for _, d in model:GetDescendants() do if d:IsA("BasePart") then count += 1 end end
check(count > 350, "a detailed jungle habitat (" .. count .. " parts)")
-- Coordenadas del diseño (mirando desde el lobby: +X = derecha)
local function localPos(p) local v = plot:PointToObjectSpace(p.Position); return Vector3.new(-v.X, v.Y, v.Z) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function named(root, name)
	local list = {}
	for _, d in root:GetDescendants() do if d.Name == name then table.insert(list, d) end end
	return list
end

-- Muro de rocas: bajo adelante, alto atrás, con una entrada adelante
local frontH, frontN, backH, backN, gapOk, ringOk = 0, 0, 0, 0, true, true
for _, rock in named(model.Wall, "Rock") do
	local lp = localPos(rock)
	if flat(lp).Magnitude < inner then ringOk = false end
	if lp.Z < -15 then frontH += rock.Size.Y; frontN += 1 end
	if lp.Z > 15 then backH += rock.Size.Y; backN += 1 end
	if lp.Z < -25 and math.abs(lp.X) < 7 then gapOk = false end
end
check(ringOk and frontN > 0 and backN > 0 and backH / backN > 2 * frontH / frontN, string.format("round rock wall, low in front (%.0f) and tall at the back (%.0f)", frontH / math.max(frontN, 1), backH / math.max(backN, 1)))
check(gapOk and #named(model.Wall, "ArmRock") == 6, "an open entrance with rock arms opening outwards")
check(#named(model.Entrance, "TikiMask") == 2 and #named(model.Entrance, "Flame") == 2 and #named(model.Entrance, "Garland") > 8, "portal: stone pillars with tiki masks, torches and a flower garland")
local sign = base.SignLabel.Parent.Parent
check(base.SignLabel.Text == "Free Base" and sign.CFrame.LookVector:Dot(base.Facing.LookVector) > 0.99 and localPos(sign).Z < -25, "the owner sign hangs on the portal, facing the lobby")
-- Agua
local water = model.Water
check(water.WaterfallTop.Mist and water.WaterfallBottom.Mist and water.WaterfallTop.Position.Y > water.WaterfallBottom.Position.Y, "a 2-step waterfall with mist at the back")
check(water.Pool and water.Lake and water.LogBridge and #named(water, "LilyPad") == 5 and #named(water, "Reed") == 8, "pool, creek with a log bridge, lake with lily pads and reeds")
check(model.Shelter.Terrace and model.Shelter.HayBed and #named(model.Shelter, "Feeder") == 2, "stone terrace with the straw shelter and 2 feeders")
check(model.Grottos.MushroomGrotto and model.Grottos.CrystalGrotto, "2 grottos (glowing mushrooms and crystals)")
check(#named(model.Jungle, "JungleTree") == 3 and #named(model.Jungle, "Palm") == 2 and #named(model.Jungle, "Monstera") == 3, "layered jungle: 3 broad trees, 2 palms, monsteras")
-- Nidos
local nestsOk = true
for i, ped in base.IncubatorSlots do
	local lp = localPos(ped)
	if lp.X < 5 or lp.Z > 2 or ped:GetAttribute("SlotIndex") ~= i then nestsOk = false end
end
check(#base.IncubatorSlots == 3 and nestsOk, "3 nests on the stone altar, right of the entrance")
-- Lugares de las criaturas
local spotsOk, spacingOk, roomOk = true, true, true
local lake, pool = localPos(water.Lake), localPos(water.Pool)
for i, spot in base.CreatureSlots do
	local lp = flat(localPos(spot))
	local room = spot:GetAttribute("WanderRadius")
	if spot:GetAttribute("SlotIndex") ~= i or spot.CanCollide or spot.Transparency < 1 then spotsOk = false end
	local bad = not room or room < 1.5 or room > Config.Habitat.WanderRadius or lp.Magnitude + room > inner
		or (lp - flat(lake)).Magnitude < 7.5 + room - 0.01 or (lp - flat(pool)).Magnitude < 5 + room - 0.01
	for _, ped in base.IncubatorSlots do if (lp - flat(localPos(ped))).Magnitude < 4 + room - 0.01 then bad = true end end
	if bad then roomOk = false; print("  spot", i, lp.X, lp.Z, room, lp.Magnitude, (lp - flat(lake)).Magnitude, (lp - flat(pool)).Magnitude) end
	for j, other in base.CreatureSlots do
		if j ~= i and (spot.Position - other.Position).Magnitude < 4.5 then spacingOk = false end
	end
end
check(#base.CreatureSlots == 20 and spotsOk, "20 invisible creature spots (SlotIndex 1-20)")
check(spacingOk, "spots are spread out (4.5+ studs apart)")
check(roomOk, "every spot has room to wander without walking into water, nests or the wall")
check(flat(localPos(base.SpawnPoint)).Magnitude < inner and localPos(base.SpawnPoint).Z < 0, "spawn just inside the entrance")
local zone = base.SafeZone
check(zone.Size.X > 2 * inner and zone.Size.Z > 2 * inner, "the safe zone covers the whole habitat")
local samePlace = true
for _, other in bases do if other ~= base and (other.Model.PrimaryPart.Position - plot.Position).Magnitude < 70 then samePlace = false end end
check(samePlace and #bases == 8, "8 habitats that don't overlap")

-- Un jugador con datos viejos (un lugar que ya no existe)
STORE_DATA[key(501)] = { Coins = 0, BaseLevel = 2, TutorialStep = 5, Creatures = {
	{ CreatureId = "SandBunny", Slot = 1 }, { CreatureId = "SandBunny", Slot = 9 }, { CreatureId = "CoralCat", Slot = 40 },
} }
local alice = ADD_PLAYER("Alice", 501); SPAWN_CHARACTER(alice); ADVANCE(1)
local myBase = BaseService.GetBase(alice)
local profile = PDS.Get(alice)
check(myBase.SignLabel.Text == "Alice's Base", "her name goes on the portal")
local slots = {}
for _, c in profile.Creatures do slots[c.CreatureId .. c.Slot] = true end
check(slots.SandBunny1 and slots.SandBunny9 and slots.CoralCat2, "a creature on a spot that no longer exists moves to a free spot")
check(CreatureService.GetFreeSlotCount(alice) == 17, "20 spots, 3 used: 17 free")
local info = myBase.Model:FindFirstChild("InfoLabel", true)
check(info.Text == "🐾 3/20 · +$" .. alice:GetAttribute("Income") .. "/s", "the info sign shows creatures and income: " .. info.Text)
local pad = myBase.CreatureSlots[1]
local creatureModel
for _, c in myBase.Model:GetChildren() do if c:GetAttribute("CreatureId") then
	if math.abs(c.PrimaryPart.Position.X - pad.Position.X) < 0.5 and math.abs(c.PrimaryPart.Position.Z - pad.Position.Z) < 0.5 then creatureModel = c end
end end
local bottom = creatureModel and (creatureModel.PrimaryPart.Position.Y - creatureModel.PrimaryPart.Size.Y / 2)
check(creatureModel and bottom >= pad.Position.Y - 0.2 and bottom < pad.Position.Y + 3, "creatures stand on the grass (not floating)")
check(creatureModel and CollectionService:HasTag(creatureModel, "WanderingCreature") and creatureModel:GetAttribute("WanderRadius") == pad:GetAttribute("WanderRadius"), "creatures are tagged to wander around their spot")
-- Vender desde donde pasea (un poco lejos del lugar)
local prompt = creatureModel.PrimaryPart:FindFirstChild("ProximityPrompt")
MOVE_TO(alice, creatureModel.PrimaryPart.Position + Vector3.new(Config.Economy.SellDistance + Config.Habitat.WanderRadius, 0, 0)); ADVANCE(0.6)
prompt.Triggered:Fire(alice); ADVANCE(0.2)
check(#profile.Creatures == 2, "you can sell a creature that wandered away from its spot")
for _ = 1, 18 do CreatureService.AddCreature(alice, Creatures.Get("SandBunny")) end
check(#profile.Creatures == 20 and CreatureService.AddCreature(alice, Creatures.Get("SandBunny")) == nil, "20 creatures max, no upgrades needed")
REMOVE_PLAYER(alice); ADVANCE(1)
check(info.Text == "🐾 0/20 · +$0/s" and myBase.SignLabel.Text == "Free Base", "when she leaves, the habitat is free again")

-- Dibujo de las bases 1 y 2
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

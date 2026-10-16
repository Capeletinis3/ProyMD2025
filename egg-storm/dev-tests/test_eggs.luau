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

ADVANCE(1)
local fullOk = true
for i, zone in Config.Zones do if Eggs.CountInZone(i) ~= zone.MaxActive then fullOk = false; print("  zone", i, Eggs.CountInZone(i)) end end
check(fullOk, "each zone starts with its max number of eggs (8, 6, 5, 4, 3, 1)")
local rightRarity = true
for _, egg in Workspace.Eggs:GetChildren() do
	if egg:GetAttribute("EggId") then
		local zone = Config.ZoneAt(egg.Position.X)
		local r = egg:GetAttribute("Rarity")
		if not zone or (r ~= zone.RarityId and r ~= zone.NextRarityId) then rightRarity = false end
	end
end
check(rightRarity, "every egg is its zone's rarity (or the next one)")
local spinning = groundEgg(1)
check(spinning:GetAttribute("Spin") == 45 and spinning:GetAttribute("Bob") == 0.4, "eggs on the ground spin and float (client animation)")

local function share(zoneIndex, n)
	local zone = Config.Zones[zoneIndex]
	local counts = {}
	for _ = 1, n do
		local r = Eggs.RollZoneRarity(zone).Id
		counts[r] = (counts[r] or 0) + 1
	end
	return counts
end
local beach = share(1, 4000)
check(beach.Common and beach.Common / 4000 > 0.87 and beach.Common / 4000 < 0.93 and beach.Rare and not beach.Epic, string.format("Beach: %.1f%% Common, rest Rare", (beach.Common or 0) / 40))
local obsidian = share(6, 500)
check(obsidian.Secret == 500, "Obsidian: always Secret")
local Events = __mod("EventService")
Events.Set("LuckyStorm")
local lucky = share(3, 4000)
check(lucky.Legendary / 4000 > 0.26 and lucky.Legendary / 4000 < 0.34, string.format("Lucky Storm: the next rarity goes up to ~30%% (%.1f%%)", lucky.Legendary / 40))
Events.Set(nil)

-- Agarrar libera el lugar y aparece otro
local alice = ADD_PLAYER("Alice", 101); SPAWN_CHARACTER(alice); ADVANCE(1)
local egg = grab(alice, 1)
check(Eggs.GetCarriedEgg(alice) ~= nil and alice:GetAttribute("CarriedEggRarity") ~= nil, "Alice carries an egg")
check(Eggs.CountInZone(1) == Config.Zones[1].MaxActive - 1, "grabbing frees its spot")
ADVANCE(Config.Zones[1].Respawn + 0.6)
check(Eggs.CountInZone(1) == Config.Zones[1].MaxActive, "a new egg appears after the respawn time")
local second = groundEgg(1)
MOVE_TO(alice, second.Position); second.ProximityPrompt.Triggered:Fire(alice); ADVANCE(0.6)
check(lastNotify(alice) == "You can only carry 1 egg at a time!", "only 1 egg at a time")

-- Variantes y Golden Rain
local function variantShare(n)
	local special = 0
	for i = 1, n do
		local e = Eggs.SpawnEgg({ Position = Vector3.new(1000, 0, 0) })
		if e.Variant.Id ~= "Normal" then special += 1 end
		if i % 50 == 0 then Eggs.ClearWorldEggs() end
	end
	Eggs.ClearWorldEggs()
	return special / n
end
local normal = variantShare(1500)
check(normal > 0.1 and normal < 0.2, string.format("about 15%% of eggs have a variant (%.1f%%)", normal * 100))
Events.Set("GoldenRain")
local golden = variantShare(1500)
check(golden > 0.4 and Events.RespawnMultiplier() == 0.5, string.format("Golden Rain: way more variants (%.1f%%) and faster respawn", golden * 100))
Events.Set(nil)

-- Meteoritos
local okRarity = true
for _ = 1, 200 do
	local m = Eggs.SpawnEgg({ Meteor = true })
	if Config.RarityRank(m.Rarity.Id) < Config.RarityRank("Epic") then okRarity = false end
end
Eggs.ClearWorldEggs()
check(okRarity, "meteor eggs are always Epic or better")
local calls = 0
local real = Eggs.SpawnEgg
Eggs.SpawnEgg = function(o) if o and o.Meteor then calls += 1 end return real(o) end
ADVANCE(Config.Events.MeteorInterval * 2 + 1)
check(calls == 0, "no meteors without the event")
Events.Set("MeteorShower")
ADVANCE(Config.Events.MeteorInterval * 2 + 1)
check(calls >= 2, "Meteor Shower drops meteors (" .. calls .. ")")
Events.Set(nil)

done()

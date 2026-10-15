local Config = __mod("Config")
Config.Storm.RainDuration = 100000
Config.Events.ChancePerStorm = 0 -- arranca sin evento; los eventos se prenden a mano
--@@MAIN
local Config = __mod("Config")
local Eggs = __mod("EggService")
local Events = __mod("EventService")
local PDS = __mod("PlayerDataService")
local BaseService = __mod("BaseService")
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
local function key(id) return "Player_" .. id end
Eggs.SetRaining(false)
ADVANCE(0.1)
Eggs.ClearWorldEggs()

-- ===== Chances según la distancia =====
local function share(rarityId, distance)
	local total, mine = 0, 0
	for _, r in Config.Rarities do
		local w = Eggs.RarityWeight(r, distance)
		total += w
		if r.Id == rarityId then mine = w end
	end
	return mine / total
end
for _, r in Config.Rarities do
	check(share(r.Id, 0) > 0, string.format("%s can drop right at the entrance (%.2f%%)", r.Id, share(r.Id, 0) * 100))
end
check(share("Legendary", 1) > share("Legendary", 0.5) and share("Legendary", 0.5) > share("Legendary", 0), "Legendary gets more likely the farther you go")
check(share("Common", 1) < share("Common", 0), "Common gets less likely far away")
check(share("Legendary", 1) < 0.08 and share("Secret", 1) < 0.02, string.format("far away is only a bit better (Legendary %.1f%%, Secret %.1f%%)", share("Legendary", 1) * 100, share("Secret", 1) * 100))

-- Todas las rarezas caen cerca de la entrada (no hay zonas)
local seen = {}
for i = 1, 4000 do
	local egg = Eggs.SpawnEgg({ Position = Vector3.new(0, 2, 40) })
	if egg then seen[egg.Rarity.Id] = (seen[egg.Rarity.Id] or 0) + 1 end
	if i % 40 == 0 then Eggs.ClearWorldEggs() end
end
Eggs.ClearWorldEggs()
check(seen.Common and seen.Rare and seen.Epic and seen.Legendary and seen.Secret, string.format("all rarities dropped near the entrance (C%d R%d E%d L%d S%d)", seen.Common or 0, seen.Rare or 0, seen.Epic or 0, seen.Legendary or 0, seen.Secret or 0))

-- Posiciones al azar: dentro del pasillo, en todo el largo
local minZ, maxZ, inside = math.huge, -math.huge, true
for i = 1, 400 do
	local egg = Eggs.SpawnEgg()
	if egg then
		local p = egg.Part.CFrame.Position
		ADVANCE(0) -- nada
		minZ = math.min(minZ, p.Z); maxZ = math.max(maxZ, p.Z)
		if math.abs(p.X) > Config.Map.CorridorWidth / 2 - Config.Map.EggSideMargin then inside = false end
	end
	if i % 40 == 0 then Eggs.ClearWorldEggs() end
end
Eggs.ClearWorldEggs()
local L = Config.Map.CorridorLength
check(inside and minZ >= 20 and maxZ <= L and maxZ > L * 0.9 and minZ < L * 0.1, string.format("eggs drop all along the corridor (z %.0f..%.0f)", minZ, maxZ))

-- ===== Variantes =====
local function variantShare(n)
	local special = 0
	for i = 1, n do
		local egg = Eggs.SpawnEgg({ Position = Vector3.new(0, 2, 40) })
		if egg and egg.Variant.Id ~= "Normal" then special += 1 end
		if i % 40 == 0 then Eggs.ClearWorldEggs() end
	end
	Eggs.ClearWorldEggs()
	return special / n
end
local normalShare = variantShare(2000)
check(normalShare > 0.08 and normalShare < 0.25, string.format("about 15%% of eggs have a variant (%.1f%%)", normalShare * 100))
Events.Set("GoldenRain")
local goldenShare = variantShare(2000)
check(goldenShare > 0.4, string.format("Golden Rain: many more variant eggs (%.1f%%)", goldenShare * 100))
Events.Set("LuckyStorm")
local legendary = Config.GetRarity("Legendary")
local common = Config.GetRarity("Common")
check(Eggs.RarityWeight(legendary, 0) == legendary.Weight * Config.Events.LuckyRarityBoost and Eggs.RarityWeight(common, 0) == common.Weight, "Lucky Storm: only Epic/Legendary/Secret are boosted")
Events.Set(nil)
check(Workspace:GetAttribute("StormEvent") == "", "event cleared")

-- Huevo dorado: agarrar, incubar, abrir
local alice = ADD_PLAYER("Alice", 601); SPAWN_CHARACTER(alice)
ADVANCE(1)
local base = BaseService.GetBase(alice)
local profile = PDS.Get(alice)
local golden = Config.GetVariant("Golden")
local egg = Eggs.SpawnEgg({ Rarity = legendary, Variant = golden, Position = Vector3.new(10, 2, 60) })
check(egg.Prompt.ObjectText == "Golden Legendary Egg", "egg prompt says " .. egg.Prompt.ObjectText)
check(egg.Part.Color == golden.Color and egg.Part.Material == golden.Material, "golden egg looks golden")
ADVANCE(Config.Eggs.FallTime + 0.2)
check(egg.Part:FindFirstChild("Beacon") ~= nil, "Legendary egg has a light beacon")
MOVE_TO(alice, egg.Part.Position); egg.Prompt.Triggered:Fire(alice); ADVANCE(0.2)
check(alice:GetAttribute("CarriedEggRarity") == "Legendary" and alice:GetAttribute("CarriedEggVariant") == "Golden", "carry attributes include the variant")
check(lastNotify(alice) == "You grabbed a Golden Legendary Egg! Bring it to your base.", "grab message: " .. tostring(lastNotify(alice)))
local inc = base.Model.Incubator1
MOVE_TO(alice, inc.Base.Position); ADVANCE(0.6); inc.Base.ProximityPrompt.Triggered:Fire(alice); ADVANCE(0.2)
check(alice:GetAttribute("CarriedEggVariant") == nil, "variant attribute cleared after incubating")
local title = inc.Dome.Display.Title.Text
check(title == "Golden Legendary Egg", "incubator shows " .. title)
ADVANCE(Config.GetIncubationTime(legendary, 1) + 0.5)
local hatchedArgs
for _, e in REMOTE_LOG do if e.player == alice and e.remote == "Hatched" then hatchedArgs = e.args end end
check(hatchedArgs and hatchedArgs[2] == "Legendary" and hatchedArgs[4] == "Golden", "hatch reveal gets the variant")
ADVANCE(Config.Effects.HatchAnimationTime + 0.2)
check(#profile.Creatures == 1 and profile.Creatures[1].Variant == "Golden", "creature is Golden")
local expectedIncome = legendary.CoinsPerSecond * golden.Multiplier
check(alice:GetAttribute("Income") == expectedIncome, "Golden x3 income: " .. tostring(alice:GetAttribute("Income")))
local model
for _, c in base.Model:GetChildren() do if c:GetAttribute("CreatureId") then model = c end end
check(model and model:GetAttribute("Variant") == "Golden" and model.Body.Color == golden.Color, "creature model is golden")
local label = model.Body.Info:FindFirstChild("Name").Text
check(string.sub(label, 1, 7) == "Golden ", "name label: " .. label)
check(model.Body.Info.Income.Text == "+300 coins/s", "income label: " .. model.Body.Info.Income.Text)
check(string.find(model.Body.ProximityPrompt.ObjectText, "18,000 coins", 1, true) ~= nil, "sell price x3: " .. model.Body.ProximityPrompt.ObjectText)

-- Double Coins
Events.Set("DoubleCoins")
local before = profile.Coins
ADVANCE(5)
local gained = profile.Coins - before
check(gained >= expectedIncome * 2 * 4 and gained <= expectedIncome * 2 * 6, "Double Coins doubles income (+" .. gained .. " in 5 s)")
Events.Set(nil)

-- Se guarda la variante y vuelve igual
REMOVE_PLAYER(alice); ADVANCE(1)
check(STORE_DATA[key(601)].Creatures[1].Variant == "Golden", "variant is saved")
local alice2 = ADD_PLAYER("Alice", 601); SPAWN_CHARACTER(alice2); ADVANCE(1)
check(PDS.Get(alice2).Creatures[1].Variant == "Golden" and alice2:GetAttribute("Income") == expectedIncome, "Golden creature comes back after rejoining")

-- Datos viejos (sin variante) o rotos: quedan Normal
STORE_DATA[key(602)] = {
	Coins = 0,
	Creatures = { { CreatureId = "SandBunny", Slot = 1 }, { CreatureId = "SandBunny", Slot = 2, Variant = "Hacked" } },
	Incubating = { { Slot = 1, RarityId = "Rare", Remaining = 10 } },
}
local bob = ADD_PLAYER("Bob", 602); SPAWN_CHARACTER(bob); ADVANCE(1)
local bp = PDS.Get(bob)
check(bp.Creatures[1].Variant == "Normal" and bp.Creatures[2].Variant == "Normal" and bob:GetAttribute("Income") == 2, "old or broken saves get Normal variant")
local bobInc = BaseService.GetBase(bob).Model.Incubator1
check(bobInc.Dome.Display.Title.Text == "Rare Egg", "old incubating egg restored as Normal")

-- Meteoritos: siempre Epic o mejor, y no los frena el límite de huevos
local okRarity, spawned = true, 0
for i = 1, 300 do
	local m = Eggs.SpawnEgg({ Meteor = true })
	if m then
		spawned += 1
		if m.Rarity.Id ~= "Epic" and m.Rarity.Id ~= "Legendary" and m.Rarity.Id ~= "Secret" then okRarity = false end
	end
end
Eggs.ClearWorldEggs()
check(spawned == 300 and okRarity, "meteor eggs are always Epic or better")

-- El ciclo hace caer meteoritos solo con Meteor Shower
local meteorCalls = 0
local realSpawn = Eggs.SpawnEgg
Eggs.SpawnEgg = function(opts)
	if opts and opts.Meteor then meteorCalls += 1 end
	return realSpawn(opts)
end
Eggs.SetRaining(true)
ADVANCE(Config.Events.MeteorInterval * 2 + 1)
check(meteorCalls == 0, "no meteors without the event")
Events.Set("MeteorShower")
ADVANCE(Config.Events.MeteorInterval * 2 + 1)
check(meteorCalls >= 2, "Meteor Shower drops meteors (" .. meteorCalls .. ")")

print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

__mod("Config").Storm.RainDuration = 100000 -- llueve todo el tiempo en esta prueba
__mod("Config").Data.AutosaveInterval = 10 -- autoguardado más seguido para que la prueba sea corta
--@@MAIN
local Config = __mod("Config")
local PDS = __mod("PlayerDataService")
local BaseService = __mod("BaseService")
local Creatures = __mod("Creatures")
local CreatureService = __mod("CreatureService")
local Inc = __mod("IncubatorService")
local Remotes = __mod("Remotes")
local buy = Remotes.Event("BuyUpgrade")
local Workspace = game:GetService("Workspace")

local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
local function key(id) return "Player_" .. id end
local function groundEgg()
	for _, child in Workspace.Eggs:GetChildren() do
		local prompt = child:FindFirstChild("ProximityPrompt")
		if prompt and prompt.Enabled then return child, prompt end
	end
end

-- 1) Jugador nuevo
local alice = ADD_PLAYER("Alice", 111); SPAWN_CHARACTER(alice); ADVANCE(1)
local base = BaseService.GetBase(alice)
local profile = PDS.Get(alice)
check(profile ~= nil and profile.Coins == 0 and profile.IncubatorCount == 1, "new player starts with a fresh profile")

-- Progresa: plata, mejoras, mascotas y un huevo incubando
PDS.AddCoins(alice, 6000)
MOVE_TO(alice, base.UpgradePanel.Position + Vector3.new(0, 0, -4))
ADVANCE(0.5); buy.OnServerEvent:Fire(alice, "IncubationSpeed"); ADVANCE(0.5)
buy.OnServerEvent:Fire(alice, "BaseFloor"); ADVANCE(0.5)
CreatureService.AddCreature(alice, Creatures.Get("GoldenDragon"))
CreatureService.AddCreature(alice, Creatures.Get("SandBunny"))
ADVANCE(5)
local egg, prompt = groundEgg()
MOVE_TO(alice, egg.Position); prompt.Triggered:Fire(alice); ADVANCE(0.2)
local carried = alice:GetAttribute("CarriedEggRarity")
local inc = base.Model.Incubator1
MOVE_TO(alice, inc.Base.Position); ADVANCE(1); inc.Base.ProximityPrompt.Triggered:Fire(alice); ADVANCE(0.2)
check(inc:FindFirstChild("Egg") ~= nil, "Alice is incubating a " .. tostring(carried) .. " egg")
local coinsNow = profile.Coins

-- 2) Autoguardado
ADVANCE(Config.Data.AutosaveInterval + 1)
local saved = STORE_DATA[key(111)]
check(saved ~= nil, "autosave wrote Alice's data")
check(saved and saved.BaseLevel == 2 and saved.IncubationSpeedLevel == 2 and #saved.Creatures == 2, "autosave has upgrades and creatures")
check(saved and #saved.Incubating == 1 and saved.Incubating[1].RarityId == carried, "autosave includes the egg being incubated")

-- 3) Sale del juego
local before = Inc.GetSnapshot(alice)[1].Remaining
local coinsAtLeave = profile.Coins
REMOVE_PLAYER(alice); ADVANCE(1)
saved = STORE_DATA[key(111)]
check(saved.Coins == coinsAtLeave, string.format("leaving saves coins (%d)", saved.Coins))
check(#saved.Incubating == 1 and math.abs(saved.Incubating[1].Remaining - before) < 1.5, string.format("leaving saves the egg with %.1fs left", saved.Incubating[1].Remaining))

-- 4) Vuelve a entrar
ADVANCE(30) -- el tiempo no corre mientras no está
local alice2 = ADD_PLAYER("Alice", 111); SPAWN_CHARACTER(alice2); ADVANCE(1)
local p2 = PDS.Get(alice2)
local base2 = BaseService.GetBase(alice2)
check(p2 and p2.Coins >= coinsAtLeave and p2.Coins < coinsAtLeave + 300 and p2.IncubationSpeedLevel == 2 and p2.BaseLevel == 2, "coming back restores coins and upgrades")
check(base2.Model:FindFirstChild("Floor2") ~= nil and #base2.CreatureSlots == 14, "2nd floor rebuilt")
local models = 0
for _, c in base2.Model:GetChildren() do if c:GetAttribute("CreatureId") then models += 1 end end
check(models == 2 and alice2:GetAttribute("Income") == 101, "creatures back on their pads (income " .. tostring(alice2:GetAttribute("Income")) .. "/s)")
local snap = Inc.GetSnapshot(alice2)[1]
check(snap ~= nil and math.abs(snap.Remaining - saved.Incubating[1].Remaining) < 1.5, "the egg keeps incubating where it left off")
check(alice2.leaderstats.Coins.Value == p2.Coins, "leaderstats show the saved coins")

-- 5) Cierre del servidor (BindToClose) guarda lo último
PDS.AddCoins(alice2, 1234)
local expected = p2.Coins
task.spawn(CLOSE_FNS[1])
ADVANCE(2)
check(STORE_DATA[key(111)].Coins == expected, "BindToClose saves everyone's latest data")

-- 6) Reintentos: Roblox falla 2 veces y después anda
STORE_DATA[key(222)] = { Coins = 500 }
STORE_FAIL_NEXT = 2
local bob = ADD_PLAYER("Bob", 222); SPAWN_CHARACTER(bob); ADVANCE(6)
check(PDS.Get(bob) and PDS.Get(bob).Coins == 500, "load succeeds after 2 failed attempts")

-- 7) Datos rotos en el DataStore
STORE_DATA[key(333)] = {
	Coins = "lots", IncubationSpeedLevel = 99, IncubatorCount = -3, BaseLevel = 7,
	Creatures = { { CreatureId = "FakeCreature", Slot = 1 }, { CreatureId = "SandBunny", Slot = 2 }, { CreatureId = "CoralCat", Slot = 2 }, "garbage" },
	Incubating = { { Slot = 3, RarityId = "Rare", Remaining = 10 }, { Slot = 1, RarityId = "Nope", Remaining = 5 } },
}
local carol = ADD_PLAYER("Carol", 333); SPAWN_CHARACTER(carol); ADVANCE(1)
local pc = PDS.Get(carol)
check(pc and pc.Coins <= 2 and pc.IncubationSpeedLevel == 5 and pc.IncubatorCount == 1 and pc.BaseLevel == 2, "broken numbers are fixed")
check(pc and #pc.Creatures == 1 and pc.Creatures[1].CreatureId == "SandBunny", "unknown creatures and duplicate pads are dropped")
check(#Inc.GetSnapshot(carol) == 0, "eggs in incubators the player doesn't own are dropped")

-- 8) El DataStore no anda en el juego publicado: lo saca y NO pisa sus datos
REMOVE_PLAYER(bob); REMOVE_PLAYER(carol); ADVANCE(1)
STORE_DATA[key(444)] = { Coins = 777 }
STORE_FAIL_ALL = true
local dave = ADD_PLAYER("Dave", 444); SPAWN_CHARACTER(dave); ADVANCE(15)
local kicked = false
for _, k in KICKED do if k[1] == dave then kicked = true end end
check(kicked and PDS.Get(dave) == nil, "live game: player is kicked if data can't load")
REMOVE_PLAYER(dave); ADVANCE(1)
STORE_FAIL_ALL = false
check(STORE_DATA[key(444)].Coins == 777, "...and their saved data is untouched")

-- 9) En Studio sin acceso a la API: juega sin guardar y no pisa nada
STUDIO = true
STORE_FAIL_ALL = true
local erin = ADD_PLAYER("Erin", 444); SPAWN_CHARACTER(erin); ADVANCE(15)
check(PDS.Get(erin) ~= nil, "Studio: player can still play without saving")
PDS.AddCoins(erin, 50)
STORE_FAIL_ALL = false
REMOVE_PLAYER(erin); ADVANCE(1)
check(STORE_DATA[key(444)].Coins == 777, "Studio: nothing is saved over the real data")

print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

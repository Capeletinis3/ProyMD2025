__mod("Config").Storm.RainDuration = 45
--@@MAIN
local Config = __mod("Config")
local PDS = __mod("PlayerDataService")
local BaseService = __mod("BaseService")
local Eggs = __mod("EggService")
local Remotes = __mod("Remotes")
local buy = Remotes.Event("BuyUpgrade")
local Workspace = game:GetService("Workspace")

local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
local function phase() return Workspace:GetAttribute("StormPhase") end
local function nearestEgg(maxZ)
	local best, bestPrompt
	for _, child in Workspace.Eggs:GetChildren() do
		local prompt = child:FindFirstChild("ProximityPrompt")
		if prompt and prompt.Enabled and child.Position.Z <= maxZ and (not best or child.Position.Z < best.Position.Z) then
			best, bestPrompt = child, prompt
		end
	end
	return best, bestPrompt
end
local function grab(p, maxZ)
	local egg, prompt = nearestEgg(maxZ)
	if not egg then return nil end
	MOVE_TO(p, egg.Position); prompt.Triggered:Fire(p); ADVANCE(0.6)
	return p:GetAttribute("CarriedEggRarity")
end
local function incubate(p)
	local inc = BaseService.GetBase(p).Model:FindFirstChild("Incubator1")
	MOVE_TO(p, inc.Base.Position); ADVANCE(0.6); inc.Base.ProximityPrompt.Triggered:Fire(p); ADVANCE(0.2)
	return inc:FindFirstChild("Egg") ~= nil
end

-- DataStore lento: la primera lectura falla (reintento en 1 s)
STORE_FAIL_NEXT = 1
local alice = ADD_PLAYER("Alice", 1001); SPAWN_CHARACTER(alice)
ADVANCE(0.3)
local baseA = BaseService.GetBase(alice)
check(PDS.Get(alice) == nil, "Alice's data is still loading...")
check((alice.Character.HumanoidRootPart.Position - baseA.SpawnPoint.Position).Magnitude < 6, "...but she is already standing in her base")
ADVANCE(2)
check(PDS.Get(alice) ~= nil and baseA.Model:FindFirstChild("Incubator1") ~= nil, "data loads and her base is built")

local bob = ADD_PLAYER("Bob", 1002); SPAWN_CHARACTER(bob); ADVANCE(1)
check(BaseService.GetBase(bob).Id == 2, "Bob gets base 2")

-- Ronda 1: los dos juntan huevos
ADVANCE(15)
local rA = grab(alice, 300)
check(rA ~= nil, "Alice grabs an egg (" .. tostring(rA) .. ")")
check(incubate(alice), "Alice incubates it")
local rB = grab(bob, 300)
check(rB ~= nil, "Bob grabs an egg (" .. tostring(rB) .. ")")
MOVE_TO(bob, Vector3.new(0, 3, 250)) -- Bob se queda en la arena con el huevo

-- Aviso y ola
while phase() ~= "Wave" do ADVANCE(0.1) end
while phase() == "Wave" do ADVANCE(0.1) end
check(bob.Character.Humanoid.Health == 0 and Eggs.GetCarriedEgg(bob) == nil, "the wave gets Bob and he loses his egg")
check(alice.Character.Humanoid.Health > 0, "Alice (in her base) survives")
SPAWN_CHARACTER(bob); ADVANCE(0.5)
check((bob.Character.HumanoidRootPart.Position - BaseService.GetBase(bob).SpawnPoint.Position).Magnitude < 6, "Bob respawns in his base")

-- El huevo de Alice se abre en algún momento
ADVANCE(150)
local profileA = PDS.Get(alice)
check(#profileA.Creatures == 1, "Alice's egg hatched into a creature")
check(profileA.Coins > 0, "Alice earns coins (" .. profileA.Coins .. ")")

-- Alice compra una mejora con lo que ganó
PDS.AddCoins(alice, 300)
MOVE_TO(alice, baseA.UpgradePanel.Position + Vector3.new(0, 0, -4)); ADVANCE(0.5)
buy.OnServerEvent:Fire(alice, "WalkSpeed"); ADVANCE(0.2)
check(alice.Character.Humanoid.WalkSpeed == 20, "Alice buys Walk Speed")

-- Bob intenta comprar desde la base de Alice: no puede
local coinsB = PDS.Get(bob).Coins
PDS.AddCoins(bob, 1000)
MOVE_TO(bob, baseA.UpgradePanel.Position); ADVANCE(0.5)
buy.OnServerEvent:Fire(bob, "WalkSpeed"); ADVANCE(0.2)
check(PDS.Get(bob).WalkSpeedLevel == 1, "Bob can't buy from Alice's panel")

-- Alice sale y vuelve: todo sigue ahí
local coinsBeforeLeave = profileA.Coins
REMOVE_PLAYER(alice); ADVANCE(1)
check(baseA.Owner == nil, "base 1 is free after Alice leaves")
local alice2 = ADD_PLAYER("Alice", 1001); SPAWN_CHARACTER(alice2); ADVANCE(1)
local p2 = PDS.Get(alice2)
check(p2 and p2.WalkSpeedLevel == 2 and #p2.Creatures == 1 and p2.Coins >= coinsBeforeLeave, "Alice comes back with her creature, coins and upgrades")
check(alice2.Character.Humanoid.WalkSpeed == 20, "her walk speed is applied again")

-- El servidor se apaga: se guarda a los dos
PDS.AddCoins(bob, 77)
local expectedBob = PDS.Get(bob).Coins
task.spawn(CLOSE_FNS[1]); ADVANCE(3)
check(STORE_DATA["Player_1002"] and STORE_DATA["Player_1002"].Coins == expectedBob, "shutdown saves Bob too")

print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

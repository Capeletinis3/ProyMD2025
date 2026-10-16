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


local Creatures = __mod("Creatures")
local CreatureService = __mod("CreatureService")
local Trade = __mod("TradeService")
local remote = Remotes.Event("Trade")
local function creatureAt(base, slot)
	local shelf = base.CreatureSlots[slot]
	for _, c in base.Model:GetChildren() do
		if c:GetAttribute("CreatureId") and math.abs(c.PrimaryPart.Position.X - shelf.Position.X) < 0.5 and math.abs(c.PrimaryPart.Position.Z - shelf.Position.Z) < 0.5 and c.PrimaryPart.Position.Y > shelf.Position.Y then return c end
	end
end
local function lastTrade(p)
	for i = #REMOTE_LOG, 1, -1 do
		local e = REMOTE_LOG[i]
		if e.player == p and e.remote == "Trade" then return e.args end
	end
end
local function has(p, id, variant)
	for _, c in PDS.Get(p).Creatures do
		if c.CreatureId == id and c.Variant == (variant or "Normal") then return c.Slot end
	end
end
local function fire(p, ...) remote.OnServerEvent:Fire(p, ...); ADVANCE(0.3) end

local alice = ADD_PLAYER("Alice", 901); SPAWN_CHARACTER(alice)
local bob = ADD_PLAYER("Bob", 902); SPAWN_CHARACTER(bob)
local carl = ADD_PLAYER("Carl", 903); SPAWN_CHARACTER(carl)
ADVANCE(1)
local counter = Workspace.Map.Lobby.Stalls.Trading.Counter
local tradePrompt = counter:FindFirstChildOfClass("ProximityPrompt")
check(tradePrompt and tradePrompt.ActionText == "Open", "the Trading stall has an Open button")
CreatureService.AddCreature(alice, Creatures.Get("GoldenDragon"), Config.GetVariant("Golden")) -- estante 1
CreatureService.AddCreature(alice, Creatures.Get("SandBunny"))                                  -- estante 2
CreatureService.AddCreature(bob, Creatures.Get("SunPhoenix"))                                   -- estante 1
local aliceIncome = alice:GetAttribute("Income")

-- Invitación
MOVE_TO(alice, Vector3.new(0, 3, 22)); ADVANCE(0.1) -- lejos del puesto: igual se puede (botón Trade del HUD)
fire(alice, "Request", alice.UserId); fire(alice, "Request", 123456); fire(alice, "Request", "Bob")
check(lastTrade(alice) == nil and lastTrade(bob) == nil, "junk requests are ignored")
fire(alice, "Request", bob.UserId)
local inv = lastTrade(bob)
check(inv and inv[1] == "Invite" and inv[2] == "Alice" and inv[3] == alice.UserId, "Bob gets the invite (wherever he is)")
check(lastNotify(alice) == "Trade request sent to Bob!", "Alice is told the request was sent")
fire(bob, "Respond", alice.UserId, false)
check(lastNotify(alice) == "Bob declined your trade." and Trade.GetSession(bob) == nil, "decline")
fire(alice, "Request", bob.UserId)
local invites = 0
for _, e in REMOTE_LOG do if e.player == bob and e.remote == "Trade" and e.args[1] == "Invite" then invites += 1 end end
check(invites == 1, "can't spam requests to the same player (5 s)")
ADVANCE(Config.Trade.RequestCooldown)
fire(alice, "Request", bob.UserId)
ADVANCE(Config.Trade.RequestTimeout + 1)
fire(bob, "Respond", alice.UserId, true)
check(Trade.GetSession(bob) == nil, "an old invite expires")
ADVANCE(Config.Trade.RequestCooldown)
fire(alice, "Request", bob.UserId)
fire(bob, "Respond", alice.UserId, true)
local session = Trade.GetSession(alice)
check(session ~= nil and Trade.GetSession(bob) == session, "accepting opens the trade")
local st = lastTrade(alice)
check(st[1] == "State" and st[2].Partner == "Bob" and #st[2].MyCreatures == 2, "Alice sees her creatures and Bob's name")
-- Otro no puede meterse
MOVE_TO(carl, counter.Position + Vector3.new(0, 0, -4)); ADVANCE(0.1)
fire(carl, "Request", alice.UserId)
check(lastNotify(carl) == "Alice is already trading.", "can't invite someone who is trading")

-- Ofertas
local dragonSlot = has(alice, "GoldenDragon", "Golden")
fire(alice, "Offer", { dragonSlot })
fire(bob, "Offer", { 99 })
check(#session.Offers[bob] == 0, "can't offer a creature you don't have")
fire(bob, "Offer", { 1, 1.5 }); fire(bob, "Offer", "lol"); fire(bob, "Offer", { 1, 2, 3, 4, 5, 6 })
check(#session.Offers[bob] == 0, "junk offers are ignored")
fire(bob, "Offer", { has(bob, "SunPhoenix") })
st = lastTrade(bob)[2]
check(#st.TheirOffer == 1 and st.TheirOffer[1].CreatureId == "GoldenDragon" and st.TheirOffer[1].Variant == "Golden", "Bob sees Alice's Golden Dragon")
-- No se puede vender lo ofrecido
local base = BaseService.GetBase(alice)
local dragon = creatureAt(base, dragonSlot)
MOVE_TO(alice, dragon.Body.Position + Vector3.new(4, 0, 0)); ADVANCE(0.6)
dragon.Body.ProximityPrompt.Triggered:Fire(alice); ADVANCE(0.3)
check(has(alice, "GoldenDragon", "Golden") and lastNotify(alice) == "That creature is in a trade!", "can't sell a creature that's in a trade")

-- Ready + cambio durante la cuenta regresiva = se cancela la cuenta
fire(alice, "Ready", true)
check(lastTrade(bob)[2].TheirReady == true and session.CountdownEndsAt == 0, "one ready: no countdown yet")
fire(bob, "Ready", true)
check(session.CountdownEndsAt > 0, "both ready: countdown starts")
fire(bob, "Offer", {})
ADVANCE(Config.Trade.CountdownTime + 0.5)
check(has(alice, "GoldenDragon", "Golden") and has(bob, "SunPhoenix") and Trade.GetSession(alice) == session, "changing the offer stops the countdown (nothing swapped)")
check(session.Ready[alice] == nil, "and both have to press Ready again")
fire(bob, "Offer", { has(bob, "SunPhoenix") })
fire(alice, "Ready", true); fire(bob, "Ready", true)
ADVANCE(Config.Trade.CountdownTime + 0.5)
check(has(bob, "GoldenDragon", "Golden") and has(alice, "SunPhoenix") and not has(alice, "GoldenDragon", "Golden") and not has(bob, "SunPhoenix"), "the creatures are swapped (variant kept)")
check(Trade.GetSession(alice) == nil and lastTrade(alice)[1] == "Closed" and lastTrade(alice)[2] == "Trade complete!", "the trade closes: Trade complete!")
check(dragon.Parent == nil and creatureAt(BaseService.GetBase(bob), has(bob, "GoldenDragon", "Golden")) ~= nil, "the models move to the new habitats")
check(alice:GetAttribute("Income") < aliceIncome and bob:GetAttribute("Income") > alice:GetAttribute("Income"), "income updates for both")
ADVANCE(1)
local saved = STORE_DATA[key(902)]
local savedDragon = false
for _, c in (saved and saved.Creatures or {}) do if c.CreatureId == "GoldenDragon" and c.Variant == "Golden" then savedDragon = true end end
check(savedDragon, "the trade is saved right away")

-- Sin lugar en el hábitat
while CreatureService.GetFreeSlotCount(bob) > 0 do CreatureService.AddCreature(bob, Creatures.Get("SandBunny")) end
check(#PDS.Get(bob).Creatures == Config.Habitat.Capacity, "Bob's habitat is full (20)")
MOVE_TO(alice, counter.Position + Vector3.new(0, 0, 4)); ADVANCE(0.1)
ADVANCE(Config.Trade.RequestCooldown)
fire(alice, "Request", bob.UserId); fire(bob, "Respond", alice.UserId, true)
session = Trade.GetSession(alice)
fire(alice, "Offer", { has(alice, "SunPhoenix"), has(alice, "SandBunny") })
fire(bob, "Offer", { has(bob, "GoldenDragon", "Golden") })
fire(alice, "Ready", true); fire(bob, "Ready", true)
ADVANCE(Config.Trade.CountdownTime + 0.5)
check(lastNotify(alice) == "Bob doesn't have enough room in their habitat for this trade." and has(alice, "SunPhoenix") and has(bob, "GoldenDragon", "Golden"), "no room: nothing is swapped")
check(Trade.GetSession(alice) == session and session.Ready[alice] == nil, "the trade stays open so they can fix it")
-- 1 por 1 sí entra
fire(alice, "Offer", { has(alice, "SunPhoenix") })
fire(alice, "Ready", true); fire(bob, "Ready", true)
ADVANCE(Config.Trade.CountdownTime + 0.5)
check(has(alice, "GoldenDragon", "Golden") and has(bob, "SunPhoenix"), "1 for 1 fits with a full habitat")

-- Cancelar e irse
ADVANCE(Config.Trade.RequestCooldown)
fire(alice, "Request", bob.UserId); fire(bob, "Respond", alice.UserId, true)
fire(bob, "Cancel")
check(Trade.GetSession(alice) == nil and lastTrade(alice)[2] == "Bob cancelled the trade.", "Cancel closes it for both")
ADVANCE(Config.Trade.RequestCooldown)
fire(alice, "Request", bob.UserId); fire(bob, "Respond", alice.UserId, true)
fire(alice, "Offer", { has(alice, "GoldenDragon", "Golden") })
fire(alice, "Ready", true); fire(bob, "Ready", true)
REMOVE_PLAYER(bob); ADVANCE(Config.Trade.CountdownTime + 1)
check(Trade.GetSession(alice) == nil and lastTrade(alice)[2] == "Bob left the game. Trade cancelled.", "leaving cancels the trade")
check(has(alice, "GoldenDragon", "Golden"), "and Alice keeps her creature")

done()

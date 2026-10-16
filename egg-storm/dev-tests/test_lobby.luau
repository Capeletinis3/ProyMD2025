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
stalls.Trading.Counter.ProximityPrompt.Triggered:Fire(alice); ADVANCE(0.1)
check(lastNotify(alice) == "Trading is coming soon!", "Trading: coming soon")
local boards = stalls.Rankings.Leaderboards
local ids = {}
for _, m in boards:GetChildren() do ids[m.Board:GetAttribute("Board")] = true end
check(ids.TopEarners and ids.EggsHatched, "Rankings stall has the 2 record boards")
local events = stalls.Rankings.EventBoard.Board
local gui = events:FindFirstChildOfClass("SurfaceGui")
check(events:GetAttribute("EventBoard") and gui.Title and gui.Line1 and gui.Line2 and gui.Line3, "event board with 3 lines (next wave, super tsunami, event)")
local buy = Remotes.Event("BuyUpgrade")
goToShop(alice)
buy.OnServerEvent:Fire(alice, "WalkSpeed"); ADVANCE(0.4)
check(PDS.Get(alice).WalkSpeedLevel == 2, "buying at the Upgrades shop works")

done()

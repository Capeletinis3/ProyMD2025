--!strict
-- TradeService: intercambio de mascotas entre dos jugadores del mismo servidor.
--
-- Cómo funciona:
--   1. En el puesto de Intercambio elegís a otro jugador y le mandás una invitación ("Request").
--   2. El otro la acepta o la rechaza ("Respond"), esté donde esté. La invitación vence sola.
--   3. Se abre la ventana de intercambio para los dos. Cada uno elige hasta Config.Trade.MaxItems mascotas ("Offer").
--   4. Cuando los dos aprietan "Ready" empieza una cuenta regresiva. Si alguien cambia algo, se cancela.
--   5. Al terminar, el servidor vuelve a revisar TODO (que las mascotas sigan siendo de cada uno y que haya
--      lugar en los estantes) e intercambia. Después guarda a los dos.
-- Mientras una mascota está ofrecida no se puede vender.
--
-- Mensajes (RemoteEvent "Trade"):
--   cliente → servidor: ("Request", userId) ("Respond", userId, aceptar) ("Offer", {lugares}) ("Ready", bool) ("Cancel")
--   servidor → cliente: ("Invite", nombre, userId) ("State", tabla) ("Closed", motivo)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CreatureService = require(script.Parent.CreatureService)

type Item = { Slot: number, CreatureId: string, Variant: string }

export type Session = {
	Players: { Player },
	Offers: { [Player]: { Item } },
	Ready: { [Player]: boolean },
	CountdownEndsAt: number, -- 0 = sin cuenta regresiva
	Token: number, -- cambia con cada cambio (así una cuenta regresiva vieja no hace nada)
	Closed: boolean,
}

type Invite = { From: Player, ExpiresAt: number }

local TradeService = {}

local tradeRemote = Remotes.Event("Trade")
local notifyRemote = Remotes.Event("Notify")

local sessions: { [Player]: Session } = {}
local invites: { [Player]: Invite } = {} -- por destinatario
local lastRequest: { [Player]: { [Player]: number } } = {}
local lastAction: { [Player]: number } = {}
local stall: BasePart? = nil

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

local function partnerOf(session: Session, player: Player): Player
	return if session.Players[1] == player then session.Players[2] else session.Players[1]
end

local function findPlayer(userId: unknown): Player?
	if typeof(userId) ~= "number" then
		return nil
	end
	for _, player in Players:GetPlayers() do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end

local function canTrade(player: Player): boolean
	return PlayerDataService.Get(player) ~= nil and BaseService.GetBase(player) ~= nil
end

local function nearStall(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not stall or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - stall.Position).Magnitude <= Config.Trade.Distance + 5
end

-- Lo que ve cada uno en su ventana
local function sendState(session: Session)
	for _, player in session.Players do
		local partner = partnerOf(session, player)
		local profile = PlayerDataService.Get(player)
		local mine = {}
		if profile then
			for _, data in profile.Creatures do
				table.insert(mine, { Slot = data.Slot, CreatureId = data.CreatureId, Variant = data.Variant })
			end
		end
		local myOffer = {}
		for _, item in session.Offers[player] do
			table.insert(myOffer, item.Slot)
		end
		local theirs = {}
		for _, item in session.Offers[partner] do
			table.insert(theirs, { CreatureId = item.CreatureId, Variant = item.Variant })
		end
		tradeRemote:FireClient(player, "State", {
			Partner = partner.DisplayName,
			MyCreatures = mine,
			MyOffer = myOffer,
			TheirOffer = theirs,
			MyReady = session.Ready[player] == true,
			TheirReady = session.Ready[partner] == true,
			CountdownEndsAt = session.CountdownEndsAt,
		})
	end
end

local function close(session: Session, reason: string)
	if session.Closed then
		return
	end
	session.Closed = true
	for _, player in session.Players do
		if sessions[player] == session then
			sessions[player] = nil
		end
		tradeRemote:FireClient(player, "Closed", reason)
	end
end

-- Cualquier cambio: los dos dejan de estar listos y se corta la cuenta regresiva
local function changed(session: Session)
	session.Token += 1
	session.CountdownEndsAt = 0
	session.Ready = {}
end

-- ¿Esta mascota sigue siendo del jugador, en ese lugar?
local function stillOwns(player: Player, item: Item): boolean
	local profile = PlayerDataService.Get(player)
	if not profile then
		return false
	end
	for _, data in profile.Creatures do
		if data.Slot == item.Slot and data.CreatureId == item.CreatureId and data.Variant == item.Variant then
			return true
		end
	end
	return false
end

local function execute(session: Session)
	local a, b = session.Players[1], session.Players[2]
	-- Revisar todo de nuevo
	for _, player in session.Players do
		for _, item in session.Offers[player] do
			if not stillOwns(player, item) then
				close(session, "A creature in the trade is gone. Trade cancelled.")
				return
			end
		end
	end
	for _, player in session.Players do
		local partner = partnerOf(session, player)
		local room = CreatureService.GetFreeSlotCount(player) + #session.Offers[player]
		if room < #session.Offers[partner] then
			changed(session)
			sendState(session)
			notify(a, `{player.DisplayName} doesn't have enough free shelves for this trade.`)
			notify(b, `{player.DisplayName} doesn't have enough free shelves for this trade.`)
			return
		end
	end
	-- Sacar las mascotas de los dos y después dárselas al otro
	local outgoing: { [Player]: { Item } } = { [a] = {}, [b] = {} }
	for _, player in session.Players do
		for _, item in session.Offers[player] do
			local removed = CreatureService.RemoveCreature(player, item.Slot)
			if removed then
				table.insert(outgoing[player], { Slot = item.Slot, CreatureId = removed.CreatureId, Variant = removed.Variant })
			end
		end
	end
	for _, player in session.Players do
		local partner = partnerOf(session, player)
		for _, item in outgoing[partner] do
			local creature = Creatures.Get(item.CreatureId)
			if creature then
				CreatureService.AddCreature(player, creature, Config.GetVariant(item.Variant))
			end
		end
		PlayerDataService.SaveNow(player)
	end
	close(session, "Trade complete!")
end

-- ===== Acciones =====

function TradeService.Request(player: Player, target: Player)
	if target == player or not canTrade(player) or not canTrade(target) then
		return
	end
	if not nearStall(player) then
		return
	end
	if sessions[player] or sessions[target] then
		notify(player, `{target.DisplayName} is already trading.`)
		return
	end
	local mine = lastRequest[player] or {}
	lastRequest[player] = mine
	local now = os.clock()
	if now - (mine[target] or -math.huge) < Config.Trade.RequestCooldown then
		return
	end
	mine[target] = now
	local existing = invites[target]
	if existing and existing.ExpiresAt > now and existing.From ~= player then
		notify(player, `{target.DisplayName} already has a trade request. Try again soon.`)
		return
	end
	invites[target] = { From = player, ExpiresAt = now + Config.Trade.RequestTimeout }
	tradeRemote:FireClient(target, "Invite", player.DisplayName, player.UserId)
	notify(player, `Trade request sent to {target.DisplayName}!`)
end

function TradeService.Respond(player: Player, from: Player, accept: boolean)
	local invite = invites[player]
	if not invite or invite.From ~= from or invite.ExpiresAt < os.clock() then
		return
	end
	invites[player] = nil
	if not accept then
		notify(from, `{player.DisplayName} declined your trade.`)
		return
	end
	if sessions[player] or sessions[from] or not canTrade(player) or not canTrade(from) then
		notify(player, "That trade isn't available anymore.")
		return
	end
	local session: Session = {
		Players = { from, player },
		Offers = { [from] = {}, [player] = {} },
		Ready = {},
		CountdownEndsAt = 0,
		Token = 0,
		Closed = false,
	}
	sessions[from] = session
	sessions[player] = session
	sendState(session)
end

function TradeService.SetOffer(player: Player, slots: { number })
	local session = sessions[player]
	local profile = PlayerDataService.Get(player)
	if not session or not profile then
		return
	end
	local items: { Item } = {}
	local seen: { [number]: boolean } = {}
	for _, slot in slots do
		if not seen[slot] then
			seen[slot] = true
			for _, data in profile.Creatures do
				if data.Slot == slot then
					table.insert(items, { Slot = slot, CreatureId = data.CreatureId, Variant = data.Variant })
				end
			end
		end
	end
	if #items > Config.Trade.MaxItems or #items ~= #slots then
		return -- algo raro: no cambiamos nada
	end
	session.Offers[player] = items
	changed(session)
	sendState(session)
end

function TradeService.SetReady(player: Player, ready: boolean)
	local session = sessions[player]
	if not session then
		return
	end
	if not ready then
		changed(session)
		sendState(session)
		return
	end
	session.Ready[player] = true
	local partner = partnerOf(session, player)
	if session.Ready[partner] and (#session.Offers[player] > 0 or #session.Offers[partner] > 0) then
		session.Token += 1
		local token = session.Token
		session.CountdownEndsAt = Workspace:GetServerTimeNow() + Config.Trade.CountdownTime
		task.delay(Config.Trade.CountdownTime, function()
			if not session.Closed and session.Token == token then
				execute(session)
			end
		end)
	end
	sendState(session)
end

function TradeService.Cancel(player: Player, reason: string?)
	local session = sessions[player]
	if session then
		close(session, reason or `{player.DisplayName} cancelled the trade.`)
	end
end

function TradeService.GetSession(player: Player): Session?
	return sessions[player]
end

-- ¿Esta mascota está ofrecida en un intercambio? (para no dejar venderla)
function TradeService.IsOffered(player: Player, slot: number): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	for _, item in session.Offers[player] do
		if item.Slot == slot then
			return true
		end
	end
	return false
end

function TradeService.Init(map: Folder)
	local stalls = map:FindFirstChild("Stalls", true)
	local trading = stalls and stalls:FindFirstChild("Trading")
	local counter = trading and trading:FindFirstChild("Counter")
	if counter and counter:IsA("BasePart") then
		stall = counter
	end
	CreatureService.SetLockCheck(TradeService.IsOffered)

	tradeRemote.OnServerEvent:Connect(function(player: Player, action: unknown, a: unknown, b: unknown)
		local now = os.clock()
		if now - (lastAction[player] or 0) < Config.Trade.Cooldown then
			return
		end
		lastAction[player] = now
		-- Lo que manda el cliente no es confiable: revisamos tipos
		if action == "Request" then
			local target = findPlayer(a)
			if target then
				TradeService.Request(player, target)
			end
		elseif action == "Respond" then
			local from = findPlayer(a)
			if from and typeof(b) == "boolean" then
				TradeService.Respond(player, from, b)
			end
		elseif action == "Offer" and typeof(a) == "table" then
			local slots: { number } = {}
			local count = 0
			for _, value in a :: { any } do
				count += 1
				if typeof(value) ~= "number" or value ~= math.floor(value) or count > 50 then
					return
				end
				table.insert(slots, value)
			end
			TradeService.SetOffer(player, slots)
		elseif action == "Ready" and typeof(a) == "boolean" then
			TradeService.SetReady(player, a)
		elseif action == "Cancel" then
			TradeService.Cancel(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		TradeService.Cancel(player, `{player.DisplayName} left the game. Trade cancelled.`)
		invites[player] = nil
		for target, invite in invites do
			if invite.From == player then
				invites[target] = nil
			end
		end
		lastRequest[player] = nil
		lastAction[player] = nil
	end)
end

return TradeService

--!strict
-- FriendService: el bonus por jugar con amigos (botón "Invite" del HUD).
-- Cada amigo tuyo de Roblox que está en el mismo servidor te da Config.Friends.BonusPerFriend más de monedas
-- (hasta MaxBonus). Lo publica en el atributo "FriendBonus" del jugador (0.2 = +20%) y CreatureService lo usa.
-- Preguntar a Roblox si dos son amigos tarda: lo hacemos una vez por pareja cuando entra alguien y lo guardamos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureService = require(script.Parent.CreatureService)

local FriendService = {}

-- friends[a][b] = true si a y b son amigos (se llena de a poco, en los dos sentidos)
local friends: { [Player]: { [Player]: boolean } } = {}

local function update(player: Player)
	local count = 0
	local mine: { [Player]: boolean } = friends[player] or {}
	for other in mine do
		if other.Parent == Players then
			count += 1
		end
	end
	local bonus = math.min(Config.Friends.MaxBonus, count * Config.Friends.BonusPerFriend)
	if player:GetAttribute("FriendBonus") ~= bonus then
		player:SetAttribute("FriendBonus", bonus)
		player:SetAttribute("FriendCount", count)
		CreatureService.RefreshIncome(player)
	end
end

local function onPlayerAdded(player: Player)
	friends[player] = friends[player] or {}
	player:SetAttribute("FriendBonus", 0)
	player:SetAttribute("FriendCount", 0)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(function()
				local ok, isFriend = pcall(function()
					return player:IsFriendsWithAsync(other.UserId)
				end)
				if ok and isFriend and player.Parent == Players and other.Parent == Players then
					friends[player] = friends[player] or {}
					friends[other] = friends[other] or {}
					friends[player][other] = true
					friends[other][player] = true
					update(player)
					update(other)
				end
			end)
		end
	end
end

local function onPlayerRemoving(player: Player)
	local mine: { [Player]: boolean } = friends[player] or {}
	friends[player] = nil
	for other in mine do
		local theirs = friends[other]
		if theirs then
			theirs[player] = nil
			update(other)
		end
	end
end

-- Para las pruebas: marca a dos jugadores como amigos (como si Roblox lo hubiera dicho)
function FriendService.SetFriends(a: Player, b: Player)
	friends[a] = friends[a] or {}
	friends[b] = friends[b] or {}
	friends[a][b] = true
	friends[b][a] = true
	update(a)
	update(b)
end

function FriendService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return FriendService

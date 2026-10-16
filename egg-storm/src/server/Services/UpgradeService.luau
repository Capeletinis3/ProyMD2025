--!strict
-- UpgradeService: cobra y aplica las mejoras (Speed, Carry Eggs, Hatching, Luck y Extra Nest).
-- Se compran desde cualquier lado (botón "Shop" o el puesto del lobby), de a 1, de a 10 o el MÁXIMO que alcance.
-- El cliente solo dice "quiero comprar X (tantos niveles)". El servidor revisa TODO antes de cobrar:
-- que el nombre de la mejora exista, que tengas base, que no esté al máximo, que te alcance la plata y que no hagas spam.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Format = require(ReplicatedStorage.Shared.Format)
local BaseService = require(script.Parent.BaseService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local IncubatorService = require(script.Parent.IncubatorService)
local TutorialService = require(script.Parent.TutorialService)

type Base = BaseService.Base
type UpgradeId = Upgrades.UpgradeId

local UpgradeService = {}

local notifyRemote = Remotes.Event("Notify")
local buyRemote = Remotes.Event("BuyUpgrade")
local lastBuy: { [Player]: number } = {}

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

-- Pone la velocidad de caminata según el nivel comprado
function UpgradeService.ApplyWalkSpeed(player: Player)
	local profile = PlayerDataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not humanoid then
		return
	end
	local levels = Config.Upgrades.WalkSpeed
	local speed = levels[math.clamp(profile.WalkSpeedLevel, 1, #levels)].Speed
	player:SetAttribute("WalkSpeed", speed) -- para el HUD y para volver de "caminar lento" ([T])
	humanoid.WalkSpeed = speed
end

-- Hace el cambio de la mejora (ya cobrada). Devuelve false si no se pudo aplicar.
local function apply(player: Player, id: UpgradeId): boolean
	local profile = PlayerDataService.Get(player)
	if not profile then
		return false
	end
	if id == "IncubationSpeed" then
		profile.IncubationSpeedLevel += 1
		IncubatorService.RecalculateTimes(player) -- los huevos que ya están incubando también se aceleran
		return true
	elseif id == "ExtraIncubator" then
		return IncubatorService.AddIncubator(player)
	elseif id == "WalkSpeed" then
		profile.WalkSpeedLevel += 1
		UpgradeService.ApplyWalkSpeed(player)
		return true
	elseif id == "Luck" then
		profile.LuckLevel += 1
		return true
	elseif id == "Carry" then
		profile.CarryLevel += 1
		return true
	end
	return false
end

-- ===== API pública =====

-- Compra hasta "amount" niveles seguidos (los que alcance la plata). Devuelve cuántos compró.
function UpgradeService.TryBuy(player: Player, id: UpgradeId, amount: number?): number
	local now = os.clock()
	if now - (lastBuy[player] or 0) < Config.Upgrades.BuyCooldown then
		return 0
	end
	lastBuy[player] = now

	local base = BaseService.GetBase(player)
	local profile = PlayerDataService.Get(player)
	if not base or not profile then
		return 0
	end
	local wanted = math.clamp(math.floor(amount or 1), 1, 100)
	local name = Upgrades.DisplayNames[id]

	local first = Upgrades.GetNextCost(id, profile)
	if first == nil then
		notify(player, `{name} is already maxed!`)
		return 0
	end
	local bought = 0
	while bought < wanted do
		local cost = Upgrades.GetNextCost(id, profile)
		if cost == nil or not PlayerDataService.SpendCoins(player, cost) then
			break
		end
		if not apply(player, id) then
			PlayerDataService.AddCoins(player, cost, true) -- algo falló: devolvemos la plata (no cuenta como ganada)
			break
		end
		bought += 1
	end
	if bought == 0 then
		notify(player, `Not enough coins! You need {Format.Number(first)}.`)
		return 0
	end
	PlayerDataService.SyncLevels(player)
	notify(player, if bought == 1 then `{name} upgraded!` else `{name} upgraded x{bought}!`)
	TutorialService.OnEvent(player, "BoughtUpgrade")
	return bought
end

-- Cuando el jugador recibe su base: le pone su velocidad.
function UpgradeService.SetupBase(player: Player, _base: Base)
	UpgradeService.ApplyWalkSpeed(player)
end

function UpgradeService.ClearBase(player: Player, _base: Base)
	lastBuy[player] = nil
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		UpgradeService.ApplyWalkSpeed(player)
	end)
end

function UpgradeService.Init()
	buyRemote.OnServerEvent:Connect(function(player: Player, id: unknown, amount: unknown)
		-- Lo que manda el cliente no es confiable: revisamos que sea un nombre de mejora válido y una cantidad razonable
		-- (sin cantidad = 1 nivel; una cantidad rara, como texto, negativa o NaN, se ignora)
		if not Upgrades.IsValid(id) then
			return
		end
		if amount == nil then
			UpgradeService.TryBuy(player, id :: UpgradeId, 1)
		elseif typeof(amount) == "number" and amount == amount and amount >= 1 then
			UpgradeService.TryBuy(player, id :: UpgradeId, amount)
		end
	end)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return UpgradeService

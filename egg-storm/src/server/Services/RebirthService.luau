--!strict
-- RebirthService: el renacimiento.
-- El jugador aprieta "Rebirth" en su ventana (RebirthPanel en el cliente). El servidor revisa todo:
-- que no haya llegado al máximo, que le alcance la plata y que no haga spam. Si está todo bien:
--   - la plata vuelve a 0 (la plata ganada en total, la de la tabla de récords, no cambia)
--   - Incubation Speed y Walk Speed vuelven al nivel 1
--   - todas sus mascotas ganan +25% para siempre
-- Las mascotas, los huevos y las incubadoras se conservan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CreatureService = require(script.Parent.CreatureService)
local IncubatorService = require(script.Parent.IncubatorService)
local UpgradeService = require(script.Parent.UpgradeService)

local RebirthService = {}

local notifyRemote = Remotes.Event("Notify")
local rebirthRemote = Remotes.Event("Rebirth")
local lastAttempt: { [Player]: number } = {}

-- Precio del próximo renacimiento (no hay máximo: cada uno sale más caro)
function RebirthService.NextCost(rebirths: number): number
	return Config.RebirthCost(rebirths)
end

function RebirthService.TryRebirth(player: Player): boolean
	local now = os.clock()
	if now - (lastAttempt[player] or 0) < Config.Rebirth.Cooldown then
		return false
	end
	lastAttempt[player] = now

	local profile = PlayerDataService.Get(player)
	local base = BaseService.GetBase(player)
	if not profile or not base then
		return false
	end
	local cost = RebirthService.NextCost(profile.Rebirths)
	if profile.Coins < cost then
		notifyRemote:FireClient(player, `You need {Format.Number(cost)} coins to rebirth.`)
		return false
	end

	-- Reinicio
	PlayerDataService.SpendCoins(player, profile.Coins)
	profile.IncubationSpeedLevel = 1
	profile.WalkSpeedLevel = 1
	profile.Rebirths += 1

	-- Aplicar
	IncubatorService.RecalculateTimes(player)
	UpgradeService.ApplyWalkSpeed(player)
	CreatureService.RefreshIncome(player)
	PlayerDataService.SyncLevels(player)

	local bonus = math.round((Config.RebirthMultiplier(profile.Rebirths) - 1) * 100)
	local message = `REBIRTH {profile.Rebirths}! Your creatures now make +{bonus}% coins.`
	notifyRemote:FireClient(player, message)
	return true
end

function RebirthService.Init()
	rebirthRemote.OnServerEvent:Connect(function(player: Player, action: unknown)
		-- Lo único que se puede pedir es renacer
		if action == "Rebirth" then
			RebirthService.TryRebirth(player)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastAttempt[player] = nil
	end)
end

return RebirthService

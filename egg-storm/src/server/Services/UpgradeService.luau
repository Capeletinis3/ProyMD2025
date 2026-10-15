--!strict
-- UpgradeService: cobra y aplica las mejoras que se compran en el panel de la base.
-- El cliente solo dice "quiero comprar X". El servidor revisa TODO antes de cobrar:
-- que el nombre de la mejora exista, que sea tu base, que estés cerca del panel,
-- que no esté al máximo, que te alcance la plata y que no estés haciendo spam.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Format = require(ReplicatedStorage.Shared.Format)
local BaseService = require(script.Parent.BaseService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local IncubatorService = require(script.Parent.IncubatorService)
local BaseFloors = require(script.Parent.BaseFloors)
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
local function applyWalkSpeed(player: Player)
	local profile = PlayerDataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not humanoid then
		return
	end
	local levels = Config.Upgrades.WalkSpeed
	humanoid.WalkSpeed = levels[math.clamp(profile.WalkSpeedLevel, 1, #levels)].Speed
end

local function isNearPanel(player: Player, base: Base): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	-- Un margen extra por el lag
	return (root.Position - base.UpgradePanel.Position).Magnitude <= Config.Upgrades.PanelDistance + 5
end

-- Hace el cambio de la mejora (ya cobrada). Devuelve false si no se pudo aplicar.
local function apply(player: Player, base: Base, id: UpgradeId): boolean
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
		applyWalkSpeed(player)
		return true
	elseif id == "BaseFloor" then
		BaseFloors.Build(base)
		profile.BaseLevel = 2
		return true
	end
	return false
end

-- ===== API pública =====

function UpgradeService.TryBuy(player: Player, id: UpgradeId)
	local now = os.clock()
	if now - (lastBuy[player] or 0) < Config.Upgrades.BuyCooldown then
		return
	end
	lastBuy[player] = now

	local base = BaseService.GetBase(player)
	local profile = PlayerDataService.Get(player)
	if not base or not profile then
		return
	end
	if not isNearPanel(player, base) then
		return
	end

	local cost = Upgrades.GetNextCost(id, profile)
	if cost == nil then
		notify(player, `{Upgrades.DisplayNames[id]} is already maxed!`)
		return
	end
	if not PlayerDataService.SpendCoins(player, cost) then
		notify(player, `Not enough coins! You need {Format.Number(cost)}.`)
		return
	end
	if not apply(player, base, id) then
		PlayerDataService.AddCoins(player, cost, true) -- algo falló: devolvemos la plata (no cuenta como ganada)
		return
	end
	PlayerDataService.SyncLevels(player)
	notify(player, `{Upgrades.DisplayNames[id]} upgraded!`)
	TutorialService.OnEvent(player, "BoughtUpgrade")
end

-- Cuando el jugador recibe su base: segundo piso (si lo compró) y velocidad de caminata.
-- Tiene que ir ANTES que CreatureService.SetupBase, porque puede haber mascotas en el piso 2.
function UpgradeService.SetupBase(player: Player, base: Base)
	local profile = PlayerDataService.Get(player)
	if profile and profile.BaseLevel >= 2 then
		BaseFloors.Build(base)
	end
	applyWalkSpeed(player)
end

function UpgradeService.ClearBase(player: Player, base: Base)
	BaseFloors.Remove(base)
	lastBuy[player] = nil
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		applyWalkSpeed(player)
	end)
end

function UpgradeService.Init()
	buyRemote.OnServerEvent:Connect(function(player: Player, id: unknown)
		-- Lo que manda el cliente no es confiable: revisamos que sea un nombre de mejora válido
		if Upgrades.IsValid(id) then
			UpgradeService.TryBuy(player, id :: UpgradeId)
		end
	end)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return UpgradeService

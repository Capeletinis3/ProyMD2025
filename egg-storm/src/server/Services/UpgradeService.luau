--!strict
-- UpgradeService: cobra y aplica las mejoras que se compran en la Tienda de mejoras del lobby.
-- El cliente solo dice "quiero comprar X". El servidor revisa TODO antes de cobrar:
-- que el nombre de la mejora exista, que tengas base, que estés cerca del mostrador de la tienda,
-- que no esté al máximo, que te alcance la plata y que no estés haciendo spam.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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
function UpgradeService.ApplyWalkSpeed(player: Player)
	local profile = PlayerDataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not humanoid then
		return
	end
	local levels = Config.Upgrades.WalkSpeed
	humanoid.WalkSpeed = levels[math.clamp(profile.WalkSpeedLevel, 1, #levels)].Speed
end

-- ¿Está cerca del mostrador de la Tienda de mejoras? (MapBuilder le pone el atributo Stall = "UpgradeShop")
local function isNearShop(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local map = Workspace:FindFirstChild("Map")
	local stalls = map and map:FindFirstChild("Stalls", true)
	if not stalls then
		return false
	end
	-- Un margen extra por el lag
	local maxDistance = Config.Upgrades.PanelDistance + 5
	for _, stall in stalls:GetChildren() do
		local counter = stall:FindFirstChild("Counter")
		if counter and counter:IsA("BasePart") and counter:GetAttribute("Stall") == "UpgradeShop" and (root.Position - counter.Position).Magnitude <= maxDistance then
			return true
		end
	end
	return false
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
	if not isNearShop(player) then
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
	if not apply(player, id) then
		PlayerDataService.AddCoins(player, cost, true) -- algo falló: devolvemos la plata (no cuenta como ganada)
		return
	end
	PlayerDataService.SyncLevels(player)
	notify(player, `{Upgrades.DisplayNames[id]} upgraded!`)
	TutorialService.OnEvent(player, "BoughtUpgrade")
end

-- Cuando el jugador recibe su base: abre los pisos de la torre que tiene desbloqueados y pone su velocidad.
function UpgradeService.SetupBase(player: Player, base: Base)
	local profile = PlayerDataService.Get(player)
	BaseFloors.Apply(base, if profile then profile.BaseLevel else 1)
	UpgradeService.ApplyWalkSpeed(player)
end

function UpgradeService.ClearBase(player: Player, base: Base)
	BaseFloors.Reset(base)
	lastBuy[player] = nil
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		UpgradeService.ApplyWalkSpeed(player)
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

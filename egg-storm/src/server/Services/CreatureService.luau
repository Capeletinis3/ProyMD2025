--!strict
-- CreatureService: las mascotas de cada jugador.
-- Las pone en los pads de su base, y cada segundo le suma la plata que generan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local BaseService = require(script.Parent.BaseService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CreatureModels = require(script.Parent.CreatureModels)

type Base = BaseService.Base
type Creature = Creatures.Creature

local CreatureService = {}

-- Modelos que están en el mundo, por jugador y por número de pad
local modelsByPlayer: { [Player]: { [number]: Model } } = {}
local random = Random.new()

local function spawnModel(player: Player, base: Base, creature: Creature, slot: number)
	local pad = base.CreatureSlots[slot]
	if not pad then
		return
	end
	-- Encima del pad, mirando hacia el pasillo (igual que la base)
	local padTop = pad.Position + Vector3.new(0, pad.Size.X / 2, 0) -- el pad es un cilindro acostado: su grosor es Size.X
	local model = CreatureModels.Build(creature, CFrame.new(padTop) * base.Facing)
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = base.Model

	local models = modelsByPlayer[player]
	if not models then
		models = {}
		modelsByPlayer[player] = models
	end
	local old = models[slot]
	if old then
		old:Destroy()
	end
	models[slot] = model
end

local function updateIncomeAttribute(player: Player)
	player:SetAttribute("Income", CreatureService.GetIncomePerSecond(player))
end

-- ===== API pública =====

function CreatureService.GetIncomePerSecond(player: Player): number
	local profile = PlayerDataService.Get(player)
	if not profile then
		return 0
	end
	local total = 0
	for _, data in profile.Creatures do
		local creature = Creatures.Get(data.CreatureId)
		local rarity = creature and Config.GetRarity(creature.RarityId)
		if rarity then
			total += rarity.CoinsPerSecond
		end
	end
	return total
end

-- Cuántos pads de mascotas libres le quedan al jugador.
function CreatureService.GetFreeSlotCount(player: Player): number
	local base = BaseService.GetBase(player)
	local profile = PlayerDataService.Get(player)
	if not base or not profile then
		return 0
	end
	return #base.CreatureSlots - #profile.Creatures
end

-- Elige una mascota al azar de esa rareza.
function CreatureService.RollCreature(rarityId: string): Creature?
	local options = Creatures.ForRarity(rarityId)
	if #options == 0 then
		return nil
	end
	return options[random:NextInteger(1, #options)]
end

-- Le da una mascota al jugador en el primer pad libre. Devuelve el número de pad, o nil si no hay lugar.
function CreatureService.AddCreature(player: Player, creature: Creature): number?
	local base = BaseService.GetBase(player)
	local profile = PlayerDataService.Get(player)
	if not base or not profile then
		return nil
	end

	local used: { [number]: boolean } = {}
	for _, data in profile.Creatures do
		used[data.Slot] = true
	end
	for slot = 1, #base.CreatureSlots do
		if not used[slot] then
			table.insert(profile.Creatures, { CreatureId = creature.Id, Slot = slot })
			spawnModel(player, base, creature, slot)
			updateIncomeAttribute(player)
			return slot
		end
	end
	return nil
end

-- Cuando el jugador recibe su base: pone las mascotas que ya tenía.
function CreatureService.SetupBase(player: Player, base: Base)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	for _, data in profile.Creatures do
		local creature = Creatures.Get(data.CreatureId)
		if creature then
			spawnModel(player, base, creature, data.Slot)
		end
	end
	updateIncomeAttribute(player)
end

-- Cuando el jugador se va: saca los modelos para dejar la base limpia.
function CreatureService.ClearBase(player: Player)
	local models = modelsByPlayer[player]
	if models then
		for _, model in models do
			model:Destroy()
		end
	end
	modelsByPlayer[player] = nil
end

function CreatureService.Init()
	-- Cobro automático: cada IncomeInterval segundos, cada jugador suma la plata de sus mascotas.
	task.spawn(function()
		while true do
			task.wait(Config.Economy.IncomeInterval)
			for _, player in Players:GetPlayers() do
				local income = CreatureService.GetIncomePerSecond(player)
				if income > 0 then
					PlayerDataService.AddCoins(player, income * Config.Economy.IncomeInterval)
				end
			end
		end
	end)
end

return CreatureService

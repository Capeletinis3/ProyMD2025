--!strict
-- CreatureService: las mascotas de cada jugador.
-- Las pone en los pads de su base, cada segundo le suma la plata que generan,
-- y deja venderlas (mantener E sobre una mascota tuya) para hacer lugar.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Format = require(ReplicatedStorage.Shared.Format)
local BaseService = require(script.Parent.BaseService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CreatureModels = require(script.Parent.CreatureModels)

type Base = BaseService.Base
type Creature = Creatures.Creature

local CreatureService = {}

-- Modelos que están en el mundo, por jugador y por número de pad
local modelsByPlayer: { [Player]: { [number]: Model } } = {}
local lastSell: { [Player]: number } = {}
local random = Random.new()
local notifyRemote = Remotes.Event("Notify")

-- Botón "Sell" sobre la mascota. Solo lo ve el dueño (ver SellPrompts en el cliente); el servidor igual valida todo.
local function addSellPrompt(player: Player, model: Model, creature: Creature, slot: number)
	local body = model.PrimaryPart
	local rarity = Config.GetRarity(creature.RarityId)
	if not body or not rarity then
		return
	end
	local rare = creature.RarityId == "Legendary" or creature.RarityId == "Secret"
	local economy = Config.Economy
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sell"
	prompt.ObjectText = `{creature.DisplayName} · {Format.Number(Config.GetSellPrice(rarity))} coins`
	prompt.HoldDuration = if rare then economy.SellHoldTimeRare else economy.SellHoldTime
	prompt.MaxActivationDistance = economy.SellDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", player.UserId)
	CollectionService:AddTag(prompt, "SellPrompt")
	prompt.Parent = body
	prompt.Triggered:Connect(function(who)
		CreatureService.TrySell(who, player, slot, model)
	end)
end

local function spawnModel(player: Player, base: Base, creature: Creature, slot: number)
	local pad = base.CreatureSlots[slot]
	if not pad then
		return
	end
	-- Encima del pad, mirando hacia el pasillo (igual que la base)
	local padTop = pad.Position + Vector3.new(0, pad.Size.X / 2, 0) -- el pad es un cilindro acostado: su grosor es Size.X
	local model = CreatureModels.Build(creature, CFrame.new(padTop) * base.Facing)
	model:SetAttribute("OwnerUserId", player.UserId)
	addSellPrompt(player, model, creature, slot)
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

-- Lo llama el botón "Sell" de una mascota. Valida TODO en el servidor antes de pagar.
function CreatureService.TrySell(who: Player, owner: Player, slot: number, model: Model)
	if who ~= owner then
		notifyRemote:FireClient(who, "That's not your creature!")
		return
	end
	local now = os.clock()
	if now - (lastSell[owner] or 0) < Config.Economy.SellCooldown then
		return
	end
	lastSell[owner] = now

	-- La mascota tiene que seguir existiendo en ese pad (por si ya se vendió)
	local models = modelsByPlayer[owner]
	local profile = PlayerDataService.Get(owner)
	if not models or models[slot] ~= model or not profile then
		return
	end
	local index: number? = nil
	for i, data in profile.Creatures do
		if data.Slot == slot then
			index = i
			break
		end
	end
	if not index then
		return
	end
	local creature = Creatures.Get(profile.Creatures[index].CreatureId)
	local rarity = creature and Config.GetRarity(creature.RarityId)
	if not creature or not rarity then
		return
	end

	-- Tiene que estar vivo y cerca
	local character = owner.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local body = model.PrimaryPart
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") or not body then
		return
	end
	if (root.Position - body.Position).Magnitude > Config.Economy.SellDistance + 5 then
		return
	end

	table.remove(profile.Creatures, index)
	models[slot] = nil
	model:Destroy()
	local price = Config.GetSellPrice(rarity)
	PlayerDataService.AddCoins(owner, price)
	updateIncomeAttribute(owner)
	notifyRemote:FireClient(owner, `Sold {creature.DisplayName} for {Format.Number(price)} coins!`)
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
	lastSell[player] = nil
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

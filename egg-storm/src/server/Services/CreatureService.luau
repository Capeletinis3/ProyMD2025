--!strict
-- CreatureService: las mascotas de cada jugador.
-- Las pone en los estantes de la torre de su base (5 por piso; solo los pisos abiertos, ver BaseFloors),
-- cada segundo le suma la plata que generan, y deja venderlas (mantener E sobre una mascota tuya) para hacer lugar.

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
local EventService = require(script.Parent.EventService)
local BaseFloors = require(script.Parent.BaseFloors)

type Base = BaseService.Base
type Creature = Creatures.Creature
type Variant = Config.Variant

local CreatureService = {}

-- Modelos que están en el mundo, por jugador y por número de pad
local modelsByPlayer: { [Player]: { [number]: Model } } = {}
local lastSell: { [Player]: number } = {}
local random = Random.new()
local notifyRemote = Remotes.Event("Notify")

-- Botón "Sell" sobre la mascota. Solo lo ve el dueño (ver SellPrompts en el cliente); el servidor igual valida todo.
local function addSellPrompt(player: Player, model: Model, creature: Creature, variant: Variant, slot: number)
	local body = model.PrimaryPart
	local rarity = Config.GetRarity(creature.RarityId)
	if not body or not rarity then
		return
	end
	-- Las valiosas piden mantener más tiempo, para no venderlas sin querer
	local rare = Config.RarityRank(creature.RarityId) >= Config.RarityRank("Legendary") or variant.Multiplier >= 5
	local economy = Config.Economy
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sell"
	prompt.ObjectText = `{Config.WithVariant(variant, creature.DisplayName)} · {Format.Number(Config.GetSellPrice(rarity, variant))} coins`
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

local function spawnModel(player: Player, base: Base, creature: Creature, variant: Variant, slot: number)
	local pad = base.CreatureSlots[slot]
	if not pad then
		return
	end
	-- Encima del estante, mirando hacia el frente de la base (al lobby)
	local padTop = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
	local model = CreatureModels.Build(creature, CFrame.new(padTop) * base.Facing, variant)
	model:SetAttribute("OwnerUserId", player.UserId)
	addSellPrompt(player, model, creature, variant, slot)
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
	-- Los renacimientos suman un porcentaje a todas las mascotas
	return Creatures.TotalIncome(profile.Creatures) * Config.RebirthMultiplier(profile.Rebirths)
end

-- Vuelve a calcular la plata por segundo que ve el cliente (por ejemplo, después de renacer)
function CreatureService.RefreshIncome(player: Player)
	updateIncomeAttribute(player)
end

-- Cuántos estantes puede usar el jugador (los de los pisos que tiene abiertos)
local function usableSlots(base: Base, floors: number): number
	return math.min(#base.CreatureSlots, BaseFloors.SlotCount(floors))
end

-- Cuántos estantes libres (en pisos abiertos) le quedan al jugador.
function CreatureService.GetFreeSlotCount(player: Player): number
	local base = BaseService.GetBase(player)
	local profile = PlayerDataService.Get(player)
	if not base or not profile then
		return 0
	end
	local free = 0
	local used: { [number]: boolean } = {}
	for _, data in profile.Creatures do
		used[data.Slot] = true
	end
	for slot = 1, usableSlots(base, profile.BaseLevel) do
		if not used[slot] then
			free += 1
		end
	end
	return free
end

-- Elige una mascota al azar de esa rareza.
function CreatureService.RollCreature(rarityId: string): Creature?
	local options = Creatures.ForRarity(rarityId)
	if #options == 0 then
		return nil
	end
	return options[random:NextInteger(1, #options)]
end

-- Le da una mascota (con su variante) al jugador en el primer pad libre.
-- Devuelve el número de pad, o nil si no hay lugar.
function CreatureService.AddCreature(player: Player, creature: Creature, variant: Variant?): number?
	local chosen = variant or Config.GetVariant("Normal")
	local base = BaseService.GetBase(player)
	local profile = PlayerDataService.Get(player)
	if not base or not profile then
		return nil
	end

	local used: { [number]: boolean } = {}
	for _, data in profile.Creatures do
		used[data.Slot] = true
	end
	for slot = 1, usableSlots(base, profile.BaseLevel) do
		if not used[slot] then
			table.insert(profile.Creatures, { CreatureId = creature.Id, Slot = slot, Variant = chosen.Id })
			spawnModel(player, base, creature, chosen, slot)
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
	local variant = Config.GetVariant(profile.Creatures[index].Variant)
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
	local price = Config.GetSellPrice(rarity, variant)
	PlayerDataService.AddCoins(owner, price)
	updateIncomeAttribute(owner)
	notifyRemote:FireClient(owner, `Sold {Config.WithVariant(variant, creature.DisplayName)} for {Format.Number(price)} coins!`)
end

-- Cuando el jugador recibe su base: pone las mascotas que ya tenía.
-- Si alguna estaba en un lugar que no existe (datos de una versión vieja del mapa), la acomoda en un estante libre.
function CreatureService.SetupBase(player: Player, base: Base)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	local used: { [number]: boolean } = {}
	local misplaced: { PlayerDataService.CreatureData } = {}
	for _, data in profile.Creatures do
		if base.CreatureSlots[data.Slot] and not used[data.Slot] then
			used[data.Slot] = true
		else
			table.insert(misplaced, data)
		end
	end
	for _, data in misplaced do
		for slot = 1, #base.CreatureSlots do
			if not used[slot] then
				used[slot] = true
				data.Slot = slot
				break
			end
		end
	end
	for _, data in profile.Creatures do
		local creature = Creatures.Get(data.CreatureId)
		if creature then
			spawnModel(player, base, creature, Config.GetVariant(data.Variant), data.Slot)
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
	-- Cobro automático: cada IncomeInterval segundos, cada jugador suma la plata de sus mascotas
	-- (el doble durante el evento Double Coins).
	task.spawn(function()
		while true do
			task.wait(Config.Economy.IncomeInterval)
			local multiplier = EventService.IncomeMultiplier()
			for _, player in Players:GetPlayers() do
				local income = CreatureService.GetIncomePerSecond(player)
				if income > 0 then
					PlayerDataService.AddCoins(player, income * multiplier * Config.Economy.IncomeInterval)
				end
			end
		end
	end)
end

return CreatureService

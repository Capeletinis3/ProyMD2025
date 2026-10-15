--!strict
-- EventService: el evento especial de la tormenta actual (si hay).
--   GoldenRain   → muchos más huevos de variante (Silver, Golden, Emerald...)
--   LuckyStorm   → Epic, Legendary y Secret más probables
--   DoubleCoins  → las mascotas dan el doble de plata
--   MeteorShower → caen meteoritos con huevos Epic o mejores (los hace caer EggService)
-- StormService elige el evento al empezar la tormenta y lo termina en la calma.
-- Los demás servicios le preguntan a este cuánto cambian las chances o la plata.
-- El evento se publica como atributo "StormEvent" de Workspace para que el cliente lo muestre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local EventService = {}

local current: string? = nil
local random = Random.new()

-- ===== Cambiar el evento =====

function EventService.Set(id: string?)
	current = if id and Config.GetEvent(id) then id else nil
	Workspace:SetAttribute("StormEvent", current or "")
end

-- Sortea si esta tormenta tiene evento y cuál. Devuelve el evento elegido (o nil).
function EventService.RollForStorm(): Config.EventInfo?
	local events = Config.Events
	if random:NextNumber() >= events.ChancePerStorm then
		EventService.Set(nil)
		return nil
	end
	local total = 0
	for _, event in events.List do
		total += event.Weight
	end
	local roll = random:NextNumber(0, total)
	for _, event in events.List do
		roll -= event.Weight
		if roll <= 0 then
			EventService.Set(event.Id)
			return event
		end
	end
	EventService.Set(nil)
	return nil
end

function EventService.Get(): string?
	return current
end

function EventService.IsActive(id: string): boolean
	return current == id
end

-- ===== Lo que cambia cada evento =====

-- Multiplicador de la chance de una rareza (Lucky Storm sube Epic, Legendary y Secret).
function EventService.RarityMultiplier(rarityId: string): number
	if current == "LuckyStorm" and (rarityId == "Epic" or rarityId == "Legendary" or rarityId == "Secret") then
		return Config.Events.LuckyRarityBoost
	end
	return 1
end

-- Multiplicador de la chance de una variante (Golden Rain sube todas menos Normal).
function EventService.VariantMultiplier(variantId: string): number
	if current == "GoldenRain" and variantId ~= "Normal" then
		return Config.Events.GoldenRainVariantBoost
	end
	return 1
end

-- Multiplicador de la plata de las mascotas (Double Coins).
function EventService.IncomeMultiplier(): number
	return if current == "DoubleCoins" then Config.Events.DoubleCoinsMultiplier else 1
end

return EventService

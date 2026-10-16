--!strict
-- EventService: los eventos especiales del servidor.
--   GoldenRain   → lluvia de huevos: muchas más variantes (Silver, Golden, Emerald...) y reaparecen más rápido
--   LuckyStorm   → en cada zona sale más seguido la rareza siguiente
--   DoubleCoins  → las mascotas dan el doble de plata
--   MeteorShower → caen meteoritos con huevos Epic o mejores (los hace caer EggService)
-- Cada Config.Events.Interval segundos se sortea si empieza uno; dura Config.Events.Duration segundos.
-- Los demás servicios le preguntan a este cuánto cambian las chances o la plata.
-- Para el cliente se publica en atributos de Workspace: "Event" (Id o ""), "EventEndsAt" y "NextEventAt".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local EventService = {}

local current: string? = nil
local random = Random.new()
local notifyRemote = Remotes.Event("Notify")

-- ===== Cambiar el evento =====

-- Prende un evento (o lo apaga con nil). duration: cuánto dura (para el cartel del cliente).
function EventService.Set(id: string?, duration: number?)
	current = if id and Config.GetEvent(id) then id else nil
	Workspace:SetAttribute("Event", current or "")
	Workspace:SetAttribute("EventEndsAt", if current then Workspace:GetServerTimeNow() + (duration or Config.Events.Duration) else 0)
end

-- Sortea un evento de la lista (según sus pesos)
function EventService.Pick(): Config.EventInfo
	local list = Config.Events.List
	local total = 0
	for _, event in list do
		total += event.Weight
	end
	local roll = random:NextNumber(0, total)
	for _, event in list do
		roll -= event.Weight
		if roll <= 0 then
			return event
		end
	end
	return list[1]
end

function EventService.Get(): string?
	return current
end

function EventService.IsActive(id: string): boolean
	return current == id
end

-- ===== Lo que cambia cada evento =====

-- Multiplicador de la chance de que una zona dé su rareza siguiente (Lucky Storm).
function EventService.NextChanceMultiplier(): number
	return if current == "LuckyStorm" then Config.Events.LuckyNextChanceMultiplier else 1
end

-- Multiplicador de la chance de una variante (Golden Rain sube todas menos Normal).
function EventService.VariantMultiplier(variantId: string): number
	if current == "GoldenRain" and variantId ~= "Normal" then
		return Config.Events.GoldenRainVariantBoost
	end
	return 1
end

-- Multiplicador del tiempo de reaparición de huevos (Golden Rain: más rápido).
function EventService.RespawnMultiplier(): number
	return if current == "GoldenRain" then Config.Events.GoldenRainRespawnMultiplier else 1
end

-- Multiplicador de la plata de las mascotas (Double Coins).
function EventService.IncomeMultiplier(): number
	return if current == "DoubleCoins" then Config.Events.DoubleCoinsMultiplier else 1
end

-- ===== Ciclo =====

function EventService.Init()
	EventService.Set(nil)
	task.spawn(function()
		local events = Config.Events
		while true do
			Workspace:SetAttribute("NextEventAt", Workspace:GetServerTimeNow() + events.Interval)
			task.wait(events.Interval)
			if random:NextNumber() < events.Chance then
				local event = EventService.Pick()
				EventService.Set(event.Id, events.Duration)
				notifyRemote:FireAllClients(`{event.DisplayName}! {event.Description}`)
				Workspace:SetAttribute("NextEventAt", Workspace:GetServerTimeNow() + events.Duration)
				task.wait(events.Duration)
				EventService.Set(nil)
			end
		end
	end)
end

return EventService

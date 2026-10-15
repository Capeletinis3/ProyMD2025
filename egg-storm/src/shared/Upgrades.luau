--!strict
-- Upgrades: la definición de cada mejora (nivel, máximo, precio y descripción).
-- La usan el servidor (para cobrar y aplicar) y el cliente (para mostrar el panel),
-- así los dos siempre muestran y cobran lo mismo. Los números salen de Config.Upgrades.

local Config = require(script.Parent.Config)

-- "IncubationSpeed", "ExtraIncubator", "WalkSpeed" o "BaseFloor" (ver Upgrades.IsValid)
export type UpgradeId = string

-- Los niveles actuales del jugador (los mismos campos que el perfil del servidor)
export type State = {
	IncubationSpeedLevel: number,
	IncubatorCount: number,
	WalkSpeedLevel: number,
	BaseLevel: number,
}

local Upgrades = {}

-- Orden en el que aparecen en el panel
Upgrades.Order = { "IncubationSpeed", "ExtraIncubator", "WalkSpeed", "BaseFloor" } :: { UpgradeId }

Upgrades.DisplayNames = {
	IncubationSpeed = "Incubation Speed",
	ExtraIncubator = "Extra Incubator",
	WalkSpeed = "Walk Speed",
	BaseFloor = "Base Floor",
} :: { [UpgradeId]: string }

local MAX_BASE_LEVEL = 2

function Upgrades.IsValid(id: unknown): boolean
	return typeof(id) == "string" and Upgrades.DisplayNames[id] ~= nil
end

-- Devuelve (nivel actual, nivel máximo)
function Upgrades.GetLevel(id: UpgradeId, state: State): (number, number)
	local cfg = Config.Upgrades
	if id == "IncubationSpeed" then
		return state.IncubationSpeedLevel, #cfg.IncubationSpeed
	elseif id == "ExtraIncubator" then
		return state.IncubatorCount, cfg.MaxIncubators
	elseif id == "WalkSpeed" then
		return state.WalkSpeedLevel, #cfg.WalkSpeed
	else
		return state.BaseLevel, MAX_BASE_LEVEL
	end
end

-- Precio del próximo nivel, o nil si ya está al máximo
function Upgrades.GetNextCost(id: UpgradeId, state: State): number?
	local current, max = Upgrades.GetLevel(id, state)
	if current >= max then
		return nil
	end
	local cfg = Config.Upgrades
	if id == "IncubationSpeed" then
		return cfg.IncubationSpeed[current + 1].Cost
	elseif id == "ExtraIncubator" then
		return cfg.ExtraIncubatorCosts[current] -- con 1 incubadora, cuesta la 1.ª de la lista
	elseif id == "WalkSpeed" then
		return cfg.WalkSpeed[current + 1].Cost
	else
		return cfg.BaseFloor.Cost
	end
end

-- Texto corto que explica qué cambia (en inglés, lo ve el jugador)
function Upgrades.Describe(id: UpgradeId, state: State): string
	local cfg = Config.Upgrades
	local current, max = Upgrades.GetLevel(id, state)
	local maxed = current >= max
	if id == "IncubationSpeed" then
		local now = math.round(cfg.IncubationSpeed[current].Multiplier * 100)
		if maxed then
			return `Hatch time: {now}%`
		end
		return `Hatch time: {now}% → {math.round(cfg.IncubationSpeed[current + 1].Multiplier * 100)}%`
	elseif id == "ExtraIncubator" then
		if maxed then
			return `Incubators: {current}`
		end
		return `Incubators: {current} → {current + 1}`
	elseif id == "WalkSpeed" then
		if maxed then
			return `Speed: {cfg.WalkSpeed[current].Speed}`
		end
		return `Speed: {cfg.WalkSpeed[current].Speed} → {cfg.WalkSpeed[current + 1].Speed}`
	else
		if maxed then
			return "2nd floor built!"
		end
		return `Build a 2nd floor (+{cfg.BaseFloor.ExtraCreatureSlots} creature spots)`
	end
end

return Upgrades

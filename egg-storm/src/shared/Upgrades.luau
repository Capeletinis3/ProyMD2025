--!strict
-- Upgrades: la definición de cada mejora (nivel, máximo, precio y descripción).
-- La usan el servidor (para cobrar y aplicar) y el cliente (para mostrar el panel),
-- así los dos siempre muestran y cobran lo mismo. Los números salen de Config.Upgrades.

local Config = require(script.Parent.Config)

-- "WalkSpeed", "Carry", "IncubationSpeed", "Luck" o "ExtraIncubator" (ver Upgrades.IsValid).
export type UpgradeId = string

-- Los niveles actuales del jugador (los mismos campos que el perfil del servidor)
export type State = {
	IncubationSpeedLevel: number,
	IncubatorCount: number,
	WalkSpeedLevel: number,
	LuckLevel: number,
	CarryLevel: number,
}

local Upgrades = {}

-- Orden en el que aparecen en el panel
Upgrades.Order = { "WalkSpeed", "Carry", "IncubationSpeed", "Luck", "ExtraIncubator" } :: { UpgradeId }

Upgrades.DisplayNames = {
	WalkSpeed = "Speed",
	Carry = "Carry Eggs",
	IncubationSpeed = "Hatching",
	Luck = "Luck",
	ExtraIncubator = "Extra Nest",
} :: { [UpgradeId]: string }

Upgrades.Descriptions = {
	WalkSpeed = "Run faster to escape the wave",
	Carry = "Carry more than one egg at a time",
	IncubationSpeed = "Your nests hatch eggs faster",
	Luck = "Better chance for rarer eggs",
	ExtraIncubator = "One more nest in your habitat",
} :: { [UpgradeId]: string }

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
	elseif id == "Luck" then
		return state.LuckLevel, #cfg.Luck
	elseif id == "Carry" then
		return state.CarryLevel, #cfg.Carry
	else
		return state.WalkSpeedLevel, #cfg.WalkSpeed
	end
end

-- Precio del nivel que sigue a "level" (o nil si ya está al máximo)
local function costAfter(id: UpgradeId, level: number): number?
	local cfg = Config.Upgrades
	if id == "IncubationSpeed" then
		local next = cfg.IncubationSpeed[level + 1]
		return next and next.Cost
	elseif id == "ExtraIncubator" then
		return if level < cfg.MaxIncubators then cfg.ExtraIncubatorCosts[level] else nil -- con 1 nido, cuesta la 1.ª de la lista
	elseif id == "Luck" then
		local next = cfg.Luck[level + 1]
		return next and next.Cost
	elseif id == "Carry" then
		local next = cfg.Carry[level + 1]
		return next and next.Cost
	else
		local next = cfg.WalkSpeed[level + 1]
		return next and next.Cost
	end
end

-- Precio del próximo nivel, o nil si ya está al máximo
function Upgrades.GetNextCost(id: UpgradeId, state: State): number?
	local current = Upgrades.GetLevel(id, state)
	return costAfter(id, current)
end

-- Cuántos niveles se pueden comprar ahora con esta plata (hasta "wanted" niveles) y cuánto cuestan juntos
function Upgrades.Plan(id: UpgradeId, state: State, coins: number, wanted: number): (number, number)
	local level = Upgrades.GetLevel(id, state)
	local count, total = 0, 0
	while count < wanted do
		local cost = costAfter(id, level + count)
		if not cost or total + cost > coins then
			break
		end
		total += cost
		count += 1
	end
	return count, total
end

-- Valor de la mejora en un nivel, como texto corto ("24", "-15%", "+9%", "2")
function Upgrades.ValueText(id: UpgradeId, level: number): string
	local cfg = Config.Upgrades
	if id == "IncubationSpeed" then
		local entry = cfg.IncubationSpeed[math.clamp(level, 1, #cfg.IncubationSpeed)]
		return `-{math.round((1 - entry.Multiplier) * 100)}%`
	elseif id == "ExtraIncubator" then
		return tostring(level)
	elseif id == "Luck" then
		local entry = cfg.Luck[math.clamp(level, 1, #cfg.Luck)]
		return `+{math.round(entry.Chance * 100)}%`
	elseif id == "Carry" then
		local entry = cfg.Carry[math.clamp(level, 1, #cfg.Carry)]
		return tostring(1 + entry.Extra)
	else
		local entry = cfg.WalkSpeed[math.clamp(level, 1, #cfg.WalkSpeed)]
		return tostring(entry.Speed)
	end
end

-- Texto corto que explica qué cambia (en inglés, lo ve el jugador)
function Upgrades.Describe(id: UpgradeId, state: State): string
	local current, max = Upgrades.GetLevel(id, state)
	local name = Upgrades.DisplayNames[id]
	if current >= max then
		return `{name}: {Upgrades.ValueText(id, current)}`
	end
	return `{name}: {Upgrades.ValueText(id, current)} → {Upgrades.ValueText(id, current + 1)}`
end

return Upgrades

--!strict
-- BaseFloors: abre y cierra los pisos de la torre de una base.
-- La torre tiene 3 pisos con 5 estantes cada uno (ver MapBuilder). El piso 1 está siempre abierto;
-- los pisos 2 y 3 tienen una barrera con candado hasta que se desbloquean (con el renacimiento).
-- Cuántos pisos tiene abiertos un jugador se guarda en su perfil como BaseLevel (1, 2 o 3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseService = require(script.Parent.BaseService)

type Base = BaseService.Base

local BaseFloors = {}

local SHELF_UNLOCKED = Color3.fromRGB(255, 226, 122)
local SHELF_LOCKED = Color3.fromRGB(91, 74, 184)

-- Las barreras de cada base, por piso (las guardamos para poder volver a ponerlas)
type LockInfo = { Folder: Instance, Barriers: { [number]: Instance } }
local locksByBase: { [Base]: LockInfo } = {}

local function getLocks(base: Base): LockInfo
	local info = locksByBase[base]
	if info then
		return info
	end
	local folder = base.Model:FindFirstChild("Locks") or base.Model
	local barriers: { [number]: Instance } = {}
	for _, child in folder:GetChildren() do
		local floor = child:GetAttribute("Floor")
		if typeof(floor) == "number" then
			barriers[floor] = child
		end
	end
	local created: LockInfo = { Folder = folder, Barriers = barriers }
	locksByBase[base] = created
	return created
end

-- Cuántos estantes se pueden usar con esa cantidad de pisos abiertos
function BaseFloors.SlotCount(floors: number): number
	return math.clamp(floors, 1, Config.Map.BaseFloors) * Config.Map.ShelvesPerFloor
end

-- ¿Este estante (número de lugar) está en un piso abierto?
function BaseFloors.IsSlotUnlocked(slot: number, floors: number): boolean
	return slot >= 1 and slot <= BaseFloors.SlotCount(floors)
end

-- Deja la base con esa cantidad de pisos abiertos (saca o pone las barreras y pinta los estantes).
function BaseFloors.Apply(base: Base, floors: number)
	local open = math.clamp(floors, 1, Config.Map.BaseFloors)
	local info = getLocks(base)
	for floor, barrier in info.Barriers do
		barrier.Parent = if floor <= open then nil else info.Folder
	end
	for index, shelf in base.CreatureSlots do
		local unlocked = BaseFloors.IsSlotUnlocked(index, open)
		shelf:SetAttribute("Unlocked", unlocked)
		shelf.Color = if unlocked then SHELF_UNLOCKED else SHELF_LOCKED
	end
end

-- Cuando el dueño se va: la base vuelve a tener solo el piso 1
function BaseFloors.Reset(base: Base)
	BaseFloors.Apply(base, 1)
end

return BaseFloors

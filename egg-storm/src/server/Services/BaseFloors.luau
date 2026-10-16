--!strict
-- BaseFloors: abre y cierra los pisos de la torre de una base.
-- La torre tiene 3 pisos con 5 estantes cada uno (ver MapBuilder). El piso 1 está siempre abierto;
-- los pisos 2 y 3 tienen una barrera con candado hasta que se desbloquean (con el renacimiento).
-- Cuántos pisos tiene abiertos un jugador se guarda en su perfil como BaseLevel (1, 2 o 3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseService = require(script.Parent.BaseService)
local BaseBuilder = require(script.Parent.BaseBuilder)

type Base = BaseService.Base

local BaseFloors = {}

local SHELF_UNLOCKED = BaseBuilder.ShelfOn
local SHELF_LOCKED = BaseBuilder.ShelfOff
local OPEN_COLOR = Color3.fromRGB(76, 209, 55)
local CLOSED_COLOR = Color3.fromRGB(107, 107, 115)

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
		-- La lamparita del estante se prende cuando su piso está abierto
		local lamp = shelf:FindFirstChild("Lamp")
		local spot = lamp and lamp:FindFirstChildOfClass("SpotLight")
		if spot then
			spot.Brightness = if unlocked then 1.6 else 0
		end
	end
	-- Cartel "BIGGER TOWER": qué pisos ya están abiertos
	local shop = base.Model:FindFirstChild("FloorShop")
	local paper = shop and shop:FindFirstChild("Paper")
	local gui = paper and paper:FindFirstChild("ShopGui")
	if gui then
		for floor = 2, Config.Map.BaseFloors do
			local row = gui:FindFirstChild(`Floor{floor}`)
			if row and row:IsA("TextLabel") then
				local isOpen = floor <= open
				row.Text = if isOpen then `FLOOR {floor} ✓ OPEN` else `FLOOR {floor} · REBIRTH {floor - 1}`
				row.BackgroundColor3 = if isOpen then OPEN_COLOR else CLOSED_COLOR
			end
		end
	end
end

-- Cuando el dueño se va: la base vuelve a tener solo el piso 1
function BaseFloors.Reset(base: Base)
	BaseFloors.Apply(base, 1)
end

return BaseFloors

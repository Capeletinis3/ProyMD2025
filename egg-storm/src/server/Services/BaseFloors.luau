--!strict
-- BaseFloors: arma (y saca) el segundo piso de una base, la mejora "Base Floor".
-- Es una plataforma sobre columnas arriba de la mitad de atrás de la base, con más pads para mascotas.
-- Los pads nuevos se suman a base.CreatureSlots, así CreatureService los usa igual que los de abajo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseService = require(script.Parent.BaseService)

type Base = BaseService.Base

local BaseFloors = {}

local FLOOR_HEIGHT = 12 -- altura del piso 2
local PAD_SIZE = 8

type FloorInfo = { Model: Model, Pads: { BasePart } }
local floors: { [Base]: FloorInfo } = {}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Parent = parent
	return p
end

function BaseFloors.Has(base: Base): boolean
	return floors[base] ~= nil
end

function BaseFloors.Build(base: Base)
	if floors[base] then
		return
	end
	local primary = base.Model.PrimaryPart
	if not primary then
		return
	end
	-- Mismo sistema de coordenadas que MapBuilder: centro de la base a nivel del piso, -Z hacia el pasillo
	local plotCFrame = CFrame.new(primary.Position - Vector3.new(0, primary.Size.Y / 2, 0)) * base.Facing
	local floorPart = base.Model:FindFirstChild("Floor")
	local color = if floorPart and floorPart:IsA("BasePart") then floorPart.Color else primary.Color
	local w, d = Config.Map.PlotWidth, Config.Map.PlotDepth
	local depth = d / 2 -- cubre la mitad de atrás

	local model = Instance.new("Model")
	model.Name = "Floor2"

	-- Plataforma y columnas
	makePart("Platform", Vector3.new(w, 1, depth), plotCFrame * CFrame.new(0, FLOOR_HEIGHT + 0.5, depth / 2), color, model)
	for _, x in { -w / 2 + 1, w / 2 - 1 } do
		for _, z in { 1, depth - 1 } do
			makePart("Pillar", Vector3.new(1.5, FLOOR_HEIGHT, 1.5), plotCFrame * CFrame.new(x, FLOOR_HEIGHT / 2, z), Color3.fromRGB(240, 240, 240), model)
		end
	end
	-- Baranda de vidrio
	local railY = FLOOR_HEIGHT + 2
	local rails: { { Size: Vector3, Offset: CFrame } } = {
		{ Size = Vector3.new(w, 2, 0.4), Offset = CFrame.new(0, railY, 0.2) },
		{ Size = Vector3.new(w, 2, 0.4), Offset = CFrame.new(0, railY, depth - 0.2) },
		{ Size = Vector3.new(0.4, 2, depth), Offset = CFrame.new(-w / 2 + 0.2, railY, depth / 2) },
		{ Size = Vector3.new(0.4, 2, depth), Offset = CFrame.new(w / 2 - 0.2, railY, depth / 2) },
	}
	for _, rail in rails do
		local p = makePart("Rail", rail.Size, plotCFrame * rail.Offset, Color3.fromRGB(200, 240, 255), model)
		p.Material = Enum.Material.Glass
		p.Transparency = 0.5
	end

	-- Pads de mascotas arriba: siguen la numeración de los de abajo
	local pads: { BasePart } = {}
	local padColor = color:Lerp(Color3.new(0, 0, 0), 0.4)
	local columns = { -14, 0, 14 }
	local rows = { depth * 0.27, depth * 0.73 }
	local extra = Config.Upgrades.BaseFloor.ExtraCreatureSlots
	for _, z in rows do
		for _, x in columns do
			if #pads >= extra then
				break
			end
			local pad = makePart("CreatureSlot", Vector3.new(0.3, PAD_SIZE, PAD_SIZE), plotCFrame * CFrame.new(x, FLOOR_HEIGHT + 1.15, z) * CFrame.Angles(0, 0, math.rad(90)), padColor, model)
			pad.Shape = Enum.PartType.Cylinder
			pad.TopSurface = Enum.SurfaceType.Smooth
			pad:SetAttribute("SlotIndex", #base.CreatureSlots + 1)
			table.insert(base.CreatureSlots, pad)
			table.insert(pads, pad)
		end
	end

	model.Parent = base.Model
	floors[base] = { Model = model, Pads = pads }
end

-- Saca el piso 2 (cuando el dueño se va) y devuelve la base a sus pads originales.
function BaseFloors.Remove(base: Base)
	local info = floors[base]
	if not info then
		return
	end
	for _, pad in info.Pads do
		local index = table.find(base.CreatureSlots, pad)
		if index then
			table.remove(base.CreatureSlots, index)
		end
	end
	info.Model:Destroy()
	floors[base] = nil
end

return BaseFloors

--!strict
-- BaseFloors: arma (y saca) el segundo piso de una base, la mejora "Base Floor".
-- Es el estante del medio de la estantería de la base (ver MapBuilder): un piso violeta a rayas
-- sobre la mitad de atrás, con más pads para mascotas y una escalera de mano por el costado para subir.
-- Los pads nuevos se suman a base.CreatureSlots, así CreatureService los usa igual que los de abajo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseService = require(script.Parent.BaseService)

type Base = BaseService.Base

local BaseFloors = {}

local FLOOR_HEIGHT = 12 -- altura del piso 2 (la parte de arriba de la plataforma queda en FLOOR_HEIGHT + 1)
local PAD_SIZE = 8
local LADDER_GAP = 6 -- hueco en la baranda, junto a la escalera, para pasar al piso

local FRAME = Color3.fromRGB(35, 45, 110)
local DECK = Color3.fromRGB(120, 80, 220)
local STRIPE = Color3.fromRGB(205, 185, 255)

type FloorInfo = { Model: Model, Pads: { BasePart } }
local floors: { [Base]: FloorInfo } = {}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
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
	local w, d = Config.Map.PlotWidth, Config.Map.PlotDepth
	local depth = d / 2 -- cubre la mitad de atrás
	local platformTop = FLOOR_HEIGHT + 1

	local model = Instance.new("Model")
	model.Name = "Floor2"

	-- Piso violeta con rayas lila (las rayas son solo dibujo, no chocan)
	makePart("Platform", Vector3.new(w, 1, depth), plotCFrame * CFrame.new(0, FLOOR_HEIGHT + 0.5, depth / 2), DECK, model)
	local stripeWidth = 2.5
	local stripeX = -w / 2 + stripeWidth / 2
	while stripeX < w / 2 do
		local stripe = makePart("DeckStripe", Vector3.new(stripeWidth, 0.05, depth), plotCFrame * CFrame.new(stripeX, platformTop + 0.025, depth / 2), STRIPE, model)
		stripe.CanCollide = false
		stripe.CanQuery = false
		stripeX += stripeWidth * 2
	end

	-- Baranda de vidrio. Del lado de la escalera (+X) deja un hueco adelante para pasar.
	local railY = FLOOR_HEIGHT + 2
	local rails: { { Size: Vector3, Offset: CFrame } } = {
		{ Size = Vector3.new(w, 2, 0.4), Offset = CFrame.new(0, railY, 0.2) },
		{ Size = Vector3.new(w, 2, 0.4), Offset = CFrame.new(0, railY, depth - 0.2) },
		{ Size = Vector3.new(0.4, 2, depth), Offset = CFrame.new(-w / 2 + 0.2, railY, depth / 2) },
		{ Size = Vector3.new(0.4, 2, depth - LADDER_GAP), Offset = CFrame.new(w / 2 - 0.2, railY, (depth + LADDER_GAP) / 2) },
	}
	for _, rail in rails do
		local p = makePart("Rail", rail.Size, plotCFrame * rail.Offset, Color3.fromRGB(200, 240, 255), model)
		p.Material = Enum.Material.Glass
		p.Transparency = 0.5
	end

	-- Escalera de mano (TrussPart: en Roblox se trepa sola al caminar contra ella), pegada al costado de afuera,
	-- frente al hueco de la baranda. Llega un poco más arriba del piso para pasar cómodo.
	local ladderHeight = math.ceil((platformTop + 1) / 2) * 2 -- las TrussPart miden de a 2 studs
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Size = Vector3.new(2, ladderHeight, 2)
	ladder.CFrame = plotCFrame * CFrame.new(w / 2 + 1, ladderHeight / 2, LADDER_GAP / 2)
	ladder.Style = Enum.Style.NoSupports -- solo los parantes y los escalones, como una escalera
	ladder.Color = FRAME
	ladder.Anchored = true
	ladder.Parent = model

	-- Pads de mascotas arriba: siguen la numeración de los de abajo
	local pads: { BasePart } = {}
	local padColor = Color3.fromRGB(70, 50, 150)
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

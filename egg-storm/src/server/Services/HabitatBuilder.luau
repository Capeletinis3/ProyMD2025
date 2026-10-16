--!strict
-- HabitatBuilder: arma la base de cada jugador como un HÁBITAT DE SELVA (diseño "Hábitat v3").
--   * muro natural de rocas (bajo adelante, alto atrás) con selva arriba y musgo
--   * entrada tipo portal: pilares de piedra con máscaras tiki, techito de paja, tu nombre y guirnalda
--   * acantilado atrás con una cascada de 2 saltos entre dos árboles grandes, pozo con niebla,
--     arroyo con un tronco de puente y lago con arena, nenúfares y juncos
--   * selva en capas: 3 árboles de copa ancha, hojas gigantes, monsteras, helechos y 2 palmeras
--   * terraza de piedra con el refugio de paja, lomitas, sendero de tierra, tronco caído y hongos que brillan
--   * 2 grutas con arco de piedra y cortina de lianas (hongos o cristales que brillan adentro)
--   * los 3 nidos en un altarcito de piedra a la derecha de la entrada y un cartel con tus criaturas
--   * 20 lugares (CreatureSlots) repartidos por el pasto: ahí nace cada criatura y pasea alrededor
--
-- Lo que usan los servicios (no cambiar los nombres): Plot (PrimaryPart, mira al lobby), CreatureSlots
-- (Spot_N con SlotIndex), IncubatorSlots (Nest1-3 con Pedestal + SlotIndex), SignLabel, InfoLabel,
-- SpawnPoint y SafeZone. Coordenadas como en el diseño, mirando el hábitat desde el lobby:
-- -Z = adelante (la entrada, hacia el lobby), +Z = atrás (la cascada), +X = a la derecha, -X = a la izquierda.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HabitatBuilder = {}

local M = Enum.Material

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local C = {
	grass = rgb(84, 160, 62), grassDark = rgb(62, 132, 50), dirt = rgb(140, 102, 64),
	rock1 = rgb(132, 124, 114), rock2 = rgb(112, 104, 96), rock3 = rgb(150, 140, 126), rockDark = rgb(90, 84, 78),
	moss = rgb(70, 140, 60), leaf1 = rgb(46, 158, 68), leaf2 = rgb(63, 154, 72), leaf3 = rgb(36, 120, 52),
	trunk = rgb(112, 76, 44), trunkDark = rgb(86, 58, 34), straw = rgb(217, 164, 65), strawDark = rgb(196, 138, 44),
	water = rgb(64, 190, 225), waterDeep = rgb(36, 150, 200), foam = rgb(240, 250, 255), sand = rgb(242, 212, 155),
	stone = rgb(142, 133, 122), stoneDark = rgb(110, 102, 93), mask = rgb(160, 82, 45), gold = rgb(255, 212, 59),
	pink = rgb(255, 79, 139), mushroom = rgb(120, 230, 255), crystal = rgb(178, 107, 255), paper = rgb(255, 241, 208),
}
local LEAVES = { C.leaf1, C.leaf2, C.leaf3 }
local ROCKS = { C.rock1, C.rock2, C.rock3 }
local FLOWERS = { rgb(255, 79, 139), rgb(255, 212, 59), rgb(178, 107, 255), rgb(255, 255, 255), rgb(255, 138, 31) }

HabitatBuilder.InnerRadius = 28 -- radio del pasto por dentro del muro
local WALL_RADIUS = 31
local ENTRANCE_HALF_ANGLE = math.rad(17)
local NEST_SPOTS = { Vector3.new(11, 0, -19), Vector3.new(17.5, 0, -10.5), Vector3.new(21, 0, -1.5) }

type Props = { [string]: any }

local P: CFrame = CFrame.new()
local rng = Random.new(1)
-- Lugares donde no puede pararse ni pasear una criatura (agua, terraza, árboles, nidos...): se llenan al armar
local obstacles: { { Center: Vector3, Radius: number } } = {}

local function avoid(center: Vector3, radius: number)
	table.insert(obstacles, { Center = Vector3.new(center.X, 0, center.Z), Radius = radius })
end
local UP = Vector3.new(0, 1, 0)

-- ===== Ayudantes (coordenadas locales del hábitat) =====

local function apply(p: BasePart, props: Props?)
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
end

local function deco(extra: Props?): Props
	local props: Props = extra or {}
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	return props
end

-- Pasa de las coordenadas del diseño al mundo. Mirando desde el lobby la derecha es -X del plot,
-- así que damos vuelta la X (y las rotaciones, para que sigan siendo rotaciones de verdad).
local function flip(v: Vector3): Vector3
	return Vector3.new(-v.X, v.Y, v.Z)
end

local function place(pos: Vector3, rot: CFrame?): CFrame
	if not rot then
		return P * CFrame.new(flip(pos))
	end
	local r, u, b = rot.RightVector, rot.UpVector, -rot.LookVector
	return P * CFrame.fromMatrix(flip(pos), Vector3.new(r.X, -r.Y, -r.Z), Vector3.new(-u.X, u.Y, u.Z), Vector3.new(-b.X, b.Y, b.Z))
end

local function newPart(parent: Instance, name: string, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function block(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, rot: CFrame?, props: Props?): Part
	local p = newPart(parent, name)
	p.Size = size
	p.CFrame = place(pos, rot)
	p.Color = color
	p.Material = material or M.SmoothPlastic
	apply(p, props)
	return p
end

local function ball(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, props: Props?): Part
	local p = newPart(parent, name, Enum.PartType.Ball)
	p.Size = size
	p.CFrame = place(pos)
	p.Color = color
	p.Material = material or M.SmoothPlastic
	apply(p, props)
	return p
end

-- Disco plano (cilindro parado) con la cara de arriba en "top"
local function disc(parent: Instance, name: string, diameter: number, thick: number, center: Vector3, top: number, color: Color3, material: Enum.Material?, props: Props?): Part
	local p = newPart(parent, name, Enum.PartType.Cylinder)
	p.Size = Vector3.new(thick, diameter, diameter)
	p.CFrame = place(Vector3.new(center.X, top - thick / 2, center.Z), CFrame.Angles(0, 0, math.rad(90)))
	p.Color = color
	p.Material = material or M.SmoothPlastic
	apply(p, props)
	return p
end

-- Cilindro entre dos puntos
local function seg(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?, props: Props?): Part
	local wa, wb = P:PointToWorldSpace(flip(a)), P:PointToWorldSpace(flip(b))
	local x = (wb - wa).Unit
	local ref = if math.abs(x.Y) < 0.95 then UP else P.RightVector
	local z = x:Cross(ref).Unit
	local y = z:Cross(x)
	local p = newPart(parent, name, Enum.PartType.Cylinder)
	p.Size = Vector3.new((wb - wa).Magnitude, diameter, diameter)
	p.CFrame = CFrame.fromMatrix((wa + wb) / 2, x, y, z)
	p.Color = color
	p.Material = material or M.Wood
	apply(p, props)
	return p
end

local function group(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function surfaceText(target: BasePart, face: Enum.NormalId, text: string, color: Color3, labelName: string): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = target
	local t = Instance.new("TextLabel")
	t.Name = labelName
	t.Size = UDim2.fromScale(0.94, 0.9)
	t.Position = UDim2.fromScale(0.03, 0.05)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = rgb(42, 22, 8)
	stroke.Parent = t
	t.Parent = gui
	return t
end

-- Punto en el borde del círculo: ángulo 0 = adelante (-Z), crece hacia la derecha (+X)
local function around(angle: number, radius: number, y: number?): Vector3
	return Vector3.new(math.sin(angle) * radius, y or 0, -math.cos(angle) * radius)
end

local function rockFace(angle: number): CFrame
	return CFrame.Angles(0, -angle, 0)
end

-- ===== Piezas =====

local function palm(parent: Instance, base: Vector3, height: number)
	avoid(base, 2.5)
	local m = group(parent, "Palm")
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
	local current = base
	local count = 6
	for i = 0, count - 1 do
		local dir = (UP + lean * (0.08 * i)).Unit
		local nextPoint = current + dir * (height / count)
		seg(m, "Trunk", current, nextPoint + dir * 0.3, 2 - i * 0.1, if i % 2 == 0 then C.trunk else C.trunkDark, M.Wood)
		current = nextPoint
	end
	for k = 1, 7 do
		local angle = k / 7 * math.pi * 2
		local droop = math.rad(rng:NextNumber(18, 34))
		local tip = current + Vector3.new(math.cos(angle) * math.cos(droop), -math.sin(droop), math.sin(angle) * math.cos(droop)) * 10
		local leaf = seg(m, "Leaf", current, tip, 0.4, LEAVES[rng:NextInteger(1, 3)], M.LeafyGrass, deco())
		leaf.Shape = Enum.PartType.Block
		leaf.Size = Vector3.new(leaf.Size.X, 0.35, 2.8)
	end
end

-- Árbol de copa ancha (los de la selva de verdad)
local function broadTree(parent: Instance, base: Vector3, height: number, spread: number)
	avoid(base, 3)
	local m = group(parent, "JungleTree")
	seg(m, "Trunk", base, base + Vector3.new(0, height, 0), 2.6, C.trunk, M.Wood)
	for k = 1, 3 do
		local angle = k * 2.1
		local branchEnd = base + Vector3.new(math.cos(angle) * spread * 0.35, height * 0.8, math.sin(angle) * spread * 0.35)
		seg(m, "Branch", base + Vector3.new(0, height * 0.6, 0), branchEnd, 1.2, C.trunkDark, M.Wood)
	end
	for k = 1, 5 do
		local angle = k / 5 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = if k == 5 then 0 else spread * 0.32
		local size = spread * rng:NextNumber(0.55, 0.75)
		ball(m, "Canopy", Vector3.new(size, size * 0.45, size), base + Vector3.new(math.cos(angle) * r, height + rng:NextNumber(-1, 1.5), math.sin(angle) * r), LEAVES[rng:NextInteger(1, 3)], M.LeafyGrass, deco())
	end
	-- Lianas con flores colgando
	for _ = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local top = base + Vector3.new(math.cos(angle) * spread * 0.4, height - 1, math.sin(angle) * spread * 0.4)
		local length = rng:NextNumber(5, 9)
		seg(m, "Liana", top, top - Vector3.new(0, length, 0), 0.25, C.leaf3, M.LeafyGrass, deco())
		ball(m, "LianaFlower", Vector3.new(0.8, 0.8, 0.8), top - Vector3.new(0, length * 0.7, 0), FLOWERS[rng:NextInteger(1, #FLOWERS)], M.SmoothPlastic, deco())
	end
end

local function bigLeaf(parent: Instance, pos: Vector3, size: number)
	local angle = rng:NextNumber(0, math.pi * 2)
	block(parent, "GiantLeaf", Vector3.new(size * 0.6, 0.25, size), pos + Vector3.new(0, size * 0.25, 0), LEAVES[rng:NextInteger(1, 3)], M.LeafyGrass, CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(-35), 0, 0), deco())
end

local function monstera(parent: Instance, pos: Vector3)
	local m = group(parent, "Monstera")
	for k = 1, 5 do
		local angle = k / 5 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		block(m, "Leaf", Vector3.new(2.6, 0.2, 3.4), pos + Vector3.new(math.cos(angle) * 1.4, 1.4 + rng:NextNumber(0, 0.8), math.sin(angle) * 1.4), C.leaf3, M.LeafyGrass, CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.Angles(math.rad(-30), 0, 0), deco())
	end
end

local function fern(parent: Instance, pos: Vector3)
	for k = 1, 4 do
		local angle = k / 4 * math.pi * 2 + rng:NextNumber(0, 0.5)
		block(parent, "Fern", Vector3.new(0.9, 0.15, 3), pos + Vector3.new(math.cos(angle), 0.6, math.sin(angle)), C.leaf1, M.Grass, CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.Angles(math.rad(-25), 0, 0), deco())
	end
end

local function mushroom(parent: Instance, pos: Vector3, color: Color3)
	local m = group(parent, "Mushroom")
	seg(m, "Stem", pos, pos + Vector3.new(0, 1.1, 0), 0.4, rgb(240, 235, 220), M.SmoothPlastic, deco())
	local cap = ball(m, "Cap", Vector3.new(1.4, 0.7, 1.4), pos + Vector3.new(0, 1.2, 0), color, M.Neon, deco())
	light(cap, color, 6, 0.8)
end

local function bush(parent: Instance, pos: Vector3, size: number)
	for _ = 1, 2 do
		local s = size * rng:NextNumber(0.7, 1)
		ball(parent, "Bush", Vector3.new(s, s * 0.7, s), pos + Vector3.new(rng:NextNumber(-1, 1), s * 0.3, rng:NextNumber(-1, 1)), LEAVES[rng:NextInteger(1, 3)], M.LeafyGrass, deco())
	end
	ball(parent, "Flower", Vector3.new(0.8, 0.8, 0.8), pos + Vector3.new(0, size * 0.65, 0), FLOWERS[rng:NextInteger(1, #FLOWERS)], M.SmoothPlastic, deco())
end

-- ===== Partes del hábitat =====

local function buildGround(model: Model, plot: CFrame)
	local g = group(model, "Ground")
	local plotPart = newPart(g, "Plot")
	plotPart.Size = Vector3.new(WALL_RADIUS * 2 + 6, 0.2, WALL_RADIUS * 2 + 6)
	plotPart.CFrame = plot * CFrame.new(0, 0.1, 0)
	plotPart.Transparency = 1
	plotPart.CanCollide = false
	model.PrimaryPart = plotPart
	disc(g, "Grass", (WALL_RADIUS + 2) * 2, 0.4, Vector3.new(0, 0, 0), 0.35, C.grass, M.Grass)
	-- Lomitas de pasto
	for _, spot in { Vector3.new(-8, 0, 6), Vector3.new(6, 0, -2), Vector3.new(-2, 0, 12) } do
		ball(g, "Mound", Vector3.new(9, 1.4, 7), spot + Vector3.new(0, 0.2, 0), C.grassDark, M.Grass, { CanCollide = false })
	end
	-- Sendero de tierra de la entrada al centro
	for i = 0, 6 do
		local t = i / 6
		disc(g, "Path", 4.4 - t * 0.8, 0.12, Vector3.new(math.sin(t * 2.4) * 2, 0, -27 + t * 22), 0.42, C.dirt, M.Ground, deco())
	end
end

local function buildWall(model: Model)
	local w = group(model, "Wall")
	local count = 30
	for i = 0, count - 1 do
		local angle = (i + 0.5) / count * math.pi * 2
		local fromFront = math.abs(((angle + math.pi) % (math.pi * 2)) - math.pi) -- 0 adelante, pi atrás
		if fromFront > ENTRANCE_HALF_ANGLE then
			local t = fromFront / math.pi
			local height = 6 + (24 - 6) * t ^ 1.6 + rng:NextNumber(-1.5, 1.5)
			local width = (WALL_RADIUS * 2 * math.pi / count) + rng:NextNumber(1, 3)
			local depth = rng:NextNumber(5, 7)
			local radius = WALL_RADIUS + rng:NextNumber(-0.6, 0.6)
			local center = around(angle, radius, height / 2 - 0.5)
			block(w, "Rock", Vector3.new(width, height, depth), center, ROCKS[rng:NextInteger(1, #ROCKS)], if i % 3 == 0 then M.Rock else M.Slate, rockFace(angle) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.08, 0.08)))
			-- Musgo y selva arriba
			block(w, "Moss", Vector3.new(width * 0.9, 0.8, depth * 0.85), center + Vector3.new(0, height / 2 + 0.2, 0), C.moss, M.LeafyGrass, rockFace(angle), deco())
			if height > 11 and i % 2 == 0 then
				local s = rng:NextNumber(6, 9)
				ball(w, "Jungle", Vector3.new(s, s * 0.6, s), around(angle, radius + 1.5, height + 1), LEAVES[rng:NextInteger(1, 3)], M.LeafyGrass, deco())
			end
			-- Liana colgando hacia adentro
			if i % 4 == 1 then
				local top = around(angle, radius - depth / 2, height - 0.5)
				seg(w, "Liana", top, top - Vector3.new(0, math.min(height - 2, 7), 0), 0.25, C.leaf3, M.LeafyGrass, deco())
			end
		end
	end
	-- Brazos de roca de la entrada (se abren hacia afuera)
	for _, side in { -1, 1 } do
		for k = 0, 2 do
			local angle = side * (ENTRANCE_HALF_ANGLE + 0.05)
			local pos = around(angle, WALL_RADIUS + 3 + k * 3.5, 0) + Vector3.new(side * k * 2.2, 0, 0)
			local h = 7 - k * 1.5
			block(w, "ArmRock", Vector3.new(5, h, 4.5), pos + Vector3.new(0, h / 2 - 0.5, 0), ROCKS[rng:NextInteger(1, #ROCKS)], M.Slate, CFrame.Angles(0, side * (0.4 + k * 0.2), 0))
			ball(w, "ArmJungle", Vector3.new(4.5, 2.4, 4.5), pos + Vector3.new(0, h + 0.4, 0), LEAVES[rng:NextInteger(1, 3)], M.LeafyGrass, deco())
		end
	end
end

-- Entrada tipo portal: pilares de piedra con máscaras tiki, techito de paja, nombre del dueño y guirnalda
local function buildEntrance(model: Model)
	local e = group(model, "Entrance")
	local z = -WALL_RADIUS - 1
	for _, side in { -1, 1 } do
		local x = side * 6.5
		block(e, "Pillar", Vector3.new(3, 11, 3), Vector3.new(x, 5.5, z), C.stone, M.Slate)
		block(e, "PillarCap", Vector3.new(3.6, 0.8, 3.6), Vector3.new(x, 11.2, z), C.stoneDark, M.Slate)
		local mask = block(e, "TikiMask", Vector3.new(2.4, 3.2, 0.5), Vector3.new(x, 7.5, z - 1.7), C.mask, M.Wood)
		for _, ex in { -0.55, 0.55 } do
			block(e, "MaskEye", Vector3.new(0.6, 0.45, 0.2), Vector3.new(x + ex, 8.1, z - 2), C.gold, M.Neon, nil, deco())
		end
		block(e, "MaskMouth", Vector3.new(1.4, 0.5, 0.2), Vector3.new(x, 6.7, z - 2), rgb(70, 40, 20), M.Wood, nil, deco())
		local torch = ball(e, "Flame", Vector3.new(1, 1, 1), Vector3.new(x + side * 2.6, 6.6, z - 1), rgb(255, 138, 31), M.Neon, deco({ Transparency = 0.3 }))
		seg(e, "TorchPole", Vector3.new(x + side * 2.6, 0, z - 1), Vector3.new(x + side * 2.6, 6, z - 1), 0.6, C.trunk, M.Wood)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Parent = torch
		light(torch, rgb(255, 138, 31), 14, 2)
		mask.Name = "TikiMask"
	end
	-- Techito de paja
	block(e, "Beam", Vector3.new(16, 1.2, 3), Vector3.new(0, 12, z), C.trunkDark, M.Wood)
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "RoofThatch"
		wedge.Anchored = true
		wedge.Size = Vector3.new(18, 3, 3)
		wedge.CFrame = place(Vector3.new(0, 14, z + side * 1.5), CFrame.Angles(0, if side < 0 then 0 else math.pi, 0))
		wedge.Color = C.straw
		wedge.Material = M.Fabric
		wedge.Parent = e
	end
	-- Cartel tallado con el nombre (BaseService cambia el texto de "SignLabel")
	local sign = block(e, "Sign", Vector3.new(11, 2.4, 0.5), Vector3.new(0, 9.8, z - 0.6), rgb(160, 102, 46), M.WoodPlanks)
	surfaceText(sign, Enum.NormalId.Front, "Free Base", rgb(255, 231, 176), "SignLabel")
	-- Guirnalda de flores
	for k = 0, 10 do
		local x = -6 + k * 1.2
		ball(e, "Garland", Vector3.new(0.8, 0.8, 0.8), Vector3.new(x, 11.1 - math.sin(k / 10 * math.pi) * 1.3, z - 1.6), FLOWERS[k % #FLOWERS + 1], M.SmoothPlastic, deco())
	end
end

-- Acantilado atrás con la cascada de 2 saltos, pozo con niebla, arroyo con tronco y lago
local function buildWater(model: Model)
	local wtr = group(model, "Water")
	local fallX = 3
	-- Acantilado (más alto que el muro) y un escalón a media altura
	block(wtr, "Cliff", Vector3.new(16, 27, 6), Vector3.new(fallX, 13.5, WALL_RADIUS - 2), C.rock2, M.Rock)
	block(wtr, "Ledge", Vector3.new(9, 13, 5), Vector3.new(fallX, 6.5, WALL_RADIUS - 6.5), C.rock1, M.Slate)
	ball(wtr, "CliffJungle", Vector3.new(14, 5, 8), Vector3.new(fallX, 27.5, WALL_RADIUS - 1), C.leaf3, M.LeafyGrass, deco())
	local function fall(name: string, top: number, bottom: number, z: number, width: number)
		local sheet = block(wtr, name, Vector3.new(width, top - bottom, 0.8), Vector3.new(fallX, (top + bottom) / 2, z), rgb(170, 225, 255), M.Glass, nil, deco({ Transparency = 0.3 }))
		local mist = Instance.new("ParticleEmitter")
		mist.Name = "Mist"
		mist.Color = ColorSequence.new(C.foam)
		mist.Size = NumberSequence.new(2.5, 6)
		mist.Transparency = NumberSequence.new(0.5, 1)
		mist.Lifetime = NumberRange.new(1.5, 2.5)
		mist.Speed = NumberRange.new(2, 4)
		mist.Rate = 8
		mist.EmissionDirection = Enum.NormalId.Bottom
		mist.Parent = sheet
		return sheet
	end
	fall("WaterfallTop", 27, 13, WALL_RADIUS - 5.3, 5)
	fall("WaterfallBottom", 13, 0.5, WALL_RADIUS - 9.4, 6)
	-- Pozo con niebla al pie
	local poolCenter = Vector3.new(fallX, 0, WALL_RADIUS - 13)
	avoid(poolCenter, 7.5)
	disc(wtr, "PoolRim", 11, 0.5, poolCenter, 0.55, C.stone, M.Slate)
	disc(wtr, "Pool", 9.5, 0.4, poolCenter, 0.62, C.waterDeep, M.Glass, deco({ Transparency = 0.15 }))
	disc(wtr, "Foam", 4, 0.1, poolCenter + Vector3.new(0, 0, 3), 0.7, C.foam, M.SmoothPlastic, deco({ Transparency = 0.3 }))
	-- Arroyo curvo hasta el lago (adelante a la izquierda)
	local lakeCenter = Vector3.new(-13, 0, -6)
	avoid(lakeCenter, 10.5)
	local previous = poolCenter
	for i = 1, 6 do
		local t = i / 6
		local point = poolCenter:Lerp(lakeCenter, t) + Vector3.new(math.sin(t * math.pi) * -5, 0, 0)
		local mid = (previous + point) / 2
		local length = (point - previous).Magnitude + 0.8
		block(wtr, "Creek", Vector3.new(3, 0.12, length), Vector3.new(mid.X, 0.6, mid.Z), C.water, M.Glass, CFrame.lookAt(Vector3.new(), point - previous), deco({ Transparency = 0.15 }))
		if i == 3 then
			-- Tronco de puente
			seg(wtr, "LogBridge", mid + Vector3.new(-3, 1.1, 0), mid + Vector3.new(3, 1.1, 0), 1.6, C.trunk, M.Wood)
		end
		avoid(mid, 3.5)
		previous = point
	end
	-- Lago con arena, nenúfares y juncos
	disc(wtr, "LakeSand", 19, 0.3, lakeCenter, 0.55, C.sand, M.Sand)
	disc(wtr, "Lake", 15, 0.3, lakeCenter, 0.65, C.water, M.Glass, deco({ Transparency = 0.15 }))
	for k = 1, 5 do
		local angle = k * 1.3
		disc(wtr, "LilyPad", 1.8, 0.1, lakeCenter + Vector3.new(math.cos(angle) * 4.5, 0, math.sin(angle) * 4.5), 0.75, C.leaf1, M.SmoothPlastic, deco())
		if k % 2 == 0 then
			ball(wtr, "Lotus", Vector3.new(0.7, 0.5, 0.7), lakeCenter + Vector3.new(math.cos(angle) * 4.5, 0.95, math.sin(angle) * 4.5), C.pink, M.SmoothPlastic, deco())
		end
	end
	for k = 1, 8 do
		local angle = k * 0.8 + 2
		local base = lakeCenter + Vector3.new(math.cos(angle) * 8.2, 0.4, math.sin(angle) * 8.2)
		seg(wtr, "Reed", base, base + Vector3.new(0, rng:NextNumber(2, 3.5), 0), 0.25, C.leaf3, M.Grass, deco())
	end
end

-- Terraza de piedra con el refugio de paja (atrás a la izquierda)
local function buildShelter(model: Model)
	local s = group(model, "Shelter")
	local c = Vector3.new(-14, 0, 13)
	avoid(c, 8.5)
	block(s, "Terrace", Vector3.new(13, 1.2, 10), c + Vector3.new(0, 0.6, 0), C.stone, M.Slate)
	block(s, "TerraceStep", Vector3.new(5, 0.6, 2), c + Vector3.new(4, 0.3, -6), C.stoneDark, M.Slate)
	for _, dx in { -4.5, 4.5 } do
		for _, dz in { -3.5, 3.5 } do
			seg(s, "Post", c + Vector3.new(dx, 1.2, dz), c + Vector3.new(dx, 7, dz), 0.8, C.trunk, M.Wood)
		end
	end
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof"
		wedge.Anchored = true
		wedge.Size = Vector3.new(12, 3, 5)
		wedge.CFrame = place(c + Vector3.new(0, 8.5, side * 2.5), CFrame.Angles(0, if side < 0 then 0 else math.pi, 0))
		wedge.Color = C.straw
		wedge.Material = M.Fabric
		wedge.Parent = s
	end
	block(s, "HayBed", Vector3.new(6, 0.8, 4), c + Vector3.new(-1, 1.6, 1), C.strawDark, M.Fabric, nil, deco())
	local lantern = block(s, "Lantern", Vector3.new(0.9, 1.2, 0.9), c + Vector3.new(3, 6, 0), C.gold, M.Neon, nil, deco())
	light(lantern, C.gold, 12, 1.4)
	-- Comederos
	for _, spot in { Vector3.new(-5, 0, -12), Vector3.new(8, 0, 6) } do
		avoid(spot, 3)
		local trough = block(s, "Feeder", Vector3.new(3.6, 1, 1.8), spot + Vector3.new(0, 0.9, 0), C.trunk, M.WoodPlanks)
		block(s, "Food", Vector3.new(3, 0.3, 1.2), spot + Vector3.new(0, 1.45, 0), rgb(255, 160, 60), M.SmoothPlastic, nil, deco())
		trough.Name = "Feeder"
	end
	-- Tronco caído
	seg(s, "FallenLog", Vector3.new(-22, 1, -6), Vector3.new(-16, 1.2, -14), 1.8, C.trunkDark, M.Wood)
	for t = 0, 1, 0.5 do
		avoid(Vector3.new(-22, 0, -6):Lerp(Vector3.new(-16, 0, -14), t), 2.5)
	end
end

-- Grutas-cueva con arco de piedra y cortina de lianas (adentro brillan hongos o cristales)
local function buildGrottos(model: Model)
	local g = group(model, "Grottos")
	for i, info in { { Angle = math.rad(-125), Glow = C.mushroom, Name = "MushroomGrotto" }, { Angle = math.rad(130), Glow = C.crystal, Name = "CrystalGrotto" } } do
		local grotto = group(g, info.Name)
		local angle = info.Angle
		local center = around(angle, WALL_RADIUS - 4.5, 0)
		block(grotto, "Back", Vector3.new(8, 9, 2), around(angle, WALL_RADIUS - 1.5, 4.5), C.rockDark, M.Rock, rockFace(angle))
		for _, side in { -1, 1 } do
			local offset = Vector3.new(math.cos(angle) * side * 4, 0, math.sin(angle) * side * 4)
			block(grotto, "ArchSide", Vector3.new(1.8, 8, 4), center + offset + Vector3.new(0, 4, 0), C.rock3, M.Slate, rockFace(angle))
		end
		block(grotto, "ArchTop", Vector3.new(10, 2, 4), center + Vector3.new(0, 8.5, 0), C.rock3, M.Slate, rockFace(angle))
		for k = -3, 3 do
			local offset = Vector3.new(math.cos(angle) * k * 1.1, 0, math.sin(angle) * k * 1.1)
			seg(grotto, "Vine", center + offset + Vector3.new(0, 7.5, 0), center + offset + Vector3.new(0, 7.5 - rng:NextNumber(2, 4), 0), 0.25, C.leaf3, M.LeafyGrass, deco())
		end
		for k = 1, 3 do
			local inside = around(angle + (k - 2) * 0.08, WALL_RADIUS - 2.8, 0.4)
			if i == 1 then
				mushroom(grotto, inside, info.Glow)
			else
				local shard = block(grotto, "Crystal", Vector3.new(0.9, rng:NextNumber(2, 3.5), 0.9), inside + Vector3.new(0, 1.4, 0), info.Glow, M.Neon, CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), deco())
				light(shard, info.Glow, 8, 1)
			end
		end
	end
end

-- Selva en capas: árboles grandes, palmeras, hojas gigantes, monsteras, helechos, arbustos y hongos
local function buildJungle(model: Model)
	local j = group(model, "Jungle")
	broadTree(j, Vector3.new(-6, 0.3, WALL_RADIUS - 8), 20, 16) -- a los lados de la cascada
	broadTree(j, Vector3.new(13, 0.3, WALL_RADIUS - 8), 18, 15)
	broadTree(j, Vector3.new(-23, 0.3, -2), 16, 13)
	palm(j, Vector3.new(-20, 0.4, -13), 18)
	palm(j, Vector3.new(-5, 0.4, -16), 15)
	for _, spot in { Vector3.new(-24, 0.3, 6), Vector3.new(24, 0.3, 12), Vector3.new(-18, 0.3, 20), Vector3.new(20, 0.3, -18), Vector3.new(9, 0.3, 21) } do
		bigLeaf(j, spot, rng:NextNumber(4, 6))
	end
	for _, spot in { Vector3.new(-25, 0.3, 12), Vector3.new(23, 0.3, 17), Vector3.new(-9, 0.3, 22) } do
		monstera(j, spot)
	end
	for _, spot in { Vector3.new(-22, 0.3, -9), Vector3.new(14, 0.3, 14), Vector3.new(-2, 0.3, 21), Vector3.new(24, 0.3, -2), Vector3.new(-26, 0.3, 0) } do
		fern(j, spot)
	end
	for _, spot in { Vector3.new(-17, 0.3, -20), Vector3.new(25, 0.3, 6), Vector3.new(-26, 0.3, -4) } do
		bush(j, spot, 3.5)
	end
	for _, spot in { Vector3.new(-19, 0.3, 7), Vector3.new(-12, 0.3, 19), Vector3.new(17, 0.3, 19), Vector3.new(-24, 0.3, -12) } do
		mushroom(j, spot, if rng:NextNumber() < 0.5 then C.mushroom else rgb(255, 120, 200))
	end
end

-- Altarcito de piedra con los 3 nidos (IncubatorService les agrega el huevo, la luz, el botón y el reloj)
local function buildNests(model: Model)
	local nests = Instance.new("Folder")
	nests.Name = "IncubatorSlots"
	nests.Parent = model
	block(model, "NestAltar", Vector3.new(9, 0.6, 30), Vector3.new(16, 0.6, -10.25), C.stoneDark, M.Slate, CFrame.Angles(0, math.rad(30), 0))
	for i, spot in NEST_SPOTS do
		local nest = group(nests, `Nest{i}`)
		local pedestal = block(nest, "Pedestal", Vector3.new(7, 2, 7), spot + Vector3.new(0, 1, 0), C.stone, M.Slate)
		pedestal:SetAttribute("SlotIndex", i)
		disc(nest, "NestBase", 6.5, 1.5, spot, 3.6, C.trunk, M.WoodPlanks)
		for k = 1, 10 do
			local a = k / 10 * math.pi * 2
			block(nest, "NestRim", Vector3.new(2, 1.1, 0.8), spot + Vector3.new(math.cos(a) * 3, 3.7, math.sin(a) * 3), if k % 2 == 0 then C.straw else C.strawDark, M.Fabric, CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(math.rad(-25), 0, 0), deco())
		end
	end
end

-- 20 lugares por el pasto (lejos del agua, de la terraza y de los nidos)
local function buildSpots(model: Model)
	local slots = Instance.new("Folder")
	slots.Name = "CreatureSlots"
	slots.Parent = model
	avoid(Vector3.new(0, 0, -WALL_RADIUS + 2), 7) -- la entrada (por ahí entra el jugador)
	for _, spot in NEST_SPOTS do
		avoid(spot, 6.5)
	end
	local blocked = obstacles
	local placed: { Vector3 } = {}
	local tries = 0
	local spotRng = Random.new(77)
	while #placed < Config.Habitat.Capacity and tries < 4000 do
		tries += 1
		local angle = spotRng:NextNumber(0, math.pi * 2)
		local radius = math.sqrt(spotRng:NextNumber(0, 1)) * (HabitatBuilder.InnerRadius - 5)
		local point = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local ok = true
		for _, area in blocked do
			if (point - area.Center).Magnitude < area.Radius then
				ok = false
				break
			end
		end
		for _, other in placed do
			if (point - other).Magnitude < 4.5 then
				ok = false
				break
			end
		end
		if ok then
			table.insert(placed, point)
		end
	end
	-- Ordenados de adelante hacia atrás (los primeros quedan cerca de la entrada)
	table.sort(placed, function(a, b)
		return a.Z < b.Z
	end)
	for i, point in placed do
		local spot = block(slots, `Spot_{i}`, Vector3.new(4, 0.2, 4), point + Vector3.new(0, 0.45, 0), C.grass, M.SmoothPlastic, nil, deco({ Transparency = 1 }))
		spot:SetAttribute("SlotIndex", i)
		-- Hasta dónde puede pasear la criatura de este lugar sin meterse al agua, a la terraza o al muro
		local room = HabitatBuilder.InnerRadius - 1.5 - point.Magnitude
		for _, area in blocked do
			room = math.min(room, (point - area.Center).Magnitude - area.Radius + 2.5)
		end
		spot:SetAttribute("WanderRadius", math.clamp(room, 1.5, Config.Habitat.WanderRadius))
	end
	return placed
end

-- Cartel con cuántas criaturas tenés y cuánto ganan (CreatureService cambia el texto de "InfoLabel")
local function buildInfoSign(model: Model)
	local s = group(model, "InfoSign")
	local pos = Vector3.new(-12, 0, -WALL_RADIUS - 5)
	seg(s, "Post", pos, pos + Vector3.new(0, 5, 0), 0.7, C.trunk, M.Wood)
	local board = block(s, "Board", Vector3.new(7, 3, 0.5), pos + Vector3.new(0, 5.8, 0), C.paper, M.SmoothPlastic)
	surfaceText(board, Enum.NormalId.Front, "0/20 · +0/s", rgb(42, 22, 8), "InfoLabel")
end

-- Arma el hábitat número "index". "plot" es el centro mirando al lobby (frente = -Z).
function HabitatBuilder.Build(index: number, plot: CFrame, parent: Instance): Model
	P = plot
	rng = Random.new(31 + index)
	obstacles = {}
	local model = Instance.new("Model")
	model.Name = `Base{index}`
	model:SetAttribute("BaseId", index)
	model:SetAttribute("OwnerUserId", 0)

	buildGround(model, plot)
	buildWall(model)
	buildEntrance(model)
	buildWater(model)
	buildShelter(model)
	buildGrottos(model)
	buildJungle(model)
	buildNests(model)
	buildSpots(model)
	buildInfoSign(model)

	block(model, "SpawnPoint", Vector3.new(4, 1, 4), Vector3.new(0, 0.5, -WALL_RADIUS + 6), C.grass, M.SmoothPlastic, nil, deco({ Transparency = 1 }))
	block(model, "SafeZone", Vector3.new(WALL_RADIUS * 2 + 6, 60, WALL_RADIUS * 2 + 6), Vector3.new(0, 30, 0), C.grass, M.SmoothPlastic, nil, deco({ Transparency = 1 }))

	model.Parent = parent
	return model
end

return HabitatBuilder

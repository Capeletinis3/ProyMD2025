--!strict
-- VillageBuilder: la decoración del lobby "Aldea de la selva" (diseño de Claude Design).
--   * plaza del altar rodeada por un foso de agua turquesa con nenúfares y peces koi, y 4 puentes de madera con faroles
--   * arriba a la izquierda: laguna con cascada, niebla, piedras para cruzar, flamencos, juncos, bancos y mariposas
--   * abajo a la izquierda: árbol gigante con una casita de paja arriba (se sube por la escalera de soga), columpio,
--     lianas, faroles colgando, hongos y luciérnagas
--   * arriba a la derecha: fogón tiki con chispas, 3 filas de troncos y un escenario con máscara gigante y tambores
--   * abajo a la derecha: jardín con los 6 huevos gigantes de las rarezas en nidos con cartel (los raros brillan),
--     flores gigantes y un arco de flores
--   * pasarela de madera desde la plaza hasta la entrada de cada hábitat, y selva entre los hábitats
-- El altar, los puestos, el camino al cañón y el portal siguen en MapBuilder. Las medidas salen de Config.Village.
-- Todo es decoración: lo único que choca es lo que se pisa (puentes, pasarela, piedras, troncos, escenario, casita).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local VillageBuilder = {}

local M = Enum.Material
local V = Config.Village
local Y0 = Config.Map.FloorY

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local C = {
	water = rgb(63, 216, 240), waterDeep = rgb(40, 170, 210), foam = rgb(240, 250, 255), sand = rgb(242, 212, 155),
	stone = rgb(150, 142, 130), stoneDark = rgb(112, 104, 96), plaza = rgb(214, 196, 160), plank = rgb(170, 116, 62),
	plankDark = rgb(120, 80, 40), rope = rgb(196, 160, 100), straw = rgb(217, 164, 65), strawDark = rgb(190, 136, 46),
	trunk = rgb(112, 76, 44), trunkDark = rgb(86, 58, 34), leaf1 = rgb(46, 158, 68), leaf2 = rgb(63, 154, 72),
	leaf3 = rgb(36, 120, 52), lamp = rgb(255, 196, 92), pink = rgb(255, 120, 170), koi = rgb(255, 120, 40),
	mask = rgb(160, 82, 45), gold = rgb(255, 212, 59), dirt = rgb(150, 110, 70), lily = rgb(70, 170, 70),
}
local LEAVES = { C.leaf1, C.leaf2, C.leaf3 }
local FLOWERS = { rgb(255, 79, 139), rgb(255, 212, 59), rgb(178, 107, 255), rgb(255, 255, 255), rgb(255, 138, 31) }
local UP = Vector3.new(0, 1, 0)

type Props = { [string]: any }

local rng = Random.new(2024)

-- ===== Ayudantes (coordenadas del mundo, con el piso en Y0) =====

local function group(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
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

-- "solid" = se puede pisar; si no, es solo decoración (no choca ni hace sombra)
local function finish(p: BasePart, color: Color3, material: Enum.Material?, solid: boolean?, props: Props?)
	p.Color = color
	p.Material = material or M.SmoothPlastic
	if solid then
		p.CanCollide = true
	else
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
	end
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, props: Props?): Part
	local p = newPart(parent, name)
	p.Size = size
	p.CFrame = cf
	finish(p, color, material, solid, props)
	return p
end

local function ball(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, props: Props?): Part
	local p = newPart(parent, name, Enum.PartType.Ball)
	p.Size = size
	p.CFrame = CFrame.new(pos)
	finish(p, color, material, false, props)
	return p
end

-- Disco plano con la cara de arriba en "top"
local function disc(parent: Instance, name: string, diameter: number, thick: number, x: number, z: number, top: number, color: Color3, material: Enum.Material?, solid: boolean?, props: Props?): Part
	local p = newPart(parent, name, Enum.PartType.Cylinder)
	p.Size = Vector3.new(thick, diameter, diameter)
	p.CFrame = CFrame.new(x, top - thick / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	finish(p, color, material, solid, props)
	return p
end

-- Cilindro entre dos puntos
local function seg(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?, solid: boolean?, props: Props?): Part
	local x = (b - a).Unit
	local ref = if math.abs(x.Y) < 0.95 then UP else Vector3.new(1, 0, 0)
	local z = x:Cross(ref).Unit
	local y = z:Cross(x)
	local p = newPart(parent, name, Enum.PartType.Cylinder)
	p.Size = Vector3.new((b - a).Magnitude, diameter, diameter)
	p.CFrame = CFrame.fromMatrix((a + b) / 2, x, y, z)
	finish(p, color, material or M.Wood, solid, props)
	return p
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function sparkles(parent: Instance, name: string, colors: { Color3 }, rate: number, size: number, speed: number, lifetime: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	local keys = {}
	for i, color in colors do
		table.insert(keys, ColorSequenceKeypoint.new(if #colors == 1 then 0 else (i - 1) / (#colors - 1), color))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, colors[1]))
	end
	e.Color = ColorSequence.new(keys)
	e.LightEmission = 1
	e.Rate = rate
	e.Size = NumberSequence.new(size, 0)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = parent
end

local function sign(parent: Instance, name: string, size: Vector3, cf: CFrame, text: string, textColor: Color3)
	local board = block(parent, name, size, cf, C.plank, M.WoodPlanks, true)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.94, 0.86)
	label.Position = UDim2.fromScale(0.03, 0.07)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = rgb(42, 22, 8)
	stroke.Parent = label
	label.Parent = gui
	return board
end

-- Farol de bambú (poste, farolito que brilla)
local function lantern(parent: Instance, at: Vector3, height: number?)
	local h = height or 6
	seg(parent, "LanternPost", at, at + Vector3.new(0, h, 0), 0.5, C.plankDark, M.Wood)
	local lamp = block(parent, "Lantern", Vector3.new(1.2, 1.4, 1.2), CFrame.new(at + Vector3.new(0, h + 0.6, 0)), C.lamp, M.Neon)
	block(parent, "LanternCap", Vector3.new(1.6, 0.3, 1.6), CFrame.new(at + Vector3.new(0, h + 1.45, 0)), C.straw, M.Fabric)
	light(lamp, C.lamp, 14, 1.2)
end

local function broadTree(parent: Instance, base: Vector3, height: number, spread: number)
	local m = group(parent, "JungleTree")
	seg(m, "Trunk", base - Vector3.new(0, 0.5, 0), base + Vector3.new(0, height, 0), 2.8, C.trunk, M.Wood, true)
	for k = 1, 3 do
		local angle = k * 2.1 + rng:NextNumber(-0.3, 0.3)
		local tip = base + Vector3.new(math.cos(angle) * spread * 0.35, height * 0.82, math.sin(angle) * spread * 0.35)
		seg(m, "Branch", base + Vector3.new(0, height * 0.6, 0), tip, 1.2, C.trunkDark, M.Wood)
	end
	for k = 1, 5 do
		local angle = k / 5 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = if k == 5 then 0 else spread * 0.32
		local size = spread * rng:NextNumber(0.55, 0.75)
		ball(m, "Canopy", Vector3.new(size, size * 0.45, size), base + Vector3.new(math.cos(angle) * r, height + rng:NextNumber(-1, 1.5), math.sin(angle) * r), LEAVES[rng:NextInteger(1, 3)], M.LeafyGrass)
	end
	for _ = 1, 2 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local top = base + Vector3.new(math.cos(angle) * spread * 0.4, height - 1, math.sin(angle) * spread * 0.4)
		local length = rng:NextNumber(5, 9)
		seg(m, "Liana", top, top - Vector3.new(0, length, 0), 0.25, C.leaf3, M.LeafyGrass)
		ball(m, "LianaFlower", Vector3.new(0.9, 0.9, 0.9), top - Vector3.new(0, length * 0.7, 0), FLOWERS[rng:NextInteger(1, #FLOWERS)])
	end
end

local function fern(parent: Instance, pos: Vector3, size: number?)
	local s = size or 1
	for k = 1, 5 do
		local angle = k / 5 * math.pi * 2 + rng:NextNumber(0, 0.5)
		block(parent, "Fern", Vector3.new(1 * s, 0.15, 3.4 * s), CFrame.new(pos + Vector3.new(math.cos(angle) * s, 0.7 * s, math.sin(angle) * s)) * CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.Angles(math.rad(-25), 0, 0), C.leaf1, M.Grass)
	end
end

local function monstera(parent: Instance, pos: Vector3)
	for k = 1, 5 do
		local angle = k / 5 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		block(parent, "Monstera", Vector3.new(2.8, 0.2, 3.6), CFrame.new(pos + Vector3.new(math.cos(angle) * 1.5, 1.5 + rng:NextNumber(0, 0.8), math.sin(angle) * 1.5)) * CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.Angles(math.rad(-30), 0, 0), C.leaf3, M.LeafyGrass)
	end
end

local function mushroom(parent: Instance, pos: Vector3, color: Color3)
	seg(parent, "MushroomStem", pos, pos + Vector3.new(0, 1.2, 0), 0.45, rgb(240, 235, 220), M.SmoothPlastic)
	local cap = ball(parent, "MushroomCap", Vector3.new(1.6, 0.8, 1.6), pos + Vector3.new(0, 1.3, 0), color, M.Neon)
	light(cap, color, 6, 0.6)
end

-- ===== Plaza con foso y 4 puentes =====

local function buildMoat(village: Instance)
	local moat = group(village, "Moat")
	local inner = V.PlazaRadius
	local outer = inner + V.MoatWidth
	local mid = (inner + outer) / 2
	disc(moat, "PlazaStone", inner * 2, 0.3, 0, 0, Y0 + 0.15, C.plaza, M.Slate, true)
	local count = 40
	local chord = 2 * math.pi * outer / count + 0.6
	for i = 0, count - 1 do
		local angle = (i + 0.5) / count * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local look = CFrame.lookAt(Vector3.new(), dir)
		-- Agua (no choca: se puede cruzar mojándose los pies), fondo y bordes de piedra
		block(moat, "Water", Vector3.new(chord, 0.6, V.MoatWidth), CFrame.new(dir * mid + Vector3.new(0, Y0 + 0.2, 0)) * look, C.water, M.Glass, false, { Transparency = 0.25 })
		block(moat, "MoatBed", Vector3.new(chord, 0.1, V.MoatWidth), CFrame.new(dir * mid + Vector3.new(0, Y0 + 0.05, 0)) * look, C.waterDeep, M.SmoothPlastic)
		for _, r in { inner - 0.4, outer + 0.4 } do
			block(moat, "Rim", Vector3.new(2 * math.pi * r / count + 0.2, 0.9, 1.2), CFrame.new(dir * r + Vector3.new(0, Y0 + 0.45, 0)) * look, if i % 2 == 0 then C.stone else C.stoneDark, M.Slate)
		end
		if i % 3 == 1 then
			local at = dir * (mid + rng:NextNumber(-3, 3))
			disc(moat, "LilyPad", 2.2, 0.1, at.X, at.Z, Y0 + 0.62, C.lily, M.SmoothPlastic)
			if i % 6 == 1 then
				ball(moat, "Lotus", Vector3.new(0.9, 0.6, 0.9), at + Vector3.new(0, Y0 + 0.9, 0), C.pink)
			end
		end
		if i % 5 == 2 then
			-- Pez koi nadando quieto (naranja con manchas blancas)
			local at = dir * (mid + rng:NextNumber(-2.5, 2.5)) + Vector3.new(0, Y0 + 0.3, 0)
			local fish = ball(moat, "Koi", Vector3.new(0.8, 0.6, 2), at, C.koi, M.SmoothPlastic)
			fish.CFrame = CFrame.lookAt(at, at + Vector3.new(-dir.Z, 0, dir.X))
			ball(moat, "KoiSpot", Vector3.new(0.5, 0.4, 0.7), (fish.CFrame * CFrame.new(0, 0.15, 0.2)).Position, rgb(255, 255, 255))
		end
	end
	-- 4 puentes de madera arqueados, con barandas y faroles en las puntas
	for k = 0, 3 do
		local angle = k * math.pi / 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local bridge = group(moat, `Bridge{k + 1}`)
		local from, to = inner - 3, outer + 3
		local steps = 8
		local previous: Vector3? = nil
		for s = 0, steps do
			local t = s / steps
			local point = dir * (from + (to - from) * t) + Vector3.new(0, Y0 + 0.3 + math.sin(t * math.pi) * 1.6, 0)
			if previous then
				local length = (point - previous).Magnitude + 0.15
				block(bridge, "Plank", Vector3.new(8, 0.5, length), CFrame.lookAt((point + previous) / 2, point), if s % 2 == 0 then C.plank else C.plankDark, M.WoodPlanks, true)
			end
			if s % 2 == 0 then
				for _, sx in { -1, 1 } do
					local post = point + side * sx * 4
					seg(bridge, "RailPost", post, post + Vector3.new(0, 2.6, 0), 0.4, C.plankDark, M.Wood)
				end
			end
			previous = point
		end
		for _, sx in { -1, 1 } do
			local a = dir * from + side * sx * 4 + Vector3.new(0, Y0 + 2.9, 0)
			local b = dir * to + side * sx * 4 + Vector3.new(0, Y0 + 2.9, 0)
			local midPoint = (a + b) / 2 + Vector3.new(0, 1.6, 0)
			seg(bridge, "Rail", a, midPoint, 0.35, C.rope, M.Fabric)
			seg(bridge, "Rail", midPoint, b, 0.35, C.rope, M.Fabric)
			lantern(bridge, dir * (to + 0.5) + side * sx * 5 + Vector3.new(0, Y0, 0), 5)
		end
	end
end

-- ===== Laguna con cascada (arriba a la izquierda) =====

local function buildLagoon(village: Instance)
	local lagoon = group(village, "Lagoon")
	local c = V.Lagoon
	disc(lagoon, "LagoonSand", 52, 0.3, c.X, c.Z, Y0 + 0.2, C.sand, M.Sand, true)
	disc(lagoon, "LagoonWater", 44, 0.4, c.X, c.Z, Y0 + 0.65, C.water, M.Glass, false, { Transparency = 0.2 })
	disc(lagoon, "LagoonBed", 42, 0.1, c.X, c.Z, Y0 + 0.3, C.waterDeep, M.SmoothPlastic)
	-- Acantilado con la cascada (en el borde de afuera, hacia el noroeste)
	local cliffDir = Vector3.new(-0.55, 0, -0.83).Unit
	local cliffAt = c + cliffDir * 25
	local face = CFrame.lookAt(cliffAt, c)
	block(lagoon, "Cliff", Vector3.new(26, 24, 12), face * CFrame.new(0, Y0 + 12, 0), C.stoneDark, M.Rock, true)
	block(lagoon, "CliffTop", Vector3.new(20, 8, 9), face * CFrame.new(-4, Y0 + 27, 1), C.stone, M.Slate, true)
	ball(lagoon, "CliffJungle", Vector3.new(24, 7, 14), (face * CFrame.new(0, Y0 + 31, 2)).Position, C.leaf3, M.LeafyGrass)
	for _, sx in { -12, 13 } do
		ball(lagoon, "CliffBush", Vector3.new(10, 8, 10), (face * CFrame.new(sx, Y0 + 24, 1)).Position, LEAVES[rng:NextInteger(1, 3)], M.LeafyGrass)
	end
	local fall = block(lagoon, "Waterfall", Vector3.new(7, 24, 0.8), face * CFrame.new(0, Y0 + 13, -6.4), rgb(170, 225, 255), M.Glass, false, { Transparency = 0.3 })
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Color = ColorSequence.new(C.foam)
	mist.Size = NumberSequence.new(3, 8)
	mist.Transparency = NumberSequence.new(0.5, 1)
	mist.Lifetime = NumberRange.new(1.5, 3)
	mist.Speed = NumberRange.new(2, 5)
	mist.Rate = 10
	mist.EmissionDirection = Enum.NormalId.Bottom
	mist.Parent = fall
	local foamAt = (face * CFrame.new(0, 0, -9)).Position
	disc(lagoon, "Foam", 9, 0.1, foamAt.X, foamAt.Z, Y0 + 0.75, C.foam, M.SmoothPlastic, false, { Transparency = 0.25 })
	-- Piedras para cruzar (de punta a punta, en zigzag)
	local crossDir = Vector3.new(0.83, 0, -0.55)
	for i = -3, 3 do
		local at = c + crossDir * (i * 5.2) + Vector3.new(-crossDir.Z, 0, crossDir.X) * (if i % 2 == 0 then 1.2 else -1.2)
		disc(lagoon, "SteppingStone", 3.8, 1, at.X, at.Z, Y0 + 0.95, if i % 2 == 0 then C.stone else C.stoneDark, M.Slate, true)
	end
	-- Flamencos (cuerpo, cuello en S, cabeza, pico y una pata)
	for k = 1, 3 do
		local angle = 0.6 + k * 0.9
		local at = c + Vector3.new(math.cos(angle) * 14, 0, math.sin(angle) * 14)
		local flamingo = group(lagoon, "Flamingo")
		local legTop = at + Vector3.new(0, Y0 + 3.2, 0)
		seg(flamingo, "Leg", at + Vector3.new(0, Y0 + 0.5, 0), legTop, 0.2, C.pink, M.SmoothPlastic)
		ball(flamingo, "Body", Vector3.new(1.6, 1.4, 2.6), legTop + Vector3.new(0, 0.7, 0), C.pink)
		local neckBase = legTop + Vector3.new(0, 1, -1)
		local neckMid = neckBase + Vector3.new(0, 1.3, -0.3)
		local head = neckMid + Vector3.new(0, 1.1, 0.3)
		seg(flamingo, "Neck", neckBase, neckMid, 0.35, C.pink, M.SmoothPlastic)
		seg(flamingo, "Neck", neckMid, head, 0.35, C.pink, M.SmoothPlastic)
		ball(flamingo, "Head", Vector3.new(0.7, 0.7, 0.7), head, C.pink)
		seg(flamingo, "Beak", head, head + Vector3.new(0, -0.3, -0.8), 0.25, rgb(40, 30, 30), M.SmoothPlastic)
		flamingo:PivotTo(CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.new(-at))
	end
	-- Juncos, nenúfares, bancos y mariposas
	for k = 1, 14 do
		local angle = k / 14 * math.pi * 2
		local at = c + Vector3.new(math.cos(angle) * 22.5, 0, math.sin(angle) * 22.5)
		seg(lagoon, "Reed", at + Vector3.new(0, Y0, 0), at + Vector3.new(0, Y0 + rng:NextNumber(2.5, 4.5), 0), 0.3, C.leaf3, M.Grass)
		if k % 2 == 0 then
			local pad = c + Vector3.new(math.cos(angle + 0.2) * 15, 0, math.sin(angle + 0.2) * 15)
			disc(lagoon, "LilyPad", 2.4, 0.1, pad.X, pad.Z, Y0 + 0.75, C.lily, M.SmoothPlastic)
		end
	end
	for _, angle in { 0.3, 2.2 } do
		local at = c + Vector3.new(math.cos(angle) * 28, 0, math.sin(angle) * 28)
		local bench = group(lagoon, "Bench")
		local cf = CFrame.lookAt(at + Vector3.new(0, Y0, 0), c + Vector3.new(0, Y0, 0))
		block(bench, "Seat", Vector3.new(6, 0.5, 2), cf * CFrame.new(0, 1.6, 0), C.plank, M.WoodPlanks, true)
		block(bench, "Back", Vector3.new(6, 1.6, 0.4), cf * CFrame.new(0, 2.6, 1), C.plank, M.WoodPlanks)
		for _, x in { -2.5, 2.5 } do
			block(bench, "Leg", Vector3.new(0.5, 1.4, 1.6), cf * CFrame.new(x, 0.7, 0), C.plankDark, M.Wood)
		end
	end
	local butterflies = block(lagoon, "Butterflies", Vector3.new(30, 6, 30), CFrame.new(c + Vector3.new(0, Y0 + 4, 0)), C.water, M.SmoothPlastic, false, { Transparency = 1 })
	sparkles(butterflies, "Butterflies", { rgb(255, 120, 200), rgb(255, 212, 59), rgb(120, 200, 255) }, 4, 0.6, 1.5, 6)
end

-- ===== Árbol gigante con la casita (abajo a la izquierda) =====

local function buildGiantTree(village: Instance)
	local tree = group(village, "GiantTree")
	local c = V.GiantTree
	local base = c + Vector3.new(0, Y0, 0)
	local platformTop = Y0 + 22
	seg(tree, "Trunk", base - Vector3.new(0, 1, 0), base + Vector3.new(0, 44, 0), 9, C.trunk, M.Wood, true)
	-- Raíces que salen para los costados
	for k = 1, 6 do
		local angle = k / 6 * math.pi * 2 + 0.3
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		seg(tree, "Root", base + dir * 3 + Vector3.new(0, 4, 0), base + dir * 9 + Vector3.new(0, -0.5, 0), 2.4, C.trunkDark, M.Wood, true)
	end
	-- Ramas y copa enorme
	for k = 1, 5 do
		local angle = k / 5 * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tip = base + dir * 18 + Vector3.new(0, 40, 0)
		seg(tree, "Branch", base + Vector3.new(0, 32, 0), tip, 2.4, C.trunkDark, M.Wood)
		ball(tree, "Canopy", Vector3.new(22, 11, 22), tip + Vector3.new(0, 3, 0), LEAVES[k % 3 + 1], M.LeafyGrass)
		-- Liana con un farol colgando
		local hang = tip - Vector3.new(0, 1, 0)
		local length = rng:NextNumber(10, 15)
		seg(tree, "Liana", hang, hang - Vector3.new(0, length, 0), 0.3, C.leaf3, M.LeafyGrass)
		if k % 2 == 1 then
			local lamp = block(tree, "HangingLantern", Vector3.new(1.2, 1.5, 1.2), CFrame.new(hang - Vector3.new(0, length + 0.8, 0)), C.lamp, M.Neon)
			light(lamp, C.lamp, 14, 1.2)
		end
	end
	ball(tree, "CanopyTop", Vector3.new(30, 14, 30), base + Vector3.new(0, 48, 0), C.leaf1, M.LeafyGrass)
	-- Plataforma redonda con baranda y la casita de paja
	disc(tree, "Platform", 32, 1, c.X, c.Z, platformTop, C.plank, M.WoodPlanks, true)
	for k = 0, 11 do
		local angle = k / 12 * math.pi * 2
		local at = Vector3.new(c.X + math.cos(angle) * 15.5, platformTop, c.Z + math.sin(angle) * 15.5)
		seg(tree, "RailPost", at, at + Vector3.new(0, 3, 0), 0.4, C.plankDark, M.Wood)
		local nextAt = Vector3.new(c.X + math.cos(angle + math.pi / 6) * 15.5, platformTop, c.Z + math.sin(angle + math.pi / 6) * 15.5)
		if k ~= 0 and k ~= 11 then -- (por el lado de la escalera queda abierto)
			seg(tree, "Rail", at + Vector3.new(0, 3, 0), nextAt + Vector3.new(0, 3, 0), 0.3, C.rope, M.Fabric)
		end
	end
	local hut = group(tree, "TreeHouse")
	-- (del lado de afuera del tronco, con la puerta mirando hacia la plaza)
	local hutAt = Vector3.new(c.X - 1, platformTop, c.Z - 10)
	block(hut, "Walls", Vector3.new(9, 6, 7), CFrame.new(hutAt + Vector3.new(0, 3, 0)), C.strawDark, M.Fabric, true)
	block(hut, "Door", Vector3.new(2.6, 4, 0.3), CFrame.new(hutAt + Vector3.new(4.6, 2, 0)) * CFrame.Angles(0, math.rad(90), 0), C.plankDark, M.Wood)
	block(hut, "Window", Vector3.new(2, 1.6, 0.3), CFrame.new(hutAt + Vector3.new(-1.5, 3.6, -3.6)), C.lamp, M.Neon)
	for _, side in { -1, 1 } do
		local roof = Instance.new("WedgePart")
		roof.Name = "Roof"
		roof.Anchored = true
		roof.Size = Vector3.new(11, 3.5, 4.5)
		roof.CFrame = CFrame.new(hutAt + Vector3.new(0, 7.75, side * 2.25)) * CFrame.Angles(0, if side < 0 then 0 else math.pi, 0)
		roof.Color = C.straw
		roof.Material = M.Fabric
		roof.Parent = hut
	end
	-- Escalera de soga (TrussPart: se puede trepar)
	local ladderAt = Vector3.new(c.X + 16.5, 0, c.Z)
	local ladder = Instance.new("TrussPart")
	ladder.Name = "RopeLadder"
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, platformTop - Y0 + 2, 2)
	ladder.CFrame = CFrame.new(ladderAt.X, Y0 + (platformTop - Y0 + 2) / 2, ladderAt.Z)
	ladder.Color = C.rope
	ladder.Material = M.Fabric
	ladder.Parent = tree
	sign(tree, "LadderSign", Vector3.new(5, 1.6, 0.3), CFrame.lookAt(ladderAt + Vector3.new(2.2, Y0 + 4, 0), ladderAt + Vector3.new(10, Y0 + 4, 0)), "CLIMB ↑", rgb(255, 231, 176))
	-- Columpio colgando de una rama baja
	local swingTop = base + Vector3.new(-12, 16, 6)
	seg(tree, "SwingBranch", base + Vector3.new(-3, 15, 2), swingTop + Vector3.new(-2, 0.5, 0.5), 1.6, C.trunkDark, M.Wood)
	for _, dz in { -1.2, 1.2 } do
		seg(tree, "SwingRope", swingTop + Vector3.new(0, 0, dz), swingTop + Vector3.new(0, -13, dz), 0.2, C.rope, M.Fabric)
	end
	block(tree, "SwingSeat", Vector3.new(1.4, 0.3, 3), CFrame.new(swingTop + Vector3.new(0, -13, 0)), C.plank, M.WoodPlanks)
	-- Hongos que brillan y luciérnagas
	for k = 1, 7 do
		local angle = k / 7 * math.pi * 2 + 0.5
		mushroom(tree, base + Vector3.new(math.cos(angle) * rng:NextNumber(7, 13), 0, math.sin(angle) * rng:NextNumber(7, 13)), if k % 2 == 0 then rgb(120, 230, 255) else rgb(255, 120, 200))
	end
	local fireflies = block(tree, "Fireflies", Vector3.new(36, 14, 36), CFrame.new(base + Vector3.new(0, 10, 0)), C.lamp, M.SmoothPlastic, false, { Transparency = 1 })
	sparkles(fireflies, "Fireflies", { rgb(255, 240, 120) }, 10, 0.35, 0.8, 5)
end

-- ===== Fogón tiki con escenario (arriba a la derecha) =====

local function buildFirePit(village: Instance)
	local camp = group(village, "FirePit")
	local c = V.FirePit
	local stageZ = c.Z - 22
	-- Fogata: aro de piedras, leña y fuego con chispas
	for k = 0, 9 do
		local angle = k / 10 * math.pi * 2
		ball(camp, "PitStone", Vector3.new(2, 1.4, 2), Vector3.new(c.X + math.cos(angle) * 3.6, Y0 + 0.6, c.Z + math.sin(angle) * 3.6), if k % 2 == 0 then C.stone else C.stoneDark, M.Slate)
	end
	for k = 0, 2 do
		local angle = k / 3 * math.pi
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local center = Vector3.new(c.X, Y0 + 0.7, c.Z)
		seg(camp, "Firewood", center - dir * 2.4, center + dir * 2.4, 0.9, C.trunkDark, M.Wood)
	end
	local flame = block(camp, "Bonfire", Vector3.new(3, 2, 3), CFrame.new(c.X, Y0 + 2, c.Z), rgb(255, 138, 31), M.Neon, false, { Transparency = 0.6 })
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Heat = 12
	fire.Color = rgb(255, 138, 31)
	fire.SecondaryColor = rgb(255, 226, 122)
	fire.Parent = flame
	sparkles(flame, "Sparks", { rgb(255, 200, 80), rgb(255, 120, 40) }, 12, 0.4, 7, 2)
	light(flame, rgb(255, 150, 60), 30, 3)
	-- 3 filas de troncos en semicírculo, mirando al escenario
	for row, radius in { 9, 13, 17 } do
		for k = 0, 3 + row do
			local t = k / (3 + row)
			local angle = math.rad(25 + t * 130) -- del lado de abajo (sur) de la fogata
			local at = Vector3.new(c.X + math.cos(angle) * radius, Y0, c.Z + math.sin(angle) * radius)
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			seg(camp, "LogSeat", at - tangent * 1.6 + Vector3.new(0, 0.8, 0), at + tangent * 1.6 + Vector3.new(0, 0.8, 0), 1.6, if (k + row) % 2 == 0 then C.trunk else C.trunkDark, M.Wood, true)
		end
	end
	-- Escenario: tarima, máscara tiki gigante atrás y tambores
	local stage = group(camp, "Stage")
	block(stage, "StageFloor", Vector3.new(26, 1.6, 12), CFrame.new(c.X, Y0 + 0.8, stageZ), C.plank, M.WoodPlanks, true)
	block(stage, "StageStep", Vector3.new(8, 0.8, 2), CFrame.new(c.X, Y0 + 0.4, stageZ + 7), C.plankDark, M.WoodPlanks, true)
	local mask = block(stage, "GiantMask", Vector3.new(12, 17, 2), CFrame.new(c.X, Y0 + 10, stageZ - 5.5), C.mask, M.Wood, true)
	for _, ex in { -2.6, 2.6 } do
		block(stage, "MaskEye", Vector3.new(2.4, 1.8, 0.4), CFrame.new(c.X + ex, Y0 + 13.5, stageZ - 4.4), C.gold, M.Neon)
	end
	block(stage, "MaskNose", Vector3.new(1.6, 3, 0.8), CFrame.new(c.X, Y0 + 11, stageZ - 4.2), rgb(130, 64, 34), M.Wood)
	block(stage, "MaskMouth", Vector3.new(6, 1.6, 0.4), CFrame.new(c.X, Y0 + 7.8, stageZ - 4.4), rgb(60, 30, 14), M.Wood)
	for k = 0, 4 do
		block(stage, "MaskTeeth", Vector3.new(0.8, 0.8, 0.2), CFrame.new(c.X - 2.4 + k * 1.2, Y0 + 8.2, stageZ - 4.15), rgb(255, 245, 225), M.SmoothPlastic)
	end
	for k = 0, 6 do
		local angle = math.rad(-90 + (k - 3) * 22)
		local tip = Vector3.new(c.X + math.cos(angle) * 9.5, Y0 + 15 + math.sin(-angle) * 9.5, stageZ - 5.6)
		seg(stage, "Feather", Vector3.new(c.X, Y0 + 15, stageZ - 5.6), tip, 1.1, FLOWERS[k % #FLOWERS + 1], M.SmoothPlastic)
	end
	light(mask, C.gold, 18, 1)
	for k, x in { -9, -6.5, 7.5 } do
		local drum = group(stage, "Drum")
		local h = if k == 2 then 2.4 else 3.2
		local d = if k == 2 then 2.2 else 3
		seg(drum, "DrumBody", Vector3.new(c.X + x, Y0 + 1.6, stageZ + 1), Vector3.new(c.X + x, Y0 + 1.6 + h, stageZ + 1), d, C.mask, M.Wood)
		disc(drum, "DrumSkin", d - 0.2, 0.1, c.X + x, stageZ + 1, Y0 + 1.65 + h, rgb(240, 220, 180), M.Fabric)
	end
	for _, x in { -13.5, 13.5 } do
		lantern(stage, Vector3.new(c.X + x, Y0, stageZ + 6.5), 8)
	end
end

-- ===== Jardín de los 6 huevos gigantes (abajo a la derecha) =====

local function buildEggGarden(village: Instance)
	local garden = group(village, "EggGarden")
	local c = V.EggGarden
	disc(garden, "GardenGrass", 58, 0.2, c.X, c.Z, Y0 + 0.1, rgb(96, 180, 70), M.Grass, true)
	local spots = {
		Vector3.new(-17, 0, -8), Vector3.new(0, 0, -11), Vector3.new(17, 0, -8),
		Vector3.new(-17, 0, 10), Vector3.new(0, 0, 13), Vector3.new(17, 0, 10),
	}
	for i, rarity in Config.Rarities do
		local offset = spots[i]
		if not offset then
			break
		end
		local at = c + offset
		local nest = group(garden, `{rarity.Id}Nest`)
		nest:SetAttribute("RarityId", rarity.Id)
		disc(nest, "NestStraw", 9, 1.6, at.X, at.Z, Y0 + 1.6, C.strawDark, M.Fabric, true)
		for k = 0, 11 do
			local angle = k / 12 * math.pi * 2
			block(nest, "NestRim", Vector3.new(2.4, 1.2, 1), CFrame.new(at.X + math.cos(angle) * 4.2, Y0 + 2, at.Z + math.sin(angle) * 4.2) * CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.Angles(math.rad(-25), 0, 0), if k % 2 == 0 then C.straw else C.strawDark, M.Fabric)
		end
		local rank = Config.RarityRank(rarity.Id)
		local glows = rank >= Config.RarityRank("Legendary")
		local egg = newPart(nest, "GiantEgg")
		egg.Size = Vector3.new(6, 8, 6)
		egg.CFrame = CFrame.new(at.X, Y0 + 5.6, at.Z)
		finish(egg, rarity.Color, if glows then M.Neon else M.SmoothPlastic, true)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = egg
		egg:SetAttribute("Spin", if glows then 12 else 0)
		egg:SetAttribute("Bob", if glows then 0.3 else 0)
		if glows then
			CollectionService:AddTag(egg, "Spinning")
			light(egg, rarity.Color, 18, 2)
			sparkles(egg, "Sparkles", { rarity.Color, rgb(255, 255, 255) }, 6, 0.5, 2, 2)
		end
		-- Cartelito adelante (mirando hacia la plaza)
		local signAt = at + Vector3.new(-6, Y0 + 1.5, 0)
		seg(nest, "SignPost", Vector3.new(signAt.X, Y0, signAt.Z), signAt, 0.4, C.plankDark, M.Wood)
		sign(nest, "RaritySign", Vector3.new(5, 1.6, 0.3), CFrame.lookAt(signAt + Vector3.new(0, 0.9, 0), signAt + Vector3.new(-10, 0.9, 0)), rarity.DisplayName:upper(), rarity.Color)
	end
	-- Flores gigantes alrededor
	for k = 1, 8 do
		local angle = k / 8 * math.pi * 2 + 0.2
		local at = c + Vector3.new(math.cos(angle) * 26, Y0, math.sin(angle) * 26)
		if math.cos(angle) > -0.75 then -- (del lado de la plaza va el arco)
			local flower = group(garden, "GiantFlower")
			local height = rng:NextNumber(5, 8)
			seg(flower, "Stem", at, at + Vector3.new(0, height, 0), 0.5, C.leaf3, M.SmoothPlastic)
			block(flower, "Leaf", Vector3.new(1.4, 0.2, 3), CFrame.new(at + Vector3.new(0.9, height * 0.4, 0)) * CFrame.Angles(0, 0, math.rad(-30)), C.leaf1, M.SmoothPlastic)
			local color = FLOWERS[k % #FLOWERS + 1]
			for petal = 0, 5 do
				local a = petal / 6 * math.pi * 2
				ball(flower, "Petal", Vector3.new(2.2, 0.5, 2.2), at + Vector3.new(math.cos(a) * 1.4, height, math.sin(a) * 1.4), color)
			end
			ball(flower, "Center", Vector3.new(1.4, 0.8, 1.4), at + Vector3.new(0, height + 0.2, 0), C.gold)
		end
	end
	-- Arco de flores en la entrada (del lado de la plaza)
	local arch = group(garden, "FlowerArch")
	local archX = c.X - 28
	for k = 0, 12 do
		local t = k / 12
		local angle = t * math.pi
		local at = Vector3.new(archX, Y0 + math.sin(angle) * 11, c.Z + math.cos(angle) * 7)
		ball(arch, "ArchFlower", Vector3.new(1.6, 1.6, 1.6), at, FLOWERS[k % #FLOWERS + 1])
		if k < 12 then
			local nextAngle = (k + 1) / 12 * math.pi
			seg(arch, "ArchVine", at, Vector3.new(archX, Y0 + math.sin(nextAngle) * 11, c.Z + math.cos(nextAngle) * 7), 0.6, C.leaf3, M.LeafyGrass)
		end
	end
	sign(arch, "GardenSign", Vector3.new(10, 2, 0.4), CFrame.lookAt(Vector3.new(archX - 0.4, Y0 + 12.5, c.Z), Vector3.new(archX - 10, Y0 + 12.5, c.Z)), "EGG GARDEN", C.gold)
end

-- ===== Pasarela de madera hasta cada hábitat =====

local function walkway(parent: Instance, a: Vector3, b: Vector3, width: number)
	local length = (b - a).Magnitude
	local dir = (b - a).Unit
	local count = math.max(1, math.floor(length / 4))
	for i = 0, count - 1 do
		local t0, t1 = i / count, (i + 1) / count
		local p0, p1 = a + (b - a) * t0, a + (b - a) * t1
		block(parent, "Plank", Vector3.new(width, 0.4, (p1 - p0).Magnitude - 0.15), CFrame.lookAt((p0 + p1) / 2 + Vector3.new(0, Y0 + 0.3, 0), (p0 + p1) / 2 + dir + Vector3.new(0, Y0 + 0.3, 0)), if i % 2 == 0 then C.plank else C.plankDark, M.WoodPlanks, true)
	end
end

local function buildBoardwalk(village: Instance)
	local boardwalk = group(village, "Boardwalk")
	local start = V.PlazaRadius + V.MoatWidth + 3
	for _, side in { -1, 1 } do
		local z = side * V.BoardwalkZ
		-- De la punta del puente norte/sur hasta la pasarela de los hábitats
		walkway(boardwalk, Vector3.new(0, 0, side * start), Vector3.new(0, 0, z - side * 4), 8)
		-- La pasarela larga por delante de los hábitats
		walkway(boardwalk, Vector3.new(-146, 0, z), Vector3.new(146, 0, z), 8)
		for x = -140, 140, 35 do
			lantern(boardwalk, Vector3.new(x, Y0, z - side * 5), 6)
		end
	end
	-- Un tramo cortito hasta la entrada de cada hábitat
	for index, position in Config.Map.BasePositions do
		local side = if position.Z < 0 then -1 else 1
		local from = Vector3.new(position.X, 0, side * (V.BoardwalkZ + 4))
		local to = Vector3.new(position.X, 0, position.Z - side * 30)
		local spur = group(boardwalk, `Spur{index}`)
		walkway(spur, from, to, 6)
	end
	-- Caminito de tierra del puente oeste a la laguna y al árbol gigante
	local path = group(village, "DirtPath")
	local west = Vector3.new(-(V.PlazaRadius + V.MoatWidth + 4), 0, 0)
	for _, target in { V.Lagoon + Vector3.new(26, 0, 14), V.GiantTree + Vector3.new(24, 0, -14) } do
		for i = 0, 8 do
			local at = west:Lerp(target, i / 8)
			disc(path, "PathDirt", 5, 0.1, at.X, at.Z, Y0 + 0.12, C.dirt, M.Ground)
		end
	end
end

-- ===== Selva entre los hábitats =====

local function buildJungle(village: Instance)
	local jungle = group(village, "Jungle")
	for _, side in { -1, 1 } do
		-- Árboles de hojas anchas entre un hábitat y otro, y en las puntas
		for _, x in { -150, -75, 0, 75, 150 } do
			broadTree(jungle, Vector3.new(x, Y0, side * (if math.abs(x) == 150 then 160 else 140)), rng:NextNumber(18, 24), rng:NextNumber(14, 18))
			broadTree(jungle, Vector3.new(x + rng:NextNumber(-4, 4), Y0, side * 202), rng:NextNumber(20, 26), rng:NextNumber(15, 19))
		end
		-- Helechos y monsteras al borde de la pasarela (sin tapar las entradas)
		for x = -145, 145, 14.5 do
			local nearEntrance = false
			for _, position in Config.Map.BasePositions do
				if math.abs(position.X - x) < 9 then
					nearEntrance = true
				end
			end
			if not nearEntrance then
				local at = Vector3.new(x + rng:NextNumber(-2, 2), Y0, side * (V.BoardwalkZ + 7))
				if rng:NextNumber() < 0.5 then
					fern(jungle, at, rng:NextNumber(1, 1.4))
				else
					monstera(jungle, at)
				end
			end
		end
		-- Luciérnagas sobre la selva
		local fireflies = block(jungle, "Fireflies", Vector3.new(300, 12, 20), CFrame.new(0, Y0 + 8, side * 140), C.lamp, M.SmoothPlastic, false, { Transparency = 1 })
		sparkles(fireflies, "Fireflies", { rgb(255, 240, 120) }, 14, 0.35, 0.8, 5)
	end
	-- Algunas plantas en el pasto del lobby
	for _, at in { Vector3.new(-60, 0, -20), Vector3.new(-62, 0, 24), Vector3.new(55, 0, -24), Vector3.new(58, 0, 22), Vector3.new(-140, 0, 0), Vector3.new(140, 0, -40), Vector3.new(140, 0, 40) } do
		fern(jungle, at + Vector3.new(0, Y0, 0), 1.3)
	end
end

-- Arma toda la aldea adentro de "lobby"
function VillageBuilder.Build(lobby: Instance)
	rng = Random.new(2024)
	local village = Instance.new("Folder")
	village.Name = "Village"
	buildMoat(village)
	buildLagoon(village)
	buildGiantTree(village)
	buildFirePit(village)
	buildEggGarden(village)
	buildBoardwalk(village)
	buildJungle(village)
	village.Parent = lobby
	return village
end

return VillageBuilder

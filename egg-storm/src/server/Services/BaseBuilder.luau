--!strict
-- BaseBuilder: arma cada base de jugador como una CHOZA TIKI DE 3 PISOS muy decorada (Base v2, ~1000 piezas).
--   * plataforma de piedra, postes de bambú con anillos y cuerdas, pisos de tablones, pared tejida, barandas
--   * 2 escaleras exteriores de bambú (piso 1→2 y 2→3)
--   * techo de paja de 3 capas con flecos, frontones, cumbrera con adornos tiki, bandera y guirnalda de luces
--   * máscaras tiki, faroles, enredaderas con flores, macetas, alfombra y baúl
--   * 15 estantes con su lamparita y paredes de vidrio (Locks) en los pisos 2 y 3
--   * patio de arena con 3 nidos rodeados de piedras, caminito, arco con el nombre del dueño, cerco,
--     hamaca entre palmeras, reposera, cocos, barril, cajas, tablas de surf, arbustos y flores
--   * cartel "BIGGER TOWER" que muestra qué renacimiento abre cada piso (abre la ventana de Rebirth)
--
-- Lo que usan los servicios del juego (no cambiar los nombres):
--   Plot (PrimaryPart, mira al lobby), CreatureSlots (Shelf_<piso>_<n> con SlotIndex/Floor/Unlocked),
--   Locks (LockBarrier2/3 con atributo Floor), IncubatorSlots (Nest1-3 con Pedestal + SlotIndex),
--   SignLabel (nombre del dueño), SpawnPoint, SafeZone y FloorShop.
--
-- Coordenadas: las piezas se escriben como en el diseño (BaseBuilder.lua de Claude Design), donde +Z es el frente.
-- Por eso por dentro se usa la base girada 180° (en el resto del juego el frente de la base es -Z).
-- Vista desde el frente queda igual que en el diseño: escalera grande a la derecha, hamaca a la izquierda.

local CollectionService = game:GetService("CollectionService")

local BaseBuilder = {}

local M = Enum.Material

local function rgb(hex: string): Color3
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16) or 0, tonumber(hex:sub(3, 4), 16) or 0, tonumber(hex:sub(5, 6), 16) or 0)
end

-- Alturas de la cara de arriba de cada piso (las usa también la prueba de la torre)
BaseBuilder.FloorTops = { 2, 14, 26 }
BaseBuilder.ShelfOn = rgb("E3B65A")
BaseBuilder.ShelfOff = rgb("5B4AB8")

local C = {
	grass = rgb("5DB33D"), sand = rgb("F2D49B"),
	stone = rgb("8E857A"), stoneDark = rgb("6E665D"), stoneLight = rgb("B8B0A3"),
	wood = rgb("8B5A2B"), woodDark = rgb("5A3418"), woodMid = rgb("7A4A1E"), woodLight = rgb("A0662E"),
	bamboo = rgb("C9A24A"), bambooDark = rgb("8A6A1E"), rope = rgb("5A3A1A"),
	thatch1 = rgb("D9A441"), thatch2 = rgb("C48A2C"), thatch3 = rgb("E8BC5E"),
	weave = rgb("E9C98A"), leaf1 = rgb("2E9E44"), leaf2 = rgb("3F9A48"), leaf3 = rgb("4FAE52"),
	glass = rgb("7FD6E8"), lavaGlow = rgb("FF8A1F"), lampYellow = rgb("FFD43B"), paper = rgb("FFF1D0"),
	maskWood = rgb("A0522D"), white = rgb("FFFFFF"), red = rgb("E53935"), cyan = rgb("3FD8F0"),
	pink = rgb("FF4F8B"), dark = rgb("2A1608"), black = rgb("1A1A1A"),
}
local LIGHTS = { rgb("FF4F8B"), rgb("FFD43B"), rgb("3FD8F0"), rgb("6CFF4D"), rgb("FF8A1F"), rgb("B26BFF") }
local LEAVES = { C.leaf1, C.leaf2, C.leaf3 }
local FLOWERS = { rgb("FF4F8B"), rgb("FFD43B"), rgb("B26BFF"), rgb("FFFFFF") }

local SHELF_X = { -16, -8, 0, 8, 16 }
local NEST_X = { -14, 0, 14 }
local UP = Vector3.new(0, 1, 0)

type Props = { [string]: any }

-- Estado de la base que se está armando
local B: CFrame = CFrame.new()
local rng = Random.new(11)

-- ===== Ayudantes (posiciones en coordenadas locales del diseño) =====

local function W(v: Vector3): Vector3
	return B:PointToWorldSpace(v)
end

-- CFrame en el mundo de una pieza ubicada en "pos" (coordenadas del diseño) con una rotación opcional
local function at(pos: Vector3, rot: CFrame?): CFrame
	return B * CFrame.new(pos) * (rot or CFrame.new())
end

local function apply(p: BasePart, props: Props?)
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
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

-- Decoración: no choca, no proyecta sombra
local function deco(extra: Props?): Props
	local props: Props = extra or {}
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	return props
end

local function block(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, rot: CFrame?, props: Props?): Part
	local p = newPart(parent, name)
	p.Size = size
	p.CFrame = at(pos, rot)
	p.Color = color
	p.Material = material or M.SmoothPlastic
	apply(p, props)
	return p
end

local function ball(parent: Instance, name: string, diameter: number, pos: Vector3, color: Color3, material: Enum.Material?, props: Props?): Part
	local p = newPart(parent, name, Enum.PartType.Ball)
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.CFrame = at(pos)
	p.Color = color
	p.Material = material or M.SmoothPlastic
	apply(p, props)
	return p
end

-- Cilindro entre dos puntos (el eje de los cilindros de Roblox es X)
local function seg(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?, props: Props?): Part
	local wa, wb = W(a), W(b)
	local len = (wb - wa).Magnitude
	local x = (wb - wa).Unit
	local ref = if math.abs(x.Y) < 0.95 then UP else B.RightVector
	local z = x:Cross(ref).Unit
	local y = z:Cross(x)
	local p = newPart(parent, name, Enum.PartType.Cylinder)
	p.Size = Vector3.new(len, diameter, diameter)
	p.CFrame = CFrame.fromMatrix((wa + wb) / 2, x, y, z)
	p.Color = color
	p.Material = material or M.Wood
	apply(p, props)
	return p
end

local function vcyl(parent: Instance, name: string, x: number, z: number, y0: number, y1: number, diameter: number, color: Color3, material: Enum.Material?, props: Props?): Part
	return seg(parent, name, Vector3.new(x, y0, z), Vector3.new(x, y1, z), diameter, color, material, props)
end

-- Losa entre dos puntos (largo en Z, ancho en X)
local function slab(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, thick: number, color: Color3, material: Enum.Material?, props: Props?): Part
	local wa, wb = W(a), W(b)
	local len = (wb - wa).Magnitude
	local look = (wb - wa).Unit
	local right = look:Cross(B.UpVector)
	if right.Magnitude < 0.05 then
		right = look:Cross(B.LookVector)
	end
	right = right.Unit
	local up = right:Cross(look)
	local p = newPart(parent, name)
	p.Size = Vector3.new(width, thick, len)
	p.CFrame = CFrame.fromMatrix((wa + wb) / 2, right, up, -look)
	p.Color = color
	p.Material = material or M.SmoothPlastic
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

-- Texto sobre una cara de una pieza. (En el diseño el frente es +Z: la cara que mira ahí es "Back".)
local function label(target: BasePart, face: Enum.NormalId, text: string, color: Color3, pixelsPerStud: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 50
	gui.LightInfluence = 0
	gui.Parent = target
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = C.dark
	stroke.Parent = t
	t.Parent = gui
	return t
end

local FRONT = Enum.NormalId.Back -- la cara que mira al frente de la base (al lobby)

-- ===== Props =====

local function palm(parent: Instance, x: number, z: number, height: number): Vector3
	local m = group(parent, "Palm")
	local count = 6
	local length = height / count
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
	local current = Vector3.new(x, 0, z)
	for i = 0, count - 1 do
		local dir = (UP + lean * (0.07 * i)).Unit
		local nextPoint = current + dir * length
		seg(m, "Trunk", current, nextPoint + dir * 0.3, 2.2 - i * 0.12, if i % 2 == 0 then C.wood else C.woodMid, M.Wood)
		current = nextPoint
	end
	for k = 1, 8 do
		local angle = (k / 8) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local droop = math.rad(rng:NextNumber(20, 38))
		local dir = Vector3.new(math.cos(angle) * math.cos(droop), -math.sin(droop), math.sin(angle) * math.cos(droop))
		slab(m, "Leaf", current, current + dir * 11, 3, 0.35, LEAVES[rng:NextInteger(1, 3)], M.LeafyGrass, deco())
	end
	for k = 1, 3 do
		ball(m, "Coconut", 1.4, current + Vector3.new(math.cos(k * 2.1) * 0.9, -1, math.sin(k * 2.1) * 0.9), rgb("6E461E"), M.SmoothPlastic, deco())
	end
	return current
end

local function bush(parent: Instance, x: number, z: number, size: number, flowers: Color3?, yBase: number?)
	local y0 = yBase or 0
	local m = group(parent, "Bush")
	for _ = 1, 3 do
		local s = size * rng:NextNumber(0.7, 1.05)
		local p = ball(m, "Leaves", s, Vector3.new(x + rng:NextNumber(-size / 3, size / 3), y0 + s * 0.3, z + rng:NextNumber(-size / 3, size / 3)), LEAVES[rng:NextInteger(1, 3)], M.LeafyGrass, deco())
		p.Size = Vector3.new(s, s * 0.75, s)
	end
	if flowers then
		for _ = 1, 5 do
			ball(m, "Flower", 0.9, Vector3.new(x + rng:NextNumber(-size / 2, size / 2), y0 + size * 0.6, z + rng:NextNumber(-size / 2, size / 2)), flowers, M.SmoothPlastic, deco())
		end
	end
end

local function rock(parent: Instance, x: number, z: number, size: number)
	block(parent, "Rock", Vector3.new(size, size * 0.6, size * 0.85), Vector3.new(x, size * 0.2, z), C.stone, M.Slate, CFrame.Angles(rng:NextNumber(0, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(0, 0.5)), deco())
end

local function tikiTorch(parent: Instance, x: number, z: number, height: number?)
	local h = height or 7
	local m = group(parent, "TikiTorch")
	vcyl(m, "Pole", x, z, 0, h, 0.8, C.woodMid, M.Wood)
	vcyl(m, "Basket", x, z, h - 0.2, h + 1.4, 2, C.bamboo, M.Wood)
	local core = ball(m, "Flame", 1, Vector3.new(x, h + 1.8, z), C.lavaGlow, M.Neon, deco({ Transparency = 0.3 }))
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = C.lavaGlow
	fire.SecondaryColor = C.lampYellow
	fire.Parent = core
	light(core, C.lavaGlow, 14, 2)
end

local function lantern(parent: Instance, pos: Vector3)
	local m = group(parent, "Lantern")
	block(m, "Cap", Vector3.new(1.6, 0.4, 1.6), pos + Vector3.new(0, 1, 0), C.woodDark, M.Wood, nil, deco())
	local glass = block(m, "Glow", Vector3.new(1.2, 1.6, 1.2), pos, C.lampYellow, M.Neon, nil, deco({ Transparency = 0.15 }))
	block(m, "Bottom", Vector3.new(1.6, 0.3, 1.6), pos - Vector3.new(0, 0.95, 0), C.woodDark, M.Wood, nil, deco())
	seg(m, "Rope", pos + Vector3.new(0, 1.2, 0), pos + Vector3.new(0, 2.6, 0), 0.15, C.rope, M.Fabric, deco())
	light(glass, C.lampYellow, 12, 1.6)
end

local function tikiMask(parent: Instance, pos: Vector3)
	local m = group(parent, "TikiMask")
	block(m, "Face", Vector3.new(3, 4.2, 0.6), pos, C.maskWood, M.Wood)
	block(m, "Brow", Vector3.new(3.2, 0.5, 0.3), pos + Vector3.new(0, 1.1, 0.4), C.woodDark, M.Wood, nil, deco())
	block(m, "EyeL", Vector3.new(0.7, 0.5, 0.2), pos + Vector3.new(-0.7, 0.6, 0.4), C.lampYellow, M.Neon, nil, deco())
	block(m, "EyeR", Vector3.new(0.7, 0.5, 0.2), pos + Vector3.new(0.7, 0.6, 0.4), C.lampYellow, M.Neon, nil, deco())
	block(m, "Mouth", Vector3.new(1.8, 0.6, 0.2), pos + Vector3.new(0, -0.9, 0.4), C.woodDark, M.Wood, nil, deco())
	for i = -2, 2 do
		block(m, "Tooth", Vector3.new(0.25, 0.35, 0.22), pos + Vector3.new(i * 0.35, -0.75, 0.45), C.white, M.SmoothPlastic, nil, deco())
	end
	block(m, "Feather1", Vector3.new(0.5, 1.6, 0.2), pos + Vector3.new(-0.9, 2.6, 0), C.red, M.Fabric, CFrame.Angles(0, 0, 0.3), deco())
	block(m, "Feather2", Vector3.new(0.5, 1.9, 0.2), pos + Vector3.new(0, 2.8, 0), C.lampYellow, M.Fabric, nil, deco())
	block(m, "Feather3", Vector3.new(0.5, 1.6, 0.2), pos + Vector3.new(0.9, 2.6, 0), C.cyan, M.Fabric, CFrame.Angles(0, 0, -0.3), deco())
end

-- ===== Partes de la base =====

local function buildGround(model: Model, plot: CFrame)
	local g = group(model, "Ground")
	-- El terreno usa la orientación del juego (su frente mira al lobby): lo usan las mascotas para mirar adelante
	local plotPart = newPart(g, "Plot")
	plotPart.Size = Vector3.new(60, 0.3, 44)
	plotPart.CFrame = plot * CFrame.new(0, 0.15, 0)
	plotPart.Color = C.grass
	plotPart.Material = M.Grass
	model.PrimaryPart = plotPart
	block(g, "SandYard", Vector3.new(54, 0.35, 19), Vector3.new(0, 0.18, 12), C.sand, M.Sand)
	for _, px in { -7, 7 } do
		for i = 0, 6 do
			local p = newPart(g, "SteppingStone", Enum.PartType.Cylinder)
			p.Size = Vector3.new(0.35, 3.2, 3.2)
			p.CFrame = at(Vector3.new(px + (if i % 2 == 0 then -0.6 else 0.6), 0.4, 21 - i * 2.9), CFrame.Angles(0, 0, math.rad(90)))
			p.Color = C.stoneLight
			p.Material = M.Slate
		end
	end
	block(g, "Plinth", Vector3.new(44, 1.5, 24), Vector3.new(0, 0.75, -9), C.stone, M.Slate)
	block(g, "PlinthTrim", Vector3.new(44.6, 0.4, 24.6), Vector3.new(0, 1.55, -9), C.stoneDark, M.Slate)
	block(g, "Step1", Vector3.new(14, 0.5, 2), Vector3.new(0, 0.25, 4), C.stoneLight, M.Slate)
	block(g, "Step2", Vector3.new(14, 1, 1.2), Vector3.new(0, 0.5, 3.4), C.stone, M.Slate)
end

-- Baranda entre a y b (en XZ) a la altura y, con huecos (partes del recorrido 0..1 sin baranda)
local function railing(parent: Instance, a: Vector3, b: Vector3, y: number, gaps: { { number } }?)
	local dir = b - a
	local n = math.floor(dir.Magnitude / 2.5)
	local function inGap(t: number): boolean
		local list: { { number } } = gaps or {}
		for _, gap in list do
			if t >= gap[1] and t <= gap[2] then
				return true
			end
		end
		return false
	end
	local startT: number? = nil
	for i = 0, n do
		local t = i / n
		local p = a + dir * t
		if not inGap(t) then
			vcyl(parent, "Baluster", p.X, p.Z, y, y + 3.4, 0.5, C.bamboo, M.Wood)
			if startT == nil then
				startT = t
			end
		end
		local nextGap = i == n or inGap((i + 1) / n)
		local from = startT
		if from ~= nil and nextGap and not inGap(t) then
			local p0 = a + dir * from
			seg(parent, "HandRail", Vector3.new(p0.X, y + 3.5, p0.Z), Vector3.new(p.X, y + 3.5, p.Z), 0.8, C.bambooDark, M.Wood)
			seg(parent, "MidRail", Vector3.new(p0.X, y + 1.7, p0.Z), Vector3.new(p.X, y + 1.7, p.Z), 0.4, C.bamboo, M.Wood, deco())
			startT = nil
		end
	end
end

local function buildTower(model: Model)
	local t = group(model, "Tower")
	local tops = BaseBuilder.FloorTops
	for _, px in { -20, 0, 20 } do
		for _, pz in { -19, 1 } do
			vcyl(t, "Post", px, pz, 1.5, 37.5, 2.4, C.bamboo, M.Wood)
			for y = 5.5, 35.5, 4 do
				vcyl(t, "PostRing", px, pz, y, y + 0.4, 2.7, C.bambooDark, M.Wood, deco())
			end
			for _, top in { tops[2], tops[3] } do
				vcyl(t, "Lashing", px, pz, top - 1.6, top - 0.6, 2.9, C.rope, M.Fabric, deco())
			end
		end
	end
	for f, top in tops do
		local floorModel = group(t, `Floor{f}`)
		for i = 0, 7 do
			block(floorModel, "Plank", Vector3.new(40, 0.5, 2.45), Vector3.new(0, top - 0.25, -17.75 + i * 2.5), if i % 2 == 0 then C.wood else C.woodMid, M.WoodPlanks)
		end
		if f > 1 then
			block(floorModel, "BeamFront", Vector3.new(41, 1, 1), Vector3.new(0, top - 1, 1), C.woodDark, M.Wood)
			block(floorModel, "BeamBack", Vector3.new(41, 1, 1), Vector3.new(0, top - 1, -19), C.woodDark, M.Wood)
			block(floorModel, "Ceiling", Vector3.new(40, 0.2, 20), Vector3.new(0, top - 1.4, -9), C.woodDark, M.WoodPlanks, nil, deco())
		end
	end
	block(t, "BackPanel", Vector3.new(40, 35, 0.4), Vector3.new(0, 19.5, -19.6), C.weave, M.Fabric)
	for x = -19, 19, 2 do
		vcyl(t, "BackCane", x, -19.2, 2, 37, 0.9, if x % 4 == 1 then C.bamboo else C.bambooDark, M.Wood, deco())
	end
	local rails = group(t, "Railings")
	local L, R = Vector3.new(-20, 0, -19), Vector3.new(20, 0, -19)
	local LF, RF = Vector3.new(-20, 0, 1), Vector3.new(20, 0, 1)
	railing(rails, L, LF, tops[1])
	railing(rails, R, RF, tops[1])
	railing(rails, R, RF, tops[2], { { 0, 0.3 } })
	railing(rails, L, LF, tops[2], { { 0, 0.3 } })
	railing(rails, LF, RF, tops[2])
	railing(rails, L, LF, tops[3], { { 0.7, 1 } })
	railing(rails, R, RF, tops[3])
	railing(rails, LF, RF, tops[3])
end

local function buildStairs(model: Model)
	local s = group(model, "Stairs")
	local tops = BaseBuilder.FloorTops
	local function flight(x: number, zStart: number, zEnd: number, yStart: number, yEnd: number, name: string)
		local f = group(s, name)
		local n = 14
		local dz = (zEnd - zStart) / n
		local dy = (yEnd - yStart) / n
		for i = 1, n do
			local z = zStart + dz * (i - 0.5)
			local y = yStart + dy * i
			block(f, "Step", Vector3.new(4, 0.5, math.abs(dz) + 0.1), Vector3.new(x, y - 0.25, z), if i % 2 == 0 then C.wood else C.woodLight, M.WoodPlanks)
		end
		local outer = x + (if x > 0 then 2.1 else -2.1)
		local inner = x - (if x > 0 then 2.1 else -2.1)
		seg(f, "StringerOuter", Vector3.new(outer, yStart, zStart), Vector3.new(outer, yEnd - 0.4, zEnd), 0.7, C.woodDark, M.Wood)
		seg(f, "StringerInner", Vector3.new(inner, yStart, zStart), Vector3.new(inner, yEnd - 0.4, zEnd), 0.7, C.woodDark, M.Wood)
		seg(f, "HandRail", Vector3.new(outer, yStart + 3.5, zStart), Vector3.new(outer, yEnd + 3.5, zEnd), 0.7, C.bambooDark, M.Wood)
		for i = 0, 4 do
			local t = i / 4
			local z = zStart + (zEnd - zStart) * t
			local y = yStart + (yEnd - yStart) * t
			vcyl(f, "RailPost", outer, z, y, y + 3.5, 0.45, C.bamboo, M.Wood)
			if y > 1 then
				vcyl(f, "Support", outer, z, 0.3, y, 0.6, C.bamboo, M.Wood, deco())
			end
		end
	end
	flight(22.6, 2.5, -18.5, 0.3, tops[2], "Flight1")
	flight(-22.6, -18.5, 1, tops[2], tops[3], "Flight2")
	block(s, "Landing2", Vector3.new(4.6, 0.5, 4), Vector3.new(-22.6, tops[2] - 0.25, -18.8), C.wood, M.WoodPlanks)
	block(s, "Landing1", Vector3.new(4.6, 0.5, 4), Vector3.new(22.6, tops[2] - 0.25, -18.8), C.wood, M.WoodPlanks)
end

local function buildRoof(model: Model)
	local r = group(model, "Roof")
	local eaveY, ridgeY = 37, 47.5
	local zBack, zFront, zRidge = -24, 6, -9
	local offsets = { 0, 0.6, 1.2 }
	local colors = { C.thatch2, C.thatch1, C.thatch3 }
	for i, off in offsets do
		local color = colors[i]
		local width = 52 - i * 1.5
		slab(r, `ThatchFront{i}`, Vector3.new(0, ridgeY + off, zRidge), Vector3.new(0, eaveY + off + i * 0.6, zFront - i * 0.8), width, 0.9, color, M.Fabric)
		slab(r, `ThatchBack{i}`, Vector3.new(0, ridgeY + off, zRidge), Vector3.new(0, eaveY + off + i * 0.6, zBack + i * 0.8), width, 0.9, color, M.Fabric)
	end
	local x = -25
	while x <= 25 do
		local hf = rng:NextNumber(1.6, 2.6)
		block(r, "Fringe", Vector3.new(1.2, hf, 0.3), Vector3.new(x, eaveY + 0.6 - hf / 2, zFront - 0.6), if math.floor(x) % 2 == 0 then C.thatch1 else C.thatch2, M.Fabric, CFrame.Angles(math.rad(-15), 0, 0), deco())
		block(r, "Fringe", Vector3.new(1.2, hf, 0.3), Vector3.new(x, eaveY + 0.6 - hf / 2, zBack + 0.6), C.thatch2, M.Fabric, CFrame.Angles(math.rad(15), 0, 0), deco())
		x += 1.6
	end
	for _, gx in { -21, 21 } do
		for k = 0, 4 do
			local half = (1 - k / 5) * 14
			block(r, "Gable", Vector3.new(0.5, 2, half * 2), Vector3.new(gx, 37.6 + k * 2, zRidge), if k % 2 == 0 then C.woodLight else C.wood, M.WoodPlanks)
		end
	end
	seg(r, "Ridge", Vector3.new(-27, ridgeY + 1.7, zRidge), Vector3.new(27, ridgeY + 1.7, zRidge), 1.4, C.woodDark, M.Wood)
	for _, ex in { -27, 27 } do
		block(r, "CrestPost", Vector3.new(1.4, 5, 1.4), Vector3.new(ex, ridgeY + 4, zRidge), C.maskWood, M.Wood)
		block(r, "HornL", Vector3.new(0.6, 3, 0.6), Vector3.new(ex, ridgeY + 7, zRidge - 1), C.woodDark, M.Wood, CFrame.Angles(math.rad(-35), 0, 0))
		block(r, "HornR", Vector3.new(0.6, 3, 0.6), Vector3.new(ex, ridgeY + 7, zRidge + 1), C.woodDark, M.Wood, CFrame.Angles(math.rad(35), 0, 0))
		block(r, "CrestEyes", Vector3.new(1.5, 0.5, 1), Vector3.new(ex, ridgeY + 5, zRidge), C.lampYellow, M.Neon, nil, deco())
	end
	vcyl(r, "FlagPole", 0, zRidge, ridgeY + 2, ridgeY + 13, 0.5, C.woodDark, M.Wood)
	block(r, "Flag", Vector3.new(5, 3, 0.2), Vector3.new(2.7, ridgeY + 11.3, zRidge), C.cyan, M.Fabric, nil, deco())
	-- Guirnalda de luces en el alero de adelante
	local lights = group(r, "StringLights")
	local i = 0
	local previous: Vector3? = nil
	local lx = -25
	while lx <= 25 do
		local sag = math.sin(((lx + 25) / 10) * math.pi) * 0.8
		local p = Vector3.new(lx, eaveY - 1.6 - math.abs(sag), zFront - 0.3)
		if previous then
			seg(lights, "Cord", previous, p, 0.12, C.black, M.SmoothPlastic, deco())
		end
		i += 1
		local bulb = ball(lights, "Bulb", 0.8, p - Vector3.new(0, 0.5, 0), LIGHTS[(i - 1) % #LIGHTS + 1], M.Neon, deco())
		if i % 4 == 0 then
			light(bulb, bulb.Color, 9, 1)
		end
		previous = p
		lx += 2.5
	end
end

-- Estantes (5 por piso, numerados piso por piso) y las paredes de vidrio de los pisos bloqueados
local function buildShelves(model: Model)
	local stands = group(model, "ShelfStands")
	local slots = Instance.new("Folder")
	slots.Name = "CreatureSlots"
	slots.Parent = model
	local slot = 0
	for f, top in BaseBuilder.FloorTops do
		for n, x in SHELF_X do
			slot += 1
			local unlocked = f == 1
			block(stands, `Stand_{f}_{n}`, Vector3.new(4.6, 1, 4.6), Vector3.new(x, top + 0.5, -15), C.woodDark, M.Wood)
			local pad = newPart(slots, `Shelf_{f}_{n}`, Enum.PartType.Cylinder)
			pad.Size = Vector3.new(0.6, 5.6, 5.6)
			pad.CFrame = at(Vector3.new(x, top + 1.3, -15), CFrame.Angles(0, 0, math.rad(90)))
			pad.Color = if unlocked then BaseBuilder.ShelfOn else BaseBuilder.ShelfOff
			pad.Material = M.Fabric
			pad:SetAttribute("SlotIndex", slot)
			pad:SetAttribute("Floor", f)
			pad:SetAttribute("Unlocked", unlocked)
			local plate = block(stands, `Plate_{f}_{n}`, Vector3.new(3.6, 0.9, 0.2), Vector3.new(x, top + 0.5, -12.6), C.paper, M.SmoothPlastic)
			label(plate, FRONT, `#{slot}`, C.dark, 40)
			-- Lamparita que ilumina el estante (BaseFloors la prende cuando se abre el piso)
			local lampY = top + 9.6
			seg(stands, "LampCord", Vector3.new(x, lampY + 0.6, -15), Vector3.new(x, top + 11.2, -15), 0.12, C.black, M.SmoothPlastic, deco())
			local lamp = block(pad, "Lamp", Vector3.new(1.4, 0.8, 1.4), Vector3.new(x, lampY, -15), C.bamboo, M.Wood, nil, deco())
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Bottom
			spot.Angle = 50
			spot.Range = 12
			spot.Brightness = if unlocked then 1.6 else 0
			spot.Color = rgb("FFE7B0")
			spot.Shadows = false
			spot.Parent = lamp
		end
	end
	-- Paredes de vidrio (adelante y a los costados, así tampoco se entra por las escaleras)
	local locks = Instance.new("Folder")
	locks.Name = "Locks"
	locks.Parent = model
	for f = 2, 3 do
		local top = BaseBuilder.FloorTops[f]
		local barrier = Instance.new("Model")
		barrier.Name = `LockBarrier{f}`
		barrier:SetAttribute("Floor", f)
		local front = block(barrier, "Front", Vector3.new(40, 11.2, 0.4), Vector3.new(0, top + 5.6, 1.9), C.glass, M.ForceField)
		for _, sx in { -20.4, 20.4 } do
			block(barrier, "Side", Vector3.new(0.4, 11.2, 20), Vector3.new(sx, top + 5.6, -9), C.glass, M.ForceField)
		end
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(240, 60)
		billboard.MaxDistance = 80
		billboard.Parent = front
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.Font = Enum.Font.FredokaOne
		text.TextColor3 = C.white
		text.Text = `🔒 LOCKED · Floor {f}`
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = rgb("0B0B10")
		stroke.Parent = text
		text.Parent = billboard
		barrier.Parent = locks
	end
end

-- Nidos: la parte que no cambia. IncubatorService les agrega el huevo, la luz, el botón y el cartel del tiempo.
local function buildNests(model: Model)
	local nests = Instance.new("Folder")
	nests.Name = "IncubatorSlots"
	nests.Parent = model
	for i, x in NEST_X do
		local nest = group(nests, `Nest{i}`)
		local z = 15
		local pedestal = block(nest, "Pedestal", Vector3.new(8, 2, 8), Vector3.new(x, 1, z), C.stone, M.Slate)
		pedestal:SetAttribute("SlotIndex", i)
		block(nest, "PedestalTrim", Vector3.new(8.6, 0.4, 8.6), Vector3.new(x, 2.1, z), C.stoneDark, M.Slate)
		local base = newPart(nest, "NestBase", Enum.PartType.Cylinder)
		base.Size = Vector3.new(1.5, 7, 7)
		base.CFrame = at(Vector3.new(x, 2.95, z), CFrame.Angles(0, 0, math.rad(90)))
		base.Color = C.woodMid
		base.Material = M.WoodPlanks
		for k = 1, 12 do
			local a = k / 12 * math.pi * 2
			block(nest, "NestRim", Vector3.new(2, 1.2, 0.8), Vector3.new(x + math.cos(a) * 3.3, 3.8, z + math.sin(a) * 3.3), if k % 2 == 0 then C.thatch1 else C.thatch3, M.Fabric, CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(math.rad(-25), 0, 0), deco())
		end
		local number = block(nest, "NumberPlate", Vector3.new(2, 1.2, 0.2), Vector3.new(x, 1.1, z + 4.1), C.paper, M.SmoothPlastic, nil, deco())
		label(number, FRONT, tostring(i), rgb("C98A00"), 40)
		for k = 1, 7 do
			local a = k / 7 * math.pi * 2 + 0.3
			rock(nest, x + math.cos(a) * 5.4, z + math.sin(a) * 5.4, rng:NextNumber(0.8, 1.6))
		end
	end
end

local function buildEntrance(model: Model)
	local e = group(model, "Entrance")
	for _, ax in { -10.5, 10.5 } do
		vcyl(e, "ArchPost", ax, 21, 0, 13, 1.6, C.bamboo, M.Wood)
		for y = 2, 12, 3 do
			vcyl(e, "ArchRing", ax, 21, y, y + 0.35, 1.85, C.bambooDark, M.Wood, deco())
		end
		tikiTorch(e, ax + (if ax > 0 then 2.4 else -2.4), 22.5, 6)
	end
	seg(e, "ArchBeam", Vector3.new(-12.5, 12.6, 21), Vector3.new(12.5, 12.6, 21), 1.4, C.woodDark, M.Wood)
	seg(e, "ArchBeam2", Vector3.new(-12, 13.8, 21), Vector3.new(12, 13.8, 21), 0.9, C.bamboo, M.Wood)
	-- Cartel con el nombre del dueño (BaseService cambia el texto de "SignLabel")
	local sign = block(e, "Sign", Vector3.new(15, 3.2, 0.6), Vector3.new(0, 10.6, 21.4), C.woodLight, M.WoodPlanks)
	local signLabel = label(sign, FRONT, "Free Base", rgb("FFE7B0"), 30)
	signLabel.Name = "SignLabel"
	seg(e, "SignRopeL", Vector3.new(-6, 12.2, 21.4), Vector3.new(-6, 12.6, 21.2), 0.2, C.rope, M.Fabric, deco())
	seg(e, "SignRopeR", Vector3.new(6, 12.2, 21.4), Vector3.new(6, 12.6, 21.2), 0.2, C.rope, M.Fabric, deco())
	local garland = { rgb("FF4F8B"), rgb("FFD43B"), rgb("FFFFFF"), rgb("FF8A1F") }
	for k = 0, 12 do
		local x = -10 + k * (20 / 12)
		local y = 12.2 - math.sin(k / 12 * math.pi) * 1.4
		ball(e, "Flower", 0.9, Vector3.new(x, y, 21.9), garland[k % #garland + 1], M.SmoothPlastic, deco())
	end
	-- Cerco de bambú (con la entrada abierta adelante)
	local fence = group(e, "Fence")
	local function fenceLine(a: Vector3, b: Vector3)
		local d = b - a
		local n = math.max(1, math.floor(d.Magnitude / 2.5))
		for i = 0, n do
			local p = a + d * (i / n)
			vcyl(fence, "FencePost", p.X, p.Z, 0, 3.2 + (if i % 2 == 0 then 0.4 else 0), 0.7, C.bamboo, M.Wood)
		end
		seg(fence, "FenceRail", Vector3.new(a.X, 1.2, a.Z), Vector3.new(b.X, 1.2, b.Z), 0.45, C.bambooDark, M.Wood)
		seg(fence, "FenceRail", Vector3.new(a.X, 2.6, a.Z), Vector3.new(b.X, 2.6, b.Z), 0.45, C.bambooDark, M.Wood)
	end
	fenceLine(Vector3.new(-29.5, 0, -21.5), Vector3.new(29.5, 0, -21.5))
	fenceLine(Vector3.new(-29.5, 0, -21.5), Vector3.new(-29.5, 0, 21.5))
	fenceLine(Vector3.new(29.5, 0, -21.5), Vector3.new(29.5, 0, 21.5))
	fenceLine(Vector3.new(-29.5, 0, 21.5), Vector3.new(-12.5, 0, 21.5))
	fenceLine(Vector3.new(12.5, 0, 21.5), Vector3.new(29.5, 0, 21.5))
end

local function buildTowerDecor(model: Model)
	local d = group(model, "TowerDecor")
	local tops = BaseBuilder.FloorTops
	tikiMask(d, Vector3.new(-20, 8, 2.6))
	tikiMask(d, Vector3.new(20, 8, 2.6))
	tikiMask(d, Vector3.new(0, 31, 2.6))
	for _, lx in { -10, 10 } do
		lantern(d, Vector3.new(lx, tops[2] - 4.5, 2.9))
		lantern(d, Vector3.new(lx, tops[3] - 4.5, 2.9))
		lantern(d, Vector3.new(lx, 33, 2.9))
	end
	tikiTorch(d, -23.5, 5, 7)
	for _, top in { tops[2], tops[3] } do
		for _, px in { -17.5, 17.5 } do
			vcyl(d, "Pot", px, -0.5, top, top + 1.6, 2.2, rgb("C2410C"), M.Slate)
			bush(d, px, -0.5, 2.6, C.pink, top + 1.4)
		end
	end
	for _, top in { tops[2], tops[3] } do
		for k = 1, 7 do
			local vx = -18 + k * 4.5 + rng:NextNumber(-1, 1)
			local len = rng:NextNumber(2.5, 5.5)
			slab(d, "Vine", Vector3.new(vx, top - 1.4, 1.6), Vector3.new(vx + rng:NextNumber(-0.4, 0.4), top - 1.4 - len, 1.7), 0.9, 0.2, LEAVES[rng:NextInteger(1, 3)], M.LeafyGrass, deco())
			if rng:NextNumber() < 0.5 then
				ball(d, "VineFlower", 0.7, Vector3.new(vx, top - 1.4 - len * 0.6, 1.9), C.pink, M.SmoothPlastic, deco())
			end
		end
	end
	block(d, "Rug", Vector3.new(14, 0.1, 8), Vector3.new(0, tops[1] + 0.05, -7), rgb("D9483B"), M.Fabric, nil, deco())
	block(d, "RugStripe", Vector3.new(14, 0.12, 1.2), Vector3.new(0, tops[1] + 0.07, -7), C.lampYellow, M.Fabric, nil, deco())
	block(d, "Chest", Vector3.new(4, 2.4, 2.6), Vector3.new(-12, tops[1] + 1.2, -5), C.woodMid, M.WoodPlanks)
	block(d, "ChestBand", Vector3.new(4.1, 0.4, 2.7), Vector3.new(-12, tops[1] + 1.6, -5), C.lampYellow, M.Metal, nil, deco())
end

local function buildGarden(model: Model)
	local g = group(model, "Garden")
	-- Rincón de descanso: hamaca entre dos palmeras
	palm(g, -27, 6, 22)
	palm(g, -27, 18.5, 20)
	local a = Vector3.new(-27, 5, 7)
	local b = Vector3.new(-27, 5, 17.5)
	local mid = (a + b) / 2 - Vector3.new(0, 1.2, 0)
	slab(g, "HammockA", a, mid, 2.6, 0.2, rgb("FF5FA2"), M.Fabric, deco())
	slab(g, "HammockB", mid, b, 2.6, 0.2, C.cyan, M.Fabric, deco())
	block(g, "LoungeChair", Vector3.new(2.6, 0.4, 5), Vector3.new(-22, 0.9, 19.5), C.white, M.Fabric, CFrame.Angles(math.rad(-10), 0.3, 0))
	block(g, "Towel", Vector3.new(2.4, 0.1, 4), Vector3.new(-22, 1.15, 19.6), C.lavaGlow, M.Fabric, CFrame.Angles(math.rad(-10), 0.3, 0), deco())
	for k = 1, 6 do
		ball(g, "Coconut", 1.3, Vector3.new(-24.5 + (k % 3) * 1.2, 0.6 + math.floor(k / 4), 10 + (k % 2) * 1.1), rgb("6E461E"), M.SmoothPlastic, deco())
	end
	palm(g, -26.5, -18.5, 26)
	palm(g, 27, -18, 24)
	local x = -26
	while x <= 26 do
		bush(g, x, -20.6, rng:NextNumber(2.5, 4), FLOWERS[rng:NextInteger(1, #FLOWERS)], if math.abs(x) < 22.5 then 1.5 else 0)
		x += 4.5
	end
	for z = -14, 2, 6 do
		bush(g, 26.8, z, 3, FLOWERS[rng:NextInteger(1, #FLOWERS)])
	end
	vcyl(g, "Barrel", 26.5, 7, 0.3, 3.8, 3, C.woodMid, M.WoodPlanks)
	vcyl(g, "BarrelBand", 26.5, 7, 1, 1.4, 3.15, rgb("3A3A3A"), M.Metal, deco())
	vcyl(g, "BarrelBand", 26.5, 7, 2.8, 3.2, 3.15, rgb("3A3A3A"), M.Metal, deco())
	block(g, "Crate", Vector3.new(3, 3, 3), Vector3.new(26, 1.8, 11), C.woodLight, M.WoodPlanks, CFrame.Angles(0, 0.3, 0))
	block(g, "Crate", Vector3.new(2.2, 2.2, 2.2), Vector3.new(26.2, 4.4, 11), C.wood, M.WoodPlanks, CFrame.Angles(0, -0.2, 0))
	local boardColors = { C.cyan, rgb("FF5FA2") }
	for k = 1, 2 do
		local tilt = CFrame.Angles(0, math.rad(90), math.rad(-14))
		block(g, "Surfboard", Vector3.new(2.2, 9, 0.4), Vector3.new(-21.6, 4.6, -4 - k * 3), boardColors[k], M.SmoothPlastic, tilt)
		block(g, "SurfStripe", Vector3.new(0.4, 8.6, 0.45), Vector3.new(-21.6, 4.6, -4 - k * 3), C.white, M.SmoothPlastic, tilt, deco())
	end
	for _ = 1, 16 do
		local fx = rng:NextNumber(-25, 25)
		local fz = rng:NextNumber(5.5, 20)
		local nearNest = (math.abs(fx + 14) < 6 or math.abs(fx) < 6 or math.abs(fx - 14) < 6) and fz > 9
		local onPath = math.abs(math.abs(fx) - 7) < 2.4
		if not nearNest and not onPath and math.abs(fx) < 20 then
			ball(g, "Flower", 0.8, Vector3.new(fx, 0.9, fz), FLOWERS[rng:NextInteger(1, #FLOWERS)], M.SmoothPlastic, deco())
			seg(g, "Stem", Vector3.new(fx, 0.3, fz), Vector3.new(fx, 0.8, fz), 0.15, C.leaf1, M.Grass, deco())
		end
	end
end

-- Cartel "BIGGER TOWER": los pisos se abren renaciendo. BaseFloors actualiza los renglones; el botón abre la ventana de Rebirth.
local function buildFloorShop(model: Model)
	local f = group(model, "FloorShop")
	local cx, cz = 24, 19
	vcyl(f, "PostLeft", cx - 4.6, cz, 0, 12, 1.2, C.bamboo, M.Wood)
	vcyl(f, "PostRight", cx + 4.6, cz, 0, 12, 1.2, C.bamboo, M.Wood)
	local board = block(f, "Board", Vector3.new(10, 7.5, 0.8), Vector3.new(cx, 7.5, cz), C.wood, M.WoodPlanks)
	local paper = block(f, "Paper", Vector3.new(9, 6.6, 0.1), Vector3.new(cx, 7.5, cz + 0.45), C.paper, M.SmoothPlastic)
	slab(f, "RoofL", Vector3.new(cx, 14.2, cz), Vector3.new(cx - 6.2, 12, cz), 2.6, 0.5, C.thatch1, M.Fabric)
	slab(f, "RoofR", Vector3.new(cx, 14.2, cz), Vector3.new(cx + 6.2, 12, cz), 2.6, 0.5, C.thatch1, M.Fabric)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ShopGui"
	gui.Face = FRONT
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = paper
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0.03, 0)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local function row(name: string, text: string, color: Color3, height: number, order: number)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.LayoutOrder = order
		t.Size = UDim2.fromScale(0.92, height)
		t.BackgroundColor3 = color
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = C.white
		t.Text = text
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = t
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = C.dark
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Parent = t
		t.Parent = gui
	end
	row("Header", "BIGGER TOWER", rgb("C98A00"), 0.24, 1)
	row("Floor2", "FLOOR 2 · REBIRTH 1", rgb("6B6B73"), 0.3, 2)
	row("Floor3", "FLOOR 3 · REBIRTH 2", rgb("6B6B73"), 0.3, 3)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Rebirth"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	CollectionService:AddTag(prompt, "RebirthPrompt")
end

-- Arma la base número "index". "plot" es el centro del terreno mirando al lobby (frente = -Z, como en el resto del juego).
function BaseBuilder.Build(index: number, plot: CFrame, parent: Instance): Model
	B = plot * CFrame.Angles(0, math.pi, 0) -- (el diseño usa +Z como frente)
	rng = Random.new(11 + index)
	local model = Instance.new("Model")
	model.Name = `Base{index}`
	model:SetAttribute("BaseId", index)
	model:SetAttribute("OwnerUserId", 0)

	buildGround(model, plot)
	buildTower(model)
	buildStairs(model)
	buildRoof(model)
	buildShelves(model)
	buildNests(model)
	buildEntrance(model)
	buildTowerDecor(model)
	buildGarden(model)
	buildFloorShop(model)

	-- Dónde aparece el dueño, y el volumen de la base (para saber si alguien está adentro)
	block(model, "SpawnPoint", Vector3.new(4, 1, 4), Vector3.new(0, 0.5, 7), C.white, M.SmoothPlastic, nil, deco({ Transparency = 1 }))
	block(model, "SafeZone", Vector3.new(60, 60, 44), Vector3.new(0, 30, 0), C.white, M.SmoothPlastic, nil, deco({ Transparency = 1 }))

	model.Parent = parent
	return model
end

return BaseBuilder

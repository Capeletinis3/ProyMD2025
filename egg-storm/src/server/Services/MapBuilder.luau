--!strict
-- MapBuilder: arma el mapa placeholder con Parts simples (estilo bloques/LEGO, colorido).
-- Tema mezcla playa + mar: lobby de arena con baldosas; pasillo de agua turquesa entre paredes azul océano
-- con corales y algas arriba. Las bases son estanterías de metal con pisos a rayas.
--
-- Forma del mapa (visto desde arriba, en forma de T), eje Z de abajo hacia arriba:
--
--             ┌──── agua (de acá sale la ola) ────┐         Z = CorridorLength + SeaDepth
--             │  1250m  (cuanto más lejos, mejor) │         pasillo de arena (peligro), con carteles
--             │  250m · 500m · 750m · 1000m ...   │         de distancia y banderines de colores
--   ┌─────────┴──────── arco "SAFE ZONE" ─────────┴────────┐ Z = 0  (línea segura)
--   │  ↑     ↑     ↑     ↑     ↑     ↑     ↑     ↑        │ lobby verde (seguro)
--   │ [B1]  [B2]  [B3]  [B4]  [B5]  [B6]  [B7]  [B8]       │ bases mirando al pasillo
--   └──────────────────────────────────────────────────────┘ Z = -(LobbyFrontWalk + PlotDepth + LobbyBackMargin)
--
-- Si en Workspace ya existe una carpeta "Map" (por ejemplo, cuando reemplaces los modelos a mano),
-- no construye nada y usa esa. Solo tiene que respetar la misma estructura:
--   Map/Bases/BaseN (Model con atributo BaseId) con SpawnPoint, SafeZone y un TextLabel "SignLabel".

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local cfg = Config.Map
local HALF_WIDTH = cfg.CorridorWidth / 2
-- El lobby tiene el ancho justo para las bases en fila (con un espacio entre cada una y contra las paredes)
local LOBBY_WIDTH = math.max(cfg.BaseCount * cfg.PlotWidth + (cfg.BaseCount + 1) * cfg.PlotGap, cfg.CorridorWidth)
local LOBBY_HALF_WIDTH = LOBBY_WIDTH / 2
local LOBBY_DEPTH = cfg.LobbyFrontWalk + cfg.PlotDepth + cfg.LobbyBackMargin

-- Colores fuertes para la decoración (se van alternando)
local PALETTE = {
	Color3.fromRGB(255, 80, 120), -- rosa
	Color3.fromRGB(80, 170, 255), -- celeste
	Color3.fromRGB(255, 200, 60), -- amarillo
	Color3.fromRGB(180, 90, 255), -- violeta
	Color3.fromRGB(80, 220, 120), -- verde
	Color3.fromRGB(255, 140, 60), -- naranja
}
local function paletteColor(i: number): Color3
	return PALETTE[(i - 1) % #PALETTE + 1]
end
local ACCENT = Color3.fromRGB(255, 200, 60) -- detalles de las bases (todas grises e iguales)
-- Estantería de las bases (como en el video de referencia)
local SHELF_FRAME = Color3.fromRGB(35, 45, 110) -- metal azul oscuro
local SHELF_DECK = Color3.fromRGB(120, 80, 220) -- pisos violeta...
local SHELF_STRIPE = Color3.fromRGB(205, 185, 255) -- ...con rayas lila
local SHELF_LEVEL = 12 -- altura del estante del medio (ahí va el piso 2 de la mejora "Base Floor")
local SHELF_TOP = 26 -- altura del techo de la estantería
local CORAL_COLORS = {
	Color3.fromRGB(255, 110, 150),
	Color3.fromRGB(255, 150, 70),
	Color3.fromRGB(190, 100, 255),
	Color3.fromRGB(255, 215, 80),
}
local DISTANCE_MARK_EVERY = 250 -- un cartel "250m", "500m"... cada tantos studs
local BUNTING_EVERY = 150 -- una tira de banderines cruzando el pasillo cada tantos studs

-- ===== Ayudantes =====

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, studs: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	local surface = if studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	part.TopSurface = surface
	part.BottomSurface = surface
	part.FrontSurface = surface
	part.BackSurface = surface
	part.LeftSurface = surface
	part.RightSurface = surface
	part.Parent = parent
	return part
end

-- Parte invisible que no choca con nada: sirve como "marcador" de una posición o un volumen.
local function makeMarker(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = makePart(name, size, cframe, Color3.new(1, 1, 1), parent)
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

-- Cilindro parado (los cilindros de Roblox tienen el eje en X, así que lo giramos 90°).
local function makeColumn(name: string, height: number, diameter: number, bottom: Vector3, color: Color3, parent: Instance): Part
	local part = makePart(name, Vector3.new(height, diameter, diameter), CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, parent)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Pone un texto sobre una cara de una Part (carteles).
local function addText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, labelName: string?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = labelName or "Label"
	label.Size = UDim2.fromScale(0.94, 0.9)
	label.Position = UDim2.fromScale(0.03, 0.05)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	return label
end

local function addRainbow(label: TextLabel)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 255, 100)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 80, 255)),
	})
	gradient.Parent = label
end

-- ===== Decoración =====

local function buildPalm(position: Vector3, parent: Instance)
	local palm = Instance.new("Model")
	palm.Name = "Palm"
	local trunkHeight = 22
	makeColumn("Trunk", trunkHeight, 2.5, position, Color3.fromRGB(140, 95, 55), palm)
	local top = position + Vector3.new(0, trunkHeight, 0)
	for i = 0, 5 do
		-- Cada hoja sale del tope del tronco, girada y un poco inclinada hacia abajo
		local leafCFrame = CFrame.new(top) * CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, 0, -6)
		makePart("Leaf", Vector3.new(3, 0.6, 12), leafCFrame, Color3.fromRGB(60, 190, 70), palm, true)
	end
	for i = 0, 2 do
		local coconut = makePart("Coconut", Vector3.new(1.6, 1.6, 1.6), CFrame.new(top + Vector3.new(math.cos(i * 2.1) * 1.4, -1.2, math.sin(i * 2.1) * 1.4)), Color3.fromRGB(110, 70, 40), palm)
		coconut.Shape = Enum.PartType.Ball
	end
	palm.Parent = parent
end

local function buildUmbrella(position: Vector3, color: Color3, parent: Instance)
	local umbrella = Instance.new("Model")
	umbrella.Name = "Umbrella"
	makeColumn("Pole", 10, 0.6, position, Color3.new(1, 1, 1), umbrella)
	local canopy = makeColumn("Canopy", 1, 12, position + Vector3.new(0, 10, 0), color, umbrella)
	canopy.CanCollide = false
	local tip = makeColumn("Tip", 1, 5, position + Vector3.new(0, 11, 0), Color3.new(1, 1, 1), umbrella)
	tip.CanCollide = false
	umbrella.Parent = parent
end

-- Toalla de playa con una franja blanca
local function buildTowel(cframe: CFrame, color: Color3, parent: Instance)
	local towel = makePart("Towel", Vector3.new(5, 0.15, 9), cframe * CFrame.new(0, 0.075, 0), color, parent)
	towel.CanCollide = false
	local stripe = makePart("TowelStripe", Vector3.new(5, 0.05, 1.2), cframe * CFrame.new(0, 0.175, 2.5), Color3.new(1, 1, 1), parent)
	stripe.CanCollide = false
end

local function buildBeachBall(position: Vector3, color: Color3, parent: Instance)
	local ball = makePart("BeachBall", Vector3.new(2.5, 2.5, 2.5), CFrame.new(position + Vector3.new(0, 1.25, 0)), color, parent)
	ball.Shape = Enum.PartType.Ball
end

-- Puesto de playa con toldo a rayas. cframe está a nivel del piso y su frente (-Z) mira al camino.
local function buildKiosk(cframe: CFrame, stripeColor: Color3, parent: Instance): Model
	local kiosk = Instance.new("Model")
	kiosk.Name = "Kiosk"
	local wood = Color3.fromRGB(150, 100, 60)
	makePart("Counter", Vector3.new(12, 4, 3), cframe * CFrame.new(0, 2, -3), wood, kiosk, true)
	makePart("CounterTop", Vector3.new(12.6, 0.5, 3.6), cframe * CFrame.new(0, 4.25, -3), Color3.new(1, 1, 1), kiosk)
	makePart("BackWall", Vector3.new(12, 8, 0.6), cframe * CFrame.new(0, 4, 3.7), stripeColor, kiosk, true)
	for _, x in { -5.7, 5.7 } do
		for _, z in { -4.5, 3.7 } do
			makePart("Post", Vector3.new(0.6, 10, 0.6), cframe * CFrame.new(x, 5, z), Color3.new(1, 1, 1), kiosk)
		end
	end
	-- Toldo: rayas alternadas, un poco inclinado hacia adelante
	for i = 0, 6 do
		local color = if i % 2 == 0 then stripeColor else Color3.new(1, 1, 1)
		makePart("Awning", Vector3.new(1.8, 0.4, 10), cframe * CFrame.new(-5.4 + i * 1.8, 10.4, -0.6) * CFrame.Angles(math.rad(-12), 0, 0), color, kiosk)
	end
	kiosk.Parent = parent
	return kiosk
end

-- Torre de guardavidas (cerca del agua)
local function buildLifeguardTower(cframe: CFrame, parent: Instance)
	local tower = Instance.new("Model")
	tower.Name = "LifeguardTower"
	local white = Color3.new(1, 1, 1)
	local red = Color3.fromRGB(230, 60, 60)
	for _, x in { -3.5, 3.5 } do
		for _, z in { -3.5, 3.5 } do
			makePart("Leg", Vector3.new(0.8, 12, 0.8), cframe * CFrame.new(x, 6, z), white, tower)
			makePart("RoofPost", Vector3.new(0.5, 7, 0.5), cframe * CFrame.new(x, 16, z), white, tower)
		end
	end
	makePart("Platform", Vector3.new(9, 1, 9), cframe * CFrame.new(0, 12.5, 0), red, tower, true)
	makePart("Rail", Vector3.new(9, 2, 0.4), cframe * CFrame.new(0, 14, -4.4), white, tower)
	makePart("Roof", Vector3.new(10, 0.6, 10), cframe * CFrame.new(0, 19.8, 0), red, tower, true)
	tower.Parent = parent
end

local function buildRocks(position: Vector3, rng: Random, parent: Instance)
	for _ = 1, rng:NextInteger(2, 3) do
		local size = rng:NextNumber(3, 6)
		local offset = Vector3.new(rng:NextNumber(-3, 3), size * 0.3, rng:NextNumber(-3, 3))
		local rotation = CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3))
		local gray = rng:NextNumber(0.45, 0.6)
		makePart("Rock", Vector3.new(size, size * 0.8, size * 1.1), CFrame.new(position + offset) * rotation, Color3.new(gray, gray, gray * 1.05), parent, true)
	end
end

-- Cofre del tesoro (abierto, con monedas)
local function buildChest(position: Vector3, rng: Random, parent: Instance)
	local chest = Instance.new("Model")
	chest.Name = "Chest"
	local wood = Color3.fromRGB(150, 95, 50)
	local gold = Color3.fromRGB(255, 205, 60)
	local base = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	makePart("ChestBox", Vector3.new(6, 3.5, 4), base * CFrame.new(0, 1.75, 0), wood, chest, true)
	makePart("ChestBand", Vector3.new(6.2, 0.6, 4.2), base * CFrame.new(0, 2.6, 0), gold, chest)
	makePart("Coins", Vector3.new(5.4, 0.6, 3.4), base * CFrame.new(0, 3.6, 0), gold, chest).Material = Enum.Material.Foil
	-- Tapa abierta, inclinada hacia atrás
	makePart("ChestLid", Vector3.new(6, 0.6, 4), base * CFrame.new(0, 3.5, 2) * CFrame.Angles(math.rad(-70), 0, 0) * CFrame.new(0, 0, -2), wood, chest, true)
	chest.Parent = parent
end

-- Coral: unas ramas paradas con una bolita en la punta. scale agranda todo.
local function buildCoral(position: Vector3, rng: Random, parent: Instance, scale: number?)
	local k = scale or 1
	local coral = Instance.new("Model")
	coral.Name = "Coral"
	local color = CORAL_COLORS[rng:NextInteger(1, #CORAL_COLORS)]
	for _ = 1, rng:NextInteger(3, 5) do
		local height = rng:NextNumber(2, 5) * k
		local tilt = CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4))
		local root = CFrame.new(position + Vector3.new(rng:NextNumber(-1.2, 1.2) * k, 0, rng:NextNumber(-1.2, 1.2) * k)) * tilt
		local branch = makePart("CoralBranch", Vector3.new(0.8 * k, height, 0.8 * k), root * CFrame.new(0, height / 2, 0), color, coral)
		branch.CanCollide = false
		local tip = makePart("CoralTip", Vector3.new(1.4, 1.4, 1.4) * k, root * CFrame.new(0, height, 0), color:Lerp(Color3.new(1, 1, 1), 0.25), coral)
		tip.Shape = Enum.PartType.Ball
		tip.CanCollide = false
	end
	coral.Parent = parent
end

-- Algas: tiras verdes altas, un poco torcidas
local function buildSeaweed(position: Vector3, rng: Random, parent: Instance, scale: number?)
	local k = scale or 1
	local seaweed = Instance.new("Model")
	seaweed.Name = "Seaweed"
	for _ = 1, rng:NextInteger(3, 5) do
		local height = rng:NextNumber(5, 10) * k
		local green = Color3.fromRGB(40, rng:NextInteger(170, 220), 80)
		local root = CFrame.new(position + Vector3.new(rng:NextNumber(-1.5, 1.5) * k, 0, rng:NextNumber(-1.5, 1.5) * k))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25))
		-- Dos tramos: el de arriba se dobla un poco, como si lo moviera el agua
		local lower = makePart("Seaweed", Vector3.new(0.7 * k, height / 2, 0.3 * k), root * CFrame.new(0, height / 4, 0), green, seaweed)
		local upper = makePart("Seaweed", Vector3.new(0.6 * k, height / 2, 0.3 * k), root * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, 0.3) * CFrame.new(0, height / 4, 0), green:Lerp(Color3.new(1, 1, 0.6), 0.2), seaweed)
		lower.CanCollide = false
		upper.CanCollide = false
	end
	seaweed.Parent = parent
end

-- Burbuja de vidrio con algas y corales adentro (como en el video de referencia)
local function buildBubbleDome(position: Vector3, diameter: number, rng: Random, parent: Instance)
	local dome = Instance.new("Model")
	dome.Name = "BubbleDome"
	makeColumn("DomeBase", 1, diameter + 1.5, position, Color3.fromRGB(235, 205, 160), dome)
	local k = diameter / 18
	buildSeaweed(position + Vector3.new(-diameter * 0.2, 1, 0), rng, dome, k)
	buildCoral(position + Vector3.new(diameter * 0.2, 1, diameter * 0.1), rng, dome, k * 1.2)
	buildCoral(position + Vector3.new(0, 1, -diameter * 0.2), rng, dome, k)
	local glass = makePart("Glass", Vector3.new(diameter, diameter, diameter), CFrame.new(position + Vector3.new(0, diameter / 2, 0)), Color3.fromRGB(190, 240, 255), dome)
	glass.Shape = Enum.PartType.Ball
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.65
	dome.Parent = parent
end

-- ===== Partes del mapa =====

local function buildWalls(map: Instance)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = map

	local t = cfg.WallThickness
	local h = cfg.WallHeight
	local farZ = cfg.CorridorLength + cfg.SeaDepth
	local nearZ = -LOBBY_DEPTH
	local pillarColor = cfg.WallColor:Lerp(Color3.new(0, 0, 0), 0.2)

	-- Pared azul con su borde de arena arriba. size/position describen el bloque de la pared.
	local function wall(name: string, size: Vector3, position: Vector3)
		makePart(name, size, CFrame.new(position), cfg.WallColor, walls, true)
		makePart("Trim", Vector3.new(size.X + 2, 2, size.Z + 2), CFrame.new(position.X, h + 1, position.Z), cfg.WallTrimColor, walls, true)
	end

	-- Paredes del pasillo (de la línea segura hasta el fondo)
	local corridorLength = farZ + t
	for _, side in { -1, 1 } do
		wall("CorridorWall", Vector3.new(t, h, corridorLength), Vector3.new(side * (HALF_WIDTH + t / 2), h / 2, corridorLength / 2))
		-- Columnas cada tanto, y entre columna y columna una franja de color (cada tramo de otro color)
		local z = 30
		local i = 0
		while z < farZ do
			i += 1
			makePart("Pillar", Vector3.new(2, h, 6), CFrame.new(side * (HALF_WIDTH - 1), h / 2, z), pillarColor, walls, true)
			local stripeLength = math.min(54, farZ - z - 3)
			if stripeLength > 4 then
				local stripe = makePart("Stripe", Vector3.new(0.6, 5, stripeLength), CFrame.new(side * (HALF_WIDTH - 0.3), 9, z + 3 + stripeLength / 2), paletteColor(i), walls)
				stripe.CanCollide = false
			end
			z += 60
		end
	end
	wall("FarWall", Vector3.new(cfg.CorridorWidth + t * 2, h, t), Vector3.new(0, h / 2, farZ + t / 2))

	-- Paredes del lobby
	local lobbyLength = LOBBY_DEPTH + t * 2
	for _, side in { -1, 1 } do
		wall("LobbyWall", Vector3.new(t, h, lobbyLength), Vector3.new(side * (LOBBY_HALF_WIDTH + t / 2), h / 2, nearZ + LOBBY_DEPTH / 2))
		-- "Hombros" de la T: cierran el lobby a los costados de la entrada del pasillo
		local shoulderWidth = LOBBY_HALF_WIDTH - HALF_WIDTH + t
		if shoulderWidth > t then
			wall("ShoulderWall", Vector3.new(shoulderWidth, h, t), Vector3.new(side * (HALF_WIDTH + shoulderWidth / 2), h / 2, t / 2))
		end
	end
	wall("BackWall", Vector3.new(LOBBY_WIDTH + t * 2, h, t), Vector3.new(0, h / 2, nearZ - t / 2))

	-- Corales y algas arriba de las paredes del pasillo (como un acuario)
	local rng = Random.new(77)
	local topY = h + 2
	for _, side in { -1, 1 } do
		local x = side * (HALF_WIDTH + t / 2)
		local z = 15 + (if side > 0 then 20 else 0)
		while z < farZ do
			local position = Vector3.new(x, topY, z)
			if rng:NextNumber() < 0.5 then
				buildCoral(position, rng, walls, 1.6)
			else
				buildSeaweed(position, rng, walls, 1.2)
			end
			z += rng:NextNumber(30, 45)
		end
	end
	-- ...y sobre la pared de atrás del lobby
	local x = -LOBBY_HALF_WIDTH + 15
	while x < LOBBY_HALF_WIDTH - 10 do
		local position = Vector3.new(x, topY, nearZ - t / 2)
		if rng:NextNumber() < 0.5 then
			buildCoral(position, rng, walls, 1.6)
		else
			buildSeaweed(position, rng, walls, 1.2)
		end
		x += rng:NextNumber(30, 45)
	end
end

-- Faroles entre las bases (y en las puntas), en el borde de adelante de la fila
local function buildLamps(map: Instance)
	local lamps = Instance.new("Folder")
	lamps.Name = "Lamps"
	lamps.Parent = map
	local rowWidth = cfg.BaseCount * cfg.PlotWidth + (cfg.BaseCount - 1) * cfg.PlotGap
	local z = -cfg.LobbyFrontWalk + 2
	for i = 0, cfg.BaseCount do
		local x = -rowWidth / 2 - cfg.PlotGap / 2 + i * (cfg.PlotWidth + cfg.PlotGap)
		local bottom = Vector3.new(x, cfg.FloorY, z)
		makeColumn("LampPost", 12, 0.8, bottom, Color3.fromRGB(60, 60, 75), lamps)
		local bulb = makePart("LampBulb", Vector3.new(2.4, 2.4, 2.4), CFrame.new(bottom + Vector3.new(0, 13, 0)), paletteColor(i + 1), lamps)
		bulb.Shape = Enum.PartType.Ball
		bulb.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = bulb.Color
		light.Range = 16
		light.Brightness = 1.5
		light.Parent = bulb
	end
end

-- Cantero de flores de colores a lo largo de la pared de atrás del lobby
local function buildFlowerBed(map: Instance)
	local bed = Instance.new("Folder")
	bed.Name = "FlowerBed"
	bed.Parent = map
	local z = -LOBBY_DEPTH + 3.5
	local width = LOBBY_WIDTH - 4
	makePart("Soil", Vector3.new(width, 1, 5), CFrame.new(0, cfg.FloorY + 0.5, z), Color3.fromRGB(110, 70, 45), bed)
	local rng = Random.new(7)
	local x = -width / 2 + 2
	while x < width / 2 - 2 do
		local position = Vector3.new(x, cfg.FloorY + 1, z + rng:NextNumber(-1.2, 1.2))
		local stemHeight = rng:NextNumber(1.5, 3)
		local stem = makePart("Stem", Vector3.new(0.3, stemHeight, 0.3), CFrame.new(position + Vector3.new(0, stemHeight / 2, 0)), Color3.fromRGB(60, 170, 60), bed)
		stem.CanCollide = false
		local flower = makePart("Flower", Vector3.new(1.6, 1.6, 1.6), CFrame.new(position + Vector3.new(0, stemHeight + 0.5, 0)), PALETTE[rng:NextInteger(1, #PALETTE)], bed)
		flower.Shape = Enum.PartType.Ball
		flower.CanCollide = false
		x += rng:NextNumber(2.5, 4)
	end
end

-- Cartel colgante con lo que falta para la tormenta y el evento. Lo escribe cada cliente (EventBoard.luau)
-- leyendo los atributos de la tormenta; acá solo armamos el cartel con dos renglones vacíos.
local function buildEventBoard(map: Instance)
	local model = Instance.new("Model")
	model.Name = "EventBoard"
	local metal = Color3.fromRGB(50, 55, 70)
	local poleX = -(HALF_WIDTH + 37) -- entre la entrada del pasillo y el tablero de récords
	local z = -6
	local top = cfg.FloorY + 34
	makePart("Pole", Vector3.new(1.5, top - cfg.FloorY, 1.5), CFrame.new(poleX, cfg.FloorY + (top - cfg.FloorY) / 2, z), metal, model)
	makePart("Arm", Vector3.new(34, 1.2, 1.2), CFrame.new(poleX + 17, top - 0.6, z), metal, model)
	local boardX = poleX + 19
	for _, dx in { -11, 11 } do
		makePart("Chain", Vector3.new(0.3, 3, 0.3), CFrame.new(boardX + dx, top - 2.7, z), metal, model)
	end
	local position = Vector3.new(boardX, top - 10.2, z)
	local board = makePart("Board", Vector3.new(30, 11, 1), CFrame.lookAt(position, position + Vector3.new(0, 0, -1)), Color3.fromRGB(25, 28, 40), model)
	board:SetAttribute("EventBoard", true)
	local frame = makePart("BoardFrame", Vector3.new(31, 12, 0.6), board.CFrame * CFrame.new(0, 0, 0.1), Color3.fromRGB(80, 200, 255), model)
	frame.Material = Enum.Material.Neon
	-- Dos renglones en cada cara (la de adelante mira al lobby, la de atrás al pasillo)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = board
		for i, name in { "Line1", "Line2" } do
			local label = Instance.new("TextLabel")
			label.Name = name
			label.Size = UDim2.fromScale(0.94, 0.42)
			label.Position = UDim2.fromScale(0.03, 0.06 + (i - 1) * 0.46)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Text = ""
			label.Parent = gui
		end
	end
	model.Parent = map
end

-- Puesto de mejoras en el lobby: abre la misma ventana que el panel de cada base (para cualquier jugador con base)
local function buildUpgradeStall(map: Instance)
	local stalls = Instance.new("Folder")
	stalls.Name = "UpgradeStalls"
	stalls.Parent = map
	local position = Vector3.new(HALF_WIDTH + 40, cfg.FloorY, -16)
	local kiosk = buildKiosk(CFrame.new(position), Color3.fromRGB(80, 200, 255), stalls)
	kiosk.Name = "UpgradeStall"
	local sign = makePart("StallSign", Vector3.new(15, 4, 0.6), CFrame.lookAt(position + Vector3.new(0, 14, -2), position + Vector3.new(0, 14, -3)), Color3.fromRGB(25, 28, 40), kiosk)
	addText(sign, Enum.NormalId.Front, "UPGRADES", Color3.fromRGB(255, 220, 80))
	-- Círculo que brilla delante del mostrador
	local glow = makeColumn("Glow", 0.2, 10, position + Vector3.new(0, 0.05, -10), Color3.fromRGB(80, 220, 255), kiosk)
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.35
	glow.CanCollide = false

	local counter = kiosk:FindFirstChild("CounterTop")
	if counter and counter:IsA("BasePart") then
		counter:SetAttribute("UpgradeStall", true)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = "Upgrades"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Shared", true) -- lo ve cualquiera que tenga base (ver UpgradePanel en el cliente)
		CollectionService:AddTag(prompt, "UpgradePrompt")
		prompt.Parent = counter
	end
end

local function buildLobby(map: Instance)
	-- Piso de arena con baldosas (la superficie Studs le da el dibujito de baldosas)
	makePart("LobbyFloor", Vector3.new(LOBBY_WIDTH, 2, LOBBY_DEPTH), CFrame.new(0, cfg.FloorY - 1, -LOBBY_DEPTH / 2), cfg.LobbyFloorColor, map, true)

	-- Volumen invisible de toda la zona segura (la ola de la fase 5 no hace nada acá adentro)
	makeMarker("SafeArea", Vector3.new(LOBBY_WIDTH, 60, LOBBY_DEPTH), CFrame.new(0, cfg.FloorY + 30, -LOBBY_DEPTH / 2), map)

	-- Línea blanca en el piso que marca el límite
	local line = makePart("SafeLine", Vector3.new(cfg.CorridorWidth, 0.2, 2), CFrame.new(0, cfg.FloorY + 0.1, 0), Color3.new(1, 1, 1), map)
	line.Material = Enum.Material.Neon
	line.CanCollide = false

	-- Arco con el cartel SAFE ZONE / DANGER ZONE
	local archHeight = 34
	-- Columnas a rayas de colores, como un caramelo
	local segment = archHeight / 8
	for _, side in { -1, 1 } do
		for i = 1, 8 do
			local color = if i % 2 == 0 then Color3.new(1, 1, 1) else paletteColor((i + 1) // 2)
			makePart("ArchPillar", Vector3.new(4, segment, 4), CFrame.new(side * (HALF_WIDTH - 4), cfg.FloorY + (i - 0.5) * segment, 0), color, map, true)
		end
	end
	-- La cara Front de esta Part mira al lobby y la Back mira al pasillo
	local beam = makePart("ArchSign", Vector3.new(cfg.CorridorWidth - 4, 10, 3), CFrame.lookAt(Vector3.new(0, cfg.FloorY + archHeight + 3, 0), Vector3.new(0, cfg.FloorY + archHeight + 3, -1)), Color3.fromRGB(40, 40, 50), map)
	addText(beam, Enum.NormalId.Front, "DANGER ZONE AHEAD", Color3.fromRGB(255, 90, 90))
	addText(beam, Enum.NormalId.Back, "SAFE ZONE", Color3.fromRGB(110, 255, 110))

	-- Palmeras en las esquinas de adelante del lobby, a los costados de la entrada del pasillo
	for _, side in { -1, 1 } do
		buildPalm(Vector3.new(side * (LOBBY_HALF_WIDTH - 12), cfg.FloorY, -10), map)
	end

	buildLamps(map)
	buildFlowerBed(map)

	-- Burbujas de vidrio con algas en las esquinas de adelante
	local rng = Random.new(12)
	for _, side in { -1, 1 } do
		buildBubbleDome(Vector3.new(side * (LOBBY_HALF_WIDTH - 22), cfg.FloorY, -30), 18, rng, map)
	end

	buildEventBoard(map)
	buildUpgradeStall(map)

	-- Tableros de récords en la pared de adelante del lobby, a cada lado de la entrada del pasillo,
	-- mirando hacia las bases. Los llena LeaderboardService.
	local boards = Instance.new("Folder")
	boards.Name = "Leaderboards"
	boards.Parent = map
	local boardSize = Vector3.new(56, 40, 1)
	if LOBBY_HALF_WIDTH - HALF_WIDTH > boardSize.X + 4 then
		for _, info in { { Side = -1, Id = "TopEarners" }, { Side = 1, Id = "EggsHatched" } } do
			local x = info.Side * (HALF_WIDTH + (LOBBY_HALF_WIDTH - HALF_WIDTH) / 2)
			local position = Vector3.new(x, cfg.FloorY + 40, -0.6) -- alto, para verse por encima de los carteles de las bases
			local facing = CFrame.lookAt(position, position + Vector3.new(0, 0, -1)) -- la cara Front mira al lobby
			local frame = makePart("BoardFrame", boardSize + Vector3.new(2, 2, -0.5), facing * CFrame.new(0, 0, 0.35), Color3.fromRGB(255, 205, 60), boards)
			frame.Material = Enum.Material.Neon
			local board = makePart("Leaderboard", boardSize, facing, Color3.fromRGB(30, 32, 48), boards)
			board:SetAttribute("Board", info.Id)
		end
	end
end

-- Tiras de banderines de colores que cruzan el pasillo, de pared a pared
local function buildBunting(corridor: Instance, length: number)
	local bunting = Instance.new("Folder")
	bunting.Name = "Bunting"
	bunting.Parent = corridor
	local y = cfg.FloorY + 50
	local i = 0
	for z = 80, length - 40, BUNTING_EVERY do
		local rope = makePart("Rope", Vector3.new(cfg.CorridorWidth, 0.3, 0.3), CFrame.new(0, y, z), Color3.new(1, 1, 1), bunting)
		rope.CanCollide = false
		rope.CanQuery = false
		local x = -HALF_WIDTH + 6
		while x < HALF_WIDTH - 4 do
			i += 1
			-- Un cuadrado girado 45° colgando de una punta parece un banderín
			local flag = makePart("Flag", Vector3.new(3, 3, 0.2), CFrame.new(x, y - 2.1, z) * CFrame.Angles(0, 0, math.rad(45)), paletteColor(i), bunting)
			flag.CanCollide = false
			flag.CanQuery = false
			x += 8
		end
	end
end

-- Caracoles y estrellas de mar de colores tirados en la arena (no molestan al caminar)
local function buildShells(corridor: Instance, length: number)
	local shells = Instance.new("Folder")
	shells.Name = "Shells"
	shells.Parent = corridor
	local rng = Random.new(31)
	for _ = 1, math.floor(length / 10) do
		local x = rng:NextNumber(-HALF_WIDTH + 4, HALF_WIDTH - 4)
		local z = rng:NextNumber(10, length - 5)
		local color = PALETTE[rng:NextInteger(1, #PALETTE)]
		local base = CFrame.new(x, cfg.FloorY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local parts: { Part } = {}
		if rng:NextNumber() < 0.7 then
			local shell = makePart("Shell", Vector3.new(1.6, 0.7, 1.4), base * CFrame.new(0, 0.3, 0), color, shells)
			shell.Shape = Enum.PartType.Ball
			table.insert(parts, shell)
		else
			-- Estrella de mar: 5 brazos
			for arm = 0, 4 do
				table.insert(parts, makePart("Starfish", Vector3.new(0.6, 0.25, 1.6), base * CFrame.Angles(0, math.rad(arm * 72), 0) * CFrame.new(0, 0.12, -0.7), color, shells))
			end
		end
		for _, part in parts do
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

local function buildCorridor(map: Instance)
	local corridor = Instance.new("Folder")
	corridor.Name = "Corridor"
	corridor.Parent = map

	local length = cfg.CorridorLength

	-- Piso turquesa, como agua bajita, con reflejos más claros
	makePart("WaterFloor", Vector3.new(cfg.CorridorWidth, 2, length), CFrame.new(0, cfg.FloorY - 1, length / 2), cfg.WaterFloorColor, corridor)
	local ripples = Instance.new("Folder")
	ripples.Name = "Ripples"
	ripples.Parent = corridor
	local rippleRng = Random.new(5)
	local rippleColor = cfg.WaterFloorColor:Lerp(Color3.new(1, 1, 1), 0.35)
	for _ = 1, math.floor(length / 8) do
		local x = rippleRng:NextNumber(-HALF_WIDTH + 6, HALF_WIDTH - 6)
		local z = rippleRng:NextNumber(5, length - 5)
		local ripple = makePart("Ripple", Vector3.new(rippleRng:NextNumber(6, 16), 0.05, rippleRng:NextNumber(1, 2.5)), CFrame.new(x, cfg.FloorY + 0.03, z) * CFrame.Angles(0, rippleRng:NextNumber(-0.3, 0.3), 0), rippleColor, ripples)
		ripple.CanCollide = false
		ripple.CanQuery = false
		ripple.CanTouch = false
	end

	-- Carteles de distancia en las dos paredes (cuanto más lejos, mejores huevos) y una raya en el piso
	local mark = 0
	for z = DISTANCE_MARK_EVERY, length - 50, DISTANCE_MARK_EVERY do
		mark += 1
		local farthest = z + DISTANCE_MARK_EVERY > length - 50
		for _, side in { -1, 1 } do
			-- Separado de la pared lo suficiente para quedar delante de las columnas
			local signPos = Vector3.new(side * (HALF_WIDTH - 2.6), cfg.FloorY + 26, z)
			local sign = makePart("DistanceSign", Vector3.new(22, 9, 1), CFrame.lookAt(signPos, signPos - Vector3.new(side, 0, 0)), Color3.fromRGB(40, 40, 50), corridor)
			local label = addText(sign, Enum.NormalId.Front, `{z}m`, if farthest then Color3.new(1, 1, 1) else paletteColor(mark))
			if farthest then
				addRainbow(label)
			end
		end
		local line = makePart("DistanceLine", Vector3.new(cfg.CorridorWidth - 2 * cfg.EggSideMargin, 0.1, 1.5), CFrame.new(0, cfg.FloorY + 0.05, z), paletteColor(mark), corridor)
		line.CanCollide = false
		line.CanQuery = false
		line.Transparency = 0.3
	end

	buildBunting(corridor, length)
	buildShells(corridor, length)

	-- Agua al fondo
	local sea = makePart("Sea", Vector3.new(cfg.CorridorWidth, 2, cfg.SeaDepth), CFrame.new(0, cfg.FloorY - 1.5, length + cfg.SeaDepth / 2), cfg.SeaColor, corridor)
	sea.Material = Enum.Material.Glass
	sea.Transparency = 0.2

	-- Decoración a los costados, en la franja entre donde caen los huevos y la pared.
	-- Usamos un Random con semilla fija para que el mapa salga siempre igual.
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = corridor
	local rng = Random.new(2025)
	local function randomColor(): Color3
		return PALETTE[rng:NextInteger(1, #PALETTE)]
	end

	local decorX = HALF_WIDTH - 13 -- centro de la franja de decoración
	for _, side in { -1, 1 } do
		-- Mirando hacia el centro del pasillo (frente = -Z local)
		local facing = CFrame.Angles(0, if side < 0 then -math.pi / 2 else math.pi / 2, 0)
		local z = 20 + (if side > 0 then 15 else 0)
		-- "Bolsa" de decoraciones: se mezcla y se van sacando de a una, así cada tramo tiene un poco de todo
		local bag: { string } = {}
		while z < length - 45 do
			if #bag == 0 then
				bag = { "Seaweed", "Seaweed", "Coral", "Coral", "Rocks", "Chest", "Umbrella", "Dome" }
				rng:Shuffle(bag)
			end
			local item = table.remove(bag) :: string
			local position = Vector3.new(side * decorX, cfg.FloorY, z)
			if item == "Seaweed" then
				buildSeaweed(position + Vector3.new(side * 4, 0, 0), rng, decor, 1.3)
				buildSeaweed(position + Vector3.new(-side * 3, 0, 5), rng, decor, 0.9)
				z += 20
			elseif item == "Coral" then
				buildCoral(position + Vector3.new(side * 3, 0, 0), rng, decor, 1.5)
				buildCoral(position + Vector3.new(-side * 4, 0, 6), rng, decor, 1)
				z += 20
			elseif item == "Dome" then
				buildBubbleDome(position + Vector3.new(side * 2, 0, 0), 11, rng, decor)
				z += 24
			elseif item == "Umbrella" then
				buildUmbrella(position + Vector3.new(side * 3, 0, 0), randomColor(), decor)
				buildTowel(CFrame.new(position + Vector3.new(-side * 3, 0, 1)) * facing, randomColor(), decor)
				if rng:NextNumber() < 0.5 then
					buildBeachBall(position + Vector3.new(-side * 7, 0, -4), randomColor(), decor)
				end
				z += 24
			elseif item == "Rocks" then
				buildRocks(position, rng, decor)
				z += 18
			else
				buildChest(position, rng, decor)
				z += 18
			end
		end
		-- Torre de guardavidas cerca del agua
		buildLifeguardTower(CFrame.new(Vector3.new(side * decorX, cfg.FloorY, length - 22)) * facing, decor)
	end
end

local PAD_HEIGHT = 0.6 -- altura de la plataforma de la base
local INCUBATOR_PAD_COLOR = Color3.fromRGB(255, 255, 255)

-- Distribución de los pads dentro de la base (coordenadas locales: -Z = adelante, hacia el pasillo).
-- Como en el dibujo: incubadoras en la fila de adelante, mascotas en dos columnas a los costados
-- y el medio libre para caminar. (El segundo piso con más mascotas llega con "mejorar base" en la fase 4.)
local INCUBATOR_COLUMNS = { -14, 0, 14 }
local INCUBATOR_ROWS = { -22 }
local INCUBATOR_PAD_SIZE = 10
local CREATURE_COLUMNS = { -15.5, 15.5 }
local CREATURE_ROWS = { -9, 2, 13, 24 }
local CREATURE_PAD_SIZE = 8
assert(#INCUBATOR_COLUMNS * #INCUBATOR_ROWS >= Config.Upgrades.MaxIncubators, "[MapBuilder] Not enough incubator pads for MaxIncubators")

-- Pad redondo (cilindro acostado) apoyado sobre la base
local function makePad(name: string, diameter: number, cframe: CFrame, color: Color3, parent: Instance): Part
	local pad = makePart(name, Vector3.new(0.3, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, parent)
	pad.Shape = Enum.PartType.Cylinder
	return pad
end

-- Piso de estantería: violeta con rayas lila. cframe es el centro de la cara de arriba.
-- Las rayas no chocan (son solo dibujo); lo que se pisa es el bloque violeta.
local function shelfDeck(name: string, size: Vector2, cframe: CFrame, parent: Instance): Part
	local deck = makePart(name, Vector3.new(size.X, 1, size.Y), cframe * CFrame.new(0, -0.5, 0), SHELF_DECK, parent)
	local stripeWidth = 2.5
	local x = -size.X / 2 + stripeWidth / 2
	while x < size.X / 2 do
		local stripe = makePart("DeckStripe", Vector3.new(stripeWidth, 0.05, size.Y), cframe * CFrame.new(x, 0.025, 0), SHELF_STRIPE, parent)
		stripe.CanCollide = false
		stripe.CanQuery = false
		x += stripeWidth * 2
	end
	return deck
end

-- Estantería de metal sobre la mitad de atrás de la base (como en el video): columnas, vigas y un techo a rayas.
-- El estante del medio aparece con la mejora "Base Floor" (lo arma BaseFloors).
local function buildShelf(model: Model, plotCFrame: CFrame)
	local shelf = Instance.new("Model")
	shelf.Name = "Shelf"
	local w, depth = cfg.PlotWidth, cfg.PlotDepth / 2
	for _, x in { -w / 2 + 0.6, w / 2 - 0.6 } do
		for _, z in { 0.6, depth - 0.6 } do
			makePart("ShelfPost", Vector3.new(1.2, SHELF_TOP, 1.2), plotCFrame * CFrame.new(x, SHELF_TOP / 2, z), SHELF_FRAME, shelf)
		end
	end
	-- Vigas a la altura del estante del medio (adelante, atrás y a los costados)
	for _, y in { SHELF_LEVEL - 0.5, SHELF_TOP - 0.5 } do
		for _, z in { 0.6, depth - 0.6 } do
			makePart("ShelfBeam", Vector3.new(w, 1, 1), plotCFrame * CFrame.new(0, y, z), SHELF_FRAME, shelf)
		end
		for _, x in { -w / 2 + 0.6, w / 2 - 0.6 } do
			makePart("ShelfBeam", Vector3.new(1, 1, depth), plotCFrame * CFrame.new(x, y, depth / 2), SHELF_FRAME, shelf)
		end
	end
	shelfDeck("ShelfRoof", Vector2.new(w + 1, depth + 1), plotCFrame * CFrame.new(0, SHELF_TOP + 1, depth / 2), shelf)
	shelf.Parent = model
end

local function buildSign(model: Model, plotCFrame: CFrame)
	-- Detrás de la base, mirando hacia el pasillo (la cara Front del cartel mira para el mismo lado que la base)
	local signZ = cfg.PlotDepth / 2 + 4
	-- Alto, para que se vea por encima del techo de la estantería
	for _, x in { -14, 14 } do
		makePart("SignPost", Vector3.new(1.5, SHELF_TOP + 9, 1.5), plotCFrame * CFrame.new(x, (SHELF_TOP + 9) / 2, signZ), SHELF_FRAME, model)
	end
	local board = makePart("SignBoard", Vector3.new(32, 8, 1), plotCFrame * CFrame.new(0, SHELF_TOP + 6, signZ), Color3.fromRGB(25, 28, 40), model)
	addText(board, Enum.NormalId.Front, "Free Base", Color3.fromRGB(200, 200, 200), "SignLabel")
end

-- Panel de mejoras: un poste con una pantalla inclinada. Al acercarte aparece "Open" (abre la ventana de mejoras).
-- cframe está a nivel del piso de la base y su frente (-Z) mira hacia el pasillo.
local function buildUpgradePanel(model: Model, baseId: number, cframe: CFrame, color: Color3)
	local panel = Instance.new("Model")
	panel.Name = "UpgradePanel"
	makePart("Post", Vector3.new(1.2, 4, 1.2), cframe * CFrame.new(0, 2, 0), Color3.fromRGB(60, 60, 70), panel)
	-- Pantalla inclinada hacia atrás, como un atril
	local screenCFrame = cframe * CFrame.new(0, 5.5, 0) * CFrame.Angles(math.rad(15), 0, 0)
	local frame = makePart("Frame", Vector3.new(9, 5.6, 0.5), screenCFrame * CFrame.new(0, 0, 0.3), color, panel)
	frame.Material = Enum.Material.Neon
	local screen = makePart("Screen", Vector3.new(8.4, 5, 0.6), screenCFrame, Color3.fromRGB(25, 25, 35), panel)
	addText(screen, Enum.NormalId.Front, "UPGRADES", Color3.fromRGB(255, 220, 80))
	panel.PrimaryPart = screen

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Upgrades"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("BaseId", baseId)
	CollectionService:AddTag(prompt, "UpgradePrompt") -- el cliente abre la ventana y lo esconde en bases ajenas
	prompt.Parent = screen

	panel.Parent = model
end

local function buildBase(index: number, position: Vector3, parent: Instance): Model
	-- Mirando hacia el pasillo (+Z del mundo). En coordenadas locales: -Z = adelante, +Z = atrás.
	local plotCFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
	local color = cfg.BaseColor
	local w, d = cfg.PlotWidth, cfg.PlotDepth

	local model = Instance.new("Model")
	model.Name = `Base{index}`
	model:SetAttribute("BaseId", index)
	model:SetAttribute("OwnerUserId", 0)

	-- Piso gris (todas las bases iguales), con un borde más oscuro
	local edge = makePart("Edge", Vector3.new(w, PAD_HEIGHT, d), plotCFrame * CFrame.new(0, PAD_HEIGHT / 2, 0), color:Lerp(Color3.new(0, 0, 0), 0.25), model, true)
	model.PrimaryPart = edge
	makePart("Floor", Vector3.new(w - 3, 0.1, d - 3), plotCFrame * CFrame.new(0, PAD_HEIGHT + 0.05, 0), color, model, true)
	local surfaceY = PAD_HEIGHT + 0.1 -- donde se apoya todo lo de arriba

	-- Pads de incubadoras (la fase 3 pone la incubadora encima). Se numeran de izquierda a derecha, de adelante hacia atrás.
	local incubatorSlots = Instance.new("Folder")
	incubatorSlots.Name = "IncubatorSlots"
	incubatorSlots.Parent = model
	local slot = 0
	for _, z in INCUBATOR_ROWS do
		for _, x in INCUBATOR_COLUMNS do
			slot += 1
			local pad = makePad(`IncubatorSlot{slot}`, INCUBATOR_PAD_SIZE, plotCFrame * CFrame.new(x, surfaceY + 0.15, z), INCUBATOR_PAD_COLOR, incubatorSlots)
			pad:SetAttribute("SlotIndex", slot)
		end
	end

	-- Pads de mascotas: columna izquierda de adelante hacia atrás, después la derecha
	local creatureSlots = Instance.new("Folder")
	creatureSlots.Name = "CreatureSlots"
	creatureSlots.Parent = model
	local creaturePadColor = color:Lerp(Color3.new(0, 0, 0), 0.3)
	slot = 0
	for _, x in CREATURE_COLUMNS do
		for _, z in CREATURE_ROWS do
			slot += 1
			local pad = makePad(`CreatureSlot{slot}`, CREATURE_PAD_SIZE, plotCFrame * CFrame.new(x, surfaceY + 0.15, z), creaturePadColor, creatureSlots)
			pad:SetAttribute("SlotIndex", slot)
		end
	end

	-- Lugar donde aparece el jugador (en el medio libre, mirando al pasillo)
	local spawnPoint = makePart("SpawnPoint", Vector3.new(8, 0.2, 8), plotCFrame * CFrame.new(0, surfaceY + 0.1, -6), Color3.new(1, 1, 1), model)
	spawnPoint.Transparency = 0.5
	spawnPoint.CanCollide = false
	spawnPoint.CanQuery = false
	spawnPoint.Material = Enum.Material.Neon

	-- Panel de mejoras: atrás, en el medio
	buildUpgradePanel(model, index, plotCFrame * CFrame.new(0, surfaceY, d / 2 - 6), ACCENT)

	-- Volumen invisible de la base (para saber si alguien está adentro)
	makeMarker("SafeZone", Vector3.new(w, 30, d), plotCFrame * CFrame.new(0, 15, 0), model)

	buildShelf(model, plotCFrame)
	buildSign(model, plotCFrame)

	model.Parent = parent
	return model
end

local function buildBases(map: Instance)
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = map

	-- Todas en una fila de izquierda a derecha, centrada, mirando al pasillo
	local rowWidth = cfg.BaseCount * cfg.PlotWidth + (cfg.BaseCount - 1) * cfg.PlotGap
	local z = -cfg.LobbyFrontWalk - cfg.PlotDepth / 2
	for i = 1, cfg.BaseCount do
		local x = -rowWidth / 2 + cfg.PlotWidth / 2 + (i - 1) * (cfg.PlotWidth + cfg.PlotGap)
		buildBase(i, Vector3.new(x, cfg.FloorY, z), basesFolder)
	end
end

function MapBuilder.Build(): Folder
	local existing = Workspace:FindFirstChild("Map")
	if existing and existing:IsA("Folder") then
		return existing
	end

	-- El Baseplate de la plantilla de Studio queda a la misma altura que nuestro piso y "parpadea".
	local templateBaseplate = Workspace:FindFirstChild("Baseplate")
	if templateBaseplate then
		warn("[MapBuilder] Removing template Baseplate (Egg Storm builds its own ground)")
		templateBaseplate:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "Map"

	buildWalls(map)
	buildLobby(map)
	buildCorridor(map)
	buildBases(map)

	map.Parent = Workspace
	return map
end

return MapBuilder

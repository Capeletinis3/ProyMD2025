--!strict
-- MapBuilder: arma el mapa placeholder con Parts simples (estilo bloques/LEGO, colorido).
--
-- Forma del mapa (visto desde arriba, en forma de T), eje Z de abajo hacia arriba:
--
--             ┌──── agua (de acá sale la ola) ────┐         Z = CorridorLength + SeaDepth
--             │  SECRET / LEGENDARY / EPIC / ...  │         pasillo de arena (peligro)
--             │  ... / RARE / COMMON zones        │
--   ┌─────────┴──────── arco "SAFE ZONE" ─────────┴────────┐ Z = 0  (línea segura)
--   │  ↑     ↑     ↑     ↑     ↑     ↑     ↑     ↑        │ lobby verde (seguro)
--   │ [B1]  [B2]  [B3]  [B4]  [B5]  [B6]  [B7]  [B8]       │ bases mirando al pasillo
--   └──────────────────────────────────────────────────────┘ Z = -(LobbyFrontWalk + PlotDepth + LobbyBackMargin)
--
-- Si en Workspace ya existe una carpeta "Map" (por ejemplo, cuando reemplaces los modelos a mano),
-- no construye nada y usa esa. Solo tiene que respetar la misma estructura:
--   Map/Bases/BaseN (Model con atributo BaseId) con SpawnPoint, SafeZone y un TextLabel "SignLabel".

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
local function buildKiosk(cframe: CFrame, stripeColor: Color3, parent: Instance)
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

local function buildCrates(position: Vector3, rng: Random, parent: Instance)
	local wood = Color3.fromRGB(170, 120, 70)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	makePart("Crate", Vector3.new(4, 4, 4), CFrame.new(position + Vector3.new(0, 2, 0)) * yaw, wood, parent, true)
	makePart("Crate", Vector3.new(4, 4, 4), CFrame.new(position + Vector3.new(0, 2, 0)) * yaw * CFrame.new(4.2, 0, 0), wood, parent, true)
	makePart("Crate", Vector3.new(4, 4, 4), CFrame.new(position + Vector3.new(0, 6, 0)) * yaw * CFrame.new(2, 0, 0) * CFrame.Angles(0, 0.3, 0), wood:Lerp(Color3.new(0, 0, 0), 0.1), parent, true)
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

	-- Pared con su borde verde arriba. size/position describen el bloque de la pared.
	local function wall(name: string, size: Vector3, position: Vector3)
		makePart(name, size, CFrame.new(position), cfg.WallColor, walls, true)
		makePart("Trim", Vector3.new(size.X + 2, 2, size.Z + 2), CFrame.new(position.X, h + 1, position.Z), cfg.WallTrimColor, walls, true)
	end

	-- Paredes del pasillo (de la línea segura hasta el fondo)
	local corridorLength = farZ + t
	for _, side in { -1, 1 } do
		wall("CorridorWall", Vector3.new(t, h, corridorLength), Vector3.new(side * (HALF_WIDTH + t / 2), h / 2, corridorLength / 2))
		-- Columnas más oscuras cada tanto para que la pared no sea un bloque liso
		local z = 30
		while z < farZ do
			makePart("Pillar", Vector3.new(2, h, 6), CFrame.new(side * (HALF_WIDTH - 1), h / 2, z), pillarColor, walls, true)
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
end

local function buildLobby(map: Instance)
	makePart("LobbyFloor", Vector3.new(LOBBY_WIDTH, 2, LOBBY_DEPTH), CFrame.new(0, cfg.FloorY - 1, -LOBBY_DEPTH / 2), cfg.GrassColor, map, true)

	-- Volumen invisible de toda la zona segura (la ola de la fase 5 no hace nada acá adentro)
	makeMarker("SafeArea", Vector3.new(LOBBY_WIDTH, 60, LOBBY_DEPTH), CFrame.new(0, cfg.FloorY + 30, -LOBBY_DEPTH / 2), map)

	-- Línea blanca en el piso que marca el límite
	local line = makePart("SafeLine", Vector3.new(cfg.CorridorWidth, 0.2, 2), CFrame.new(0, cfg.FloorY + 0.1, 0), Color3.new(1, 1, 1), map)
	line.Material = Enum.Material.Neon
	line.CanCollide = false

	-- Arco con el cartel SAFE ZONE / DANGER ZONE
	local archHeight = 34
	for _, side in { -1, 1 } do
		makePart("ArchPillar", Vector3.new(4, archHeight, 4), CFrame.new(side * (HALF_WIDTH - 4), cfg.FloorY + archHeight / 2, 0), Color3.fromRGB(255, 255, 255), map, true)
	end
	-- La cara Front de esta Part mira al lobby y la Back mira al pasillo
	local beam = makePart("ArchSign", Vector3.new(cfg.CorridorWidth - 4, 10, 3), CFrame.lookAt(Vector3.new(0, cfg.FloorY + archHeight + 3, 0), Vector3.new(0, cfg.FloorY + archHeight + 3, -1)), Color3.fromRGB(40, 40, 50), map)
	addText(beam, Enum.NormalId.Front, "DANGER ZONE AHEAD", Color3.fromRGB(255, 90, 90))
	addText(beam, Enum.NormalId.Back, "SAFE ZONE", Color3.fromRGB(110, 255, 110))

	-- Palmeras en las esquinas de adelante del lobby, a los costados de la entrada del pasillo
	for _, side in { -1, 1 } do
		buildPalm(Vector3.new(side * (LOBBY_HALF_WIDTH - 12), cfg.FloorY, -10), map)
	end
end

local function buildCorridor(map: Instance)
	local corridor = Instance.new("Folder")
	corridor.Name = "Corridor"
	corridor.Parent = map

	local length = cfg.CorridorLength

	-- Piso de arena de un solo color
	makePart("Sand", Vector3.new(cfg.CorridorWidth, 2, length), CFrame.new(0, cfg.FloorY - 1, length / 2), cfg.SandColor, corridor, true)

	-- Carteles de cada zona en las dos paredes, mirando hacia el centro del pasillo
	for _, rarity in Config.Rarities do
		local z0 = rarity.ZoneStart * length
		for _, side in { -1, 1 } do
			-- Separado de la pared lo suficiente para quedar delante de las columnas
			local signPos = Vector3.new(side * (HALF_WIDTH - 2.6), cfg.FloorY + 26, z0 + 18)
			local sign = makePart("ZoneSign", Vector3.new(30, 8, 1), CFrame.lookAt(signPos, signPos - Vector3.new(side, 0, 0)), Color3.fromRGB(40, 40, 50), corridor)
			local label = addText(sign, Enum.NormalId.Front, `{string.upper(rarity.DisplayName)} ZONE`, if rarity.Id == "Secret" then Color3.new(1, 1, 1) else rarity.Color)
			if rarity.Id == "Secret" then
				addRainbow(label)
			end
		end
	end

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
	local colors = {
		Color3.fromRGB(255, 80, 120),
		Color3.fromRGB(80, 170, 255),
		Color3.fromRGB(255, 200, 60),
		Color3.fromRGB(180, 90, 255),
		Color3.fromRGB(80, 220, 120),
		Color3.fromRGB(255, 140, 60),
	}
	local function randomColor(): Color3
		return colors[rng:NextInteger(1, #colors)]
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
				bag = { "Palm", "Palm", "Umbrella", "Umbrella", "Kiosk", "Rocks", "Crates" }
				rng:Shuffle(bag)
			end
			local item = table.remove(bag) :: string
			local position = Vector3.new(side * decorX, cfg.FloorY, z)
			if item == "Palm" then
				buildPalm(position + Vector3.new(side * 2, 0, 0), decor)
				z += 26
			elseif item == "Umbrella" then
				buildUmbrella(position + Vector3.new(side * 3, 0, 0), randomColor(), decor)
				buildTowel(CFrame.new(position + Vector3.new(-side * 3, 0, 1)) * facing, randomColor(), decor)
				if rng:NextNumber() < 0.5 then
					buildBeachBall(position + Vector3.new(-side * 7, 0, -4), randomColor(), decor)
				end
				z += 24
			elseif item == "Kiosk" then
				buildKiosk(CFrame.new(position + Vector3.new(side * 2, 0, 0)) * facing, randomColor(), decor)
				z += 26
			elseif item == "Rocks" then
				buildRocks(position, rng, decor)
				z += 18
			else
				buildCrates(position, rng, decor)
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

local function buildSign(model: Model, plotCFrame: CFrame)
	-- Detrás de la base, mirando hacia el pasillo (la cara Front del cartel mira para el mismo lado que la base)
	local signZ = cfg.PlotDepth / 2 + 4
	for _, x in { -14, 14 } do
		makePart("SignPost", Vector3.new(1.5, 18, 1.5), plotCFrame * CFrame.new(x, 9, signZ), Color3.fromRGB(90, 60, 40), model)
	end
	local board = makePart("SignBoard", Vector3.new(32, 8, 1), plotCFrame * CFrame.new(0, 15, signZ), Color3.fromRGB(60, 45, 35), model)
	addText(board, Enum.NormalId.Front, "Free Base", Color3.fromRGB(200, 200, 200), "SignLabel")
end

local function buildBase(index: number, position: Vector3, parent: Instance): Model
	-- Mirando hacia el pasillo (+Z del mundo). En coordenadas locales: -Z = adelante, +Z = atrás.
	local plotCFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
	local color = cfg.BaseColors[index] or Color3.new(1, 1, 1)
	local w, d = cfg.PlotWidth, cfg.PlotDepth

	local model = Instance.new("Model")
	model.Name = `Base{index}`
	model:SetAttribute("BaseId", index)
	model:SetAttribute("OwnerUserId", 0)

	-- Piso del color de la base, con un borde más oscuro
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
	local creaturePadColor = color:Lerp(Color3.new(0, 0, 0), 0.4)
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

	-- Lugar reservado para el panel de mejoras (fase 4): atrás, en el medio
	makeMarker("UpgradeSpot", Vector3.new(1, 1, 1), plotCFrame * CFrame.new(0, surfaceY, d / 2 - 6), model)

	-- Volumen invisible de la base (para saber si alguien está adentro)
	makeMarker("SafeZone", Vector3.new(w, 30, d), plotCFrame * CFrame.new(0, 15, 0), model)

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

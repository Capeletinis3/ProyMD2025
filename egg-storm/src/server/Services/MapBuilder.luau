--!strict
-- MapBuilder: arma el mapa placeholder con Parts simples (estilo bloques/LEGO, colorido).
--
-- Forma del mapa (visto desde arriba), eje Z de abajo hacia arriba:
--
--   ┌──────────── agua (de acá sale la ola) ────────────┐   Z = CorridorLength + SeaDepth
--   │  SECRET / LEGENDARY / EPIC / RARE / COMMON zones   │   pasillo de arena (peligro)
--   ├──────────────── arco "SAFE ZONE" ──────────────────┤   Z = 0  (línea segura)
--   │ [Base1]                                   [Base5]  │
--   │ [Base2]          camino central           [Base6]  │   lobby verde (seguro)
--   │ [Base3]                                   [Base7]  │
--   │ [Base4]                                   [Base8]  │
--   └────────────────────────────────────────────────────┘   Z = -LobbyDepth
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

-- ===== Partes del mapa =====

local function buildWalls(map: Instance)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = map

	local t = cfg.WallThickness
	local h = cfg.WallHeight
	local farZ = cfg.CorridorLength + cfg.SeaDepth
	local nearZ = -cfg.LobbyDepth
	local length = farZ - nearZ + t * 2
	local midZ = (farZ + nearZ) / 2

	for _, side in { -1, 1 } do
		local x = side * (HALF_WIDTH + t / 2)
		makePart("SideWall", Vector3.new(t, h, length), CFrame.new(x, h / 2, midZ), cfg.WallColor, walls, true)
		makePart("Trim", Vector3.new(t + 2, 2, length), CFrame.new(x, h + 1, midZ), cfg.WallTrimColor, walls, true)
		-- Columnas más oscuras cada tanto para que la pared no sea un bloque liso
		local z = nearZ + 30
		while z < farZ do
			makePart("Pillar", Vector3.new(2, h, 6), CFrame.new(side * (HALF_WIDTH - 1), h / 2, z), cfg.WallColor:Lerp(Color3.new(0, 0, 0), 0.2), walls, true)
			z += 60
		end
	end

	local fullWidth = cfg.CorridorWidth + t * 2
	makePart("BackWall", Vector3.new(fullWidth, h, t), CFrame.new(0, h / 2, nearZ - t / 2), cfg.WallColor, walls, true)
	makePart("Trim", Vector3.new(fullWidth, 2, t + 2), CFrame.new(0, h + 1, nearZ - t / 2), cfg.WallTrimColor, walls, true)
	makePart("FarWall", Vector3.new(fullWidth, h, t), CFrame.new(0, h / 2, farZ + t / 2), cfg.WallColor, walls, true)
	makePart("Trim", Vector3.new(fullWidth, 2, t + 2), CFrame.new(0, h + 1, farZ + t / 2), cfg.WallTrimColor, walls, true)
end

local function buildLobby(map: Instance)
	local lobby = makePart("LobbyFloor", Vector3.new(cfg.CorridorWidth, 2, cfg.LobbyDepth), CFrame.new(0, cfg.FloorY - 1, -cfg.LobbyDepth / 2), cfg.GrassColor, map, true)
	lobby.Material = Enum.Material.SmoothPlastic

	-- Volumen invisible de toda la zona segura (la ola de la fase 5 no hace nada acá adentro)
	makeMarker("SafeArea", Vector3.new(cfg.CorridorWidth, 60, cfg.LobbyDepth), CFrame.new(0, cfg.FloorY + 30, -cfg.LobbyDepth / 2), map)

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

	-- Palmeras en el fondo del camino central (los costados están ocupados por las bases)
	for _, x in { -35, 35 } do
		buildPalm(Vector3.new(x, cfg.FloorY, -cfg.LobbyDepth + 12), map)
	end
end

local function buildCorridor(map: Instance)
	local corridor = Instance.new("Folder")
	corridor.Name = "Corridor"
	corridor.Parent = map

	local length = cfg.CorridorLength

	-- Primer tramo (antes de la zona Common): arena lisa
	local firstZone = Config.Rarities[1].ZoneStart * length
	if firstZone > 0 then
		makePart("Sand", Vector3.new(cfg.CorridorWidth, 2, firstZone), CFrame.new(0, cfg.FloorY - 1, firstZone / 2), cfg.SandColor, corridor, true)
	end

	-- Un tramo de piso por rareza, con el color de la arena mezclado con el de la rareza
	for _, rarity in Config.Rarities do
		local z0 = rarity.ZoneStart * length
		local z1 = rarity.ZoneEnd * length
		local tint = if rarity.Id == "Secret" then Color3.fromRGB(120, 60, 160) else rarity.Color
		makePart(`{rarity.Id}Zone`, Vector3.new(cfg.CorridorWidth, 2, z1 - z0), CFrame.new(0, cfg.FloorY - 1, (z0 + z1) / 2), cfg.SandColor:Lerp(tint, 0.45), corridor, true)

		-- Franja de color donde empieza la zona
		local stripe = makePart("ZoneStripe", Vector3.new(cfg.CorridorWidth, 0.2, 1.5), CFrame.new(0, cfg.FloorY + 0.1, z0), tint, corridor)
		stripe.Material = Enum.Material.Neon
		stripe.CanCollide = false

		-- Cartel en cada pared, mirando hacia el centro del pasillo
		for _, side in { -1, 1 } do
			-- Separado de la pared lo suficiente para quedar delante de las columnas
			local signPos = Vector3.new(side * (HALF_WIDTH - 2.6), cfg.FloorY + 22, z0 + 18)
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

	-- Decoración a los costados
	local umbrellaColors = { Color3.fromRGB(255, 80, 120), Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 200, 60), Color3.fromRGB(180, 90, 255) }
	local z = 40
	local i = 0
	while z < length - 20 do
		i += 1
		local side = if i % 2 == 0 then 1 else -1
		buildPalm(Vector3.new(side * (HALF_WIDTH - 8), cfg.FloorY, z), corridor)
		buildUmbrella(Vector3.new(-side * (HALF_WIDTH - 9), cfg.FloorY, z + 30), umbrellaColors[(i % #umbrellaColors) + 1], corridor)
		z += 80
	end
end

local function buildSign(model: Model, plotCFrame: CFrame)
	local signZ = cfg.PlotDepth / 2 - 2 -- cerca del borde de atrás (contra la pared)
	for _, x in { -11, 11 } do
		makePart("SignPost", Vector3.new(1, 12, 1), plotCFrame * CFrame.new(x, 6, signZ), Color3.fromRGB(90, 60, 40), model)
	end
	-- plotCFrame mira hacia el camino central, así que la cara Front del cartel también
	local board = makePart("SignBoard", Vector3.new(24, 6, 1), plotCFrame * CFrame.new(0, 11, signZ), Color3.fromRGB(60, 45, 35), model)
	addText(board, Enum.NormalId.Front, "Free Base", Color3.fromRGB(200, 200, 200), "SignLabel")
end

local function buildBase(index: number, position: Vector3, parent: Instance): Model
	-- Mirando hacia el camino central. En coordenadas locales: -Z = hacia el camino, +Z = hacia la pared.
	local plotCFrame = CFrame.lookAt(position, Vector3.new(0, position.Y, position.Z))
	local color = cfg.BaseColors[index] or Color3.new(1, 1, 1)
	local w, d = cfg.PlotWidth, cfg.PlotDepth
	local padHeight = 0.6

	local model = Instance.new("Model")
	model.Name = `Base{index}`
	model:SetAttribute("BaseId", index)
	model:SetAttribute("OwnerUserId", 0)

	local floor = makePart("Floor", Vector3.new(w, padHeight, d), plotCFrame * CFrame.new(0, padHeight / 2, 0), color, model, true)
	model.PrimaryPart = floor

	-- Baldosas más claras en damero, encima del piso de la base
	local light = color:Lerp(Color3.new(1, 1, 1), 0.45)
	local tilesX, tilesZ = 4, 4
	local tileW, tileD = w / tilesX, d / tilesZ
	for tx = 0, tilesX - 1 do
		for tz = 0, tilesZ - 1 do
			if (tx + tz) % 2 == 0 then
				local x = -w / 2 + tileW * (tx + 0.5)
				local z = -d / 2 + tileD * (tz + 0.5)
				local tile = makePart("Tile", Vector3.new(tileW, 0.1, tileD), plotCFrame * CFrame.new(x, padHeight + 0.05, z), light, model, true)
				tile.CanCollide = false
			end
		end
	end

	-- Borde bajo atrás y a los costados (el frente queda abierto)
	local rimY = padHeight + 0.75
	makePart("Rim", Vector3.new(w, 1.5, 1), plotCFrame * CFrame.new(0, rimY, d / 2 - 0.5), color, model, true)
	makePart("Rim", Vector3.new(1, 1.5, d), plotCFrame * CFrame.new(-w / 2 + 0.5, rimY, 0), color, model, true)
	makePart("Rim", Vector3.new(1, 1.5, d), plotCFrame * CFrame.new(w / 2 - 0.5, rimY, 0), color, model, true)

	-- Lugar donde aparece el jugador
	local spawnPoint = makePart("SpawnPoint", Vector3.new(8, 0.2, 8), plotCFrame * CFrame.new(0, padHeight + 0.15, -d / 2 + 8), Color3.new(1, 1, 1), model)
	spawnPoint.Transparency = 0.5
	spawnPoint.CanCollide = false
	spawnPoint.CanQuery = false
	spawnPoint.Material = Enum.Material.Neon

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

	local perSide = math.ceil(cfg.BaseCount / 2)
	local x = HALF_WIDTH - cfg.PlotDepth / 2 - 4
	for i = 1, cfg.BaseCount do
		-- Bases 1..4 a la izquierda y 5..8 a la derecha, empezando por las más cercanas a la arena
		local side = if i <= perSide then -1 else 1
		local row = (i - 1) % perSide
		local z = -cfg.PlotWidth / 2 - 12 - row * (cfg.PlotWidth + cfg.PlotGap)
		buildBase(i, Vector3.new(side * x, cfg.FloorY, z), basesFolder)
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

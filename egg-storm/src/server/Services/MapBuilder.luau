--!strict
-- MapBuilder: arma el mapa placeholder con Parts simples (estilo low-poly y colorido).
-- Si en Workspace ya existe una carpeta "Map" (por ejemplo, cuando reemplaces los modelos a mano),
-- no construye nada y usa esa. Solo tiene que respetar la misma estructura:
--   Map/Bases/BaseN (Model con atributo BaseId) con SpawnPoint, SafeZone y un TextLabel "SignLabel".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
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

local function buildSign(model: Model, baseCFrame: CFrame, floorTop: number)
	local cfg = Config.Map
	local signZ = cfg.BaseDepth / 2 - 3 -- cerca del borde de atrás

	for _, x in { -12, 12 } do
		makePart("SignPost", Vector3.new(1, 12, 1), baseCFrame * CFrame.new(x, floorTop + 6, signZ), Color3.fromRGB(90, 60, 40), model)
	end

	-- baseCFrame mira hacia el centro del mapa, así que la cara "Front" del cartel también.
	local board = makePart("SignBoard", Vector3.new(26, 7, 1), baseCFrame * CFrame.new(0, floorTop + 10, signZ), Color3.fromRGB(60, 45, 35), model)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "SignLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.Text = "Free Base"
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
end

local function buildBase(index: number, parent: Instance): Model
	local cfg = Config.Map
	local angle = (index - 1) / cfg.BaseCount * math.pi * 2
	local center = Vector3.new(math.cos(angle) * cfg.BaseRingRadius, 0, math.sin(angle) * cfg.BaseRingRadius)

	-- CFrame de la base a nivel del piso, mirando hacia el centro del mapa.
	-- En coordenadas locales: -Z = hacia el centro, +Z = hacia afuera.
	local baseCFrame = CFrame.lookAt(center, Vector3.zero)
	local color = cfg.BaseColors[index] or Color3.new(1, 1, 1)
	local floorTop = cfg.BaseHeight + 1

	local model = Instance.new("Model")
	model.Name = `Base{index}`
	model:SetAttribute("BaseId", index)
	model:SetAttribute("OwnerUserId", 0)

	-- Bloque que eleva la base
	makePart("Foundation", Vector3.new(cfg.BaseWidth, cfg.BaseHeight, cfg.BaseDepth), baseCFrame * CFrame.new(0, cfg.BaseHeight / 2, 0), cfg.BaseFoundationColor, model)

	-- Piso de la base, con el color del dueño
	local floor = makePart("Floor", Vector3.new(cfg.BaseWidth, 1, cfg.BaseDepth), baseCFrame * CFrame.new(0, cfg.BaseHeight + 0.5, 0), color, model)
	model.PrimaryPart = floor

	-- Paredes bajas atrás y a los costados (el frente queda abierto para la rampa)
	local wallY = floorTop + cfg.WallHeight / 2
	makePart("Wall", Vector3.new(cfg.BaseWidth, cfg.WallHeight, 2), baseCFrame * CFrame.new(0, wallY, cfg.BaseDepth / 2 - 1), color, model)
	makePart("Wall", Vector3.new(2, cfg.WallHeight, cfg.BaseDepth), baseCFrame * CFrame.new(-cfg.BaseWidth / 2 + 1, wallY, 0), color, model)
	makePart("Wall", Vector3.new(2, cfg.WallHeight, cfg.BaseDepth), baseCFrame * CFrame.new(cfg.BaseWidth / 2 - 1, wallY, 0), color, model)

	-- Rampa: va desde el borde delantero de la base hasta el piso, en dirección al centro
	local rampTop = baseCFrame:PointToWorldSpace(Vector3.new(0, floorTop, -cfg.BaseDepth / 2))
	local rampBottom = baseCFrame:PointToWorldSpace(Vector3.new(0, 0, -cfg.BaseDepth / 2 - cfg.RampLength))
	local rampThickness = 2
	local rampCFrame = CFrame.lookAt((rampTop + rampBottom) / 2, rampTop) * CFrame.new(0, -rampThickness / 2, 0)
	makePart("Ramp", Vector3.new(cfg.RampWidth, rampThickness, (rampTop - rampBottom).Magnitude + 1), rampCFrame, cfg.RampColor, model)

	-- Lugar donde aparece el jugador (un poco hacia atrás, mirando al centro)
	local spawnPoint = makePart("SpawnPoint", Vector3.new(8, 0.2, 8), baseCFrame * CFrame.new(0, floorTop + 0.1, 12), Color3.new(1, 1, 1), model)
	spawnPoint.Transparency = 0.5
	spawnPoint.CanCollide = false
	spawnPoint.CanQuery = false
	spawnPoint.Material = Enum.Material.Neon

	-- Volumen invisible que marca la "zona segura" (lo usa la ola en la fase 5)
	makeMarker("SafeZone", Vector3.new(cfg.BaseWidth, 40, cfg.BaseDepth), baseCFrame * CFrame.new(0, floorTop + 20, 0), model)

	buildSign(model, baseCFrame, floorTop)

	model.Parent = parent
	return model
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

	local cfg = Config.Map
	local map = Instance.new("Folder")
	map.Name = "Map"

	-- Piso general (la parte de arriba queda en Y = 0)
	local ground = makePart("Ground", Vector3.new(cfg.GroundSize, 4, cfg.GroundSize), CFrame.new(0, -2, 0), cfg.GroundColor, map)
	ground.Material = Enum.Material.Grass

	-- Zona de peligro: disco central donde van a caer los huevos.
	-- Los cilindros de Roblox tienen el eje en X, por eso lo rotamos 90° para que quede "acostado".
	local dangerZone = makePart(
		"DangerZone",
		Vector3.new(0.4, cfg.DangerZoneRadius * 2, cfg.DangerZoneRadius * 2),
		CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		cfg.DangerZoneColor,
		map
	)
	dangerZone.Shape = Enum.PartType.Cylinder
	dangerZone.Material = Enum.Material.Sand

	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = map
	for i = 1, cfg.BaseCount do
		buildBase(i, basesFolder)
	end

	map.Parent = Workspace
	return map
end

return MapBuilder

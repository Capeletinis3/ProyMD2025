--!strict
-- MapBuilder: arma el mapa "Isla tropical + volcán" con Parts simples (ver MAPA_SPEC.md).
--
-- Visto desde arriba (+X hacia la derecha, -Z arriba):
--
--         Bases 1-4 (terraza de pasto, mirando al altar)
--   ┌───────────────────────┐
--   │ Tienda        Rankings│ ┌──────────────────── CAÑÓN (1200) ────────────────────┐
--   │      ALTAR (0,0,0) ───┼─┤ Playa│Selva│Rocas│Basalto│Lava fría│Obsidiana│ ← OLA ← VOLCÁN (en el mar)
--   │ Comerciante Intercamb.│ └──────────── cuevas-refugio en las paredes ───────────┘
--   └───────────────────────┘
--         Bases 5-8
--
-- Todo sale de Config (medidas, paleta, zonas, cuevas). Las Parts del piso tienen 2 de alto con la cara de arriba en Y = 0.
-- Si en Workspace ya existe una carpeta "Map" (por ejemplo, cuando reemplaces los modelos a mano),
-- no construye nada y usa esa. Tiene que respetar la misma estructura (ver BaseService y los demás servicios).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local cfg = Config.Map
local P = Config.Palette
local Y0 = cfg.FloorY
local HALF_LOBBY_X = cfg.LobbySize.X / 2
local HALF_LOBBY_Z = cfg.LobbySize.Y / 2
local CANYON_START = cfg.CanyonStartX
local CANYON_END = cfg.CanyonStartX + cfg.CanyonLength
local HALF_CANYON = cfg.CanyonWidth / 2
local WALL_T = cfg.CanyonWallThickness
local WALL_H = cfg.CanyonWallHeight

local M = Enum.Material

-- ===== Ayudantes =====

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Lo mismo, pero que no choca (flores, conchas, grietas, hojas...)
local function deco(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = part(name, size, cframe, color, material, parent)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function wedge(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Parent = parent
	return p
end

-- Parte invisible que no choca con nada: marca una posición o un volumen.
local function marker(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local p = part(name, size, cframe, Color3.new(1, 1, 1), M.SmoothPlastic, parent)
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	return p
end

-- Pared invisible que sí choca (para que nadie se salga)
local function invisibleWall(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local p = part(name, size, cframe, Color3.new(1, 1, 1), M.SmoothPlastic, parent)
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- Cilindro parado apoyado en "bottom" (los cilindros de Roblox tienen el eje en X, así que lo giramos 90°).
local function column(name: string, height: number, diameter: number, bottom: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = part(name, Vector3.new(height, diameter, diameter), CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, material, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(name: string, diameter: number, position: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = part(name, Vector3.new(diameter, diameter, diameter), CFrame.new(position), color, material, parent)
	p.Shape = Enum.PartType.Ball
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Pone un texto sobre una cara de una Part (carteles).
local function addText(target: BasePart, face: Enum.NormalId, text: string, color: Color3, labelName: string?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = target

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

local function addLight(target: Instance, color: Color3, range: number, brightness: number, shadows: boolean?)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = target
end

-- ===== Modelos de decoración (§9) =====

-- Palmera: tronco curvo de 6 tramos que se afinan, 6 hojas en estrella y 3 cocos
local function buildPalm(position: Vector3, height: number, rng: Random, parent: Instance)
	local palm = Instance.new("Model")
	palm.Name = "Palm"
	local segment = height / 6
	local current = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	for i = 1, 6 do
		current = current * CFrame.Angles(0, 0, math.rad(rng:NextNumber(4, 6))) -- cada tramo un poco más torcido
		local diameter = 2.2 - (i - 1) * 0.12
		local trunk = part("Trunk", Vector3.new(segment + 0.2, diameter, diameter), current * CFrame.new(0, segment / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Wood, M.Wood, palm)
		trunk.Shape = Enum.PartType.Cylinder
		current = current * CFrame.new(0, segment, 0)
	end
	local top = current.Position
	for i = 0, 5 do
		wedge("Leaf", Vector3.new(3, 0.4, 10), CFrame.new(top) * CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -5), Color3.fromRGB(46, 158, 68), M.LeafyGrass, palm).CanCollide = false
	end
	for i = 0, 2 do
		local coconut = ball("Coconut", 1.2, top + Vector3.new(math.cos(i * 2.1) * 1.1, -1, math.sin(i * 2.1) * 1.1), Color3.fromRGB(122, 74, 30), M.Wood, palm)
		coconut.CanCollide = false
	end
	palm.Parent = parent
end

-- Antorcha tiki: palo, canasta de bambú, fuego y luz naranja
local function buildTorch(position: Vector3, parent: Instance)
	local torch = Instance.new("Model")
	torch.Name = "TikiTorch"
	part("Pole", Vector3.new(0.8, 7, 0.8), CFrame.new(position + Vector3.new(0, 3.5, 0)), Color3.fromRGB(122, 74, 30), M.Wood, torch)
	local basket = column("Basket", 1.5, 2, position + Vector3.new(0, 7, 0), P.Bamboo, M.Wood, torch)
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = P.TorchLight
	fire.SecondaryColor = Color3.fromRGB(255, 226, 122)
	fire.Parent = basket
	addLight(basket, P.TorchLight, 14, 2, true)
	torch.Parent = parent
end

-- Roca: un bloque rotado al azar y 1-2 piedras chicas al lado
local function buildRock(position: Vector3, size: number, rng: Random, parent: Instance)
	local rock = Instance.new("Model")
	rock.Name = "Rock"
	local function one(at: Vector3, s: number)
		local rotation = CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4))
		part("Rock", Vector3.new(s, s * 0.8, s * 1.1), CFrame.new(at + Vector3.new(0, s * 0.3, 0)) * rotation, P.Stone, M.Slate, rock)
	end
	one(position, size)
	for _ = 1, rng:NextInteger(1, 2) do
		local s = size * rng:NextNumber(0.25, 0.4)
		local angle = rng:NextNumber(0, math.pi * 2)
		one(position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (size * 0.7), s)
	end
	rock.Parent = parent
end

-- Cristal: 3 cuñas de vidrio violeta en abanico + luz violeta
local function buildCrystal(position: Vector3, rng: Random, parent: Instance)
	local crystal = Instance.new("Model")
	crystal.Name = "Crystal"
	local yaw = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	for i, height in { 4, 7, 10 } do
		local tilt = (i - 2) * 0.25
		local w = wedge("Shard", Vector3.new(1.5, height, 2.5), yaw * CFrame.new((i - 2) * 1.6, 0, 0) * CFrame.Angles(0, 0, tilt) * CFrame.new(0, height / 2, 0), P.Crystal, M.Glass, crystal)
		w.Transparency = 0.15
	end
	local glow = marker("Glow", Vector3.new(1, 1, 1), yaw * CFrame.new(0, 4, 0), crystal)
	addLight(glow, P.Crystal, 8, 2)
	crystal.Parent = parent
end

-- Concha o estrella de mar (decoración del piso, no molesta al caminar)
local function buildShell(position: Vector3, rng: Random, parent: Instance)
	local colors = { Color3.fromRGB(255, 180, 200), Color3.fromRGB(255, 240, 220), Color3.fromRGB(255, 150, 90) }
	local color = colors[rng:NextInteger(1, #colors)]
	local base = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if rng:NextNumber() < 0.6 then
		local shell = deco("Shell", Vector3.new(1.6, 0.7, 1.4), base * CFrame.new(0, 0.3, 0), color, M.SmoothPlastic, parent)
		shell.Shape = Enum.PartType.Ball
	else
		for arm = 0, 4 do
			deco("Starfish", Vector3.new(0.6, 0.25, 1.6), base * CFrame.Angles(0, math.rad(arm * 72), 0) * CFrame.new(0, 0.12, -0.7), Color3.fromRGB(255, 140, 40), M.SmoothPlastic, parent)
		end
	end
end

-- Flor de hibisco (esfera chica rosa o amarilla)
local function buildFlower(position: Vector3, rng: Random, parent: Instance)
	local color = if rng:NextNumber() < 0.5 then Color3.fromRGB(255, 79, 139) else Color3.fromRGB(255, 226, 122)
	local flower = deco("Hibiscus", Vector3.new(1.2, 1.2, 1.2), CFrame.new(position + Vector3.new(0, 0.6, 0)), color, M.SmoothPlastic, parent)
	flower.Shape = Enum.PartType.Ball
end

-- Puesto de playa (§9.5). cframe a nivel del piso, con el frente (-Z) mirando al altar.
-- Devuelve el modelo y el mostrador (donde va el botón para abrirlo).
local function buildStall(name: string, cframe: CFrame, awningColor: Color3, title: string, parent: Instance): (Model, Part)
	local stall = Instance.new("Model")
	stall.Name = name
	part("StallBase", Vector3.new(24, 6, 14), cframe * CFrame.new(0, 3, 0), Color3.fromRGB(233, 201, 138), M.Wood, stall)
	local counter = part("Counter", Vector3.new(26, 1, 4), cframe * CFrame.new(0, 6.5, -6), P.Wood, M.WoodPlanks, stall)
	for _, x in { -11, 11 } do
		for _, z in { -6, 6 } do
			column("Post", 14, 1.2, (cframe * CFrame.new(x, 0, z)).Position, P.Bamboo, M.Wood, stall)
		end
	end
	-- Toldo a rayas, inclinado hacia adelante
	for i = 0, 7 do
		local color = if i % 2 == 0 then awningColor else Color3.new(1, 1, 1)
		part("Awning", Vector3.new(3, 0.4, 16), cframe * CFrame.new(-10.5 + i * 3, 14, -1) * CFrame.Angles(math.rad(-15), 0, 0), color, M.Fabric, stall)
	end
	local sign = part("Sign", Vector3.new(14, 3, 0.5), cframe * CFrame.new(0, 17.5, 5), P.Wood, M.WoodPlanks, stall)
	addText(sign, Enum.NormalId.Front, title, Color3.new(1, 1, 1))
	stall.Parent = parent
	return stall, counter
end

local function addPrompt(target: BasePart, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = target
	return prompt
end

-- Tablero de madera parado sobre dos postes. cframe = centro del tablero, con el frente (-Z) mirando a la gente.
local function buildBoard(name: string, size: Vector2, cframe: CFrame, parent: Instance): Part
	local model = Instance.new("Model")
	model.Name = name
	local bottomY = cframe.Position.Y + size.Y / 2
	for _, x in { -size.X / 2 + 1, size.X / 2 - 1 } do
		local at = (cframe * CFrame.new(x, 0, 0.8)).Position
		part("BoardPost", Vector3.new(1, bottomY - Y0, 1), CFrame.new(at.X, Y0 + (bottomY - Y0) / 2, at.Z), P.DarkWood, M.Wood, model)
	end
	local frame = part("BoardFrame", Vector3.new(size.X + 1, size.Y + 1, 0.6), cframe * CFrame.new(0, 0, 0.4), P.Wood, M.WoodPlanks, model)
	frame.CanCollide = false
	local board = part("Board", Vector3.new(size.X, size.Y, 1), cframe, Color3.fromRGB(40, 28, 18), M.WoodPlanks, model)
	model.Parent = parent
	return board
end

-- ===== Iluminación y mar (§4, §8.1) =====

local function setupLighting()
	local L = Config.Lighting
	Lighting.ClockTime = L.ClockTime
	Lighting.Brightness = L.Brightness
	Lighting.Ambient = L.Ambient
	Lighting.OutdoorAmbient = L.OutdoorAmbient

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = L.AtmosphereDensity
	atmosphere.Haze = L.AtmosphereHaze
	atmosphere.Glare = L.AtmosphereGlare
	atmosphere.Color = L.AtmosphereColor
	atmosphere.Decay = L.AtmosphereDecay
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = L.BloomIntensity
	bloom.Size = L.BloomSize
	bloom.Threshold = L.BloomThreshold
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "IslandColors"
	color.Saturation = L.Saturation
	color.Contrast = L.Contrast
	color.TintColor = L.Tint
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = L.SunRaysIntensity
	rays.Spread = L.SunRaysSpread
	rays.Parent = Lighting
end

local function buildOcean()
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		return
	end
	local L = Config.Lighting
	terrain.WaterColor = L.WaterColor
	terrain.WaterTransparency = L.WaterTransparency
	terrain.WaterWaveSize = L.WaterWaveSize
	terrain.WaterWaveSpeed = L.WaterWaveSpeed
	-- Agua de Y = -30 a Y = -1.5 alrededor de todo el mapa (queda debajo del piso de la isla y del cañón)
	terrain:FillBlock(CFrame.new(700, -15.75, 0), Vector3.new(2200, 28.5, 800), M.Water)
	terrain:FillBlock(CFrame.new(700, -32, 0), Vector3.new(2200, 4, 800), M.Sand)
end

-- ===== Lobby (§5) =====

local function buildLobbyGround(lobby: Instance)
	local ground = folder("Ground", lobby)
	part("LobbySand", Vector3.new(cfg.LobbySize.X, 2, cfg.LobbySize.Y), CFrame.new(0, Y0 - 1, 0), P.LobbySand, M.Sand, ground)
	for _, side in { -1, 1 } do
		part("Terrace", Vector3.new(cfg.LobbySize.X, 2.2, cfg.TerraceDepth), CFrame.new(0, Y0 - 0.9, side * cfg.TerraceZ), P.TerraceGrass, M.Grass, ground)
	end
	-- Orilla mojada alrededor de la isla, un poco más baja
	local shore = cfg.ShoreWidth
	for _, side in { -1, 1 } do
		part("Shore", Vector3.new(cfg.LobbySize.X + shore * 2, 2, shore), CFrame.new(0, Y0 - 1.5, side * (HALF_LOBBY_Z + shore / 2)), P.WetSand, M.Sand, ground)
		part("Shore", Vector3.new(shore, 2, cfg.LobbySize.Y), CFrame.new(side * (HALF_LOBBY_X + shore / 2), Y0 - 1.5, 0), P.WetSand, M.Sand, ground)
		for _, sideZ in { -1, 1 } do
			-- Esquinas: cilindros de arena para que no se vean tan cuadradas
			local corner = part("ShoreCorner", Vector3.new(2, 60, 60), CFrame.new(side * HALF_LOBBY_X, Y0 - 1.5, sideZ * HALF_LOBBY_Z) * CFrame.Angles(0, 0, math.rad(90)), P.WetSand, M.Sand, ground)
			corner.Shape = Enum.PartType.Cylinder
		end
	end
end

local function buildAltar(lobby: Instance)
	local altar = Instance.new("Model")
	altar.Name = "Altar"
	column("AltarRingEdge", 1.5, 36, Vector3.new(0, Y0, 0), Color3.fromRGB(94, 87, 81), M.Slate, altar)
	column("AltarRing", 2, 34, Vector3.new(0, Y0, 0), P.Stone, M.Slate, altar)
	local lava = column("LavaPool", 0.4, 18, Vector3.new(0, Y0 + 1.9, 0), P.Lava, M.Neon, altar)
	addLight(lava, P.Lava, 16, 3)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60))
	sparks.LightEmission = 1
	sparks.Rate = 8
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Speed = NumberRange.new(4, 8)
	sparks.EmissionDirection = Enum.NormalId.Right -- el cilindro está acostado: su +X apunta para arriba
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.Parent = lava
	part("Pedestal", Vector3.new(6, 6, 6), CFrame.new(0, Y0 + 5, 0), P.Stone, M.Slate, altar)
	-- Huevo dorado gigante: gira y sube/baja (lo anima cada cliente, ver EggAnimator)
	local egg = part("GoldenEgg", Vector3.new(5, 7, 5), CFrame.new(0, Y0 + 11.5, 0), Color3.fromRGB(255, 216, 77), M.Neon, altar)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	egg.CanCollide = false
	egg:SetAttribute("Spin", 20) -- grados por segundo
	egg:SetAttribute("Bob", 0.5)
	CollectionService:AddTag(egg, "Spinning")
	-- 8 antorchas en círculo (corridas medio paso para no pisar el spawn ni el camino)
	for i = 0, 7 do
		local angle = math.rad(22.5 + i * 45)
		buildTorch(Vector3.new(math.cos(angle) * 22, Y0, math.sin(angle) * 22), altar)
	end
	altar.Parent = lobby

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(cfg.SpawnPosition)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0 -- sin campo de fuerza al aparecer
	spawn.Parent = lobby
end

local STALLS = {
	{ Name = "UpgradeShop", Position = Vector3.new(-95, 0, -55), Color = Color3.fromRGB(30, 136, 229), Title = "UPGRADES" },
	{ Name = "Merchant", Position = Vector3.new(-95, 0, 55), Color = Color3.fromRGB(142, 63, 214), Title = "MYSTERY MERCHANT" },
	{ Name = "Rankings", Position = Vector3.new(95, 0, -55), Color = Color3.fromRGB(232, 89, 12), Title = "RANKINGS" },
	{ Name = "Trading", Position = Vector3.new(95, 0, 55), Color = Color3.fromRGB(15, 157, 138), Title = "TRADING" },
}

-- Tablero de eventos: título y 3 renglones (próxima ola, súper tsunami, evento). Los escribe cada cliente (EventBoard.luau).
local function addEventLines(board: BasePart)
	board:SetAttribute("EventBoard", true)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	local function line(name: string, y: number, height: number, color: Color3, text: string)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.fromScale(0.94, height)
		label.Position = UDim2.fromScale(0.03, y)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.Parent = gui
	end
	line("Title", 0.03, 0.2, Color3.fromRGB(255, 220, 80), "EVENTS")
	for i = 1, 3 do
		line(`Line{i}`, 0.27 + (i - 1) * 0.24, 0.2, Color3.new(1, 1, 1), "")
	end
end

local function buildStalls(lobby: Instance)
	local stalls = folder("Stalls", lobby)
	for _, info in STALLS do
		local position = info.Position + Vector3.new(0, Y0, 0)
		local cframe = CFrame.lookAt(position, Vector3.new(0, Y0, 0)) -- el frente mira al altar
		local stall, counter = buildStall(info.Name, cframe, info.Color, info.Title, stalls)
		counter:SetAttribute("Stall", info.Name)
		if info.Name == "UpgradeShop" then
			local prompt = addPrompt(counter, "Open", "Upgrades")
			prompt:SetAttribute("Shared", true) -- lo ve cualquiera que tenga base (ver UpgradePanel en el cliente)
			CollectionService:AddTag(prompt, "UpgradePrompt")
		elseif info.Name == "Merchant" then
			addPrompt(counter, "Open", "Mystery Merchant")
		elseif info.Name == "Trading" then
			addPrompt(counter, "Open", "Trading")
		elseif info.Name == "Rankings" then
			-- Récords de plata arriba del puesto; a los costados, huevos abiertos y el tablero de eventos
			local boards = folder("Leaderboards", stall)
			local top = buildBoard("TopEarnersBoard", Vector2.new(20, 12), cframe * CFrame.new(0, 26, 6), boards)
			top:SetAttribute("Board", "TopEarners")
			local hatched = buildBoard("EggsHatchedBoard", Vector2.new(14, 12), cframe * CFrame.new(-21, 9, 2) * CFrame.Angles(0, math.rad(20), 0), boards)
			hatched:SetAttribute("Board", "EggsHatched")
			local events = buildBoard("EventBoard", Vector2.new(14, 12), cframe * CFrame.new(21, 9, 2) * CFrame.Angles(0, math.rad(-20), 0), stall)
			addEventLines(events)
		end
	end
end

local function buildPath(lobby: Instance)
	local path = folder("Path", lobby)
	local i = 0
	for x = 30, 145, 8 do
		i += 1
		local z = if i % 2 == 0 then 2 else -2
		column("Stone", 0.4, 5, Vector3.new(x, Y0, z), Color3.fromRGB(184, 176, 163), M.Slate, path)
	end
end

local function buildPortal(lobby: Instance)
	local portal = Instance.new("Model")
	portal.Name = "Portal"
	local x = CANYON_START
	for _, side in { -1, 1 } do
		local totem = part("Totem", Vector3.new(6, 18, 6), CFrame.new(x, Y0 + 9, side * 44), Color3.fromRGB(160, 82, 45), M.Wood, portal)
		-- Cara tallada mirando al lobby (-X): ojos amarillos y boca
		for _, ez in { -1.3, 1.3 } do
			deco("Eye", Vector3.new(0.4, 1, 1), totem.CFrame * CFrame.new(-3.1, 5, ez), Color3.fromRGB(255, 226, 122), M.Neon, portal)
		end
		deco("Mouth", Vector3.new(0.4, 0.8, 3), totem.CFrame * CFrame.new(-3.1, 2.5, 0), P.DarkWood, M.Wood, portal)
		buildTorch(Vector3.new(x - 4, Y0, side * 50), portal)
	end
	part("Beam", Vector3.new(4, 3, 96), CFrame.new(x, Y0 + 19.5, 0), P.Wood, M.WoodPlanks, portal)
	local sign = part("Sign", Vector3.new(2, 4, 24), CFrame.new(x - 1, Y0 + 16, 0), P.Wood, M.WoodPlanks, portal)
	addText(sign, Enum.NormalId.Left, "TO THE CANYON ⚠", Color3.fromRGB(255, 226, 122)) -- la cara Left (-X) mira al lobby
	addText(sign, Enum.NormalId.Right, "SAFE ISLAND", Color3.fromRGB(150, 255, 150))
	portal.Parent = lobby
end

local function buildLobbyDecor(lobby: Instance)
	local decor = folder("Decor", lobby)
	local rng = Random.new(1405)
	local palms = {
		Vector3.new(-60, 0, -95), Vector3.new(60, 0, -95), Vector3.new(-60, 0, 95), Vector3.new(60, 0, 95),
		Vector3.new(-135, 0, -10), Vector3.new(-135, 0, 25), Vector3.new(135, 0, -95), Vector3.new(135, 0, 95),
	}
	for _, position in palms do
		buildPalm(position + Vector3.new(0, Y0, 0), rng:NextNumber(18, 26), rng, decor)
	end
	-- Flores de hibisco en el borde de las terrazas
	for i = 1, 20 do
		local side = if i % 2 == 0 then 1 else -1
		buildFlower(Vector3.new(rng:NextNumber(-140, 140), Y0, side * rng:NextNumber(118, 122)), rng, decor)
	end
	-- Conchas y estrellas de mar en la orilla
	for i = 1, 15 do
		local side = if i % 2 == 0 then 1 else -1
		if i % 3 == 0 then
			buildShell(Vector3.new(-HALF_LOBBY_X - cfg.ShoreWidth / 2, Y0 - 0.5, rng:NextNumber(-150, 150)), rng, decor)
		else
			buildShell(Vector3.new(rng:NextNumber(-140, 140), Y0 - 0.5, side * (HALF_LOBBY_Z + cfg.ShoreWidth / 2)), rng, decor)
		end
	end
end

-- ===== Bases (§6) =====

local FLOOR_TOPS = { 1, 13, 25 } -- altura de la cara de arriba de cada piso de la torre
local SHELF_X = { -16, -8, 0, 8, 16 }
local SHELF_Z = 13 -- cerca de la pared de atrás de la torre
local TOWER_Z = 9 -- centro de la torre (local; +Z = atrás)
local SHELF_UNLOCKED = Color3.fromRGB(255, 226, 122)
local SHELF_LOCKED = Color3.fromRGB(91, 74, 184)
local INCUBATOR_X = { -14, 0, 14 }
local INCUBATOR_Z = -15 -- adelante de la torre, del lado del lobby

-- Nido-incubadora (la parte que no cambia). IncubatorService le agrega el huevo, la luz, el botón y el timer.
local function buildNest(cframe: CFrame, slot: number, parent: Instance)
	local nest = Instance.new("Model")
	nest.Name = `Nest{slot}`
	local pedestal = part("Pedestal", Vector3.new(8, 2, 8), cframe * CFrame.new(0, 1, 0), P.Stone, M.Slate, nest)
	pedestal:SetAttribute("SlotIndex", slot)
	column("NestBase", 1.5, 7, (cframe * CFrame.new(0, 2, 0)).Position, Color3.fromRGB(122, 74, 30), M.WoodPlanks, nest)
	for i = 0, 9 do
		local angle = math.rad(i * 36)
		local rim = cframe * CFrame.Angles(0, angle, 0) * CFrame.new(0, 3.6, -3.2) * CFrame.Angles(math.rad(-25), 0, 0)
		deco("NestRim", Vector3.new(2.2, 1, 0.8), rim, Color3.fromRGB(227, 182, 90), M.Fabric, nest)
	end
	nest.Parent = parent
end

-- Barrera de un piso bloqueado: celeste brillante con un candado (adelante y del lado de la escalera)
local function buildLockBarrier(plot: CFrame, floor: number, parent: Instance)
	local barrier = Instance.new("Model")
	barrier.Name = `LockBarrier{floor}`
	barrier:SetAttribute("Floor", floor)
	local y = FLOOR_TOPS[floor] + 5.5
	local front = part("Front", Vector3.new(40, 11, 0.5), plot * CFrame.new(0, y, TOWER_Z - 10), Color3.fromRGB(127, 214, 232), M.ForceField, barrier)
	part("Side", Vector3.new(0.5, 11, 20), plot * CFrame.new(20, y, TOWER_Z), Color3.fromRGB(127, 214, 232), M.ForceField, barrier)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(4, 4)
	gui.MaxDistance = 120
	gui.Parent = front
	local lock = Instance.new("TextLabel")
	lock.Size = UDim2.fromScale(1, 1)
	lock.BackgroundTransparency = 1
	lock.TextScaled = true
	lock.Text = "🔒"
	lock.Parent = gui
	barrier.Parent = parent
end

local function buildBase(index: number, position: Vector3, parent: Instance): Model
	-- El frente mira al centro del lobby. En coordenadas locales: -Z = adelante, +Z = atrás.
	local facing = if position.Z < 0 then Vector3.new(0, 0, 1) else Vector3.new(0, 0, -1)
	local plot = CFrame.lookAt(position, position + facing)
	local w, d = cfg.PlotSize.X, cfg.PlotSize.Y

	local model = Instance.new("Model")
	model.Name = `Base{index}`
	model:SetAttribute("BaseId", index)
	model:SetAttribute("OwnerUserId", 0)

	local plotPart = part("Plot", Vector3.new(w, 0.3, d), plot * CFrame.new(0, 0.15, 0), P.PlotGrass, M.Grass, model)
	model.PrimaryPart = plotPart

	-- Torre de 3 pisos
	local tower = Instance.new("Model")
	tower.Name = "Tower"
	for floor, top in FLOOR_TOPS do
		part(`Floor{floor}`, Vector3.new(40, 1, 20), plot * CFrame.new(0, top - 0.5, TOWER_Z), P.Wood, M.WoodPlanks, tower)
	end
	for _, x in { -20, 0, 20 } do
		for _, z in { TOWER_Z + 10, TOWER_Z - 10 } do
			local bottom = (plot * CFrame.new(x, 0, z)).Position
			column("Post", 36, 2, bottom, P.Bamboo, M.Wood, tower)
			for ringY = 4, 32, 4 do
				column("PostRing", 0.5, 2.3, bottom + Vector3.new(0, ringY, 0), Color3.fromRGB(140, 105, 40), M.Wood, tower)
			end
		end
	end
	part("BackWall", Vector3.new(40, 36, 1), plot * CFrame.new(0, 18, TOWER_Z + 10), Color3.fromRGB(233, 201, 138), M.Wood, tower)
	-- Techo de paja a dos aguas (de Y = 36 a Y = 46), sobresale 3 de cada lado
	local roofDepth = 13
	wedge("Roof", Vector3.new(46, 10, roofDepth), plot * CFrame.new(0, 41, TOWER_Z - roofDepth / 2), P.Straw, M.Fabric, tower)
	wedge("Roof", Vector3.new(46, 10, roofDepth), plot * CFrame.new(0, 41, TOWER_Z + roofDepth / 2) * CFrame.Angles(0, math.pi, 0), P.Straw, M.Fabric, tower)
	local x = -22.5
	while x <= 22.5 do
		deco("RoofFringe", Vector3.new(1, 3, 0.5), plot * CFrame.new(x, 35, TOWER_Z - roofDepth), Color3.fromRGB(196, 138, 44), M.Fabric, tower)
		x += 1.5
	end
	-- Escalera de mano (TrussPart: se trepa caminando contra ella) en el costado, hasta el piso 3
	for _, z in { TOWER_Z - 1, TOWER_Z + 1 } do
		local ladder = Instance.new("TrussPart")
		ladder.Name = "Ladder"
		ladder.Size = Vector3.new(2, 26, 2)
		ladder.CFrame = plot * CFrame.new(21, 13, z)
		ladder.Style = Enum.Style.NoSupports
		ladder.Color = P.Wood
		ladder.Material = M.Wood
		ladder.Anchored = true
		ladder.Parent = tower
	end
	-- Máscaras tiki en los postes del frente
	for _, mx in { -20, 20 } do
		local mask = part("TikiMask", Vector3.new(3, 4, 1), plot * CFrame.new(mx, 30, TOWER_Z - 11.2), Color3.fromRGB(160, 82, 45), M.Wood, tower)
		for _, ex in { -0.7, 0.7 } do
			deco("MaskEye", Vector3.new(0.6, 0.6, 0.2), mask.CFrame * CFrame.new(ex, 0.8, -0.55), Color3.fromRGB(255, 226, 122), M.Neon, tower)
		end
		deco("MaskMouth", Vector3.new(1.6, 0.4, 0.2), mask.CFrame * CFrame.new(0, -0.8, -0.55), P.DarkWood, M.Wood, tower)
	end
	tower.Parent = model

	-- Estantes: 5 por piso. Se numeran piso por piso (1-5 abajo, 6-10 en el 2, 11-15 en el 3).
	local shelves = folder("CreatureSlots", model)
	local slot = 0
	for floor, top in FLOOR_TOPS do
		for n, sx in SHELF_X do
			slot += 1
			local shelf = part(`Shelf_{floor}_{n}`, Vector3.new(6, 0.5, 6), plot * CFrame.new(sx, top + 0.25, SHELF_Z), SHELF_UNLOCKED, M.WoodPlanks, shelves)
			shelf:SetAttribute("SlotIndex", slot)
			shelf:SetAttribute("Floor", floor)
			shelf:SetAttribute("Unlocked", floor == 1)
			if floor > 1 then
				shelf.Color = SHELF_LOCKED
			end
		end
	end
	-- Pisos 2 y 3 bloqueados al principio (BaseFloors los abre)
	local locks = folder("Locks", model)
	for floor = 2, #FLOOR_TOPS do
		buildLockBarrier(plot, floor, locks)
	end

	-- Incubadoras: 3 nidos ADELANTE de la torre
	local nests = folder("IncubatorSlots", model)
	for i, ix in INCUBATOR_X do
		buildNest(plot * CFrame.new(ix, 0, INCUBATOR_Z), i, nests)
	end

	-- Cartel con el nombre del dueño
	local sign = part("Sign", Vector3.new(18, 4, 1), plot * CFrame.new(0, 33, TOWER_Z - 11.5), P.Wood, M.WoodPlanks, model)
	addText(sign, Enum.NormalId.Front, "Free Base", Color3.fromRGB(230, 230, 230), "SignLabel")

	for _, tx in { -26, 26 } do
		buildTorch((plot * CFrame.new(tx, 0, -6)).Position, model)
	end
	marker("SpawnPoint", Vector3.new(4, 1, 4), plot * CFrame.new(0, 1, -6), model)
	-- Volumen de la base (para saber si alguien está adentro)
	marker("SafeZone", Vector3.new(w, 50, d), plot * CFrame.new(0, 25, 0), model)

	model.Parent = parent
	return model
end

-- ===== Cañón (§7) =====

-- Distancia de un punto (x, z) del piso a la boca de una cueva
local function distanceToCave(x: number, z: number, cave: Config.Cave): number
	local half = Config.CaveWidth(cave) / 2
	local dx = math.max(0, math.abs(x - cave.X) - half)
	local dz = math.abs(cave.Side * HALF_CANYON - z)
	return math.sqrt(dx * dx + dz * dz)
end

local function farFromCaves(x: number, z: number, margin: number): boolean
	for _, cave in Config.Caves do
		if distanceToCave(x, z, cave) < margin then
			return false
		end
	end
	return true
end

-- Puntos donde aparecen huevos: al azar con semilla fija, separados entre sí y lejos de las cuevas.
local function buildEggSpawns(): { Vector3 }
	local existing = Workspace:FindFirstChild("EggSpawns")
	if existing then
		existing:Destroy()
	end
	local root = folder("EggSpawns", Workspace)
	local rng = Random.new(31337)
	local all: { Vector3 } = {}
	local maxZ = HALF_CANYON - cfg.SpawnWallMargin
	for index, zone in Config.Zones do
		local zoneFolder = folder(`Zone{index}`, root)
		local startX, endX = Config.ZoneRange(index)
		local placed = 0
		local attempts = 0
		while placed < zone.SpawnCount and attempts < 5000 do
			attempts += 1
			local x = rng:NextNumber(startX + 8, endX - 8)
			local z = rng:NextNumber(-maxZ, maxZ)
			local ok = farFromCaves(x, z, cfg.SpawnWallMargin + 2)
			if ok then
				for _, other in all do
					if (Vector3.new(x, 0, z) - Vector3.new(other.X, 0, other.Z)).Magnitude < Config.Eggs.SpawnMinDistance then
						ok = false
						break
					end
				end
			end
			if ok then
				placed += 1
				local position = Vector3.new(x, Y0 + 0.5, z)
				table.insert(all, position)
				local spawnPart = marker(`Spawn{placed}`, Vector3.new(2, 1, 2), CFrame.new(position), zoneFolder)
				spawnPart:SetAttribute("Zone", index)
			end
		end
		if placed < zone.SpawnCount then
			warn(`[MapBuilder] Only placed {placed}/{zone.SpawnCount} egg spawns in zone {zone.Id}`)
		end
	end
	return all
end

local function buildCanyonFloor(canyon: Instance)
	local floorFolder = folder("Floor", canyon)
	for index, zone in Config.Zones do
		local startX, endX = Config.ZoneRange(index)
		local floorPart = part(`Zone{index}`, Vector3.new(endX - startX, 2, cfg.CanyonWidth), CFrame.new((startX + endX) / 2, Y0 - 1, 0), zone.Color, zone.Material, floorFolder)
		floorPart:SetAttribute("Zone", index)
		-- Cartel de madera en la pared norte al empezar la zona: nombre y rareza
		local rarity = Config.GetRarity(zone.RarityId)
		local signPos = Vector3.new(startX + 5, Y0 + 9, -HALF_CANYON + 0.6)
		part("ZoneSignPost", Vector3.new(0.6, 9, 0.6), CFrame.new(startX + 5, Y0 + 4.5, -HALF_CANYON + 0.6), P.DarkWood, M.Wood, floorFolder)
		local board = part("ZoneSign", Vector3.new(8, 3, 0.5), CFrame.lookAt(signPos, signPos + Vector3.new(0, 0, 1)), P.Wood, M.WoodPlanks, floorFolder)
		addText(board, Enum.NormalId.Front, `{zone.DisplayName}\n{if rarity then rarity.DisplayName else ""}`, if rarity and rarity.Id ~= "Secret" then rarity.Color else Color3.new(1, 1, 1))
	end
end

-- Paredes de roca con selva arriba, en tramos que dejan los huecos de las cuevas
local function buildCanyonWalls(canyon: Instance, caves: Instance)
	local walls = folder("Walls", canyon)
	local rng = Random.new(808)
	local greens = { Color3.fromRGB(63, 154, 72), P.Jungle, Color3.fromRGB(79, 174, 82) }
	local cave = Config.CaveSize
	local caveNumber: { [Config.Cave]: number } = {}
	for i, info in Config.Caves do
		caveNumber[info] = i
	end
	for _, side in { -1, 1 } do
		local wallZ = side * (HALF_CANYON + WALL_T / 2)
		local sideCaves = {}
		for _, info in Config.Caves do
			if info.Side == side then
				table.insert(sideCaves, info)
			end
		end
		table.sort(sideCaves, function(a, b)
			return a.X < b.X
		end)

		local function segment(x0: number, x1: number)
			if x1 - x0 > 0.01 then
				part("Wall", Vector3.new(x1 - x0, WALL_H, WALL_T), CFrame.new((x0 + x1) / 2, Y0 + WALL_H / 2, wallZ), P.WallRock, M.Rock, walls)
			end
		end

		local cursor = CANYON_START
		for _, info in sideCaves do
			local width = Config.CaveWidth(info)
			local x0, x1 = info.X - width / 2, info.X + width / 2
			segment(cursor, x0)
			cursor = x1

			-- Cueva: tapa del fondo (mitad de afuera de la pared) + techo sobre el hueco
			local model = Instance.new("Model")
			model.Name = string.format("Cave%02d", caveNumber[info])
			local innerZ = side * (HALF_CANYON + cave.Z / 2)
			local outerZ = side * (HALF_CANYON + cave.Z + (WALL_T - cave.Z) / 2)
			part("CaveBack", Vector3.new(width, WALL_H, WALL_T - cave.Z), CFrame.new(info.X, Y0 + WALL_H / 2, outerZ), P.WallRock, M.Rock, model)
			part("CaveCeiling", Vector3.new(width, WALL_H - cave.Y, cave.Z), CFrame.new(info.X, Y0 + cave.Y + (WALL_H - cave.Y) / 2, innerZ), P.WallRock, M.Rock, model)
			-- Marco de madera (dorado en la VIP)
			local frameColor = if info.Vip then Color3.fromRGB(245, 184, 0) else Color3.fromRGB(138, 106, 74)
			local frameMaterial = if info.Vip then M.Neon else M.WoodPlanks
			local frameZ = side * (HALF_CANYON - 0.75)
			for _, fx in { x0 - 0.75, x1 + 0.75 } do
				part("CaveFrame", Vector3.new(1.5, cave.Y, 1.5), CFrame.new(fx, Y0 + cave.Y / 2, frameZ), frameColor, frameMaterial, model)
			end
			part("CaveFrame", Vector3.new(width + 3, 1.5, 1.5), CFrame.new(info.X, Y0 + cave.Y + 0.75, frameZ), frameColor, frameMaterial, model)
			buildTorch(Vector3.new(info.X, Y0, side * (HALF_CANYON + cave.Z - 2)), model)
			-- Zona segura: si estás acá adentro cuando pasa la ola, no te pasa nada
			local safe = marker("SafeZone", Vector3.new(width, cave.Y, cave.Z), CFrame.new(info.X, Y0 + cave.Y / 2, innerZ), model)
			safe:SetAttribute("Safe", true)
			if info.Vip then
				model:SetAttribute("Vip", true)
				-- Pared invisible en la entrada: solo pasan los que tienen el pase VIP (ver VipService)
				local barrier = invisibleWall("VipBarrier", Vector3.new(width, cave.Y, 1), CFrame.new(info.X, Y0 + cave.Y / 2, side * (HALF_CANYON + 0.5)), model)
				barrier:SetAttribute("VipBarrier", true)
				local signPos = Vector3.new(info.X, Y0 + cave.Y + 3.5, side * (HALF_CANYON - 0.3))
				local sign = part("VipSign", Vector3.new(10, 4, 0.5), CFrame.lookAt(signPos, signPos - Vector3.new(0, 0, side)), Color3.fromRGB(40, 28, 18), M.WoodPlanks, model)
				addText(sign, Enum.NormalId.Front, "VIP", Color3.fromRGB(245, 184, 0))
			end
			model.Parent = caves
		end
		segment(cursor, CANYON_END)

		-- Franja de selva arriba de la pared, con copas de árboles desordenadas
		part("JungleTop", Vector3.new(cfg.CanyonLength, 4, WALL_T), CFrame.new((CANYON_START + CANYON_END) / 2, Y0 + WALL_H + 2, wallZ), P.Jungle, M.LeafyGrass, walls)
		local x = CANYON_START + rng:NextNumber(0, 6)
		while x < CANYON_END do
			local diameter = rng:NextNumber(10, 16)
			local canopy = ball("TreeTop", diameter, Vector3.new(x, Y0 + WALL_H + 4 + diameter * 0.25, wallZ + rng:NextNumber(-6, 6)), greens[rng:NextInteger(1, #greens)], M.LeafyGrass, walls)
			canopy.CanCollide = false
			x += rng:NextNumber(9, 15)
		end
		-- Pared invisible encima, para que nadie se salga del cañón
		invisibleWall("InvisibleWall", Vector3.new(cfg.CanyonLength, 100, WALL_T), CFrame.new((CANYON_START + CANYON_END) / 2, Y0 + WALL_H + 50, wallZ), walls)
	end
	-- Al final del cañón: el mar. Una pared invisible para no caerse al agua.
	invisibleWall("EndWall", Vector3.new(2, WALL_H + 100, cfg.CanyonWidth), CFrame.new(CANYON_END + 1, Y0 + (WALL_H + 100) / 2, 0), walls)
end

-- Decoración de cada zona (§7.4). Deja libres 6 studs alrededor de cada cueva y de cada punto de huevos.
local function buildCanyonDecor(canyon: Instance, spawns: { Vector3 })
	local decor = folder("Decor", canyon)
	local rng = Random.new(2024)
	local margin = 6

	local function isClear(x: number, z: number, radius: number): boolean
		if not farFromCaves(x, z, margin + radius) then
			return false
		end
		for _, s in spawns do
			if (Vector3.new(x, 0, z) - Vector3.new(s.X, 0, s.Z)).Magnitude < margin + radius then
				return false
			end
		end
		return true
	end

	-- Busca un lugar libre en la zona (nil si no encuentra)
	local function spot(zoneIndex: number, radius: number, nearWall: boolean?): Vector3?
		local startX, endX = Config.ZoneRange(zoneIndex)
		for _ = 1, 60 do
			local x = rng:NextNumber(startX + 4, endX - 4)
			local z = if nearWall
				then (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(HALF_CANYON - 6, HALF_CANYON - 3)
				else rng:NextNumber(-HALF_CANYON + 3, HALF_CANYON - 3)
			if isClear(x, z, radius) then
				return Vector3.new(x, Y0, z)
			end
		end
		return nil
	end

	-- 1 Playa: conchas, estrellas, maderas de naufragio y 2 palmeras contra las paredes
	for i = 1, 20 do
		local at = spot(1, 1)
		if at then
			if i % 4 == 0 then
				deco("Driftwood", Vector3.new(rng:NextNumber(4, 7), 0.6, 1), CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(150, 120, 90), M.Wood, decor)
			else
				buildShell(at, rng, decor)
			end
		end
	end
	for _ = 1, 2 do
		local at = spot(1, 3, true)
		if at then
			buildPalm(at, rng:NextNumber(18, 24), rng, decor)
		end
	end

	-- 2 Selva: arbustos con flores y lianas colgando de las paredes
	for _ = 1, 15 do
		local at = spot(2, 3)
		if at then
			local size = rng:NextNumber(4, 7)
			local bush = ball("Bush", size, at + Vector3.new(0, size * 0.25, 0), Color3.fromRGB(63, 154, 72), M.Grass, decor)
			bush.Size = Vector3.new(size, size * 0.6, size)
			for _ = 1, rng:NextInteger(1, 3) do
				buildFlower(at + Vector3.new(rng:NextNumber(-size / 3, size / 3), size * 0.45, rng:NextNumber(-size / 3, size / 3)), rng, decor)
			end
		end
	end
	local jungleStart, jungleEnd = Config.ZoneRange(2)
	for _ = 1, 10 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = rng:NextNumber(jungleStart + 4, jungleEnd - 4)
		if farFromCaves(x, side * HALF_CANYON, 4) then
			local length = rng:NextNumber(8, 18)
			deco("Vine", Vector3.new(0.4, length, 0.4), CFrame.new(x, Y0 + WALL_H - length / 2, side * (HALF_CANYON - 0.3)), Color3.fromRGB(60, 150, 60), M.LeafyGrass, decor)
		end
	end

	-- 3 Rocas
	for _ = 1, 12 do
		local size = rng:NextNumber(4, 10)
		local at = spot(3, size * 0.7)
		if at then
			buildRock(at, size, rng, decor)
		end
	end

	-- 4 Basalto: grupos de columnas de distintas alturas
	for _ = 1, 8 do
		local at = spot(4, 4)
		if at then
			local group = Instance.new("Model")
			group.Name = "BasaltColumns"
			for c = 1, rng:NextInteger(3, 5) do
				local angle = c * 2.1
				column("Basalt", rng:NextNumber(3, 14), rng:NextNumber(2.5, 3.5), at + Vector3.new(math.cos(angle) * 2.2, 0, math.sin(angle) * 2.2), Color3.fromRGB(75, 70, 66), M.Basalt, group)
			end
			group.Parent = decor
		end
	end

	-- 5 Lava fría: grietas de lava en zigzag hundidas en el piso, algunas con humo
	for i = 1, 10 do
		local at = spot(5, 4)
		if at then
			local current = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			for k = 1, rng:NextInteger(3, 4) do
				local length = rng:NextNumber(4, 8)
				current = current * CFrame.Angles(0, (if k % 2 == 0 then 1 else -1) * rng:NextNumber(0.5, 0.9), 0)
				local crack = deco("LavaCrack", Vector3.new(0.6, 0.4, length), current * CFrame.new(0, 0, -length / 2), P.Lava, M.Neon, decor)
				if i <= 4 and k == 1 then
					local smoke = Instance.new("Smoke")
					smoke.Color = Color3.fromRGB(110, 110, 115)
					smoke.Size = 3
					smoke.RiseVelocity = 4
					smoke.Opacity = 0.15
					smoke.Parent = crack
				end
				current = current * CFrame.new(0, 0, -length)
			end
		end
	end

	-- 6 Obsidiana: grupos de cristales violetas que brillan
	for _ = 1, 10 do
		local at = spot(6, 3)
		if at then
			buildCrystal(at, rng, decor)
		end
	end
end

-- ===== Volcán (§8.2) =====

local function buildVolcano(map: Instance)
	local volcano = Instance.new("Model")
	volcano.Name = "Volcano"
	local center = cfg.VolcanoPosition + Vector3.new(0, Y0, 0)
	local height = cfg.VolcanoHeight
	local baseDiameter = cfg.VolcanoBaseDiameter
	local topDiameter = 50
	local layers = 11
	local layerHeight = (height + 10) / layers
	for i = 0, layers - 1 do
		local t = i / (layers - 1)
		local diameter = baseDiameter + (topDiameter - baseDiameter) * t
		column("Slope", layerHeight + 0.5, diameter, center + Vector3.new(0, -10 + i * layerHeight, 0), Color3.fromRGB(90, 64, 56), M.Basalt, volcano)
	end
	local crater = column("Crater", 1, 40, center + Vector3.new(0, height + 0.2, 0), P.Lava, M.Neon, volcano)
	addLight(crater, P.Lava, 60, 3)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "VolcanoSmoke"
	smoke.Color = ColorSequence.new(Color3.fromRGB(142, 142, 150))
	smoke.Size = NumberSequence.new(20, 45)
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Lifetime = NumberRange.new(8, 12)
	smoke.Speed = NumberRange.new(10, 20)
	smoke.Rate = 4
	smoke.EmissionDirection = Enum.NormalId.Right -- el cilindro está acostado: su +X apunta para arriba
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Parent = crater
	-- 3 ríos de lava por la ladera que mira al cañón (-X)
	local topRadius = topDiameter / 2
	local baseRadius = baseDiameter / 2
	for _, angleDeg in { -20, 0, 20 } do
		local angle = math.rad(180 + angleDeg)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local top = center + direction * (topRadius - 2) + Vector3.new(0, height, 0)
		local bottom = center + direction * (baseRadius - 4) + Vector3.new(0, 2, 0)
		local midpoint = (top + bottom) / 2 + direction * 3 -- un poco hacia afuera para que se vea sobre la ladera
		local length = (top - bottom).Magnitude
		part("LavaRiver", Vector3.new(4, 1, length), CFrame.lookAt(midpoint, midpoint + (bottom - top)), P.Lava, M.Neon, volcano).CanCollide = false
	end
	volcano.Parent = map
end

-- ===== Construcción =====

function MapBuilder.Build(): Folder
	local existing = Workspace:FindFirstChild("Map")
	if existing and existing:IsA("Folder") then
		return existing
	end

	-- La plantilla de Studio trae un Baseplate y un SpawnLocation: los sacamos (el mapa trae los suyos).
	for _, name in { "Baseplate", "SpawnLocation" } do
		local template = Workspace:FindFirstChild(name)
		if template then
			warn(`[MapBuilder] Removing template {name} (Egg Storm builds its own)`)
			template:Destroy()
		end
	end

	setupLighting()
	buildOcean()

	local map = Instance.new("Folder")
	map.Name = "Map"

	local lobby = folder("Lobby", map)
	buildLobbyGround(lobby)
	buildAltar(lobby)
	buildStalls(lobby)
	buildPath(lobby)
	buildPortal(lobby)
	buildLobbyDecor(lobby)

	local bases = folder("Bases", map)
	for index, position in cfg.BasePositions do
		buildBase(index, position + Vector3.new(0, Y0, 0), bases)
	end

	local canyon = folder("Canyon", map)
	local caves = folder("Caves", canyon)
	local spawns = buildEggSpawns()
	buildCanyonFloor(canyon)
	buildCanyonWalls(canyon, caves)
	buildCanyonDecor(canyon, spawns)

	buildVolcano(map)

	map.Parent = Workspace
	return map
end

return MapBuilder

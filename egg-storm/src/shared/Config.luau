--!strict
-- Config: TODOS los números de balance del juego viven acá.
-- Si querés ajustar tiempos, precios o probabilidades, cambiá este archivo y nada más.
-- Está en ReplicatedStorage para que el cliente también pueda leerlo (por ejemplo, para mostrar precios),
-- pero el servidor es el único que decide: el cliente solo lo usa para dibujar la interfaz.

export type Rarity = {
	Id: string, -- identificador interno (no cambiar una vez que haya datos guardados)
	DisplayName: string, -- texto que ve el jugador
	Color: Color3,
	BaseIncubationTime: number, -- segundos, antes de aplicar mejoras
	CoinsPerSecond: number, -- plata que genera la criatura que sale de este huevo
}

-- Variantes: un huevo puede ser además Silver, Golden, Emerald... La mascota sale de ese material y gana más.
export type Variant = {
	Id: string, -- identificador interno (no cambiar una vez que haya datos guardados)
	DisplayName: string, -- adjetivo que va antes del nombre: "Golden Rare Egg", "Golden Sun Phoenix"
	Color: Color3,
	Material: Enum.Material,
	Multiplier: number, -- multiplica la plata por segundo (y el precio de venta)
	Weight: number, -- probabilidad relativa
}

-- Zonas del cañón: cada una da huevos de SU rareza (o, con poca chance, de la siguiente).
export type Zone = {
	Id: string,
	DisplayName: string, -- texto del cartel
	RarityId: string, -- rareza de la zona
	NextRarityId: string?, -- la siguiente rareza (nil = no hay)
	NextChance: number, -- chance de que salga la siguiente (0.1 = 10%)
	Color: Color3, -- color del piso
	Material: Enum.Material,
	SpawnCount: number, -- cuántos puntos de aparición tiene
	MaxActive: number, -- cuántos huevos puede haber a la vez
	Respawn: number, -- cada cuántos segundos aparece uno nuevo (si hay lugar)
}

-- Cuevas-refugio en las paredes del cañón. Side: -1 = pared norte (Z-), 1 = pared sur (Z+).
export type Cave = {
	X: number, -- centro de la cueva a lo largo del cañón
	Side: number,
	Vip: boolean?,
}

export type EventInfo = {
	Id: string,
	DisplayName: string,
	Description: string,
	Color: Color3,
	Weight: number, -- probabilidad relativa entre eventos
}

export type WaveKind = {
	Speed: number, -- studs por segundo
	Warning: number, -- segundos de aviso antes de que salga
	Height: number, -- alto de la pared de agua
}

export type IncubationSpeedLevel = {
	Multiplier: number, -- 1 = 100% del tiempo, 0.25 = 25% del tiempo
	Cost: number,
}

export type WalkSpeedLevel = {
	Speed: number,
	Cost: number,
}

export type LuckLevel = {
	Chance: number, -- probabilidad (0 a 1) de que el huevo que agarrás suba una rareza
	Cost: number,
}

export type CarryLevel = {
	Extra: number, -- huevos de más que podés llevar (además del primero)
	Cost: number,
}

local Config = {}

-- ===== Servidor =====
-- OJO: el límite real de jugadores se pone en Game Settings (ver README). Esto es solo para el código.
Config.MaxPlayers = 8

-- ===== Mapa: isla tropical + volcán (ver MAPA_SPEC.md) =====
-- Origen (0, 0, 0) = centro del Altar del volcán. El piso de todo el mapa está en Y = 0.
-- +X = hacia el cañón y el volcán (este). La ola viaja en dirección -X. -Z = norte (bases 1-4), +Z = sur (bases 5-8).
Config.Map = {
	FloorY = 0,

	-- Lobby (plaza de arena en el oeste de la isla)
	LobbySize = Vector2.new(300, 420), -- X × Z
	TerraceZ = 165, -- centro de las terrazas de pasto (norte y sur), donde están los hábitats
	TerraceDepth = 90,
	SpawnPosition = Vector3.new(0, 2.5, 22), -- al lado del altar: ahí aparecen los jugadores

	-- Cañón (de X = CanyonStartX a CanyonStartX + CanyonLength)
	CanyonStartX = 150,
	CanyonLength = 1200,
	CanyonWidth = 80, -- de Z = -40 a 40
	CanyonWallThickness = 20,
	CanyonWallHeight = 40,
	SpawnWallMargin = 6, -- los puntos de huevos quedan a esta distancia de las paredes (y de las cuevas)

	-- Bases: 8 hábitats de selva (redondos, ~70 de ancho), mirando al centro del lobby
	PlotSize = Vector2.new(70, 70), -- X × Z
	BasePositions = {
		Vector3.new(-112.5, 0, -165),
		Vector3.new(-37.5, 0, -165),
		Vector3.new(37.5, 0, -165),
		Vector3.new(112.5, 0, -165),
		Vector3.new(-112.5, 0, 165),
		Vector3.new(-37.5, 0, 165),
		Vector3.new(37.5, 0, 165),
		Vector3.new(112.5, 0, 165),
	},

}

-- ===== Aldea de la selva (el lobby, ver VillageBuilder) =====
-- +X = hacia el cañón (este), -Z = norte (bases 1-4). El altar está en (0, 0, 0).
Config.Village = {
	PlazaRadius = 30, -- la plaza de piedra del altar (adentro del foso)
	MoatWidth = 10, -- el foso de agua alrededor (se puede cruzar por los 4 puentes o mojándose los pies)
	StallRadius = 62, -- los 4 puestos, en diagonal del otro lado del foso
	BoardwalkZ = 116, -- la pasarela de madera que pasa por delante de los hábitats (norte y sur)
	Lagoon = Vector3.new(-105, 0, -72), -- laguna con cascada (arriba a la izquierda)
	GiantTree = Vector3.new(-105, 0, 72), -- árbol gigante con la casita (abajo a la izquierda)
	FirePit = Vector3.new(100, 0, -76), -- fogón tiki con escenario (arriba a la derecha)
	EggGarden = Vector3.new(100, 0, 74), -- jardín con los 6 huevos gigantes (abajo a la derecha)
}

-- ===== Tutorial =====
Config.Tutorial = {
	StepReward = 100, -- monedas por cada paso completado ("STEP COMPLETE! +100 coins")
}

-- ===== Isla v2 (Terrain) =====
-- Una forma de la costa (ver Config.Island.Lobes)
export type IslandLobe = {
	Name: string,
	Kind: string, -- "Ellipse" o "Capsule"
	X: number?,
	Z: number,
	RX: number?,
	RZ: number?,
	X1: number?,
	X2: number?,
	R: number?,
}

-- La isla grande alrededor del lobby y del cañón: la arma IslandBuilder con Terrain cuando arranca el servidor.
-- El lobby, las bases y el cañón (de Parts) quedan igual: el terreno los rodea pero nunca los tapa.
-- Visto desde arriba: -Z es el norte (arriba), +X va hacia el volcán.
Config.Island = {
	Enabled = true, -- false = sin isla (solo el mar), por si querés probar algo rápido
	SeaLevel = -1.5, -- altura del agua
	-- Rectángulo que cubre el terreno (afuera es mar)
	MinX = -640,
	MaxX = 2160,
	MinZ = -560,
	MaxZ = 560,
	-- Forma de la costa: la unión de estas formas, con ruido para que no se vea geométrica.
	-- Ellipse: centro X/Z y radios RX/RZ. Capsule: una "pastilla" de X1 a X2 (en Z) con radio R.
	Lobes = {
		{ Name = "West", Kind = "Ellipse", X = -60, Z = 10, RX = 390, RZ = 420 }, -- pasto, lobby, punta con el faro
		{ Name = "Middle", Kind = "Capsule", X1 = 300, X2 = 1350, Z = 0, R = 210 }, -- colinas con selva a los lados del cañón
		{ Name = "NorthCove", Kind = "Ellipse", X = 1010, Z = -320, RX = 125, RZ = 115 }, -- caleta norte (cascada y laguna)
		{ Name = "SouthPeninsula", Kind = "Ellipse", X = 590, Z = 320, RX = 115, RZ = 140 }, -- península sur (muelle y botes)
		{ Name = "East", Kind = "Ellipse", X = 1610, Z = 0, RX = 420, RZ = 420 }, -- el volcán
	} :: { IslandLobe },
	CoastNoise = 38, -- cuánto se mete o sale la costa (studs)
	CoastNoiseScale = 170,
	BeachWidth = 16, -- ancho de la playa
	SeaSlope = 0.32, -- qué tan rápido se hace hondo el mar (arrecife cerca de la costa, mar profundo lejos)
	SeaFloor = -32,
	ReefChance = 0.5, -- más alto = menos arrecife
	ReefRocks = 34, -- rocas que asoman del agua
	-- Colinas
	WestHills = 12, -- alto de las lomas de pasto del oeste
	Hills = 44, -- alto de las colinas con selva
	HillScale = 150,
	LobbyFlatMargin = 14, -- alrededor del lobby el piso queda plano...
	LobbyBlend = 90, -- ...y después sube de a poco
	CliffHeight = 46, -- acantilados al lado de las paredes del cañón
	CliffWidth = 70,
	-- Volcán realista: alto = Peak × (1 − r/Radius)^Power, cortado en RimHeight (el borde del cráter)
	Volcano = {
		X = 1600,
		Z = 0,
		Peak = 330,
		Radius = 380,
		Power = 1.55,
		RimHeight = 240,
		CraterDepth = 38,
		LavaLevel = 206, -- altura del lago de lava
		Ravines = 9, -- barrancos que bajan desde la cumbre
		RavineDepth = 0.12,
	},
	LavaRivers = { 150, 212, 35 }, -- ángulo de cada río de lava (grados; 180 = hacia el cañón)
	LavaHotRadius = 230, -- hasta acá la lava brilla; más abajo ya se enfrió
	-- Caleta norte
	Lagoon = { X = 1000, Z = -288, Radius = 44 },
	Ridge = { X = 1010, Z = -362, Height = 42, Radius = 60 }, -- loma de donde cae la cascada
	-- Decoración (cantidades)
	Palms = 70,
	Trees = 110,
	Bushes = 140,
	Flowers = 90,
	Shells = 40, -- conchas y estrellas de mar en las playas
	Seed = 2025,
	-- Colores de los materiales del terreno
	Colors = {
		Sand = Color3.fromRGB(240, 220, 170),
		Grass = Color3.fromRGB(108, 192, 74),
		LeafyGrass = Color3.fromRGB(46, 139, 62),
		Ground = Color3.fromRGB(120, 92, 62),
		Rock = Color3.fromRGB(143, 138, 133),
		Basalt = Color3.fromRGB(74, 68, 64),
		Slate = Color3.fromRGB(58, 54, 52),
		CrackedLava = Color3.fromRGB(255, 106, 26),
		Limestone = Color3.fromRGB(214, 226, 214),
	},
}

-- Paleta y materiales: usar SIEMPRE estos para que todo combine
Config.Palette = {
	LobbySand = Color3.fromRGB(246, 221, 176),
	TerraceGrass = Color3.fromRGB(108, 194, 74),
	PlotGrass = Color3.fromRGB(93, 179, 61),
	Wood = Color3.fromRGB(139, 90, 43),
	DarkWood = Color3.fromRGB(74, 44, 18),
	Bamboo = Color3.fromRGB(201, 162, 74),
	Straw = Color3.fromRGB(217, 164, 65),
	Jungle = Color3.fromRGB(47, 138, 60),
	WallRock = Color3.fromRGB(122, 110, 98),
	WetSand = Color3.fromRGB(242, 212, 155),
	Lava = Color3.fromRGB(255, 106, 26),
	Crystal = Color3.fromRGB(163, 91, 255),
	Stone = Color3.fromRGB(142, 133, 122),
	TorchLight = Color3.fromRGB(255, 138, 31),
	Water = Color3.fromRGB(22, 147, 181),
}

-- Iluminación (la propiedad Technology = Future se pone en default.project.json porque un script no puede cambiarla)
Config.Lighting = {
	ClockTime = 14.5,
	Brightness = 2.5,
	Ambient = Color3.fromRGB(90, 80, 70),
	OutdoorAmbient = Color3.fromRGB(150, 140, 130),
	AtmosphereDensity = 0.34, -- niebla que tapa el horizonte
	AtmosphereHaze = 1.6,
	AtmosphereGlare = 0.2,
	AtmosphereColor = Color3.fromRGB(199, 232, 240),
	AtmosphereDecay = Color3.fromRGB(106, 112, 125),
	BloomIntensity = 0.6,
	BloomSize = 24,
	BloomThreshold = 1.5,
	Saturation = 0.15,
	Contrast = 0.05,
	Tint = Color3.fromRGB(255, 245, 230),
	SunRaysIntensity = 0.08,
	SunRaysSpread = 1,
	WaterColor = Color3.fromRGB(22, 147, 181),
	WaterTransparency = 0.6,
	WaterWaveSize = 0.15,
	WaterWaveSpeed = 8,
}

-- ===== Huevos =====
Config.Rarities = {
	{ Id = "Common", DisplayName = "Common", Color = Color3.fromRGB(244, 244, 244), BaseIncubationTime = 30, CoinsPerSecond = 1 },
	{ Id = "Rare", DisplayName = "Rare", Color = Color3.fromRGB(96, 165, 250), BaseIncubationTime = 60, CoinsPerSecond = 5 },
	{ Id = "Epic", DisplayName = "Epic", Color = Color3.fromRGB(167, 139, 250), BaseIncubationTime = 180, CoinsPerSecond = 25 },
	{ Id = "Legendary", DisplayName = "Legendary", Color = Color3.fromRGB(252, 211, 77), BaseIncubationTime = 480, CoinsPerSecond = 120 },
	{ Id = "Mythic", DisplayName = "Mythic", Color = Color3.fromRGB(248, 113, 113), BaseIncubationTime = 1200, CoinsPerSecond = 600 },
	-- Secret: negro; el brillo blanco/arcoíris se agrega con efectos
	{ Id = "Secret", DisplayName = "Secret", Color = Color3.fromRGB(17, 24, 39), BaseIncubationTime = 2700, CoinsPerSecond = 3000 },
} :: { Rarity }

-- Las 6 zonas del cañón, en orden desde el portal hasta el fondo (cada una mide ZoneLength).
Config.ZoneLength = 200
Config.Zones = {
	{ Id = "Beach", DisplayName = "BEACH", RarityId = "Common", NextRarityId = "Rare", NextChance = 0.1, Color = Color3.fromRGB(242, 212, 155), Material = Enum.Material.Sand, SpawnCount = 16, MaxActive = 8, Respawn = 10 },
	{ Id = "Jungle", DisplayName = "JUNGLE", RarityId = "Rare", NextRarityId = "Epic", NextChance = 0.1, Color = Color3.fromRGB(124, 196, 107), Material = Enum.Material.Grass, SpawnCount = 14, MaxActive = 6, Respawn = 15 },
	{ Id = "Rocks", DisplayName = "ROCKS", RarityId = "Epic", NextRarityId = "Legendary", NextChance = 0.1, Color = Color3.fromRGB(171, 162, 148), Material = Enum.Material.Slate, SpawnCount = 12, MaxActive = 5, Respawn = 20 },
	{ Id = "Basalt", DisplayName = "BASALT", RarityId = "Legendary", NextRarityId = "Mythic", NextChance = 0.1, Color = Color3.fromRGB(110, 104, 99), Material = Enum.Material.Basalt, SpawnCount = 10, MaxActive = 4, Respawn = 30 },
	{ Id = "CooledLava", DisplayName = "COOLED LAVA", RarityId = "Mythic", NextRarityId = "Secret", NextChance = 0.1, Color = Color3.fromRGB(74, 56, 51), Material = Enum.Material.CrackedLava, SpawnCount = 8, MaxActive = 3, Respawn = 45 },
	{ Id = "Obsidian", DisplayName = "OBSIDIAN", RarityId = "Secret", NextRarityId = nil, NextChance = 0, Color = Color3.fromRGB(38, 31, 51), Material = Enum.Material.Slate, SpawnCount = 6, MaxActive = 1, Respawn = 90 },
} :: { Zone }

-- Cuevas-refugio: más separadas a medida que avanzás. La VIP es más ancha y solo entra quien tiene el pase.
Config.CaveSize = Vector3.new(12, 12, 10) -- ancho (X) × alto × profundidad
Config.VipCaveWidth = 20
Config.Caves = {
	{ X = 200, Side = -1 },
	{ X = 260, Side = 1 },
	{ X = 320, Side = -1 },
	{ X = 400, Side = 1 },
	{ X = 480, Side = -1, Vip = true },
	{ X = 560, Side = 1 },
	{ X = 660, Side = -1 },
	{ X = 760, Side = 1 },
	{ X = 880, Side = -1 },
	{ X = 1000, Side = 1 },
	{ X = 1150, Side = -1 },
	{ X = 1300, Side = 1 },
} :: { Cave }

Config.Eggs = {
	Size = Vector3.new(2.5, 3.2, 2.5),
	SpawnMinDistance = 15, -- distancia mínima entre puntos de aparición
	FallHeight = 150, -- desde qué altura caen los meteoritos
	GrabHoldTime = 0.3, -- cuánto hay que mantener apretada la tecla para agarrar
	GrabDistance = 10, -- distancia máxima para agarrar (studs)
	GrabCooldown = 0.5, -- tiempo mínimo entre intentos de agarrar (anti-spam)
}

-- ===== Variantes de huevo =====
-- Normal es la más común. Las demás cambian el material de la mascota y multiplican su plata.
Config.Variants = {
	{ Id = "Normal", DisplayName = "", Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, Multiplier = 1, Weight = 85 },
	{ Id = "Silver", DisplayName = "Silver", Color = Color3.fromRGB(215, 220, 230), Material = Enum.Material.Foil, Multiplier = 2, Weight = 8 },
	{ Id = "Golden", DisplayName = "Golden", Color = Color3.fromRGB(255, 200, 50), Material = Enum.Material.Foil, Multiplier = 3, Weight = 4 },
	{ Id = "Emerald", DisplayName = "Emerald", Color = Color3.fromRGB(40, 210, 110), Material = Enum.Material.Glass, Multiplier = 5, Weight = 2 },
	{ Id = "Diamond", DisplayName = "Diamond", Color = Color3.fromRGB(150, 235, 255), Material = Enum.Material.Glass, Multiplier = 10, Weight = 0.8 },
	{ Id = "Rainbow", DisplayName = "Rainbow", Color = Color3.fromRGB(255, 120, 220), Material = Enum.Material.ForceField, Multiplier = 25, Weight = 0.2 },
} :: { Variant }

-- ===== Eventos =====
-- Cada Interval segundos hay Chance de que empiece un evento, que dura Duration segundos.
Config.Events = {
	Interval = 240,
	Chance = 0.5,
	Duration = 120,
	List = {
		{ Id = "GoldenRain", DisplayName = "GOLDEN RAIN", Description = "Egg rain! Way more Silver, Golden and Emerald eggs!", Color = Color3.fromRGB(255, 205, 60), Weight = 30 },
		{ Id = "LuckyStorm", DisplayName = "LUCKY STORM", Description = "Every zone gives its better eggs 3x more often!", Color = Color3.fromRGB(110, 255, 140), Weight = 30 },
		{ Id = "DoubleCoins", DisplayName = "DOUBLE COINS", Description = "All creatures make 2x coins!", Color = Color3.fromRGB(255, 160, 60), Weight = 25 },
		{ Id = "MeteorShower", DisplayName = "METEOR SHOWER", Description = "Meteors drop Epic or better eggs in the canyon!", Color = Color3.fromRGB(255, 90, 60), Weight = 15 },
	} :: { EventInfo },
	GoldenRainVariantBoost = 6, -- en Golden Rain, la chance de cada variante (no Normal) se multiplica por esto
	GoldenRainRespawnMultiplier = 0.5, -- ...y los huevos reaparecen el doble de rápido
	LuckyNextChanceMultiplier = 3, -- en Lucky Storm, la chance de la rareza siguiente de cada zona se multiplica por esto
	DoubleCoinsMultiplier = 2,
	MeteorInterval = 10, -- segundos entre meteoritos (en Meteor Shower)
	MeteorRarityWeights = { Epic = 55, Legendary = 30, Mythic = 12, Secret = 3 } :: { [string]: number },
}

-- ===== Olas (salen del volcán y barren el cañón hacia el lobby) =====
Config.Waves = {
	StartX = 1360, -- donde arranca la ola
	EndX = 150, -- el portal: la ola nunca entra al lobby
	Thickness = 6,
	Width = 84,
	MinInterval = 60, -- segundos entre una ola y el aviso de la siguiente (al azar entre Min y Max)
	MaxInterval = 90,
	Normal = { Speed = 60, Warning = 5, Height = 50 } :: WaveKind,
	FastChance = 0.25, -- 1 de cada 4 olas es rápida
	Fast = { Speed = 120, Warning = 3, Height = 50 } :: WaveKind,
	SuperInterval = 1800, -- Súper tsunami cada 30 minutos
	Super = { Speed = 90, Warning = 15, Height = 80 } :: WaveKind,
	FadeTime = 1.5, -- segundos que tarda en desvanecerse al llegar al portal
	-- Sonidos (podés cambiarlos por IDs de la Creator Store, ej: "rbxassetid://1234567"; "" = sin sonido)
	WarningSoundId = "rbxasset://sounds/electronicpingshort.wav", -- cuerno de caracol
	WaveSoundId = "", -- rugido de la ola
}

-- ===== Incubadoras y plata =====
Config.Incubators = {
	HoldTime = 0.5, -- cuánto mantener apretada la tecla para poner el huevo / abrirlo
	Distance = 10, -- distancia máxima para usar la incubadora (studs)
	Cooldown = 0.5, -- tiempo mínimo entre intentos (anti-spam)
}

Config.Economy = {
	StartingCoins = 0,
	IncomeInterval = 1, -- cada cuántos segundos se cobra la plata de las mascotas

	-- Vender mascotas (mantener E sobre una mascota tuya)
	SellValueSeconds = 60, -- precio de venta = esta cantidad de segundos de lo que genera (Common 60, Legendary 7.200...)
	SellHoldTime = 1.5, -- segundos que hay que mantener la tecla para vender (así no se vende sin querer)
	SellHoldTimeRare = 3, -- lo mismo, para Legendary o mejores y variantes Emerald o mejores
	SellDistance = 12, -- distancia máxima
	SellCooldown = 0.5, -- tiempo mínimo entre ventas (anti-spam)

	-- Ganancia mientras no estás: al volver, tus mascotas te pagan por el tiempo que estuviste afuera
	OfflineRate = 0.5, -- qué parte de lo normal (0.5 = la mitad)
	OfflineMaxHours = 8, -- tope de horas que se cuentan
	OfflineMinSeconds = 60, -- si estuviste afuera menos que esto, no cuenta (así no sale el cartel cada vez que reentrás)
}

-- ===== Guardado =====
Config.Data = {
	-- Nombre del DataStore. Si lo cambiás, todos empiezan de cero (los datos viejos quedan en el nombre anterior).
	StoreName = "EggStorm_PlayerData_v1",
	AutosaveInterval = 60, -- cada cuántos segundos se guarda a todos los que están jugando
	MaxAttempts = 4, -- cuántas veces se reintenta si Roblox falla al leer o guardar
	RetryDelay = 1, -- segundos de espera entre reintentos (va creciendo: 1, 2, 3...)
}

-- ===== Tabla de récords =====
Config.Leaderboard = {
	Size = 10, -- cuántos puestos muestra cada tablero
	UpdateInterval = 120, -- cada cuántos segundos se actualizan (Roblox limita cuántas veces se puede leer/escribir)
	FirstUpdateDelay = 10, -- la primera actualización, unos segundos después de que arranca el servidor
	-- Nombres de los OrderedDataStore (si los cambiás, las tablas empiezan de cero)
	EarnersStoreName = "EggStorm_TopEarners_v1",
	HatchedStoreName = "EggStorm_EggsHatched_v1",
}

-- ===== Efectos e interfaz =====
Config.Effects = {
	HatchAnimationTime = 3, -- segundos que el huevo tiembla y brilla antes de abrirse
	RevealDuration = 3, -- segundos que queda el cartel "You got..." (los Legendary o mejores, uno más)
	-- Sonidos (podés cambiarlos por IDs de la Creator Store, ej: "rbxassetid://1234567"; "" = sin sonido)
	HatchSoundId = "rbxasset://sounds/electronicpingshort.wav",
}

-- ===== Mejoras (se compran en la Tienda de mejoras del lobby) =====
-- (Se compran desde cualquier lado: botón "Shop" del costado o el puesto del lobby. Se puede comprar x1, x10 o MAX.)
Config.Upgrades = {
	PanelDistance = 14, -- distancia para que el puesto del lobby abra la ventana (studs)
	BuyCooldown = 0.3, -- tiempo mínimo entre compras (anti-spam)

	-- Velocidad de caminata (el nivel 1 es la velocidad normal de Roblox)
	WalkSpeed = {
		{ Speed = 16, Cost = 0 },
		{ Speed = 18, Cost = 150 },
		{ Speed = 20, Cost = 400 },
		{ Speed = 22, Cost = 1000 },
		{ Speed = 24, Cost = 2500 },
		{ Speed = 26, Cost = 6000 },
		{ Speed = 28, Cost = 15000 },
		{ Speed = 30, Cost = 35000 },
		{ Speed = 32, Cost = 80000 },
		{ Speed = 34, Cost = 180000 },
	} :: { WalkSpeedLevel },

	-- Llevar huevos: cuántos huevos de más podés cargar (se suma con el VIP)
	Carry = {
		{ Extra = 0, Cost = 0 },
		{ Extra = 1, Cost = 5000 },
	} :: { CarryLevel },

	-- Multiplica el tiempo de incubación
	IncubationSpeed = {
		{ Multiplier = 1.0, Cost = 0 }, -- nivel 1 (gratis, es el inicial)
		{ Multiplier = 0.92, Cost = 100 },
		{ Multiplier = 0.85, Cost = 300 },
		{ Multiplier = 0.78, Cost = 800 },
		{ Multiplier = 0.71, Cost = 2000 },
		{ Multiplier = 0.64, Cost = 5000 },
		{ Multiplier = 0.57, Cost = 12000 },
		{ Multiplier = 0.5, Cost = 30000 },
		{ Multiplier = 0.43, Cost = 75000 },
		{ Multiplier = 0.36, Cost = 180000 },
	} :: { IncubationSpeedLevel },
	MinIncubationTime = 5, -- segundos: ningún huevo tarda menos que esto

	-- Incubadoras extra (los 3 nidos están siempre adelante de la base; los que no compraste dicen LOCKED)
	StartingIncubators = 1,
	MaxIncubators = 3,
	ExtraIncubatorCosts = { 250, 1500 }, -- precio de la 2.ª y de la 3.ª incubadora

	-- Suerte: chance de que el huevo que agarrás suba una rareza (los muy raros suben menos, ver LuckByRarity)
	Luck = {
		{ Chance = 0, Cost = 0 },
		{ Chance = 0.03, Cost = 500 },
		{ Chance = 0.06, Cost = 1500 },
		{ Chance = 0.09, Cost = 4000 },
		{ Chance = 0.12, Cost = 10000 },
		{ Chance = 0.15, Cost = 25000 },
		{ Chance = 0.18, Cost = 60000 },
		{ Chance = 0.21, Cost = 150000 },
		{ Chance = 0.24, Cost = 350000 },
		{ Chance = 0.27, Cost = 800000 },
	} :: { LuckLevel },
	-- Cuánto de la suerte vale para cada rareza (Common, Rare, Epic, Legendary, Mythic). Un Secret no sube.
	LuckByRarity = { 1, 1, 0.75, 0.5, 0.2 },
}

-- ===== Hábitat (dónde viven las criaturas) =====
Config.Habitat = {
	Capacity = 20, -- criaturas por jugador (todas desde el principio, no hace falta mejorar nada)
	WanderRadius = 6, -- cuánto se aleja cada criatura de su lugar cuando pasea (lo hace el cliente)
	WanderViewDistance = 160, -- las criaturas más lejos que esto no se mueven (para no gastar)
}

-- ===== Renacimiento =====
-- Renacer reinicia la plata y las mejoras de velocidad (Incubation Speed y Walk Speed).
-- Se conservan las mascotas, los huevos, las incubadoras, la Suerte y Llevar huevos.
-- A cambio, cada renacimiento suma IncomeBonus a la plata de TODAS tus mascotas (para siempre).
-- Es ilimitado: cada uno cuesta CostGrowth veces el anterior (100K, 250K, 625K, 1.56M, 3.9M...).
Config.Rebirth = {
	BaseCost = 100000, -- precio del primero
	CostGrowth = 2.5, -- cada renacimiento cuesta esto × el anterior
	IncomeBonus = 0.25, -- +25% de plata por renacimiento
	Cooldown = 1, -- anti-spam
}

-- ===== Comerciante misterioso =====
-- Cada RestockInterval segundos trae OfferCount huevos nuevos (los mismos para todo el servidor).
-- Cada jugador puede comprar cada oferta una vez por tanda. El huevo va directo a un nido libre de su base.
Config.Merchant = {
	RestockInterval = 600,
	OfferCount = 3,
	PriceSeconds = 600, -- precio = la plata por segundo que daría su mascota × esta cantidad de segundos
	RarityWeights = { Rare = 40, Epic = 30, Legendary = 18, Mythic = 9, Secret = 3 } :: { [string]: number },
	VariantChance = 0.35, -- chance de que una oferta venga con variante (Silver, Golden...)
	Distance = 14, -- distancia máxima al mostrador para comprar
	Cooldown = 0.5,
}

-- ===== Intercambio entre jugadores =====
Config.Trade = {
	MaxItems = 4, -- cuántas mascotas puede ofrecer cada uno en un intercambio
	RequestTimeout = 30, -- segundos que dura una invitación sin responder
	RequestCooldown = 5, -- segundos entre invitaciones a la misma persona (anti-spam)
	CountdownTime = 3, -- cuenta regresiva cuando los dos aprietan "Ready" (si alguien cambia algo, se cancela)
	Distance = 14, -- distancia máxima al puesto de Intercambio para mandar una invitación
	Cooldown = 0.2, -- anti-spam de los botones
}

-- ===== Pase VIP =====
-- Para activarlo: creá el Game Pass en el Creator Dashboard y pegá su número acá (ver PUBLICAR.md).
-- Con 0, el juego funciona igual pero nadie puede comprar el pase todavía.
Config.Vip = {
	GamePassId = 0,
	PriceRobux = 199, -- solo para mostrarlo en la ventana (el precio de verdad se pone en el Creator Dashboard)
	-- Regalar VIP: un Developer Product (Monetization → Developer Products). Con 0, el botón de regalo avisa que no está.
	GiftProductId = 0,
	GiftStoreName = "EggStormVipGifts", -- DataStore donde se anotan los VIP regalados
	TestUserIds = {} :: { number }, -- UserIds que son VIP sin comprar (para probar en Studio o regalarlo)
	PromptCooldown = 2, -- anti-spam de los botones de compra y regalo
	-- Ventajas
	CoinMultiplier = 2, -- x2 de plata de las mascotas (para siempre)
	HatchSpeedBonus = 0.2, -- los nidos incuban 20% más rápido
	ExtraCarry = 1, -- puede llevar 1 huevo más a la vez
	DailyEggRarity = "Rare", -- huevo gratis de cada día...
	DailyEggVariant = "Golden", -- ...dorado
	DailyEggInterval = 24 * 3600, -- cada cuánto (segundos)
}

-- ===== Ayudantes =====
local raritiesById: { [string]: Rarity } = {}
for _, rarity in Config.Rarities do
	raritiesById[rarity.Id] = rarity
end

function Config.GetRarity(id: string): Rarity?
	return raritiesById[id]
end

-- Posición de la rareza en la lista (Common = 1 ... Secret = 6). Sirve para comparar "Legendary o mejor".
function Config.RarityRank(id: string): number
	for i, rarity in Config.Rarities do
		if rarity.Id == id then
			return i
		end
	end
	return 0
end

local variantsById: { [string]: Variant } = {}
for _, variant in Config.Variants do
	variantsById[variant.Id] = variant
end

-- La variante con ese Id (si no existe, Normal).
function Config.GetVariant(id: string?): Variant
	return (id and variantsById[id]) or Config.Variants[1]
end

local eventsById: { [string]: EventInfo } = {}
for _, event in Config.Events.List do
	eventsById[event.Id] = event
end

function Config.GetEvent(id: string?): EventInfo?
	return if id then eventsById[id] else nil
end

-- Desde qué X hasta qué X va la zona número index (1 = Playa ... 6 = Obsidiana).
function Config.ZoneRange(index: number): (number, number)
	local startX = Config.Map.CanyonStartX + (index - 1) * Config.ZoneLength
	return startX, startX + Config.ZoneLength
end

-- En qué zona está esta X del cañón (nil si está fuera del cañón).
function Config.ZoneAt(x: number): (Zone?, number?)
	for i, zone in Config.Zones do
		local startX, endX = Config.ZoneRange(i)
		if x >= startX and x < endX then
			return zone, i
		end
	end
	return nil, nil
end

-- Ancho de una cueva (la VIP es más ancha)
function Config.CaveWidth(cave: Cave): number
	return if cave.Vip then Config.VipCaveWidth else Config.CaveSize.X
end

-- Multiplicador de plata por los renacimientos (1 renacimiento = x1.25)
-- Precio del próximo renacimiento si ya renaciste "rebirths" veces (redondeado a miles)
function Config.RebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths / 1000 + 0.5) * 1000
end

function Config.RebirthMultiplier(rebirths: number): number
	return 1 + Config.Rebirth.IncomeBonus * rebirths
end

-- Plata por segundo de una mascota de esta rareza y variante.
function Config.GetIncome(rarity: Rarity, variant: Variant?): number
	return rarity.CoinsPerSecond * (if variant then variant.Multiplier else 1)
end

-- Cuánto pagan por vender una mascota de esta rareza (y variante).
function Config.GetSellPrice(rarity: Rarity, variant: Variant?): number
	return Config.GetIncome(rarity, variant) * Config.Economy.SellValueSeconds
end

-- Nombre con la variante adelante: ("Golden", "Rare Egg") -> "Golden Rare Egg"; Normal no agrega nada.
function Config.WithVariant(variant: Variant, name: string): string
	return if variant.DisplayName ~= "" then `{variant.DisplayName} {name}` else name
end

-- Segundos que tarda un huevo de esta rareza con el nivel de "Incubation Speed" dado (con el mínimo aplicado).
function Config.GetIncubationTime(rarity: Rarity, speedLevel: number, vip: boolean?): number
	local levels = Config.Upgrades.IncubationSpeed
	local level = levels[math.clamp(speedLevel, 1, #levels)]
	local vipFactor = if vip then 1 - Config.Vip.HatchSpeedBonus else 1
	return math.max(Config.Upgrades.MinIncubationTime, rarity.BaseIncubationTime * level.Multiplier * vipFactor)
end

-- ¿Es VIP? Lo decide SOLO el servidor (VipService pone el atributo "VIP"; lo que cambia un cliente no le llega al servidor).
function Config.IsVip(player: Player): boolean
	return player:GetAttribute("VIP") == true
end

-- Chance de que un huevo de esta rareza suba una rareza al agarrarlo (mejora Luck × poción de suerte)
function Config.LuckChance(player: Player, rarityId: string): number
	local level = player:GetAttribute("LuckLevel")
	local levels = Config.Upgrades.Luck
	local base = levels[math.clamp(if typeof(level) == "number" then level else 1, 1, #levels)].Chance
	local boost = player:GetAttribute("LuckBoost")
	local factor = Config.Upgrades.LuckByRarity[Config.RarityRank(rarityId)] or 0
	return math.min(0.9, base * (if typeof(boost) == "number" then boost else 1) * factor)
end

-- Cuántos huevos puede llevar a la vez: 1 + la mejora "Llevar huevos" + el VIP (se suman)
function Config.CarryCapacity(player: Player): number
	local level = player:GetAttribute("CarryLevel")
	local levels = Config.Upgrades.Carry
	local extra = levels[math.clamp(if typeof(level) == "number" then level else 1, 1, #levels)].Extra
	return 1 + extra + (if Config.IsVip(player) then Config.Vip.ExtraCarry else 0)
end

return Config

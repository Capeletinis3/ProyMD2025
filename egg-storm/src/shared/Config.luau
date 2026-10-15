--!strict
-- Config: TODOS los números de balance del juego viven acá.
-- Si querés ajustar tiempos, precios o probabilidades, cambiá este archivo y nada más.
-- Está en ReplicatedStorage para que el cliente también pueda leerlo (por ejemplo, para mostrar precios),
-- pero el servidor es el único que decide: el cliente solo lo usa para dibujar la interfaz.

export type Rarity = {
	Id: string, -- identificador interno (no cambiar una vez que haya datos guardados)
	DisplayName: string, -- texto que ve el jugador
	Color: Color3,
	Weight: number, -- probabilidad relativa (los pesos suman 100)
	BaseIncubationTime: number, -- segundos, antes de aplicar mejoras
	CoinsPerSecond: number, -- plata que genera la criatura que sale de este huevo
	-- Cualquier rareza puede caer en cualquier parte del pasillo, pero lejos es un poco mejor:
	-- la chance se multiplica por (1 + FarBonus × distancia), con distancia de 0 (entrada) a 1 (fondo).
	FarBonus: number,
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

export type EventInfo = {
	Id: string,
	DisplayName: string,
	Description: string,
	Color: Color3,
	Weight: number, -- probabilidad relativa entre eventos
}

export type IncubationSpeedLevel = {
	Multiplier: number, -- 1 = 100% del tiempo, 0.25 = 25% del tiempo
	Cost: number,
}

export type WalkSpeedLevel = {
	Speed: number,
	Cost: number,
}

local Config = {}

-- ===== Servidor =====
-- OJO: el límite real de jugadores se pone en Game Settings (ver README). Esto es solo para el código.
Config.MaxPlayers = 8

-- ===== Mapa =====
-- Forma de T. Eje Z: el lobby (zona segura con las bases en fila) queda en Z < 0,
-- la línea segura está en Z = 0 y el pasillo de arena va de Z = 0 hasta Z = CorridorLength.
-- El ancho y el largo del lobby se calculan solos a partir de la cantidad y el tamaño de las bases.
Config.Map = {
	FloorY = 0, -- altura del piso
	CorridorWidth = 240, -- ancho del pasillo de arena
	CorridorLength = 1500, -- largo del pasillo de arena (zona de peligro)
	SeaDepth = 25, -- franja de agua al fondo del pasillo, de donde sale la ola
	WallHeight = 80,
	WallThickness = 10,
	EggSideMargin = 25, -- los huevos no caen en la franja de decoración junto a las paredes

	BaseCount = 8, -- todas en una fila, mirando hacia el pasillo
	PlotWidth = 44, -- ancho de cada parcela
	PlotDepth = 60, -- profundidad de cada parcela (incubadoras adelante, mascotas a los costados)
	PlotGap = 16, -- espacio entre parcelas (y entre las parcelas de las puntas y la pared)
	LobbyFrontWalk = 50, -- espacio para caminar entre las bases y la línea segura
	LobbyBackMargin = 24, -- espacio detrás de las bases (ahí va el cartel con el nombre)

	-- Mezcla playa + mar: lobby de arena con baldosas, pasillo de agua turquesa entre paredes azul océano
	LobbyFloorColor = Color3.fromRGB(235, 200, 155),
	WaterFloorColor = Color3.fromRGB(70, 215, 230),
	WallColor = Color3.fromRGB(35, 110, 215),
	WallTrimColor = Color3.fromRGB(235, 205, 160),
	SeaColor = Color3.fromRGB(20, 90, 220),

	-- Todas las bases son grises e iguales (se distinguen por el cartel con el nombre del dueño)
	BaseColor = Color3.fromRGB(160, 165, 175),
}

-- ===== Huevos (se usan desde la fase 2) =====
Config.Rarities = {
	{
		Id = "Common",
		DisplayName = "Common",
		Color = Color3.fromRGB(245, 245, 245),
		Weight = 75,
		BaseIncubationTime = 30,
		CoinsPerSecond = 1,
		FarBonus = 0,
	},
	{
		Id = "Rare",
		DisplayName = "Rare",
		Color = Color3.fromRGB(70, 140, 255),
		Weight = 18,
		BaseIncubationTime = 60,
		CoinsPerSecond = 5,
		FarBonus = 0.5,
	},
	{
		Id = "Epic",
		DisplayName = "Epic",
		Color = Color3.fromRGB(170, 80, 255),
		Weight = 5,
		BaseIncubationTime = 90,
		CoinsPerSecond = 20,
		FarBonus = 1.5,
	},
	{
		Id = "Legendary",
		DisplayName = "Legendary",
		Color = Color3.fromRGB(255, 200, 40),
		Weight = 1.7,
		BaseIncubationTime = 120,
		CoinsPerSecond = 100,
		FarBonus = 3,
	},
	{
		Id = "Secret",
		DisplayName = "Secret",
		Color = Color3.fromRGB(20, 20, 25), -- negro; el brillo arcoíris se agrega con efectos
		Weight = 0.3,
		BaseIncubationTime = 180,
		CoinsPerSecond = 500,
		FarBonus = 5,
	},
} :: { Rarity }

Config.Eggs = {
	SpawnInterval = 1.5, -- segundos entre huevo y huevo mientras llueve
	MaxOnGround = 45, -- si ya hay esta cantidad en el piso (o cayendo), no cae ninguno más
	FallHeight = 150, -- desde qué altura caen
	FallTime = 2.5, -- cuánto tarda la caída (segundos)
	GrabHoldTime = 0.25, -- cuánto hay que mantener apretada la tecla para agarrar
	GrabDistance = 10, -- distancia máxima para agarrar (studs)
	GrabCooldown = 0.5, -- tiempo mínimo entre intentos de agarrar (anti-spam)
	CarryHeight = 2.5, -- cuántos studs sobre la cabeza se lleva el huevo
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

-- ===== Eventos de tormenta =====
-- Al empezar cada tormenta hay ChancePerStorm de que sea especial. El evento dura toda la tormenta (hasta la calma).
Config.Events = {
	ChancePerStorm = 0.4,
	List = {
		{ Id = "GoldenRain", DisplayName = "GOLDEN RAIN", Description = "Way more Silver, Golden and Emerald eggs!", Color = Color3.fromRGB(255, 205, 60), Weight = 30 },
		{ Id = "LuckyStorm", DisplayName = "LUCKY STORM", Description = "Epic, Legendary and Secret eggs are 3x more likely!", Color = Color3.fromRGB(110, 255, 140), Weight = 30 },
		{ Id = "DoubleCoins", DisplayName = "DOUBLE COINS", Description = "All creatures make 2x coins during this storm!", Color = Color3.fromRGB(255, 160, 60), Weight = 25 },
		{ Id = "MeteorShower", DisplayName = "METEOR SHOWER", Description = "Meteors drop Epic or better eggs. Be the first!", Color = Color3.fromRGB(255, 90, 60), Weight = 15 },
	} :: { EventInfo },
	GoldenRainVariantBoost = 6, -- en Golden Rain, la chance de cada variante (no Normal) se multiplica por esto
	LuckyRarityBoost = 3, -- en Lucky Storm, la chance de Epic/Legendary/Secret se multiplica por esto
	DoubleCoinsMultiplier = 2,
	MeteorInterval = 10, -- segundos entre meteoritos (en Meteor Shower)
	MeteorRarityWeights = { Epic = 70, Legendary = 25, Secret = 5 } :: { [string]: number },
}

-- ===== Incubadoras y plata (fase 3) =====
Config.Incubators = {
	HoldTime = 0.3, -- cuánto mantener apretada la tecla para poner el huevo
	Distance = 12, -- distancia máxima para usar la incubadora (studs)
	Cooldown = 0.5, -- tiempo mínimo entre intentos (anti-spam)
}

Config.Economy = {
	StartingCoins = 0,
	IncomeInterval = 1, -- cada cuántos segundos se cobra la plata de las mascotas

	-- Vender mascotas (mantener E sobre una mascota tuya)
	SellValueSeconds = 60, -- precio de venta = esta cantidad de segundos de lo que genera (Common 60, Legendary 6.000...)
	SellHoldTime = 1.5, -- segundos que hay que mantener la tecla para vender (así no se vende sin querer)
	SellHoldTimeRare = 3, -- lo mismo, para Legendary, Secret y variantes Emerald o mejores
	SellDistance = 16, -- distancia máxima (alcanza para las mascotas del segundo piso desde abajo)
	SellCooldown = 0.5, -- tiempo mínimo entre ventas (anti-spam)

	-- Ganancia mientras no estás: al volver, tus mascotas te pagan por el tiempo que estuviste afuera
	OfflineRate = 0.5, -- qué parte de lo normal (0.5 = la mitad)
	OfflineMaxHours = 8, -- tope de horas que se cuentan
	OfflineMinSeconds = 60, -- si estuviste afuera menos que esto, no cuenta (así no sale el cartel cada vez que reentrás)
}

-- ===== Guardado (fase 7) =====
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

-- ===== Efectos e interfaz (fase 6) =====
Config.Effects = {
	HatchAnimationTime = 3, -- segundos que el huevo tiembla y brilla antes de abrirse
	RevealDuration = 3, -- segundos que queda el cartel "You got..." (los Legendary y Secret, uno más)
	-- Sonidos (podés cambiarlos por IDs de la Creator Store, ej: "rbxassetid://1234567"; "" = sin sonido)
	HatchSoundId = "rbxasset://sounds/electronicpingshort.wav",
}

-- ===== Mejoras (fase 4) =====
Config.Upgrades = {
	PanelDistance = 12, -- distancia máxima al panel de mejoras para poder comprar (studs)
	BuyCooldown = 0.3, -- tiempo mínimo entre compras (anti-spam)

	-- Multiplica el tiempo de incubación
	IncubationSpeed = {
		{ Multiplier = 1.0, Cost = 0 }, -- nivel 1 (gratis, es el inicial)
		{ Multiplier = 0.8, Cost = 100 },
		{ Multiplier = 0.6, Cost = 500 },
		{ Multiplier = 0.4, Cost = 2000 },
		{ Multiplier = 0.25, Cost = 10000 },
	} :: { IncubationSpeedLevel },
	MinIncubationTime = 5, -- segundos: ningún huevo tarda menos que esto

	-- Incubadoras extra
	StartingIncubators = 1,
	MaxIncubators = 3,
	ExtraIncubatorCosts = { 250, 1500 }, -- precio de la 2.ª y de la 3.ª incubadora

	-- Velocidad de caminata (el nivel 1 es la velocidad normal de Roblox)
	WalkSpeed = {
		{ Speed = 16, Cost = 0 },
		{ Speed = 20, Cost = 300 },
		{ Speed = 24, Cost = 1500 },
		{ Speed = 28, Cost = 6000 },
	} :: { WalkSpeedLevel },

	-- "Mejorar base": segundo piso con más lugares para mascotas
	BaseFloor = {
		Cost = 5000,
		ExtraCreatureSlots = 6,
	},
}

-- ===== Tormenta y ola (fase 5) =====
-- Ciclo: lluvia → aviso → ola → calma → lluvia...
Config.Storm = {
	-- Con el pasillo de 1500 studs, a velocidad normal (16) en una tormenta llegás a ~800 studs y volvés;
	-- con las mejoras de "Walk Speed" llegás al fondo. Si cambiás CorridorLength, revisá estos números.
	RainDuration = 90, -- segundos de lluvia de huevos (cielo oscuro)
	WarningDuration = 10, -- segundos del cartel "WAVE INCOMING"
	CalmDuration = 20, -- segundos de calma después de la ola

	WaveSpeed = 100, -- studs por segundo (recorre los 1525 studs del pasillo en ~15 s)
	WaveHeight = 35, -- altura de la pared de agua
	WaveThickness = 30, -- grosor de la pared de agua
	RespawnTime = 3, -- segundos hasta reaparecer en tu base después de que te agarra la ola

	-- Sonidos (podés cambiarlos por IDs de la Creator Store, ej: "rbxassetid://1234567"; "" = sin sonido)
	WarningSoundId = "rbxasset://sounds/electronicpingshort.wav",
	WaveSoundId = "",
}

-- ===== Ayudantes =====
local raritiesById: { [string]: Rarity } = {}
for _, rarity in Config.Rarities do
	raritiesById[rarity.Id] = rarity
end

function Config.GetRarity(id: string): Rarity?
	return raritiesById[id]
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
function Config.GetIncubationTime(rarity: Rarity, speedLevel: number): number
	local levels = Config.Upgrades.IncubationSpeed
	local level = levels[math.clamp(speedLevel, 1, #levels)]
	return math.max(Config.Upgrades.MinIncubationTime, rarity.BaseIncubationTime * level.Multiplier)
end

return Config

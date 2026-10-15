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
	-- Tramo del pasillo donde caen estos huevos, como fracción del largo
	-- (0 = línea de la zona segura, 1 = fondo del pasillo, donde nace la ola).
	-- Cada rareza tiene su tramo: cuanto más rara, más lejos de las bases. El piso se pinta por tramos.
	ZoneStart: number,
	ZoneEnd: number,
}

export type IncubationSpeedLevel = {
	Multiplier: number, -- 1 = 100% del tiempo, 0.25 = 25% del tiempo
	Cost: number,
}

local Config = {}

-- ===== Servidor =====
-- OJO: el límite real de jugadores se pone en Game Settings (ver README). Esto es solo para el código.
Config.MaxPlayers = 8

-- ===== Mapa =====
-- El mapa es un pasillo largo. Eje Z: el lobby (zona segura con las bases) queda en Z < 0,
-- la línea segura está en Z = 0 y el pasillo de arena va de Z = 0 hasta Z = CorridorLength.
Config.Map = {
	FloorY = 0, -- altura del piso
	CorridorWidth = 200, -- ancho de todo el mapa (lobby y pasillo)
	CorridorLength = 500, -- largo del pasillo de arena (zona de peligro)
	LobbyDepth = 180, -- largo del lobby verde (zona segura)
	SeaDepth = 25, -- franja de agua al fondo del pasillo, de donde sale la ola
	WallHeight = 80,
	WallThickness = 10,
	EggSideMargin = 15, -- los huevos no caen pegados a las paredes

	BaseCount = 8, -- mitad de cada lado del lobby
	PlotWidth = 38, -- largo de cada parcela a lo largo del lobby
	PlotDepth = 44, -- profundidad de cada parcela (desde el camino central hacia la pared)
	PlotGap = 4, -- espacio entre parcelas

	GrassColor = Color3.fromRGB(80, 220, 70),
	SandColor = Color3.fromRGB(240, 215, 160),
	WallColor = Color3.fromRGB(215, 120, 85),
	WallTrimColor = Color3.fromRGB(90, 200, 90),
	SeaColor = Color3.fromRGB(40, 150, 255),

	-- Un color por base, en orden (Base1, Base2, ...)
	BaseColors = {
		Color3.fromRGB(255, 99, 99), -- rojo
		Color3.fromRGB(255, 170, 70), -- naranja
		Color3.fromRGB(255, 230, 90), -- amarillo
		Color3.fromRGB(120, 220, 120), -- verde
		Color3.fromRGB(90, 200, 255), -- celeste
		Color3.fromRGB(110, 130, 255), -- azul
		Color3.fromRGB(190, 120, 255), -- violeta
		Color3.fromRGB(255, 130, 210), -- rosa
	},
}

-- ===== Huevos (se usan desde la fase 2) =====
Config.Rarities = {
	{
		Id = "Common",
		DisplayName = "Common",
		Color = Color3.fromRGB(245, 245, 245),
		Weight = 60,
		BaseIncubationTime = 30,
		CoinsPerSecond = 1,
		ZoneStart = 0.05,
		ZoneEnd = 0.4,
	},
	{
		Id = "Rare",
		DisplayName = "Rare",
		Color = Color3.fromRGB(70, 140, 255),
		Weight = 25,
		BaseIncubationTime = 60,
		CoinsPerSecond = 5,
		ZoneStart = 0.4,
		ZoneEnd = 0.65,
	},
	{
		Id = "Epic",
		DisplayName = "Epic",
		Color = Color3.fromRGB(170, 80, 255),
		Weight = 10,
		BaseIncubationTime = 90,
		CoinsPerSecond = 20,
		ZoneStart = 0.65,
		ZoneEnd = 0.83,
	},
	{
		Id = "Legendary",
		DisplayName = "Legendary",
		Color = Color3.fromRGB(255, 200, 40),
		Weight = 4.5,
		BaseIncubationTime = 120,
		CoinsPerSecond = 100,
		ZoneStart = 0.83,
		ZoneEnd = 0.94,
	},
	{
		Id = "Secret",
		DisplayName = "Secret",
		Color = Color3.fromRGB(20, 20, 25), -- negro; el brillo arcoíris se agrega con efectos
		Weight = 0.5,
		BaseIncubationTime = 180,
		CoinsPerSecond = 500,
		ZoneStart = 0.94,
		ZoneEnd = 1,
	},
} :: { Rarity }

Config.Eggs = {
	SpawnInterval = 2, -- segundos entre huevo y huevo mientras llueve
	MaxOnGround = 25, -- si ya hay esta cantidad en el piso (o cayendo), no cae ninguno más
	FallHeight = 150, -- desde qué altura caen
	FallTime = 2.5, -- cuánto tarda la caída (segundos)
	GrabHoldTime = 0.25, -- cuánto hay que mantener apretada la tecla para agarrar
	GrabDistance = 10, -- distancia máxima para agarrar (studs)
	GrabCooldown = 0.5, -- tiempo mínimo entre intentos de agarrar (anti-spam)
	CarryHeight = 2.5, -- cuántos studs sobre la cabeza se lleva el huevo
}

-- ===== Mejoras (se usan desde la fase 4) =====
Config.Upgrades = {
	IncubationSpeed = {
		{ Multiplier = 1.0, Cost = 0 }, -- nivel 1 (gratis, es el inicial)
		{ Multiplier = 0.8, Cost = 100 },
		{ Multiplier = 0.6, Cost = 500 },
		{ Multiplier = 0.4, Cost = 2000 },
		{ Multiplier = 0.25, Cost = 10000 },
	} :: { IncubationSpeedLevel },
	MinIncubationTime = 5, -- segundos: ningún huevo tarda menos que esto

	StartingIncubators = 1,
	MaxIncubators = 6,
}

-- ===== Tormenta (se usa en la fase 5) =====
Config.Storm = {
	RainDuration = 60,
	WarningDuration = 10,
	CalmDuration = 20,
}

return Config

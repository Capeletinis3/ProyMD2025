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
Config.Map = {
	GroundSize = 800, -- lado del piso cuadrado (studs)
	GroundColor = Color3.fromRGB(110, 190, 90),

	DangerZoneRadius = 160, -- zona central donde caen los huevos
	DangerZoneColor = Color3.fromRGB(235, 205, 140),

	BaseCount = 8,
	BaseRingRadius = 250, -- distancia del centro del mapa al centro de cada base
	BaseWidth = 60,
	BaseDepth = 60,
	BaseHeight = 30, -- qué tan elevada está la base (la ola no llega hasta acá)
	BaseFoundationColor = Color3.fromRGB(120, 120, 130),
	WallHeight = 3,

	RampLength = 70, -- largo horizontal de la rampa que baja al mapa
	RampWidth = 16,
	RampColor = Color3.fromRGB(160, 120, 80),

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
	},
	{
		Id = "Rare",
		DisplayName = "Rare",
		Color = Color3.fromRGB(70, 140, 255),
		Weight = 25,
		BaseIncubationTime = 60,
		CoinsPerSecond = 5,
	},
	{
		Id = "Epic",
		DisplayName = "Epic",
		Color = Color3.fromRGB(170, 80, 255),
		Weight = 10,
		BaseIncubationTime = 90,
		CoinsPerSecond = 20,
	},
	{
		Id = "Legendary",
		DisplayName = "Legendary",
		Color = Color3.fromRGB(255, 200, 40),
		Weight = 4.5,
		BaseIncubationTime = 120,
		CoinsPerSecond = 100,
	},
	{
		Id = "Secret",
		DisplayName = "Secret",
		Color = Color3.fromRGB(20, 20, 25), -- negro; el brillo arcoíris se agrega con efectos
		Weight = 0.5,
		BaseIncubationTime = 180,
		CoinsPerSecond = 500,
	},
} :: { Rarity }

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

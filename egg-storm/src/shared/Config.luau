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
	CorridorLength = 800, -- largo del pasillo de arena (zona de peligro)
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
	SellHoldTimeRare = 3, -- lo mismo, para Legendary y Secret
	SellDistance = 16, -- distancia máxima (alcanza para las mascotas del segundo piso desde abajo)
	SellCooldown = 0.5, -- tiempo mínimo entre ventas (anti-spam)
}

-- ===== Guardado (fase 7) =====
Config.Data = {
	-- Nombre del DataStore. Si lo cambiás, todos empiezan de cero (los datos viejos quedan en el nombre anterior).
	StoreName = "EggStorm_PlayerData_v1",
	AutosaveInterval = 60, -- cada cuántos segundos se guarda a todos los que están jugando
	MaxAttempts = 4, -- cuántas veces se reintenta si Roblox falla al leer o guardar
	RetryDelay = 1, -- segundos de espera entre reintentos (va creciendo: 1, 2, 3...)
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
	RainDuration = 60, -- segundos de lluvia de huevos (cielo oscuro)
	WarningDuration = 10, -- segundos del cartel "WAVE INCOMING"
	CalmDuration = 20, -- segundos de calma después de la ola

	WaveSpeed = 70, -- studs por segundo (recorre los 825 studs del pasillo en ~12 s)
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

-- Cuánto pagan por vender una mascota de esta rareza.
function Config.GetSellPrice(rarity: Rarity): number
	return rarity.CoinsPerSecond * Config.Economy.SellValueSeconds
end

-- Segundos que tarda un huevo de esta rareza con el nivel de "Incubation Speed" dado (con el mínimo aplicado).
function Config.GetIncubationTime(rarity: Rarity, speedLevel: number): number
	local levels = Config.Upgrades.IncubationSpeed
	local level = levels[math.clamp(speedLevel, 1, #levels)]
	return math.max(Config.Upgrades.MinIncubationTime, rarity.BaseIncubationTime * level.Multiplier)
end

return Config

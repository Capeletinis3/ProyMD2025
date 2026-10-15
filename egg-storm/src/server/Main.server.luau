--!strict
-- Punto de entrada del servidor: arranca cada servicio en orden.
-- A medida que avancemos de fase se van sumando servicios acá (mejoras, tormenta, guardado...).

local Services = script.Parent.Services
local MapBuilder = require(Services.MapBuilder)
local BaseService = require(Services.BaseService)
local PlayerDataService = require(Services.PlayerDataService)
local EggService = require(Services.EggService)
local CreatureService = require(Services.CreatureService)
local IncubatorService = require(Services.IncubatorService)
local UpgradeService = require(Services.UpgradeService)

local map = MapBuilder.Build()

PlayerDataService.Init()
EggService.Init()
CreatureService.Init()
IncubatorService.Init()
UpgradeService.Init()

-- Cuando un jugador recibe su base: cargamos sus datos y armamos su base.
-- El orden importa: las mejoras primero (el piso 2 tiene que existir antes de poner mascotas ahí).
BaseService.OnAssigned(function(player, base)
	PlayerDataService.Load(player)
	UpgradeService.SetupBase(player, base)
	CreatureService.SetupBase(player, base)
	IncubatorService.SetupBase(player, base)
end)

-- Cuando se va: limpiamos su base (las incubadoras guardan sus huevos en el perfil) y soltamos sus datos.
BaseService.OnReleased(function(player, base)
	IncubatorService.ClearBase(player)
	CreatureService.ClearBase(player)
	UpgradeService.ClearBase(player, base)
	PlayerDataService.Unload(player)
end)

-- Init de BaseService va al final: recién ahí empieza a repartir bases (y a llamar a lo de arriba).
BaseService.Init(map)

-- Hasta la fase 5 (ciclo de tormenta) llueven huevos todo el tiempo.
EggService.SetRaining(true)

print("[EggStorm] Server ready")

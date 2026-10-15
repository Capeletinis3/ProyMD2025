--!strict
-- Punto de entrada del servidor: arranca cada servicio en orden.
-- A medida que avancemos de fase se van sumando servicios acá (incubadoras, tormenta, guardado...).

local Services = script.Parent.Services
local MapBuilder = require(Services.MapBuilder)
local BaseService = require(Services.BaseService)
local EggService = require(Services.EggService)

local map = MapBuilder.Build()
BaseService.Init(map)
EggService.Init()

-- Hasta la fase 5 (ciclo de tormenta) llueven huevos todo el tiempo.
EggService.SetRaining(true)

print("[EggStorm] Server ready")

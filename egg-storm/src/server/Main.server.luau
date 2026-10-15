--!strict
-- Punto de entrada del servidor: arranca cada servicio en orden.
-- A medida que avancemos de fase se van sumando servicios acá (huevos, incubadoras, tormenta, guardado...).

local Services = script.Parent.Services
local MapBuilder = require(Services.MapBuilder)
local BaseService = require(Services.BaseService)

local map = MapBuilder.Build()
BaseService.Init(map)

print("[EggStorm] Server ready")

--!strict
-- Punto de entrada del servidor: arranca cada servicio en orden.
-- Cada servicio se encarga de una parte del juego (ver README).

local Services = script.Parent.Services
local MapBuilder = require(Services.MapBuilder)
local BaseService = require(Services.BaseService)
local PlayerDataService = require(Services.PlayerDataService)
local EggService = require(Services.EggService)
local CreatureService = require(Services.CreatureService)
local IncubatorService = require(Services.IncubatorService)
local UpgradeService = require(Services.UpgradeService)
local WaveService = require(Services.WaveService)
local EventService = require(Services.EventService)
local TutorialService = require(Services.TutorialService)
local LeaderboardService = require(Services.LeaderboardService)
local StallService = require(Services.StallService)
local RebirthService = require(Services.RebirthService)
local MerchantService = require(Services.MerchantService)
local TradeService = require(Services.TradeService)
local VipService = require(Services.VipService)

local map = MapBuilder.Build()

PlayerDataService.Init()
EggService.Init()
CreatureService.Init()
IncubatorService.Init()
UpgradeService.Init()
TutorialService.Init()
RebirthService.Init()

-- Para el autoguardado: así PlayerDataService puede guardar los huevos que se están incubando ahora mismo
PlayerDataService.SetIncubatingProvider(IncubatorService.GetSnapshot)

-- Cuando un jugador recibe su base: cargamos sus datos y armamos su base.
-- El orden importa: primero su velocidad, después las mascotas en su hábitat y al final los nidos.
BaseService.OnAssigned(function(player, base)
	-- Load espera al DataStore. Si devuelve nil, el jugador se fue mientras cargaba (o lo tuvimos que sacar).
	if not PlayerDataService.Load(player) then
		return
	end
	UpgradeService.SetupBase(player, base)
	CreatureService.SetupBase(player, base)
	IncubatorService.SetupBase(player, base)
end)

-- Cuando se va: limpiamos su base (las incubadoras pasan sus huevos al perfil) y guardamos sus datos.
BaseService.OnReleased(function(player, base)
	IncubatorService.ClearBase(player)
	CreatureService.ClearBase(player)
	UpgradeService.ClearBase(player, base)
	PlayerDataService.Unload(player)
end)

-- Init de BaseService va al final: recién ahí empieza a repartir bases (y a llamar a lo de arriba).
BaseService.Init(map)

-- Las olas del volcán y los eventos especiales
WaveService.Init(map)
EventService.Init()

-- Puestos del lobby y tableros de récords
StallService.Init(map)
MerchantService.Init(map)
TradeService.Init(map)
VipService.Init(map)
LeaderboardService.Init(map)

print("[EggStorm] Server ready")

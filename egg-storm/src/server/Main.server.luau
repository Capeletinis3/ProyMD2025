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
local FriendService = require(Services.FriendService)
local PotionService = require(Services.PotionService)
local EggRainService = require(Services.EggRainService)
local ReceiptService = require(Services.ReceiptService)
local SpinService = require(Services.SpinService)

local map = MapBuilder.Build()
ReceiptService.Init() -- (antes que los que venden con Robux: VIP y ruleta)

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
	PotionService.SetupBase(player)
	SpinService.SetupBase(player)
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

-- Las olas del volcán, los eventos especiales, la lluvia de huevos y las pociones
WaveService.Init(map)
EventService.Init()
EggRainService.Init()
PotionService.Init()

-- Puestos del lobby y tableros de récords
StallService.Init(map)
MerchantService.Init(map)
TradeService.Init(map)
VipService.Init(map)
LeaderboardService.Init(map)
FriendService.Init()
SpinService.Init()

print("[EggStorm] Server ready")

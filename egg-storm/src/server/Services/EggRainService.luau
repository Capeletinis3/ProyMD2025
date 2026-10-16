--!strict
-- EggRainService: la "Lluvia de huevos" (tiene su reloj en el HUD).
-- Cada Config.EggRain.Interval segundos, durante Duration segundos caen huevos del cielo por todo el cañón:
-- de la rareza de la zona donde caen (o la siguiente, con poca chance) y con más chance de variantes.
-- Si nadie los agarra, desaparecen después de un rato (ver EggService, opción Rain).
-- Para el cliente: Workspace "NextEggRainAt" y "EggRainEndsAt" (horas del servidor).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EggService = require(script.Parent.EggService)

local EggRainService = {}

local notifyRemote = Remotes.Event("Notify")
local active: { EggService.Egg } = {}
local raining = false

local function countActive(): number
	local alive = {}
	for _, egg in active do
		if egg.Part.Parent ~= nil and egg.State ~= "Carried" then
			table.insert(alive, egg)
		end
	end
	active = alive
	return #alive
end

function EggRainService.IsRaining(): boolean
	return raining
end

-- Empieza una lluvia ahora (la llama el reloj de Init; las pruebas la pueden llamar directo)
function EggRainService.Start()
	if raining then
		return
	end
	local rain = Config.EggRain
	raining = true
	Workspace:SetAttribute("EggRainEndsAt", Workspace:GetServerTimeNow() + rain.Duration)
	notifyRemote:FireAllClients("🥚 EGG RAIN! Eggs are falling all over the canyon!")
	task.spawn(function()
		local endsAt = os.clock() + rain.Duration
		while os.clock() < endsAt do
			if countActive() < rain.MaxEggs then
				table.insert(active, EggService.SpawnEgg({ Rain = true }))
			end
			task.wait(rain.DropEvery)
		end
		raining = false
		Workspace:SetAttribute("EggRainEndsAt", nil)
	end)
end

function EggRainService.Init()
	task.spawn(function()
		while true do
			Workspace:SetAttribute("NextEggRainAt", Workspace:GetServerTimeNow() + Config.EggRain.Interval)
			task.wait(Config.EggRain.Interval)
			EggRainService.Start()
			task.wait(Config.EggRain.Duration)
		end
	end)
end

return EggRainService

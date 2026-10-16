--!strict
-- PotionService: las pociones que vende el Comerciante.
--   * Luck x2: la mejora de Suerte cuenta el doble (y sirve aunque no la tengas: ver Config.LuckChance)
--   * Fast Nests: los nidos incuban el doble de rápido (ver IncubatorService)
-- El tiempo que les queda se guarda en el perfil (LuckPotion / FastNestPotion, en segundos) y solo corre mientras jugás.
-- Para el cliente: atributos "LuckPotion" y "FastNestPotion" (segundos que quedan) y "LuckBoost" (el multiplicador).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PotionService = {}

export type PotionId = "Luck" | "FastNest"

local FIELDS: { [string]: string } = { Luck = "LuckPotion", FastNest = "FastNestPotion" }

local function sync(player: Player)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	player:SetAttribute("LuckPotion", math.ceil(profile.LuckPotion))
	player:SetAttribute("FastNestPotion", math.ceil(profile.FastNestPotion))
	player:SetAttribute("LuckBoost", if profile.LuckPotion > 0 then Config.Potions.Luck.Multiplier else nil)
end

function PotionService.IsValid(id: unknown): boolean
	return typeof(id) == "string" and FIELDS[id] ~= nil
end

-- Suma "seconds" a una poción (sin pasarse de Config.Potions.MaxTime). Devuelve false si no se pudo.
function PotionService.Add(player: Player, id: PotionId, seconds: number?): boolean
	local profile = PlayerDataService.Get(player)
	local info = (Config.Potions :: any)[id]
	if not profile or not info then
		return false
	end
	local field = FIELDS[id]
	local current = (profile :: any)[field] :: number
	if current >= Config.Potions.MaxTime then
		return false
	end
	(profile :: any)[field] = math.min(Config.Potions.MaxTime, current + (seconds or info.Duration))
	sync(player)
	return true
end

-- Segundos que le quedan a una poción
function PotionService.TimeLeft(player: Player, id: PotionId): number
	local profile = PlayerDataService.Get(player)
	return if profile then (profile :: any)[FIELDS[id]] :: number else 0
end

-- Cuánto más rápido incuban sus nidos ahora (1 = normal)
function PotionService.HatchMultiplier(player: Player): number
	return if PotionService.TimeLeft(player, "FastNest") > 0 then Config.Potions.FastNest.Multiplier else 1
end

-- Avanza el reloj de las pociones (lo llama el loop de Init; las pruebas lo pueden llamar directo)
function PotionService.Tick(dt: number)
	for _, player in Players:GetPlayers() do
		local profile = PlayerDataService.Get(player)
		if profile and (profile.LuckPotion > 0 or profile.FastNestPotion > 0) then
			profile.LuckPotion = math.max(0, profile.LuckPotion - dt)
			profile.FastNestPotion = math.max(0, profile.FastNestPotion - dt)
			sync(player)
		end
	end
end

-- Cuando carga sus datos: le mostramos las pociones que le quedaban
function PotionService.SetupBase(player: Player)
	sync(player)
end

function PotionService.Init()
	task.spawn(function()
		while true do
			task.wait(1)
			PotionService.Tick(1)
		end
	end)
end

return PotionService

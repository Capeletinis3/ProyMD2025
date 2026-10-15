--!strict
-- StormService: el ciclo de la tormenta.
--   Rain    (60 s): cielo oscuro y caen huevos
--   Warning (10 s): cartel "WAVE INCOMING" (lo dibuja el cliente)
--   Wave          : una pared de agua sale del mar y recorre el pasillo hasta la línea segura (Z = 0)
--   Calm    (20 s): vuelve el sol
--
-- El servidor decide TODO lo importante (a quién agarra la ola, qué huevos se borran).
-- Para que la ola se vea suave, cada cliente la dibuja con la misma fórmula usando estos atributos de Workspace:
--   StormPhase, PhaseEndsAt, WaveStartedAt, WaveStartZ, WaveSpeed
-- Al empezar cada tormenta se sortea si tiene evento especial (EventService → atributo StormEvent).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EggService = require(script.Parent.EggService)
local EventService = require(script.Parent.EventService)

export type Phase = "Rain" | "Warning" | "Wave" | "Calm"

local StormService = {}

local SAFE_LINE_Z = 0 -- todo lo que esté en Z < 0 es el lobby (zona segura); ver MapBuilder

local notifyRemote = Remotes.Event("Notify")
local currentPhase: Phase = "Calm"
local colorCorrection: ColorCorrectionEffect
local clouds: Clouds?

-- ===== Clima =====

local CALM_LIGHTING = {
	Brightness = 2.4,
	Ambient = Color3.fromRGB(130, 130, 140),
	OutdoorAmbient = Color3.fromRGB(160, 160, 170),
	FogEnd = 100000,
	FogColor = Color3.fromRGB(192, 192, 192),
}
local STORM_LIGHTING = {
	Brightness = 0.7,
	Ambient = Color3.fromRGB(60, 60, 85),
	OutdoorAmbient = Color3.fromRGB(70, 75, 100),
	FogEnd = 700,
	FogColor = Color3.fromRGB(70, 75, 95),
}

-- Con sol los colores están bien vivos; en la tormenta se apagan un poco
-- (en Golden Rain la tormenta se ve dorada).
local CALM_SATURATION = 0.25
local STORM_TINT = Color3.fromRGB(200, 210, 235)
local GOLDEN_TINT = Color3.fromRGB(255, 230, 170)

local function setStormWeather(stormy: boolean)
	local info = TweenInfo.new(3, Enum.EasingStyle.Sine)
	local golden = EventService.IsActive("GoldenRain")
	TweenService:Create(Lighting, info, if stormy then STORM_LIGHTING else CALM_LIGHTING):Play()
	TweenService:Create(colorCorrection, info, {
		Saturation = if stormy then (if golden then 0 else -0.35) else CALM_SATURATION,
		Contrast = if stormy then 0 else 0.08,
		TintColor = if not stormy then Color3.new(1, 1, 1) elseif golden then GOLDEN_TINT else STORM_TINT,
	}):Play()
	if clouds then
		TweenService:Create(clouds, info, {
			Cover = if stormy then 0.9 else 0.5,
			Density = if stormy then 0.8 else 0.3,
			Color = if stormy then Color3.fromRGB(80, 85, 100) else Color3.new(1, 1, 1),
		}):Play()
	end
end

local function setupWeather()
	Lighting.ClockTime = 14
	for key, value in CALM_LIGHTING do
		(Lighting :: any)[key] = value
	end
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "StormTint"
	colorCorrection.Saturation = CALM_SATURATION
	colorCorrection.Contrast = 0.08
	colorCorrection.Parent = Lighting

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local c = Instance.new("Clouds")
		c.Cover = 0.5
		c.Density = 0.3
		c.Parent = terrain
		clouds = c
	end
end

-- ===== Fases =====

local function setPhase(phase: Phase, duration: number)
	currentPhase = phase
	Workspace:SetAttribute("StormPhase", phase)
	Workspace:SetAttribute("PhaseEndsAt", Workspace:GetServerTimeNow() + duration)
end

local function notifyAll(text: string)
	notifyRemote:FireAllClients(text)
end

-- ¿La ola agarra a este jugador? Solo si está en el pasillo (fuera del lobby), ya alcanzado por la ola y no muy arriba.
local function isCaught(root: BasePart, frontZ: number): boolean
	local position = root.Position
	return position.Z > SAFE_LINE_Z and position.Z >= frontZ and position.Y < Config.Map.FloorY + Config.Storm.WaveHeight
end

local function hitPlayer(player: Player, humanoid: Humanoid)
	local hadEgg = EggService.GetCarriedEgg(player) ~= nil
	EggService.LoseCarriedEgg(player)
	humanoid.Health = 0 -- reaparece en su base (BaseService lo lleva ahí)
	notifyRemote:FireClient(player, if hadEgg then "The wave got you! You lost your egg." else "The wave got you!")
end

local function runWave()
	local storm = Config.Storm
	local startZ = Config.Map.CorridorLength + Config.Map.SeaDepth
	local travelTime = (startZ - SAFE_LINE_Z) / storm.WaveSpeed

	Workspace:SetAttribute("WaveStartedAt", Workspace:GetServerTimeNow())
	Workspace:SetAttribute("WaveStartZ", startZ)
	Workspace:SetAttribute("WaveSpeed", storm.WaveSpeed)
	setPhase("Wave", travelTime)

	local startedAt = os.clock()
	while true do
		local frontZ = startZ - storm.WaveSpeed * (os.clock() - startedAt)

		-- Huevos del piso que la ola ya alcanzó
		EggService.ClearWorldEggsBeyond(frontZ)

		-- Jugadores que la ola ya alcanzó
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and isCaught(root, frontZ) then
				hitPlayer(player, humanoid)
			end
		end

		if frontZ <= SAFE_LINE_Z then
			break
		end
		task.wait(0.05)
	end
end

-- ===== API pública =====

function StormService.GetPhase(): Phase
	return currentPhase
end

function StormService.Init()
	Players.RespawnTime = Config.Storm.RespawnTime
	EventService.Set(nil)
	setupWeather()

	task.spawn(function()
		local storm = Config.Storm
		while true do
			-- Lluvia: cielo oscuro y caen huevos. Primero se sortea el evento, así el cliente
			-- ya lo sabe cuando ve empezar la fase (y muestra el cartel del evento).
			local event = EventService.RollForStorm()
			setPhase("Rain", storm.RainDuration)
			setStormWeather(true)
			EggService.SetRaining(true)
			notifyAll(if event
				then `{event.DisplayName}! {event.Description}`
				else "The storm is here! Grab eggs and bring them home!")
			task.wait(storm.RainDuration)

			-- Aviso: dejan de caer huevos y el cliente muestra "WAVE INCOMING"
			EggService.SetRaining(false)
			setPhase("Warning", storm.WarningDuration)
			task.wait(storm.WarningDuration)

			-- La ola
			runWave()

			-- Calma: termina el evento y, por las dudas, borramos cualquier huevo que haya quedado
			EventService.Set(nil)
			EggService.ClearWorldEggs()
			setPhase("Calm", storm.CalmDuration)
			setStormWeather(false)
			task.wait(storm.CalmDuration)
		end
	end)
end

return StormService

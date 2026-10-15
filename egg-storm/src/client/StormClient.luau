--!strict
-- StormClient: todo lo que el jugador VE y ESCUCHA de la tormenta.
--   - Arriba de la pantalla: en qué fase estamos y cuánto falta.
--   - Durante el aviso: cartel grande "WAVE INCOMING" con cuenta regresiva y un pitido por segundo.
--   - Si la tormenta tiene evento (atributo StormEvent): un cartel grande al empezar y el nombre arriba.
--   - Lluvia que cae alrededor de la cámara.
--   - La ola: este cliente la dibuja con la misma fórmula que usa el servidor para decidir a quién agarra,
--     así se mueve suave (sin los saltitos que tendría si la moviera el servidor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer

local StormClient = {}

local FONT = Enum.Font.FredokaOne

local PHASE_TEXT: { [string]: string } = {
	Rain = "EGG RAIN",
	Warning = "WAVE INCOMING",
	Wave = "WAVE!",
	Calm = "CALM",
}
local PHASE_COLOR: { [string]: Color3 } = {
	Rain = Color3.fromRGB(120, 200, 255),
	Warning = Color3.fromRGB(255, 80, 80),
	Wave = Color3.fromRGB(255, 80, 80),
	Calm = Color3.fromRGB(150, 255, 150),
}

local phaseLabel: TextLabel
local banner: TextLabel
local bannerCount: TextLabel
local eventTitle: TextLabel
local eventDescription: TextLabel
local eventShownAt = -math.huge
local rainEmitter: ParticleEmitter
local rainHolder: Part
local warningSound: Sound
local waveSound: Sound
local waveModel: Model? = nil
local lastBeepSecond = -1

local function stroke(label: TextLabel, thickness: number)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Parent = label
end

local function phase(): string
	local value = Workspace:GetAttribute("StormPhase")
	return if typeof(value) == "string" then value else ""
end

local function remaining(): number
	local endsAt = Workspace:GetAttribute("PhaseEndsAt")
	if typeof(endsAt) ~= "number" then
		return 0
	end
	return math.max(0, endsAt - Workspace:GetServerTimeNow())
end

local NORMAL_RAIN = ColorSequence.new(Color3.fromRGB(190, 210, 255))
local GOLDEN_RAIN = ColorSequence.new(Color3.fromRGB(255, 215, 90))
local BANNER_TOP = 124 -- px desde arriba donde empiezan los carteles grandes
local TUTORIAL_SPACE = 76 -- si el tutorial está activo, su cartel ocupa ese lugar: bajamos los nuestros
local TUTORIAL_DONE = 5 -- igual que en TutorialService
local EVENT_BANNER_TIME = 5 -- segundos que se ve el cartel grande del evento

local function currentEvent(): Config.EventInfo?
	local id = Workspace:GetAttribute("StormEvent")
	return if typeof(id) == "string" then Config.GetEvent(id) else nil
end

local function formatTime(seconds: number): string
	local s = math.ceil(seconds)
	return string.format("%d:%02d", s // 60, s % 60)
end

-- ===== Armado =====

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "StormUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Cartelito de arriba: fondo oscuro redondeado con la fase y el tiempo
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 62)
	pill.Size = UDim2.fromOffset(300, 46)
	pill.BackgroundColor3 = UIKit.Colors.Panel
	pill.BackgroundTransparency = 0.15
	pill.Parent = gui
	UIKit.Corner(pill, 23)
	UIKit.FitToScreen(pill, Vector2.new(300, 46), Vector2.new(24, 0))

	phaseLabel = UIKit.Label(pill, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 26)
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Center
	stroke(phaseLabel, 2)

	-- Los carteles grandes van debajo del cartelito de arriba (que llega hasta ~110 px), así no se pisan en celulares
	banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, BANNER_TOP)
	banner.Size = UDim2.fromScale(0.8, 0.12)
	banner.BackgroundTransparency = 1
	banner.Font = FONT
	banner.TextScaled = true
	banner.TextColor3 = Color3.fromRGB(255, 70, 70)
	banner.Text = "WAVE INCOMING!"
	banner.Visible = false
	banner.Parent = gui
	stroke(banner, 4)

	bannerCount = Instance.new("TextLabel")
	bannerCount.AnchorPoint = Vector2.new(0.5, 0)
	bannerCount.Position = UDim2.new(0.5, 0, 0.12, BANNER_TOP + 6)
	bannerCount.Size = UDim2.fromScale(0.3, 0.12)
	bannerCount.BackgroundTransparency = 1
	bannerCount.Font = FONT
	bannerCount.TextScaled = true
	bannerCount.TextColor3 = Color3.new(1, 1, 1)
	bannerCount.Visible = false
	bannerCount.Parent = gui
	stroke(bannerCount, 4)

	-- Cartel del evento: nombre grande y una línea que explica qué hace
	eventTitle = Instance.new("TextLabel")
	eventTitle.AnchorPoint = Vector2.new(0.5, 0)
	eventTitle.Position = UDim2.new(0.5, 0, 0, BANNER_TOP)
	eventTitle.Size = UDim2.fromScale(0.75, 0.1)
	eventTitle.BackgroundTransparency = 1
	eventTitle.Font = FONT
	eventTitle.TextScaled = true
	eventTitle.Visible = false
	eventTitle.Parent = gui
	stroke(eventTitle, 4)

	eventDescription = Instance.new("TextLabel")
	eventDescription.AnchorPoint = Vector2.new(0.5, 0)
	eventDescription.Position = UDim2.new(0.5, 0, 0.1, BANNER_TOP + 6)
	eventDescription.Size = UDim2.fromScale(0.7, 0.05)
	eventDescription.BackgroundTransparency = 1
	eventDescription.Font = FONT
	eventDescription.TextScaled = true
	eventDescription.TextColor3 = Color3.new(1, 1, 1)
	eventDescription.Visible = false
	eventDescription.Parent = gui
	stroke(eventDescription, 3)
end

-- Cuando empieza una tormenta con evento: el cartel aparece con un "pop"
local function onEventChanged()
	local event = currentEvent()
	if not event then
		return
	end
	eventTitle.Text = `⚡ {event.DisplayName} ⚡`
	eventTitle.TextColor3 = event.Color
	eventDescription.Text = event.Description
	eventShownAt = os.clock()
	local scale = eventTitle:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = eventTitle
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function buildRain()
	-- Una Part invisible que sigue a la cámara, con partículas que caen
	rainHolder = Instance.new("Part")
	rainHolder.Name = "RainEmitter"
	rainHolder.Size = Vector3.new(160, 1, 160)
	rainHolder.Transparency = 1
	rainHolder.Anchored = true
	rainHolder.CanCollide = false
	rainHolder.CanQuery = false
	rainHolder.CanTouch = false
	rainHolder.Parent = Workspace

	rainEmitter = Instance.new("ParticleEmitter")
	rainEmitter.EmissionDirection = Enum.NormalId.Bottom
	rainEmitter.Shape = Enum.ParticleEmitterShape.Box
	rainEmitter.Rate = 0
	rainEmitter.Speed = NumberRange.new(90, 110)
	rainEmitter.Lifetime = NumberRange.new(0.7, 0.9)
	rainEmitter.Size = NumberSequence.new(0.15)
	rainEmitter.Color = NORMAL_RAIN
	rainEmitter.Transparency = NumberSequence.new(0.3)
	rainEmitter.LightEmission = 0.3
	rainEmitter.Parent = rainHolder
end

local function buildSounds()
	warningSound = Instance.new("Sound")
	warningSound.SoundId = Config.Storm.WarningSoundId
	warningSound.Volume = 0.6
	warningSound.Parent = Workspace

	waveSound = Instance.new("Sound")
	waveSound.SoundId = Config.Storm.WaveSoundId
	waveSound.Volume = 0.8
	waveSound.Parent = Workspace
end

-- La ola: pared de agua + espuma blanca arriba, del ancho del pasillo
local function buildWave(): Model
	local storm = Config.Storm
	local width = Config.Map.CorridorWidth
	local model = Instance.new("Model")
	model.Name = "Wave"

	local water = Instance.new("Part")
	water.Name = "Water"
	water.Size = Vector3.new(width, storm.WaveHeight, storm.WaveThickness)
	water.Color = Color3.fromRGB(40, 140, 255)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.2
	water.Anchored = true
	water.CanCollide = false
	water.CanQuery = false
	water.CanTouch = false
	water.Parent = model
	model.PrimaryPart = water

	local foam = Instance.new("Part")
	foam.Name = "Foam"
	foam.Size = Vector3.new(width, 3, storm.WaveThickness * 0.6)
	foam.Color = Color3.fromRGB(240, 250, 255)
	foam.Material = Enum.Material.SmoothPlastic
	foam.Anchored = true
	foam.CanCollide = false
	foam.CanQuery = false
	foam.CanTouch = false
	foam.Parent = model

	model.Parent = Workspace
	return model
end

-- Dónde está el frente de la ola ahora (misma fórmula que el servidor)
local function waveFrontZ(): number?
	local startedAt = Workspace:GetAttribute("WaveStartedAt")
	local startZ = Workspace:GetAttribute("WaveStartZ")
	local speed = Workspace:GetAttribute("WaveSpeed")
	if typeof(startedAt) ~= "number" or typeof(startZ) ~= "number" or typeof(speed) ~= "number" then
		return nil
	end
	local front = startZ - speed * (Workspace:GetServerTimeNow() - startedAt)
	return math.max(front, 0)
end

-- ===== Cada frame =====

local function update()
	local current = phase()
	local left = remaining()

	-- Texto de arriba (durante la lluvia, si hay evento, se ve el nombre del evento)
	local event = currentEvent()
	local eventRain = event ~= nil and current == "Rain"
	phaseLabel.Text = if current == "Wave" then "WAVE!"
		elseif eventRain and event then `{event.DisplayName}  {formatTime(left)}`
		else `{PHASE_TEXT[current] or ""}  {formatTime(left)}`
	phaseLabel.TextColor3 = if eventRain and event then event.Color else PHASE_COLOR[current] or Color3.new(1, 1, 1)

	-- Cartel grande del evento, los primeros segundos
	local showEvent = event ~= nil and os.clock() - eventShownAt < EVENT_BANNER_TIME and current ~= "Warning"
	eventTitle.Visible = showEvent
	eventDescription.Visible = showEvent

	-- Carteles grandes: debajo del cartel del tutorial si está activo
	local step = player:GetAttribute("TutorialStep")
	local top = BANNER_TOP + (if typeof(step) == "number" and step < TUTORIAL_DONE then TUTORIAL_SPACE else 0)
	banner.Position = UDim2.new(0.5, 0, 0, top)
	bannerCount.Position = UDim2.new(0.5, 0, 0.12, top + 6)
	eventTitle.Position = UDim2.new(0.5, 0, 0, top)
	eventDescription.Position = UDim2.new(0.5, 0, 0.1, top + 6)

	-- Cartel grande de aviso, que late
	local warning = current == "Warning"
	banner.Visible = warning
	bannerCount.Visible = warning
	if warning then
		local second = math.ceil(left)
		bannerCount.Text = tostring(second)
		local pulse = 1 + 0.08 * math.sin(os.clock() * 10)
		banner.Size = UDim2.fromScale(0.8 * pulse, 0.12 * pulse)
		if second ~= lastBeepSecond and second > 0 then
			lastBeepSecond = second
			warningSound:Play()
		end
	else
		lastBeepSecond = -1
	end

	-- Lluvia alrededor de la cámara
	local camera = Workspace.CurrentCamera
	if camera then
		rainHolder.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 40, 0))
	end
	rainEmitter.Rate = if current == "Rain" or current == "Warning" or current == "Wave" then 600 else 0
	rainEmitter.Color = if event and event.Id == "GoldenRain" then GOLDEN_RAIN else NORMAL_RAIN

	-- La ola
	if current == "Wave" then
		local front = waveFrontZ()
		if front then
			local model: Model
			if waveModel then
				model = waveModel
			else
				model = buildWave()
				waveModel = model
				waveSound:Play()
			end
			local storm = Config.Storm
			local centerZ = front + storm.WaveThickness / 2
			local y = Config.Map.FloorY
			local water = model:FindFirstChild("Water")
			local foam = model:FindFirstChild("Foam")
			if water and water:IsA("BasePart") then
				water.CFrame = CFrame.new(0, y + storm.WaveHeight / 2, centerZ)
			end
			if foam and foam:IsA("BasePart") then
				-- La espuma va un poquito adelante y arriba, y se mueve un poco para que parezca viva
				foam.CFrame = CFrame.new(0, y + storm.WaveHeight + 0.5 + math.sin(os.clock() * 6) * 0.4, front + storm.WaveThickness * 0.3)
			end
		end
	elseif waveModel then
		waveModel:Destroy()
		waveModel = nil
		waveSound:Stop()
	end
end

function StormClient.Start()
	buildGui()
	buildRain()
	buildSounds()
	Workspace:GetAttributeChangedSignal("StormEvent"):Connect(onEventChanged)
	onEventChanged()
	RunService.RenderStepped:Connect(update)
end

return StormClient

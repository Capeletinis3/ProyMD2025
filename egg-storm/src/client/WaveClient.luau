--!strict
-- WaveClient: todo lo que el jugador VE y ESCUCHA de las olas y los eventos.
--   - Arriba de la pantalla: cuánto falta para la próxima ola (y abajo, el evento activo si hay).
--   - Durante el aviso: cartel grande "THE WAVE IS COMING!" con cuenta regresiva, cuerno y la cámara tiembla
--     (si estás en el cañón).
--   - La ola: este cliente la dibuja con la misma fórmula que usa el servidor para decidir a quién agarra,
--     así se mueve suave (sin los saltitos que tendría si la moviera el servidor).
--   - Cuando empieza un evento: un cartel grande con su nombre y qué hace.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer

local WaveClient = {}

local FONT = Enum.Font.FredokaOne
local BANNER_TOP = 160 -- px desde arriba donde empiezan los carteles grandes (debajo de los cartelitos de arriba)
local TUTORIAL_SPACE = 76 -- si el tutorial está activo, su cartel ocupa ese lugar: bajamos los nuestros
local TUTORIAL_DONE = 5 -- igual que en TutorialService
local EVENT_BANNER_TIME = 5 -- segundos que se ve el cartel grande del evento
local WAVE_COLOR = Color3.fromRGB(168, 238, 246)
local RED = Color3.fromRGB(255, 80, 80)

local phaseLabel: TextLabel
local eventPill: Frame
local eventPillLabel: TextLabel
local banner: TextLabel
local bannerHint: TextLabel
local bannerCount: TextLabel
local eventTitle: TextLabel
local eventDescription: TextLabel
local eventShownAt = -math.huge
local warningSound: Sound
local waveSound: Sound
local waveModel: Model? = nil
local fading = false
local lastBeepSecond = -1

local function stroke(label: TextLabel, thickness: number)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Parent = label
end

local function attribute(name: string): any
	return Workspace:GetAttribute(name)
end

local function phase(): string
	local value = attribute("WavePhase")
	return if typeof(value) == "string" then value else ""
end

local function untilTime(name: string): number
	local at = attribute(name)
	if typeof(at) ~= "number" then
		return 0
	end
	return math.max(0, at - Workspace:GetServerTimeNow())
end

local function formatTime(seconds: number): string
	local s = math.ceil(seconds)
	return string.format("%d:%02d", s // 60, s % 60)
end

local function currentEvent(): Config.EventInfo?
	local id = attribute("Event")
	return if typeof(id) == "string" then Config.GetEvent(id) else nil
end

local function isSuper(): boolean
	return attribute("WaveKind") == "Super"
end

local function inCanyon(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and root.Position.X > Config.Map.CanyonStartX
end

-- ===== Armado =====

local function bigLabel(gui: ScreenGui, size: UDim2, color: Color3, thickness: number): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, BANNER_TOP)
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = color
	label.Visible = false
	label.Parent = gui
	stroke(label, thickness)
	return label
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WaveUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Cartelito de arriba: cuánto falta para la ola
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 62)
	pill.Size = UDim2.fromOffset(320, 46)
	pill.BackgroundColor3 = UIKit.Colors.Panel
	pill.BackgroundTransparency = 0.15
	pill.Parent = gui
	UIKit.Corner(pill, 23)
	UIKit.FitToScreen(pill, Vector2.new(320, 46), Vector2.new(24, 0))
	phaseLabel = UIKit.Label(pill, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 26)
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Center
	stroke(phaseLabel, 2)

	-- Debajo: el evento activo (si hay)
	eventPill = Instance.new("Frame")
	eventPill.AnchorPoint = Vector2.new(0.5, 0)
	eventPill.Position = UDim2.new(0.5, 0, 0, 114)
	eventPill.Size = UDim2.fromOffset(280, 34)
	eventPill.BackgroundColor3 = UIKit.Colors.Panel
	eventPill.BackgroundTransparency = 0.15
	eventPill.Visible = false
	eventPill.Parent = gui
	UIKit.Corner(eventPill, 17)
	UIKit.FitToScreen(eventPill, Vector2.new(280, 34), Vector2.new(24, 0))
	eventPillLabel = UIKit.Label(eventPill, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 20)
	eventPillLabel.TextXAlignment = Enum.TextXAlignment.Center
	stroke(eventPillLabel, 1.5)

	banner = bigLabel(gui, UDim2.fromScale(0.8, 0.11), RED, 4)
	bannerHint = bigLabel(gui, UDim2.fromScale(0.6, 0.05), Color3.new(1, 1, 1), 3)
	bannerCount = bigLabel(gui, UDim2.fromScale(0.3, 0.11), Color3.new(1, 1, 1), 4)
	eventTitle = bigLabel(gui, UDim2.fromScale(0.75, 0.1), Color3.new(1, 1, 1), 4)
	eventDescription = bigLabel(gui, UDim2.fromScale(0.7, 0.05), Color3.new(1, 1, 1), 3)
end

local function buildSounds()
	warningSound = Instance.new("Sound")
	warningSound.SoundId = Config.Waves.WarningSoundId
	warningSound.Volume = 0.8
	warningSound.Parent = Workspace

	waveSound = Instance.new("Sound")
	waveSound.SoundId = Config.Waves.WaveSoundId
	waveSound.Volume = 1
	waveSound.Parent = Workspace
end

-- La ola: pared de agua del ancho del cañón, con espuma blanca saliendo del frente
local function buildWave(height: number): Model
	local waves = Config.Waves
	local model = Instance.new("Model")
	model.Name = "Wave"

	local water = Instance.new("Part")
	water.Name = "Water"
	water.Size = Vector3.new(waves.Thickness, height, waves.Width)
	water.Color = WAVE_COLOR
	water.Material = Enum.Material.Glass
	water.Transparency = 0.3
	water.Anchored = true
	water.CanCollide = false
	water.CanQuery = false
	water.CanTouch = false
	water.Parent = model
	model.PrimaryPart = water

	local foam = Instance.new("ParticleEmitter")
	foam.Name = "Foam"
	foam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	foam.EmissionDirection = Enum.NormalId.Left -- el frente de la ola mira a -X (hacia el lobby)
	foam.Rate = 120
	foam.Lifetime = NumberRange.new(0.6, 1.2)
	foam.Speed = NumberRange.new(10, 18)
	foam.SpreadAngle = Vector2.new(30, 60)
	foam.Size = NumberSequence.new(2.5, 0.5)
	foam.Transparency = NumberSequence.new(0.1, 1)
	foam.Parent = water

	model.Parent = Workspace
	return model
end

-- Dónde está el frente de la ola ahora (misma fórmula que el servidor)
local function waveFrontX(): number?
	local startedAt = attribute("WaveStartedAt")
	local startX = attribute("WaveStartX")
	local speed = attribute("WaveSpeed")
	if typeof(startedAt) ~= "number" or typeof(startX) ~= "number" or typeof(speed) ~= "number" then
		return nil
	end
	local front = startX - speed * (Workspace:GetServerTimeNow() - startedAt)
	return math.max(front, Config.Waves.EndX)
end

-- Al llegar al portal la ola se desvanece
local function fadeWave()
	local model = waveModel
	if not model or fading then
		return
	end
	fading = true
	local water = model:FindFirstChild("Water")
	if water and water:IsA("BasePart") then
		local foam = water:FindFirstChild("Foam")
		if foam and foam:IsA("ParticleEmitter") then
			foam.Enabled = false
		end
		TweenService:Create(water, TweenInfo.new(Config.Waves.FadeTime), { Transparency = 1 }):Play()
	end
	waveSound:Stop()
	task.delay(Config.Waves.FadeTime, function()
		model:Destroy()
		if waveModel == model then
			waveModel = nil
		end
		fading = false
	end)
end

-- Cuando empieza un evento: el cartel aparece con un "pop"
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

-- La cámara tiembla un poco (solo si estás en el cañón)
local function shakeCamera(strength: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.CameraOffset = if strength > 0
			then Vector3.new(math.sin(os.clock() * 37) * strength, math.sin(os.clock() * 53) * strength, 0)
			else Vector3.zero
	end
end

-- ===== Cada frame =====

local function update()
	local current = phase()
	local left = untilTime("PhaseEndsAt")
	local super = isSuper()

	-- Cartelito de arriba
	if current == "Warning" then
		phaseLabel.Text = if super then `SUPER TSUNAMI {formatTime(left)}` else `WAVE INCOMING {formatTime(left)}`
		phaseLabel.TextColor3 = RED
	elseif current == "Wave" then
		phaseLabel.Text = if super then "SUPER TSUNAMI!" else "WAVE!"
		phaseLabel.TextColor3 = RED
	else
		phaseLabel.Text = `🌋 NEXT WAVE {formatTime(left)}`
		phaseLabel.TextColor3 = Color3.fromRGB(150, 230, 255)
	end

	local event = currentEvent()
	eventPill.Visible = event ~= nil
	if event then
		eventPillLabel.Text = `{event.DisplayName}  {formatTime(untilTime("EventEndsAt"))}`
		eventPillLabel.TextColor3 = event.Color
	end

	-- Carteles grandes: debajo del cartel del tutorial si está activo
	local step = player:GetAttribute("TutorialStep")
	local top = BANNER_TOP + (if typeof(step) == "number" and step < TUTORIAL_DONE then TUTORIAL_SPACE else 0)
	banner.Position = UDim2.new(0.5, 0, 0, top)
	bannerHint.Position = UDim2.new(0.5, 0, 0.11, top + 4)
	bannerCount.Position = UDim2.new(0.5, 0, 0.16, top + 8)
	eventTitle.Position = UDim2.new(0.5, 0, 0, top)
	eventDescription.Position = UDim2.new(0.5, 0, 0.1, top + 6)

	-- Aviso: cartel que late, cuenta regresiva, cuerno y temblor
	local warning = current == "Warning"
	banner.Visible = warning
	bannerHint.Visible = warning
	bannerCount.Visible = warning
	if warning then
		banner.Text = if super then "🌊 SUPER TSUNAMI! 🌊" else "THE WAVE IS COMING!"
		banner.TextColor3 = if super then Color3.fromRGB(200, 120, 255) else RED
		bannerHint.Text = if inCanyon() then "Hide in a cave!" else "Stay on the island!"
		local second = math.ceil(left)
		bannerCount.Text = tostring(second)
		local pulse = 1 + 0.08 * math.sin(os.clock() * 10)
		banner.Size = UDim2.fromScale(0.8 * pulse, 0.11 * pulse)
		if second ~= lastBeepSecond and second > 0 then
			lastBeepSecond = second
			warningSound:Play()
		end
	else
		lastBeepSecond = -1
	end
	local shaking = (warning or current == "Wave") and inCanyon()
	shakeCamera(if shaking then (if super then 0.35 else 0.15) else 0)

	-- Cartel grande del evento, los primeros segundos (salvo durante el aviso de ola)
	local showEvent = event ~= nil and os.clock() - eventShownAt < EVENT_BANNER_TIME and not warning
	eventTitle.Visible = showEvent
	eventDescription.Visible = showEvent

	-- La ola
	if current == "Wave" then
		local front = waveFrontX()
		if front then
			local heightValue = attribute("WaveHeight")
			local height = if typeof(heightValue) == "number" then heightValue else Config.Waves.Normal.Height
			if not waveModel and not fading then
				waveModel = buildWave(height)
				waveSound:Play()
			end
			local model = waveModel
			if model and not fading then
				local water = model:FindFirstChild("Water")
				if water and water:IsA("BasePart") then
					water.CFrame = CFrame.new(front + Config.Waves.Thickness / 2, Config.Map.FloorY + height / 2, 0)
				end
				if front <= Config.Waves.EndX then
					fadeWave()
				end
			end
		end
	elseif waveModel then
		fadeWave()
	end
end

function WaveClient.Start()
	buildGui()
	buildSounds()
	Workspace:GetAttributeChangedSignal("Event"):Connect(onEventChanged)
	onEventChanged()
	RunService.RenderStepped:Connect(update)
end

return WaveClient

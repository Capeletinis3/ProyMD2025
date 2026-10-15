--!strict
-- HatchReveal: la animación de apertura del huevo (lo que la gente graba).
--   1) Durante Config.Effects.HatchAnimationTime segundos el huevo de la incubadora tiembla
--      cada vez más fuerte y brilla cada vez más (con el color de su rareza).
--   2) Explota: destello + chispas, y el huevo desaparece.
--   3) Aparece el cartel grande "YOU GOT / Golden Dragon / LEGENDARY" con rayos de luz girando.
--      Si el huevo tenía variante, se ve en la línea de la rareza ("GOLDEN LEGENDARY") y en la plata (x3).
-- Todo esto pasa solo en la pantalla del dueño. El servidor espera el mismo tiempo antes de poner la mascota.
-- Si se abren varios huevos juntos, los carteles se muestran de a uno (en fila).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)

type Rarity = Config.Rarity
type Variant = Config.Variant

local player = Players.LocalPlayer

local HatchReveal = {}

local DESIGN = Vector2.new(700, 420)
-- Qué tan "fuerte" es el festejo según la rareza (rayos, destello en pantalla)
local INTENSITY: { [string]: number } = { Common = 0.3, Rare = 0.5, Epic = 0.75, Legendary = 1, Secret = 1 }

local gui: ScreenGui
local flash: Frame
local hatchSound: Sound
local queue: { { Name: string, Rarity: Rarity, Variant: Variant } } = {}
local showing = false

-- ===== 1 y 2: el huevo tiembla, brilla y explota =====

local function explode(position: Vector3, color: Color3)
	-- Esfera de luz que se agranda y se desvanece
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2, 2, 2)
	ball.CFrame = CFrame.new(position)
	ball.Color = color
	ball.Material = Enum.Material.Neon
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Parent = Workspace
	TweenService:Create(ball, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(16, 16, 16),
		Transparency = 1,
	}):Play()

	-- Chispas
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(20, 35)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(1, 0)
	sparks.Drag = 3
	sparks.Parent = holder
	sparks:Emit(80)

	task.delay(1.5, function()
		ball:Destroy()
		holder:Destroy()
	end)
end

-- Color del festejo: el de la variante si tiene, si no el de la rareza (blanco para Secret)
local function revealColor(rarity: Rarity, variant: Variant): Color3
	return if variant.Id ~= "Normal" then variant.Color
		elseif rarity.Id == "Secret" then Color3.new(1, 1, 1)
		else rarity.Color
end

local function animateEgg(eggPart: BasePart, rarity: Rarity, variant: Variant)
	local duration = Config.Effects.HatchAnimationTime
	local color = revealColor(rarity, variant)
	local baseCFrame = eggPart.CFrame

	-- Brillo que crece (solo en esta pantalla: los cambios del cliente no le llegan a nadie más)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Adornee = eggPart
	highlight.Parent = eggPart
	local light = eggPart:FindFirstChildOfClass("PointLight")

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		if not eggPart.Parent then
			connection:Disconnect()
			return
		end
		-- Tiembla cada vez más fuerte y más rápido
		local strength = 0.05 + t * t * 0.45
		local speed = 18 + t * 30
		local now = os.clock()
		local wobble = CFrame.Angles(math.sin(now * speed) * strength, 0, math.cos(now * speed * 1.3) * strength)
		eggPart.CFrame = baseCFrame * CFrame.new(0, math.abs(math.sin(now * speed * 0.5)) * t * 0.6, 0) * wobble
		highlight.FillTransparency = 1 - t * 0.85
		highlight.OutlineTransparency = 1 - t
		if light then
			light.Brightness = 1 + t * 8
			light.Range = 8 + t * 10
		end
		if t >= 1 then
			connection:Disconnect()
			eggPart.Transparency = 1
			highlight:Destroy()
			explode(eggPart.Position, color)
		end
	end)
end

-- ===== 3: el cartel =====

local function makeRays(parent: Instance, color: Color3, intensity: number): Frame
	local rays = Instance.new("Frame")
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(10, 10)
	rays.BackgroundTransparency = 1
	rays.Parent = parent
	local count = math.floor(6 + intensity * 10)
	for i = 1, count do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		-- No más largos que el cartel (el CanvasGroup recorta lo que se sale)
		ray.Size = UDim2.fromOffset(28 + intensity * 30, 300 + intensity * 110)
		ray.Rotation = (i / count) * 180
		ray.BackgroundColor3 = color
		ray.BorderSizePixel = 0
		ray.Parent = rays
		-- Más transparente en las puntas que en el centro
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.6 + (1 - intensity) * 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = ray
	end
	return rays
end

local function showBanner(name: string, rarity: Rarity, variant: Variant)
	local hasVariant = variant.Id ~= "Normal"
	-- Una variante buena festeja como una rareza alta
	local intensity = math.max(INTENSITY[rarity.Id] or 0.5, if hasVariant then math.min(1, 0.5 + variant.Multiplier / 20) else 0)
	local special = rarity.Id == "Legendary" or rarity.Id == "Secret" or variant.Multiplier >= 5
	local color = revealColor(rarity, variant)
	local nameColor = if rarity.Id == "Secret" then Color3.new(1, 1, 1) else rarity.Color

	-- Destello en toda la pantalla (más fuerte para las raras)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - intensity * 0.6
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	if hatchSound.SoundId ~= "" then
		hatchSound:Play()
	end

	-- CanvasGroup: deja desvanecer todo el cartel junto al final
	local group = Instance.new("CanvasGroup")
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.42)
	group.Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y)
	group.BackgroundTransparency = 1
	group.Parent = gui
	UIKit.FitToScreen(group, DESIGN, Vector2.new(20, 40))
	local pop = Instance.new("UIScale")
	pop.Scale = 0
	pop.Parent = group

	local rays = makeRays(group, color, intensity)

	-- Fondo oscuro detrás del texto, para que siempre se lea (aunque los rayos sean del mismo color)
	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.fromOffset(DESIGN.X / 2, 84)
	plate.Size = UDim2.fromOffset(620, 246)
	plate.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
	plate.BackgroundTransparency = 0.3
	plate.Parent = group
	UIKit.Corner(plate, 28)
	UIKit.Stroke(plate, 4, color).Transparency = 0.2

	local function bigLabel(text: string, y: number, height: number, size: number, textColor: Color3, strokeSize: number): TextLabel
		local label = UIKit.Label(group, text, UDim2.fromOffset(DESIGN.X, height), UDim2.fromOffset(0, y), size, textColor)
		label.TextXAlignment = Enum.TextXAlignment.Center
		UIKit.Stroke(label, strokeSize)
		return label
	end
	bigLabel("YOU GOT", 92, 40, 34, Color3.new(1, 1, 1), 3)
	local nameLabel = bigLabel(name, 132, 90, if #name > 16 then 58 else 72, nameColor, 5)
	local rarityText = string.upper(Config.WithVariant(variant, rarity.DisplayName))
	local rarityLabel = bigLabel(rarityText, 222, 56, 46, if hasVariant then variant.Color else nameColor, 4)
	local income = Config.GetIncome(rarity, variant)
	local incomeText = if hasVariant then `+{income} coins/sec  (x{variant.Multiplier})` else `+{income} coins/sec`
	bigLabel(incomeText, 284, 36, 28, Color3.fromRGB(130, 255, 130), 3)

	-- Arcoíris animado (Secret o variante Rainbow), brillo que pasa (Legendary o cualquier otra variante)
	local gradients: { UIGradient } = {}
	local function addRainbow(label: TextLabel)
		local g = Instance.new("UIGradient")
		g.Color = UIKit.Rainbow
		g.Parent = label
		table.insert(gradients, g)
	end
	local function addShine(label: TextLabel, base: Color3)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, base),
			ColorSequenceKeypoint.new(0.45, base),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 0.85)),
			ColorSequenceKeypoint.new(0.55, base),
			ColorSequenceKeypoint.new(1, base),
		})
		g.Parent = label
		table.insert(gradients, g)
	end
	if rarity.Id == "Secret" then
		addRainbow(nameLabel)
	elseif rarity.Id == "Legendary" then
		addShine(nameLabel, rarity.Color)
	end
	if variant.Id == "Rainbow" or (rarity.Id == "Secret" and not hasVariant) then
		addRainbow(rarityLabel)
	elseif hasVariant then
		addShine(rarityLabel, variant.Color)
	elseif rarity.Id == "Legendary" then
		addShine(rarityLabel, rarity.Color)
	end

	-- Entra con un "pop", los rayos giran y los degradés se mueven
	TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local started = os.clock()
	local spin = RunService.RenderStepped:Connect(function(dt: number)
		rays.Rotation += dt * (20 + intensity * 25)
		local t = os.clock() - started
		for _, g in gradients do
			g.Offset = Vector2.new(((t * 0.6) % 2) - 1, 0)
		end
	end)

	local hold = Config.Effects.RevealDuration + (if special then 1 else 0)
	task.wait(hold)
	local fade = TweenService:Create(group, TweenInfo.new(0.4), { GroupTransparency = 1 })
	fade:Play()
	fade.Completed:Wait()
	spin:Disconnect()
	group:Destroy()
end

local function processQueue()
	if showing then
		return
	end
	showing = true
	while #queue > 0 do
		local item = table.remove(queue, 1)
		if item then
			showBanner(item.Name, item.Rarity, item.Variant)
		end
	end
	showing = false
end

local function onHatched(creatureName: unknown, rarityId: unknown, eggPart: unknown, variantId: unknown)
	if typeof(creatureName) ~= "string" or typeof(rarityId) ~= "string" then
		return
	end
	local rarity = Config.GetRarity(rarityId)
	if not rarity then
		return
	end
	local variant = Config.GetVariant(if typeof(variantId) == "string" then variantId else nil)
	if typeof(eggPart) == "Instance" and eggPart:IsA("BasePart") then
		animateEgg(eggPart, rarity, variant)
	end
	-- El cartel aparece justo cuando explota el huevo
	task.delay(Config.Effects.HatchAnimationTime, function()
		table.insert(queue, { Name = creatureName, Rarity = rarity, Variant = variant })
		processQueue()
	end)
end

function HatchReveal.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "HatchReveal"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	hatchSound = Instance.new("Sound")
	hatchSound.SoundId = Config.Effects.HatchSoundId
	hatchSound.Volume = 0.8
	hatchSound.Parent = gui

	Remotes.Event("Hatched").OnClientEvent:Connect(onHatched)
end

return HatchReveal

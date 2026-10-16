--!strict
-- UIKit: ayudantes para armar la interfaz con el mismo estilo en todos lados
-- (colores, letra, bordes redondeados, contornos) y para que las ventanas entren en cualquier pantalla.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne

UIKit.Colors = {
	Panel = Color3.fromRGB(32, 34, 52),
	Row = Color3.fromRGB(48, 52, 76),
	Text = Color3.new(1, 1, 1),
	SubText = Color3.fromRGB(190, 195, 220),
	Gold = Color3.fromRGB(255, 215, 70),
	Green = Color3.fromRGB(70, 205, 95),
	Red = Color3.fromRGB(215, 75, 75),
	Gray = Color3.fromRGB(110, 112, 128),
	Accent = Color3.fromRGB(255, 205, 60),
}

UIKit.Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 255, 100)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 80, 255)),
})

function UIKit.Corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = parent
end

function UIKit.Stroke(parent: Instance, thickness: number, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = color or Color3.new(0, 0, 0)
	stroke.Parent = parent
	return stroke
end

-- Texto con tamaño de letra FIJO (no se aplasta ni se agranda solo).
-- Con UIScale toda la ventana se achica junta, así las proporciones nunca se rompen.
function UIKit.Label(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = UIKit.Font
	label.TextSize = textSize
	label.TextColor3 = color or UIKit.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.Parent = parent
	return label
end

function UIKit.Button(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.Font = UIKit.Font
	button.TextSize = textSize
	button.TextColor3 = UIKit.Colors.Text
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent
	UIKit.Corner(button, 10)
	UIKit.Stroke(button, 2, Color3.fromRGB(20, 20, 30)).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return button
end

-- Le pone un UIScale al frame para que una ventana de tamaño fijo (designSize, en píxeles)
-- entre siempre en la pantalla: en pantallas chicas se achica entera, sin deformarse.
function UIKit.FitToScreen(frame: GuiObject, designSize: Vector2, margin: Vector2?)
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local extra = margin or Vector2.new(32, 120)
	local function update()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		scale.Scale = math.min(1, (viewport.X - extra.X) / designSize.X, (viewport.Y - extra.Y) / designSize.Y)
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

-- Escala para las piezas del HUD (diseñadas para una pantalla de 1280×720): en pantallas chicas se achican todas igual.
local hudScales: { UIScale } = {}
local hudConnected = false

local function hudFactor(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	return math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.5, 1)
end

function UIKit.HudScale(frame: GuiObject)
	local scale = Instance.new("UIScale")
	scale.Scale = hudFactor()
	scale.Parent = frame
	table.insert(hudScales, scale)
	local camera = Workspace.CurrentCamera
	if camera and not hudConnected then
		hudConnected = true
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local factor = hudFactor()
			for _, s in hudScales do
				s.Scale = factor
			end
		end)
	end
end

-- El id de una imagen de Config.Images ("rbxassetid://..."), o nil si todavía no la subiste
function UIKit.ImageId(key: string): string?
	local value = Config.Images[key]
	if typeof(value) ~= "string" or value == "" then
		return nil
	end
	-- (también se puede pegar solo el número)
	return if string.match(value, "^%d+$") then "rbxassetid://" .. value else value
end

-- Imagen (si ya la subiste) o el emoji de reemplazo, del mismo tamaño y en el mismo lugar.
function UIKit.Icon(parent: Instance, key: string, emoji: string, size: UDim2, position: UDim2, textSize: number): GuiObject
	local id = UIKit.ImageId(key)
	if id then
		local image = Instance.new("ImageLabel")
		image.Name = key .. "Icon"
		image.BackgroundTransparency = 1
		image.Size = size
		image.Position = position
		image.Image = id
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = parent
		return image
	end
	local label = UIKit.Label(parent, emoji, size, position, textSize)
	label.Name = key .. "Icon"
	label.TextXAlignment = Enum.TextXAlignment.Center
	return label
end

-- Texto con contorno grueso negro (el estilo de los textos del HUD)
function UIKit.Outlined(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3?, thickness: number?): TextLabel
	local label = UIKit.Label(parent, text, size, position, textSize, color)
	label.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.Stroke(label, thickness or 2.5, Color3.fromRGB(17, 17, 17))
	return label
end

-- Ruleta de colores (para el botón GIRAR y la ventana de la ruleta). Son rayos finitos que salen del centro,
-- así que se puede girar entera cambiando el Rotation del marco que devuelve.
function UIKit.Wheel(parent: Instance, diameter: number, colors: { Color3 }): Frame
	local wheel = Instance.new("Frame")
	wheel.Name = "Wheel"
	wheel.Size = UDim2.fromOffset(diameter, diameter)
	wheel.BackgroundColor3 = Color3.new(1, 1, 1)
	wheel.Parent = parent
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = wheel
	UIKit.Stroke(wheel, math.max(2, diameter / 24), Color3.fromRGB(42, 10, 26))
	local radius = diameter / 2 - 2
	local rays = 72
	local width = math.max(3, 2 * math.pi * radius / rays + 1.5)
	for i = 0, rays / 2 - 1 do
		-- Cada línea cruza todo el círculo: la mitad de un lado tiene un color y la otra mitad el de enfrente
		local angle = i * 360 / rays
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = UDim2.fromOffset(radius * 2, width)
		line.Rotation = angle
		line.BackgroundTransparency = 1
		line.Parent = wheel
		for half = 0, 1 do
			local a = (angle + half * 180) % 360 -- ángulo de este rayo (0 = derecha, sentido del reloj)
			local segment = math.floor(((a + 90) % 360) / (360 / #colors)) + 1
			local ray = Instance.new("Frame")
			ray.BorderSizePixel = 0
			ray.Size = UDim2.new(0.5, 0, 1, 0)
			ray.Position = UDim2.fromScale(if half == 0 then 0.5 else 0, 0)
			ray.BackgroundColor3 = colors[segment]
			ray.Parent = line
		end
	end
	local hub = Instance.new("Frame")
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(diameter * 0.2, diameter * 0.2)
	hub.BackgroundColor3 = Color3.new(1, 1, 1)
	hub.ZIndex = 3
	hub.Parent = wheel
	local hubRound = Instance.new("UICorner")
	hubRound.CornerRadius = UDim.new(0.5, 0)
	hubRound.Parent = hub
	UIKit.Stroke(hub, math.max(1.5, diameter / 32), Color3.fromRGB(42, 10, 26))
	return wheel
end

-- Ventana centrada con título, borde dorado y botón X (se achica sola en pantallas chicas).
-- Devuelve el ScreenGui (empieza cerrado), el marco y el botón de cerrar.
function UIKit.Window(name: string, title: string, size: Vector2, displayOrder: number?): (ScreenGui, Frame, TextButton)
	local Players = game:GetService("Players")
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = displayOrder or 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = UIKit.Colors.Panel
	frame.Parent = gui
	UIKit.Corner(frame, 20)
	UIKit.Stroke(frame, 4, UIKit.Colors.Accent)
	UIKit.FitToScreen(frame, size)

	UIKit.Label(frame, title, UDim2.fromOffset(size.X - 120, 50), UDim2.fromOffset(28, 18), 36, UIKit.Colors.Accent)
	local closeButton = UIKit.Button(frame, "X", UDim2.fromOffset(52, 52), UDim2.fromOffset(size.X - 70, 17), 28, UIKit.Colors.Red)
	closeButton.Activated:Connect(function()
		gui.Enabled = false
	end)
	return gui, frame, closeButton
end

return UIKit

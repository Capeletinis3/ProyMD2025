--!strict
-- UIKit: ayudantes para armar la interfaz con el mismo estilo en todos lados
-- (colores, letra, bordes redondeados, contornos) y para que las ventanas entren en cualquier pantalla.

local Workspace = game:GetService("Workspace")

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

return UIKit

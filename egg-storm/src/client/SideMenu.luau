--!strict
-- SideMenu: los botones del HUD (diseño "HUD del jugador").
--   * Arriba a la izquierda: la ruleta GIRAR y 6 botones en 2 columnas: Shop, Trade, Index, V.I.P, Rebirth e Invite.
--   * Debajo: la barra "[T] Slow walk" (también se toca con el dedo).
--   * A la derecha: los 2 íconos grandes UPGRADE SHOP y MYSTERY MERCHANT.
-- Los botones están siempre; cada módulo les pone qué hacen con SideMenu.Bind(id, función).
-- Ids: "Spin", "Shop", "Trade", "Index", "Vip", "Rebirth", "Invite", "SlowWalk", "Upgrades", "Merchant".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer

local SideMenu = {}

export type ButtonId = string

local DARK = Color3.fromRGB(52, 48, 58)
local EDGE = Color3.fromRGB(17, 17, 17)
local GOLD = Color3.fromRGB(245, 184, 0)
local WHEEL_COLORS = {
	Color3.fromRGB(255, 106, 26), Color3.fromRGB(255, 212, 59), Color3.fromRGB(46, 158, 68),
	Color3.fromRGB(30, 155, 255), Color3.fromRGB(176, 38, 255), Color3.fromRGB(255, 95, 162),
}

type Info = { Id: string, Text: string, Icon: string, TextSize: number, Border: Color3?, TextColor: Color3? }

local GRID: { Info } = {
	{ Id = "Shop", Text = "Shop", Icon = "🛍️", TextSize = 19, Border = GOLD, TextColor = Color3.fromRGB(255, 212, 59) },
	{ Id = "Trade", Text = "Trade", Icon = "🔄", TextSize = 19 },
	{ Id = "Index", Text = "Index", Icon = "📗", TextSize = 19 },
	{ Id = "Vip", Text = "V.I.P", Icon = "👑", TextSize = 19 },
	{ Id = "Rebirth", Text = "Rebirth [0]", Icon = "🔁", TextSize = 15 },
	{ Id = "Invite", Text = "Invite", Icon = "👥", TextSize = 19 },
}

local actions: { [string]: () -> () } = {}
local labels: { [string]: TextLabel } = {}
local badges: { [string]: TextLabel } = {}
local buttons: { [string]: GuiButton } = {}
local built = false

local function press(id: string)
	local action = actions[id]
	if action then
		action()
	end
end

local function hookButton(id: string, button: GuiButton)
	buttons[id] = button
	button.Activated:Connect(function()
		press(id)
	end)
end

-- Botón cuadrado oscuro del diseño: ícono arriba y el nombre abajo con contorno
local function gridButton(parent: Instance, info: Info, position: UDim2)
	local button = Instance.new("TextButton")
	button.Name = info.Id
	button.Text = ""
	button.Size = UDim2.fromOffset(107, 74)
	button.Position = position
	button.BackgroundColor3 = DARK
	button.AutoButtonColor = true
	button.Parent = parent
	UIKit.Corner(button, 4)
	UIKit.Stroke(button, 3, info.Border or EDGE).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local icon = UIKit.Label(button, info.Icon, UDim2.fromOffset(107, 46), UDim2.fromOffset(0, 2), 34)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	labels[info.Id] = UIKit.Outlined(button, info.Text, UDim2.fromOffset(107, 24), UDim2.fromOffset(0, 50), info.TextSize, info.TextColor, 2.5)
	-- Cartelito chiquito (NEW!, +20%...), escondido hasta que alguien lo prenda
	local badge = UIKit.Outlined(button, "", UDim2.fromOffset(60, 20), UDim2.fromOffset(56, -12), 15, Color3.fromRGB(255, 59, 59), 2)
	badge.Rotation = 8
	badge.Visible = false
	badges[info.Id] = badge
	hookButton(info.Id, button)
end

-- Ícono grande de la derecha (con su nombre arriba y abajo)
local function bigIcon(parent: Instance, id: string, icon: string, top: string, bottom: string, color: Color3, y: number)
	local button = Instance.new("TextButton")
	button.Name = id
	button.Text = ""
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromOffset(120, 100)
	button.Position = UDim2.fromOffset(0, y)
	button.Parent = parent
	local emoji = UIKit.Label(button, icon, UDim2.fromOffset(120, 70), UDim2.fromOffset(0, 14), 58)
	emoji.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.Outlined(button, top, UDim2.fromOffset(120, 22), UDim2.fromOffset(0, -8), 19, color, 3)
	UIKit.Outlined(button, bottom, UDim2.fromOffset(120, 22), UDim2.fromOffset(0, 80), if #bottom > 9 then 15 else 19, color, 3)
	hookButton(id, button)
end

local function build()
	if built then
		return
	end
	built = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "SideMenu"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Columna de la izquierda
	local left = Instance.new("Frame")
	left.Name = "Left"
	left.BackgroundTransparency = 1
	left.Position = UDim2.fromOffset(12, 50)
	left.Size = UDim2.fromOffset(222, 420)
	left.Parent = gui
	UIKit.HudScale(left)

	-- Ruleta GIRAR
	local spin = Instance.new("TextButton")
	spin.Name = "Spin"
	spin.Text = ""
	spin.BackgroundTransparency = 1
	spin.Size = UDim2.fromOffset(130, 124)
	spin.Position = UDim2.fromOffset(46, 0)
	spin.Parent = left
	UIKit.Outlined(spin, "SPIN", UDim2.fromOffset(130, 26), UDim2.fromOffset(0, 0), 24, Color3.fromRGB(255, 95, 162), 3)
	local wheel = UIKit.Wheel(spin, 92, WHEEL_COLORS)
	wheel.Position = UDim2.fromOffset(19, 28)
	local pointer = UIKit.Label(spin, "▼", UDim2.fromOffset(30, 20), UDim2.fromOffset(50, 18), 20, Color3.fromRGB(229, 57, 53))
	pointer.TextXAlignment = Enum.TextXAlignment.Center
	pointer.ZIndex = 4
	UIKit.Stroke(pointer, 1.5, Color3.fromRGB(42, 10, 26))
	local spinBadge = UIKit.Outlined(spin, "", UDim2.fromOffset(80, 20), UDim2.fromOffset(70, 96), 15, Color3.fromRGB(108, 255, 77), 2)
	spinBadge.Rotation = -6
	spinBadge.ZIndex = 5
	spinBadge.Visible = false
	badges.Spin = spinBadge
	hookButton("Spin", spin)

	-- Los 6 botones
	for i, info in GRID do
		local column = (i - 1) % 2
		local row = (i - 1) // 2
		gridButton(left, info, UDim2.fromOffset(column * 115, 132 + row * 84))
	end

	-- Barra de caminar lento
	local slow = Instance.new("TextButton")
	slow.Name = "SlowWalk"
	slow.Text = ""
	slow.Size = UDim2.fromOffset(222, 34)
	slow.Position = UDim2.fromOffset(0, 384)
	slow.BackgroundColor3 = Color3.fromRGB(163, 163, 169)
	slow.Parent = left
	UIKit.Corner(slow, 3)
	UIKit.Stroke(slow, 3, Color3.fromRGB(34, 34, 34)).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	labels.SlowWalk = UIKit.Outlined(slow, `[{Config.Controls.SlowWalkKey.Name}] Slow walk: OFF`, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 15, nil, 2.5)
	hookButton("SlowWalk", slow)

	-- Íconos grandes de la derecha
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.BackgroundTransparency = 1
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.new(1, -8, 0.5, -20)
	right.Size = UDim2.fromOffset(120, 220)
	right.Parent = gui
	UIKit.HudScale(right)
	bigIcon(right, "Upgrades", "⏫", "UPGRADE", "SHOP", Color3.fromRGB(77, 210, 255), 0)
	bigIcon(right, "Merchant", "🛒", "MYSTERY", "MERCHANT", Color3.fromRGB(199, 125, 255), 116)
end

-- Le dice a un botón qué hacer cuando lo tocan.
function SideMenu.Bind(id: ButtonId, action: () -> ())
	build()
	actions[id] = action
end

-- Cambia el texto de un botón (por ejemplo "Rebirth [3]" o "Slow walk: ON").
function SideMenu.SetText(id: ButtonId, text: string)
	build()
	local label = labels[id]
	if label then
		label.Text = text
	end
end

-- Prende (con texto) o apaga (nil) el cartelito chiquito de un botón: "NEW!", "+20%", "READY!"...
function SideMenu.SetBadge(id: ButtonId, text: string?, color: Color3?)
	build()
	local badge = badges[id]
	if badge then
		badge.Visible = text ~= nil and text ~= ""
		badge.Text = text or ""
		if color then
			badge.TextColor3 = color
		end
	end
end

-- Hace lo mismo que tocar el botón (por ejemplo, el "+" de la velocidad abre las mejoras)
function SideMenu.Press(id: ButtonId)
	press(id)
end

-- El botón en sí (por ejemplo, para que el tutorial lo señale)
function SideMenu.Get(id: ButtonId): GuiButton?
	build()
	return buttons[id]
end

return SideMenu

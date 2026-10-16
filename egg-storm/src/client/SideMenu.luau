--!strict
-- SideMenu: la columna de botones grandes del costado izquierdo (Rebirth, Trade, VIP...).
-- Cada módulo agrega su botón con SideMenu.AddButton (el orden en que se agregan es el orden en pantalla).

local Players = game:GetService("Players")

local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer

local SideMenu = {}

local BUTTON = Vector2.new(120, 46)
local GAP = 8

local holder: Frame? = nil
local count = 0

local function getHolder(): Frame
	if holder then
		return holder
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SideMenu"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Position = UDim2.new(0, 16, 0.2, 0)
	frame.Size = UDim2.fromOffset(BUTTON.X, (BUTTON.Y + GAP) * 4)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	UIKit.FitToScreen(frame, Vector2.new(BUTTON.X, (BUTTON.Y + GAP) * 4), Vector2.new(400, 160))
	holder = frame
	return frame
end

-- Agrega un botón. Devuelve el botón (por si hay que cambiarle el texto o esconderlo).
function SideMenu.AddButton(text: string, color: Color3, onClick: () -> ()): TextButton
	local frame = getHolder()
	local button = UIKit.Button(frame, text, UDim2.fromOffset(BUTTON.X, BUTTON.Y), UDim2.fromOffset(0, count * (BUTTON.Y + GAP)), 22, color)
	count += 1
	button.Activated:Connect(onClick)
	return button
end

return SideMenu

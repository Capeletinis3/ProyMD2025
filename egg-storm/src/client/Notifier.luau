--!strict
-- Notifier: avisos cortos en pantalla ("You grabbed a Rare Egg!", "Not enough coins!"...).
-- Aparecen abajo en el centro, se apilan (máximo 3) y se desvanecen solos.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer

local Notifier = {}

local MAX_TOASTS = 3
local TOAST_HEIGHT = 46
local TOAST_GAP = 8

local container: Frame? = nil
local toasts: { CanvasGroup } = {}

local function getContainer(): Frame
	if container then
		return container
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Toasts"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -130) -- arriba de los nidos y los casilleros del HUD
	frame.Size = UDim2.fromOffset(520, (TOAST_HEIGHT + TOAST_GAP) * MAX_TOASTS)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	UIKit.FitToScreen(frame, Vector2.new(520, 160), Vector2.new(24, 260))
	container = frame
	return frame
end

-- Acomoda los avisos: el más nuevo abajo de todo
local function layout()
	for i, toast in toasts do
		local fromBottom = #toasts - i
		local y = -(fromBottom * (TOAST_HEIGHT + TOAST_GAP))
		TweenService:Create(toast, TweenInfo.new(0.2), { Position = UDim2.new(0.5, 0, 1, y) }):Play()
	end
end

local function remove(toast: CanvasGroup)
	local index = table.find(toasts, toast)
	if not index then
		return
	end
	table.remove(toasts, index)
	local fade = TweenService:Create(toast, TweenInfo.new(0.3), { GroupTransparency = 1 })
	fade.Completed:Connect(function()
		toast:Destroy()
	end)
	fade:Play()
	layout()
end

function Notifier.Show(text: string, duration: number?, color: Color3?)
	local parent = getContainer()

	-- CanvasGroup deja desvanecer todo el aviso junto (fondo + texto)
	local toast = Instance.new("CanvasGroup")
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, 0)
	toast.Size = UDim2.fromOffset(500, TOAST_HEIGHT)
	toast.BackgroundColor3 = Color3.fromRGB(25, 27, 42)
	toast.BackgroundTransparency = 0.15
	toast.GroupTransparency = 1
	toast.Parent = parent
	UIKit.Corner(toast, 14)

	local label = UIKit.Label(toast, text, UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), 22, color or UIKit.Colors.Text)
	label.TextXAlignment = Enum.TextXAlignment.Center

	table.insert(toasts, toast)
	if #toasts > MAX_TOASTS then
		remove(toasts[1])
	end
	layout()
	TweenService:Create(toast, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()

	task.delay(duration or 3.5, remove, toast)
end

return Notifier

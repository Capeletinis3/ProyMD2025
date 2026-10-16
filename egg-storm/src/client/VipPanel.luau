--!strict
-- VipPanel: la ventana del VIP (botón "👑 VIP" del costado o "Get VIP" en la cueva VIP).
-- A la izquierda el "ticket dorado" con el precio y el botón para comprar; a la derecha las 6 ventajas.
-- Abajo, "Gift it to a friend?" abre una lista de jugadores para regalarles el VIP.
-- Los botones solo PIDEN cosas: el servidor (VipService) abre la compra de Roblox y decide quién es VIP.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local vipRemote = Remotes.Event("Vip")
local C = UIKit.Colors

local VipPanel = {}

local SIZE = Vector2.new(660, 470)
local PICKER_SIZE = Vector2.new(560, 470)
local PICKER_SLOTS = 12
local ROBUX = utf8.char(0xE002) -- el ícono de Robux en los textos de Roblox
local GOLD = Color3.fromRGB(255, 200, 40)
local NAVY = Color3.fromRGB(24, 30, 58)
local CARD = Color3.fromRGB(34, 42, 78)

type Perk = { Badge: string, Title: string, Text: string, Color: Color3 }

local gui: ScreenGui
local buyButton: TextButton
local dailyText: TextLabel
local pickerGui: ScreenGui
local pickerButtons: { TextButton } = {}
local pickerEmpty: TextLabel
local lastClick = 0

local function clickOk(): boolean
	if os.clock() - lastClick < 0.4 then
		return false
	end
	lastClick = os.clock()
	return true
end

local function centered(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3?): TextLabel
	local label = UIKit.Label(parent, text, size, position, textSize, color)
	label.TextXAlignment = Enum.TextXAlignment.Center
	return label
end

local function perks(): { Perk }
	local v = Config.Vip
	return {
		{ Badge = `x{v.CoinMultiplier}`, Title = `X{v.CoinMultiplier} COINS`, Text = "Your creatures make double coins forever", Color = GOLD },
		{ Badge = "VIP", Title = "VIP CAVE", Text = "Secret golden shelter in the canyon", Color = Color3.fromRGB(255, 150, 40) },
		{ Badge = `{math.round(v.HatchSpeedBonus * 100)}%`, Title = "FAST HATCH", Text = `Your nests hatch eggs {math.round(v.HatchSpeedBonus * 100)}% faster`, Color = Color3.fromRGB(170, 100, 255) },
		{ Badge = `+{v.ExtraCarry}`, Title = "EXTRA HAND", Text = `Carry {v.ExtraCarry} more egg at the same time`, Color = Color3.fromRGB(80, 170, 255) },
		{ Badge = "★", Title = "DAILY EGG", Text = "A free golden egg every day", Color = Color3.fromRGB(80, 200, 90) },
		{ Badge = "TAG", Title = "GOLD TAG", Text = "Shiny crown over your head and in chat", Color = Color3.fromRGB(240, 90, 140) },
	}
end

-- Cuánto falta para el próximo huevo diario (solo para VIP)
local function dailyStatus(): string
	local nextAt = player:GetAttribute("NextDailyEgg")
	if typeof(nextAt) ~= "number" then
		return "A free golden egg every day"
	end
	local left = nextAt - Workspace:GetServerTimeNow()
	if left <= 0 then
		return "Ready! Free up a nest to get it"
	end
	local hours = math.floor(left / 3600)
	local minutes = math.floor((left % 3600) / 60)
	return `Next free egg in {hours}h {minutes}m`
end

local function refresh()
	local vip = Config.IsVip(player)
	if vip then
		buyButton.Text = "✓ OWNED"
		buyButton.BackgroundColor3 = C.Gray
	else
		buyButton.Text = `{ROBUX} BUY {Config.Vip.PriceRobux}`
		buyButton.BackgroundColor3 = C.Green
	end
	dailyText.Text = if vip then dailyStatus() else "A free golden egg every day"
end

function VipPanel.Open()
	refresh()
	pickerGui.Enabled = false
	gui.Enabled = true
end

-- ===== Lista para regalar =====

local function refreshPicker()
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and not Config.IsVip(other) then
			table.insert(others, other)
		end
	end
	table.sort(others, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	for i, button in pickerButtons do
		local other = others[i]
		button.Visible = other ~= nil
		if other then
			button.Text = `🎁 {other.DisplayName}`
			button:SetAttribute("UserId", other.UserId)
		end
	end
	pickerEmpty.Visible = #others == 0
end

function VipPanel.OpenGift()
	refreshPicker()
	gui.Enabled = false
	pickerGui.Enabled = true
end

local function buildPicker()
	local frame
	pickerGui, frame = UIKit.Window("VipGift", "GIFT VIP", PICKER_SIZE, 7)
	UIKit.Label(frame, "Pick a friend in this server to gift VIP:", UDim2.fromOffset(500, 30), UDim2.fromOffset(28, 72), 21, C.SubText)
	pickerEmpty = UIKit.Label(frame, "Everyone here already has VIP!", UDim2.fromOffset(500, 40), UDim2.fromOffset(28, 120), 24, C.Gray)
	for i = 1, PICKER_SLOTS do
		local col = (i - 1) % 2
		local row = (i - 1) // 2
		local button = UIKit.Button(frame, "", UDim2.fromOffset(244, 50), UDim2.fromOffset(28 + col * 260, 112 + row * 58), 22, C.Row)
		button.Visible = false
		button.Activated:Connect(function()
			local userId = button:GetAttribute("UserId")
			if typeof(userId) == "number" and clickOk() then
				vipRemote:FireServer("Gift", userId)
				pickerGui.Enabled = false
			end
		end)
		table.insert(pickerButtons, button)
	end
end

-- ===== Ventana =====

local function buildTicket(frame: Frame)
	local ticket = Instance.new("Frame")
	ticket.Size = UDim2.fromOffset(240, 200)
	ticket.Position = UDim2.fromOffset(28, 122)
	ticket.Rotation = -3
	ticket.BackgroundColor3 = Color3.fromRGB(255, 205, 70)
	ticket.Parent = frame
	UIKit.Corner(ticket, 14)
	UIKit.Stroke(ticket, 3, Color3.fromRGB(150, 100, 20))
	centered(ticket, "GOLDEN TICKET", UDim2.fromOffset(240, 22), UDim2.fromOffset(0, 12), 15, Color3.fromRGB(140, 90, 20))
	local title = centered(ticket, "VIP PASS", UDim2.fromOffset(240, 44), UDim2.fromOffset(0, 32), 40, Color3.new(1, 1, 1))
	UIKit.Stroke(title, 3, Color3.fromRGB(110, 60, 10))
	centered(ticket, "Egg Storm", UDim2.fromOffset(240, 20), UDim2.fromOffset(0, 78), 15, Color3.fromRGB(110, 70, 20))
	local dash = Instance.new("Frame")
	dash.Size = UDim2.fromOffset(200, 2)
	dash.Position = UDim2.fromOffset(20, 108)
	dash.BackgroundColor3 = Color3.fromRGB(190, 140, 40)
	dash.BorderSizePixel = 0
	dash.Parent = ticket
	centered(ticket, "FOREVER · ONE-TIME BUY", UDim2.fromOffset(240, 20), UDim2.fromOffset(0, 120), 14, Color3.fromRGB(110, 70, 20))
	local price = centered(ticket, `{ROBUX} {Config.Vip.PriceRobux}`, UDim2.fromOffset(240, 46), UDim2.fromOffset(0, 144), 40, Color3.new(1, 1, 1))
	UIKit.Stroke(price, 3, Color3.fromRGB(60, 120, 60))
end

local function buildPerk(frame: Frame, index: number, perk: Perk): TextLabel
	local col = (index - 1) % 2
	local row = (index - 1) // 2
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(166, 86)
	card.Position = UDim2.fromOffset(292 + col * 178, 120 + row * 96)
	card.BackgroundColor3 = CARD
	card.Parent = frame
	UIKit.Corner(card, 12)
	UIKit.Stroke(card, 1.5, Color3.fromRGB(60, 70, 120))
	local badge = centered(card, perk.Badge, UDim2.fromOffset(40, 40), UDim2.fromOffset(8, 10), 16)
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = perk.Color
	UIKit.Corner(badge, 20)
	UIKit.Stroke(badge, 1.5)
	local title = UIKit.Label(card, perk.Title, UDim2.fromOffset(108, 22), UDim2.fromOffset(54, 8), 16, perk.Color)
	UIKit.Stroke(title, 1.5)
	local text = UIKit.Label(card, perk.Text, UDim2.fromOffset(108, 50), UDim2.fromOffset(54, 30), 13, C.SubText)
	text.TextWrapped = true
	text.TextTruncate = Enum.TextTruncate.None
	text.TextYAlignment = Enum.TextYAlignment.Top
	return text
end

function VipPanel.Start()
	local frame
	gui, frame = UIKit.Window("VipPanel", "", SIZE, 6)
	frame.BackgroundColor3 = NAVY
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = GOLD
	end

	-- Corona, título y frase
	centered(frame, "👑", UDim2.fromOffset(100, 90), UDim2.fromOffset(SIZE.X / 2 - 50, -58), 70)
	local title = centered(frame, "VIP", UDim2.fromOffset(200, 66), UDim2.fromOffset(SIZE.X / 2 - 100, 22), 54, GOLD)
	UIKit.Stroke(title, 3, Color3.fromRGB(110, 60, 10))
	centered(frame, "Live like a king of the island", UDim2.fromOffset(SIZE.X - 40, 24), UDim2.fromOffset(20, 88), 18, C.Text)

	buildTicket(frame)
	buyButton = UIKit.Button(frame, "", UDim2.fromOffset(240, 60), UDim2.fromOffset(28, 342), 28, C.Green)
	buyButton.Activated:Connect(function()
		if clickOk() and not Config.IsVip(player) then
			vipRemote:FireServer("Buy")
		end
	end)
	local gift = Instance.new("TextButton")
	gift.Size = UDim2.fromOffset(240, 26)
	gift.Position = UDim2.fromOffset(28, 412)
	gift.BackgroundTransparency = 1
	gift.Font = UIKit.Font
	gift.TextSize = 16
	gift.TextColor3 = C.SubText
	gift.Text = "🎁 Gift it to a friend? Tap here"
	gift.Parent = frame
	gift.Activated:Connect(VipPanel.OpenGift)

	for index, perk in perks() do
		local text = buildPerk(frame, index, perk)
		if perk.Title == "DAILY EGG" then
			dailyText = text
		end
	end

	buildPicker()
	player:GetAttributeChangedSignal("VIP"):Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if gui.Enabled and elapsed > 1 then
			elapsed = 0
			refresh() -- (la cuenta del huevo diario)
		end
	end)
end

return VipPanel

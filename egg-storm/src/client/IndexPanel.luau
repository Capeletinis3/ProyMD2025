--!strict
-- IndexPanel: la ventana del Índice (botón "Index" del HUD).
-- Muestra todas las criaturas del juego por rareza: las que ya tuviste alguna vez con su color y nombre,
-- y las que te faltan como "???". Arriba, cuántas descubriste.
-- Lee el atributo "Discovered" que publica el servidor (lista de ids separados por comas).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)

local player = Players.LocalPlayer
local C = UIKit.Colors

local IndexPanel = {}

local SIZE = Vector2.new(760, 600)
local ROW_HEIGHT = 78
local CARD = Vector2.new(184, 64)
local LOCKED = Color3.fromRGB(40, 42, 60)

local gui: ScreenGui
local progressLabel: TextLabel
local barFill: Frame
type Card = { Creature: Creatures.Creature, Frame: Frame, Dot: Frame, Name: TextLabel, Earn: TextLabel }
local cards: { Card } = {}

local function discovered(): { [string]: boolean }
	local set = {}
	local value = player:GetAttribute("Discovered")
	if typeof(value) == "string" then
		for _, id in string.split(value, ",") do
			if id ~= "" then
				set[id] = true
			end
		end
	end
	return set
end

local function refresh()
	local found = discovered()
	local count = 0
	for _, card in cards do
		local known = found[card.Creature.Id] == true
		if known then
			count += 1
		end
		local rarity = Config.GetRarity(card.Creature.RarityId)
		card.Dot.BackgroundColor3 = if known then card.Creature.Color else Color3.fromRGB(20, 20, 28)
		card.Name.Text = if known then card.Creature.DisplayName else "???"
		card.Name.TextColor3 = if known then C.Text else C.SubText
		card.Earn.Text = if known and rarity then `+{rarity.CoinsPerSecond}/s` else "Not found yet"
		card.Frame.BackgroundColor3 = if known then C.Row else LOCKED
	end
	progressLabel.Text = `Discovered {count}/{#cards}`
	barFill.Size = UDim2.fromScale(if #cards > 0 then count / #cards else 0, 1)
end

function IndexPanel.Open()
	refresh()
	gui.Enabled = true
end

function IndexPanel.Start()
	local frame
	gui, frame = UIKit.Window("IndexPanel", "📗 CREATURE INDEX", SIZE, 6)

	progressLabel = UIKit.Label(frame, "", UDim2.fromOffset(300, 26), UDim2.fromOffset(30, 70), 20, C.Gold)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromOffset(SIZE.X - 360, 16)
	bar.Position = UDim2.fromOffset(330, 76)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	bar.Parent = frame
	UIKit.Corner(bar, 8)
	barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = C.Green
	barFill.Parent = bar
	UIKit.Corner(barFill, 8)

	-- Una fila por rareza
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromOffset(SIZE.X - 40, SIZE.Y - 130)
	list.Position = UDim2.fromOffset(20, 110)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 8
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.fromOffset(0, #Config.Rarities * ROW_HEIGHT + 10)
	list.Parent = frame
	for row, rarity in Config.Rarities do
		local y = (row - 1) * ROW_HEIGHT
		local tag = UIKit.Label(list, rarity.DisplayName:upper(), UDim2.fromOffset(120, CARD.Y), UDim2.fromOffset(0, y), 18, if rarity.Id == "Secret" then Color3.fromRGB(196, 160, 255) else rarity.Color)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		tag.BackgroundTransparency = 0
		tag.BackgroundColor3 = Color3.fromRGB(24, 26, 40)
		UIKit.Corner(tag, 12)
		UIKit.Stroke(tag, 1.5)
		local column = 0
		for _, creature in Creatures.List do
			if creature.RarityId == rarity.Id then
				local card = Instance.new("Frame")
				card.Size = UDim2.fromOffset(CARD.X, CARD.Y)
				card.Position = UDim2.fromOffset(130 + column * (CARD.X + 8), y)
				card.BackgroundColor3 = LOCKED
				card.Parent = list
				UIKit.Corner(card, 12)
				local dot = Instance.new("Frame")
				dot.Size = UDim2.fromOffset(44, 44)
				dot.Position = UDim2.fromOffset(10, 10)
				dot.Parent = card
				UIKit.Corner(dot, 22)
				UIKit.Stroke(dot, 2, if rarity.Id == "Secret" then Color3.fromRGB(196, 160, 255) else rarity.Color)
				local name = UIKit.Label(card, "???", UDim2.fromOffset(CARD.X - 70, 26), UDim2.fromOffset(62, 8), 17)
				local earn = UIKit.Label(card, "", UDim2.fromOffset(CARD.X - 70, 20), UDim2.fromOffset(62, 34), 14, C.SubText)
				table.insert(cards, { Creature = creature, Frame = card, Dot = dot, Name = name, Earn = earn })
				column += 1
			end
		end
	end

	player:GetAttributeChangedSignal("Discovered"):Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
	SideMenu.Bind("Index", IndexPanel.Open)
	refresh()
end

return IndexPanel

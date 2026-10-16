--!strict
-- TradePanel: todo lo del intercambio en la pantalla del jugador.
--   * Lista de jugadores (se abre con "Open" en el puesto de Intercambio): elegís a quién invitar.
--   * Cartel de invitación (aparece esté donde esté): Accept / Decline.
--   * Ventana de intercambio: tocás tus mascotas para ofrecerlas, ves lo que ofrece el otro y apretás "Ready".
-- El cliente solo PIDE cosas: el servidor (TradeService) decide y le manda el estado ("State").

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)

local player = Players.LocalPlayer
local tradeRemote = Remotes.Event("Trade")
local C = UIKit.Colors

local TradePanel = {}

local PICKER_SIZE = Vector2.new(560, 470)
local PICKER_SLOTS = 12
local TRADE_SIZE = Vector2.new(900, 560)
local MAX_SPOTS = Config.Habitat.Capacity
local CLOSE_DISTANCE = 22

type Mine = { Slot: number, CreatureId: string, Variant: string }
type Theirs = { CreatureId: string, Variant: string }
type State = {
	Partner: string,
	MyCreatures: { Mine },
	MyOffer: { number },
	TheirOffer: { Theirs },
	MyReady: boolean,
	TheirReady: boolean,
	CountdownEndsAt: number,
}

local pickerGui: ScreenGui
local pickerButtons: { TextButton } = {}
local pickerEmpty: TextLabel
local pickerPart: BasePart? = nil

local inviteGui: ScreenGui
local inviteLabel: TextLabel
local inviteFrom = 0
local inviteExpires = 0

local tradeGui: ScreenGui
local tradeTitle: TextLabel
local myTiles: { TextButton } = {}
local myOfferRows: { TextLabel } = {}
local theirRows: { TextLabel } = {}
local myOfferHeader: TextLabel
local theirHeader: TextLabel
local statusLabel: TextLabel
local readyButton: TextButton

local state: State? = nil
local lastClick = 0

local function clickOk(): boolean
	if os.clock() - lastClick < 0.25 then
		return false
	end
	lastClick = os.clock()
	return true
end

-- Nombre lindo de una mascota ("Golden Lava Pup") y su color
local function describe(creatureId: string, variantId: string): (string, Color3, number)
	local creature = Creatures.Get(creatureId)
	local variant = Config.GetVariant(variantId)
	if not creature then
		return "???", C.Text, 0
	end
	local rarity = Config.GetRarity(creature.RarityId)
	local color = if variant.Id ~= "Normal" then variant.Color elseif rarity and rarity.Id ~= "Secret" then rarity.Color else C.Text
	local income = if rarity then Config.GetIncome(rarity, variant) else 0
	return Config.WithVariant(variant, creature.DisplayName), color, income
end

-- ===== Lista de jugadores =====

local function refreshPicker()
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
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
			button.Text = other.DisplayName
			button:SetAttribute("UserId", other.UserId)
		end
	end
	pickerEmpty.Visible = #others == 0
end

function TradePanel.OpenPicker(part: BasePart?)
	if state then
		tradeGui.Enabled = true
		return
	end
	pickerPart = part
	refreshPicker()
	pickerGui.Enabled = true
end

-- ===== Ventana de intercambio =====

local function setRow(row: TextLabel, item: Theirs?)
	if item then
		local name, color, income = describe(item.CreatureId, item.Variant)
		row.Text = `  {name}  (+{Format.Compact(income)}/s)`
		row.TextColor3 = color
		row.BackgroundTransparency = 0
	else
		row.Text = "  —"
		row.TextColor3 = C.Gray
		row.BackgroundTransparency = 0.5
	end
end

local function render()
	local current = state
	if not current then
		return
	end
	tradeTitle.Text = `TRADE WITH {string.upper(current.Partner)}`
	local offered: { [number]: boolean } = {}
	for _, slot in current.MyOffer do
		offered[slot] = true
	end
	local mine = table.clone(current.MyCreatures)
	table.sort(mine, function(a, b)
		return a.Slot < b.Slot
	end)
	for i, tile in myTiles do
		local item = mine[i]
		tile.Visible = item ~= nil
		if item then
			local name, color = describe(item.CreatureId, item.Variant)
			tile.Text = name
			tile.TextColor3 = color
			tile:SetAttribute("Slot", item.Slot)
			tile.BackgroundColor3 = if offered[item.Slot] then Color3.fromRGB(60, 140, 80) else C.Row
		end
	end
	local myItems: { Theirs } = {}
	for _, item in mine do
		if offered[item.Slot] then
			table.insert(myItems, { CreatureId = item.CreatureId, Variant = item.Variant })
		end
	end
	for i, row in myOfferRows do
		setRow(row, myItems[i])
	end
	for i, row in theirRows do
		setRow(row, current.TheirOffer[i])
	end
	myOfferHeader.Text = `YOUR OFFER ({#myItems}/{Config.Trade.MaxItems})` .. (if current.MyReady then "  · READY!" else "")
	theirHeader.Text = `{string.upper(current.Partner)}'S OFFER` .. (if current.TheirReady then "  · READY!" else "")
	readyButton.Text = if current.MyReady then "Not ready" else "Ready"
	readyButton.BackgroundColor3 = if current.MyReady then C.Gray else C.Green
end

local function updateStatus()
	local current = state
	if not current then
		return
	end
	if current.CountdownEndsAt > 0 then
		local left = math.max(0, math.ceil(current.CountdownEndsAt - Workspace:GetServerTimeNow()))
		statusLabel.Text = `Trading in {left}...`
		statusLabel.TextColor3 = C.Gold
	elseif current.MyReady and not current.TheirReady then
		statusLabel.Text = `Waiting for {current.Partner}...`
		statusLabel.TextColor3 = C.SubText
	elseif current.TheirReady and not current.MyReady then
		statusLabel.Text = `{current.Partner} is ready!`
		statusLabel.TextColor3 = C.Green
	elseif #current.MyOffer == 0 and #current.TheirOffer == 0 then
		statusLabel.Text = "Tap your creatures to add them."
		statusLabel.TextColor3 = C.SubText
	else
		statusLabel.Text = "Check the offers, then press Ready."
		statusLabel.TextColor3 = C.SubText
	end
end

local function toggleOffer(slot: number)
	local current = state
	if not current or not clickOk() then
		return
	end
	local list: { number } = {}
	local found = false
	for _, s in current.MyOffer do
		if s == slot then
			found = true
		else
			table.insert(list, s)
		end
	end
	if not found then
		if #list >= Config.Trade.MaxItems then
			return
		end
		table.insert(list, slot)
	end
	tradeRemote:FireServer("Offer", list)
end

local function buildTrade()
	local frame, closeButton
	tradeGui, frame, closeButton = UIKit.Window("TradePanel", "TRADE", TRADE_SIZE, 7)
	tradeTitle = frame:FindFirstChildOfClass("TextLabel") :: TextLabel
	closeButton.Activated:Connect(function()
		tradeRemote:FireServer("Cancel")
	end)

	-- Izquierda: tus mascotas (20 lugares como máximo, así que entran sin desplazar)
	UIKit.Label(frame, "YOUR CREATURES", UDim2.fromOffset(400, 30), UDim2.fromOffset(28, 76), 22, C.SubText)
	local columns, tileW, tileH = 4, 96, 56
	for i = 1, MAX_SPOTS do
		local col = (i - 1) % columns
		local row = (i - 1) // columns
		local tile = UIKit.Button(frame, "", UDim2.fromOffset(tileW, tileH), UDim2.fromOffset(28 + col * (tileW + 8), 112 + row * (tileH + 8)), 16, C.Row)
		tile.TextWrapped = true
		tile.Visible = false
		tile.Activated:Connect(function()
			local slot = tile:GetAttribute("Slot")
			if typeof(slot) == "number" then
				toggleOffer(slot)
			end
		end)
		table.insert(myTiles, tile)
	end

	-- Derecha: las dos ofertas
	local rightX = 456
	local rowW = TRADE_SIZE.X - rightX - 28
	local function offerList(y: number, rows: { TextLabel }): TextLabel
		local header = UIKit.Label(frame, "", UDim2.fromOffset(rowW, 30), UDim2.fromOffset(rightX, y), 22, C.Accent)
		for i = 1, Config.Trade.MaxItems do
			local row = UIKit.Label(frame, "", UDim2.fromOffset(rowW, 34), UDim2.fromOffset(rightX, y + 34 + (i - 1) * 38), 19)
			row.BackgroundColor3 = C.Row
			UIKit.Corner(row, 8)
			table.insert(rows, row)
		end
		return header
	end
	myOfferHeader = offerList(76, myOfferRows)
	theirHeader = offerList(268, theirRows)

	-- Abajo: estado + botones
	statusLabel = UIKit.Label(frame, "", UDim2.fromOffset(rowW, 30), UDim2.fromOffset(rightX, 448), 21, C.SubText)
	readyButton = UIKit.Button(frame, "Ready", UDim2.fromOffset(200, 56), UDim2.fromOffset(rightX, TRADE_SIZE.Y - 80), 26, C.Green)
	readyButton.Activated:Connect(function()
		local current = state
		if current and clickOk() then
			tradeRemote:FireServer("Ready", not current.MyReady)
		end
	end)
	local cancel = UIKit.Button(frame, "Cancel", UDim2.fromOffset(200, 56), UDim2.fromOffset(rightX + 216, TRADE_SIZE.Y - 80), 26, C.Red)
	cancel.Activated:Connect(function()
		if clickOk() then
			tradeRemote:FireServer("Cancel")
		end
	end)
end

local function buildPicker()
	local frame
	pickerGui, frame = UIKit.Window("TradePicker", "TRADING", PICKER_SIZE, 6)
	UIKit.Label(frame, "Pick a player to send a trade request:", UDim2.fromOffset(500, 30), UDim2.fromOffset(28, 72), 21, C.SubText)
	pickerEmpty = UIKit.Label(frame, "Nobody else is here yet!", UDim2.fromOffset(500, 40), UDim2.fromOffset(28, 120), 24, C.Gray)
	for i = 1, PICKER_SLOTS do
		local col = (i - 1) % 2
		local row = (i - 1) // 2
		local button = UIKit.Button(frame, "", UDim2.fromOffset(244, 50), UDim2.fromOffset(28 + col * 260, 112 + row * 58), 22, C.Row)
		button.Visible = false
		button.Activated:Connect(function()
			local userId = button:GetAttribute("UserId")
			if typeof(userId) == "number" and clickOk() then
				tradeRemote:FireServer("Request", userId)
				pickerGui.Enabled = false
			end
		end)
		table.insert(pickerButtons, button)
	end
end

local function buildInvite()
	inviteGui = Instance.new("ScreenGui")
	inviteGui.Name = "TradeInvite"
	inviteGui.ResetOnSpawn = false
	inviteGui.Enabled = false
	inviteGui.DisplayOrder = 8
	inviteGui.Parent = player:WaitForChild("PlayerGui")
	local size = Vector2.new(440, 150)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 90)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = C.Panel
	frame.Parent = inviteGui
	UIKit.Corner(frame, 18)
	UIKit.Stroke(frame, 3, C.Accent)
	UIKit.FitToScreen(frame, size)
	inviteLabel = UIKit.Label(frame, "", UDim2.fromOffset(size.X - 32, 50), UDim2.fromOffset(16, 10), 24)
	inviteLabel.TextXAlignment = Enum.TextXAlignment.Center
	inviteLabel.TextWrapped = true
	local accept = UIKit.Button(frame, "Accept", UDim2.fromOffset(190, 54), UDim2.fromOffset(20, 78), 24, C.Green)
	local decline = UIKit.Button(frame, "Decline", UDim2.fromOffset(190, 54), UDim2.fromOffset(size.X - 210, 78), 24, C.Red)
	accept.Activated:Connect(function()
		tradeRemote:FireServer("Respond", inviteFrom, true)
		inviteGui.Enabled = false
	end)
	decline.Activated:Connect(function()
		tradeRemote:FireServer("Respond", inviteFrom, false)
		inviteGui.Enabled = false
	end)
end

local function setupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function()
		local part = prompt.Parent
		TradePanel.OpenPicker(if part and part:IsA("BasePart") then part else nil)
	end)
end

-- Para las pruebas y vistas previas: mostrar un estado como si viniera del servidor
function TradePanel.ShowState(newState: State)
	state = newState
	pickerGui.Enabled = false
	tradeGui.Enabled = true
	render()
	updateStatus()
end

function TradePanel.ShowInvite(name: string, userId: number)
	inviteFrom = userId
	inviteExpires = os.clock() + Config.Trade.RequestTimeout
	inviteLabel.Text = `{name} wants to trade with you!`
	inviteGui.Enabled = true
end

function TradePanel.Start()
	buildPicker()
	buildInvite()
	buildTrade()
	SideMenu.Bind("Trade", function()
		TradePanel.OpenPicker(nil)
	end)

	for _, prompt in CollectionService:GetTagged("TradePrompt") do
		setupPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("TradePrompt"):Connect(setupPrompt)
	Players.PlayerAdded:Connect(function()
		if pickerGui.Enabled then
			refreshPicker()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if pickerGui.Enabled then
			task.defer(refreshPicker)
		end
	end)

	tradeRemote.OnClientEvent:Connect(function(kind: unknown, a: unknown, b: unknown)
		if kind == "Invite" and typeof(a) == "string" and typeof(b) == "number" then
			TradePanel.ShowInvite(a, b)
		elseif kind == "State" and typeof(a) == "table" then
			TradePanel.ShowState(a :: State)
		elseif kind == "Closed" then
			state = nil
			tradeGui.Enabled = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		if inviteGui.Enabled and os.clock() > inviteExpires then
			inviteGui.Enabled = false
		end
		if tradeGui.Enabled then
			updateStatus()
		end
		-- La lista de jugadores se cierra si te alejás del puesto
		local part = pickerPart
		if pickerGui.Enabled and part then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") or (root.Position - part.Position).Magnitude > CLOSE_DISTANCE then
				pickerGui.Enabled = false
			end
		end
	end)
end

return TradePanel

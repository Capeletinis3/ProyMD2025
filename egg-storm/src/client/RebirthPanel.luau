--!strict
-- RebirthPanel: la ventana de renacimiento (se abre con el botón "Rebirth" del costado).
-- Muestra qué ganás, qué perdés y qué conservás, y el botón para renacer.
-- El botón solo PIDE renacer: el servidor decide si se puede (ver RebirthService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)

local player = Players.LocalPlayer
local rebirthRemote = Remotes.Event("Rebirth")
local C = UIKit.Colors

local RebirthPanel = {}

local SIZE = Vector2.new(560, 430)

local gui: ScreenGui
local countLabel: TextLabel
local gainLabel: TextLabel
local button: TextButton
local lastClick = 0

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refresh()
	local rebirths = number("Rebirths")
	local maxRebirths = #Config.Rebirth.Costs
	local cost = Config.Rebirth.Costs[rebirths + 1]
	countLabel.Text = `Rebirths: {rebirths}/{maxRebirths}`
	local now = math.round((Config.RebirthMultiplier(rebirths) - 1) * 100)
	local nextBonus = math.round((Config.RebirthMultiplier(rebirths + 1) - 1) * 100)
	local lines = {}
	local floors = Config.FloorsForRebirths(rebirths + 1)
	if floors > number("BaseLevel") then
		table.insert(lines, `🏠 Unlocks floor {floors} of your tower`)
	end
	table.insert(lines, `💰 Creatures make +{nextBonus}% coins (now +{now}%)`)
	gainLabel.Text = table.concat(lines, "\n")
	if not cost then
		button.Text = "MAX"
		button.BackgroundColor3 = C.Gray
		gainLabel.Text = `💰 Creatures make +{now}% coins`
		return
	end
	button.Text = `Rebirth  {Format.Number(cost)}`
	button.BackgroundColor3 = if number("Coins") >= cost then C.Green else C.Red
end

function RebirthPanel.Open()
	refresh()
	gui.Enabled = true
end

function RebirthPanel.Start()
	local frame
	gui, frame = UIKit.Window("RebirthPanel", "REBIRTH", SIZE, 6)

	countLabel = UIKit.Label(frame, "", UDim2.fromOffset(SIZE.X - 56, 34), UDim2.fromOffset(28, 76), 26, C.SubText)

	UIKit.Label(frame, "You get:", UDim2.fromOffset(200, 30), UDim2.fromOffset(28, 118), 24, C.Green)
	gainLabel = UIKit.Label(frame, "", UDim2.fromOffset(SIZE.X - 56, 64), UDim2.fromOffset(28, 148), 22)
	gainLabel.TextYAlignment = Enum.TextYAlignment.Top

	UIKit.Label(frame, "You lose:", UDim2.fromOffset(200, 30), UDim2.fromOffset(28, 218), 24, C.Red)
	UIKit.Label(frame, "Your coins, Incubation Speed and Walk Speed", UDim2.fromOffset(SIZE.X - 56, 28), UDim2.fromOffset(28, 248), 22)

	UIKit.Label(frame, "You keep:", UDim2.fromOffset(200, 30), UDim2.fromOffset(28, 284), 24, C.Gold)
	UIKit.Label(frame, "Your creatures, eggs and incubators", UDim2.fromOffset(SIZE.X - 56, 28), UDim2.fromOffset(28, 314), 22)

	button = UIKit.Button(frame, "Rebirth", UDim2.fromOffset(300, 56), UDim2.fromOffset((SIZE.X - 300) / 2, SIZE.Y - 76), 28, C.Green)
	button.Activated:Connect(function()
		if os.clock() - lastClick < 0.5 then
			return
		end
		lastClick = os.clock()
		rebirthRemote:FireServer("Rebirth")
	end)

	for _, name in { "Coins", "Rebirths", "BaseLevel" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if gui.Enabled then
				refresh()
			end
		end)
	end
	SideMenu.AddButton("🔄 Rebirth", Color3.fromRGB(200, 70, 90), RebirthPanel.Open)
end

return RebirthPanel

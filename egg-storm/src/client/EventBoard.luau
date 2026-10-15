--!strict
-- EventBoard: escribe el cartel colgante del lobby (lo arma MapBuilder, con el atributo "EventBoard").
--   Renglón 1: en qué está la tormenta y cuánto falta ("NEXT STORM IN 0:15", "EGG RAIN · 1:12", ...).
--   Renglón 2: el evento de esta tormenta, o la chance de que haya uno.
-- Lo hace cada cliente con los atributos de Workspace, así el servidor no tiene que mandar nada.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local EventBoard = {}

local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(255, 90, 90)
local BLUE = Color3.fromRGB(120, 200, 255)
local GREEN = Color3.fromRGB(150, 255, 150)

local function formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Qué dicen los dos renglones ahora
local function lines(): (string, Color3, string, Color3)
	local phase = Workspace:GetAttribute("StormPhase")
	local endsAt = Workspace:GetAttribute("PhaseEndsAt")
	local left = if typeof(endsAt) == "number" then endsAt - Workspace:GetServerTimeNow() else 0
	local eventId = Workspace:GetAttribute("StormEvent")
	local event = if typeof(eventId) == "string" then Config.GetEvent(eventId) else nil

	if phase == "Rain" then
		local second = if event then `EVENT: {event.DisplayName}` else "No special event this storm"
		return `EGG RAIN · ENDS IN {formatTime(left)}`, BLUE, second, if event then event.Color else WHITE
	elseif phase == "Warning" then
		return `WAVE IN {formatTime(left)}!`, RED, "Run back to the safe zone!", WHITE
	elseif phase == "Wave" then
		return "WAVE!", RED, "Run back to the safe zone!", WHITE
	end
	local chance = math.floor(Config.Events.ChancePerStorm * 100 + 0.5)
	return `NEXT STORM IN {formatTime(left)}`, GREEN, `{chance}% chance of a special event!`, WHITE
end

local function findBoards(): { BasePart }
	local boards = {}
	local map = Workspace:FindFirstChild("Map")
	local model = map and map:FindFirstChild("EventBoard")
	local board = model and model:FindFirstChild("Board")
	if board and board:IsA("BasePart") and board:GetAttribute("EventBoard") then
		table.insert(boards, board)
	end
	return boards
end

local function update(boards: { BasePart })
	local text1, color1, text2, color2 = lines()
	for _, board in boards do
		for _, gui in board:GetChildren() do
			if gui:IsA("SurfaceGui") then
				local line1 = gui:FindFirstChild("Line1")
				local line2 = gui:FindFirstChild("Line2")
				if line1 and line1:IsA("TextLabel") then
					line1.Text = text1
					line1.TextColor3 = color1
				end
				if line2 and line2:IsA("TextLabel") then
					line2.Text = text2
					line2.TextColor3 = color2
				end
			end
		end
	end
end

function EventBoard.Start()
	task.spawn(function()
		local boards: { BasePart } = {}
		while true do
			-- El mapa puede tardar en llegar al cliente: lo buscamos hasta encontrarlo
			if #boards == 0 then
				boards = findBoards()
			end
			update(boards)
			task.wait(0.25)
		end
	end)
end

return EventBoard

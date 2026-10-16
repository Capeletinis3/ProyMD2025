--!strict
-- EventBoard: escribe el tablero de eventos del puesto de Rankings (lo arma MapBuilder, con el atributo "EventBoard").
--   Renglón 1: la próxima ola ("NEXT WAVE IN 0:42", "WAVE IN 0:03!", "WAVE!")
--   Renglón 2: cuánto falta para el Súper tsunami
--   Renglón 3: el evento activo (o cuánto falta para el próximo sorteo de evento)
-- Lo hace cada cliente con los atributos de Workspace, así el servidor no tiene que mandar nada.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local EventBoard = {}

local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(255, 90, 90)
local BLUE = Color3.fromRGB(150, 230, 255)
local PURPLE = Color3.fromRGB(200, 150, 255)

local function formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function untilTime(name: string): number
	local at = Workspace:GetAttribute(name)
	return if typeof(at) == "number" then at - Workspace:GetServerTimeNow() else 0
end

-- Qué dice cada renglón ahora: { texto, color }
local function lines(): { { Text: string, Color: Color3 } }
	local phase = Workspace:GetAttribute("WavePhase")
	local wave
	if phase == "Warning" then
		wave = { Text = `WAVE IN {formatTime(untilTime("PhaseEndsAt"))}!`, Color = RED }
	elseif phase == "Wave" then
		wave = { Text = "WAVE!", Color = RED }
	else
		wave = { Text = `NEXT WAVE IN {formatTime(untilTime("PhaseEndsAt"))}`, Color = BLUE }
	end
	local super = { Text = `SUPER TSUNAMI IN {formatTime(untilTime("NextSuperAt"))}`, Color = PURPLE }

	local eventId = Workspace:GetAttribute("Event")
	local event = if typeof(eventId) == "string" then Config.GetEvent(eventId) else nil
	local eventLine = if event
		then { Text = `{event.DisplayName} · {formatTime(untilTime("EventEndsAt"))}`, Color = event.Color }
		else { Text = `Next event in {formatTime(untilTime("NextEventAt"))}`, Color = WHITE }
	return { wave, super, eventLine }
end

local function findBoards(): { BasePart }
	local boards = {}
	local map = Workspace:FindFirstChild("Map")
	local model = map and map:FindFirstChild("EventBoard", true)
	local board = model and model:FindFirstChild("Board")
	if board and board:IsA("BasePart") and board:GetAttribute("EventBoard") then
		table.insert(boards, board)
	end
	return boards
end

local function update(boards: { BasePart })
	local content = lines()
	for _, board in boards do
		for _, gui in board:GetChildren() do
			if gui:IsA("SurfaceGui") then
				for i, line in content do
					local label = gui:FindFirstChild(`Line{i}`)
					if label and label:IsA("TextLabel") then
						label.Text = line.Text
						label.TextColor3 = line.Color
					end
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

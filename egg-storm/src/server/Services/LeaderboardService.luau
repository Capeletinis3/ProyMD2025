--!strict
-- LeaderboardService: los tableros de récords del lobby (top 10 de TODOS los servidores).
--   TOP EARNERS       → plata ganada en total (no baja al gastar)
--   MOST EGGS HATCHED → huevos abiertos en total
-- Cada Config.Leaderboard.UpdateInterval segundos:
--   1) escribe los récords de los jugadores de este servidor en un OrderedDataStore
--   2) lee el top 10 y lo muestra en el tablero
-- Si el DataStore no responde (por ejemplo, en Studio sin acceso a la API), muestra el ranking de este servidor.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local PlayerDataService = require(script.Parent.PlayerDataService)

type Entry = { UserId: number, Value: number }

type BoardInfo = {
	Id: string,
	Title: string,
	StoreName: string,
	Unit: string, -- texto chiquito después del número
	Stat: (profile: PlayerDataService.Profile) -> number,
	-- Lo que se arma en el tablero:
	Subtitle: TextLabel?,
	Rows: { { Rank: TextLabel, Name: TextLabel, Value: TextLabel } },
}

local LeaderboardService = {}

local FONT = Enum.Font.FredokaOne
local MEDALS = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(200, 205, 215), Color3.fromRGB(215, 140, 80) }

local BOARDS: { BoardInfo } = {
	{
		Id = "TopEarners",
		Title = "🪙 TOP EARNERS",
		StoreName = Config.Leaderboard.EarnersStoreName,
		Unit = "coins",
		Stat = function(profile)
			return profile.TotalEarned
		end,
		Rows = {},
	},
	{
		Id = "EggsHatched",
		Title = "🥚 MOST EGGS HATCHED",
		StoreName = Config.Leaderboard.HatchedStoreName,
		Unit = "eggs",
		Stat = function(profile)
			return profile.EggsHatched
		end,
		Rows = {},
	},
}

local nameCache: { [number]: string } = {}

-- ===== Armado del tablero =====

local function label(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3, align: Enum.TextXAlignment): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = FONT
	l.TextSize = textSize
	l.TextColor3 = color
	l.TextXAlignment = align
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = text
	l.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = l
	return l
end

-- Pone el SurfaceGui con título, subtítulo y 10 filas sobre la Part del tablero.
local function buildBoard(part: BasePart, info: BoardInfo)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- Siempre 1120 píxeles de ancho, sea del tamaño que sea el tablero (así el texto entra igual)
	local pixelsPerStud = 1120 / part.Size.X
	gui.PixelsPerStud = pixelsPerStud
	gui.Parent = part

	local width = 1120
	local height = part.Size.Y * pixelsPerStud
	label(gui, info.Title, UDim2.fromOffset(width, 90), UDim2.fromOffset(0, 16), 64, Color3.fromRGB(255, 205, 60), Enum.TextXAlignment.Center)
	info.Subtitle = label(gui, "Loading...", UDim2.fromOffset(width, 36), UDim2.fromOffset(0, 104), 28, Color3.fromRGB(190, 195, 220), Enum.TextXAlignment.Center)

	local size = Config.Leaderboard.Size
	local top = 156
	local rowHeight = math.floor((height - top - 8) / size)
	for i = 1, size do
		local y = top + (i - 1) * rowHeight
		local row = Instance.new("Frame")
		row.Size = UDim2.fromOffset(width - 80, rowHeight - 8)
		row.Position = UDim2.fromOffset(40, y)
		row.BackgroundColor3 = if i % 2 == 1 then Color3.fromRGB(48, 52, 76) else Color3.fromRGB(40, 43, 64)
		row.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = row

		local rankColor = MEDALS[i] or Color3.new(1, 1, 1)
		local rank = label(row, `#{i}`, UDim2.fromOffset(100, rowHeight - 8), UDim2.fromOffset(16, 0), 38, rankColor, Enum.TextXAlignment.Left)
		local name = label(row, "---", UDim2.fromOffset(520, rowHeight - 8), UDim2.fromOffset(120, 0), 36, Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
		local value = label(row, "", UDim2.fromOffset(340, rowHeight - 8), UDim2.fromOffset(width - 80 - 360, 0), 34, Color3.fromRGB(130, 255, 130), Enum.TextXAlignment.Right)
		table.insert(info.Rows, { Rank = rank, Name = name, Value = value })
	end
end

-- ===== Datos =====

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	-- Si el jugador está en este servidor, usamos su nombre directo
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and typeof(name) == "string" then name else "Player"
	nameCache[userId] = result
	return result
end

local function show(info: BoardInfo, entries: { Entry }, subtitle: string)
	if info.Subtitle then
		info.Subtitle.Text = subtitle
	end
	for i, row in info.Rows do
		local entry = entries[i]
		if entry then
			row.Name.Text = nameFor(entry.UserId)
			row.Value.Text = `{Format.Compact(entry.Value)} {info.Unit}`
		else
			row.Name.Text = "---"
			row.Value.Text = ""
		end
	end
end

-- Ranking solo con los jugadores de este servidor (cuando el DataStore no anda)
local function localEntries(info: BoardInfo): { Entry }
	local entries: { Entry } = {}
	for _, player in Players:GetPlayers() do
		local profile = PlayerDataService.Get(player)
		if profile then
			table.insert(entries, { UserId = player.UserId, Value = math.floor(info.Stat(profile)) })
		end
	end
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)
	return entries
end

local function updateBoard(info: BoardInfo)
	local store = DataStoreService:GetOrderedDataStore(info.StoreName)

	-- 1) Escribimos los récords de los jugadores de este servidor (solo si sus datos se cargaron bien)
	for _, player in Players:GetPlayers() do
		local profile = PlayerDataService.Get(player)
		if profile and PlayerDataService.CanSave(player) then
			local value = math.floor(info.Stat(profile))
			local ok, err = pcall(function()
				store:SetAsync(tostring(player.UserId), value)
			end)
			if not ok then
				warn(`[Leaderboard] Couldn't save {info.Id} for {player.UserId}: {err}`)
			end
		end
	end

	-- 2) Leemos el top
	local ok, result = pcall(function()
		local pages = store:GetSortedAsync(false, Config.Leaderboard.Size)
		return pages:GetCurrentPage()
	end)
	if ok and typeof(result) == "table" then
		local entries: { Entry } = {}
		for _, item in result do
			local userId = tonumber(item.key)
			if userId and typeof(item.value) == "number" then
				table.insert(entries, { UserId = userId, Value = item.value })
			end
		end
		show(info, entries, `All servers · updates every {math.floor(Config.Leaderboard.UpdateInterval / 60)} min`)
	else
		show(info, localEntries(info), "This server only (global board unavailable)")
	end
end

-- ===== API pública =====

function LeaderboardService.UpdateNow()
	for _, info in BOARDS do
		local ok, err = pcall(function()
			updateBoard(info)
		end)
		if not ok then
			warn(`[Leaderboard] Update failed for {info.Id}: {err}`)
		end
	end
end

function LeaderboardService.Init(map: Folder)
	local folder = map:FindFirstChild("Leaderboards", true)
	if not folder then
		return -- el mapa no tiene tableros
	end
	-- Cada tablero es una Part con el atributo Board (suelta en la carpeta o adentro de un Model con sus postes)
	local function check(part: Instance)
		if part:IsA("BasePart") then
			local id = part:GetAttribute("Board")
			for _, info in BOARDS do
				if info.Id == id then
					buildBoard(part, info)
				end
			end
		elseif part:IsA("Model") then
			for _, child in part:GetChildren() do
				check(child)
			end
		end
	end
	for _, child in folder:GetChildren() do
		check(child)
	end

	task.spawn(function()
		task.wait(Config.Leaderboard.FirstUpdateDelay)
		while true do
			LeaderboardService.UpdateNow()
			task.wait(Config.Leaderboard.UpdateInterval)
		end
	end)
end

return LeaderboardService

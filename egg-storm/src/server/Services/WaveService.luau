--!strict
-- WaveService: las olas del volcán.
--   Calm    : tiempo hasta la próxima ola (al azar entre Config.Waves.MinInterval y MaxInterval)
--   Warning : el volcán echa más humo, suena el cuerno y el cliente muestra "THE WAVE IS COMING!"
--   Wave    : una pared de agua sale del fondo del cañón y lo recorre hasta el portal (nunca entra al lobby)
-- Tipos: Normal, Fast (1 de cada 4, más rápida y con menos aviso) y Super tsunami (cada 30 min, más alta).
--
-- Para salvarse hay que meterse en una cueva (su SafeZone). Si la ola te toca afuera: perdés el huevo
-- que llevabas y volvés al lobby.
--
-- El servidor decide TODO lo importante (a quién agarra la ola). Para que la ola se vea suave, cada cliente
-- la dibuja con la misma fórmula usando estos atributos de Workspace:
--   WavePhase, PhaseEndsAt, WaveKind, WaveStartedAt, WaveStartX, WaveSpeed, WaveHeight, NextSuperAt

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)
local EggService = require(script.Parent.EggService)

export type Phase = "Calm" | "Warning" | "Wave"

local WaveService = {}

local CATCH_BEHIND = 12 -- studs detrás del frente de la ola que también cuentan como "mojado" (la ola avanza a saltos)
local SMOKE_CALM = 4
local SMOKE_ERUPTING = 25

local notifyRemote = Remotes.Event("Notify")
local random = Random.new()
local currentPhase: Phase = "Calm"
local safeZones: { BasePart } = {}
local volcanoSmoke: ParticleEmitter? = nil

-- ===== Fases =====

local function setPhase(phase: Phase, duration: number)
	currentPhase = phase
	Workspace:SetAttribute("WavePhase", phase)
	Workspace:SetAttribute("PhaseEndsAt", Workspace:GetServerTimeNow() + duration)
end

local function setEruption(on: boolean)
	if volcanoSmoke then
		volcanoSmoke.Rate = if on then SMOKE_ERUPTING else SMOKE_CALM
	end
end

-- ¿Este punto está adentro de una cueva-refugio?
function WaveService.IsSafe(position: Vector3): boolean
	for _, zone in safeZones do
		local p = zone.CFrame:PointToObjectSpace(position)
		local half = zone.Size / 2
		if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y + 2 and math.abs(p.Z) <= half.Z then
			return true
		end
	end
	return false
end

-- ¿La ola agarra a este jugador? Solo si está en el cañón, justo donde pasa la ola, no muy arriba y fuera de una cueva.
local function isCaught(root: BasePart, frontX: number, height: number): boolean
	local position = root.Position
	local waves = Config.Waves
	local canyonEnd = Config.Map.CanyonStartX + Config.Map.CanyonLength
	if position.X < waves.EndX or position.X > canyonEnd + 10 then
		return false -- en el lobby (o fuera del cañón)
	end
	if position.X < frontX - 2 or position.X > frontX + waves.Thickness + CATCH_BEHIND then
		return false -- la ola todavía no llegó, o ya pasó
	end
	if position.Y > Config.Map.FloorY + height then
		return false
	end
	return not WaveService.IsSafe(position)
end

local function hitPlayer(player: Player)
	local hadEgg = EggService.GetCarriedEgg(player) ~= nil
	EggService.LoseCarriedEgg(player)
	BaseService.TeleportToLobby(player)
	notifyRemote:FireClient(player, if hadEgg then "The wave got you! You lost your egg." else "The wave got you!")
end

local function runWave(kindName: string, kind: Config.WaveKind)
	local waves = Config.Waves
	local startX = waves.StartX
	local travelTime = (startX - waves.EndX) / kind.Speed

	Workspace:SetAttribute("WaveKind", kindName)
	Workspace:SetAttribute("WaveStartedAt", Workspace:GetServerTimeNow())
	Workspace:SetAttribute("WaveStartX", startX)
	Workspace:SetAttribute("WaveSpeed", kind.Speed)
	Workspace:SetAttribute("WaveHeight", kind.Height)
	setPhase("Wave", travelTime)

	local startedAt = os.clock()
	local hitThisWave: { [Player]: boolean } = {}
	while true do
		local frontX = startX - kind.Speed * (os.clock() - startedAt)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not hitThisWave[player] and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and isCaught(root, frontX, kind.Height) then
				hitThisWave[player] = true
				hitPlayer(player)
			end
		end
		if frontX <= waves.EndX then
			break
		end
		task.wait(0.05)
	end
end

-- ===== API pública =====

function WaveService.GetPhase(): Phase
	return currentPhase
end

function WaveService.Init(map: Folder)
	-- Las zonas seguras de todas las cuevas
	local canyon = map:FindFirstChild("Canyon")
	local caves = canyon and canyon:FindFirstChild("Caves")
	if caves then
		for _, cave in caves:GetChildren() do
			local zone = cave:FindFirstChild("SafeZone")
			if zone and zone:IsA("BasePart") then
				table.insert(safeZones, zone)
			end
		end
	end
	local volcano = map:FindFirstChild("Volcano")
	local crater = volcano and volcano:FindFirstChild("Crater")
	local smoke = crater and crater:FindFirstChild("VolcanoSmoke")
	if smoke and smoke:IsA("ParticleEmitter") then
		volcanoSmoke = smoke
	end

	task.spawn(function()
		local waves = Config.Waves
		local nextSuper = os.clock() + waves.SuperInterval
		Workspace:SetAttribute("NextSuperAt", Workspace:GetServerTimeNow() + waves.SuperInterval)
		while true do
			-- Calma hasta la próxima ola
			local calmTime = random:NextNumber(waves.MinInterval, waves.MaxInterval)
			setPhase("Calm", calmTime)
			task.wait(calmTime)

			-- ¿Qué ola viene?
			local kindName, kind = "Normal", waves.Normal
			if os.clock() >= nextSuper then
				kindName, kind = "Super", waves.Super
				nextSuper = os.clock() + waves.SuperInterval
				Workspace:SetAttribute("NextSuperAt", Workspace:GetServerTimeNow() + waves.SuperInterval)
			elseif random:NextNumber() < waves.FastChance then
				kindName, kind = "Fast", waves.Fast
			end

			-- Aviso: el volcán humea más y el cliente muestra el cartel
			Workspace:SetAttribute("WaveKind", kindName)
			setEruption(true)
			setPhase("Warning", kind.Warning)
			if kindName == "Super" then
				notifyRemote:FireAllClients("SUPER TSUNAMI incoming! Hide in a cave!")
			end
			task.wait(kind.Warning)

			-- La ola
			runWave(kindName, kind)
			setEruption(false)
		end
	end)
end

return WaveService

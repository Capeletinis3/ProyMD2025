--!strict
-- BaseService: le da una base libre a cada jugador que entra y la libera cuando sale.
-- También lleva al personaje a su base cada vez que aparece (al entrar y al reaparecer).
-- Otros sistemas (huevos, incubadoras, ola) le preguntan a este servicio "¿cuál es la base de X?".

local Players = game:GetService("Players")

export type Base = {
	Id: number,
	Model: Model,
	SpawnPoint: BasePart,
	SafeZone: BasePart,
	SignLabel: TextLabel,
	Facing: CFrame, -- solo la rotación de la base: su LookVector apunta al pasillo
	IncubatorSlots: { BasePart }, -- pads de incubadoras, ordenados por SlotIndex
	CreatureSlots: { BasePart }, -- pads de mascotas, ordenados por SlotIndex
	Owner: Player?,
}

type BaseCallback = (player: Player, base: Base) -> ()

local BaseService = {}

local bases: { Base } = {}
local baseByPlayer: { [Player]: Base } = {}
local assignedCallbacks: { BaseCallback } = {}
local releasedCallbacks: { BaseCallback } = {}

local function updateSign(base: Base)
	local owner = base.Owner
	if owner then
		base.SignLabel.Text = `{owner.DisplayName}'s Base`
		base.SignLabel.TextColor3 = Color3.new(1, 1, 1)
	else
		base.SignLabel.Text = "Free Base"
		base.SignLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end

local function findFreeBase(): Base?
	for _, base in bases do
		if base.Owner == nil then
			return base
		end
	end
	return nil
end

-- ===== API pública =====

function BaseService.GetBase(player: Player): Base?
	return baseByPlayer[player]
end

function BaseService.GetBases(): { Base }
	return bases
end

-- Registrar funciones que se llaman cuando un jugador recibe su base (cargar datos, armar incubadoras...)
-- y cuando la suelta (guardar, limpiar). Hay que registrarlas ANTES de llamar a Init.
function BaseService.OnAssigned(callback: BaseCallback)
	table.insert(assignedCallbacks, callback)
end

function BaseService.OnReleased(callback: BaseCallback)
	table.insert(releasedCallbacks, callback)
end

-- ¿Este punto está dentro de la zona segura de la base? (lo usa la ola en la fase 5)
function BaseService.IsInsideBase(base: Base, position: Vector3): boolean
	local zone = base.SafeZone
	local localPos = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

function BaseService.TeleportToBase(player: Player)
	local base = baseByPlayer[player]
	local character = player.Character
	if not base or not character then
		return
	end
	character:PivotTo(base.SpawnPoint.CFrame + Vector3.new(0, 4, 0))
end

-- ===== Entrada / salida de jugadores =====

local function onCharacterAdded(player: Player, character: Model)
	if not character:WaitForChild("HumanoidRootPart", 10) then
		return
	end
	-- Esperamos un frame para que Roblox termine de ubicar al personaje, y recién ahí lo movemos.
	task.wait()
	if player.Character == character then
		BaseService.TeleportToBase(player)
	end
end

local function assignBase(player: Player): boolean
	local base = findFreeBase()
	if not base then
		-- No debería pasar si Max Players = 8 en Game Settings, pero por las dudas.
		player:Kick("This server is full. Please join another one!")
		return false
	end

	base.Owner = player
	baseByPlayer[player] = base
	base.Model:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("BaseId", base.Id) -- el cliente lee este atributo para saber cuál es su base
	updateSign(base)
	for _, callback in assignedCallbacks do
		local ok, err = pcall(function()
			callback(player, base)
		end)
		if not ok then
			warn(`[BaseService] Error setting up base {base.Id}: {err}`)
		end
	end
	return true
end

local function releaseBase(player: Player)
	local base = baseByPlayer[player]
	if not base then
		return
	end
	-- Primero avisamos (para guardar y limpiar la base) y después la liberamos
	for _, callback in releasedCallbacks do
		local ok, err = pcall(function()
			callback(player, base)
		end)
		if not ok then
			warn(`[BaseService] Error releasing base {base.Id}: {err}`)
		end
	end
	baseByPlayer[player] = nil
	base.Owner = nil
	base.Model:SetAttribute("OwnerUserId", 0)
	updateSign(base)
end

local function onPlayerAdded(player: Player)
	if not assignBase(player) then
		return
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

-- Junta los pads de una carpeta de la base, ordenados por su número (atributo SlotIndex).
local function collectSlots(model: Model, folderName: string): { BasePart }
	local folder = model:FindFirstChild(folderName)
	assert(folder, `[BaseService] {model.Name} is missing {folderName}`)
	local slots: { BasePart } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and typeof(child:GetAttribute("SlotIndex")) == "number" then
			table.insert(slots, child)
		end
	end
	table.sort(slots, function(a, b)
		return (a:GetAttribute("SlotIndex") :: number) < (b:GetAttribute("SlotIndex") :: number)
	end)
	return slots
end

-- Lee las bases del mapa y empieza a escuchar a los jugadores.
function BaseService.Init(map: Folder)
	local basesFolder = map:FindFirstChild("Bases")
	assert(basesFolder, "[BaseService] Map is missing a 'Bases' folder")

	for _, model in basesFolder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local id = model:GetAttribute("BaseId")
		local spawnPoint = model:FindFirstChild("SpawnPoint")
		local safeZone = model:FindFirstChild("SafeZone")
		local signLabel = model:FindFirstChild("SignLabel", true)
		assert(typeof(id) == "number", `[BaseService] {model.Name} has no BaseId attribute`)
		assert(spawnPoint and spawnPoint:IsA("BasePart"), `[BaseService] {model.Name} is missing SpawnPoint`)
		assert(safeZone and safeZone:IsA("BasePart"), `[BaseService] {model.Name} is missing SafeZone`)
		assert(signLabel and signLabel:IsA("TextLabel"), `[BaseService] {model.Name} is missing SignLabel`)
		assert(model.PrimaryPart, `[BaseService] {model.Name} has no PrimaryPart`)

		local base: Base = {
			Id = id,
			Model = model,
			SpawnPoint = spawnPoint,
			SafeZone = safeZone,
			SignLabel = signLabel,
			Facing = model.PrimaryPart.CFrame.Rotation,
			IncubatorSlots = collectSlots(model, "IncubatorSlots"),
			CreatureSlots = collectSlots(model, "CreatureSlots"),
			Owner = nil,
		}
		table.insert(bases, base)
		updateSign(base)
	end

	-- Orden fijo: Base1, Base2, ... así el primero que entra recibe la 1.
	table.sort(bases, function(a, b)
		return a.Id < b.Id
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(releaseBase)
	-- En Studio a veces el jugador entra antes de que corra este script: lo atendemos igual.
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return BaseService

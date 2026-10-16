--!strict
-- VipService: el pase VIP (un Game Pass de Roblox).
-- Hoy el VIP sirve para entrar a la cueva-refugio VIP del cañón (más ancha, con marco dorado).
--   * La entrada tiene una pared invisible (MapBuilder la marca con el atributo VipBarrier).
--   * Con grupos de colisión, esa pared NO choca con los personajes de los jugadores VIP: ellos pasan, el resto no.
--   * Al lado hay un botón "Get VIP" que abre la compra del pase.
-- Quién es VIP lo decide SIEMPRE el servidor (le pregunta a Roblox) y lo publica en el atributo "VIP" del jugador.
-- El número del pase va en Config.Vip.GamePassId.

local MarketplaceService = game:GetService("MarketplaceService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local VipService = {}

local BARRIER_GROUP = "VipBarrier"
local PLAYER_GROUP = "VipPlayers"

local notifyRemote = Remotes.Event("Notify")
local vipRemote = Remotes.Event("Vip")
local vipPlayers: { [Player]: boolean } = {}
local lastPrompt: { [Player]: number } = {}

local function setGroup(part: Instance)
	if part:IsA("BasePart") then
		part.CollisionGroup = PLAYER_GROUP
	end
end

local function applyToCharacter(character: Model)
	for _, child in character:GetDescendants() do
		setGroup(child)
	end
	character.DescendantAdded:Connect(setGroup)
end

function VipService.IsVip(player: Player): boolean
	return vipPlayers[player] == true
end

-- Lo hace VIP en este servidor (después de comprarlo, o si Roblox dice que ya lo tiene)
function VipService.Grant(player: Player)
	if vipPlayers[player] then
		return
	end
	vipPlayers[player] = true
	player:SetAttribute("VIP", true)
	local character = player.Character
	if character then
		applyToCharacter(character)
	end
end

local function ownsPass(player: Player): boolean
	if table.find(Config.Vip.TestUserIds, player.UserId) then
		return true
	end
	local passId = Config.Vip.GamePassId
	if passId <= 0 then
		return false
	end
	-- Preguntarle a Roblox puede fallar: probamos 3 veces
	for attempt = 1, 3 do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok then
			return owns == true
		end
		warn(`[VipService] Could not check VIP for {player.Name} (try {attempt}): {owns}`)
		if attempt < 3 then
			task.wait(attempt * 2)
		end
	end
	return false
end

-- Abre la compra del pase (o avisa si ya sos VIP / si todavía no está configurado)
function VipService.PromptPurchase(player: Player)
	local now = os.clock()
	if now - (lastPrompt[player] or -math.huge) < Config.Vip.PromptCooldown then
		return
	end
	lastPrompt[player] = now
	if vipPlayers[player] then
		notifyRemote:FireClient(player, "You're VIP! Walk right into the VIP cave.")
		return
	end
	if Config.Vip.GamePassId <= 0 then
		notifyRemote:FireClient(player, "VIP isn't available yet. Check back soon!")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, Config.Vip.GamePassId)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		if vipPlayers[player] then
			applyToCharacter(character)
		end
	end)
	if ownsPass(player) and player.Parent then
		VipService.Grant(player)
	end
end

function VipService.Init(map: Folder)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(BARRIER_GROUP)
		PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(BARRIER_GROUP, PLAYER_GROUP, false)

	for _, item in map:GetDescendants() do
		if item:IsA("BasePart") and item:GetAttribute("VipBarrier") then
			item.CollisionGroup = BARRIER_GROUP
			local prompt = item:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(VipService.PromptPurchase)
			end
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if purchased and passId == Config.Vip.GamePassId and Config.Vip.GamePassId > 0 then
			VipService.Grant(player)
			notifyRemote:FireClient(player, "Thanks for getting VIP! The VIP cave is open for you.")
		end
	end)

	vipRemote.OnServerEvent:Connect(function(player: Player, action: unknown)
		if action == "Buy" then
			VipService.PromptPurchase(player)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		vipPlayers[player] = nil
		lastPrompt[player] = nil
	end)
end

return VipService

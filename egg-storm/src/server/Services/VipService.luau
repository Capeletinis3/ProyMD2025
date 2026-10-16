--!strict
-- VipService: el pase VIP (un Game Pass de Roblox) y sus ventajas.
--
-- Quién es VIP lo decide SIEMPRE el servidor y lo publica en el atributo "VIP" del jugador. Es VIP si:
--   * tiene el Game Pass (Config.Vip.GamePassId), o
--   * alguien se lo regaló (queda anotado en el DataStore Config.Vip.GiftStoreName), o
--   * su UserId está en Config.Vip.TestUserIds.
--
-- Ventajas (los números están en Config.Vip):
--   * x2 de plata             → CreatureService (mira el atributo "VIP")
--   * cueva VIP               → acá: grupos de colisión para atravesar la pared invisible de la entrada
--   * incubación 20% más rápida → IncubatorService
--   * 1 huevo más para llevar  → EggService
--   * huevo Rare dorado gratis cada día → acá: va directo a un nido libre
--   * corona dorada arriba de la cabeza → acá; el [VIP] en el chat lo pone cada cliente (VipClient)
--
-- Regalar VIP: el jugador elige a otro del servidor y paga un Developer Product (Config.Vip.GiftProductId).
-- Cuando Roblox confirma el pago (ProcessReceipt) se anota en el DataStore y el otro pasa a ser VIP para siempre.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ReceiptService = require(script.Parent.ReceiptService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CreatureService = require(script.Parent.CreatureService)
local IncubatorService = require(script.Parent.IncubatorService)

local VipService = {}

local BARRIER_GROUP = "VipBarrier"
local PLAYER_GROUP = "VipPlayers"
local DAILY_CHECK = 15 -- cada cuántos segundos revisa el huevo diario

local notifyRemote = Remotes.Event("Notify")
local vipRemote = Remotes.Event("Vip")
local vipPlayers: { [Player]: boolean } = {}
local lastPrompt: { [Player]: number } = {}
local pendingGift: { [Player]: number } = {} -- a quién le quiere regalar (UserId), hasta que Roblox confirme el pago
local dailyWarned: { [Player]: boolean } = {}
local giftStore: DataStore? = nil

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

local function getGiftStore(): DataStore
	if not giftStore then
		giftStore = DataStoreService:GetDataStore(Config.Vip.GiftStoreName)
	end
	return giftStore :: DataStore
end

local function giftKey(userId: number): string
	return `Gift_{userId}`
end

-- ===== Cueva VIP y corona =====

local function setGroup(part: Instance)
	if part:IsA("BasePart") then
		part.CollisionGroup = PLAYER_GROUP
	end
end

-- Corona dorada flotando arriba de la cabeza (la ven todos)
local function addCrown(character: Model)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") or head:FindFirstChild("VipCrown") then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "VipCrown"
	billboard.Size = UDim2.fromScale(3, 1.6)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Parent = head
	local crown = Instance.new("TextLabel")
	crown.Size = UDim2.fromScale(1, 0.75)
	crown.BackgroundTransparency = 1
	crown.Text = "👑"
	crown.TextScaled = true
	crown.Parent = billboard
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromScale(1, 0.3)
	tag.Position = UDim2.fromScale(0, 0.7)
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.FredokaOne
	tag.Text = "VIP"
	tag.TextScaled = true
	tag.TextColor3 = Color3.fromRGB(255, 200, 40)
	tag.TextStrokeTransparency = 0
	tag.Parent = billboard
end

local function applyToCharacter(character: Model)
	for _, child in character:GetDescendants() do
		setGroup(child)
	end
	character.DescendantAdded:Connect(setGroup)
	addCrown(character)
end

-- ===== Huevo diario =====

-- Le da el huevo diario si ya le toca y tiene un nido libre (si no, lo guarda para cuando tenga lugar)
function VipService.TryDailyEgg(player: Player): boolean
	local profile = PlayerDataService.Get(player)
	if not vipPlayers[player] or not profile then
		return false
	end
	profile.Vip = true -- (por si los datos cargaron después de saber que es VIP)
	player:SetAttribute("NextDailyEgg", profile.LastDailyEgg + Config.Vip.DailyEggInterval)
	if not player:GetAttribute("BaseId") then
		return false
	end
	local now = os.time()
	if now < profile.LastDailyEgg + Config.Vip.DailyEggInterval then
		return false
	end
	local rarity = Config.GetRarity(Config.Vip.DailyEggRarity)
	local variant = Config.GetVariant(Config.Vip.DailyEggVariant)
	if not rarity then
		return false
	end
	local placed = IncubatorService.PlaceEgg(player, rarity, variant)
	if not placed then
		if not dailyWarned[player] then
			dailyWarned[player] = true
			notify(player, "👑 Your VIP daily egg is waiting! Free up an incubator to get it.")
		end
		return false
	end
	dailyWarned[player] = nil
	profile.LastDailyEgg = now
	player:SetAttribute("NextDailyEgg", now + Config.Vip.DailyEggInterval)
	notify(player, `👑 VIP daily egg! A {Config.WithVariant(variant, rarity.DisplayName .. " Egg")} is in your nest.`)
	return true
end

-- ===== Quién es VIP =====

function VipService.IsVip(player: Player): boolean
	return vipPlayers[player] == true
end

-- Lo hace VIP en este servidor y le activa todas las ventajas
function VipService.Grant(player: Player)
	if vipPlayers[player] then
		return
	end
	vipPlayers[player] = true
	player:SetAttribute("VIP", true)
	local profile = PlayerDataService.Get(player)
	if profile then
		profile.Vip = true
		player:SetAttribute("NextDailyEgg", profile.LastDailyEgg + Config.Vip.DailyEggInterval)
	end
	local character = player.Character
	if character then
		applyToCharacter(character)
	end
	CreatureService.RefreshIncome(player) -- x2 de plata
	IncubatorService.RecalculateTimes(player) -- incuba más rápido
	-- Huevo diario: apenas sus datos y sus nidos estén listos (puede tardar un poco al entrar)
	task.spawn(function()
		for _ = 1, 60 do
			if player.Parent ~= Players then
				return
			end
			if PlayerDataService.Get(player) and player:GetAttribute("BaseId") then
				task.wait(1) -- (los nidos se arman justo después)
				VipService.TryDailyEgg(player)
				return
			end
			task.wait(0.5)
		end
	end)
end

-- Pregunta a Roblox (puede fallar: probamos 3 veces)
local function withRetries(label: string, fn: () -> any): (boolean, any)
	local lastError: any = nil
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		warn(`[VipService] {label} failed (try {attempt}): {result}`)
		if attempt < 3 then
			task.wait(attempt * 2)
		end
	end
	return false, lastError
end

local function ownsVip(player: Player): boolean
	if table.find(Config.Vip.TestUserIds, player.UserId) then
		return true
	end
	local passId = Config.Vip.GamePassId
	if passId > 0 then
		local ok, owns = withRetries(`Pass check for {player.Name}`, function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok and owns == true then
			return true
		end
	end
	local ok, gift = withRetries(`Gift check for {player.Name}`, function()
		return getGiftStore():GetAsync(giftKey(player.UserId))
	end)
	return ok and typeof(gift) == "table" and gift.Gifted == true
end

-- ===== Comprar y regalar =====

local function cooledDown(player: Player): boolean
	local now = os.clock()
	if now - (lastPrompt[player] or -math.huge) < Config.Vip.PromptCooldown then
		return false
	end
	lastPrompt[player] = now
	return true
end

-- Abre la compra del pase (o avisa si ya sos VIP / si todavía no está configurado)
function VipService.PromptPurchase(player: Player)
	if not cooledDown(player) then
		return
	end
	if vipPlayers[player] then
		notify(player, "You're already VIP! Enjoy your perks.")
		return
	end
	if Config.Vip.GamePassId <= 0 then
		notify(player, "VIP isn't available yet. Check back soon!")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, Config.Vip.GamePassId)
end

-- Abre la compra del regalo para otro jugador del servidor
function VipService.PromptGift(player: Player, target: Player)
	if target == player or target.Parent ~= Players or not cooledDown(player) then
		return
	end
	if vipPlayers[target] then
		notify(player, `{target.DisplayName} already has VIP!`)
		return
	end
	if Config.Vip.GiftProductId <= 0 then
		notify(player, "Gifting VIP isn't available yet. Check back soon!")
		return
	end
	pendingGift[player] = target.UserId
	MarketplaceService:PromptProductPurchase(player, Config.Vip.GiftProductId)
end

-- Roblox confirma un pago de un Developer Product. Solo devolvemos "Granted" cuando el regalo quedó guardado:
-- si algo falla, Roblox lo vuelve a intentar más tarde (así nadie paga sin recibir).
local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision?
	if receipt.ProductId ~= Config.Vip.GiftProductId or Config.Vip.GiftProductId <= 0 then
		return nil -- no es un regalo de VIP (ver ReceiptService)
	end
	local buyer = Players:GetPlayerByUserId(receipt.PlayerId)
	local targetId = buyer and pendingGift[buyer]
	if not buyer or not targetId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	local ok = withRetries("Saving VIP gift", function()
		return getGiftStore():UpdateAsync(giftKey(targetId), function(old: any)
			local data = if typeof(old) == "table" then old else {}
			data.Receipts = if typeof(data.Receipts) == "table" then data.Receipts else {}
			data.Receipts[purchaseId] = true -- (si Roblox manda el mismo pago dos veces, no pasa nada)
			data.Gifted = true
			data.From = buyer.UserId
			return data
		end)
	end)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	pendingGift[buyer] = nil
	local target = Players:GetPlayerByUserId(targetId)
	if target then
		VipService.Grant(target)
		notify(target, `🎁 {buyer.DisplayName} gifted you VIP! Enjoy your perks!`)
		notify(buyer, `🎁 You gifted VIP to {target.DisplayName}!`)
	else
		notify(buyer, "🎁 VIP gift sent! They'll get it next time they play.")
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ===== Arranque =====

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		if vipPlayers[player] then
			applyToCharacter(character)
		end
	end)
	if ownsVip(player) and player.Parent then
		VipService.Grant(player)
	end
end

function VipService.Init(map: Folder)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(BARRIER_GROUP)
		PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(BARRIER_GROUP, PLAYER_GROUP, false)
	-- La pared de la cueva VIP (su botón "Get VIP" lo abre cada cliente: muestra la ventana VIP)
	for _, item in map:GetDescendants() do
		if item:IsA("BasePart") and item:GetAttribute("VipBarrier") then
			item.CollisionGroup = BARRIER_GROUP
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if purchased and passId == Config.Vip.GamePassId and Config.Vip.GamePassId > 0 then
			VipService.Grant(player)
			notify(player, "👑 Thanks for getting VIP! All your perks are on.")
		end
	end)
	ReceiptService.Register(processReceipt)

	vipRemote.OnServerEvent:Connect(function(player: Player, action: unknown, userId: unknown)
		if action == "Buy" then
			VipService.PromptPurchase(player)
		elseif action == "Gift" and typeof(userId) == "number" then
			local target = Players:GetPlayerByUserId(userId)
			if target then
				VipService.PromptGift(player, target)
			end
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		vipPlayers[player] = nil
		lastPrompt[player] = nil
		pendingGift[player] = nil
		dailyWarned[player] = nil
	end)

	-- Huevo diario: revisa de vez en cuando (por si le tocó mientras jugaba o liberó un nido)
	task.spawn(function()
		while true do
			task.wait(DAILY_CHECK)
			for player in vipPlayers do
				VipService.TryDailyEgg(player)
			end
		end
	end)
end

return VipService

--!strict
-- SpinService: la ruleta (botón SPIN del HUD).
--   * Un giro gratis cada Config.Spin.FreeInterval (se guarda cuándo usaste el último: LastFreeSpin).
--   * Giros extra: se compran con Robux (Developer Product Config.Spin.ProductId) y quedan guardados (SpinTokens).
--   * El servidor elige el premio y lo da en el momento; el cliente solo hace girar la ruleta hasta ese premio.
-- Para el cliente: atributos "NextFreeSpinAt" (hora del servidor) y "SpinTokens".
-- Remote "Spin": el cliente manda "Spin" o "Buy"; el servidor contesta ("Result", númeroDePremio, texto).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CreatureService = require(script.Parent.CreatureService)
local IncubatorService = require(script.Parent.IncubatorService)
local PotionService = require(script.Parent.PotionService)
local MerchantService = require(script.Parent.MerchantService)
local ReceiptService = require(script.Parent.ReceiptService)

local SpinService = {}

local random = Random.new()
local lastAction: { [Player]: number } = {}
local spinRemote = Remotes.Event("Spin")
local notifyRemote = Remotes.Event("Notify")

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

local function sync(player: Player)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	local wait = math.max(0, profile.LastFreeSpin + Config.Spin.FreeInterval - os.time())
	player:SetAttribute("NextFreeSpinAt", Workspace:GetServerTimeNow() + wait)
	player:SetAttribute("SpinTokens", profile.SpinTokens)
end

function SpinService.HasFreeSpin(player: Player): boolean
	local profile = PlayerDataService.Get(player)
	return profile ~= nil and os.time() - profile.LastFreeSpin >= Config.Spin.FreeInterval
end

local function rollPrize(): number
	local total = 0
	for _, prize in Config.Spin.Prizes do
		total += prize.Weight
	end
	local roll = random:NextNumber(0, total)
	for i, prize in Config.Spin.Prizes do
		roll -= prize.Weight
		if roll <= 0 then
			return i
		end
	end
	return 1
end

-- Da el premio. Devuelve el texto para mostrar.
local function grant(player: Player, prize: Config.SpinPrize): string
	if prize.Potion then
		PotionService.Add(player, prize.Potion :: any)
		local info = (Config.Potions :: any)[prize.Potion]
		return `{info.Icon} {info.DisplayName}! ({info.Description})`
	elseif prize.RarityId then
		local rarity = Config.GetRarity(prize.RarityId)
		if rarity then
			local variant = Config.GetVariant("Normal")
			if IncubatorService.CanPlaceEgg(player) and IncubatorService.PlaceEgg(player, rarity, variant) then
				return `🥚 A {rarity.DisplayName} Egg! It's incubating in your habitat.`
			end
			-- Sin nido libre: te damos lo que vale en monedas
			local coins = MerchantService.PriceOf(rarity, variant)
			PlayerDataService.AddCoins(player, coins)
			return `🥚 A {rarity.DisplayName} Egg! No free nest, so you got {Format.Number(coins)} coins instead.`
		end
	end
	local coins = math.max(prize.MinCoins or 0, math.floor(CreatureService.GetIncomePerSecond(player) * (prize.IncomeSeconds or 0)))
	PlayerDataService.AddCoins(player, coins)
	return `💰 {Format.Number(coins)} coins!`
end

-- Gira: usa el giro gratis si hay, si no un giro comprado. Devuelve el número de premio (o nil si no pudo).
function SpinService.TrySpin(player: Player): number?
	local now = os.clock()
	if now - (lastAction[player] or 0) < Config.Spin.Cooldown then
		return nil
	end
	lastAction[player] = now
	local profile = PlayerDataService.Get(player)
	if not profile then
		return nil
	end
	if SpinService.HasFreeSpin(player) then
		profile.LastFreeSpin = os.time()
	elseif profile.SpinTokens > 0 then
		profile.SpinTokens -= 1
	else
		notify(player, "No spins left! Come back later or buy a spin.")
		return nil
	end
	local index = rollPrize()
	local text = grant(player, Config.Spin.Prizes[index])
	sync(player)
	PlayerDataService.SaveNow(player)
	spinRemote:FireClient(player, "Result", index, text)
	return index
end

function SpinService.PromptPurchase(player: Player)
	if Config.Spin.ProductId <= 0 then
		notify(player, "Spins can't be bought yet. Check back soon!")
		return
	end
	MarketplaceService:PromptProductPurchase(player, Config.Spin.ProductId)
end

-- Roblox confirma que pagó un giro. Solo decimos "Granted" cuando el giro quedó guardado.
local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision?
	if Config.Spin.ProductId <= 0 or receipt.ProductId ~= Config.Spin.ProductId then
		return nil
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and PlayerDataService.Get(player)
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- se fue o no cargó: Roblox lo intenta de nuevo después
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(profile.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- ya lo dimos (Roblox lo mandó dos veces)
	end
	profile.SpinTokens += 1
	table.insert(profile.Receipts, purchaseId)
	while #profile.Receipts > 50 do
		table.remove(profile.Receipts, 1)
	end
	if not PlayerDataService.SaveAndWait(player) then
		profile.SpinTokens -= 1
		table.remove(profile.Receipts, table.find(profile.Receipts, purchaseId) :: number)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	sync(player)
	notify(player, "🎡 Thanks! You got 1 spin. Tap SPIN to use it!")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Cuando carga sus datos
function SpinService.SetupBase(player: Player)
	sync(player)
end

function SpinService.Init()
	ReceiptService.Register(processReceipt)
	spinRemote.OnServerEvent:Connect(function(player: Player, action: unknown)
		if action == "Spin" then
			SpinService.TrySpin(player)
		elseif action == "Buy" then
			local now = os.clock()
			if now - (lastAction[player] or 0) >= Config.Spin.Cooldown then
				lastAction[player] = now
				SpinService.PromptPurchase(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return SpinService

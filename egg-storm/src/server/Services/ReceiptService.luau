--!strict
-- ReceiptService: Roblox deja UNA sola función para cobrar los Developer Products (MarketplaceService.ProcessReceipt).
-- Cada servicio que vende algo con Robux (regalar VIP, giros de la ruleta...) se anota acá con Register.
-- Cada uno devuelve nil si el pago no es de su producto, o lo que decidió (PurchaseGranted / NotProcessedYet).

local MarketplaceService = game:GetService("MarketplaceService")

local ReceiptService = {}

export type Handler = ({ [string]: any }) -> Enum.ProductPurchaseDecision?

local handlers: { Handler } = {}

function ReceiptService.Register(handler: Handler)
	table.insert(handlers, handler)
end

function ReceiptService.Process(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	for _, handler in handlers do
		local ok, decision = pcall(handler, receipt)
		if not ok then
			warn("[ReceiptService] Error processing a purchase:", decision)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if decision ~= nil then
			return decision
		end
	end
	-- De ningún producto conocido: Roblox lo vuelve a intentar (por si el servidor todavía estaba arrancando)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function ReceiptService.Init()
	MarketplaceService.ProcessReceipt = ReceiptService.Process
end

return ReceiptService

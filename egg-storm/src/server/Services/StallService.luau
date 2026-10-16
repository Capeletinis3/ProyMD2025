--!strict
-- StallService: los puestos del lobby que todavía no tienen su sistema.
-- El Intercambio (fase 4) por ahora solo avisa "Coming soon!".
-- La Tienda de mejoras la maneja UpgradeService, el Comerciante MerchantService y los Rankings, LeaderboardService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local StallService = {}

local COMING_SOON: { [string]: string } = {
	Trading = "Trading is coming soon!",
}

local notifyRemote = Remotes.Event("Notify")

function StallService.Init(map: Folder)
	local stalls = map:FindFirstChild("Stalls", true)
	if not stalls then
		return
	end
	for _, stall in stalls:GetChildren() do
		local message = COMING_SOON[stall.Name]
		local counter = stall:FindFirstChild("Counter")
		local prompt = counter and counter:FindFirstChildOfClass("ProximityPrompt")
		if message and prompt then
			prompt.Triggered:Connect(function(player)
				notifyRemote:FireClient(player, message)
			end)
		end
	end
end

return StallService

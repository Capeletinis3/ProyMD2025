--!strict
-- SellPrompts: el botón "Sell" de cada mascota solo lo ve su dueño.
-- (Es para no llenar la pantalla de botones en bases ajenas: el servidor igual valida cada venta.)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local SellPrompts = {}

local function setup(prompt: Instance)
	if prompt:IsA("ProximityPrompt") then
		prompt.Enabled = prompt:GetAttribute("OwnerUserId") == player.UserId
	end
end

function SellPrompts.Start()
	for _, prompt in CollectionService:GetTagged("SellPrompt") do
		setup(prompt)
	end
	CollectionService:GetInstanceAddedSignal("SellPrompt"):Connect(setup)
end

return SellPrompts

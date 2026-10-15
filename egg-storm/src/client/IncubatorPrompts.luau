--!strict
-- IncubatorPrompts: decide si ESTE jugador ve el botón "Incubate" de cada incubadora.
-- Solo lo ve en su propia base, si la incubadora está libre y si lleva un huevo.
-- Esto es solo para que la pantalla no se llene de botones inútiles:
-- el servidor igual valida todo cuando se aprieta.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local IncubatorPrompts = {}

local function refresh(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local myBase = player:GetAttribute("BaseId")
	local carrying = player:GetAttribute("CarriedEggRarity") ~= nil
	local available = prompt:GetAttribute("Available") == true
	prompt.Enabled = available and carrying and prompt:GetAttribute("BaseId") == myBase
end

local function refreshAll()
	for _, prompt in CollectionService:GetTagged("IncubatorPrompt") do
		refresh(prompt)
	end
end

function IncubatorPrompts.Start()
	CollectionService:GetInstanceAddedSignal("IncubatorPrompt"):Connect(function(prompt)
		refresh(prompt)
		prompt:GetAttributeChangedSignal("Available"):Connect(function()
			refresh(prompt)
		end)
	end)
	for _, prompt in CollectionService:GetTagged("IncubatorPrompt") do
		prompt:GetAttributeChangedSignal("Available"):Connect(function()
			refresh(prompt)
		end)
	end
	player:GetAttributeChangedSignal("CarriedEggRarity"):Connect(refreshAll)
	player:GetAttributeChangedSignal("BaseId"):Connect(refreshAll)
	refreshAll()
end

return IncubatorPrompts

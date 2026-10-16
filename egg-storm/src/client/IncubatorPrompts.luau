--!strict
-- IncubatorPrompts: decide si ESTE jugador ve el botón de cada nido-incubadora.
--   "Place Egg": solo en tu propia base, si el nido está vacío y llevás un huevo.
--   "Open":      solo en tu propia base, cuando el huevo está listo.
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
	local mine = prompt:GetAttribute("BaseId") == player:GetAttribute("BaseId")
	local carrying = player:GetAttribute("CarriedEggRarity") ~= nil
	local state = prompt:GetAttribute("State")
	prompt.Enabled = mine and ((state == "Empty" and carrying) or state == "Ready")
end

local function refreshAll()
	for _, prompt in CollectionService:GetTagged("IncubatorPrompt") do
		refresh(prompt)
	end
end

local function watch(prompt: Instance)
	refresh(prompt)
	prompt:GetAttributeChangedSignal("State"):Connect(function()
		refresh(prompt)
	end)
end

function IncubatorPrompts.Start()
	CollectionService:GetInstanceAddedSignal("IncubatorPrompt"):Connect(watch)
	for _, prompt in CollectionService:GetTagged("IncubatorPrompt") do
		watch(prompt)
	end
	player:GetAttributeChangedSignal("CarriedEggRarity"):Connect(refreshAll)
	player:GetAttributeChangedSignal("BaseId"):Connect(refreshAll)
	refreshAll()
end

return IncubatorPrompts

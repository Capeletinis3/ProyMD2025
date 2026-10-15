--!strict
-- Punto de entrada del cliente.
-- (El cliente nunca decide nada importante: solo muestra lo que el servidor le dice.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notifier = require(script.Parent.Notifier)
local IncubatorPrompts = require(script.Parent.IncubatorPrompts)
local UpgradePanel = require(script.Parent.UpgradePanel)
local StormClient = require(script.Parent.StormClient)

local player = Players.LocalPlayer

-- Avisos que manda el servidor ("You grabbed a Rare Egg!", etc.)
Remotes.Event("Notify").OnClientEvent:Connect(function(text: unknown)
	if typeof(text) == "string" then
		Notifier.Show(text)
	end
end)

-- Un huevo se abrió (en la fase 6 esto se reemplaza por la animación de apertura)
Remotes.Event("Hatched").OnClientEvent:Connect(function(creatureName: unknown, rarityId: unknown)
	if typeof(creatureName) == "string" and typeof(rarityId) == "string" then
		local rarity = Config.GetRarity(rarityId)
		local rarityName = if rarity then string.upper(rarity.DisplayName) else rarityId
		Notifier.Show(`You got: {creatureName}! {rarityName}`, 6)
	end
end)

local function onBaseChanged()
	local baseId = player:GetAttribute("BaseId")
	if typeof(baseId) == "number" then
		Notifier.Show(`Welcome! Your base is #{baseId}.`, 6)
	end
end

player:GetAttributeChangedSignal("BaseId"):Connect(onBaseChanged)
onBaseChanged()

IncubatorPrompts.Start()
UpgradePanel.Start()
StormClient.Start()

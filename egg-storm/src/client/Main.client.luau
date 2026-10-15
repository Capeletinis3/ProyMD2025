--!strict
-- Punto de entrada del cliente.
-- (El cliente nunca decide nada importante: solo muestra lo que el servidor le dice.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notifier = require(script.Parent.Notifier)

local player = Players.LocalPlayer

-- Avisos que manda el servidor ("You grabbed a Rare Egg!", etc.)
Remotes.Event("Notify").OnClientEvent:Connect(function(text: unknown)
	if typeof(text) == "string" then
		Notifier.Show(text)
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

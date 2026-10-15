--!strict
-- Punto de entrada del cliente.
-- (El cliente nunca decide nada importante: solo muestra lo que el servidor le dice.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notifier = require(script.Parent.Notifier)
local IncubatorPrompts = require(script.Parent.IncubatorPrompts)
local SellPrompts = require(script.Parent.SellPrompts)
local UpgradePanel = require(script.Parent.UpgradePanel)
local StormClient = require(script.Parent.StormClient)
local Hud = require(script.Parent.Hud)
local HatchReveal = require(script.Parent.HatchReveal)
local Tutorial = require(script.Parent.Tutorial)
local WelcomeBack = require(script.Parent.WelcomeBack)

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

IncubatorPrompts.Start()
SellPrompts.Start()
UpgradePanel.Start()
StormClient.Start()
Hud.Start()
HatchReveal.Start()
Tutorial.Start()
WelcomeBack.Start()

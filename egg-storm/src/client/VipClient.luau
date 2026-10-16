--!strict
-- VipClient: lo del pase VIP en la pantalla del jugador.
--   * Botón "👑 VIP" en el costado (pide al servidor que abra la compra; si ya sos VIP, cambia a "👑 VIP ✓").
--   * Si ya sos VIP, se esconde el botón "Get VIP" de la cueva (solo para vos).
-- Quién es VIP lo decide el servidor (atributo "VIP"); acá solo se muestra.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SideMenu = require(script.Parent.SideMenu)

local player = Players.LocalPlayer
local vipRemote = Remotes.Event("Vip")

local VipClient = {}

local function isVip(): boolean
	return player:GetAttribute("VIP") == true
end

local function updatePrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") then
		prompt.Enabled = not isVip()
	end
end

function VipClient.Start()
	local button = SideMenu.AddButton("👑 VIP", Color3.fromRGB(230, 170, 20), function()
		vipRemote:FireServer("Buy")
	end)
	local function refresh()
		button.Text = if isVip() then "👑 VIP ✓" else "👑 VIP"
		for _, prompt in CollectionService:GetTagged("VipPrompt") do
			updatePrompt(prompt)
		end
	end
	CollectionService:GetInstanceAddedSignal("VipPrompt"):Connect(updatePrompt)
	player:GetAttributeChangedSignal("VIP"):Connect(refresh)
	refresh()
end

return VipClient

--!strict
-- VipClient: lo del VIP en la pantalla del jugador.
--   * Botón "👑 VIP" en el costado y "Get VIP" en la cueva VIP: abren la ventana VIP (VipPanel).
--   * Si ya sos VIP, se esconde el "Get VIP" de la cueva (solo para vos).
--   * [VIP] dorado delante del nombre en el chat, para todos los jugadores VIP.
-- Quién es VIP lo decide el servidor (atributo "VIP"); acá solo se muestra.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local SideMenu = require(script.Parent.SideMenu)
local VipPanel = require(script.Parent.VipPanel)

local player = Players.LocalPlayer

local VipClient = {}

local function isVip(who: Player): boolean
	return who:GetAttribute("VIP") == true
end

local function setupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Enabled = not isVip(player)
	prompt.Triggered:Connect(function()
		VipPanel.Open()
	end)
end

-- Etiqueta en el chat (con el chat nuevo de Roblox, TextChatService)
local function setupChatTag()
	TextChatService.OnIncomingMessage = (function(message: TextChatMessage): TextChatMessageProperties?
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		if sender and isVip(sender) then
			local properties = Instance.new("TextChatMessageProperties")
			properties.PrefixText = `<font color="#FFC828">[VIP]</font> {message.PrefixText}`
			return properties
		end
		return nil
	end) :: any
end

function VipClient.Start()
	VipPanel.Start()
	SideMenu.Bind("Vip", VipPanel.Open)
	local function refresh()
		SideMenu.SetBadge("Vip", if isVip(player) then "✓" else nil, Color3.fromRGB(108, 255, 77))
		for _, prompt in CollectionService:GetTagged("VipPrompt") do
			if prompt:IsA("ProximityPrompt") then
				prompt.Enabled = not isVip(player)
			end
		end
	end
	for _, prompt in CollectionService:GetTagged("VipPrompt") do
		setupPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("VipPrompt"):Connect(setupPrompt)
	player:GetAttributeChangedSignal("VIP"):Connect(refresh)
	refresh()
	pcall(setupChatTag) -- (si el juego usa el chat viejo, simplemente no hay etiqueta)
end

return VipClient

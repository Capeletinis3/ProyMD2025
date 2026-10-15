--!strict
-- Punto de entrada del cliente. Por ahora solo avisa qué base te tocó.
-- (El cliente nunca decide nada importante: solo muestra lo que el servidor le dice.)

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

-- SetCore puede fallar si la interfaz de Roblox todavía no cargó, así que reintentamos un rato.
local function notify(title: string, text: string)
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 6 })
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end

local function onBaseChanged()
	local baseId = player:GetAttribute("BaseId")
	if typeof(baseId) == "number" then
		notify("Egg Storm", `Welcome! Your base is #{baseId}.`)
	end
end

player:GetAttributeChangedSignal("BaseId"):Connect(onBaseChanged)
onBaseChanged()

--!strict
-- Notifier: muestra avisos chiquitos en pantalla (abajo a la derecha).
-- En la fase 6 lo reemplazamos por una interfaz propia más linda.

local StarterGui = game:GetService("StarterGui")

local Notifier = {}

-- SetCore puede fallar si la interfaz de Roblox todavía no cargó, así que reintentamos un rato.
function Notifier.Show(text: string, duration: number?)
	task.spawn(function()
		for _ = 1, 20 do
			local ok = pcall(function()
				StarterGui:SetCore("SendNotification", { Title = "Egg Storm", Text = text, Duration = duration or 4 })
			end)
			if ok then
				return
			end
			task.wait(0.5)
		end
	end)
end

return Notifier

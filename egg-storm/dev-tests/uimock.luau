-- UI mock: real UDim2/Vector2 values, LocalPlayer, camera, tags, GUI signals.
local function udim2(xs, xo, ys, yo) return { X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 }, __udim2 = true } end
UDim2 = {
	new = function(xs, xo, ys, yo) return udim2(xs, xo, ys, yo) end,
	fromOffset = function(x, y) return udim2(0, x, 0, y) end,
	fromScale = function(x, y) return udim2(x, 0, y, 0) end,
}
UDim = { new = function(s, o) return { Scale = s, Offset = o } end }
Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }
NumberSequenceKeypoint = { new = function(...) return { ... } end }

-- más señales de GUI
do
	local probe = Instance.new("Folder")
	local M = getmetatable(probe)
	local idx = M.__index
	local EXTRA = { Activated = true, Heartbeat = true, RenderStepped = true }
	M.__index = function(self, k)
		if EXTRA[k] then
			local sigs = rawget(self, "_signals")
			if not sigs then sigs = {}; rawset(self, "_signals", sigs) end
			sigs[k] = sigs[k] or NEW_SIGNAL()
			return sigs[k]
		end
		if (k == "Play" or k == "Stop") and rawget(self, "_props").ClassName == "Sound" then
			return function() end
		end
		if k == "GetPropertyChangedSignal" then
			return function() return NEW_SIGNAL() end
		end
		return idx(self, k)
	end
end

TAGGED = {}
local cs = game:GetService("CollectionService")
rawget(cs, "_props").GetTagged = function(_, tag) return TAGGED[tag] or {} end
rawget(cs, "_props").GetInstanceAddedSignal = function() return NEW_SIGNAL() end

local ws = game:GetService("Workspace")
local camera = Instance.new("Camera")
camera.ViewportSize = Vector2.new(VIEW_W or 1280, VIEW_H or 720)
camera.CFrame = CFrame.new(0, 10, 0)
ws.CurrentCamera = camera

local players = game:GetService("Players")
LOCAL = Instance.new("Player")
LOCAL.Name = "Tester"
local pg = Instance.new("PlayerGui")
pg.Name = "PlayerGui"
pg.Parent = LOCAL
rawget(players, "_props").LocalPlayer = LOCAL

-- Recorre la interfaz e imprime cada elemento con su rectángulo absoluto
function DUMP_GUI(root)
	local function abs(obj, px, py, pw, ph, k)
		-- k = escala acumulada de los UIScale de los padres (en Roblox escala todo el subárbol)
		local size, pos = obj.Size, obj.Position
		local w = (size and (size.X.Scale * pw + size.X.Offset * k)) or pw
		local h = (size and (size.Y.Scale * ph + size.Y.Offset * k)) or ph
		local x = px + ((pos and (pos.X.Scale * pw + pos.X.Offset * k)) or 0)
		local y = py + ((pos and (pos.Y.Scale * ph + pos.Y.Offset * k)) or 0)
		local ap = obj.AnchorPoint or Vector2.new(0, 0)
		x -= ap.X * w
		y -= ap.Y * h
		-- UIScale: escala alrededor del centro del objeto
		local sc = obj:FindFirstChildOfClass("UIScale")
		if sc then
			local s = sc.Scale or 1
			local cx, cy = x + w / 2, y + h / 2
			w *= s; h *= s; x = cx - w / 2; y = cy - h / 2
		end
		return x, y, w, h
	end
	local function walk(obj, px, py, pw, ph, scale, visible)
		local cls = obj.ClassName
		if cls == "ScreenGui" or cls == "SurfaceGui" then
			if obj.Enabled == false then return end
			for _, c in obj:GetChildren() do walk(c, 0, 0, pw, ph, 1, true) end
			return
		end
		local isGui = cls == "Frame" or cls == "TextLabel" or cls == "TextButton" or cls == "CanvasGroup"
		if not isGui then return end
		if obj.Visible == false then return end
		local x, y, w, h = abs(obj, px, py, pw, ph, scale)
		local sc = obj:FindFirstChildOfClass("UIScale")
		local s = scale * (sc and sc.Scale or 1)
		local bg = obj.BackgroundColor3
		local bt = obj.BackgroundTransparency or 0
		local hasCorner = obj:FindFirstChildOfClass("UICorner") ~= nil
		local text = obj.Text
		local tc = obj.TextColor3
		print(string.format("GUI\t%s\t%.1f\t%.1f\t%.1f\t%.1f\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s",
			cls, x, y, w, h,
			bg and string.format("%.3f,%.3f,%.3f", bg.R, bg.G, bg.B) or "-",
			tostring(bt), tostring(hasCorner),
			text and text:gsub("\t", " "):gsub("\n", "\\n") or "",
			tc and string.format("%.3f,%.3f,%.3f", tc.R, tc.G, tc.B) or "-",
			tostring(if obj.TextScaled and text then math.min(h * 0.8, w / math.max(1, utf8.len(text) or #text) / 0.6) else (obj.TextSize or 14) * s),
			tostring(obj.TextXAlignment or ""), tostring(s),
			obj.Name .. "|" .. tostring(obj.Rotation or 0)))
		for _, c in obj:GetChildren() do walk(c, x, y, w, h, s, true) end
	end
	for _, c in root:GetChildren() do walk(c, 0, 0, VIEW_W or 1280, VIEW_H or 720, 1, true) end
end

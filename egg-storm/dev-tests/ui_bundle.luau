VIEW_W, VIEW_H = 844, 390
-- Minimal Roblox API mock, enough to run MapBuilder + BaseService.Init outside Studio.

local function vec(x, y, z) end
local V = {}
V.__index = function(self, k)
	if k == "X" then return rawget(self, "x") end
	if k == "Y" then return rawget(self, "y") end
	if k == "Z" then return rawget(self, "z") end
	if k == "Magnitude" then return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z) end
	if k == "Unit" then local m = self.Magnitude; return vec(self.x / m, self.y / m, self.z / m) end
	if k == "Cross" then return function(a, b) return vec(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end end
	if k == "Dot" then return function(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end end
	return nil
end
function vec(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0, __vec = true }, V) end
V.__add = function(a, b) return vec(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__unm = function(a) return vec(-a.x, -a.y, -a.z) end
V.__mul = function(a, b)
	if type(a) == "number" then return vec(a * b.x, a * b.y, a * b.z) end
	if type(b) == "number" then return vec(a.x * b, a.y * b, a.z * b) end
	return vec(a.x * b.x, a.y * b.y, a.z * b.z)
end
V.__div = function(a, b)
	if type(b) == "number" then return vec(a.x / b, a.y / b, a.z / b) end
	return vec(a.x / b.x, a.y / b.y, a.z / b.z)
end
Vector3 = { new = vec, zero = vec(0, 0, 0) }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }

-- CFrame: position p + rotation matrix columns r (right), u (up), b (back)
local C = {}
local function cf(p, r, u, b) return setmetatable({ p = p, r = r, u = u, b = b }, C) end
local function rot(c, v) return c.r * v.x + c.u * v.y + c.b * v.z end
C.__index = function(self, k)
	if k == "Position" then return self.p end
	if k == "LookVector" then return -self.b end
	if k == "RightVector" then return self.r end
	if k == "UpVector" then return self.u end
	if k == "PointToWorldSpace" then return function(c, v) return c.p + rot(c, v) end end
	if k == "PointToObjectSpace" then return function(c, v) local d = v - c.p; return vec(d:Dot(c.r), d:Dot(c.u), d:Dot(c.b)) end end
	return nil
end
C.__mul = function(a, b)
	if b.__vec then return a.p + rot(a, b) end
	return cf(a.p + rot(a, b.p), rot(a, b.r), rot(a, b.u), rot(a, b.b))
end
C.__add = function(a, v) return cf(a.p + v, a.r, a.u, a.b) end
local I = { vec(1, 0, 0), vec(0, 1, 0), vec(0, 0, 1) }
CFrame = {}
CFrame.new = function(x, y, z)
	if type(x) == "table" then return cf(x, I[1], I[2], I[3]) end
	return cf(vec(x or 0, y or 0, z or 0), I[1], I[2], I[3])
end
CFrame.lookAt = function(at, target)
	local look = (target - at).Unit
	local right = look:Cross(vec(0, 1, 0)).Unit
	local up = right:Cross(look)
	return cf(at, right, up, -look)
end
local function rx(t) return cf(vec(), vec(1, 0, 0), vec(0, math.cos(t), math.sin(t)), vec(0, -math.sin(t), math.cos(t))) end
local function ry(t) return cf(vec(), vec(math.cos(t), 0, -math.sin(t)), vec(0, 1, 0), vec(math.sin(t), 0, math.cos(t))) end
local function rz(t) return cf(vec(), vec(math.cos(t), math.sin(t), 0), vec(-math.sin(t), math.cos(t), 0), vec(0, 0, 1)) end
CFrame.Angles = function(a, b, c) return rx(a) * ry(b) * rz(c) end

local Col = {}
Col.__index = { Lerp = function(a, b, t) return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end }
Color3 = {
	new = function(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Col) end,
}
Color3.fromRGB = function(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end

local dummy = function(...) return { ... } end
UDim2 = { new = dummy, fromScale = dummy, fromOffset = dummy }
UDim = { new = dummy }
ColorSequence = { new = dummy }
ColorSequenceKeypoint = { new = dummy }
NumberSequence = { new = dummy }
NumberRange = { new = dummy }
Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })

-- Instances
ALL_PARTS = {}
local Inst = {}
local PART_CLASSES = { Part = true, TrussPart = true, WedgePart = true, SpawnLocation = true }
local function isA(self, class)
	if self.ClassName == class then return true end
	if class == "BasePart" and PART_CLASSES[self.ClassName] then return true end
	if class == "Instance" then return true end
	return false
end
Inst.__index = function(self, k)
	local methods = {
		IsA = isA,
		GetChildren = function(s) local t = {}; for _, c in rawget(s, "_children") do table.insert(t, c) end; return t end,
		FindFirstChild = function(s, name, recursive)
			for _, c in rawget(s, "_children") do
				if c.Name == name then return c end
			end
			if recursive then
				for _, c in rawget(s, "_children") do
					local f = c:FindFirstChild(name, true)
					if f then return f end
				end
			end
			return nil
		end,
		FindFirstChildOfClass = function(s, cls) for _, c in rawget(s, "_children") do if c.ClassName == cls then return c end end return nil end,
		WaitForChild = function(s, name) return s:FindFirstChild(name) end,
		SetAttribute = function(s, k2, v) rawget(s, "_attrs")[k2] = v end,
		GetAttribute = function(s, k2) return rawget(s, "_attrs")[k2] end,
		Destroy = function(s) s.Parent = nil end,
		AddTag = function() end,
		RemoveTag = function() end,
		GetFullName = function(s) local p = rawget(s, "_props").Parent; return (p and p:GetFullName() .. "." or "") .. s.Name end,
	}
	if methods[k] then return methods[k] end
	if k == "_children" or k == "_attrs" or k == "_props" then return rawget(self, k) end
	local props = rawget(self, "_props")
	if k == "Position" and props.CFrame then return props.CFrame.p end
	if k == "Parent" then return props.Parent end
	local v = props[k]
	if v == nil then
		-- signals
		if k:match("Changed$") or k == "Triggered" or k == "Completed" then return { Connect = function() end } end
	end
	return v
end
Inst.__newindex = function(self, k, v)
	local props = rawget(self, "_props")
	if k == "Parent" then
		local old = props.Parent
		if old then
			local ch = rawget(old, "_children")
			for i, c in ch do if c == self then table.remove(ch, i) break end end
		end
		props.Parent = v
		if v then table.insert(rawget(v, "_children"), self) end
		return
	end
	props[k] = v
end
local function newInstance(class)
	local o = setmetatable({ _children = {}, _attrs = {}, _props = { ClassName = class, Name = class, Transparency = 0 } }, Inst)
	if PART_CLASSES[class] then table.insert(ALL_PARTS, o) end
	return o
end
Instance = { new = newInstance }

local services = {}
local function signal() return { Connect = function() end } end
game = { GetService = function(_, name)
	if not services[name] then
		local s = newInstance(name)
		s.Name = name
		if name == "Players" then
			rawget(s, "_props").PlayerAdded = signal()
			rawget(s, "_props").PlayerRemoving = signal()
			rawget(s, "_props").GetPlayers = function() return {} end
		end
		services[name] = s
	end
	return services[name]
end }
warn = function(...) print("WARN", ...) end

Random = { new = function(seed)
	local state = (seed or 1) % 2147483647
	local function nxt()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	return {
		NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + (b - a) * nxt() end,
		NextInteger = function(_, a, b) return a + math.floor(nxt() * (b - a + 1)) end,
	}
end }
do
	local base = Random.new
	Random.new = function(seed)
		local r = base(seed)
		r.Shuffle = function(self, t)
			for i = #t, 2, -1 do
				local j = self:NextInteger(1, i)
				t[i], t[j] = t[j], t[i]
			end
		end
		return r
	end
end

-- Runtime extensions on top of mock.luau: fake clock, task scheduler, signals, players, services.

NOW = 0
local realOs = os
os = setmetatable({ clock = function() return NOW end }, { __index = realOs })

-- ===== Scheduler =====
local sleeping = {} -- { {co=, at=, args=} }
local function schedule(co, at, ...)
	table.insert(sleeping, { co = co, at = at, args = table.pack(...) })
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error("coroutine error: " .. tostring(err) .. "\n" .. debug.traceback(co))
	end
end
task = {}
task.spawn = function(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	resume(co, ...)
	return co
end
task.defer = function(f, ...)
	local co = coroutine.create(f)
	schedule(co, NOW, ...)
	return co
end
task.delay = function(t, f, ...)
	local co = coroutine.create(f)
	schedule(co, NOW + (t or 0), ...)
	return co
end
task.wait = function(t)
	local co = coroutine.running()
	assert(co and coroutine.isyieldable(), "task.wait called outside a coroutine")
	schedule(co, NOW + (t or 0.03))
	return coroutine.yield()
end
function ADVANCE(seconds, step)
	step = step or 0.05
	local target = NOW + seconds
	while true do
		-- run everything due
		local ran = true
		while ran do
			ran = false
			table.sort(sleeping, function(a, b) return a.at < b.at end)
			local first = sleeping[1]
			if first and first.at <= NOW then
				table.remove(sleeping, 1)
				resume(first.co, table.unpack(first.args, 1, first.args.n))
				ran = true
			end
		end
		if NOW >= target then break end
		NOW = math.min(target, NOW + step)
	end
end

-- ===== Signals =====
local Signal = {}
Signal.__index = Signal
function NEW_SIGNAL() return setmetatable({ fns = {} }, Signal) end
function Signal:Connect(fn) table.insert(self.fns, fn); return { Disconnect = function() end } end
function Signal:Fire(...) for _, fn in self.fns do task.spawn(fn, ...) end end
function Signal:Wait() local co = coroutine.running(); local c; c = self:Connect(function(...) resume(co, ...) end); return coroutine.yield() end

-- Patch Instance mock: per-instance signals + more methods
local probe = Instance.new("Folder")
local InstMeta = getmetatable(probe)
local baseIndex = InstMeta.__index
local SIGNAL_NAMES = {
	PlayerAdded = true, PlayerRemoving = true, CharacterAdded = true, CharacterRemoving = true,
	Triggered = true, Died = true, Completed = true, OnClientEvent = true, OnServerEvent = true, Changed = true,
}
REMOTE_LOG = {}
InstMeta.__index = function(self, k)
	if SIGNAL_NAMES[k] then
		local sigs = rawget(self, "_signals")
		if not sigs then sigs = {}; rawset(self, "_signals", sigs) end
		sigs[k] = sigs[k] or NEW_SIGNAL()
		return sigs[k]
	end
	if k == "GetAttributeChangedSignal" then
		return function(s, name)
			local sigs = rawget(s, "_attrSignals")
			if not sigs then sigs = {}; rawset(s, "_attrSignals", sigs) end
			sigs[name] = sigs[name] or NEW_SIGNAL()
			return sigs[name]
		end
	end
	if k == "SetAttribute" then
		return function(s, name, v)
			rawget(s, "_attrs")[name] = v
			local sigs = rawget(s, "_attrSignals")
			if sigs and sigs[name] then sigs[name]:Fire() end
		end
	end
	if k == "FireClient" then
		return function(s, player, ...) table.insert(REMOTE_LOG, { remote = s.Name, player = player, args = table.pack(...) }) end
	end
	if k == "FireAllClients" then
		return function(s, ...) table.insert(REMOTE_LOG, { remote = s.Name, player = "ALL", args = table.pack(...) }) end
	end
	if k == "Emit" or k == "AddTag" then return function() end end
	if k == "PivotTo" then
		return function(s, cf)
			local root = s:FindFirstChild("HumanoidRootPart")
			if root then root.CFrame = cf end
		end
	end
	if k == "Kick" then return function(s, msg) print("KICK", s.Name, msg) end end
	if k == "FindFirstChildOfClass" then
		return function(s, cls) for _, c in rawget(s, "_children") do if c.ClassName == cls then return c end end return nil end
	end
	local v = baseIndex(self, k)
	if v == nil and type(k) == "string" then
		return self:FindFirstChild(k) -- como en Roblox: inst.Hijo
	end
	return v
end

-- Parts' Position derived from CFrame; Rotation on CFrame
do
	local cf = CFrame.new(1, 2, 3)
	local C = getmetatable(cf)
	local idx = C.__index
	C.__index = function(self, k)
		if k == "Rotation" then return setmetatable({ p = Vector3.zero, r = self.r, u = self.u, b = self.b }, C) end
		return idx(self, k)
	end
end

-- Services
local function svc(name) return game:GetService(name) end
local RunService = svc("RunService")
rawget(RunService, "_props").IsServer = function() return true end
local TweenService = svc("TweenService")
rawget(TweenService, "_props").Create = function(_, inst, info, goals)
	local tween = Instance.new("Tween")
	rawget(tween, "_props").Play = function()
		task.delay(info[1] or 0, function()
			for k, v in goals do inst[k] = v end
			tween.Completed:Fire(Enum.PlaybackState.Completed)
		end)
	end
	return tween
end
TweenInfo = { new = function(...) return { ... } end }
local CollectionService = svc("CollectionService")
rawget(CollectionService, "_props").AddTag = function() end
rawget(CollectionService, "_props").RemoveTag = function() end
local Players = svc("Players")
local playerList = {}
rawget(Players, "_props").GetPlayers = function() return playerList end

local nextUserId = 1000
function ADD_PLAYER(name)
	nextUserId += 1
	local p = Instance.new("Player")
	p.Name = name
	p.DisplayName = name
	p.UserId = nextUserId
	table.insert(playerList, p)
	p.Parent = Players
	Players.PlayerAdded:Fire(p)
	return p
end
function SPAWN_CHARACTER(p)
	local char = Instance.new("Model")
	char.Name = p.Name
	local hum = Instance.new("Humanoid")
	hum.Health = 100
	hum.Parent = char
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(0, 5, 0)
	root.Parent = char
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.CFrame = CFrame.new(0, 7, 0)
	head.Parent = char
	char.Parent = game:GetService("Workspace")
	p.Character = char
	p.CharacterAdded:Fire(char)
	return char
end
function REMOVE_PLAYER(p)
	for i, q in playerList do if q == p then table.remove(playerList, i) break end end
	Players.PlayerRemoving:Fire(p)
	p.Parent = nil
end
function MOVE_TO(p, pos)
	local root = p.Character:FindFirstChild("HumanoidRootPart")
	root.CFrame = CFrame.new(pos)
end

-- Phase 5 additions
do
	local ws = game:GetService("Workspace")
	rawget(ws, "_props").GetServerTimeNow = function() return NOW end
	local terrain = Instance.new("Terrain")
	terrain.Name = "Terrain"
	terrain.Parent = ws
	rawget(terrain, "_props").FillBlock = function() end
end

-- Phase 7: fake DataStore with failure injection, BindToClose, IsStudio, IsDescendantOf
STORE_DATA = {}
STORE_FAIL_NEXT = 0
STORE_FAIL_ALL = false
STORE_CALLS = 0
STUDIO = false
CLOSE_FNS = {}
KICKED = {}
local function maybeFail()
	STORE_CALLS += 1
	task.wait(0.05) -- latencia
	if STORE_FAIL_ALL then error("DataStore unavailable (simulated)") end
	if STORE_FAIL_NEXT > 0 then STORE_FAIL_NEXT -= 1; error("Request failed (simulated)") end
end
local function deepcopy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in v do t[k] = deepcopy(x) end
	return t
end
local fakeStore = {
	GetAsync = function(_, key) maybeFail(); return deepcopy(STORE_DATA[key]) end,
	UpdateAsync = function(_, key, fn) maybeFail(); STORE_DATA[key] = deepcopy(fn(deepcopy(STORE_DATA[key]))); return STORE_DATA[key] end,
}
rawget(game:GetService("DataStoreService"), "_props").GetDataStore = function() return fakeStore end
rawget(game:GetService("RunService"), "_props").IsStudio = function() return STUDIO end
game.BindToClose = function(_, fn) table.insert(CLOSE_FNS, fn) end
do
	local probe = Instance.new("Folder")
	local M = getmetatable(probe)
	local idx = M.__index
	M.__index = function(self, k)
		if k == "IsDescendantOf" then
			return function(s, ancestor)
				local p = s.Parent
				while p do if p == ancestor then return true end p = p.Parent end
				return false
			end
		end
		if k == "Kick" then
			return function(s, msg) table.insert(KICKED, { s, msg }); print("KICK", s.Name, msg) end
		end
		return idx(self, k)
	end
end
local oldAdd = ADD_PLAYER
function ADD_PLAYER(name, userId)
	local p = Instance.new("Player")
	p.Name = name
	p.DisplayName = name
	p.UserId = userId or math.random(100000, 999999)
	table.insert(game:GetService("Players"):GetPlayers(), p)
	p.Parent = game:GetService("Players")
	game:GetService("Players").PlayerAdded:Fire(p)
	return p
end

-- Leaderboards: fake OrderedDataStore + name lookups
ORDERED = {}
ORDERED_FAIL = false
local function orderedStore(name)
	ORDERED[name] = ORDERED[name] or {}
	local data = ORDERED[name]
	return {
		SetAsync = function(_, key, value)
			if ORDERED_FAIL then error("OrderedDataStore unavailable (simulated)") end
			assert(type(value) == "number" and value == math.floor(value), "ordered values must be integers")
			data[key] = value
		end,
		GetSortedAsync = function(_, ascending, size)
			if ORDERED_FAIL then error("OrderedDataStore unavailable (simulated)") end
			local list = {}
			for k, v in data do table.insert(list, { key = k, value = v }) end
			table.sort(list, function(a, b) if ascending then return a.value < b.value end return a.value > b.value end)
			local page = {}
			for i = 1, math.min(size, #list) do page[i] = list[i] end
			return { GetCurrentPage = function() return page end }
		end,
	}
end
rawget(game:GetService("DataStoreService"), "_props").GetOrderedDataStore = function(_, name) return orderedStore(name) end
local playersSvc = game:GetService("Players")
rawget(playersSvc, "_props").GetNameFromUserIdAsync = function(_, id) return "User" .. id end
rawget(playersSvc, "_props").GetPlayerByUserId = function(_, id)
	for _, p in playersSvc:GetPlayers() do if p.UserId == id then return p end end
	return nil
end

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

local __loaders, __cache = {}, {}
local function __req(name) if __cache[name] == nil then __cache[name] = __loaders[name]() end return __cache[name] end
__loaders['Format'] = function()
--!strict
-- Format: ayudantes para mostrar números lindos en pantalla.

local Format = {}

-- 1234567 -> "1,234,567"
function Format.Number(n: number): string
	local whole = tostring(math.floor(n))
	local sign = ""
	if string.sub(whole, 1, 1) == "-" then
		sign = "-"
		whole = string.sub(whole, 2)
	end
	local result = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(result, 1, 1) == "," then
		result = string.sub(result, 2)
	end
	return sign .. result
end

-- Corto para números grandes: 999,999 -> "999,999"; 1440000 -> "1.44M"; 2300000000 -> "2.3B"
local SUFFIXES: { { Size: number, Letter: string } } = {
	{ Size = 1e15, Letter = "Qa" },
	{ Size = 1e12, Letter = "T" },
	{ Size = 1e9, Letter = "B" },
	{ Size = 1e6, Letter = "M" },
}
function Format.Compact(n: number): string
	for _, suffix in SUFFIXES do
		if math.abs(n) >= suffix.Size then
			-- 2 decimales sin redondear para arriba (el 1e-6 corrige errores chiquitos de los decimales: 2.3 -> 229.9999)
			local value = math.floor(n / suffix.Size * 100 + 1e-6) / 100
			local text = string.format("%.2f", value)
			text = string.gsub(text, "0+$", "")
			text = string.gsub(text, "%.$", "")
			return text .. suffix.Letter
		end
	end
	return Format.Number(n)
end

return Format

end
__loaders['Upgrades'] = function()
--!strict
-- Upgrades: la definición de cada mejora (nivel, máximo, precio y descripción).
-- La usan el servidor (para cobrar y aplicar) y el cliente (para mostrar el panel),
-- así los dos siempre muestran y cobran lo mismo. Los números salen de Config.Upgrades.

local Config = __req("Config")

-- "IncubationSpeed", "ExtraIncubator" o "WalkSpeed" (ver Upgrades.IsValid).
-- (Los pisos 2 y 3 de la torre no se compran: se abren con el renacimiento.)
export type UpgradeId = string

-- Los niveles actuales del jugador (los mismos campos que el perfil del servidor)
export type State = {
	IncubationSpeedLevel: number,
	IncubatorCount: number,
	WalkSpeedLevel: number,
}

local Upgrades = {}

-- Orden en el que aparecen en el panel
Upgrades.Order = { "IncubationSpeed", "ExtraIncubator", "WalkSpeed" } :: { UpgradeId }

Upgrades.DisplayNames = {
	IncubationSpeed = "Incubation Speed",
	ExtraIncubator = "Extra Incubator",
	WalkSpeed = "Walk Speed",
} :: { [UpgradeId]: string }

function Upgrades.IsValid(id: unknown): boolean
	return typeof(id) == "string" and Upgrades.DisplayNames[id] ~= nil
end

-- Devuelve (nivel actual, nivel máximo)
function Upgrades.GetLevel(id: UpgradeId, state: State): (number, number)
	local cfg = Config.Upgrades
	if id == "IncubationSpeed" then
		return state.IncubationSpeedLevel, #cfg.IncubationSpeed
	elseif id == "ExtraIncubator" then
		return state.IncubatorCount, cfg.MaxIncubators
	else
		return state.WalkSpeedLevel, #cfg.WalkSpeed
	end
end

-- Precio del próximo nivel, o nil si ya está al máximo
function Upgrades.GetNextCost(id: UpgradeId, state: State): number?
	local current, max = Upgrades.GetLevel(id, state)
	if current >= max then
		return nil
	end
	local cfg = Config.Upgrades
	if id == "IncubationSpeed" then
		return cfg.IncubationSpeed[current + 1].Cost
	elseif id == "ExtraIncubator" then
		return cfg.ExtraIncubatorCosts[current] -- con 1 incubadora, cuesta la 1.ª de la lista
	else
		return cfg.WalkSpeed[current + 1].Cost
	end
end

-- Texto corto que explica qué cambia (en inglés, lo ve el jugador)
function Upgrades.Describe(id: UpgradeId, state: State): string
	local cfg = Config.Upgrades
	local current, max = Upgrades.GetLevel(id, state)
	local maxed = current >= max
	if id == "IncubationSpeed" then
		local now = math.round(cfg.IncubationSpeed[current].Multiplier * 100)
		if maxed then
			return `Hatch time: {now}%`
		end
		return `Hatch time: {now}% → {math.round(cfg.IncubationSpeed[current + 1].Multiplier * 100)}%`
	elseif id == "ExtraIncubator" then
		if maxed then
			return `Incubators: {current}`
		end
		return `Incubators: {current} → {current + 1}`
	else
		if maxed then
			return `Speed: {cfg.WalkSpeed[current].Speed}`
		end
		return `Speed: {cfg.WalkSpeed[current].Speed} → {cfg.WalkSpeed[current + 1].Speed}`
	end
end

return Upgrades

end
__loaders['Remotes'] = function()
--!strict
-- Remotes: un solo lugar para crear/buscar los RemoteEvents (la forma en que servidor y cliente se hablan).
-- El servidor los crea; el cliente espera a que existan.
-- Regla de oro: todo lo que llega DEL cliente hay que validarlo en el servidor (nunca confiar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {}

local function getFolder(): Instance
	if false then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.Event(name: string): RemoteEvent
	local folder = getFolder()
	if false then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `[Remotes] {name} is not a RemoteEvent`)
	return remote
end

return Remotes

end
__loaders['Creatures'] = function()
--!strict
-- Creatures: el catálogo de mascotas que pueden salir de cada huevo.
-- Cuando sale un huevo de cierta rareza, se elige una de sus mascotas al azar (todas con la misma chance).
-- La plata por segundo NO va acá: la define la rareza en Config.Rarities.
-- Style elige la forma del modelo placeholder: "Blob", "Bunny", "Cat", "Bird" o "Dragon".

local Config = __req("Config")

export type Style = "Blob" | "Bunny" | "Cat" | "Bird" | "Dragon"

export type Creature = {
	Id: string, -- identificador interno (no cambiar una vez que haya datos guardados)
	DisplayName: string,
	RarityId: string,
	Color: Color3,
	Style: Style,
}

local Creatures = {}

Creatures.List = {
	-- Common
	{ Id = "SandBunny", DisplayName = "Sand Bunny", RarityId = "Common", Color = Color3.fromRGB(235, 205, 150), Style = "Bunny" },
	{ Id = "PuddleBlob", DisplayName = "Puddle Blob", RarityId = "Common", Color = Color3.fromRGB(150, 210, 255), Style = "Blob" },
	{ Id = "BeachChick", DisplayName = "Beach Chick", RarityId = "Common", Color = Color3.fromRGB(255, 230, 90), Style = "Bird" },
	-- Rare
	{ Id = "CoralCat", DisplayName = "Coral Cat", RarityId = "Rare", Color = Color3.fromRGB(255, 120, 110), Style = "Cat" },
	{ Id = "WaveBunny", DisplayName = "Wave Bunny", RarityId = "Rare", Color = Color3.fromRGB(70, 140, 255), Style = "Bunny" },
	{ Id = "BubbleBlob", DisplayName = "Bubble Blob", RarityId = "Rare", Color = Color3.fromRGB(90, 230, 220), Style = "Blob" },
	-- Epic
	{ Id = "StormOwl", DisplayName = "Storm Owl", RarityId = "Epic", Color = Color3.fromRGB(150, 90, 230), Style = "Bird" },
	{ Id = "ThunderCat", DisplayName = "Thunder Cat", RarityId = "Epic", Color = Color3.fromRGB(110, 80, 200), Style = "Cat" },
	{ Id = "MistDragon", DisplayName = "Mist Dragon", RarityId = "Epic", Color = Color3.fromRGB(200, 170, 255), Style = "Dragon" },
	-- Legendary
	{ Id = "GoldenDragon", DisplayName = "Golden Dragon", RarityId = "Legendary", Color = Color3.fromRGB(255, 200, 40), Style = "Dragon" },
	{ Id = "SunPhoenix", DisplayName = "Sun Phoenix", RarityId = "Legendary", Color = Color3.fromRGB(255, 120, 30), Style = "Bird" },
	-- Mythic
	{ Id = "MagmaSerpent", DisplayName = "Magma Serpent", RarityId = "Mythic", Color = Color3.fromRGB(230, 70, 40), Style = "Dragon" },
	{ Id = "TikiGolem", DisplayName = "Tiki Golem", RarityId = "Mythic", Color = Color3.fromRGB(160, 82, 45), Style = "Blob" },
	-- Secret
	{ Id = "RainbowLeviathan", DisplayName = "Rainbow Leviathan", RarityId = "Secret", Color = Color3.fromRGB(25, 25, 35), Style = "Dragon" },
	{ Id = "VoidCat", DisplayName = "Void Cat", RarityId = "Secret", Color = Color3.fromRGB(15, 10, 25), Style = "Cat" },
} :: { Creature }

local byId: { [string]: Creature } = {}
for _, creature in Creatures.List do
	byId[creature.Id] = creature
end

function Creatures.Get(id: string): Creature?
	return byId[id]
end

function Creatures.ForRarity(rarityId: string): { Creature }
	local result = {}
	for _, creature in Creatures.List do
		if creature.RarityId == rarityId then
			table.insert(result, creature)
		end
	end
	return result
end

-- Cuánta plata por segundo dan, en total, estas mascotas (lista como la del perfil del jugador).
-- Lo usan el cobro normal (CreatureService) y la ganancia mientras no estás (PlayerDataService).
-- La variante (Silver, Golden...) multiplica lo que da cada una.
function Creatures.TotalIncome(list: { { CreatureId: string, Slot: number, Variant: string } }): number
	local total = 0
	for _, entry in list do
		local creature = byId[entry.CreatureId]
		local rarity = creature and Config.GetRarity(creature.RarityId)
		if rarity then
			total += Config.GetIncome(rarity, Config.GetVariant(entry.Variant))
		end
	end
	return total
end

return Creatures

end
__loaders['Config'] = function()
--!strict
-- Config: TODOS los números de balance del juego viven acá.
-- Si querés ajustar tiempos, precios o probabilidades, cambiá este archivo y nada más.
-- Está en ReplicatedStorage para que el cliente también pueda leerlo (por ejemplo, para mostrar precios),
-- pero el servidor es el único que decide: el cliente solo lo usa para dibujar la interfaz.

export type Rarity = {
	Id: string, -- identificador interno (no cambiar una vez que haya datos guardados)
	DisplayName: string, -- texto que ve el jugador
	Color: Color3,
	BaseIncubationTime: number, -- segundos, antes de aplicar mejoras
	CoinsPerSecond: number, -- plata que genera la criatura que sale de este huevo
}

-- Variantes: un huevo puede ser además Silver, Golden, Emerald... La mascota sale de ese material y gana más.
export type Variant = {
	Id: string, -- identificador interno (no cambiar una vez que haya datos guardados)
	DisplayName: string, -- adjetivo que va antes del nombre: "Golden Rare Egg", "Golden Sun Phoenix"
	Color: Color3,
	Material: Enum.Material,
	Multiplier: number, -- multiplica la plata por segundo (y el precio de venta)
	Weight: number, -- probabilidad relativa
}

-- Zonas del cañón: cada una da huevos de SU rareza (o, con poca chance, de la siguiente).
export type Zone = {
	Id: string,
	DisplayName: string, -- texto del cartel
	RarityId: string, -- rareza de la zona
	NextRarityId: string?, -- la siguiente rareza (nil = no hay)
	NextChance: number, -- chance de que salga la siguiente (0.1 = 10%)
	Color: Color3, -- color del piso
	Material: Enum.Material,
	SpawnCount: number, -- cuántos puntos de aparición tiene
	MaxActive: number, -- cuántos huevos puede haber a la vez
	Respawn: number, -- cada cuántos segundos aparece uno nuevo (si hay lugar)
}

-- Cuevas-refugio en las paredes del cañón. Side: -1 = pared norte (Z-), 1 = pared sur (Z+).
export type Cave = {
	X: number, -- centro de la cueva a lo largo del cañón
	Side: number,
	Vip: boolean?,
}

export type EventInfo = {
	Id: string,
	DisplayName: string,
	Description: string,
	Color: Color3,
	Weight: number, -- probabilidad relativa entre eventos
}

export type WaveKind = {
	Speed: number, -- studs por segundo
	Warning: number, -- segundos de aviso antes de que salga
	Height: number, -- alto de la pared de agua
}

export type IncubationSpeedLevel = {
	Multiplier: number, -- 1 = 100% del tiempo, 0.25 = 25% del tiempo
	Cost: number,
}

export type WalkSpeedLevel = {
	Speed: number,
	Cost: number,
}

local Config = {}

-- ===== Servidor =====
-- OJO: el límite real de jugadores se pone en Game Settings (ver README). Esto es solo para el código.
Config.MaxPlayers = 8

-- ===== Mapa: isla tropical + volcán (ver MAPA_SPEC.md) =====
-- Origen (0, 0, 0) = centro del Altar del volcán. El piso de todo el mapa está en Y = 0.
-- +X = hacia el cañón y el volcán (este). La ola viaja en dirección -X. -Z = norte (bases 1-4), +Z = sur (bases 5-8).
Config.Map = {
	FloorY = 0,

	-- Lobby (isla de arena)
	LobbySize = Vector2.new(300, 340), -- X × Z
	TerraceZ = 145, -- centro de las terrazas de pasto (norte y sur)
	TerraceDepth = 50,
	ShoreWidth = 8,
	SpawnPosition = Vector3.new(0, 2.5, 22), -- al lado del altar: ahí aparecen los jugadores

	-- Cañón (de X = CanyonStartX a CanyonStartX + CanyonLength)
	CanyonStartX = 150,
	CanyonLength = 1200,
	CanyonWidth = 80, -- de Z = -40 a 40
	CanyonWallThickness = 20,
	CanyonWallHeight = 40,
	SpawnWallMargin = 6, -- los puntos de huevos quedan a esta distancia de las paredes (y de las cuevas)

	-- Bases (8, mirando al centro del lobby)
	PlotSize = Vector2.new(60, 44), -- X × Z
	BasePositions = {
		Vector3.new(-117, 0, -148),
		Vector3.new(-39, 0, -148),
		Vector3.new(39, 0, -148),
		Vector3.new(117, 0, -148),
		Vector3.new(-117, 0, 148),
		Vector3.new(-39, 0, 148),
		Vector3.new(39, 0, 148),
		Vector3.new(117, 0, 148),
	},
	BaseFloors = 3, -- pisos de la torre
	ShelvesPerFloor = 5, -- estantes (lugares para mascotas) por piso

	-- Volcán (en el mar, detrás del final del cañón)
	VolcanoPosition = Vector3.new(1550, 0, 0),
	VolcanoBaseDiameter = 260,
	VolcanoHeight = 220,
}

-- Paleta y materiales: usar SIEMPRE estos para que todo combine
Config.Palette = {
	LobbySand = Color3.fromRGB(246, 221, 176),
	TerraceGrass = Color3.fromRGB(108, 194, 74),
	PlotGrass = Color3.fromRGB(93, 179, 61),
	Wood = Color3.fromRGB(139, 90, 43),
	DarkWood = Color3.fromRGB(74, 44, 18),
	Bamboo = Color3.fromRGB(201, 162, 74),
	Straw = Color3.fromRGB(217, 164, 65),
	Jungle = Color3.fromRGB(47, 138, 60),
	WallRock = Color3.fromRGB(122, 110, 98),
	WetSand = Color3.fromRGB(242, 212, 155),
	Lava = Color3.fromRGB(255, 106, 26),
	Crystal = Color3.fromRGB(163, 91, 255),
	Stone = Color3.fromRGB(142, 133, 122),
	TorchLight = Color3.fromRGB(255, 138, 31),
	Water = Color3.fromRGB(22, 147, 181),
}

-- Iluminación (la propiedad Technology = Future se pone en default.project.json porque un script no puede cambiarla)
Config.Lighting = {
	ClockTime = 14.5,
	Brightness = 2.5,
	Ambient = Color3.fromRGB(90, 80, 70),
	OutdoorAmbient = Color3.fromRGB(150, 140, 130),
	AtmosphereDensity = 0.3,
	AtmosphereHaze = 1,
	AtmosphereGlare = 0.2,
	AtmosphereColor = Color3.fromRGB(199, 232, 240),
	AtmosphereDecay = Color3.fromRGB(106, 112, 125),
	BloomIntensity = 0.6,
	BloomSize = 24,
	BloomThreshold = 1.5,
	Saturation = 0.15,
	Contrast = 0.05,
	Tint = Color3.fromRGB(255, 245, 230),
	SunRaysIntensity = 0.08,
	SunRaysSpread = 1,
	WaterColor = Color3.fromRGB(22, 147, 181),
	WaterTransparency = 0.6,
	WaterWaveSize = 0.15,
	WaterWaveSpeed = 8,
}

-- ===== Huevos =====
Config.Rarities = {
	{ Id = "Common", DisplayName = "Common", Color = Color3.fromRGB(244, 244, 244), BaseIncubationTime = 30, CoinsPerSecond = 1 },
	{ Id = "Rare", DisplayName = "Rare", Color = Color3.fromRGB(96, 165, 250), BaseIncubationTime = 60, CoinsPerSecond = 5 },
	{ Id = "Epic", DisplayName = "Epic", Color = Color3.fromRGB(167, 139, 250), BaseIncubationTime = 180, CoinsPerSecond = 25 },
	{ Id = "Legendary", DisplayName = "Legendary", Color = Color3.fromRGB(252, 211, 77), BaseIncubationTime = 480, CoinsPerSecond = 120 },
	{ Id = "Mythic", DisplayName = "Mythic", Color = Color3.fromRGB(248, 113, 113), BaseIncubationTime = 1200, CoinsPerSecond = 600 },
	-- Secret: negro; el brillo blanco/arcoíris se agrega con efectos
	{ Id = "Secret", DisplayName = "Secret", Color = Color3.fromRGB(17, 24, 39), BaseIncubationTime = 2700, CoinsPerSecond = 3000 },
} :: { Rarity }

-- Las 6 zonas del cañón, en orden desde el portal hasta el fondo (cada una mide ZoneLength).
Config.ZoneLength = 200
Config.Zones = {
	{ Id = "Beach", DisplayName = "BEACH", RarityId = "Common", NextRarityId = "Rare", NextChance = 0.1, Color = Color3.fromRGB(242, 212, 155), Material = Enum.Material.Sand, SpawnCount = 16, MaxActive = 8, Respawn = 10 },
	{ Id = "Jungle", DisplayName = "JUNGLE", RarityId = "Rare", NextRarityId = "Epic", NextChance = 0.1, Color = Color3.fromRGB(124, 196, 107), Material = Enum.Material.Grass, SpawnCount = 14, MaxActive = 6, Respawn = 15 },
	{ Id = "Rocks", DisplayName = "ROCKS", RarityId = "Epic", NextRarityId = "Legendary", NextChance = 0.1, Color = Color3.fromRGB(171, 162, 148), Material = Enum.Material.Slate, SpawnCount = 12, MaxActive = 5, Respawn = 20 },
	{ Id = "Basalt", DisplayName = "BASALT", RarityId = "Legendary", NextRarityId = "Mythic", NextChance = 0.1, Color = Color3.fromRGB(110, 104, 99), Material = Enum.Material.Basalt, SpawnCount = 10, MaxActive = 4, Respawn = 30 },
	{ Id = "CooledLava", DisplayName = "COOLED LAVA", RarityId = "Mythic", NextRarityId = "Secret", NextChance = 0.1, Color = Color3.fromRGB(74, 56, 51), Material = Enum.Material.CrackedLava, SpawnCount = 8, MaxActive = 3, Respawn = 45 },
	{ Id = "Obsidian", DisplayName = "OBSIDIAN", RarityId = "Secret", NextRarityId = nil, NextChance = 0, Color = Color3.fromRGB(38, 31, 51), Material = Enum.Material.Slate, SpawnCount = 6, MaxActive = 1, Respawn = 90 },
} :: { Zone }

-- Cuevas-refugio: más separadas a medida que avanzás. La VIP es más ancha y solo entra quien tiene el pase.
Config.CaveSize = Vector3.new(12, 12, 10) -- ancho (X) × alto × profundidad
Config.VipCaveWidth = 20
Config.Caves = {
	{ X = 200, Side = -1 },
	{ X = 260, Side = 1 },
	{ X = 320, Side = -1 },
	{ X = 400, Side = 1 },
	{ X = 480, Side = -1, Vip = true },
	{ X = 560, Side = 1 },
	{ X = 660, Side = -1 },
	{ X = 760, Side = 1 },
	{ X = 880, Side = -1 },
	{ X = 1000, Side = 1 },
	{ X = 1150, Side = -1 },
	{ X = 1300, Side = 1 },
} :: { Cave }

Config.Eggs = {
	Size = Vector3.new(2.5, 3.2, 2.5),
	SpawnMinDistance = 15, -- distancia mínima entre puntos de aparición
	FallHeight = 150, -- desde qué altura caen los meteoritos
	GrabHoldTime = 0.3, -- cuánto hay que mantener apretada la tecla para agarrar
	GrabDistance = 10, -- distancia máxima para agarrar (studs)
	GrabCooldown = 0.5, -- tiempo mínimo entre intentos de agarrar (anti-spam)
}

-- ===== Variantes de huevo =====
-- Normal es la más común. Las demás cambian el material de la mascota y multiplican su plata.
Config.Variants = {
	{ Id = "Normal", DisplayName = "", Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, Multiplier = 1, Weight = 85 },
	{ Id = "Silver", DisplayName = "Silver", Color = Color3.fromRGB(215, 220, 230), Material = Enum.Material.Foil, Multiplier = 2, Weight = 8 },
	{ Id = "Golden", DisplayName = "Golden", Color = Color3.fromRGB(255, 200, 50), Material = Enum.Material.Foil, Multiplier = 3, Weight = 4 },
	{ Id = "Emerald", DisplayName = "Emerald", Color = Color3.fromRGB(40, 210, 110), Material = Enum.Material.Glass, Multiplier = 5, Weight = 2 },
	{ Id = "Diamond", DisplayName = "Diamond", Color = Color3.fromRGB(150, 235, 255), Material = Enum.Material.Glass, Multiplier = 10, Weight = 0.8 },
	{ Id = "Rainbow", DisplayName = "Rainbow", Color = Color3.fromRGB(255, 120, 220), Material = Enum.Material.ForceField, Multiplier = 25, Weight = 0.2 },
} :: { Variant }

-- ===== Eventos =====
-- Cada Interval segundos hay Chance de que empiece un evento, que dura Duration segundos.
Config.Events = {
	Interval = 240,
	Chance = 0.5,
	Duration = 120,
	List = {
		{ Id = "GoldenRain", DisplayName = "GOLDEN RAIN", Description = "Egg rain! Way more Silver, Golden and Emerald eggs!", Color = Color3.fromRGB(255, 205, 60), Weight = 30 },
		{ Id = "LuckyStorm", DisplayName = "LUCKY STORM", Description = "Every zone gives its better eggs 3x more often!", Color = Color3.fromRGB(110, 255, 140), Weight = 30 },
		{ Id = "DoubleCoins", DisplayName = "DOUBLE COINS", Description = "All creatures make 2x coins!", Color = Color3.fromRGB(255, 160, 60), Weight = 25 },
		{ Id = "MeteorShower", DisplayName = "METEOR SHOWER", Description = "Meteors drop Epic or better eggs in the canyon!", Color = Color3.fromRGB(255, 90, 60), Weight = 15 },
	} :: { EventInfo },
	GoldenRainVariantBoost = 6, -- en Golden Rain, la chance de cada variante (no Normal) se multiplica por esto
	GoldenRainRespawnMultiplier = 0.5, -- ...y los huevos reaparecen el doble de rápido
	LuckyNextChanceMultiplier = 3, -- en Lucky Storm, la chance de la rareza siguiente de cada zona se multiplica por esto
	DoubleCoinsMultiplier = 2,
	MeteorInterval = 10, -- segundos entre meteoritos (en Meteor Shower)
	MeteorRarityWeights = { Epic = 55, Legendary = 30, Mythic = 12, Secret = 3 } :: { [string]: number },
}

-- ===== Olas (salen del volcán y barren el cañón hacia el lobby) =====
Config.Waves = {
	StartX = 1360, -- donde arranca la ola
	EndX = 150, -- el portal: la ola nunca entra al lobby
	Thickness = 6,
	Width = 84,
	MinInterval = 60, -- segundos entre una ola y el aviso de la siguiente (al azar entre Min y Max)
	MaxInterval = 90,
	Normal = { Speed = 60, Warning = 5, Height = 50 } :: WaveKind,
	FastChance = 0.25, -- 1 de cada 4 olas es rápida
	Fast = { Speed = 120, Warning = 3, Height = 50 } :: WaveKind,
	SuperInterval = 1800, -- Súper tsunami cada 30 minutos
	Super = { Speed = 90, Warning = 15, Height = 80 } :: WaveKind,
	FadeTime = 1.5, -- segundos que tarda en desvanecerse al llegar al portal
	-- Sonidos (podés cambiarlos por IDs de la Creator Store, ej: "rbxassetid://1234567"; "" = sin sonido)
	WarningSoundId = "rbxasset://sounds/electronicpingshort.wav", -- cuerno de caracol
	WaveSoundId = "", -- rugido de la ola
}

-- ===== Incubadoras y plata =====
Config.Incubators = {
	HoldTime = 0.5, -- cuánto mantener apretada la tecla para poner el huevo / abrirlo
	Distance = 10, -- distancia máxima para usar la incubadora (studs)
	Cooldown = 0.5, -- tiempo mínimo entre intentos (anti-spam)
}

Config.Economy = {
	StartingCoins = 0,
	IncomeInterval = 1, -- cada cuántos segundos se cobra la plata de las mascotas

	-- Vender mascotas (mantener E sobre una mascota tuya)
	SellValueSeconds = 60, -- precio de venta = esta cantidad de segundos de lo que genera (Common 60, Legendary 7.200...)
	SellHoldTime = 1.5, -- segundos que hay que mantener la tecla para vender (así no se vende sin querer)
	SellHoldTimeRare = 3, -- lo mismo, para Legendary o mejores y variantes Emerald o mejores
	SellDistance = 12, -- distancia máxima
	SellCooldown = 0.5, -- tiempo mínimo entre ventas (anti-spam)

	-- Ganancia mientras no estás: al volver, tus mascotas te pagan por el tiempo que estuviste afuera
	OfflineRate = 0.5, -- qué parte de lo normal (0.5 = la mitad)
	OfflineMaxHours = 8, -- tope de horas que se cuentan
	OfflineMinSeconds = 60, -- si estuviste afuera menos que esto, no cuenta (así no sale el cartel cada vez que reentrás)
}

-- ===== Guardado =====
Config.Data = {
	-- Nombre del DataStore. Si lo cambiás, todos empiezan de cero (los datos viejos quedan en el nombre anterior).
	StoreName = "EggStorm_PlayerData_v1",
	AutosaveInterval = 60, -- cada cuántos segundos se guarda a todos los que están jugando
	MaxAttempts = 4, -- cuántas veces se reintenta si Roblox falla al leer o guardar
	RetryDelay = 1, -- segundos de espera entre reintentos (va creciendo: 1, 2, 3...)
}

-- ===== Tabla de récords =====
Config.Leaderboard = {
	Size = 10, -- cuántos puestos muestra cada tablero
	UpdateInterval = 120, -- cada cuántos segundos se actualizan (Roblox limita cuántas veces se puede leer/escribir)
	FirstUpdateDelay = 10, -- la primera actualización, unos segundos después de que arranca el servidor
	-- Nombres de los OrderedDataStore (si los cambiás, las tablas empiezan de cero)
	EarnersStoreName = "EggStorm_TopEarners_v1",
	HatchedStoreName = "EggStorm_EggsHatched_v1",
}

-- ===== Efectos e interfaz =====
Config.Effects = {
	HatchAnimationTime = 3, -- segundos que el huevo tiembla y brilla antes de abrirse
	RevealDuration = 3, -- segundos que queda el cartel "You got..." (los Legendary o mejores, uno más)
	-- Sonidos (podés cambiarlos por IDs de la Creator Store, ej: "rbxassetid://1234567"; "" = sin sonido)
	HatchSoundId = "rbxasset://sounds/electronicpingshort.wav",
}

-- ===== Mejoras (se compran en la Tienda de mejoras del lobby) =====
Config.Upgrades = {
	PanelDistance = 14, -- distancia máxima al mostrador de la tienda para poder comprar (studs)
	BuyCooldown = 0.3, -- tiempo mínimo entre compras (anti-spam)

	-- Multiplica el tiempo de incubación
	IncubationSpeed = {
		{ Multiplier = 1.0, Cost = 0 }, -- nivel 1 (gratis, es el inicial)
		{ Multiplier = 0.8, Cost = 100 },
		{ Multiplier = 0.6, Cost = 500 },
		{ Multiplier = 0.4, Cost = 2000 },
		{ Multiplier = 0.25, Cost = 10000 },
	} :: { IncubationSpeedLevel },
	MinIncubationTime = 5, -- segundos: ningún huevo tarda menos que esto

	-- Incubadoras extra (los 3 nidos están siempre adelante de la base; los que no compraste dicen LOCKED)
	StartingIncubators = 1,
	MaxIncubators = 3,
	ExtraIncubatorCosts = { 250, 1500 }, -- precio de la 2.ª y de la 3.ª incubadora

	-- Velocidad de caminata (el nivel 1 es la velocidad normal de Roblox)
	WalkSpeed = {
		{ Speed = 16, Cost = 0 },
		{ Speed = 20, Cost = 300 },
		{ Speed = 24, Cost = 1500 },
		{ Speed = 28, Cost = 6000 },
	} :: { WalkSpeedLevel },
}

-- ===== Renacimiento =====
-- Renacer reinicia la plata y las mejoras de velocidad (Incubation Speed y Walk Speed).
-- Se conservan las mascotas, los huevos y las incubadoras. A cambio:
--   - el 1.º renacimiento abre el piso 2 de la torre y el 2.º el piso 3
--   - cada renacimiento suma IncomeBonus a la plata de TODAS tus mascotas (para siempre)
Config.Rebirth = {
	Costs = { 100000, 1000000, 5000000, 25000000, 100000000 }, -- precio de cada renacimiento (la cantidad = el máximo)
	IncomeBonus = 0.25, -- +25% de plata por renacimiento
	Cooldown = 1, -- anti-spam
}

-- ===== Comerciante misterioso =====
-- Cada RestockInterval segundos trae OfferCount huevos nuevos (los mismos para todo el servidor).
-- Cada jugador puede comprar cada oferta una vez por tanda. El huevo va directo a un nido libre de su base.
Config.Merchant = {
	RestockInterval = 600,
	OfferCount = 3,
	PriceSeconds = 600, -- precio = la plata por segundo que daría su mascota × esta cantidad de segundos
	RarityWeights = { Rare = 40, Epic = 30, Legendary = 18, Mythic = 9, Secret = 3 } :: { [string]: number },
	VariantChance = 0.35, -- chance de que una oferta venga con variante (Silver, Golden...)
	Distance = 14, -- distancia máxima al mostrador para comprar
	Cooldown = 0.5,
}

-- ===== Intercambio entre jugadores =====
Config.Trade = {
	MaxItems = 4, -- cuántas mascotas puede ofrecer cada uno en un intercambio
	RequestTimeout = 30, -- segundos que dura una invitación sin responder
	RequestCooldown = 5, -- segundos entre invitaciones a la misma persona (anti-spam)
	CountdownTime = 3, -- cuenta regresiva cuando los dos aprietan "Ready" (si alguien cambia algo, se cancela)
	Distance = 14, -- distancia máxima al puesto de Intercambio para mandar una invitación
	Cooldown = 0.2, -- anti-spam de los botones
}

-- ===== Ayudantes =====
local raritiesById: { [string]: Rarity } = {}
for _, rarity in Config.Rarities do
	raritiesById[rarity.Id] = rarity
end

function Config.GetRarity(id: string): Rarity?
	return raritiesById[id]
end

-- Posición de la rareza en la lista (Common = 1 ... Secret = 6). Sirve para comparar "Legendary o mejor".
function Config.RarityRank(id: string): number
	for i, rarity in Config.Rarities do
		if rarity.Id == id then
			return i
		end
	end
	return 0
end

local variantsById: { [string]: Variant } = {}
for _, variant in Config.Variants do
	variantsById[variant.Id] = variant
end

-- La variante con ese Id (si no existe, Normal).
function Config.GetVariant(id: string?): Variant
	return (id and variantsById[id]) or Config.Variants[1]
end

local eventsById: { [string]: EventInfo } = {}
for _, event in Config.Events.List do
	eventsById[event.Id] = event
end

function Config.GetEvent(id: string?): EventInfo?
	return if id then eventsById[id] else nil
end

-- Desde qué X hasta qué X va la zona número index (1 = Playa ... 6 = Obsidiana).
function Config.ZoneRange(index: number): (number, number)
	local startX = Config.Map.CanyonStartX + (index - 1) * Config.ZoneLength
	return startX, startX + Config.ZoneLength
end

-- En qué zona está esta X del cañón (nil si está fuera del cañón).
function Config.ZoneAt(x: number): (Zone?, number?)
	for i, zone in Config.Zones do
		local startX, endX = Config.ZoneRange(i)
		if x >= startX and x < endX then
			return zone, i
		end
	end
	return nil, nil
end

-- Ancho de una cueva (la VIP es más ancha)
function Config.CaveWidth(cave: Cave): number
	return if cave.Vip then Config.VipCaveWidth else Config.CaveSize.X
end

-- Multiplicador de plata por los renacimientos (1 renacimiento = x1.25)
function Config.RebirthMultiplier(rebirths: number): number
	return 1 + Config.Rebirth.IncomeBonus * rebirths
end

-- Cuántos pisos de la torre abre esa cantidad de renacimientos (1 piso sin renacer)
function Config.FloorsForRebirths(rebirths: number): number
	return math.min(Config.Map.BaseFloors, 1 + rebirths)
end

-- Plata por segundo de una mascota de esta rareza y variante.
function Config.GetIncome(rarity: Rarity, variant: Variant?): number
	return rarity.CoinsPerSecond * (if variant then variant.Multiplier else 1)
end

-- Cuánto pagan por vender una mascota de esta rareza (y variante).
function Config.GetSellPrice(rarity: Rarity, variant: Variant?): number
	return Config.GetIncome(rarity, variant) * Config.Economy.SellValueSeconds
end

-- Nombre con la variante adelante: ("Golden", "Rare Egg") -> "Golden Rare Egg"; Normal no agrega nada.
function Config.WithVariant(variant: Variant, name: string): string
	return if variant.DisplayName ~= "" then `{variant.DisplayName} {name}` else name
end

-- Segundos que tarda un huevo de esta rareza con el nivel de "Incubation Speed" dado (con el mínimo aplicado).
function Config.GetIncubationTime(rarity: Rarity, speedLevel: number): number
	local levels = Config.Upgrades.IncubationSpeed
	local level = levels[math.clamp(speedLevel, 1, #levels)]
	return math.max(Config.Upgrades.MinIncubationTime, rarity.BaseIncubationTime * level.Multiplier)
end

return Config

end
__loaders['SellPrompts'] = function()
--!strict
-- SellPrompts: el botón "Sell" de cada mascota solo lo ve su dueño.
-- (Es para no llenar la pantalla de botones en bases ajenas: el servidor igual valida cada venta.)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local SellPrompts = {}

local function setup(prompt: Instance)
	if prompt:IsA("ProximityPrompt") then
		prompt.Enabled = prompt:GetAttribute("OwnerUserId") == player.UserId
	end
end

function SellPrompts.Start()
	for _, prompt in CollectionService:GetTagged("SellPrompt") do
		setup(prompt)
	end
	CollectionService:GetInstanceAddedSignal("SellPrompt"):Connect(setup)
end

return SellPrompts

end
__loaders['WelcomeBack'] = function()
--!strict
-- WelcomeBack: el cartel "Welcome back!" que muestra cuánto ganaron tus mascotas mientras no estabas.
-- La plata ya la sumó el servidor al cargar tus datos (ver PlayerDataService); este cartel solo lo cuenta.
-- Lee los atributos del jugador "OfflineCoins" y "OfflineSeconds".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = __req("Config")
local Format = __req("Format")
local UIKit = __req("UIKit")

local player = Players.LocalPlayer
local C = UIKit.Colors

local WelcomeBack = {}

local WIDTH, HEIGHT = 500, 300
local shown = false

-- 8100 segundos -> "2h 15m"
local function formatDuration(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local hours = minutes // 60
	minutes = minutes % 60
	if hours > 0 and minutes > 0 then
		return `{hours}h {minutes}m`
	elseif hours > 0 then
		return `{hours}h`
	end
	return `{math.max(1, minutes)}m`
end

local function show(coins: number, seconds: number)
	if shown then
		return
	end
	shown = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "WelcomeBack"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.45)
	frame.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	frame.BackgroundColor3 = C.Panel
	frame.Parent = gui
	UIKit.Corner(frame, 22)
	UIKit.Stroke(frame, 4, C.Gold)
	UIKit.FitToScreen(frame, Vector2.new(WIDTH, HEIGHT))

	local function centered(text: string, y: number, height: number, size: number, color: Color3): TextLabel
		local label = UIKit.Label(frame, text, UDim2.fromOffset(WIDTH - 40, height), UDim2.fromOffset(20, y), size, color)
		label.TextXAlignment = Enum.TextXAlignment.Center
		return label
	end
	centered("Welcome back!", 22, 46, 38, C.Accent)
	centered("While you were away, your creatures made", 76, 28, 20, C.SubText)
	local amount = centered(`🪙 +{Format.Number(coins)}`, 108, 64, 52, C.Gold)
	UIKit.Stroke(amount, 3)
	local percent = math.round(Config.Economy.OfflineRate * 100)
	centered(`Away for {formatDuration(seconds)} · {percent}% speed · max {Config.Economy.OfflineMaxHours}h`, 176, 26, 17, C.SubText)

	local button = UIKit.Button(frame, "Collect!", UDim2.fromOffset(200, 56), UDim2.fromOffset((WIDTH - 200) / 2, 218), 26, C.Green)

	-- Entra con un "pop"
	local pop = frame:FindFirstChildOfClass("UIScale")
	local fit = if pop then pop.Scale else 1
	if pop then
		pop.Scale = 0
		TweenService:Create(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
	end

	button.Activated:Connect(function()
		gui:Destroy()
	end)
end

local function check()
	local coins = player:GetAttribute("OfflineCoins")
	local seconds = player:GetAttribute("OfflineSeconds")
	if typeof(coins) == "number" and coins > 0 and typeof(seconds) == "number" then
		show(coins, seconds)
	end
end

function WelcomeBack.Start()
	player:GetAttributeChangedSignal("OfflineCoins"):Connect(check)
	check()
end

return WelcomeBack

end
__loaders['Main.client'] = function()
--!strict
-- Punto de entrada del cliente.
-- (El cliente nunca decide nada importante: solo muestra lo que el servidor le dice.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = __req("Remotes")
local Notifier = __req("Notifier")
local IncubatorPrompts = __req("IncubatorPrompts")
local SellPrompts = __req("SellPrompts")
local UpgradePanel = __req("UpgradePanel")
local WaveClient = __req("WaveClient")
local EggAnimator = __req("EggAnimator")
local RebirthPanel = __req("RebirthPanel")
local MerchantPanel = __req("MerchantPanel")
local TradePanel = __req("TradePanel")
local Hud = __req("Hud")
local HatchReveal = __req("HatchReveal")
local Tutorial = __req("Tutorial")
local WelcomeBack = __req("WelcomeBack")
local EventBoard = __req("EventBoard")

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
WaveClient.Start()
EggAnimator.Start()
RebirthPanel.Start()
MerchantPanel.Start()
TradePanel.Start()
Hud.Start()
HatchReveal.Start()
Tutorial.Start()
WelcomeBack.Start()
EventBoard.Start()

end
__loaders['UIKit'] = function()
--!strict
-- UIKit: ayudantes para armar la interfaz con el mismo estilo en todos lados
-- (colores, letra, bordes redondeados, contornos) y para que las ventanas entren en cualquier pantalla.

local Workspace = game:GetService("Workspace")

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne

UIKit.Colors = {
	Panel = Color3.fromRGB(32, 34, 52),
	Row = Color3.fromRGB(48, 52, 76),
	Text = Color3.new(1, 1, 1),
	SubText = Color3.fromRGB(190, 195, 220),
	Gold = Color3.fromRGB(255, 215, 70),
	Green = Color3.fromRGB(70, 205, 95),
	Red = Color3.fromRGB(215, 75, 75),
	Gray = Color3.fromRGB(110, 112, 128),
	Accent = Color3.fromRGB(255, 205, 60),
}

UIKit.Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 255, 100)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 80, 255)),
})

function UIKit.Corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = parent
end

function UIKit.Stroke(parent: Instance, thickness: number, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = color or Color3.new(0, 0, 0)
	stroke.Parent = parent
	return stroke
end

-- Texto con tamaño de letra FIJO (no se aplasta ni se agranda solo).
-- Con UIScale toda la ventana se achica junta, así las proporciones nunca se rompen.
function UIKit.Label(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = UIKit.Font
	label.TextSize = textSize
	label.TextColor3 = color or UIKit.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.Parent = parent
	return label
end

function UIKit.Button(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.Font = UIKit.Font
	button.TextSize = textSize
	button.TextColor3 = UIKit.Colors.Text
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent
	UIKit.Corner(button, 10)
	UIKit.Stroke(button, 2, Color3.fromRGB(20, 20, 30)).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return button
end

-- Le pone un UIScale al frame para que una ventana de tamaño fijo (designSize, en píxeles)
-- entre siempre en la pantalla: en pantallas chicas se achica entera, sin deformarse.
function UIKit.FitToScreen(frame: GuiObject, designSize: Vector2, margin: Vector2?)
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local extra = margin or Vector2.new(32, 120)
	local function update()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		scale.Scale = math.min(1, (viewport.X - extra.X) / designSize.X, (viewport.Y - extra.Y) / designSize.Y)
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

-- Ventana centrada con título, borde dorado y botón X (se achica sola en pantallas chicas).
-- Devuelve el ScreenGui (empieza cerrado), el marco y el botón de cerrar.
function UIKit.Window(name: string, title: string, size: Vector2, displayOrder: number?): (ScreenGui, Frame, TextButton)
	local Players = game:GetService("Players")
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = displayOrder or 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = UIKit.Colors.Panel
	frame.Parent = gui
	UIKit.Corner(frame, 20)
	UIKit.Stroke(frame, 4, UIKit.Colors.Accent)
	UIKit.FitToScreen(frame, size)

	UIKit.Label(frame, title, UDim2.fromOffset(size.X - 120, 50), UDim2.fromOffset(28, 18), 36, UIKit.Colors.Accent)
	local closeButton = UIKit.Button(frame, "X", UDim2.fromOffset(52, 52), UDim2.fromOffset(size.X - 70, 17), 28, UIKit.Colors.Red)
	closeButton.Activated:Connect(function()
		gui.Enabled = false
	end)
	return gui, frame, closeButton
end

return UIKit

end
__loaders['RebirthPanel'] = function()
--!strict
-- RebirthPanel: la ventana de renacimiento (se abre con el botón "Rebirth" del costado).
-- Muestra qué ganás, qué perdés y qué conservás, y el botón para renacer.
-- El botón solo PIDE renacer: el servidor decide si se puede (ver RebirthService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = __req("Config")
local Format = __req("Format")
local Remotes = __req("Remotes")
local UIKit = __req("UIKit")
local SideMenu = __req("SideMenu")

local player = Players.LocalPlayer
local rebirthRemote = Remotes.Event("Rebirth")
local C = UIKit.Colors

local RebirthPanel = {}

local SIZE = Vector2.new(560, 430)

local gui: ScreenGui
local countLabel: TextLabel
local gainLabel: TextLabel
local button: TextButton
local lastClick = 0

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refresh()
	local rebirths = number("Rebirths")
	local maxRebirths = #Config.Rebirth.Costs
	local cost = Config.Rebirth.Costs[rebirths + 1]
	countLabel.Text = `Rebirths: {rebirths}/{maxRebirths}`
	local now = math.round((Config.RebirthMultiplier(rebirths) - 1) * 100)
	local nextBonus = math.round((Config.RebirthMultiplier(rebirths + 1) - 1) * 100)
	local lines = {}
	local floors = Config.FloorsForRebirths(rebirths + 1)
	if floors > number("BaseLevel") then
		table.insert(lines, `🏠 Unlocks floor {floors} of your tower`)
	end
	table.insert(lines, `💰 Creatures make +{nextBonus}% coins (now +{now}%)`)
	gainLabel.Text = table.concat(lines, "\n")
	if not cost then
		button.Text = "MAX"
		button.BackgroundColor3 = C.Gray
		gainLabel.Text = `💰 Creatures make +{now}% coins`
		return
	end
	button.Text = `Rebirth  {Format.Number(cost)}`
	button.BackgroundColor3 = if number("Coins") >= cost then C.Green else C.Red
end

function RebirthPanel.Open()
	refresh()
	gui.Enabled = true
end

function RebirthPanel.Start()
	local frame
	gui, frame = UIKit.Window("RebirthPanel", "REBIRTH", SIZE, 6)

	countLabel = UIKit.Label(frame, "", UDim2.fromOffset(SIZE.X - 56, 34), UDim2.fromOffset(28, 76), 26, C.SubText)

	UIKit.Label(frame, "You get:", UDim2.fromOffset(200, 30), UDim2.fromOffset(28, 118), 24, C.Green)
	gainLabel = UIKit.Label(frame, "", UDim2.fromOffset(SIZE.X - 56, 64), UDim2.fromOffset(28, 148), 22)
	gainLabel.TextYAlignment = Enum.TextYAlignment.Top

	UIKit.Label(frame, "You lose:", UDim2.fromOffset(200, 30), UDim2.fromOffset(28, 218), 24, C.Red)
	UIKit.Label(frame, "Your coins, Incubation Speed and Walk Speed", UDim2.fromOffset(SIZE.X - 56, 28), UDim2.fromOffset(28, 248), 22)

	UIKit.Label(frame, "You keep:", UDim2.fromOffset(200, 30), UDim2.fromOffset(28, 284), 24, C.Gold)
	UIKit.Label(frame, "Your creatures, eggs and incubators", UDim2.fromOffset(SIZE.X - 56, 28), UDim2.fromOffset(28, 314), 22)

	button = UIKit.Button(frame, "Rebirth", UDim2.fromOffset(300, 56), UDim2.fromOffset((SIZE.X - 300) / 2, SIZE.Y - 76), 28, C.Green)
	button.Activated:Connect(function()
		if os.clock() - lastClick < 0.5 then
			return
		end
		lastClick = os.clock()
		rebirthRemote:FireServer("Rebirth")
	end)

	for _, name in { "Coins", "Rebirths", "BaseLevel" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if gui.Enabled then
				refresh()
			end
		end)
	end
	SideMenu.AddButton("🔄 Rebirth", Color3.fromRGB(200, 70, 90), RebirthPanel.Open)
end

return RebirthPanel

end
__loaders['EggAnimator'] = function()
--!strict
-- EggAnimator: hace girar despacio y flotar un poco los huevos del piso (y el huevo dorado del altar).
-- Lo hace cada cliente en su pantalla, así el servidor no tiene que mandar movimiento todo el tiempo.
-- Anima las Parts con la etiqueta "Spinning" usando sus atributos Spin (grados por segundo) y Bob (cuánto sube y baja).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local EggAnimator = {}

-- Posición original de cada Part (la que puso el servidor)
local baseCFrames: { [BasePart]: CFrame } = {}

local function track(instance: Instance)
	if instance:IsA("BasePart") then
		baseCFrames[instance] = instance.CFrame
	end
end

local function untrack(instance: Instance)
	if instance:IsA("BasePart") then
		baseCFrames[instance] = nil
	end
end

local function number(part: BasePart, name: string): number
	local value = part:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

function EggAnimator.Start()
	for _, part in CollectionService:GetTagged("Spinning") do
		track(part)
	end
	CollectionService:GetInstanceAddedSignal("Spinning"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("Spinning"):Connect(untrack)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for part, base in baseCFrames do
			if not part.Parent then
				baseCFrames[part] = nil
			else
				-- Cada huevo con su propio "ritmo" (según su posición), así no se mueven todos juntos
				local phase = base.Position.X * 0.13 + base.Position.Z * 0.07
				local angle = math.rad(number(part, "Spin")) * t
				local bob = math.sin(t * 2 + phase) * number(part, "Bob")
				part.CFrame = CFrame.new(base.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, angle + phase, 0)
			end
		end
	end)
end

return EggAnimator

end
__loaders['TradePanel'] = function()
--!strict
-- TradePanel: todo lo del intercambio en la pantalla del jugador.
--   * Lista de jugadores (se abre con "Open" en el puesto de Intercambio): elegís a quién invitar.
--   * Cartel de invitación (aparece esté donde esté): Accept / Decline.
--   * Ventana de intercambio: tocás tus mascotas para ofrecerlas, ves lo que ofrece el otro y apretás "Ready".
-- El cliente solo PIDE cosas: el servidor (TradeService) decide y le manda el estado ("State").

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = __req("Config")
local Creatures = __req("Creatures")
local Format = __req("Format")
local Remotes = __req("Remotes")
local UIKit = __req("UIKit")

local player = Players.LocalPlayer
local tradeRemote = Remotes.Event("Trade")
local C = UIKit.Colors

local TradePanel = {}

local PICKER_SIZE = Vector2.new(560, 470)
local PICKER_SLOTS = 12
local TRADE_SIZE = Vector2.new(900, 560)
local MAX_SHELVES = Config.Map.BaseFloors * Config.Map.ShelvesPerFloor
local CLOSE_DISTANCE = 22

type Mine = { Slot: number, CreatureId: string, Variant: string }
type Theirs = { CreatureId: string, Variant: string }
type State = {
	Partner: string,
	MyCreatures: { Mine },
	MyOffer: { number },
	TheirOffer: { Theirs },
	MyReady: boolean,
	TheirReady: boolean,
	CountdownEndsAt: number,
}

local pickerGui: ScreenGui
local pickerButtons: { TextButton } = {}
local pickerEmpty: TextLabel
local pickerPart: BasePart? = nil

local inviteGui: ScreenGui
local inviteLabel: TextLabel
local inviteFrom = 0
local inviteExpires = 0

local tradeGui: ScreenGui
local tradeTitle: TextLabel
local myTiles: { TextButton } = {}
local myOfferRows: { TextLabel } = {}
local theirRows: { TextLabel } = {}
local myOfferHeader: TextLabel
local theirHeader: TextLabel
local statusLabel: TextLabel
local readyButton: TextButton

local state: State? = nil
local lastClick = 0

local function clickOk(): boolean
	if os.clock() - lastClick < 0.25 then
		return false
	end
	lastClick = os.clock()
	return true
end

-- Nombre lindo de una mascota ("Golden Lava Pup") y su color
local function describe(creatureId: string, variantId: string): (string, Color3, number)
	local creature = Creatures.Get(creatureId)
	local variant = Config.GetVariant(variantId)
	if not creature then
		return "???", C.Text, 0
	end
	local rarity = Config.GetRarity(creature.RarityId)
	local color = if variant.Id ~= "Normal" then variant.Color elseif rarity and rarity.Id ~= "Secret" then rarity.Color else C.Text
	local income = if rarity then Config.GetIncome(rarity, variant) else 0
	return Config.WithVariant(variant, creature.DisplayName), color, income
end

-- ===== Lista de jugadores =====

local function refreshPicker()
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(others, other)
		end
	end
	table.sort(others, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	for i, button in pickerButtons do
		local other = others[i]
		button.Visible = other ~= nil
		if other then
			button.Text = other.DisplayName
			button:SetAttribute("UserId", other.UserId)
		end
	end
	pickerEmpty.Visible = #others == 0
end

function TradePanel.OpenPicker(part: BasePart?)
	if state then
		tradeGui.Enabled = true
		return
	end
	pickerPart = part
	refreshPicker()
	pickerGui.Enabled = true
end

-- ===== Ventana de intercambio =====

local function setRow(row: TextLabel, item: Theirs?)
	if item then
		local name, color, income = describe(item.CreatureId, item.Variant)
		row.Text = `  {name}  (+{Format.Compact(income)}/s)`
		row.TextColor3 = color
		row.BackgroundTransparency = 0
	else
		row.Text = "  —"
		row.TextColor3 = C.Gray
		row.BackgroundTransparency = 0.5
	end
end

local function render()
	local current = state
	if not current then
		return
	end
	tradeTitle.Text = `TRADE WITH {string.upper(current.Partner)}`
	local offered: { [number]: boolean } = {}
	for _, slot in current.MyOffer do
		offered[slot] = true
	end
	local mine = table.clone(current.MyCreatures)
	table.sort(mine, function(a, b)
		return a.Slot < b.Slot
	end)
	for i, tile in myTiles do
		local item = mine[i]
		tile.Visible = item ~= nil
		if item then
			local name, color = describe(item.CreatureId, item.Variant)
			tile.Text = name
			tile.TextColor3 = color
			tile:SetAttribute("Slot", item.Slot)
			tile.BackgroundColor3 = if offered[item.Slot] then Color3.fromRGB(60, 140, 80) else C.Row
		end
	end
	local myItems: { Theirs } = {}
	for _, item in mine do
		if offered[item.Slot] then
			table.insert(myItems, { CreatureId = item.CreatureId, Variant = item.Variant })
		end
	end
	for i, row in myOfferRows do
		setRow(row, myItems[i])
	end
	for i, row in theirRows do
		setRow(row, current.TheirOffer[i])
	end
	myOfferHeader.Text = `YOUR OFFER ({#myItems}/{Config.Trade.MaxItems})` .. (if current.MyReady then "  · READY!" else "")
	theirHeader.Text = `{string.upper(current.Partner)}'S OFFER` .. (if current.TheirReady then "  · READY!" else "")
	readyButton.Text = if current.MyReady then "Not ready" else "Ready"
	readyButton.BackgroundColor3 = if current.MyReady then C.Gray else C.Green
end

local function updateStatus()
	local current = state
	if not current then
		return
	end
	if current.CountdownEndsAt > 0 then
		local left = math.max(0, math.ceil(current.CountdownEndsAt - Workspace:GetServerTimeNow()))
		statusLabel.Text = `Trading in {left}...`
		statusLabel.TextColor3 = C.Gold
	elseif current.MyReady and not current.TheirReady then
		statusLabel.Text = `Waiting for {current.Partner}...`
		statusLabel.TextColor3 = C.SubText
	elseif current.TheirReady and not current.MyReady then
		statusLabel.Text = `{current.Partner} is ready!`
		statusLabel.TextColor3 = C.Green
	elseif #current.MyOffer == 0 and #current.TheirOffer == 0 then
		statusLabel.Text = "Tap your creatures to add them."
		statusLabel.TextColor3 = C.SubText
	else
		statusLabel.Text = "Check the offers, then press Ready."
		statusLabel.TextColor3 = C.SubText
	end
end

local function toggleOffer(slot: number)
	local current = state
	if not current or not clickOk() then
		return
	end
	local list: { number } = {}
	local found = false
	for _, s in current.MyOffer do
		if s == slot then
			found = true
		else
			table.insert(list, s)
		end
	end
	if not found then
		if #list >= Config.Trade.MaxItems then
			return
		end
		table.insert(list, slot)
	end
	tradeRemote:FireServer("Offer", list)
end

local function buildTrade()
	local frame, closeButton
	tradeGui, frame, closeButton = UIKit.Window("TradePanel", "TRADE", TRADE_SIZE, 7)
	tradeTitle = frame:FindFirstChildOfClass("TextLabel") :: TextLabel
	closeButton.Activated:Connect(function()
		tradeRemote:FireServer("Cancel")
	end)

	-- Izquierda: tus mascotas (15 lugares como máximo, así que entran sin desplazar)
	UIKit.Label(frame, "YOUR CREATURES", UDim2.fromOffset(400, 30), UDim2.fromOffset(28, 76), 22, C.SubText)
	local columns, tileW, tileH = 3, 128, 56
	for i = 1, MAX_SHELVES do
		local col = (i - 1) % columns
		local row = (i - 1) // columns
		local tile = UIKit.Button(frame, "", UDim2.fromOffset(tileW, tileH), UDim2.fromOffset(28 + col * (tileW + 8), 112 + row * (tileH + 8)), 16, C.Row)
		tile.TextWrapped = true
		tile.Visible = false
		tile.Activated:Connect(function()
			local slot = tile:GetAttribute("Slot")
			if typeof(slot) == "number" then
				toggleOffer(slot)
			end
		end)
		table.insert(myTiles, tile)
	end

	-- Derecha: las dos ofertas
	local rightX = 456
	local rowW = TRADE_SIZE.X - rightX - 28
	local function offerList(y: number, rows: { TextLabel }): TextLabel
		local header = UIKit.Label(frame, "", UDim2.fromOffset(rowW, 30), UDim2.fromOffset(rightX, y), 22, C.Accent)
		for i = 1, Config.Trade.MaxItems do
			local row = UIKit.Label(frame, "", UDim2.fromOffset(rowW, 34), UDim2.fromOffset(rightX, y + 34 + (i - 1) * 38), 19)
			row.BackgroundColor3 = C.Row
			UIKit.Corner(row, 8)
			table.insert(rows, row)
		end
		return header
	end
	myOfferHeader = offerList(76, myOfferRows)
	theirHeader = offerList(268, theirRows)

	-- Abajo: estado + botones
	statusLabel = UIKit.Label(frame, "", UDim2.fromOffset(rowW, 30), UDim2.fromOffset(rightX, 448), 21, C.SubText)
	readyButton = UIKit.Button(frame, "Ready", UDim2.fromOffset(200, 56), UDim2.fromOffset(rightX, TRADE_SIZE.Y - 80), 26, C.Green)
	readyButton.Activated:Connect(function()
		local current = state
		if current and clickOk() then
			tradeRemote:FireServer("Ready", not current.MyReady)
		end
	end)
	local cancel = UIKit.Button(frame, "Cancel", UDim2.fromOffset(200, 56), UDim2.fromOffset(rightX + 216, TRADE_SIZE.Y - 80), 26, C.Red)
	cancel.Activated:Connect(function()
		if clickOk() then
			tradeRemote:FireServer("Cancel")
		end
	end)
end

local function buildPicker()
	local frame
	pickerGui, frame = UIKit.Window("TradePicker", "TRADING", PICKER_SIZE, 6)
	UIKit.Label(frame, "Pick a player to send a trade request:", UDim2.fromOffset(500, 30), UDim2.fromOffset(28, 72), 21, C.SubText)
	pickerEmpty = UIKit.Label(frame, "Nobody else is here yet!", UDim2.fromOffset(500, 40), UDim2.fromOffset(28, 120), 24, C.Gray)
	for i = 1, PICKER_SLOTS do
		local col = (i - 1) % 2
		local row = (i - 1) // 2
		local button = UIKit.Button(frame, "", UDim2.fromOffset(244, 50), UDim2.fromOffset(28 + col * 260, 112 + row * 58), 22, C.Row)
		button.Visible = false
		button.Activated:Connect(function()
			local userId = button:GetAttribute("UserId")
			if typeof(userId) == "number" and clickOk() then
				tradeRemote:FireServer("Request", userId)
				pickerGui.Enabled = false
			end
		end)
		table.insert(pickerButtons, button)
	end
end

local function buildInvite()
	inviteGui = Instance.new("ScreenGui")
	inviteGui.Name = "TradeInvite"
	inviteGui.ResetOnSpawn = false
	inviteGui.Enabled = false
	inviteGui.DisplayOrder = 8
	inviteGui.Parent = player:WaitForChild("PlayerGui")
	local size = Vector2.new(440, 150)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 90)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = C.Panel
	frame.Parent = inviteGui
	UIKit.Corner(frame, 18)
	UIKit.Stroke(frame, 3, C.Accent)
	UIKit.FitToScreen(frame, size)
	inviteLabel = UIKit.Label(frame, "", UDim2.fromOffset(size.X - 32, 50), UDim2.fromOffset(16, 10), 24)
	inviteLabel.TextXAlignment = Enum.TextXAlignment.Center
	inviteLabel.TextWrapped = true
	local accept = UIKit.Button(frame, "Accept", UDim2.fromOffset(190, 54), UDim2.fromOffset(20, 78), 24, C.Green)
	local decline = UIKit.Button(frame, "Decline", UDim2.fromOffset(190, 54), UDim2.fromOffset(size.X - 210, 78), 24, C.Red)
	accept.Activated:Connect(function()
		tradeRemote:FireServer("Respond", inviteFrom, true)
		inviteGui.Enabled = false
	end)
	decline.Activated:Connect(function()
		tradeRemote:FireServer("Respond", inviteFrom, false)
		inviteGui.Enabled = false
	end)
end

local function setupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function()
		local part = prompt.Parent
		TradePanel.OpenPicker(if part and part:IsA("BasePart") then part else nil)
	end)
end

-- Para las pruebas y vistas previas: mostrar un estado como si viniera del servidor
function TradePanel.ShowState(newState: State)
	state = newState
	pickerGui.Enabled = false
	tradeGui.Enabled = true
	render()
	updateStatus()
end

function TradePanel.ShowInvite(name: string, userId: number)
	inviteFrom = userId
	inviteExpires = os.clock() + Config.Trade.RequestTimeout
	inviteLabel.Text = `{name} wants to trade with you!`
	inviteGui.Enabled = true
end

function TradePanel.Start()
	buildPicker()
	buildInvite()
	buildTrade()

	for _, prompt in CollectionService:GetTagged("TradePrompt") do
		setupPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("TradePrompt"):Connect(setupPrompt)
	Players.PlayerAdded:Connect(function()
		if pickerGui.Enabled then
			refreshPicker()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if pickerGui.Enabled then
			task.defer(refreshPicker)
		end
	end)

	tradeRemote.OnClientEvent:Connect(function(kind: unknown, a: unknown, b: unknown)
		if kind == "Invite" and typeof(a) == "string" and typeof(b) == "number" then
			TradePanel.ShowInvite(a, b)
		elseif kind == "State" and typeof(a) == "table" then
			TradePanel.ShowState(a :: State)
		elseif kind == "Closed" then
			state = nil
			tradeGui.Enabled = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		if inviteGui.Enabled and os.clock() > inviteExpires then
			inviteGui.Enabled = false
		end
		if tradeGui.Enabled then
			updateStatus()
		end
		-- La lista de jugadores se cierra si te alejás del puesto
		local part = pickerPart
		if pickerGui.Enabled and part then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") or (root.Position - part.Position).Magnitude > CLOSE_DISTANCE then
				pickerGui.Enabled = false
			end
		end
	end)
end

return TradePanel

end
__loaders['SideMenu'] = function()
--!strict
-- SideMenu: la columna de botones grandes del costado izquierdo (Rebirth, Trade, VIP...).
-- Cada módulo agrega su botón con SideMenu.AddButton (el orden en que se agregan es el orden en pantalla).

local Players = game:GetService("Players")

local UIKit = __req("UIKit")

local player = Players.LocalPlayer

local SideMenu = {}

local BUTTON = Vector2.new(120, 46)
local GAP = 8

local holder: Frame? = nil
local count = 0

local function getHolder(): Frame
	if holder then
		return holder
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SideMenu"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Position = UDim2.new(0, 16, 0.2, 0)
	frame.Size = UDim2.fromOffset(BUTTON.X, (BUTTON.Y + GAP) * 4)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	UIKit.FitToScreen(frame, Vector2.new(BUTTON.X, (BUTTON.Y + GAP) * 4), Vector2.new(400, 300))
	holder = frame
	return frame
end

-- Agrega un botón. Devuelve el botón (por si hay que cambiarle el texto o esconderlo).
function SideMenu.AddButton(text: string, color: Color3, onClick: () -> ()): TextButton
	local frame = getHolder()
	local button = UIKit.Button(frame, text, UDim2.fromOffset(BUTTON.X, BUTTON.Y), UDim2.fromOffset(0, count * (BUTTON.Y + GAP)), 22, color)
	count += 1
	button.Activated:Connect(onClick)
	return button
end

return SideMenu

end
__loaders['Hud'] = function()
--!strict
-- Hud: lo que siempre está en pantalla.
--   Abajo a la izquierda: tu plata (salta cuando sube) y cuánto ganás por segundo.
--   Arriba de la plata: qué huevo estás llevando (con el color de su rareza o variante).
-- Lee los atributos que publica el servidor: Coins, Income, CarriedEggRarity y CarriedEggVariant,
-- y Event de Workspace (en "Double Coins" la plata por segundo se muestra x2).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = __req("Config")
local Format = __req("Format")
local UIKit = __req("UIKit")

local player = Players.LocalPlayer
local C = UIKit.Colors

local Hud = {}

local coinsLabel: TextLabel
local incomeLabel: TextLabel
local coinsScale: UIScale
local carryPill: Frame
local carryLabel: TextLabel
local lastCoins = 0

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function onCoinsChanged()
	local coins = number("Coins")
	coinsLabel.Text = Format.Number(coins)
	-- Saltito cuando sube la plata
	if coins > lastCoins then
		coinsScale.Scale = 1.12
		TweenService:Create(coinsScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	lastCoins = coins
end

local function onIncomeChanged()
	local doubled = Workspace:GetAttribute("Event") == "DoubleCoins"
	local income = number("Income") * (if doubled then Config.Events.DoubleCoinsMultiplier else 1)
	incomeLabel.Text = if doubled
		then `+{Format.Compact(income)} / sec  (x{Config.Events.DoubleCoinsMultiplier}!)`
		else `+{Format.Compact(income)} / sec`
	incomeLabel.TextColor3 = if doubled then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(130, 255, 130)
end

local function onCarryChanged()
	local rarityId = player:GetAttribute("CarriedEggRarity")
	local rarity = if typeof(rarityId) == "string" then Config.GetRarity(rarityId) else nil
	carryPill.Visible = rarity ~= nil
	if rarity then
		local variantId = player:GetAttribute("CarriedEggVariant")
		local variant = Config.GetVariant(if typeof(variantId) == "string" then variantId else nil)
		carryLabel.Text = `🥚 Carrying: {Config.WithVariant(variant, rarity.DisplayName .. " Egg")}`
		carryLabel.TextColor3 = if variant.Id ~= "Normal" then variant.Color
			elseif rarity.Id == "Secret" then Color3.fromRGB(230, 200, 255)
			else rarity.Color
	end
end

function Hud.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Contenedor abajo a la izquierda (tamaño fijo, se achica en pantallas chicas)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, 16, 1, -16)
	holder.Size = UDim2.fromOffset(320, 130)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	UIKit.FitToScreen(holder, Vector2.new(320, 130), Vector2.new(400, 300))

	-- Plata
	local coinsPill = Instance.new("Frame")
	coinsPill.AnchorPoint = Vector2.new(0, 1)
	coinsPill.Position = UDim2.fromScale(0, 1)
	coinsPill.Size = UDim2.fromOffset(280, 76)
	coinsPill.BackgroundColor3 = C.Panel
	coinsPill.BackgroundTransparency = 0.1
	coinsPill.Parent = holder
	UIKit.Corner(coinsPill, 18)
	UIKit.Stroke(coinsPill, 3, C.Gold)
	coinsScale = Instance.new("UIScale")
	coinsScale.Parent = coinsPill

	local icon = UIKit.Label(coinsPill, "🪙", UDim2.fromOffset(56, 56), UDim2.fromOffset(10, 10), 40)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	coinsLabel = UIKit.Label(coinsPill, "0", UDim2.fromOffset(200, 40), UDim2.fromOffset(70, 6), 34, C.Gold)
	UIKit.Stroke(coinsLabel, 2)
	incomeLabel = UIKit.Label(coinsPill, "+0 / sec", UDim2.fromOffset(200, 24), UDim2.fromOffset(72, 46), 20, Color3.fromRGB(130, 255, 130))

	-- Huevo que estás llevando
	carryPill = Instance.new("Frame")
	carryPill.AnchorPoint = Vector2.new(0, 1)
	carryPill.Position = UDim2.new(0, 0, 1, -86)
	carryPill.Size = UDim2.fromOffset(320, 40)
	carryPill.BackgroundColor3 = C.Panel
	carryPill.BackgroundTransparency = 0.1
	carryPill.Visible = false
	carryPill.Parent = holder
	UIKit.Corner(carryPill, 14)
	carryLabel = UIKit.Label(carryPill, "", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), 20)
	UIKit.Stroke(carryLabel, 1.5)

	player:GetAttributeChangedSignal("Coins"):Connect(onCoinsChanged)
	player:GetAttributeChangedSignal("Income"):Connect(onIncomeChanged)
	player:GetAttributeChangedSignal("CarriedEggRarity"):Connect(onCarryChanged)
	player:GetAttributeChangedSignal("CarriedEggVariant"):Connect(onCarryChanged)
	Workspace:GetAttributeChangedSignal("Event"):Connect(onIncomeChanged)
	lastCoins = number("Coins")
	onCoinsChanged()
	onIncomeChanged()
	onCarryChanged()
end

return Hud

end
__loaders['EventBoard'] = function()
--!strict
-- EventBoard: escribe el tablero de eventos del puesto de Rankings (lo arma MapBuilder, con el atributo "EventBoard").
--   Renglón 1: la próxima ola ("NEXT WAVE IN 0:42", "WAVE IN 0:03!", "WAVE!")
--   Renglón 2: cuánto falta para el Súper tsunami
--   Renglón 3: el evento activo (o cuánto falta para el próximo sorteo de evento)
-- Lo hace cada cliente con los atributos de Workspace, así el servidor no tiene que mandar nada.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = __req("Config")

local EventBoard = {}

local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(255, 90, 90)
local BLUE = Color3.fromRGB(150, 230, 255)
local PURPLE = Color3.fromRGB(200, 150, 255)

local function formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function untilTime(name: string): number
	local at = Workspace:GetAttribute(name)
	return if typeof(at) == "number" then at - Workspace:GetServerTimeNow() else 0
end

-- Qué dice cada renglón ahora: { texto, color }
local function lines(): { { Text: string, Color: Color3 } }
	local phase = Workspace:GetAttribute("WavePhase")
	local wave
	if phase == "Warning" then
		wave = { Text = `WAVE IN {formatTime(untilTime("PhaseEndsAt"))}!`, Color = RED }
	elseif phase == "Wave" then
		wave = { Text = "WAVE!", Color = RED }
	else
		wave = { Text = `NEXT WAVE IN {formatTime(untilTime("PhaseEndsAt"))}`, Color = BLUE }
	end
	local super = { Text = `SUPER TSUNAMI IN {formatTime(untilTime("NextSuperAt"))}`, Color = PURPLE }

	local eventId = Workspace:GetAttribute("Event")
	local event = if typeof(eventId) == "string" then Config.GetEvent(eventId) else nil
	local eventLine = if event
		then { Text = `{event.DisplayName} · {formatTime(untilTime("EventEndsAt"))}`, Color = event.Color }
		else { Text = `Next event in {formatTime(untilTime("NextEventAt"))}`, Color = WHITE }
	return { wave, super, eventLine }
end

local function findBoards(): { BasePart }
	local boards = {}
	local map = Workspace:FindFirstChild("Map")
	local model = map and map:FindFirstChild("EventBoard", true)
	local board = model and model:FindFirstChild("Board")
	if board and board:IsA("BasePart") and board:GetAttribute("EventBoard") then
		table.insert(boards, board)
	end
	return boards
end

local function update(boards: { BasePart })
	local content = lines()
	for _, board in boards do
		for _, gui in board:GetChildren() do
			if gui:IsA("SurfaceGui") then
				for i, line in content do
					local label = gui:FindFirstChild(`Line{i}`)
					if label and label:IsA("TextLabel") then
						label.Text = line.Text
						label.TextColor3 = line.Color
					end
				end
			end
		end
	end
end

function EventBoard.Start()
	task.spawn(function()
		local boards: { BasePart } = {}
		while true do
			-- El mapa puede tardar en llegar al cliente: lo buscamos hasta encontrarlo
			if #boards == 0 then
				boards = findBoards()
			end
			update(boards)
			task.wait(0.25)
		end
	end)
end

return EventBoard

end
__loaders['UpgradePanel'] = function()
--!strict
-- UpgradePanel: la ventana de mejoras que se abre desde el panel de tu base.
-- Ventana ancha de tamaño fijo (680x500) que se achica entera en pantallas chicas (UIKit.FitToScreen),
-- con columnas separadas para que los textos nunca se pisen:
--   [ícono] [nombre]        [Lv 2/5]            [  Buy 500  ]
--           [descripción de qué cambia...]
-- El botón "Buy" solo PIDE la compra: el servidor decide si se puede (ver UpgradeService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = __req("Remotes")
local Upgrades = __req("Upgrades")
local Format = __req("Format")
local UIKit = __req("UIKit")

local player = Players.LocalPlayer
local buyRemote = Remotes.Event("BuyUpgrade")
local tutorialRemote = Remotes.Event("TutorialAction")
local C = UIKit.Colors

local UpgradePanel = {}

local CLOSE_DISTANCE = 20 -- si te alejás más que esto del panel, la ventana se cierra sola
local ROW_HEIGHT, ROW_GAP, HEADER = 88, 12, 84
-- El alto de la ventana depende de cuántas mejoras hay
local WIDTH, HEIGHT = 680, HEADER + #Upgrades.Order * (ROW_HEIGHT + ROW_GAP) + 16

local ICONS: { [string]: string } = {
	IncubationSpeed = "⏩",
	ExtraIncubator = "🥚",
	WalkSpeed = "👟",
	BaseFloor = "🏠",
}
local ICON_COLORS: { [string]: Color3 } = {
	IncubationSpeed = Color3.fromRGB(255, 150, 60),
	ExtraIncubator = Color3.fromRGB(90, 190, 255),
	WalkSpeed = Color3.fromRGB(120, 220, 120),
	BaseFloor = Color3.fromRGB(200, 130, 255),
}

type Row = { Level: TextLabel, Description: TextLabel, Button: TextButton }

local gui: ScreenGui
local coinsLabel: TextLabel
local rows: { [string]: Row } = {}
local openPanelPart: BasePart? = nil
local lastClick = 0

local function currentState(): Upgrades.State
	local function attr(name: string): number
		local value = player:GetAttribute(name)
		return if typeof(value) == "number" then value else 1
	end
	return {
		IncubationSpeedLevel = attr("IncubationSpeedLevel"),
		IncubatorCount = attr("IncubatorCount"),
		WalkSpeedLevel = attr("WalkSpeedLevel"),
		BaseLevel = attr("BaseLevel"),
	}
end

local function refresh()
	local coins = player:GetAttribute("Coins")
	local coinValue = if typeof(coins) == "number" then coins else 0
	coinsLabel.Text = Format.Number(coinValue)

	local state = currentState()
	for id, row in rows do
		local current, max = Upgrades.GetLevel(id, state)
		local cost = Upgrades.GetNextCost(id, state)
		row.Level.Text = `Lv {current}/{max}`
		row.Description.Text = Upgrades.Describe(id, state)
		if cost == nil then
			row.Button.Text = "MAX"
			row.Button.BackgroundColor3 = C.Gray
			row.Button.AutoButtonColor = false
		else
			row.Button.Text = `Buy  {Format.Number(cost)}`
			local canAfford = coinValue >= cost
			row.Button.BackgroundColor3 = if canAfford then C.Green else C.Red
			row.Button.AutoButtonColor = canAfford
		end
	end
end

local function close()
	gui.Enabled = false
	openPanelPart = nil
end

local function open(panelPart: BasePart)
	openPanelPart = panelPart
	refresh()
	gui.Enabled = true
	-- Paso 4 del tutorial: "abrí el panel de mejoras"
	if player:GetAttribute("TutorialStep") == 4 then
		tutorialRemote:FireServer("OpenedUpgrades")
	end
end

local function buildRow(parent: Instance, index: number, id: string)
	local rowWidth = WIDTH - 48
	local row = Instance.new("Frame")
	row.Size = UDim2.fromOffset(rowWidth, ROW_HEIGHT)
	row.Position = UDim2.fromOffset(24, HEADER + (index - 1) * (ROW_HEIGHT + ROW_GAP))
	row.BackgroundColor3 = C.Row
	row.Parent = parent
	UIKit.Corner(row, 14)

	-- Ícono
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromOffset(64, 64)
	icon.Position = UDim2.fromOffset(12, 12)
	icon.BackgroundColor3 = ICON_COLORS[id] or C.Gray
	icon.Text = ICONS[id] or "?"
	icon.TextSize = 34
	icon.Font = UIKit.Font
	icon.Parent = row
	UIKit.Corner(icon, 12)

	-- Columna de textos (de x=88 a x=448): nombre + nivel arriba, descripción abajo
	UIKit.Label(row, Upgrades.DisplayNames[id], UDim2.fromOffset(250, 34), UDim2.fromOffset(88, 10), 26)

	local level = UIKit.Label(row, "Lv 1/1", UDim2.fromOffset(84, 28), UDim2.fromOffset(346, 13), 18, C.Accent)
	level.TextXAlignment = Enum.TextXAlignment.Center
	level.BackgroundTransparency = 0
	level.BackgroundColor3 = Color3.fromRGB(30, 32, 48)
	UIKit.Corner(level, 14)

	local description = UIKit.Label(row, "", UDim2.fromOffset(354, 28), UDim2.fromOffset(88, 48), 18, C.SubText)

	-- Botón (de x=460 a x=620)
	local button = UIKit.Button(row, "", UDim2.fromOffset(160, 60), UDim2.fromOffset(rowWidth - 172, 14), 22, C.Green)
	button.Activated:Connect(function()
		-- Pequeña pausa entre clics para no mandar 20 pedidos al servidor
		if os.clock() - lastClick < 0.3 then
			return
		end
		lastClick = os.clock()
		buyRemote:FireServer(id)
	end)

	rows[id] = { Level = level, Description = description, Button = button }
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "UpgradePanel"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	frame.BackgroundColor3 = C.Panel
	frame.Parent = gui
	UIKit.Corner(frame, 20)
	UIKit.Stroke(frame, 4, C.Accent)
	UIKit.FitToScreen(frame, Vector2.new(WIDTH, HEIGHT))

	-- Encabezado: título a la izquierda, plata a la derecha, X en la esquina
	UIKit.Label(frame, "UPGRADES", UDim2.fromOffset(300, 50), UDim2.fromOffset(28, 18), 40, C.Accent)

	local coinsPill = Instance.new("Frame")
	coinsPill.Size = UDim2.fromOffset(210, 44)
	coinsPill.Position = UDim2.fromOffset(WIDTH - 210 - 84, 21)
	coinsPill.BackgroundColor3 = Color3.fromRGB(22, 24, 38)
	coinsPill.Parent = frame
	UIKit.Corner(coinsPill, 22)
	local coinIcon = UIKit.Label(coinsPill, "🪙", UDim2.fromOffset(36, 36), UDim2.fromOffset(8, 4), 26)
	coinIcon.TextXAlignment = Enum.TextXAlignment.Center
	coinsLabel = UIKit.Label(coinsPill, "0", UDim2.fromOffset(156, 44), UDim2.fromOffset(46, 0), 24, C.Gold)

	local closeButton = UIKit.Button(frame, "X", UDim2.fromOffset(52, 52), UDim2.fromOffset(WIDTH - 70, 17), 28, C.Red)
	closeButton.Activated:Connect(close)

	for i, id in Upgrades.Order do
		buildRow(frame, i, id)
	end
end

-- El prompt "Open" solo se ve en tu propia base. El del puesto del lobby (atributo Shared) lo ve cualquiera con base.
local function setupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local function updateVisibility()
		local myBase = player:GetAttribute("BaseId")
		prompt.Enabled = if prompt:GetAttribute("Shared") then myBase ~= nil else prompt:GetAttribute("BaseId") == myBase
	end
	updateVisibility()
	player:GetAttributeChangedSignal("BaseId"):Connect(updateVisibility)
	prompt.Triggered:Connect(function()
		local part = prompt.Parent
		if prompt.Enabled and part and part:IsA("BasePart") then
			open(part)
		end
	end)
end

function UpgradePanel.Start()
	build()

	for _, prompt in CollectionService:GetTagged("UpgradePrompt") do
		setupPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("UpgradePrompt"):Connect(setupPrompt)

	for _, name in { "Coins", "IncubationSpeedLevel", "IncubatorCount", "WalkSpeedLevel", "BaseLevel" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if gui.Enabled then
				refresh()
			end
		end)
	end

	-- Si te alejás del panel, se cierra
	RunService.Heartbeat:Connect(function()
		local part = openPanelPart
		if not gui.Enabled or not part then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - part.Position).Magnitude > CLOSE_DISTANCE then
			close()
		end
	end)
end

return UpgradePanel

end
__loaders['MerchantPanel'] = function()
--!strict
-- MerchantPanel: la ventana del Comerciante misterioso (se abre con "Open" en su puesto del lobby).
-- Muestra las ofertas de esta tanda (las publica el servidor en Workspace.MerchantOffers),
-- cuánto falta para la próxima y cuáles ya compraste. "Buy" solo PIDE la compra (ver MerchantService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = __req("Config")
local Format = __req("Format")
local Remotes = __req("Remotes")
local UIKit = __req("UIKit")

local player = Players.LocalPlayer
local merchantRemote = Remotes.Event("Merchant")
local C = UIKit.Colors

local MerchantPanel = {}

local SIZE = Vector2.new(760, 430)
local CARD = Vector2.new(220, 300)
local CLOSE_DISTANCE = 22

type Card = { Frame: Frame, Egg: Frame, Name: TextLabel, Income: TextLabel, Button: TextButton }
type Offer = { RarityId: string, VariantId: string, Price: number }

local gui: ScreenGui
local timerLabel: TextLabel
local cards: { Card } = {}
local openPart: BasePart? = nil
local lastClick = 0

local function parseOffers(): { Offer }
	local text = Workspace:GetAttribute("MerchantOffers")
	local result: { Offer } = {}
	if typeof(text) ~= "string" then
		return result
	end
	for _, chunk in string.split(text, ";") do
		local fields = string.split(chunk, ":")
		local price = tonumber(fields[3])
		if #fields == 3 and price then
			table.insert(result, { RarityId = fields[1], VariantId = fields[2], Price = price })
		end
	end
	return result
end

local function boughtSet(): { [number]: boolean }
	local text = player:GetAttribute("MerchantBought")
	local set: { [number]: boolean } = {}
	if typeof(text) == "string" then
		for _, n in string.split(text, ",") do
			local index = tonumber(n)
			if index then
				set[index] = true
			end
		end
	end
	return set
end

local function refresh()
	local offers = parseOffers()
	local sold = boughtSet()
	local coinsValue = player:GetAttribute("Coins")
	local coins = if typeof(coinsValue) == "number" then coinsValue else 0
	for i, card in cards do
		local offer = offers[i]
		card.Frame.Visible = offer ~= nil
		if offer then
			local rarity = Config.GetRarity(offer.RarityId)
			local variant = Config.GetVariant(offer.VariantId)
			if rarity then
				card.Egg.BackgroundColor3 = if variant.Id ~= "Normal" then variant.Color else rarity.Color
				card.Name.Text = Config.WithVariant(variant, rarity.DisplayName .. " Egg")
				card.Name.TextColor3 = if variant.Id ~= "Normal" then variant.Color elseif rarity.Id == "Secret" then C.Text else rarity.Color
				card.Income.Text = `Creature: +{Format.Compact(Config.GetIncome(rarity, variant))}/s`
			end
			if sold[i] then
				card.Button.Text = "SOLD"
				card.Button.BackgroundColor3 = C.Gray
			else
				card.Button.Text = `Buy  {Format.Compact(offer.Price)}`
				card.Button.BackgroundColor3 = if coins >= offer.Price then C.Green else C.Red
			end
		end
	end
end

local function updateTimer()
	local at = Workspace:GetAttribute("MerchantRestockAt")
	local left = if typeof(at) == "number" then math.max(0, at - Workspace:GetServerTimeNow()) else 0
	local s = math.ceil(left)
	timerLabel.Text = string.format("New stock in %d:%02d", s // 60, s % 60)
end

function MerchantPanel.Open(part: BasePart?)
	openPart = part
	refresh()
	updateTimer()
	gui.Enabled = true
end

local function buildCard(frame: Frame, index: number): Card
	local x = 28 + (index - 1) * (CARD.X + 16)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	card.Position = UDim2.fromOffset(x, 106)
	card.BackgroundColor3 = C.Row
	card.Parent = frame
	UIKit.Corner(card, 16)

	-- "Huevo" de color (un óvalo)
	local egg = Instance.new("Frame")
	egg.AnchorPoint = Vector2.new(0.5, 0)
	egg.Position = UDim2.fromOffset(CARD.X / 2, 18)
	egg.Size = UDim2.fromOffset(84, 108)
	egg.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = egg
	UIKit.Stroke(egg, 3, Color3.fromRGB(20, 20, 30))

	local name = UIKit.Label(card, "", UDim2.fromOffset(CARD.X - 16, 56), UDim2.fromOffset(8, 134), 22)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextWrapped = true
	name.TextTruncate = Enum.TextTruncate.None
	UIKit.Stroke(name, 1.5)
	local income = UIKit.Label(card, "", UDim2.fromOffset(CARD.X - 16, 28), UDim2.fromOffset(8, 192), 20, Color3.fromRGB(130, 255, 130))
	income.TextXAlignment = Enum.TextXAlignment.Center

	local button = UIKit.Button(card, "Buy", UDim2.fromOffset(CARD.X - 32, 50), UDim2.fromOffset(16, CARD.Y - 66), 24, C.Green)
	button.Activated:Connect(function()
		if os.clock() - lastClick < 0.4 then
			return
		end
		lastClick = os.clock()
		merchantRemote:FireServer("Buy", index)
	end)
	return { Frame = card, Egg = egg, Name = name, Income = income, Button = button }
end

local function setupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function()
		local part = prompt.Parent
		MerchantPanel.Open(if part and part:IsA("BasePart") then part else nil)
	end)
end

function MerchantPanel.Start()
	local frame
	gui, frame = UIKit.Window("MerchantPanel", "MYSTERY MERCHANT", SIZE, 6)
	timerLabel = UIKit.Label(frame, "", UDim2.fromOffset(400, 30), UDim2.fromOffset(28, 66), 22, C.SubText)
	for i = 1, Config.Merchant.OfferCount do
		table.insert(cards, buildCard(frame, i))
	end

	for _, prompt in CollectionService:GetTagged("MerchantPrompt") do
		setupPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("MerchantPrompt"):Connect(setupPrompt)

	Workspace:GetAttributeChangedSignal("MerchantOffers"):Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
	for _, name in { "Coins", "MerchantBought" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if gui.Enabled then
				refresh()
			end
		end)
	end
	RunService.Heartbeat:Connect(function()
		if not gui.Enabled then
			return
		end
		updateTimer()
		-- Si te alejás del puesto, se cierra
		local part = openPart
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if part and (not root or not root:IsA("BasePart") or (root.Position - part.Position).Magnitude > CLOSE_DISTANCE) then
			gui.Enabled = false
		end
	end)
end

return MerchantPanel

end
__loaders['Tutorial'] = function()
--!strict
-- Tutorial: muestra qué hacer ahora (cartel arriba) y una flecha de luz desde tu personaje hasta el objetivo.
-- El paso lo decide el servidor (atributo "TutorialStep", ver TutorialService). Este módulo solo lo dibuja.
-- Si viene la ola y estás en el cañón, el tutorial te lleva a la cueva-refugio más cercana.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = __req("Config")
local Remotes = __req("Remotes")
local UIKit = __req("UIKit")

local player = Players.LocalPlayer
local actionRemote = Remotes.Event("TutorialAction")

local Tutorial = {}

-- Mismos números que TutorialService.Steps
local GRAB_EGG, INCUBATE, WAIT_HATCH, OPEN_UPGRADES, DONE = 1, 2, 3, 4, 5

local TEXTS: { [string]: string } = {
	Grab = "🥚 Go through the tiki portal and grab an egg in the canyon!",
	Incubate = "🏠 Bring the egg to an incubator in front of your base!",
	Wait = "⏳ Your egg is incubating! When it says READY!, open it.",
	Open = "🐣 Your egg is READY! Open it!",
	Upgrades = "🪙 Your creature makes coins! Visit the Upgrades shop on the island.",
	Danger = "🌊 THE WAVE IS COMING! Hide in a cave!",
}

local WIDTH, HEIGHT = 600, 64

local banner: Frame
local bannerText: TextLabel
local beam: Beam
local targetAttachment: Attachment
local marker: Part
local markerGui: BillboardGui
local lastSearch = 0
local cachedEgg: BasePart? = nil
local caveSpots: { Vector3 }? = nil

local function step(): number
	local value = player:GetAttribute("TutorialStep")
	return if typeof(value) == "number" then value else DONE
end

local function myBase(): Model?
	local baseId = player:GetAttribute("BaseId")
	local map = Workspace:FindFirstChild("Map")
	local bases = map and map:FindFirstChild("Bases")
	local base = bases and bases:FindFirstChild(`Base{baseId}`)
	return if base and base:IsA("Model") then base else nil
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- El huevo del piso más cercano (se busca cada medio segundo, no en cada frame)
local function nearestEgg(from: Vector3): BasePart?
	if os.clock() - lastSearch < 0.5 and cachedEgg and cachedEgg.Parent then
		return cachedEgg
	end
	lastSearch = os.clock()
	cachedEgg = nil
	local eggs = Workspace:FindFirstChild("Eggs")
	if not eggs then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, child in eggs:GetChildren() do
		local prompt = child:FindFirstChildOfClass("ProximityPrompt")
		if child:IsA("BasePart") and prompt and prompt.Enabled then
			local distance = (child.Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = child, distance
			end
		end
	end
	cachedEgg = best
	return best
end

local function findPart(root: Instance?, path: { string }): BasePart?
	local current: Instance? = root
	for _, name in path do
		current = current and current:FindFirstChild(name)
	end
	return if current and current:IsA("BasePart") then current else nil
end

-- La cueva-refugio más cercana (las comunes; la VIP no, porque no todos pueden entrar)
local function nearestCave(from: Vector3): Vector3?
	if not caveSpots then
		local found: { Vector3 } = {}
		local map = Workspace:FindFirstChild("Map")
		local canyon = map and map:FindFirstChild("Canyon")
		local caves = canyon and canyon:FindFirstChild("Caves")
		if caves then
			for _, cave in caves:GetChildren() do
				local zone = cave:FindFirstChild("SafeZone")
				if zone and zone:IsA("BasePart") and not cave:GetAttribute("Vip") then
					table.insert(found, zone.Position)
				end
			end
		end
		if #found == 0 then
			return nil
		end
		caveSpots = found
	end
	local best: Vector3? = nil
	local bestDistance = math.huge
	local spots: { Vector3 } = caveSpots or {}
	for _, spot in spots do
		local distance = (spot - from).Magnitude
		if distance < bestDistance then
			best, bestDistance = spot, distance
		end
	end
	return best
end

-- Decide qué texto mostrar y a dónde apunta la flecha
local function currentGoal(root: BasePart): (string?, Vector3?)
	local s = step()
	if s >= DONE then
		return nil, nil
	end
	local base = myBase()

	-- Si viene la ola y estás en el cañón: ¡a una cueva!
	local phase = Workspace:GetAttribute("WavePhase")
	if (phase == "Warning" or phase == "Wave") and root.Position.X > Config.Map.CanyonStartX then
		return TEXTS.Danger, nearestCave(root.Position)
	end

	local carrying = player:GetAttribute("CarriedEggRarity") ~= nil
	local incubator = findPart(base, { "IncubatorSlots", "Nest1", "Pedestal" })
	if s == GRAB_EGG or (s == INCUBATE and not carrying) then
		local egg = nearestEgg(root.Position)
		-- Si no ves ninguno cerca, apuntamos al portal tiki (la entrada del cañón)
		return TEXTS.Grab, if egg then egg.Position else Vector3.new(Config.Map.CanyonStartX, 3, 0)
	elseif s == INCUBATE then
		return TEXTS.Incubate, if incubator then incubator.Position else nil
	elseif s == WAIT_HATCH then
		local prompt = incubator and incubator:FindFirstChildOfClass("ProximityPrompt")
		if prompt and prompt:GetAttribute("State") == "Ready" then
			return TEXTS.Open, incubator and incubator.Position
		end
		return TEXTS.Wait, nil
	elseif s == OPEN_UPGRADES then
		local map = Workspace:FindFirstChild("Map")
		local shop = findPart(map and map:FindFirstChild("Stalls", true), { "UpgradeShop", "Counter" })
		return TEXTS.Upgrades, if shop then shop.Position else nil
	end
	return nil, nil
end

-- ===== Armado =====

local function buildBanner()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 116) -- abajo del cartel de la tormenta
	banner.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	banner.BackgroundColor3 = UIKit.Colors.Panel
	banner.BackgroundTransparency = 0.1
	banner.Visible = false
	banner.Parent = gui
	UIKit.Corner(banner, 16)
	UIKit.Stroke(banner, 3, UIKit.Colors.Accent)
	UIKit.FitToScreen(banner, Vector2.new(WIDTH, HEIGHT), Vector2.new(24, 0))

	bannerText = UIKit.Label(banner, "", UDim2.fromOffset(WIDTH - 110, HEIGHT - 8), UDim2.fromOffset(16, 4), 20)
	bannerText.TextWrapped = true
	bannerText.TextTruncate = Enum.TextTruncate.None

	local skip = UIKit.Button(banner, "Skip", UDim2.fromOffset(76, 40), UDim2.fromOffset(WIDTH - 88, 12), 18, UIKit.Colors.Gray)
	skip.Activated:Connect(function()
		actionRemote:FireServer("Skip")
	end)
end

local function buildArrow()
	-- La flecha es un Beam entre un punto en tu personaje y un punto en el objetivo
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "TutorialTarget"
	targetAttachment.Parent = Workspace.Terrain

	beam = Instance.new("Beam")
	beam.Name = "TutorialBeam"
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(UIKit.Colors.Accent)
	beam.Transparency = NumberSequence.new(0.2, 0.5)
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 20
	beam.CurveSize0 = 6 -- un poco curva, hacia arriba
	beam.CurveSize1 = -6
	beam.Enabled = false
	beam.Parent = Workspace.Terrain

	-- Marca que salta arriba del objetivo
	marker = Instance.new("Part")
	marker.Name = "TutorialMarker"
	marker.Size = Vector3.new(1, 1, 1)
	marker.Transparency = 1
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Parent = Workspace
	markerGui = Instance.new("BillboardGui")
	markerGui.Size = UDim2.fromOffset(60, 60)
	markerGui.AlwaysOnTop = true
	markerGui.Enabled = false
	markerGui.Parent = marker
	local arrow = UIKit.Label(markerGui, "▼", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 48, UIKit.Colors.Accent)
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.Stroke(arrow, 3)
end

-- El extremo de la flecha que sale de tu personaje (hay que rehacerlo cada vez que reaparecés)
local function attachToCharacter()
	local root = rootPart()
	if not root then
		return
	end
	local existing = root:FindFirstChild("TutorialSource")
	local source = if existing and existing:IsA("Attachment") then existing else Instance.new("Attachment")
	source.Name = "TutorialSource"
	source.Parent = root
	beam.Attachment0 = source
end

local function update()
	local root = rootPart()
	local text, target = nil, nil
	if root then
		text, target = currentGoal(root)
	end

	banner.Visible = text ~= nil
	if text then
		bannerText.Text = text
	end

	local showArrow = target ~= nil and root ~= nil and beam.Attachment0 ~= nil
	beam.Enabled = showArrow
	markerGui.Enabled = showArrow
	if target and showArrow then
		targetAttachment.WorldPosition = target
		-- La marca sube y baja arriba del objetivo
		marker.CFrame = CFrame.new(target + Vector3.new(0, 5 + math.sin(os.clock() * 4) * 0.8, 0))
	end
end

function Tutorial.Start()
	buildBanner()
	buildArrow()
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		attachToCharacter()
	end)
	attachToCharacter()
	RunService.RenderStepped:Connect(update)
end

return Tutorial

end
__loaders['WaveClient'] = function()
--!strict
-- WaveClient: todo lo que el jugador VE y ESCUCHA de las olas y los eventos.
--   - Arriba de la pantalla: cuánto falta para la próxima ola (y abajo, el evento activo si hay).
--   - Durante el aviso: cartel grande "THE WAVE IS COMING!" con cuenta regresiva, cuerno y la cámara tiembla
--     (si estás en el cañón).
--   - La ola: este cliente la dibuja con la misma fórmula que usa el servidor para decidir a quién agarra,
--     así se mueve suave (sin los saltitos que tendría si la moviera el servidor).
--   - Cuando empieza un evento: un cartel grande con su nombre y qué hace.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = __req("Config")
local UIKit = __req("UIKit")

local player = Players.LocalPlayer

local WaveClient = {}

local FONT = Enum.Font.FredokaOne
local BANNER_TOP = 160 -- px desde arriba donde empiezan los carteles grandes (debajo de los cartelitos de arriba)
local TUTORIAL_SPACE = 76 -- si el tutorial está activo, su cartel ocupa ese lugar: bajamos los nuestros
local TUTORIAL_DONE = 5 -- igual que en TutorialService
local EVENT_BANNER_TIME = 5 -- segundos que se ve el cartel grande del evento
local WAVE_COLOR = Color3.fromRGB(168, 238, 246)
local RED = Color3.fromRGB(255, 80, 80)

local phaseLabel: TextLabel
local eventPill: Frame
local eventPillLabel: TextLabel
local banner: TextLabel
local bannerHint: TextLabel
local bannerCount: TextLabel
local eventTitle: TextLabel
local eventDescription: TextLabel
local eventShownAt = -math.huge
local warningSound: Sound
local waveSound: Sound
local waveModel: Model? = nil
local fading = false
local lastBeepSecond = -1

local function stroke(label: TextLabel, thickness: number)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Parent = label
end

local function attribute(name: string): any
	return Workspace:GetAttribute(name)
end

local function phase(): string
	local value = attribute("WavePhase")
	return if typeof(value) == "string" then value else ""
end

local function untilTime(name: string): number
	local at = attribute(name)
	if typeof(at) ~= "number" then
		return 0
	end
	return math.max(0, at - Workspace:GetServerTimeNow())
end

local function formatTime(seconds: number): string
	local s = math.ceil(seconds)
	return string.format("%d:%02d", s // 60, s % 60)
end

local function currentEvent(): Config.EventInfo?
	local id = attribute("Event")
	return if typeof(id) == "string" then Config.GetEvent(id) else nil
end

local function isSuper(): boolean
	return attribute("WaveKind") == "Super"
end

local function inCanyon(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and root.Position.X > Config.Map.CanyonStartX
end

-- ===== Armado =====

local function bigLabel(gui: ScreenGui, size: UDim2, color: Color3, thickness: number): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, BANNER_TOP)
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = color
	label.Visible = false
	label.Parent = gui
	stroke(label, thickness)
	return label
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WaveUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Cartelito de arriba: cuánto falta para la ola
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 62)
	pill.Size = UDim2.fromOffset(320, 46)
	pill.BackgroundColor3 = UIKit.Colors.Panel
	pill.BackgroundTransparency = 0.15
	pill.Parent = gui
	UIKit.Corner(pill, 23)
	UIKit.FitToScreen(pill, Vector2.new(320, 46), Vector2.new(24, 0))
	phaseLabel = UIKit.Label(pill, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 26)
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Center
	stroke(phaseLabel, 2)

	-- Debajo: el evento activo (si hay)
	eventPill = Instance.new("Frame")
	eventPill.AnchorPoint = Vector2.new(0.5, 0)
	eventPill.Position = UDim2.new(0.5, 0, 0, 114)
	eventPill.Size = UDim2.fromOffset(280, 34)
	eventPill.BackgroundColor3 = UIKit.Colors.Panel
	eventPill.BackgroundTransparency = 0.15
	eventPill.Visible = false
	eventPill.Parent = gui
	UIKit.Corner(eventPill, 17)
	UIKit.FitToScreen(eventPill, Vector2.new(280, 34), Vector2.new(24, 0))
	eventPillLabel = UIKit.Label(eventPill, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 20)
	eventPillLabel.TextXAlignment = Enum.TextXAlignment.Center
	stroke(eventPillLabel, 1.5)

	banner = bigLabel(gui, UDim2.fromScale(0.8, 0.11), RED, 4)
	bannerHint = bigLabel(gui, UDim2.fromScale(0.6, 0.05), Color3.new(1, 1, 1), 3)
	bannerCount = bigLabel(gui, UDim2.fromScale(0.3, 0.11), Color3.new(1, 1, 1), 4)
	eventTitle = bigLabel(gui, UDim2.fromScale(0.75, 0.1), Color3.new(1, 1, 1), 4)
	eventDescription = bigLabel(gui, UDim2.fromScale(0.7, 0.05), Color3.new(1, 1, 1), 3)
end

local function buildSounds()
	warningSound = Instance.new("Sound")
	warningSound.SoundId = Config.Waves.WarningSoundId
	warningSound.Volume = 0.8
	warningSound.Parent = Workspace

	waveSound = Instance.new("Sound")
	waveSound.SoundId = Config.Waves.WaveSoundId
	waveSound.Volume = 1
	waveSound.Parent = Workspace
end

-- La ola: pared de agua del ancho del cañón, con espuma blanca saliendo del frente
local function buildWave(height: number): Model
	local waves = Config.Waves
	local model = Instance.new("Model")
	model.Name = "Wave"

	local water = Instance.new("Part")
	water.Name = "Water"
	water.Size = Vector3.new(waves.Thickness, height, waves.Width)
	water.Color = WAVE_COLOR
	water.Material = Enum.Material.Glass
	water.Transparency = 0.3
	water.Anchored = true
	water.CanCollide = false
	water.CanQuery = false
	water.CanTouch = false
	water.Parent = model
	model.PrimaryPart = water

	local foam = Instance.new("ParticleEmitter")
	foam.Name = "Foam"
	foam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	foam.EmissionDirection = Enum.NormalId.Left -- el frente de la ola mira a -X (hacia el lobby)
	foam.Rate = 120
	foam.Lifetime = NumberRange.new(0.6, 1.2)
	foam.Speed = NumberRange.new(10, 18)
	foam.SpreadAngle = Vector2.new(30, 60)
	foam.Size = NumberSequence.new(2.5, 0.5)
	foam.Transparency = NumberSequence.new(0.1, 1)
	foam.Parent = water

	model.Parent = Workspace
	return model
end

-- Dónde está el frente de la ola ahora (misma fórmula que el servidor)
local function waveFrontX(): number?
	local startedAt = attribute("WaveStartedAt")
	local startX = attribute("WaveStartX")
	local speed = attribute("WaveSpeed")
	if typeof(startedAt) ~= "number" or typeof(startX) ~= "number" or typeof(speed) ~= "number" then
		return nil
	end
	local front = startX - speed * (Workspace:GetServerTimeNow() - startedAt)
	return math.max(front, Config.Waves.EndX)
end

-- Al llegar al portal la ola se desvanece
local function fadeWave()
	local model = waveModel
	if not model or fading then
		return
	end
	fading = true
	local water = model:FindFirstChild("Water")
	if water and water:IsA("BasePart") then
		local foam = water:FindFirstChild("Foam")
		if foam and foam:IsA("ParticleEmitter") then
			foam.Enabled = false
		end
		TweenService:Create(water, TweenInfo.new(Config.Waves.FadeTime), { Transparency = 1 }):Play()
	end
	waveSound:Stop()
	task.delay(Config.Waves.FadeTime, function()
		model:Destroy()
		if waveModel == model then
			waveModel = nil
		end
		fading = false
	end)
end

-- Cuando empieza un evento: el cartel aparece con un "pop"
local function onEventChanged()
	local event = currentEvent()
	if not event then
		return
	end
	eventTitle.Text = `⚡ {event.DisplayName} ⚡`
	eventTitle.TextColor3 = event.Color
	eventDescription.Text = event.Description
	eventShownAt = os.clock()
	local scale = eventTitle:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = eventTitle
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- La cámara tiembla un poco (solo si estás en el cañón)
local function shakeCamera(strength: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.CameraOffset = if strength > 0
			then Vector3.new(math.sin(os.clock() * 37) * strength, math.sin(os.clock() * 53) * strength, 0)
			else Vector3.zero
	end
end

-- ===== Cada frame =====

local function update()
	local current = phase()
	local left = untilTime("PhaseEndsAt")
	local super = isSuper()

	-- Cartelito de arriba
	if current == "Warning" then
		phaseLabel.Text = if super then `SUPER TSUNAMI {formatTime(left)}` else `WAVE INCOMING {formatTime(left)}`
		phaseLabel.TextColor3 = RED
	elseif current == "Wave" then
		phaseLabel.Text = if super then "SUPER TSUNAMI!" else "WAVE!"
		phaseLabel.TextColor3 = RED
	else
		phaseLabel.Text = `🌋 NEXT WAVE {formatTime(left)}`
		phaseLabel.TextColor3 = Color3.fromRGB(150, 230, 255)
	end

	local event = currentEvent()
	eventPill.Visible = event ~= nil
	if event then
		eventPillLabel.Text = `{event.DisplayName}  {formatTime(untilTime("EventEndsAt"))}`
		eventPillLabel.TextColor3 = event.Color
	end

	-- Carteles grandes: debajo del cartel del tutorial si está activo
	local step = player:GetAttribute("TutorialStep")
	local top = BANNER_TOP + (if typeof(step) == "number" and step < TUTORIAL_DONE then TUTORIAL_SPACE else 0)
	banner.Position = UDim2.new(0.5, 0, 0, top)
	bannerHint.Position = UDim2.new(0.5, 0, 0.11, top + 4)
	bannerCount.Position = UDim2.new(0.5, 0, 0.16, top + 8)
	eventTitle.Position = UDim2.new(0.5, 0, 0, top)
	eventDescription.Position = UDim2.new(0.5, 0, 0.1, top + 6)

	-- Aviso: cartel que late, cuenta regresiva, cuerno y temblor
	local warning = current == "Warning"
	banner.Visible = warning
	bannerHint.Visible = warning
	bannerCount.Visible = warning
	if warning then
		banner.Text = if super then "🌊 SUPER TSUNAMI! 🌊" else "THE WAVE IS COMING!"
		banner.TextColor3 = if super then Color3.fromRGB(200, 120, 255) else RED
		bannerHint.Text = if inCanyon() then "Hide in a cave!" else "Stay on the island!"
		local second = math.ceil(left)
		bannerCount.Text = tostring(second)
		local pulse = 1 + 0.08 * math.sin(os.clock() * 10)
		banner.Size = UDim2.fromScale(0.8 * pulse, 0.11 * pulse)
		if second ~= lastBeepSecond and second > 0 then
			lastBeepSecond = second
			warningSound:Play()
		end
	else
		lastBeepSecond = -1
	end
	local shaking = (warning or current == "Wave") and inCanyon()
	shakeCamera(if shaking then (if super then 0.35 else 0.15) else 0)

	-- Cartel grande del evento, los primeros segundos (salvo durante el aviso de ola)
	local showEvent = event ~= nil and os.clock() - eventShownAt < EVENT_BANNER_TIME and not warning
	eventTitle.Visible = showEvent
	eventDescription.Visible = showEvent

	-- La ola
	if current == "Wave" then
		local front = waveFrontX()
		if front then
			local heightValue = attribute("WaveHeight")
			local height = if typeof(heightValue) == "number" then heightValue else Config.Waves.Normal.Height
			if not waveModel and not fading then
				waveModel = buildWave(height)
				waveSound:Play()
			end
			local model = waveModel
			if model and not fading then
				local water = model:FindFirstChild("Water")
				if water and water:IsA("BasePart") then
					water.CFrame = CFrame.new(front + Config.Waves.Thickness / 2, Config.Map.FloorY + height / 2, 0)
				end
				if front <= Config.Waves.EndX then
					fadeWave()
				end
			end
		end
	elseif waveModel then
		fadeWave()
	end
end

function WaveClient.Start()
	buildGui()
	buildSounds()
	Workspace:GetAttributeChangedSignal("Event"):Connect(onEventChanged)
	onEventChanged()
	RunService.RenderStepped:Connect(update)
end

return WaveClient

end
__loaders['Notifier'] = function()
--!strict
-- Notifier: avisos cortos en pantalla ("You grabbed a Rare Egg!", "Not enough coins!"...).
-- Aparecen abajo en el centro, se apilan (máximo 3) y se desvanecen solos.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIKit = __req("UIKit")

local player = Players.LocalPlayer

local Notifier = {}

local MAX_TOASTS = 3
local TOAST_HEIGHT = 46
local TOAST_GAP = 8

local container: Frame? = nil
local toasts: { CanvasGroup } = {}

local function getContainer(): Frame
	if container then
		return container
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Toasts"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -20) -- bien abajo, para no tapar la ventana de mejoras
	frame.Size = UDim2.fromOffset(520, (TOAST_HEIGHT + TOAST_GAP) * MAX_TOASTS)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	UIKit.FitToScreen(frame, Vector2.new(520, 160), Vector2.new(24, 260))
	container = frame
	return frame
end

-- Acomoda los avisos: el más nuevo abajo de todo
local function layout()
	for i, toast in toasts do
		local fromBottom = #toasts - i
		local y = -(fromBottom * (TOAST_HEIGHT + TOAST_GAP))
		TweenService:Create(toast, TweenInfo.new(0.2), { Position = UDim2.new(0.5, 0, 1, y) }):Play()
	end
end

local function remove(toast: CanvasGroup)
	local index = table.find(toasts, toast)
	if not index then
		return
	end
	table.remove(toasts, index)
	local fade = TweenService:Create(toast, TweenInfo.new(0.3), { GroupTransparency = 1 })
	fade.Completed:Connect(function()
		toast:Destroy()
	end)
	fade:Play()
	layout()
end

function Notifier.Show(text: string, duration: number?, color: Color3?)
	local parent = getContainer()

	-- CanvasGroup deja desvanecer todo el aviso junto (fondo + texto)
	local toast = Instance.new("CanvasGroup")
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, 0)
	toast.Size = UDim2.fromOffset(500, TOAST_HEIGHT)
	toast.BackgroundColor3 = Color3.fromRGB(25, 27, 42)
	toast.BackgroundTransparency = 0.15
	toast.GroupTransparency = 1
	toast.Parent = parent
	UIKit.Corner(toast, 14)

	local label = UIKit.Label(toast, text, UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), 22, color or UIKit.Colors.Text)
	label.TextXAlignment = Enum.TextXAlignment.Center

	table.insert(toasts, toast)
	if #toasts > MAX_TOASTS then
		remove(toasts[1])
	end
	layout()
	TweenService:Create(toast, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()

	task.delay(duration or 3.5, remove, toast)
end

return Notifier

end
__loaders['HatchReveal'] = function()
--!strict
-- HatchReveal: la animación de apertura del huevo (lo que la gente graba).
--   1) Durante Config.Effects.HatchAnimationTime segundos el huevo de la incubadora tiembla
--      cada vez más fuerte y brilla cada vez más (con el color de su rareza).
--   2) Explota: destello + chispas, y el huevo desaparece.
--   3) Aparece el cartel grande "YOU GOT / Golden Dragon / LEGENDARY" con rayos de luz girando.
--      Si el huevo tenía variante, se ve en la línea de la rareza ("GOLDEN LEGENDARY") y en la plata (x3).
-- Todo esto pasa solo en la pantalla del dueño. El servidor espera el mismo tiempo antes de poner la mascota.
-- Si se abren varios huevos juntos, los carteles se muestran de a uno (en fila).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = __req("Config")
local Remotes = __req("Remotes")
local UIKit = __req("UIKit")

type Rarity = Config.Rarity
type Variant = Config.Variant

local player = Players.LocalPlayer

local HatchReveal = {}

local DESIGN = Vector2.new(700, 420)
-- Qué tan "fuerte" es el festejo según la rareza (rayos, destello en pantalla)
local INTENSITY: { [string]: number } = { Common = 0.3, Rare = 0.5, Epic = 0.75, Legendary = 0.9, Mythic = 1, Secret = 1 }

local gui: ScreenGui
local flash: Frame
local hatchSound: Sound
local queue: { { Name: string, Rarity: Rarity, Variant: Variant } } = {}
local showing = false

-- ===== 1 y 2: el huevo tiembla, brilla y explota =====

local function explode(position: Vector3, color: Color3)
	-- Esfera de luz que se agranda y se desvanece
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2, 2, 2)
	ball.CFrame = CFrame.new(position)
	ball.Color = color
	ball.Material = Enum.Material.Neon
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Parent = Workspace
	TweenService:Create(ball, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(16, 16, 16),
		Transparency = 1,
	}):Play()

	-- Chispas
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(20, 35)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(1, 0)
	sparks.Drag = 3
	sparks.Parent = holder
	sparks:Emit(80)

	task.delay(1.5, function()
		ball:Destroy()
		holder:Destroy()
	end)
end

-- Color del festejo: el de la variante si tiene, si no el de la rareza (blanco para Secret)
local function revealColor(rarity: Rarity, variant: Variant): Color3
	return if variant.Id ~= "Normal" then variant.Color
		elseif rarity.Id == "Secret" then Color3.new(1, 1, 1)
		else rarity.Color
end

local function animateEgg(eggPart: BasePart, rarity: Rarity, variant: Variant)
	local duration = Config.Effects.HatchAnimationTime
	local color = revealColor(rarity, variant)
	local baseCFrame = eggPart.CFrame

	-- Brillo que crece (solo en esta pantalla: los cambios del cliente no le llegan a nadie más)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Adornee = eggPart
	highlight.Parent = eggPart
	local light = eggPart:FindFirstChildOfClass("PointLight")

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		if not eggPart.Parent then
			connection:Disconnect()
			return
		end
		-- Tiembla cada vez más fuerte y más rápido
		local strength = 0.05 + t * t * 0.45
		local speed = 18 + t * 30
		local now = os.clock()
		local wobble = CFrame.Angles(math.sin(now * speed) * strength, 0, math.cos(now * speed * 1.3) * strength)
		eggPart.CFrame = baseCFrame * CFrame.new(0, math.abs(math.sin(now * speed * 0.5)) * t * 0.6, 0) * wobble
		highlight.FillTransparency = 1 - t * 0.85
		highlight.OutlineTransparency = 1 - t
		if light then
			light.Brightness = 1 + t * 8
			light.Range = 8 + t * 10
		end
		if t >= 1 then
			connection:Disconnect()
			eggPart.Transparency = 1
			highlight:Destroy()
			explode(eggPart.Position, color)
		end
	end)
end

-- ===== 3: el cartel =====

local function makeRays(parent: Instance, color: Color3, intensity: number): Frame
	local rays = Instance.new("Frame")
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(10, 10)
	rays.BackgroundTransparency = 1
	rays.Parent = parent
	local count = math.floor(6 + intensity * 10)
	for i = 1, count do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		-- No más largos que el cartel (el CanvasGroup recorta lo que se sale)
		ray.Size = UDim2.fromOffset(28 + intensity * 30, 300 + intensity * 110)
		ray.Rotation = (i / count) * 180
		ray.BackgroundColor3 = color
		ray.BorderSizePixel = 0
		ray.Parent = rays
		-- Más transparente en las puntas que en el centro
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.6 + (1 - intensity) * 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = ray
	end
	return rays
end

local function showBanner(name: string, rarity: Rarity, variant: Variant)
	local hasVariant = variant.Id ~= "Normal"
	-- Una variante buena festeja como una rareza alta
	local intensity = math.max(INTENSITY[rarity.Id] or 0.5, if hasVariant then math.min(1, 0.5 + variant.Multiplier / 20) else 0)
	local special = Config.RarityRank(rarity.Id) >= Config.RarityRank("Legendary") or variant.Multiplier >= 5
	local color = revealColor(rarity, variant)
	local nameColor = if rarity.Id == "Secret" then Color3.new(1, 1, 1) else rarity.Color

	-- Destello en toda la pantalla (más fuerte para las raras)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - intensity * 0.6
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	if hatchSound.SoundId ~= "" then
		hatchSound:Play()
	end

	-- CanvasGroup: deja desvanecer todo el cartel junto al final
	local group = Instance.new("CanvasGroup")
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.42)
	group.Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y)
	group.BackgroundTransparency = 1
	group.Parent = gui
	UIKit.FitToScreen(group, DESIGN, Vector2.new(20, 40))
	local pop = Instance.new("UIScale")
	pop.Scale = 0
	pop.Parent = group

	local rays = makeRays(group, color, intensity)

	-- Fondo oscuro detrás del texto, para que siempre se lea (aunque los rayos sean del mismo color)
	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.fromOffset(DESIGN.X / 2, 84)
	plate.Size = UDim2.fromOffset(620, 246)
	plate.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
	plate.BackgroundTransparency = 0.3
	plate.Parent = group
	UIKit.Corner(plate, 28)
	UIKit.Stroke(plate, 4, color).Transparency = 0.2

	local function bigLabel(text: string, y: number, height: number, size: number, textColor: Color3, strokeSize: number): TextLabel
		local label = UIKit.Label(group, text, UDim2.fromOffset(DESIGN.X, height), UDim2.fromOffset(0, y), size, textColor)
		label.TextXAlignment = Enum.TextXAlignment.Center
		UIKit.Stroke(label, strokeSize)
		return label
	end
	bigLabel("YOU GOT", 92, 40, 34, Color3.new(1, 1, 1), 3)
	local nameLabel = bigLabel(name, 132, 90, if #name > 16 then 58 else 72, nameColor, 5)
	local rarityText = string.upper(Config.WithVariant(variant, rarity.DisplayName))
	local rarityLabel = bigLabel(rarityText, 222, 56, 46, if hasVariant then variant.Color else nameColor, 4)
	local income = Config.GetIncome(rarity, variant)
	local incomeText = if hasVariant then `+{income} coins/sec  (x{variant.Multiplier})` else `+{income} coins/sec`
	bigLabel(incomeText, 284, 36, 28, Color3.fromRGB(130, 255, 130), 3)

	-- Arcoíris animado (Secret o variante Rainbow), brillo que pasa (Legendary o cualquier otra variante)
	local gradients: { UIGradient } = {}
	local function addRainbow(label: TextLabel)
		local g = Instance.new("UIGradient")
		g.Color = UIKit.Rainbow
		g.Parent = label
		table.insert(gradients, g)
	end
	local function addShine(label: TextLabel, base: Color3)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, base),
			ColorSequenceKeypoint.new(0.45, base),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 0.85)),
			ColorSequenceKeypoint.new(0.55, base),
			ColorSequenceKeypoint.new(1, base),
		})
		g.Parent = label
		table.insert(gradients, g)
	end
	if rarity.Id == "Secret" then
		addRainbow(nameLabel)
	elseif rarity.Id == "Legendary" or rarity.Id == "Mythic" then
		addShine(nameLabel, rarity.Color)
	end
	if variant.Id == "Rainbow" or (rarity.Id == "Secret" and not hasVariant) then
		addRainbow(rarityLabel)
	elseif hasVariant then
		addShine(rarityLabel, variant.Color)
	elseif rarity.Id == "Legendary" or rarity.Id == "Mythic" then
		addShine(rarityLabel, rarity.Color)
	end

	-- Entra con un "pop", los rayos giran y los degradés se mueven
	TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local started = os.clock()
	local spin = RunService.RenderStepped:Connect(function(dt: number)
		rays.Rotation += dt * (20 + intensity * 25)
		local t = os.clock() - started
		for _, g in gradients do
			g.Offset = Vector2.new(((t * 0.6) % 2) - 1, 0)
		end
	end)

	local hold = Config.Effects.RevealDuration + (if special then 1 else 0)
	task.wait(hold)
	local fade = TweenService:Create(group, TweenInfo.new(0.4), { GroupTransparency = 1 })
	fade:Play()
	fade.Completed:Wait()
	spin:Disconnect()
	group:Destroy()
end

local function processQueue()
	if showing then
		return
	end
	showing = true
	while #queue > 0 do
		local item = table.remove(queue, 1)
		if item then
			showBanner(item.Name, item.Rarity, item.Variant)
		end
	end
	showing = false
end

local function onHatched(creatureName: unknown, rarityId: unknown, eggPart: unknown, variantId: unknown)
	if typeof(creatureName) ~= "string" or typeof(rarityId) ~= "string" then
		return
	end
	local rarity = Config.GetRarity(rarityId)
	if not rarity then
		return
	end
	local variant = Config.GetVariant(if typeof(variantId) == "string" then variantId else nil)
	if typeof(eggPart) == "Instance" and eggPart:IsA("BasePart") then
		animateEgg(eggPart, rarity, variant)
	end
	-- El cartel aparece justo cuando explota el huevo
	task.delay(Config.Effects.HatchAnimationTime, function()
		table.insert(queue, { Name = creatureName, Rarity = rarity, Variant = variant })
		processQueue()
	end)
end

function HatchReveal.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "HatchReveal"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	hatchSound = Instance.new("Sound")
	hatchSound.SoundId = Config.Effects.HatchSoundId
	hatchSound.Volume = 0.8
	hatchSound.Parent = gui

	Remotes.Event("Hatched").OnClientEvent:Connect(onHatched)
end

return HatchReveal

end
__loaders['IncubatorPrompts'] = function()
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

end
local function __mod(n) return __req(n) end
task.spawn(function()
local rf = Instance.new("Folder"); rf.Name = "Remotes"; rf.Parent = game:GetService("ReplicatedStorage")
for _, n in { "BuyUpgrade", "Notify", "Hatched", "TutorialAction", "Trade" } do local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = rf end
local ws = game:GetService("Workspace")
rawget(ws, "_props").GetServerTimeNow = function() return NOW end
LOCAL:SetAttribute("Coins", 250000); LOCAL:SetAttribute("Income", 245)
__mod("Hud").Start()
local panel = __mod("TradePanel")
panel.Start()
panel.ShowInvite("Carl", 903)
ADVANCE(0.2)
DUMP_GUI(LOCAL.PlayerGui)

end)
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
local PART_CLASSES = { Part = true }
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

return Format

end
__loaders['Upgrades'] = function()
--!strict
-- Upgrades: la definición de cada mejora (nivel, máximo, precio y descripción).
-- La usan el servidor (para cobrar y aplicar) y el cliente (para mostrar el panel),
-- así los dos siempre muestran y cobran lo mismo. Los números salen de Config.Upgrades.

local Config = __req("Config")

-- "IncubationSpeed", "ExtraIncubator", "WalkSpeed" o "BaseFloor" (ver Upgrades.IsValid)
export type UpgradeId = string

-- Los niveles actuales del jugador (los mismos campos que el perfil del servidor)
export type State = {
	IncubationSpeedLevel: number,
	IncubatorCount: number,
	WalkSpeedLevel: number,
	BaseLevel: number,
}

local Upgrades = {}

-- Orden en el que aparecen en el panel
Upgrades.Order = { "IncubationSpeed", "ExtraIncubator", "WalkSpeed", "BaseFloor" } :: { UpgradeId }

Upgrades.DisplayNames = {
	IncubationSpeed = "Incubation Speed",
	ExtraIncubator = "Extra Incubator",
	WalkSpeed = "Walk Speed",
	BaseFloor = "Base Floor",
} :: { [UpgradeId]: string }

local MAX_BASE_LEVEL = 2

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
	elseif id == "WalkSpeed" then
		return state.WalkSpeedLevel, #cfg.WalkSpeed
	else
		return state.BaseLevel, MAX_BASE_LEVEL
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
	elseif id == "WalkSpeed" then
		return cfg.WalkSpeed[current + 1].Cost
	else
		return cfg.BaseFloor.Cost
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
	elseif id == "WalkSpeed" then
		if maxed then
			return `Speed: {cfg.WalkSpeed[current].Speed}`
		end
		return `Speed: {cfg.WalkSpeed[current].Speed} → {cfg.WalkSpeed[current + 1].Speed}`
	else
		if maxed then
			return "2nd floor built!"
		end
		return `Build a 2nd floor (+{cfg.BaseFloor.ExtraCreatureSlots} creature spots)`
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
	if RunService:IsServer() then
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
	if RunService:IsServer() then
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
	Weight: number, -- probabilidad relativa (los pesos suman 100)
	BaseIncubationTime: number, -- segundos, antes de aplicar mejoras
	CoinsPerSecond: number, -- plata que genera la criatura que sale de este huevo
	-- Tramo del pasillo donde caen estos huevos, como fracción del largo
	-- (0 = línea de la zona segura, 1 = fondo del pasillo, donde nace la ola).
	-- Cada rareza tiene su tramo: cuanto más rara, más lejos de las bases. El piso se pinta por tramos.
	ZoneStart: number,
	ZoneEnd: number,
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

-- ===== Mapa =====
-- Forma de T. Eje Z: el lobby (zona segura con las bases en fila) queda en Z < 0,
-- la línea segura está en Z = 0 y el pasillo de arena va de Z = 0 hasta Z = CorridorLength.
-- El ancho y el largo del lobby se calculan solos a partir de la cantidad y el tamaño de las bases.
Config.Map = {
	FloorY = 0, -- altura del piso
	CorridorWidth = 240, -- ancho del pasillo de arena
	CorridorLength = 800, -- largo del pasillo de arena (zona de peligro)
	SeaDepth = 25, -- franja de agua al fondo del pasillo, de donde sale la ola
	WallHeight = 80,
	WallThickness = 10,
	EggSideMargin = 25, -- los huevos no caen en la franja de decoración junto a las paredes

	BaseCount = 8, -- todas en una fila, mirando hacia el pasillo
	PlotWidth = 44, -- ancho de cada parcela
	PlotDepth = 60, -- profundidad de cada parcela (incubadoras adelante, mascotas a los costados)
	PlotGap = 16, -- espacio entre parcelas (y entre las parcelas de las puntas y la pared)
	LobbyFrontWalk = 50, -- espacio para caminar entre las bases y la línea segura
	LobbyBackMargin = 24, -- espacio detrás de las bases (ahí va el cartel con el nombre)

	GrassColor = Color3.fromRGB(80, 220, 70),
	SandColor = Color3.fromRGB(240, 215, 160),
	WallColor = Color3.fromRGB(215, 120, 85),
	WallTrimColor = Color3.fromRGB(90, 200, 90),
	SeaColor = Color3.fromRGB(40, 150, 255),

	-- Un color por base, en orden (Base1, Base2, ...)
	BaseColors = {
		Color3.fromRGB(255, 99, 99), -- rojo
		Color3.fromRGB(255, 170, 70), -- naranja
		Color3.fromRGB(255, 230, 90), -- amarillo
		Color3.fromRGB(120, 220, 120), -- verde
		Color3.fromRGB(90, 200, 255), -- celeste
		Color3.fromRGB(110, 130, 255), -- azul
		Color3.fromRGB(190, 120, 255), -- violeta
		Color3.fromRGB(255, 130, 210), -- rosa
	},
}

-- ===== Huevos (se usan desde la fase 2) =====
Config.Rarities = {
	{
		Id = "Common",
		DisplayName = "Common",
		Color = Color3.fromRGB(245, 245, 245),
		Weight = 60,
		BaseIncubationTime = 30,
		CoinsPerSecond = 1,
		ZoneStart = 0.05,
		ZoneEnd = 0.4,
	},
	{
		Id = "Rare",
		DisplayName = "Rare",
		Color = Color3.fromRGB(70, 140, 255),
		Weight = 25,
		BaseIncubationTime = 60,
		CoinsPerSecond = 5,
		ZoneStart = 0.4,
		ZoneEnd = 0.65,
	},
	{
		Id = "Epic",
		DisplayName = "Epic",
		Color = Color3.fromRGB(170, 80, 255),
		Weight = 10,
		BaseIncubationTime = 90,
		CoinsPerSecond = 20,
		ZoneStart = 0.65,
		ZoneEnd = 0.83,
	},
	{
		Id = "Legendary",
		DisplayName = "Legendary",
		Color = Color3.fromRGB(255, 200, 40),
		Weight = 4.5,
		BaseIncubationTime = 120,
		CoinsPerSecond = 100,
		ZoneStart = 0.83,
		ZoneEnd = 0.94,
	},
	{
		Id = "Secret",
		DisplayName = "Secret",
		Color = Color3.fromRGB(20, 20, 25), -- negro; el brillo arcoíris se agrega con efectos
		Weight = 0.5,
		BaseIncubationTime = 180,
		CoinsPerSecond = 500,
		ZoneStart = 0.94,
		ZoneEnd = 1,
	},
} :: { Rarity }

Config.Eggs = {
	SpawnInterval = 2, -- segundos entre huevo y huevo mientras llueve
	MaxOnGround = 25, -- si ya hay esta cantidad en el piso (o cayendo), no cae ninguno más
	FallHeight = 150, -- desde qué altura caen
	FallTime = 2.5, -- cuánto tarda la caída (segundos)
	GrabHoldTime = 0.25, -- cuánto hay que mantener apretada la tecla para agarrar
	GrabDistance = 10, -- distancia máxima para agarrar (studs)
	GrabCooldown = 0.5, -- tiempo mínimo entre intentos de agarrar (anti-spam)
	CarryHeight = 2.5, -- cuántos studs sobre la cabeza se lleva el huevo
}

-- ===== Incubadoras y plata (fase 3) =====
Config.Incubators = {
	HoldTime = 0.3, -- cuánto mantener apretada la tecla para poner el huevo
	Distance = 12, -- distancia máxima para usar la incubadora (studs)
	Cooldown = 0.5, -- tiempo mínimo entre intentos (anti-spam)
}

Config.Economy = {
	StartingCoins = 0,
	IncomeInterval = 1, -- cada cuántos segundos se cobra la plata de las mascotas
}

-- ===== Guardado (fase 7) =====
Config.Data = {
	-- Nombre del DataStore. Si lo cambiás, todos empiezan de cero (los datos viejos quedan en el nombre anterior).
	StoreName = "EggStorm_PlayerData_v1",
	AutosaveInterval = 60, -- cada cuántos segundos se guarda a todos los que están jugando
	MaxAttempts = 4, -- cuántas veces se reintenta si Roblox falla al leer o guardar
	RetryDelay = 1, -- segundos de espera entre reintentos (va creciendo: 1, 2, 3...)
}

-- ===== Efectos e interfaz (fase 6) =====
Config.Effects = {
	HatchAnimationTime = 3, -- segundos que el huevo tiembla y brilla antes de abrirse
	RevealDuration = 3, -- segundos que queda el cartel "You got..." (los Legendary y Secret, uno más)
	-- Sonidos (podés cambiarlos por IDs de la Creator Store, ej: "rbxassetid://1234567"; "" = sin sonido)
	HatchSoundId = "rbxasset://sounds/electronicpingshort.wav",
}

-- ===== Mejoras (fase 4) =====
Config.Upgrades = {
	PanelDistance = 12, -- distancia máxima al panel de mejoras para poder comprar (studs)
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

	-- Incubadoras extra
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

	-- "Mejorar base": segundo piso con más lugares para mascotas
	BaseFloor = {
		Cost = 5000,
		ExtraCreatureSlots = 6,
	},
}

-- ===== Tormenta y ola (fase 5) =====
-- Ciclo: lluvia → aviso → ola → calma → lluvia...
Config.Storm = {
	RainDuration = 60, -- segundos de lluvia de huevos (cielo oscuro)
	WarningDuration = 10, -- segundos del cartel "WAVE INCOMING"
	CalmDuration = 20, -- segundos de calma después de la ola

	WaveSpeed = 70, -- studs por segundo (recorre los 825 studs del pasillo en ~12 s)
	WaveHeight = 35, -- altura de la pared de agua
	WaveThickness = 30, -- grosor de la pared de agua
	RespawnTime = 3, -- segundos hasta reaparecer en tu base después de que te agarra la ola

	-- Sonidos (podés cambiarlos por IDs de la Creator Store, ej: "rbxassetid://1234567"; "" = sin sonido)
	WarningSoundId = "rbxasset://sounds/electronicpingshort.wav",
	WaveSoundId = "",
}

-- ===== Ayudantes =====
local raritiesById: { [string]: Rarity } = {}
for _, rarity in Config.Rarities do
	raritiesById[rarity.Id] = rarity
end

function Config.GetRarity(id: string): Rarity?
	return raritiesById[id]
end

-- Segundos que tarda un huevo de esta rareza con el nivel de "Incubation Speed" dado (con el mínimo aplicado).
function Config.GetIncubationTime(rarity: Rarity, speedLevel: number): number
	local levels = Config.Upgrades.IncubationSpeed
	local level = levels[math.clamp(speedLevel, 1, #levels)]
	return math.max(Config.Upgrades.MinIncubationTime, rarity.BaseIncubationTime * level.Multiplier)
end

return Config

end
__loaders['IncubatorService'] = function()
--!strict
-- IncubatorService: las incubadoras de cada base.
-- El jugador llega con un huevo, aprieta "Incubate", el huevo queda adentro con una cuenta regresiva
-- y al terminar se abre: sale una mascota que va a un pad libre de la base.
--
-- Cada huevo incubando es un objeto del servidor (IncubatingEgg) con su dueño, rareza y tiempo.
-- Así más adelante es fácil agregar el robo: alcanza con sacar el IncubatingEgg de una incubadora.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = __req("Config")
local Remotes = __req("Remotes")
local BaseService = __req("BaseService")
local PlayerDataService = __req("PlayerDataService")
local EggService = __req("EggService")
local CreatureService = __req("CreatureService")
local Creatures = __req("Creatures")

type Base = BaseService.Base
type Rarity = Config.Rarity

export type IncubatingEgg = {
	Id: number,
	Owner: Player,
	Rarity: Rarity,
	TotalTime: number, -- segundos que tarda en total (con la mejora de velocidad aplicada)
	HatchAt: number, -- os.clock() en el que se abre
	Part: BasePart,
	Hatching: boolean, -- true mientras corre la animación de apertura (unos segundos antes de que salga la mascota)
}

export type Incubator = {
	Owner: Player,
	Base: Base,
	Slot: number,
	Model: Model,
	Root: BasePart,
	Dome: BasePart,
	Prompt: ProximityPrompt,
	Title: TextLabel,
	Timer: TextLabel,
	Egg: IncubatingEgg?,
}

local IncubatorService = {}

local incubatorsByPlayer: { [Player]: { Incubator } } = {}
local lockedSignsByPlayer: { [Player]: { [number]: Instance } } = {}
local lastAttempt: { [Player]: number } = {}
local nextEggId = 0

local notifyRemote = Remotes.Event("Notify")
local hatchedRemote = Remotes.Event("Hatched")

local METAL = Color3.fromRGB(90, 95, 110)
local GLOW = Color3.fromRGB(255, 170, 60)

-- ===== Ayudantes visuales =====

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Parent = parent
	return p
end

-- Cilindro parado apoyado en "bottom"
local function makeDisc(name: string, height: number, diameter: number, bottom: Vector3, color: Color3, parent: Instance): Part
	local p = makePart(name, Vector3.new(height, diameter, diameter), CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function makeLabel(name: string, parent: Instance, y: number, height: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromScale(1, height)
	label.Position = UDim2.fromScale(0, y)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	return label
end

local function formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- ===== Armado de una incubadora =====

local function padTop(pad: BasePart): Vector3
	-- El pad es un cilindro acostado: su grosor es Size.X
	return pad.Position + Vector3.new(0, pad.Size.X / 2, 0)
end

local function buildIncubator(player: Player, base: Base, slot: number): Incubator
	local pad = base.IncubatorSlots[slot]
	local bottom = padTop(pad)

	local model = Instance.new("Model")
	model.Name = `Incubator{slot}`

	local root = makeDisc("Base", 1.6, 8, bottom, METAL, model)
	local ring = makeDisc("Ring", 0.4, 8.4, bottom + Vector3.new(0, 1.6, 0), GLOW, model)
	ring.Material = Enum.Material.Neon
	local dome = makePart("Dome", Vector3.new(6.5, 6.5, 6.5), CFrame.new(bottom + Vector3.new(0, 4.6, 0)), Color3.fromRGB(200, 240, 255), model)
	dome.Shape = Enum.PartType.Ball
	dome.Material = Enum.Material.Glass
	dome.Transparency = 0.6
	dome.CanCollide = false
	model.PrimaryPart = root

	local gui = Instance.new("BillboardGui")
	gui.Name = "Display"
	gui.Size = UDim2.fromScale(7, 2.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.2, 0)
	gui.MaxDistance = 80
	gui.Parent = dome
	local title = makeLabel("Title", gui, 0, 0.5, Color3.new(1, 1, 1))
	local timer = makeLabel("Timer", gui, 0.5, 0.5, Color3.fromRGB(255, 230, 120))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Incubate"
	prompt.ObjectText = "Incubator"
	prompt.HoldDuration = Config.Incubators.HoldTime
	prompt.MaxActivationDistance = Config.Incubators.Distance
	prompt.RequiresLineOfSight = false
	-- El cliente muestra este prompt solo en su propia base y solo si lleva un huevo (ver IncubatorPrompts).
	prompt:SetAttribute("BaseId", base.Id)
	prompt:SetAttribute("Available", true)
	CollectionService:AddTag(prompt, "IncubatorPrompt")
	prompt.Parent = root

	model.Parent = base.Model

	local incubator: Incubator = {
		Owner = player,
		Base = base,
		Slot = slot,
		Model = model,
		Root = root,
		Dome = dome,
		Prompt = prompt,
		Title = title,
		Timer = timer,
		Egg = nil,
	}
	prompt.Triggered:Connect(function(who)
		IncubatorService.TryIncubate(who, incubator)
	end)
	return incubator
end

local function showEmpty(incubator: Incubator)
	incubator.Title.Text = "Empty"
	incubator.Title.TextColor3 = Color3.new(1, 1, 1)
	incubator.Timer.Text = "Bring an egg!"
	incubator.Prompt:SetAttribute("Available", true)
end

-- Cartel "LOCKED" sobre los pads de incubadoras que todavía no se compraron (fase 4).
local function addLockedSign(player: Player, base: Base, slot: number)
	local pad = base.IncubatorSlots[slot]
	local holder = Instance.new("Part")
	holder.Name = `LockedSlot{slot}`
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(padTop(pad) + Vector3.new(0, 3, 0))
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 1.5)
	gui.MaxDistance = 60
	gui.Parent = holder
	local label = makeLabel("Locked", gui, 0, 1, Color3.fromRGB(200, 200, 200))
	label.Text = "LOCKED"

	holder.Parent = base.Model
	local signs = lockedSignsByPlayer[player]
	if not signs then
		signs = {}
		lockedSignsByPlayer[player] = signs
	end
	signs[slot] = holder
end

-- ===== Huevos dentro de la incubadora =====

local function getIncubators(player: Player): { Incubator }
	return incubatorsByPlayer[player] or {}
end

local function countIncubating(player: Player): number
	local count = 0
	for _, incubator in getIncubators(player) do
		if incubator.Egg then
			count += 1
		end
	end
	return count
end

local function speedLevel(player: Player): number
	local profile = PlayerDataService.Get(player)
	return if profile then profile.IncubationSpeedLevel else 1
end

local function startIncubation(incubator: Incubator, rarity: Rarity, remaining: number?)
	local total = Config.GetIncubationTime(rarity, speedLevel(incubator.Owner))
	local left = math.clamp(remaining or total, 0, total)

	local eggPart = makePart("Egg", Vector3.new(2.4, 3.2, 2.4), CFrame.new(incubator.Dome.Position), rarity.Color, incubator.Model)
	eggPart.CanCollide = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = eggPart
	local light = Instance.new("PointLight")
	light.Color = if rarity.Id == "Secret" then Color3.new(1, 1, 1) else rarity.Color
	light.Range = 8
	light.Parent = eggPart

	nextEggId += 1
	incubator.Egg = {
		Id = nextEggId,
		Owner = incubator.Owner,
		Rarity = rarity,
		TotalTime = total,
		HatchAt = os.clock() + left,
		Part = eggPart :: BasePart,
		Hatching = false,
	}
	incubator.Title.Text = `{rarity.DisplayName} Egg`
	incubator.Title.TextColor3 = if rarity.Id == "Secret" then Color3.fromRGB(230, 230, 230) else rarity.Color
	incubator.Timer.Text = formatTime(left)
	incubator.Prompt:SetAttribute("Available", false)
end

local function burst(position: Vector3, color: Color3, parent: Instance)
	local holder = Instance.new("Part")
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(position)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(12, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Parent = holder
	holder.Parent = parent
	emitter:Emit(40)
	task.delay(1.5, function()
		holder:Destroy()
	end)
end

-- Final de la apertura: sale la mascota y la incubadora queda libre.
local function finishHatch(incubator: Incubator, egg: IncubatingEgg, creature: Creatures.Creature)
	-- Si el dueño se fue durante la animación, no hacemos nada (el huevo quedó guardado en su perfil)
	if incubator.Egg ~= egg or not table.find(getIncubators(incubator.Owner), incubator) then
		return
	end
	local slot = CreatureService.AddCreature(incubator.Owner, creature)
	if not slot then
		-- No hay lugar para la mascota: el huevo espera y reintenta en un rato
		egg.Hatching = false
		egg.HatchAt = os.clock() + 2
		incubator.Timer.Text = "No room!"
		return
	end
	burst(egg.Part.Position, egg.Rarity.Color, incubator.Model)
	egg.Part:Destroy()
	incubator.Egg = nil
	showEmpty(incubator)
end

-- Empieza la apertura: le avisa al dueño (su pantalla hace temblar y brillar el huevo)
-- y unos segundos después sale la mascota. Así la mascota no aparece antes de la animación.
local function hatch(incubator: Incubator)
	local egg = incubator.Egg
	if not egg or egg.Hatching then
		return
	end
	local player = incubator.Owner
	if CreatureService.GetFreeSlotCount(player) <= 0 then
		egg.HatchAt = os.clock() + 2
		incubator.Timer.Text = "No room!"
		return
	end
	local creature = CreatureService.RollCreature(egg.Rarity.Id)
	if not creature then
		warn(`[IncubatorService] No creatures defined for rarity {egg.Rarity.Id}`)
		return
	end

	egg.Hatching = true
	incubator.Timer.Text = "Hatching!"
	hatchedRemote:FireClient(player, creature.DisplayName, egg.Rarity.Id, egg.Part)
	task.delay(Config.Effects.HatchAnimationTime, finishHatch, incubator, egg, creature)
end

-- ===== API pública =====

-- Lo llama el ProximityPrompt "Incubate". Valida TODO en el servidor.
function IncubatorService.TryIncubate(player: Player, incubator: Incubator)
	local now = os.clock()
	if now - (lastAttempt[player] or 0) < Config.Incubators.Cooldown then
		return
	end
	lastAttempt[player] = now

	if incubator.Owner ~= player then
		notifyRemote:FireClient(player, "This isn't your base!")
		return
	end
	if incubator.Egg then
		return
	end
	if not EggService.GetCarriedEgg(player) then
		notifyRemote:FireClient(player, "Grab an egg first!")
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - incubator.Root.Position).Magnitude > Config.Incubators.Distance + 5 then
		return
	end

	-- Cada huevo necesita un pad libre para su mascota (contando los que ya se están incubando)
	if CreatureService.GetFreeSlotCount(player) - countIncubating(player) <= 0 then
		notifyRemote:FireClient(player, "Your creature spots are full!")
		return
	end

	local rarity = EggService.TakeCarriedEgg(player)
	if not rarity then
		return
	end
	startIncubation(incubator, rarity)
end

-- Cuando el jugador recibe su base: arma sus incubadoras y restaura los huevos que tenía.
function IncubatorService.SetupBase(player: Player, base: Base)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	local maxSlots = math.min(Config.Upgrades.MaxIncubators, #base.IncubatorSlots)
	local owned = math.clamp(profile.IncubatorCount, 1, maxSlots)

	local list: { Incubator } = {}
	incubatorsByPlayer[player] = list
	for slot = 1, owned do
		local incubator = buildIncubator(player, base, slot)
		showEmpty(incubator)
		table.insert(list, incubator)
	end
	for slot = owned + 1, maxSlots do
		addLockedSign(player, base, slot)
	end

	-- Huevos que estaban incubando cuando se fue (fase 7)
	for _, data in profile.Incubating do
		local incubator = list[data.Slot]
		local rarity = Config.GetRarity(data.RarityId)
		if incubator and rarity and not incubator.Egg then
			startIncubation(incubator, rarity, data.Remaining)
		end
	end
	profile.Incubating = {}
end

-- Foto de los huevos que se están incubando, para guardarla (fase 7).
function IncubatorService.GetSnapshot(player: Player): { PlayerDataService.IncubatingData }
	local snapshot = {}
	local now = os.clock()
	for _, incubator in getIncubators(player) do
		local egg = incubator.Egg
		if egg then
			table.insert(snapshot, { Slot = incubator.Slot, RarityId = egg.Rarity.Id, Remaining = math.max(0, egg.HatchAt - now) })
		end
	end
	return snapshot
end

-- Cuando el jugador se va: guarda los huevos en su perfil y limpia la base.
function IncubatorService.ClearBase(player: Player)
	local profile = PlayerDataService.Get(player)
	if profile then
		profile.Incubating = IncubatorService.GetSnapshot(player)
	end
	for _, incubator in getIncubators(player) do
		incubator.Model:Destroy()
	end
	local signs = lockedSignsByPlayer[player]
	if signs then
		for _, sign in signs do
			sign:Destroy()
		end
	end
	incubatorsByPlayer[player] = nil
	lockedSignsByPlayer[player] = nil
	lastAttempt[player] = nil
end

-- Suma una incubadora (la compra la hace la fase 4). Devuelve true si se pudo.
function IncubatorService.AddIncubator(player: Player): boolean
	local base = BaseService.GetBase(player)
	local profile = PlayerDataService.Get(player)
	local list = incubatorsByPlayer[player]
	if not base or not profile or not list then
		return false
	end
	local slot = #list + 1
	if slot > math.min(Config.Upgrades.MaxIncubators, #base.IncubatorSlots) then
		return false
	end
	local signs = lockedSignsByPlayer[player]
	if signs and signs[slot] then
		signs[slot]:Destroy()
		signs[slot] = nil
	end
	local incubator = buildIncubator(player, base, slot)
	showEmpty(incubator)
	table.insert(list, incubator)
	profile.IncubatorCount = #list
	return true
end

-- Recalcula los tiempos cuando cambia el nivel de "Incubation Speed" (fase 4).
-- Se conserva el progreso: si iba por la mitad, sigue por la mitad del tiempo nuevo.
function IncubatorService.RecalculateTimes(player: Player)
	local now = os.clock()
	for _, incubator in getIncubators(player) do
		local egg = incubator.Egg
		if egg and not egg.Hatching then
			local progress = 1 - math.max(0, egg.HatchAt - now) / egg.TotalTime
			local newTotal = Config.GetIncubationTime(egg.Rarity, speedLevel(player))
			egg.TotalTime = newTotal
			egg.HatchAt = now + newTotal * (1 - progress)
		end
	end
end

function IncubatorService.Init()
	-- Reloj de las incubadoras: actualiza las cuentas regresivas y abre los huevos que terminaron.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, list in incubatorsByPlayer do
				for _, incubator in list do
					local egg = incubator.Egg
					if egg and not egg.Hatching then
						local remaining = egg.HatchAt - now
						if remaining <= 0 then
							hatch(incubator)
						else
							incubator.Timer.Text = formatTime(remaining)
						end
					end
				end
			end
		end
	end)
end

return IncubatorService

end
__loaders['PlayerDataService'] = function()
--!strict
-- PlayerDataService: los datos de cada jugador (plata, mascotas, mejoras, huevos incubando)
-- y su guardado con DataStore.
--
-- Cuándo se guarda:
--   - al salir del juego
--   - cada Config.Data.AutosaveInterval segundos (autoguardado)
--   - cuando el servidor se apaga (game:BindToClose)
-- Cada lectura/escritura usa pcall y se reintenta varias veces si Roblox falla.
--
-- MUY IMPORTANTE: si no pudimos LEER los datos de alguien, nunca le guardamos encima
-- (si no, un error de Roblox le borraría el progreso). En el juego publicado lo sacamos para que reintente;
-- en Studio lo dejamos jugar sin guardar (ver "Enable Studio Access to API Services" en el README).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = __req("Config")
local Creatures = __req("Creatures")

export type CreatureData = {
	CreatureId: string,
	Slot: number, -- en qué pad de mascotas está
}

export type IncubatingData = {
	Slot: number, -- en qué incubadora
	RarityId: string,
	Remaining: number, -- segundos que le faltaban al salir (el tiempo no corre mientras no estás)
}

export type Profile = {
	Coins: number,
	IncubationSpeedLevel: number,
	IncubatorCount: number,
	WalkSpeedLevel: number,
	BaseLevel: number, -- 2 = tiene el segundo piso ("Base Floor")
	Creatures: { CreatureData },
	Incubating: { IncubatingData }, -- se llena al salir (mientras jugás, los huevos viven en IncubatorService)
}

local DATA_VERSION = 1 -- si algún día cambia la forma de los datos, sirve para convertir los viejos

local PlayerDataService = {}

local profiles: { [Player]: Profile } = {}
local canSave: { [Player]: boolean } = {} -- false si no pudimos leer sus datos (nunca le guardamos encima)
local savingUsers: { [number]: boolean } = {} -- para que dos guardados del mismo jugador no se pisen
local pendingSaves = 0
local incubatingProvider: ((Player) -> { IncubatingData })? = nil

local store: DataStore? = nil

local function getStore(): DataStore
	if not store then
		store = DataStoreService:GetDataStore(Config.Data.StoreName)
	end
	return store :: DataStore
end

local function keyFor(userId: number): string
	return `Player_{userId}`
end

local function newProfile(): Profile
	return {
		Coins = Config.Economy.StartingCoins,
		IncubationSpeedLevel = 1,
		IncubatorCount = Config.Upgrades.StartingIncubators,
		WalkSpeedLevel = 1,
		BaseLevel = 1,
		Creatures = {},
		Incubating = {},
	}
end

-- Ejecuta fn con pcall y la reintenta si falla (esperando un poco más cada vez).
local function withRetries(label: string, fn: () -> any, maxAttempts: number?): (boolean, any)
	local attempts = maxAttempts or Config.Data.MaxAttempts
	local lastError: any = nil
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		warn(`[PlayerData] {label} failed (attempt {attempt}/{attempts}): {result}`)
		if attempt < attempts then
			task.wait(Config.Data.RetryDelay * attempt)
		end
	end
	return false, lastError
end

-- ===== Revisar lo que viene del DataStore =====
-- Los datos guardados podrían estar incompletos o rotos: nos quedamos solo con valores válidos.

local function cleanNumber(value: any, default: number, min: number, max: number): number
	if typeof(value) ~= "number" or value ~= value then -- value ~= value detecta NaN
		return default
	end
	return math.clamp(math.floor(value), min, max)
end

-- Un número de lugar (pad o incubadora) válido: entero entre 1 y max. Si no, nil (se descarta, no se "acomoda").
local function validSlot(value: any, max: number): number?
	if typeof(value) ~= "number" or value ~= math.floor(value) or value < 1 or value > max then
		return nil
	end
	return value
end

local function profileFromData(data: any): Profile
	local profile = newProfile()
	if typeof(data) ~= "table" then
		return profile
	end
	local up = Config.Upgrades
	profile.Coins = cleanNumber(data.Coins, profile.Coins, 0, 1e15)
	profile.IncubationSpeedLevel = cleanNumber(data.IncubationSpeedLevel, 1, 1, #up.IncubationSpeed)
	profile.IncubatorCount = cleanNumber(data.IncubatorCount, up.StartingIncubators, 1, up.MaxIncubators)
	profile.WalkSpeedLevel = cleanNumber(data.WalkSpeedLevel, 1, 1, #up.WalkSpeed)
	profile.BaseLevel = cleanNumber(data.BaseLevel, 1, 1, 2)

	-- Mascotas: que existan y que no haya dos en el mismo pad
	local usedSlots: { [number]: boolean } = {}
	if typeof(data.Creatures) == "table" then
		for _, entry in data.Creatures do
			if typeof(entry) == "table" and typeof(entry.CreatureId) == "string" and Creatures.Get(entry.CreatureId) then
				local slot = validSlot(entry.Slot, 1000)
				if slot and not usedSlots[slot] then
					usedSlots[slot] = true
					table.insert(profile.Creatures, { CreatureId = entry.CreatureId, Slot = slot })
				end
			end
		end
	end

	-- Huevos incubando: rareza válida, incubadora que tenga, una sola vez cada una
	local usedIncubators: { [number]: boolean } = {}
	if typeof(data.Incubating) == "table" then
		for _, entry in data.Incubating do
			if typeof(entry) == "table" and typeof(entry.RarityId) == "string" and Config.GetRarity(entry.RarityId) then
				local slot = validSlot(entry.Slot, profile.IncubatorCount)
				if slot and not usedIncubators[slot] then
					usedIncubators[slot] = true
					local remaining = if typeof(entry.Remaining) == "number" and entry.Remaining == entry.Remaining then math.max(0, entry.Remaining) else 0
					table.insert(profile.Incubating, { Slot = slot, RarityId = entry.RarityId, Remaining = remaining })
				end
			end
		end
	end
	return profile
end

-- Copia del perfil lista para guardar (tablas simples: números, textos y listas)
local function dataFromProfile(profile: Profile, incubating: { IncubatingData }): { [string]: any }
	local creatures = {}
	for _, c in profile.Creatures do
		table.insert(creatures, { CreatureId = c.CreatureId, Slot = c.Slot })
	end
	local eggs = {}
	for _, e in incubating do
		table.insert(eggs, { Slot = e.Slot, RarityId = e.RarityId, Remaining = math.floor(e.Remaining * 10) / 10 })
	end
	return {
		Version = DATA_VERSION,
		Coins = profile.Coins,
		IncubationSpeedLevel = profile.IncubationSpeedLevel,
		IncubatorCount = profile.IncubatorCount,
		WalkSpeedLevel = profile.WalkSpeedLevel,
		BaseLevel = profile.BaseLevel,
		Creatures = creatures,
		Incubating = eggs,
		SavedAt = os.time(),
	}
end

-- ===== Guardar =====

local function writeData(userId: number, data: { [string]: any }): boolean
	-- Si ya se está guardando este jugador, esperamos (así el guardado más nuevo siempre llega último)
	while savingUsers[userId] do
		task.wait(0.1)
	end
	savingUsers[userId] = true
	local ok = withRetries(`Save {userId}`, function()
		getStore():UpdateAsync(keyFor(userId), function()
			return data
		end)
		return true
	end)
	savingUsers[userId] = nil
	return ok
end

-- Guarda en segundo plano y lleva la cuenta de los guardados pendientes (para BindToClose).
local function saveInBackground(userId: number, data: { [string]: any })
	pendingSaves += 1
	task.spawn(function()
		writeData(userId, data)
		pendingSaves -= 1
	end)
end

-- Guarda a un jugador que sigue en el juego (autoguardado / cierre del servidor).
local function saveOnline(player: Player)
	local profile = profiles[player]
	if not profile or not canSave[player] then
		return
	end
	local incubating = if incubatingProvider then incubatingProvider(player) else profile.Incubating
	saveInBackground(player.UserId, dataFromProfile(profile, incubating))
end

-- ===== Plata y niveles visibles =====

-- La tabla "leaderstats" hace que la plata se vea en la lista de jugadores de Roblox.
local function createLeaderstats(player: Player, coins: number)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coinsValue = Instance.new("NumberValue")
	coinsValue.Name = "Coins"
	coinsValue.Value = coins
	coinsValue.Parent = leaderstats
	leaderstats.Parent = player
end

local function syncCoins(player: Player, profile: Profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsValue = leaderstats and leaderstats:FindFirstChild("Coins")
	if coinsValue and coinsValue:IsA("NumberValue") then
		coinsValue.Value = profile.Coins
	end
	player:SetAttribute("Coins", profile.Coins) -- para la interfaz
end

-- Copia los niveles de mejoras a atributos del jugador, para que el panel del cliente los pueda leer.
local function syncLevels(player: Player, profile: Profile)
	player:SetAttribute("IncubationSpeedLevel", profile.IncubationSpeedLevel)
	player:SetAttribute("IncubatorCount", profile.IncubatorCount)
	player:SetAttribute("WalkSpeedLevel", profile.WalkSpeedLevel)
	player:SetAttribute("BaseLevel", profile.BaseLevel)
end

-- ===== API pública =====

-- Lee los datos del jugador (puede tardar un poco: espera al DataStore).
-- Devuelve nil si el jugador se fue mientras cargaba o si hubo que sacarlo.
function PlayerDataService.Load(player: Player): Profile?
	local existing = profiles[player]
	if existing then
		return existing
	end

	-- En Studio probamos una sola vez: si no está activado el acceso a la API, no tiene sentido esperar reintentos
	local ok, data = withRetries(`Load {player.UserId}`, function()
		return getStore():GetAsync(keyFor(player.UserId))
	end, if RunService:IsStudio() then 1 else nil)

	if not player:IsDescendantOf(Players) then
		return nil -- se fue mientras cargábamos
	end

	local profile: Profile
	if ok then
		profile = profileFromData(data)
		canSave[player] = true
	elseif RunService:IsStudio() then
		warn("[PlayerData] Couldn't load data. Playing WITHOUT saving. In Studio, turn on Game Settings > Security > 'Enable Studio Access to API Services'.")
		profile = newProfile()
		canSave[player] = false
	else
		-- En el juego publicado: mejor que reintente a que juegue y le borremos el progreso
		player:Kick("We couldn't load your data. Please rejoin in a moment!")
		return nil
	end

	profiles[player] = profile
	createLeaderstats(player, profile.Coins)
	syncCoins(player, profile)
	syncLevels(player, profile)
	return profile
end

function PlayerDataService.Get(player: Player): Profile?
	return profiles[player]
end

-- Cuando el jugador se va: guarda (en segundo plano) y suelta sus datos.
-- Para entonces IncubatorService ya pasó los huevos a profile.Incubating.
function PlayerDataService.Unload(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	if canSave[player] then
		saveInBackground(player.UserId, dataFromProfile(profile, profile.Incubating))
	end
	canSave[player] = nil
end

-- IncubatorService le dice a este servicio cómo sacar la foto de los huevos que se están incubando
-- (para el autoguardado mientras el jugador sigue jugando).
function PlayerDataService.SetIncubatingProvider(provider: (Player) -> { IncubatingData })
	incubatingProvider = provider
end

-- Hay que llamarlo después de cambiar un nivel de mejora en el perfil.
function PlayerDataService.SyncLevels(player: Player)
	local profile = profiles[player]
	if profile then
		syncLevels(player, profile)
	end
end

function PlayerDataService.AddCoins(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or amount <= 0 then
		return
	end
	profile.Coins += amount
	syncCoins(player, profile)
end

-- Cobra si alcanza la plata. Devuelve true si pudo cobrar. (Lo usan las mejoras.)
function PlayerDataService.SpendCoins(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or amount < 0 or profile.Coins < amount then
		return false
	end
	profile.Coins -= amount
	syncCoins(player, profile)
	return true
end

-- Guarda a todos los que están jugando (lo usan el autoguardado y el cierre del servidor).
function PlayerDataService.SaveAll()
	for player in profiles do
		saveOnline(player)
	end
end

function PlayerDataService.Init()
	Players.PlayerRemoving:Connect(function(player)
		-- Por si el jugador se va sin haber tenido base (servidor lleno): no queda nada colgado
		task.defer(function()
			if profiles[player] then
				PlayerDataService.Unload(player)
			end
			canSave[player] = nil
		end)
	end)

	-- Autoguardado
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			PlayerDataService.SaveAll()
		end
	end)

	-- Cuando el servidor se apaga: guardamos a todos y esperamos a que terminen (Roblox da ~30 s)
	game:BindToClose(function()
		PlayerDataService.SaveAll()
		local started = os.clock()
		while pendingSaves > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService

end
__loaders['StormService'] = function()
--!strict
-- StormService: el ciclo de la tormenta.
--   Rain    (60 s): cielo oscuro y caen huevos
--   Warning (10 s): cartel "WAVE INCOMING" (lo dibuja el cliente)
--   Wave          : una pared de agua sale del mar y recorre el pasillo hasta la línea segura (Z = 0)
--   Calm    (20 s): vuelve el sol
--
-- El servidor decide TODO lo importante (a quién agarra la ola, qué huevos se borran).
-- Para que la ola se vea suave, cada cliente la dibuja con la misma fórmula usando estos atributos de Workspace:
--   StormPhase, PhaseEndsAt, WaveStartedAt, WaveStartZ, WaveSpeed

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = __req("Config")
local Remotes = __req("Remotes")
local EggService = __req("EggService")

export type Phase = "Rain" | "Warning" | "Wave" | "Calm"

local StormService = {}

local SAFE_LINE_Z = 0 -- todo lo que esté en Z < 0 es el lobby (zona segura); ver MapBuilder

local notifyRemote = Remotes.Event("Notify")
local currentPhase: Phase = "Calm"
local colorCorrection: ColorCorrectionEffect
local clouds: Clouds?

-- ===== Clima =====

local CALM_LIGHTING = {
	Brightness = 2,
	Ambient = Color3.fromRGB(110, 110, 110),
	OutdoorAmbient = Color3.fromRGB(140, 140, 140),
	FogEnd = 100000,
	FogColor = Color3.fromRGB(192, 192, 192),
}
local STORM_LIGHTING = {
	Brightness = 0.7,
	Ambient = Color3.fromRGB(60, 60, 85),
	OutdoorAmbient = Color3.fromRGB(70, 75, 100),
	FogEnd = 700,
	FogColor = Color3.fromRGB(70, 75, 95),
}

local function setStormWeather(stormy: boolean)
	local info = TweenInfo.new(3, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, if stormy then STORM_LIGHTING else CALM_LIGHTING):Play()
	TweenService:Create(colorCorrection, info, {
		Saturation = if stormy then -0.35 else 0,
		TintColor = if stormy then Color3.fromRGB(200, 210, 235) else Color3.new(1, 1, 1),
	}):Play()
	if clouds then
		TweenService:Create(clouds, info, {
			Cover = if stormy then 0.9 else 0.5,
			Density = if stormy then 0.8 else 0.3,
			Color = if stormy then Color3.fromRGB(80, 85, 100) else Color3.new(1, 1, 1),
		}):Play()
	end
end

local function setupWeather()
	Lighting.ClockTime = 14
	for key, value in CALM_LIGHTING do
		(Lighting :: any)[key] = value
	end
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "StormTint"
	colorCorrection.Parent = Lighting

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local c = Instance.new("Clouds")
		c.Cover = 0.5
		c.Density = 0.3
		c.Parent = terrain
		clouds = c
	end
end

-- ===== Fases =====

local function setPhase(phase: Phase, duration: number)
	currentPhase = phase
	Workspace:SetAttribute("StormPhase", phase)
	Workspace:SetAttribute("PhaseEndsAt", Workspace:GetServerTimeNow() + duration)
end

local function notifyAll(text: string)
	notifyRemote:FireAllClients(text)
end

-- ¿La ola agarra a este jugador? Solo si está en el pasillo (fuera del lobby), ya alcanzado por la ola y no muy arriba.
local function isCaught(root: BasePart, frontZ: number): boolean
	local position = root.Position
	return position.Z > SAFE_LINE_Z and position.Z >= frontZ and position.Y < Config.Map.FloorY + Config.Storm.WaveHeight
end

local function hitPlayer(player: Player, humanoid: Humanoid)
	local hadEgg = EggService.GetCarriedEgg(player) ~= nil
	EggService.LoseCarriedEgg(player)
	humanoid.Health = 0 -- reaparece en su base (BaseService lo lleva ahí)
	notifyRemote:FireClient(player, if hadEgg then "The wave got you! You lost your egg." else "The wave got you!")
end

local function runWave()
	local storm = Config.Storm
	local startZ = Config.Map.CorridorLength + Config.Map.SeaDepth
	local travelTime = (startZ - SAFE_LINE_Z) / storm.WaveSpeed

	Workspace:SetAttribute("WaveStartedAt", Workspace:GetServerTimeNow())
	Workspace:SetAttribute("WaveStartZ", startZ)
	Workspace:SetAttribute("WaveSpeed", storm.WaveSpeed)
	setPhase("Wave", travelTime)

	local startedAt = os.clock()
	while true do
		local frontZ = startZ - storm.WaveSpeed * (os.clock() - startedAt)

		-- Huevos del piso que la ola ya alcanzó
		EggService.ClearWorldEggsBeyond(frontZ)

		-- Jugadores que la ola ya alcanzó
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and isCaught(root, frontZ) then
				hitPlayer(player, humanoid)
			end
		end

		if frontZ <= SAFE_LINE_Z then
			break
		end
		task.wait(0.05)
	end
end

-- ===== API pública =====

function StormService.GetPhase(): Phase
	return currentPhase
end

function StormService.Init()
	Players.RespawnTime = Config.Storm.RespawnTime
	setupWeather()

	task.spawn(function()
		local storm = Config.Storm
		while true do
			-- Lluvia: cielo oscuro y caen huevos
			setPhase("Rain", storm.RainDuration)
			setStormWeather(true)
			EggService.SetRaining(true)
			notifyAll("The storm is here! Grab eggs and bring them home!")
			task.wait(storm.RainDuration)

			-- Aviso: dejan de caer huevos y el cliente muestra "WAVE INCOMING"
			EggService.SetRaining(false)
			setPhase("Warning", storm.WarningDuration)
			task.wait(storm.WarningDuration)

			-- La ola
			runWave()

			-- Calma: por las dudas, borramos cualquier huevo que haya quedado
			EggService.ClearWorldEggs()
			setPhase("Calm", storm.CalmDuration)
			setStormWeather(false)
			task.wait(storm.CalmDuration)
		end
	end)
end

return StormService

end
__loaders['CreatureModels'] = function()
--!strict
-- CreatureModels: arma el modelo placeholder de cada mascota con Parts simples.
-- Cuerpo redondo + ojos, y según el estilo: orejas, alas, pico, cuernos o cola.
-- Cuando tengas modelos de verdad, se reemplaza este archivo y el resto del juego sigue igual.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = __req("Config")
local Creatures = __req("Creatures")

type Creature = Creatures.Creature

local CreatureModels = {}

-- Las mascotas más raras son más grandes
local SCALE_BY_RARITY: { [string]: number } = {
	Common = 1,
	Rare = 1.15,
	Epic = 1.3,
	Legendary = 1.5,
	Secret = 1.7,
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 255, 100)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 80, 255)),
})

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, ball: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	if ball then
		p.Shape = Enum.PartType.Ball
	end
	p.Parent = parent
	return p
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- cframe: dónde va la mascota, apoyada en el piso y mirando hacia adelante (-Z local).
function CreatureModels.Build(creature: Creature, cframe: CFrame): Model
	local rarity = Config.GetRarity(creature.RarityId)
	local s = SCALE_BY_RARITY[creature.RarityId] or 1
	local color = creature.Color

	local model = Instance.new("Model")
	model.Name = creature.DisplayName
	model:SetAttribute("CreatureId", creature.Id)

	-- Cuerpo
	local bodySize = 3 * s
	local center = cframe * CFrame.new(0, bodySize / 2, 0)
	local body = part("Body", Vector3.new(bodySize, bodySize, bodySize), center, color, model, true)
	model.PrimaryPart = body

	-- Ojos (blancos con pupila negra), en la cara de adelante
	for _, x in { -0.45, 0.45 } do
		local eyeCFrame = center * CFrame.new(x * s, 0.35 * s, -1.25 * s)
		part("Eye", Vector3.new(0.8, 0.8, 0.8) * s, eyeCFrame, Color3.new(1, 1, 1), model, true)
		part("Pupil", Vector3.new(0.4, 0.4, 0.4) * s, eyeCFrame * CFrame.new(0, 0, -0.3 * s), Color3.new(0, 0, 0), model, true)
	end

	local style = creature.Style
	if style == "Bunny" then
		for _, x in { -0.5, 0.5 } do
			part("Ear", Vector3.new(0.5, 2.2, 0.3) * s, center * CFrame.new(x * s, 2 * s, 0) * CFrame.Angles(0, 0, -x * 0.4), color, model)
		end
	elseif style == "Cat" then
		for _, x in { -0.75, 0.75 } do
			-- Un cubo girado 45° asoma como una oreja en punta
			part("Ear", Vector3.new(0.8, 0.8, 0.3) * s, center * CFrame.new(x * s, 1.35 * s, 0) * CFrame.Angles(0, 0, math.rad(45)), darker(color, 0.15), model)
		end
		part("Tail", Vector3.new(0.35, 0.35, 2) * s, center * CFrame.new(0, 0.2 * s, 1.8 * s) * CFrame.Angles(math.rad(35), 0, 0), color, model)
	elseif style == "Bird" then
		part("Beak", Vector3.new(0.5, 0.4, 0.8) * s, center * CFrame.new(0, 0, -1.6 * s), Color3.fromRGB(255, 160, 40), model)
		for _, x in { -1, 1 } do
			part("Wing", Vector3.new(0.3, 1.4, 1.8) * s, center * CFrame.new(x * 1.55 * s, 0, 0.2 * s) * CFrame.Angles(0, 0, -x * 0.35), darker(color, 0.15), model)
		end
	elseif style == "Dragon" then
		for _, x in { -0.5, 0.5 } do
			part("Horn", Vector3.new(0.35, 1.1, 0.35) * s, center * CFrame.new(x * s, 1.6 * s, 0.2 * s) * CFrame.Angles(math.rad(-20), 0, -x * 0.5), Color3.fromRGB(250, 245, 230), model)
		end
		for _, x in { -1, 1 } do
			part("Wing", Vector3.new(2.4, 0.2, 1.6) * s, center * CFrame.new(x * 2 * s, 0.6 * s, 0.6 * s) * CFrame.Angles(0, 0, x * 0.5), darker(color, 0.2), model)
		end
		part("Tail", Vector3.new(0.6, 0.6, 2.4) * s, center * CFrame.new(0, -0.6 * s, 2 * s) * CFrame.Angles(math.rad(15), 0, 0), color, model)
	end
	-- "Blob": solo cuerpo y ojos

	-- Brillo para las raras
	if creature.RarityId == "Legendary" or creature.RarityId == "Secret" then
		local light = Instance.new("PointLight")
		light.Color = if rarity and creature.RarityId ~= "Secret" then rarity.Color else Color3.new(1, 1, 1)
		light.Brightness = 2
		light.Range = 12
		light.Parent = body

		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = if creature.RarityId == "Secret" then RAINBOW else ColorSequence.new(rarity and rarity.Color or color)
		sparkles.LightEmission = 1
		sparkles.Rate = 10
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.4, 0)
		sparkles.Parent = body
	end

	-- Cartel flotante con nombre y plata por segundo
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromScale(8, 2.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, bodySize / 2 + 2.2 * s, 0)
	gui.MaxDistance = 80
	gui.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.Text = creature.DisplayName
	nameLabel.TextColor3 = if rarity and creature.RarityId ~= "Secret" then rarity.Color else Color3.new(1, 1, 1)
	nameLabel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = nameLabel
	if creature.RarityId == "Secret" then
		local gradient = Instance.new("UIGradient")
		gradient.Color = RAINBOW
		gradient.Parent = nameLabel
	end

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "Income"
	incomeLabel.Size = UDim2.fromScale(1, 0.45)
	incomeLabel.Position = UDim2.fromScale(0, 0.55)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Font = Enum.Font.FredokaOne
	incomeLabel.TextScaled = true
	incomeLabel.Text = `+{rarity and rarity.CoinsPerSecond or 0} coins/s`
	incomeLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	incomeLabel.Parent = gui
	local stroke2 = Instance.new("UIStroke")
	stroke2.Thickness = 2
	stroke2.Parent = incomeLabel

	return model
end

return CreatureModels

end
__loaders['MapBuilder'] = function()
--!strict
-- MapBuilder: arma el mapa placeholder con Parts simples (estilo bloques/LEGO, colorido).
--
-- Forma del mapa (visto desde arriba, en forma de T), eje Z de abajo hacia arriba:
--
--             ┌──── agua (de acá sale la ola) ────┐         Z = CorridorLength + SeaDepth
--             │  SECRET / LEGENDARY / EPIC / ...  │         pasillo de arena (peligro)
--             │  ... / RARE / COMMON zones        │
--   ┌─────────┴──────── arco "SAFE ZONE" ─────────┴────────┐ Z = 0  (línea segura)
--   │  ↑     ↑     ↑     ↑     ↑     ↑     ↑     ↑        │ lobby verde (seguro)
--   │ [B1]  [B2]  [B3]  [B4]  [B5]  [B6]  [B7]  [B8]       │ bases mirando al pasillo
--   └──────────────────────────────────────────────────────┘ Z = -(LobbyFrontWalk + PlotDepth + LobbyBackMargin)
--
-- Si en Workspace ya existe una carpeta "Map" (por ejemplo, cuando reemplaces los modelos a mano),
-- no construye nada y usa esa. Solo tiene que respetar la misma estructura:
--   Map/Bases/BaseN (Model con atributo BaseId) con SpawnPoint, SafeZone y un TextLabel "SignLabel".

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = __req("Config")

local MapBuilder = {}

local cfg = Config.Map
local HALF_WIDTH = cfg.CorridorWidth / 2
-- El lobby tiene el ancho justo para las bases en fila (con un espacio entre cada una y contra las paredes)
local LOBBY_WIDTH = math.max(cfg.BaseCount * cfg.PlotWidth + (cfg.BaseCount + 1) * cfg.PlotGap, cfg.CorridorWidth)
local LOBBY_HALF_WIDTH = LOBBY_WIDTH / 2
local LOBBY_DEPTH = cfg.LobbyFrontWalk + cfg.PlotDepth + cfg.LobbyBackMargin

-- ===== Ayudantes =====

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, studs: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	local surface = if studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	part.TopSurface = surface
	part.BottomSurface = surface
	part.FrontSurface = surface
	part.BackSurface = surface
	part.LeftSurface = surface
	part.RightSurface = surface
	part.Parent = parent
	return part
end

-- Parte invisible que no choca con nada: sirve como "marcador" de una posición o un volumen.
local function makeMarker(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = makePart(name, size, cframe, Color3.new(1, 1, 1), parent)
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

-- Cilindro parado (los cilindros de Roblox tienen el eje en X, así que lo giramos 90°).
local function makeColumn(name: string, height: number, diameter: number, bottom: Vector3, color: Color3, parent: Instance): Part
	local part = makePart(name, Vector3.new(height, diameter, diameter), CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, parent)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Pone un texto sobre una cara de una Part (carteles).
local function addText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, labelName: string?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = labelName or "Label"
	label.Size = UDim2.fromScale(0.94, 0.9)
	label.Position = UDim2.fromScale(0.03, 0.05)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	return label
end

local function addRainbow(label: TextLabel)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 255, 100)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 80, 255)),
	})
	gradient.Parent = label
end

-- ===== Decoración =====

local function buildPalm(position: Vector3, parent: Instance)
	local palm = Instance.new("Model")
	palm.Name = "Palm"
	local trunkHeight = 22
	makeColumn("Trunk", trunkHeight, 2.5, position, Color3.fromRGB(140, 95, 55), palm)
	local top = position + Vector3.new(0, trunkHeight, 0)
	for i = 0, 5 do
		-- Cada hoja sale del tope del tronco, girada y un poco inclinada hacia abajo
		local leafCFrame = CFrame.new(top) * CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, 0, -6)
		makePart("Leaf", Vector3.new(3, 0.6, 12), leafCFrame, Color3.fromRGB(60, 190, 70), palm, true)
	end
	for i = 0, 2 do
		local coconut = makePart("Coconut", Vector3.new(1.6, 1.6, 1.6), CFrame.new(top + Vector3.new(math.cos(i * 2.1) * 1.4, -1.2, math.sin(i * 2.1) * 1.4)), Color3.fromRGB(110, 70, 40), palm)
		coconut.Shape = Enum.PartType.Ball
	end
	palm.Parent = parent
end

local function buildUmbrella(position: Vector3, color: Color3, parent: Instance)
	local umbrella = Instance.new("Model")
	umbrella.Name = "Umbrella"
	makeColumn("Pole", 10, 0.6, position, Color3.new(1, 1, 1), umbrella)
	local canopy = makeColumn("Canopy", 1, 12, position + Vector3.new(0, 10, 0), color, umbrella)
	canopy.CanCollide = false
	local tip = makeColumn("Tip", 1, 5, position + Vector3.new(0, 11, 0), Color3.new(1, 1, 1), umbrella)
	tip.CanCollide = false
	umbrella.Parent = parent
end

-- Toalla de playa con una franja blanca
local function buildTowel(cframe: CFrame, color: Color3, parent: Instance)
	local towel = makePart("Towel", Vector3.new(5, 0.15, 9), cframe * CFrame.new(0, 0.075, 0), color, parent)
	towel.CanCollide = false
	local stripe = makePart("TowelStripe", Vector3.new(5, 0.05, 1.2), cframe * CFrame.new(0, 0.175, 2.5), Color3.new(1, 1, 1), parent)
	stripe.CanCollide = false
end

local function buildBeachBall(position: Vector3, color: Color3, parent: Instance)
	local ball = makePart("BeachBall", Vector3.new(2.5, 2.5, 2.5), CFrame.new(position + Vector3.new(0, 1.25, 0)), color, parent)
	ball.Shape = Enum.PartType.Ball
end

-- Puesto de playa con toldo a rayas. cframe está a nivel del piso y su frente (-Z) mira al camino.
local function buildKiosk(cframe: CFrame, stripeColor: Color3, parent: Instance)
	local kiosk = Instance.new("Model")
	kiosk.Name = "Kiosk"
	local wood = Color3.fromRGB(150, 100, 60)
	makePart("Counter", Vector3.new(12, 4, 3), cframe * CFrame.new(0, 2, -3), wood, kiosk, true)
	makePart("CounterTop", Vector3.new(12.6, 0.5, 3.6), cframe * CFrame.new(0, 4.25, -3), Color3.new(1, 1, 1), kiosk)
	makePart("BackWall", Vector3.new(12, 8, 0.6), cframe * CFrame.new(0, 4, 3.7), stripeColor, kiosk, true)
	for _, x in { -5.7, 5.7 } do
		for _, z in { -4.5, 3.7 } do
			makePart("Post", Vector3.new(0.6, 10, 0.6), cframe * CFrame.new(x, 5, z), Color3.new(1, 1, 1), kiosk)
		end
	end
	-- Toldo: rayas alternadas, un poco inclinado hacia adelante
	for i = 0, 6 do
		local color = if i % 2 == 0 then stripeColor else Color3.new(1, 1, 1)
		makePart("Awning", Vector3.new(1.8, 0.4, 10), cframe * CFrame.new(-5.4 + i * 1.8, 10.4, -0.6) * CFrame.Angles(math.rad(-12), 0, 0), color, kiosk)
	end
	kiosk.Parent = parent
end

-- Torre de guardavidas (cerca del agua)
local function buildLifeguardTower(cframe: CFrame, parent: Instance)
	local tower = Instance.new("Model")
	tower.Name = "LifeguardTower"
	local white = Color3.new(1, 1, 1)
	local red = Color3.fromRGB(230, 60, 60)
	for _, x in { -3.5, 3.5 } do
		for _, z in { -3.5, 3.5 } do
			makePart("Leg", Vector3.new(0.8, 12, 0.8), cframe * CFrame.new(x, 6, z), white, tower)
			makePart("RoofPost", Vector3.new(0.5, 7, 0.5), cframe * CFrame.new(x, 16, z), white, tower)
		end
	end
	makePart("Platform", Vector3.new(9, 1, 9), cframe * CFrame.new(0, 12.5, 0), red, tower, true)
	makePart("Rail", Vector3.new(9, 2, 0.4), cframe * CFrame.new(0, 14, -4.4), white, tower)
	makePart("Roof", Vector3.new(10, 0.6, 10), cframe * CFrame.new(0, 19.8, 0), red, tower, true)
	tower.Parent = parent
end

local function buildRocks(position: Vector3, rng: Random, parent: Instance)
	for _ = 1, rng:NextInteger(2, 3) do
		local size = rng:NextNumber(3, 6)
		local offset = Vector3.new(rng:NextNumber(-3, 3), size * 0.3, rng:NextNumber(-3, 3))
		local rotation = CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3))
		local gray = rng:NextNumber(0.45, 0.6)
		makePart("Rock", Vector3.new(size, size * 0.8, size * 1.1), CFrame.new(position + offset) * rotation, Color3.new(gray, gray, gray * 1.05), parent, true)
	end
end

local function buildCrates(position: Vector3, rng: Random, parent: Instance)
	local wood = Color3.fromRGB(170, 120, 70)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	makePart("Crate", Vector3.new(4, 4, 4), CFrame.new(position + Vector3.new(0, 2, 0)) * yaw, wood, parent, true)
	makePart("Crate", Vector3.new(4, 4, 4), CFrame.new(position + Vector3.new(0, 2, 0)) * yaw * CFrame.new(4.2, 0, 0), wood, parent, true)
	makePart("Crate", Vector3.new(4, 4, 4), CFrame.new(position + Vector3.new(0, 6, 0)) * yaw * CFrame.new(2, 0, 0) * CFrame.Angles(0, 0.3, 0), wood:Lerp(Color3.new(0, 0, 0), 0.1), parent, true)
end

-- ===== Partes del mapa =====

local function buildWalls(map: Instance)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = map

	local t = cfg.WallThickness
	local h = cfg.WallHeight
	local farZ = cfg.CorridorLength + cfg.SeaDepth
	local nearZ = -LOBBY_DEPTH
	local pillarColor = cfg.WallColor:Lerp(Color3.new(0, 0, 0), 0.2)

	-- Pared con su borde verde arriba. size/position describen el bloque de la pared.
	local function wall(name: string, size: Vector3, position: Vector3)
		makePart(name, size, CFrame.new(position), cfg.WallColor, walls, true)
		makePart("Trim", Vector3.new(size.X + 2, 2, size.Z + 2), CFrame.new(position.X, h + 1, position.Z), cfg.WallTrimColor, walls, true)
	end

	-- Paredes del pasillo (de la línea segura hasta el fondo)
	local corridorLength = farZ + t
	for _, side in { -1, 1 } do
		wall("CorridorWall", Vector3.new(t, h, corridorLength), Vector3.new(side * (HALF_WIDTH + t / 2), h / 2, corridorLength / 2))
		-- Columnas más oscuras cada tanto para que la pared no sea un bloque liso
		local z = 30
		while z < farZ do
			makePart("Pillar", Vector3.new(2, h, 6), CFrame.new(side * (HALF_WIDTH - 1), h / 2, z), pillarColor, walls, true)
			z += 60
		end
	end
	wall("FarWall", Vector3.new(cfg.CorridorWidth + t * 2, h, t), Vector3.new(0, h / 2, farZ + t / 2))

	-- Paredes del lobby
	local lobbyLength = LOBBY_DEPTH + t * 2
	for _, side in { -1, 1 } do
		wall("LobbyWall", Vector3.new(t, h, lobbyLength), Vector3.new(side * (LOBBY_HALF_WIDTH + t / 2), h / 2, nearZ + LOBBY_DEPTH / 2))
		-- "Hombros" de la T: cierran el lobby a los costados de la entrada del pasillo
		local shoulderWidth = LOBBY_HALF_WIDTH - HALF_WIDTH + t
		if shoulderWidth > t then
			wall("ShoulderWall", Vector3.new(shoulderWidth, h, t), Vector3.new(side * (HALF_WIDTH + shoulderWidth / 2), h / 2, t / 2))
		end
	end
	wall("BackWall", Vector3.new(LOBBY_WIDTH + t * 2, h, t), Vector3.new(0, h / 2, nearZ - t / 2))
end

local function buildLobby(map: Instance)
	makePart("LobbyFloor", Vector3.new(LOBBY_WIDTH, 2, LOBBY_DEPTH), CFrame.new(0, cfg.FloorY - 1, -LOBBY_DEPTH / 2), cfg.GrassColor, map, true)

	-- Volumen invisible de toda la zona segura (la ola de la fase 5 no hace nada acá adentro)
	makeMarker("SafeArea", Vector3.new(LOBBY_WIDTH, 60, LOBBY_DEPTH), CFrame.new(0, cfg.FloorY + 30, -LOBBY_DEPTH / 2), map)

	-- Línea blanca en el piso que marca el límite
	local line = makePart("SafeLine", Vector3.new(cfg.CorridorWidth, 0.2, 2), CFrame.new(0, cfg.FloorY + 0.1, 0), Color3.new(1, 1, 1), map)
	line.Material = Enum.Material.Neon
	line.CanCollide = false

	-- Arco con el cartel SAFE ZONE / DANGER ZONE
	local archHeight = 34
	for _, side in { -1, 1 } do
		makePart("ArchPillar", Vector3.new(4, archHeight, 4), CFrame.new(side * (HALF_WIDTH - 4), cfg.FloorY + archHeight / 2, 0), Color3.fromRGB(255, 255, 255), map, true)
	end
	-- La cara Front de esta Part mira al lobby y la Back mira al pasillo
	local beam = makePart("ArchSign", Vector3.new(cfg.CorridorWidth - 4, 10, 3), CFrame.lookAt(Vector3.new(0, cfg.FloorY + archHeight + 3, 0), Vector3.new(0, cfg.FloorY + archHeight + 3, -1)), Color3.fromRGB(40, 40, 50), map)
	addText(beam, Enum.NormalId.Front, "DANGER ZONE AHEAD", Color3.fromRGB(255, 90, 90))
	addText(beam, Enum.NormalId.Back, "SAFE ZONE", Color3.fromRGB(110, 255, 110))

	-- Palmeras en las esquinas de adelante del lobby, a los costados de la entrada del pasillo
	for _, side in { -1, 1 } do
		buildPalm(Vector3.new(side * (LOBBY_HALF_WIDTH - 12), cfg.FloorY, -10), map)
	end
end

local function buildCorridor(map: Instance)
	local corridor = Instance.new("Folder")
	corridor.Name = "Corridor"
	corridor.Parent = map

	local length = cfg.CorridorLength

	-- Piso de arena de un solo color
	makePart("Sand", Vector3.new(cfg.CorridorWidth, 2, length), CFrame.new(0, cfg.FloorY - 1, length / 2), cfg.SandColor, corridor, true)

	-- Carteles de cada zona en las dos paredes, mirando hacia el centro del pasillo
	for _, rarity in Config.Rarities do
		local z0 = rarity.ZoneStart * length
		for _, side in { -1, 1 } do
			-- Separado de la pared lo suficiente para quedar delante de las columnas
			local signPos = Vector3.new(side * (HALF_WIDTH - 2.6), cfg.FloorY + 26, z0 + 18)
			local sign = makePart("ZoneSign", Vector3.new(30, 8, 1), CFrame.lookAt(signPos, signPos - Vector3.new(side, 0, 0)), Color3.fromRGB(40, 40, 50), corridor)
			local label = addText(sign, Enum.NormalId.Front, `{string.upper(rarity.DisplayName)} ZONE`, if rarity.Id == "Secret" then Color3.new(1, 1, 1) else rarity.Color)
			if rarity.Id == "Secret" then
				addRainbow(label)
			end
		end
	end

	-- Agua al fondo
	local sea = makePart("Sea", Vector3.new(cfg.CorridorWidth, 2, cfg.SeaDepth), CFrame.new(0, cfg.FloorY - 1.5, length + cfg.SeaDepth / 2), cfg.SeaColor, corridor)
	sea.Material = Enum.Material.Glass
	sea.Transparency = 0.2

	-- Decoración a los costados, en la franja entre donde caen los huevos y la pared.
	-- Usamos un Random con semilla fija para que el mapa salga siempre igual.
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = corridor
	local rng = Random.new(2025)
	local colors = {
		Color3.fromRGB(255, 80, 120),
		Color3.fromRGB(80, 170, 255),
		Color3.fromRGB(255, 200, 60),
		Color3.fromRGB(180, 90, 255),
		Color3.fromRGB(80, 220, 120),
		Color3.fromRGB(255, 140, 60),
	}
	local function randomColor(): Color3
		return colors[rng:NextInteger(1, #colors)]
	end

	local decorX = HALF_WIDTH - 13 -- centro de la franja de decoración
	for _, side in { -1, 1 } do
		-- Mirando hacia el centro del pasillo (frente = -Z local)
		local facing = CFrame.Angles(0, if side < 0 then -math.pi / 2 else math.pi / 2, 0)
		local z = 20 + (if side > 0 then 15 else 0)
		-- "Bolsa" de decoraciones: se mezcla y se van sacando de a una, así cada tramo tiene un poco de todo
		local bag: { string } = {}
		while z < length - 45 do
			if #bag == 0 then
				bag = { "Palm", "Palm", "Umbrella", "Umbrella", "Kiosk", "Rocks", "Crates" }
				rng:Shuffle(bag)
			end
			local item = table.remove(bag) :: string
			local position = Vector3.new(side * decorX, cfg.FloorY, z)
			if item == "Palm" then
				buildPalm(position + Vector3.new(side * 2, 0, 0), decor)
				z += 26
			elseif item == "Umbrella" then
				buildUmbrella(position + Vector3.new(side * 3, 0, 0), randomColor(), decor)
				buildTowel(CFrame.new(position + Vector3.new(-side * 3, 0, 1)) * facing, randomColor(), decor)
				if rng:NextNumber() < 0.5 then
					buildBeachBall(position + Vector3.new(-side * 7, 0, -4), randomColor(), decor)
				end
				z += 24
			elseif item == "Kiosk" then
				buildKiosk(CFrame.new(position + Vector3.new(side * 2, 0, 0)) * facing, randomColor(), decor)
				z += 26
			elseif item == "Rocks" then
				buildRocks(position, rng, decor)
				z += 18
			else
				buildCrates(position, rng, decor)
				z += 18
			end
		end
		-- Torre de guardavidas cerca del agua
		buildLifeguardTower(CFrame.new(Vector3.new(side * decorX, cfg.FloorY, length - 22)) * facing, decor)
	end
end

local PAD_HEIGHT = 0.6 -- altura de la plataforma de la base
local INCUBATOR_PAD_COLOR = Color3.fromRGB(255, 255, 255)

-- Distribución de los pads dentro de la base (coordenadas locales: -Z = adelante, hacia el pasillo).
-- Como en el dibujo: incubadoras en la fila de adelante, mascotas en dos columnas a los costados
-- y el medio libre para caminar. (El segundo piso con más mascotas llega con "mejorar base" en la fase 4.)
local INCUBATOR_COLUMNS = { -14, 0, 14 }
local INCUBATOR_ROWS = { -22 }
local INCUBATOR_PAD_SIZE = 10
local CREATURE_COLUMNS = { -15.5, 15.5 }
local CREATURE_ROWS = { -9, 2, 13, 24 }
local CREATURE_PAD_SIZE = 8
assert(#INCUBATOR_COLUMNS * #INCUBATOR_ROWS >= Config.Upgrades.MaxIncubators, "[MapBuilder] Not enough incubator pads for MaxIncubators")

-- Pad redondo (cilindro acostado) apoyado sobre la base
local function makePad(name: string, diameter: number, cframe: CFrame, color: Color3, parent: Instance): Part
	local pad = makePart(name, Vector3.new(0.3, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, parent)
	pad.Shape = Enum.PartType.Cylinder
	return pad
end

local function buildSign(model: Model, plotCFrame: CFrame)
	-- Detrás de la base, mirando hacia el pasillo (la cara Front del cartel mira para el mismo lado que la base)
	local signZ = cfg.PlotDepth / 2 + 4
	-- Alto, para que se siga viendo por encima del segundo piso ("mejorar base")
	for _, x in { -14, 14 } do
		makePart("SignPost", Vector3.new(1.5, 26, 1.5), plotCFrame * CFrame.new(x, 13, signZ), Color3.fromRGB(90, 60, 40), model)
	end
	local board = makePart("SignBoard", Vector3.new(32, 8, 1), plotCFrame * CFrame.new(0, 23, signZ), Color3.fromRGB(60, 45, 35), model)
	addText(board, Enum.NormalId.Front, "Free Base", Color3.fromRGB(200, 200, 200), "SignLabel")
end

-- Panel de mejoras: un poste con una pantalla inclinada. Al acercarte aparece "Open" (abre la ventana de mejoras).
-- cframe está a nivel del piso de la base y su frente (-Z) mira hacia el pasillo.
local function buildUpgradePanel(model: Model, baseId: number, cframe: CFrame, color: Color3)
	local panel = Instance.new("Model")
	panel.Name = "UpgradePanel"
	makePart("Post", Vector3.new(1.2, 4, 1.2), cframe * CFrame.new(0, 2, 0), Color3.fromRGB(60, 60, 70), panel)
	-- Pantalla inclinada hacia atrás, como un atril
	local screenCFrame = cframe * CFrame.new(0, 5.5, 0) * CFrame.Angles(math.rad(15), 0, 0)
	local frame = makePart("Frame", Vector3.new(9, 5.6, 0.5), screenCFrame * CFrame.new(0, 0, 0.3), color, panel)
	frame.Material = Enum.Material.Neon
	local screen = makePart("Screen", Vector3.new(8.4, 5, 0.6), screenCFrame, Color3.fromRGB(25, 25, 35), panel)
	addText(screen, Enum.NormalId.Front, "UPGRADES", Color3.fromRGB(255, 220, 80))
	panel.PrimaryPart = screen

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Upgrades"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("BaseId", baseId)
	CollectionService:AddTag(prompt, "UpgradePrompt") -- el cliente abre la ventana y lo esconde en bases ajenas
	prompt.Parent = screen

	panel.Parent = model
end

local function buildBase(index: number, position: Vector3, parent: Instance): Model
	-- Mirando hacia el pasillo (+Z del mundo). En coordenadas locales: -Z = adelante, +Z = atrás.
	local plotCFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
	local color = cfg.BaseColors[index] or Color3.new(1, 1, 1)
	local w, d = cfg.PlotWidth, cfg.PlotDepth

	local model = Instance.new("Model")
	model.Name = `Base{index}`
	model:SetAttribute("BaseId", index)
	model:SetAttribute("OwnerUserId", 0)

	-- Piso del color de la base, con un borde más oscuro
	local edge = makePart("Edge", Vector3.new(w, PAD_HEIGHT, d), plotCFrame * CFrame.new(0, PAD_HEIGHT / 2, 0), color:Lerp(Color3.new(0, 0, 0), 0.25), model, true)
	model.PrimaryPart = edge
	makePart("Floor", Vector3.new(w - 3, 0.1, d - 3), plotCFrame * CFrame.new(0, PAD_HEIGHT + 0.05, 0), color, model, true)
	local surfaceY = PAD_HEIGHT + 0.1 -- donde se apoya todo lo de arriba

	-- Pads de incubadoras (la fase 3 pone la incubadora encima). Se numeran de izquierda a derecha, de adelante hacia atrás.
	local incubatorSlots = Instance.new("Folder")
	incubatorSlots.Name = "IncubatorSlots"
	incubatorSlots.Parent = model
	local slot = 0
	for _, z in INCUBATOR_ROWS do
		for _, x in INCUBATOR_COLUMNS do
			slot += 1
			local pad = makePad(`IncubatorSlot{slot}`, INCUBATOR_PAD_SIZE, plotCFrame * CFrame.new(x, surfaceY + 0.15, z), INCUBATOR_PAD_COLOR, incubatorSlots)
			pad:SetAttribute("SlotIndex", slot)
		end
	end

	-- Pads de mascotas: columna izquierda de adelante hacia atrás, después la derecha
	local creatureSlots = Instance.new("Folder")
	creatureSlots.Name = "CreatureSlots"
	creatureSlots.Parent = model
	local creaturePadColor = color:Lerp(Color3.new(0, 0, 0), 0.4)
	slot = 0
	for _, x in CREATURE_COLUMNS do
		for _, z in CREATURE_ROWS do
			slot += 1
			local pad = makePad(`CreatureSlot{slot}`, CREATURE_PAD_SIZE, plotCFrame * CFrame.new(x, surfaceY + 0.15, z), creaturePadColor, creatureSlots)
			pad:SetAttribute("SlotIndex", slot)
		end
	end

	-- Lugar donde aparece el jugador (en el medio libre, mirando al pasillo)
	local spawnPoint = makePart("SpawnPoint", Vector3.new(8, 0.2, 8), plotCFrame * CFrame.new(0, surfaceY + 0.1, -6), Color3.new(1, 1, 1), model)
	spawnPoint.Transparency = 0.5
	spawnPoint.CanCollide = false
	spawnPoint.CanQuery = false
	spawnPoint.Material = Enum.Material.Neon

	-- Panel de mejoras: atrás, en el medio
	buildUpgradePanel(model, index, plotCFrame * CFrame.new(0, surfaceY, d / 2 - 6), color)

	-- Volumen invisible de la base (para saber si alguien está adentro)
	makeMarker("SafeZone", Vector3.new(w, 30, d), plotCFrame * CFrame.new(0, 15, 0), model)

	buildSign(model, plotCFrame)

	model.Parent = parent
	return model
end

local function buildBases(map: Instance)
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = map

	-- Todas en una fila de izquierda a derecha, centrada, mirando al pasillo
	local rowWidth = cfg.BaseCount * cfg.PlotWidth + (cfg.BaseCount - 1) * cfg.PlotGap
	local z = -cfg.LobbyFrontWalk - cfg.PlotDepth / 2
	for i = 1, cfg.BaseCount do
		local x = -rowWidth / 2 + cfg.PlotWidth / 2 + (i - 1) * (cfg.PlotWidth + cfg.PlotGap)
		buildBase(i, Vector3.new(x, cfg.FloorY, z), basesFolder)
	end
end

function MapBuilder.Build(): Folder
	local existing = Workspace:FindFirstChild("Map")
	if existing and existing:IsA("Folder") then
		return existing
	end

	-- El Baseplate de la plantilla de Studio queda a la misma altura que nuestro piso y "parpadea".
	local templateBaseplate = Workspace:FindFirstChild("Baseplate")
	if templateBaseplate then
		warn("[MapBuilder] Removing template Baseplate (Egg Storm builds its own ground)")
		templateBaseplate:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "Map"

	buildWalls(map)
	buildLobby(map)
	buildCorridor(map)
	buildBases(map)

	map.Parent = Workspace
	return map
end

return MapBuilder

end
__loaders['CreatureService'] = function()
--!strict
-- CreatureService: las mascotas de cada jugador.
-- Las pone en los pads de su base, y cada segundo le suma la plata que generan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = __req("Config")
local Creatures = __req("Creatures")
local BaseService = __req("BaseService")
local PlayerDataService = __req("PlayerDataService")
local CreatureModels = __req("CreatureModels")

type Base = BaseService.Base
type Creature = Creatures.Creature

local CreatureService = {}

-- Modelos que están en el mundo, por jugador y por número de pad
local modelsByPlayer: { [Player]: { [number]: Model } } = {}
local random = Random.new()

local function spawnModel(player: Player, base: Base, creature: Creature, slot: number)
	local pad = base.CreatureSlots[slot]
	if not pad then
		return
	end
	-- Encima del pad, mirando hacia el pasillo (igual que la base)
	local padTop = pad.Position + Vector3.new(0, pad.Size.X / 2, 0) -- el pad es un cilindro acostado: su grosor es Size.X
	local model = CreatureModels.Build(creature, CFrame.new(padTop) * base.Facing)
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = base.Model

	local models = modelsByPlayer[player]
	if not models then
		models = {}
		modelsByPlayer[player] = models
	end
	local old = models[slot]
	if old then
		old:Destroy()
	end
	models[slot] = model
end

local function updateIncomeAttribute(player: Player)
	player:SetAttribute("Income", CreatureService.GetIncomePerSecond(player))
end

-- ===== API pública =====

function CreatureService.GetIncomePerSecond(player: Player): number
	local profile = PlayerDataService.Get(player)
	if not profile then
		return 0
	end
	local total = 0
	for _, data in profile.Creatures do
		local creature = Creatures.Get(data.CreatureId)
		local rarity = creature and Config.GetRarity(creature.RarityId)
		if rarity then
			total += rarity.CoinsPerSecond
		end
	end
	return total
end

-- Cuántos pads de mascotas libres le quedan al jugador.
function CreatureService.GetFreeSlotCount(player: Player): number
	local base = BaseService.GetBase(player)
	local profile = PlayerDataService.Get(player)
	if not base or not profile then
		return 0
	end
	return #base.CreatureSlots - #profile.Creatures
end

-- Elige una mascota al azar de esa rareza.
function CreatureService.RollCreature(rarityId: string): Creature?
	local options = Creatures.ForRarity(rarityId)
	if #options == 0 then
		return nil
	end
	return options[random:NextInteger(1, #options)]
end

-- Le da una mascota al jugador en el primer pad libre. Devuelve el número de pad, o nil si no hay lugar.
function CreatureService.AddCreature(player: Player, creature: Creature): number?
	local base = BaseService.GetBase(player)
	local profile = PlayerDataService.Get(player)
	if not base or not profile then
		return nil
	end

	local used: { [number]: boolean } = {}
	for _, data in profile.Creatures do
		used[data.Slot] = true
	end
	for slot = 1, #base.CreatureSlots do
		if not used[slot] then
			table.insert(profile.Creatures, { CreatureId = creature.Id, Slot = slot })
			spawnModel(player, base, creature, slot)
			updateIncomeAttribute(player)
			return slot
		end
	end
	return nil
end

-- Cuando el jugador recibe su base: pone las mascotas que ya tenía.
function CreatureService.SetupBase(player: Player, base: Base)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	for _, data in profile.Creatures do
		local creature = Creatures.Get(data.CreatureId)
		if creature then
			spawnModel(player, base, creature, data.Slot)
		end
	end
	updateIncomeAttribute(player)
end

-- Cuando el jugador se va: saca los modelos para dejar la base limpia.
function CreatureService.ClearBase(player: Player)
	local models = modelsByPlayer[player]
	if models then
		for _, model in models do
			model:Destroy()
		end
	end
	modelsByPlayer[player] = nil
end

function CreatureService.Init()
	-- Cobro automático: cada IncomeInterval segundos, cada jugador suma la plata de sus mascotas.
	task.spawn(function()
		while true do
			task.wait(Config.Economy.IncomeInterval)
			for _, player in Players:GetPlayers() do
				local income = CreatureService.GetIncomePerSecond(player)
				if income > 0 then
					PlayerDataService.AddCoins(player, income * Config.Economy.IncomeInterval)
				end
			end
		end
	end)
end

return CreatureService

end
__loaders['UpgradeService'] = function()
--!strict
-- UpgradeService: cobra y aplica las mejoras que se compran en el panel de la base.
-- El cliente solo dice "quiero comprar X". El servidor revisa TODO antes de cobrar:
-- que el nombre de la mejora exista, que sea tu base, que estés cerca del panel,
-- que no esté al máximo, que te alcance la plata y que no estés haciendo spam.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = __req("Config")
local Remotes = __req("Remotes")
local Upgrades = __req("Upgrades")
local Format = __req("Format")
local BaseService = __req("BaseService")
local PlayerDataService = __req("PlayerDataService")
local IncubatorService = __req("IncubatorService")
local BaseFloors = __req("BaseFloors")

type Base = BaseService.Base
type UpgradeId = Upgrades.UpgradeId

local UpgradeService = {}

local notifyRemote = Remotes.Event("Notify")
local buyRemote = Remotes.Event("BuyUpgrade")
local lastBuy: { [Player]: number } = {}

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

-- Pone la velocidad de caminata según el nivel comprado
local function applyWalkSpeed(player: Player)
	local profile = PlayerDataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not humanoid then
		return
	end
	local levels = Config.Upgrades.WalkSpeed
	humanoid.WalkSpeed = levels[math.clamp(profile.WalkSpeedLevel, 1, #levels)].Speed
end

local function isNearPanel(player: Player, base: Base): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	-- Un margen extra por el lag
	return (root.Position - base.UpgradePanel.Position).Magnitude <= Config.Upgrades.PanelDistance + 5
end

-- Hace el cambio de la mejora (ya cobrada). Devuelve false si no se pudo aplicar.
local function apply(player: Player, base: Base, id: UpgradeId): boolean
	local profile = PlayerDataService.Get(player)
	if not profile then
		return false
	end
	if id == "IncubationSpeed" then
		profile.IncubationSpeedLevel += 1
		IncubatorService.RecalculateTimes(player) -- los huevos que ya están incubando también se aceleran
		return true
	elseif id == "ExtraIncubator" then
		return IncubatorService.AddIncubator(player)
	elseif id == "WalkSpeed" then
		profile.WalkSpeedLevel += 1
		applyWalkSpeed(player)
		return true
	elseif id == "BaseFloor" then
		BaseFloors.Build(base)
		profile.BaseLevel = 2
		return true
	end
	return false
end

-- ===== API pública =====

function UpgradeService.TryBuy(player: Player, id: UpgradeId)
	local now = os.clock()
	if now - (lastBuy[player] or 0) < Config.Upgrades.BuyCooldown then
		return
	end
	lastBuy[player] = now

	local base = BaseService.GetBase(player)
	local profile = PlayerDataService.Get(player)
	if not base or not profile then
		return
	end
	if not isNearPanel(player, base) then
		return
	end

	local cost = Upgrades.GetNextCost(id, profile)
	if cost == nil then
		notify(player, `{Upgrades.DisplayNames[id]} is already maxed!`)
		return
	end
	if not PlayerDataService.SpendCoins(player, cost) then
		notify(player, `Not enough coins! You need {Format.Number(cost)}.`)
		return
	end
	if not apply(player, base, id) then
		PlayerDataService.AddCoins(player, cost) -- algo falló: devolvemos la plata
		return
	end
	PlayerDataService.SyncLevels(player)
	notify(player, `{Upgrades.DisplayNames[id]} upgraded!`)
end

-- Cuando el jugador recibe su base: segundo piso (si lo compró) y velocidad de caminata.
-- Tiene que ir ANTES que CreatureService.SetupBase, porque puede haber mascotas en el piso 2.
function UpgradeService.SetupBase(player: Player, base: Base)
	local profile = PlayerDataService.Get(player)
	if profile and profile.BaseLevel >= 2 then
		BaseFloors.Build(base)
	end
	applyWalkSpeed(player)
end

function UpgradeService.ClearBase(player: Player, base: Base)
	BaseFloors.Remove(base)
	lastBuy[player] = nil
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		applyWalkSpeed(player)
	end)
end

function UpgradeService.Init()
	buyRemote.OnServerEvent:Connect(function(player: Player, id: unknown)
		-- Lo que manda el cliente no es confiable: revisamos que sea un nombre de mejora válido
		if Upgrades.IsValid(id) then
			UpgradeService.TryBuy(player, id :: UpgradeId)
		end
	end)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return UpgradeService

end
__loaders['BaseService'] = function()
--!strict
-- BaseService: le da una base libre a cada jugador que entra y la libera cuando sale.
-- También lleva al personaje a su base cada vez que aparece (al entrar y al reaparecer).
-- Otros sistemas (huevos, incubadoras, ola) le preguntan a este servicio "¿cuál es la base de X?".

local Players = game:GetService("Players")

export type Base = {
	Id: number,
	Model: Model,
	SpawnPoint: BasePart,
	SafeZone: BasePart,
	SignLabel: TextLabel,
	Facing: CFrame, -- solo la rotación de la base: su LookVector apunta al pasillo
	UpgradePanel: BasePart, -- la pantalla del panel de mejoras (para medir distancia al comprar)
	IncubatorSlots: { BasePart }, -- pads de incubadoras, ordenados por SlotIndex
	CreatureSlots: { BasePart }, -- pads de mascotas, ordenados por SlotIndex
	Owner: Player?,
}

type BaseCallback = (player: Player, base: Base) -> ()

local BaseService = {}

local bases: { Base } = {}
local baseByPlayer: { [Player]: Base } = {}
local assignedCallbacks: { BaseCallback } = {}
local releasedCallbacks: { BaseCallback } = {}

local function updateSign(base: Base)
	local owner = base.Owner
	if owner then
		base.SignLabel.Text = `{owner.DisplayName}'s Base`
		base.SignLabel.TextColor3 = Color3.new(1, 1, 1)
	else
		base.SignLabel.Text = "Free Base"
		base.SignLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end

local function findFreeBase(): Base?
	for _, base in bases do
		if base.Owner == nil then
			return base
		end
	end
	return nil
end

-- ===== API pública =====

function BaseService.GetBase(player: Player): Base?
	return baseByPlayer[player]
end

function BaseService.GetBases(): { Base }
	return bases
end

-- Registrar funciones que se llaman cuando un jugador recibe su base (cargar datos, armar incubadoras...)
-- y cuando la suelta (guardar, limpiar). Hay que registrarlas ANTES de llamar a Init.
function BaseService.OnAssigned(callback: BaseCallback)
	table.insert(assignedCallbacks, callback)
end

function BaseService.OnReleased(callback: BaseCallback)
	table.insert(releasedCallbacks, callback)
end

-- ¿Este punto está dentro de la zona segura de la base? (lo usa la ola en la fase 5)
function BaseService.IsInsideBase(base: Base, position: Vector3): boolean
	local zone = base.SafeZone
	local localPos = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

function BaseService.TeleportToBase(player: Player)
	local base = baseByPlayer[player]
	local character = player.Character
	if not base or not character then
		return
	end
	character:PivotTo(base.SpawnPoint.CFrame + Vector3.new(0, 4, 0))
end

-- ===== Entrada / salida de jugadores =====

local function onCharacterAdded(player: Player, character: Model)
	if not character:WaitForChild("HumanoidRootPart", 10) then
		return
	end
	-- Esperamos un frame para que Roblox termine de ubicar al personaje, y recién ahí lo movemos.
	task.wait()
	if player.Character == character then
		BaseService.TeleportToBase(player)
	end
end

-- Reserva una base libre para el jugador (no espera nada). Devuelve nil si el servidor está lleno.
local function assignBase(player: Player): Base?
	local base = findFreeBase()
	if not base then
		-- No debería pasar si Max Players = 8 en Game Settings, pero por las dudas.
		player:Kick("This server is full. Please join another one!")
		return nil
	end

	base.Owner = player
	baseByPlayer[player] = base
	base.Model:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("BaseId", base.Id) -- el cliente lee este atributo para saber cuál es su base
	updateSign(base)
	return base
end

-- Avisa a los demás servicios que el jugador tiene base (cargar datos, armar incubadoras...).
-- Puede tardar: cargar los datos espera al DataStore.
local function runAssignedCallbacks(player: Player, base: Base)
	for _, callback in assignedCallbacks do
		local ok, err = pcall(function()
			callback(player, base)
		end)
		if not ok then
			warn(`[BaseService] Error setting up base {base.Id}: {err}`)
		end
	end
end

local function releaseBase(player: Player)
	local base = baseByPlayer[player]
	if not base then
		return
	end
	-- Primero avisamos (para guardar y limpiar la base) y después la liberamos
	for _, callback in releasedCallbacks do
		local ok, err = pcall(function()
			callback(player, base)
		end)
		if not ok then
			warn(`[BaseService] Error releasing base {base.Id}: {err}`)
		end
	end
	baseByPlayer[player] = nil
	base.Owner = nil
	base.Model:SetAttribute("OwnerUserId", 0)
	updateSign(base)
end

local function onPlayerAdded(player: Player)
	local base = assignBase(player)
	if not base then
		return
	end
	-- Primero conectamos el "viajar a tu base" (así el personaje va directo aunque los datos tarden en cargar)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	-- Después cargamos los datos y armamos la base
	runAssignedCallbacks(player, base)
end

-- Junta los pads de una carpeta de la base, ordenados por su número (atributo SlotIndex).
local function collectSlots(model: Model, folderName: string): { BasePart }
	local folder = model:FindFirstChild(folderName)
	assert(folder, `[BaseService] {model.Name} is missing {folderName}`)
	local slots: { BasePart } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and typeof(child:GetAttribute("SlotIndex")) == "number" then
			table.insert(slots, child)
		end
	end
	table.sort(slots, function(a, b)
		return (a:GetAttribute("SlotIndex") :: number) < (b:GetAttribute("SlotIndex") :: number)
	end)
	return slots
end

-- Lee las bases del mapa y empieza a escuchar a los jugadores.
function BaseService.Init(map: Folder)
	local basesFolder = map:FindFirstChild("Bases")
	assert(basesFolder, "[BaseService] Map is missing a 'Bases' folder")

	for _, model in basesFolder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local id = model:GetAttribute("BaseId")
		local spawnPoint = model:FindFirstChild("SpawnPoint")
		local safeZone = model:FindFirstChild("SafeZone")
		local signLabel = model:FindFirstChild("SignLabel", true)
		assert(typeof(id) == "number", `[BaseService] {model.Name} has no BaseId attribute`)
		assert(spawnPoint and spawnPoint:IsA("BasePart"), `[BaseService] {model.Name} is missing SpawnPoint`)
		assert(safeZone and safeZone:IsA("BasePart"), `[BaseService] {model.Name} is missing SafeZone`)
		assert(signLabel and signLabel:IsA("TextLabel"), `[BaseService] {model.Name} is missing SignLabel`)
		assert(model.PrimaryPart, `[BaseService] {model.Name} has no PrimaryPart`)
		local panel = model:FindFirstChild("UpgradePanel")
		local panelScreen = panel and panel:FindFirstChild("Screen")
		assert(panelScreen and panelScreen:IsA("BasePart"), `[BaseService] {model.Name} is missing UpgradePanel.Screen`)

		local base: Base = {
			Id = id,
			Model = model,
			SpawnPoint = spawnPoint,
			SafeZone = safeZone,
			SignLabel = signLabel,
			Facing = model.PrimaryPart.CFrame.Rotation,
			UpgradePanel = panelScreen,
			IncubatorSlots = collectSlots(model, "IncubatorSlots"),
			CreatureSlots = collectSlots(model, "CreatureSlots"),
			Owner = nil,
		}
		table.insert(bases, base)
		updateSign(base)
	end

	-- Orden fijo: Base1, Base2, ... así el primero que entra recibe la 1.
	table.sort(bases, function(a, b)
		return a.Id < b.Id
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(releaseBase)
	-- En Studio a veces el jugador entra antes de que corra este script: lo atendemos igual.
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return BaseService

end
__loaders['BaseFloors'] = function()
--!strict
-- BaseFloors: arma (y saca) el segundo piso de una base, la mejora "Base Floor".
-- Es una plataforma sobre columnas arriba de la mitad de atrás de la base, con más pads para mascotas.
-- Los pads nuevos se suman a base.CreatureSlots, así CreatureService los usa igual que los de abajo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = __req("Config")
local BaseService = __req("BaseService")

type Base = BaseService.Base

local BaseFloors = {}

local FLOOR_HEIGHT = 12 -- altura del piso 2
local PAD_SIZE = 8

type FloorInfo = { Model: Model, Pads: { BasePart } }
local floors: { [Base]: FloorInfo } = {}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Parent = parent
	return p
end

function BaseFloors.Has(base: Base): boolean
	return floors[base] ~= nil
end

function BaseFloors.Build(base: Base)
	if floors[base] then
		return
	end
	local primary = base.Model.PrimaryPart
	if not primary then
		return
	end
	-- Mismo sistema de coordenadas que MapBuilder: centro de la base a nivel del piso, -Z hacia el pasillo
	local plotCFrame = CFrame.new(primary.Position - Vector3.new(0, primary.Size.Y / 2, 0)) * base.Facing
	local floorPart = base.Model:FindFirstChild("Floor")
	local color = if floorPart and floorPart:IsA("BasePart") then floorPart.Color else primary.Color
	local w, d = Config.Map.PlotWidth, Config.Map.PlotDepth
	local depth = d / 2 -- cubre la mitad de atrás

	local model = Instance.new("Model")
	model.Name = "Floor2"

	-- Plataforma y columnas
	makePart("Platform", Vector3.new(w, 1, depth), plotCFrame * CFrame.new(0, FLOOR_HEIGHT + 0.5, depth / 2), color, model)
	for _, x in { -w / 2 + 1, w / 2 - 1 } do
		for _, z in { 1, depth - 1 } do
			makePart("Pillar", Vector3.new(1.5, FLOOR_HEIGHT, 1.5), plotCFrame * CFrame.new(x, FLOOR_HEIGHT / 2, z), Color3.fromRGB(240, 240, 240), model)
		end
	end
	-- Baranda de vidrio
	local railY = FLOOR_HEIGHT + 2
	local rails: { { Size: Vector3, Offset: CFrame } } = {
		{ Size = Vector3.new(w, 2, 0.4), Offset = CFrame.new(0, railY, 0.2) },
		{ Size = Vector3.new(w, 2, 0.4), Offset = CFrame.new(0, railY, depth - 0.2) },
		{ Size = Vector3.new(0.4, 2, depth), Offset = CFrame.new(-w / 2 + 0.2, railY, depth / 2) },
		{ Size = Vector3.new(0.4, 2, depth), Offset = CFrame.new(w / 2 - 0.2, railY, depth / 2) },
	}
	for _, rail in rails do
		local p = makePart("Rail", rail.Size, plotCFrame * rail.Offset, Color3.fromRGB(200, 240, 255), model)
		p.Material = Enum.Material.Glass
		p.Transparency = 0.5
	end

	-- Pads de mascotas arriba: siguen la numeración de los de abajo
	local pads: { BasePart } = {}
	local padColor = color:Lerp(Color3.new(0, 0, 0), 0.4)
	local columns = { -14, 0, 14 }
	local rows = { depth * 0.27, depth * 0.73 }
	local extra = Config.Upgrades.BaseFloor.ExtraCreatureSlots
	for _, z in rows do
		for _, x in columns do
			if #pads >= extra then
				break
			end
			local pad = makePart("CreatureSlot", Vector3.new(0.3, PAD_SIZE, PAD_SIZE), plotCFrame * CFrame.new(x, FLOOR_HEIGHT + 1.15, z) * CFrame.Angles(0, 0, math.rad(90)), padColor, model)
			pad.Shape = Enum.PartType.Cylinder
			pad.TopSurface = Enum.SurfaceType.Smooth
			pad:SetAttribute("SlotIndex", #base.CreatureSlots + 1)
			table.insert(base.CreatureSlots, pad)
			table.insert(pads, pad)
		end
	end

	model.Parent = base.Model
	floors[base] = { Model = model, Pads = pads }
end

-- Saca el piso 2 (cuando el dueño se va) y devuelve la base a sus pads originales.
function BaseFloors.Remove(base: Base)
	local info = floors[base]
	if not info then
		return
	end
	for _, pad in info.Pads do
		local index = table.find(base.CreatureSlots, pad)
		if index then
			table.remove(base.CreatureSlots, index)
		end
	end
	info.Model:Destroy()
	floors[base] = nil
end

return BaseFloors

end
__loaders['EggService'] = function()
--!strict
-- EggService: hace caer huevos en la zona de peligro y deja que los jugadores los agarren y los lleven.
-- Cada huevo es un objeto del servidor (tabla Egg) con su rareza, su Part y su estado.
-- El cliente nunca dice "agarré un huevo": solo aprieta el ProximityPrompt y el servidor decide si vale.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = __req("Config")
local Remotes = __req("Remotes")
local BaseService = __req("BaseService")

type Rarity = Config.Rarity

export type EggState = "Falling" | "Ground" | "Carried"

export type Egg = {
	Id: number,
	Rarity: Rarity,
	Part: BasePart,
	Prompt: ProximityPrompt,
	State: EggState,
	Carrier: Player?,
}

-- Efectos visuales por rareza (no son balance, por eso no están en Config).
type Visual = {
	LightBrightness: number,
	LightRange: number,
	Sparkles: number, -- partículas por segundo (0 = sin partículas)
	Beacon: boolean, -- columna de luz cuando está en el piso, para verlo de lejos
	Rainbow: boolean,
}

local VISUALS: { [string]: Visual } = {
	Common = { LightBrightness = 0.5, LightRange = 6, Sparkles = 0, Beacon = false, Rainbow = false },
	Rare = { LightBrightness = 1, LightRange = 10, Sparkles = 3, Beacon = false, Rainbow = false },
	Epic = { LightBrightness = 2, LightRange = 14, Sparkles = 8, Beacon = false, Rainbow = false },
	Legendary = { LightBrightness = 3, LightRange = 18, Sparkles = 15, Beacon = true, Rainbow = false },
	Secret = { LightBrightness = 3, LightRange = 20, Sparkles = 25, Beacon = true, Rainbow = true },
}

local EGG_SIZE = Vector3.new(3, 4, 3)
local FLOOR_Y = Config.Map.FloorY

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 255, 100)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 80, 255)),
})

local EggService = {}

local random = Random.new()
local eggsFolder: Folder
local eggs: { [number]: Egg } = {}
local carriedByPlayer: { [Player]: Egg } = {}
local lastGrabAttempt: { [Player]: number } = {}
local nextEggId = 0
local raining = false

local notifyRemote = Remotes.Event("Notify")

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

-- ===== Sorteo de rareza y posición =====

local function rollRarity(): Rarity
	local total = 0
	for _, rarity in Config.Rarities do
		total += rarity.Weight
	end
	local roll = random:NextNumber(0, total)
	for _, rarity in Config.Rarities do
		roll -= rarity.Weight
		if roll <= 0 then
			return rarity
		end
	end
	return Config.Rarities[1]
end

-- Un punto al azar dentro del tramo del pasillo que le toca a esta rareza.
local function randomLandingPosition(rarity: Rarity): Vector3
	local map = Config.Map
	local halfWidth = map.CorridorWidth / 2 - map.EggSideMargin
	local x = random:NextNumber(-halfWidth, halfWidth)
	local z = random:NextNumber(rarity.ZoneStart, rarity.ZoneEnd) * map.CorridorLength
	return Vector3.new(x, FLOOR_Y + EGG_SIZE.Y / 2, z)
end

local function countEggsInWorld(): number
	local count = 0
	for _, egg in eggs do
		if egg.State ~= "Carried" then
			count += 1
		end
	end
	return count
end

-- ===== Armado del huevo =====

local function createEggPart(egg: { Id: number, Rarity: Rarity }): (BasePart, ProximityPrompt)
	local rarity = egg.Rarity
	local visual = VISUALS[rarity.Id] or VISUALS.Common

	local part = Instance.new("Part")
	part.Name = `{rarity.Id}Egg`
	part.Size = EGG_SIZE
	part.Color = rarity.Color
	part.Material = if rarity.Id == "Secret" then Enum.Material.Glass else Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part:SetAttribute("EggId", egg.Id)
	part:SetAttribute("Rarity", rarity.Id)

	-- Un SpecialMesh esférico estira la Part y le da forma de huevo.
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part

	local light = Instance.new("PointLight")
	light.Color = if visual.Rainbow then Color3.new(1, 1, 1) else rarity.Color
	light.Brightness = visual.LightBrightness
	light.Range = visual.LightRange
	light.Parent = part

	if visual.Sparkles > 0 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Color = if visual.Rainbow then RAINBOW else ColorSequence.new(rarity.Color)
		sparkles.LightEmission = 1
		sparkles.Rate = visual.Sparkles
		sparkles.Lifetime = NumberRange.new(0.8, 1.5)
		sparkles.Speed = NumberRange.new(1, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.4, 0)
		sparkles.Parent = part
	end

	-- Explosión de partículas al tocar el piso (Rate 0: solo sale cuando la disparamos con :Emit)
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "LandingBurst"
	burst.Color = if visual.Rainbow then RAINBOW else ColorSequence.new(rarity.Color)
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.4, 0.8)
	burst.Speed = NumberRange.new(10, 18)
	burst.SpreadAngle = Vector2.new(80, 80)
	burst.Size = NumberSequence.new(0.6, 0)
	burst.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = `{rarity.DisplayName} Egg`
	prompt.HoldDuration = Config.Eggs.GrabHoldTime
	prompt.MaxActivationDistance = Config.Eggs.GrabDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- se habilita cuando aterriza
	prompt.Parent = part

	return part, prompt
end

-- Círculo en el piso que avisa dónde va a caer el huevo.
local function createLandingMarker(position: Vector3, color: Color3): Part
	local marker = Instance.new("Part")
	marker.Name = "LandingMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.1, 6, 6)
	marker.CFrame = CFrame.new(position.X, FLOOR_Y + 0.15, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	marker.Color = color
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.5
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Parent = eggsFolder
	return marker
end

local function addBeacon(egg: Egg)
	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(80, 1.5, 1.5)
	-- Cilindro parado: el eje X apunta para arriba
	beacon.CFrame = CFrame.new(egg.Part.Position + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Color = if egg.Rarity.Id == "Secret" then Color3.new(1, 1, 1) else egg.Rarity.Color
	beacon.Material = Enum.Material.Neon
	beacon.Transparency = 0.6
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanTouch = false
	beacon.CanQuery = false
	beacon.Parent = egg.Part
end

-- ===== Ciclo de vida =====

local function destroyEgg(egg: Egg)
	eggs[egg.Id] = nil
	if egg.Carrier then
		carriedByPlayer[egg.Carrier] = nil
		egg.Carrier:SetAttribute("CarriedEggRarity", nil)
		egg.Carrier = nil
	end
	egg.Part:Destroy()
end

local function onLanded(egg: Egg, marker: Part)
	marker:Destroy()
	if eggs[egg.Id] ~= egg or egg.State ~= "Falling" then
		return -- lo borró la ola mientras caía
	end
	egg.State = "Ground"
	egg.Prompt.Enabled = true

	local burst = egg.Part:FindFirstChild("LandingBurst")
	if burst and burst:IsA("ParticleEmitter") then
		burst:Emit(25)
	end
	if (VISUALS[egg.Rarity.Id] or VISUALS.Common).Beacon then
		addBeacon(egg)
	end
end

local function spawnEgg()
	if countEggsInWorld() >= Config.Eggs.MaxOnGround then
		return
	end

	nextEggId += 1
	local rarity = rollRarity()
	local part, prompt = createEggPart({ Id = nextEggId, Rarity = rarity })
	local egg: Egg = {
		Id = nextEggId,
		Rarity = rarity,
		Part = part,
		Prompt = prompt,
		State = "Falling",
		Carrier = nil,
	}
	eggs[egg.Id] = egg

	local landing = randomLandingPosition(rarity)
	local spin = CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	part.CFrame = CFrame.new(landing + Vector3.new(0, Config.Eggs.FallHeight, 0)) * spin
	part.Parent = eggsFolder
	local marker = createLandingMarker(landing, rarity.Color)

	prompt.Triggered:Connect(function(player)
		EggService.TryGrab(player, egg)
	end)

	-- Caída: acelera hacia el final (Quad In), como si fuera gravedad.
	local tween = TweenService:Create(
		part,
		TweenInfo.new(Config.Eggs.FallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(landing) * spin }
	)
	tween.Completed:Connect(function()
		onLanded(egg, marker)
	end)
	tween:Play()
end

local function attachToCharacter(egg: Egg, character: Model): boolean
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return false
	end

	local beacon = egg.Part:FindFirstChild("Beacon")
	if beacon then
		beacon:Destroy()
	end
	egg.Prompt.Enabled = false

	local part = egg.Part
	part.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + Config.Eggs.CarryHeight, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
	part.Massless = true -- que no pese ni cambie cómo camina el personaje
	part.CanQuery = false
	part.Anchored = false
	return true
end

-- ===== API pública =====

-- Lo llama el ProximityPrompt. Valida TODO en el servidor antes de dar el huevo.
function EggService.TryGrab(player: Player, egg: Egg)
	if eggs[egg.Id] ~= egg or egg.State ~= "Ground" then
		return
	end

	-- Anti-spam
	local now = os.clock()
	if now - (lastGrabAttempt[player] or 0) < Config.Eggs.GrabCooldown then
		return
	end
	lastGrabAttempt[player] = now

	if carriedByPlayer[player] then
		notify(player, "You can only carry 1 egg at a time!")
		return
	end
	if not BaseService.GetBase(player) then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	-- Distancia: un margen extra por el lag, pero nada de agarrar desde lejos.
	if (root.Position - egg.Part.Position).Magnitude > Config.Eggs.GrabDistance + 5 then
		return
	end

	if not attachToCharacter(egg, character) then
		return
	end
	egg.State = "Carried"
	egg.Carrier = player
	carriedByPlayer[player] = egg
	player:SetAttribute("CarriedEggRarity", egg.Rarity.Id) -- para que el cliente pueda mostrarlo
	notify(player, `You grabbed a {egg.Rarity.DisplayName} Egg! Bring it to your base.`)
end

function EggService.GetCarriedEgg(player: Player): Egg?
	return carriedByPlayer[player]
end

-- El jugador entrega el huevo que lleva (por ejemplo, a una incubadora). Devuelve su rareza.
function EggService.TakeCarriedEgg(player: Player): Rarity?
	local egg = carriedByPlayer[player]
	if not egg then
		return nil
	end
	local rarity = egg.Rarity
	destroyEgg(egg)
	return rarity
end

-- El jugador pierde el huevo que lleva (muerte, ola, salida del juego).
function EggService.LoseCarriedEgg(player: Player)
	local egg = carriedByPlayer[player]
	if egg then
		destroyEgg(egg)
	end
end

-- Borra los huevos que están en el piso o cayendo (lo va a usar la ola en la fase 5).
function EggService.ClearWorldEggs()
	for _, egg in eggs do
		if egg.State ~= "Carried" then
			destroyEgg(egg)
		end
	end
	-- Los círculos de aviso de huevos que estaban cayendo
	for _, child in eggsFolder:GetChildren() do
		if child.Name == "LandingMarker" then
			child:Destroy()
		end
	end
end

-- Borra los huevos del piso que la ola ya alcanzó (los que están en Z >= frontZ).
function EggService.ClearWorldEggsBeyond(frontZ: number)
	for _, egg in eggs do
		if egg.State ~= "Carried" and egg.Part.Position.Z >= frontZ then
			destroyEgg(egg)
		end
	end
	for _, child in eggsFolder:GetChildren() do
		if child.Name == "LandingMarker" and child:IsA("BasePart") and child.Position.Z >= frontZ then
			child:Destroy()
		end
	end
end

-- Prende/apaga la lluvia de huevos (el ciclo de tormenta de la fase 5 va a usar esto).
function EggService.SetRaining(on: boolean)
	raining = on
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			EggService.LoseCarriedEgg(player)
		end)
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
	player.CharacterRemoving:Connect(function()
		EggService.LoseCarriedEgg(player)
	end)
end

function EggService.Init()
	eggsFolder = Instance.new("Folder")
	eggsFolder.Name = "Eggs"
	eggsFolder.Parent = Workspace

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		EggService.LoseCarriedEgg(player)
		lastGrabAttempt[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Eggs.SpawnInterval)
			if raining then
				spawnEgg()
			end
		end
	end)
end

return EggService

end
local function __mod(n) return __req(n) end
task.spawn(function()
__mod("Config").Storm.RainDuration = 45

end)
task.spawn(function()
--!strict
-- Punto de entrada del servidor: arranca cada servicio en orden.
-- Cada servicio se encarga de una parte del juego (ver README).


local MapBuilder = __req("MapBuilder")
local BaseService = __req("BaseService")
local PlayerDataService = __req("PlayerDataService")
local EggService = __req("EggService")
local CreatureService = __req("CreatureService")
local IncubatorService = __req("IncubatorService")
local UpgradeService = __req("UpgradeService")
local StormService = __req("StormService")

local map = MapBuilder.Build()

PlayerDataService.Init()
EggService.Init()
CreatureService.Init()
IncubatorService.Init()
UpgradeService.Init()

-- Para el autoguardado: así PlayerDataService puede guardar los huevos que se están incubando ahora mismo
PlayerDataService.SetIncubatingProvider(IncubatorService.GetSnapshot)

-- Cuando un jugador recibe su base: cargamos sus datos y armamos su base.
-- El orden importa: las mejoras primero (el piso 2 tiene que existir antes de poner mascotas ahí).
BaseService.OnAssigned(function(player, base)
	-- Load espera al DataStore. Si devuelve nil, el jugador se fue mientras cargaba (o lo tuvimos que sacar).
	if not PlayerDataService.Load(player) then
		return
	end
	UpgradeService.SetupBase(player, base)
	CreatureService.SetupBase(player, base)
	IncubatorService.SetupBase(player, base)
end)

-- Cuando se va: limpiamos su base (las incubadoras pasan sus huevos al perfil) y guardamos sus datos.
BaseService.OnReleased(function(player, base)
	IncubatorService.ClearBase(player)
	CreatureService.ClearBase(player)
	UpgradeService.ClearBase(player, base)
	PlayerDataService.Unload(player)
end)

-- Init de BaseService va al final: recién ahí empieza a repartir bases (y a llamar a lo de arriba).
BaseService.Init(map)

-- El ciclo de tormenta (lluvia → aviso → ola → calma) prende y apaga la lluvia de huevos.
StormService.Init()

print("[EggStorm] Server ready")

end)
task.spawn(function()

local Config = __mod("Config")
local PDS = __mod("PlayerDataService")
local BaseService = __mod("BaseService")
local Eggs = __mod("EggService")
local Remotes = __mod("Remotes")
local buy = Remotes.Event("BuyUpgrade")
local Workspace = game:GetService("Workspace")

local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
local function phase() return Workspace:GetAttribute("StormPhase") end
local function nearestEgg(maxZ)
	local best, bestPrompt
	for _, child in Workspace.Eggs:GetChildren() do
		local prompt = child:FindFirstChild("ProximityPrompt")
		if prompt and prompt.Enabled and child.Position.Z <= maxZ and (not best or child.Position.Z < best.Position.Z) then
			best, bestPrompt = child, prompt
		end
	end
	return best, bestPrompt
end
local function grab(p, maxZ)
	local egg, prompt = nearestEgg(maxZ)
	if not egg then return nil end
	MOVE_TO(p, egg.Position); prompt.Triggered:Fire(p); ADVANCE(0.6)
	return p:GetAttribute("CarriedEggRarity")
end
local function incubate(p)
	local inc = BaseService.GetBase(p).Model:FindFirstChild("Incubator1")
	MOVE_TO(p, inc.Base.Position); ADVANCE(0.6); inc.Base.ProximityPrompt.Triggered:Fire(p); ADVANCE(0.2)
	return inc:FindFirstChild("Egg") ~= nil
end

-- DataStore lento: la primera lectura falla (reintento en 1 s)
STORE_FAIL_NEXT = 1
local alice = ADD_PLAYER("Alice", 1001); SPAWN_CHARACTER(alice)
ADVANCE(0.3)
local baseA = BaseService.GetBase(alice)
check(PDS.Get(alice) == nil, "Alice's data is still loading...")
check((alice.Character.HumanoidRootPart.Position - baseA.SpawnPoint.Position).Magnitude < 6, "...but she is already standing in her base")
ADVANCE(2)
check(PDS.Get(alice) ~= nil and baseA.Model:FindFirstChild("Incubator1") ~= nil, "data loads and her base is built")

local bob = ADD_PLAYER("Bob", 1002); SPAWN_CHARACTER(bob); ADVANCE(1)
check(BaseService.GetBase(bob).Id == 2, "Bob gets base 2")

-- Ronda 1: los dos juntan huevos
ADVANCE(15)
local rA = grab(alice, 300)
check(rA ~= nil, "Alice grabs an egg (" .. tostring(rA) .. ")")
check(incubate(alice), "Alice incubates it")
local rB = grab(bob, 300)
check(rB ~= nil, "Bob grabs an egg (" .. tostring(rB) .. ")")
MOVE_TO(bob, Vector3.new(0, 3, 250)) -- Bob se queda en la arena con el huevo

-- Aviso y ola
while phase() ~= "Wave" do ADVANCE(0.1) end
while phase() == "Wave" do ADVANCE(0.1) end
check(bob.Character.Humanoid.Health == 0 and Eggs.GetCarriedEgg(bob) == nil, "the wave gets Bob and he loses his egg")
check(alice.Character.Humanoid.Health > 0, "Alice (in her base) survives")
SPAWN_CHARACTER(bob); ADVANCE(0.5)
check((bob.Character.HumanoidRootPart.Position - BaseService.GetBase(bob).SpawnPoint.Position).Magnitude < 6, "Bob respawns in his base")

-- El huevo de Alice se abre en algún momento
ADVANCE(150)
local profileA = PDS.Get(alice)
check(#profileA.Creatures == 1, "Alice's egg hatched into a creature")
check(profileA.Coins > 0, "Alice earns coins (" .. profileA.Coins .. ")")

-- Alice compra una mejora con lo que ganó
PDS.AddCoins(alice, 300)
MOVE_TO(alice, baseA.UpgradePanel.Position + Vector3.new(0, 0, -4)); ADVANCE(0.5)
buy.OnServerEvent:Fire(alice, "WalkSpeed"); ADVANCE(0.2)
check(alice.Character.Humanoid.WalkSpeed == 20, "Alice buys Walk Speed")

-- Bob intenta comprar desde la base de Alice: no puede
local coinsB = PDS.Get(bob).Coins
PDS.AddCoins(bob, 1000)
MOVE_TO(bob, baseA.UpgradePanel.Position); ADVANCE(0.5)
buy.OnServerEvent:Fire(bob, "WalkSpeed"); ADVANCE(0.2)
check(PDS.Get(bob).WalkSpeedLevel == 1, "Bob can't buy from Alice's panel")

-- Alice sale y vuelve: todo sigue ahí
local coinsBeforeLeave = profileA.Coins
REMOVE_PLAYER(alice); ADVANCE(1)
check(baseA.Owner == nil, "base 1 is free after Alice leaves")
local alice2 = ADD_PLAYER("Alice", 1001); SPAWN_CHARACTER(alice2); ADVANCE(1)
local p2 = PDS.Get(alice2)
check(p2 and p2.WalkSpeedLevel == 2 and #p2.Creatures == 1 and p2.Coins >= coinsBeforeLeave, "Alice comes back with her creature, coins and upgrades")
check(alice2.Character.Humanoid.WalkSpeed == 20, "her walk speed is applied again")

-- El servidor se apaga: se guarda a los dos
PDS.AddCoins(bob, 77)
local expectedBob = PDS.Get(bob).Coins
task.spawn(CLOSE_FNS[1]); ADVANCE(3)
check(STORE_DATA["Player_1002"] and STORE_DATA["Player_1002"].Coins == expectedBob, "shutdown saves Bob too")

print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

end)
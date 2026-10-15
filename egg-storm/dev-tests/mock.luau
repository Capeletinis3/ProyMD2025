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

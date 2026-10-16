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
	DescendantAdded = true, PromptGamePassPurchaseFinished = true,
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
	if k == "GetDescendants" then
		return function(s)
			local list = {}
			local function walk(o) for _, c in rawget(o, "_children") do table.insert(list, c); walk(c) end end
			walk(s)
			return list
		end
	end
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
	VOXEL_WRITES = 0
	VOXEL_COUNT = 0
	rawget(terrain, "_props").FillBall = function() end
	rawget(terrain, "_props").SetMaterialColor = function() end
	rawget(terrain, "_props").WriteVoxels = function(_, region, res, materials, occupancy)
		assert(res == 4, "resolution must be 4")
		local size = (region.Max - region.Min) / 4
		assert(#materials == size.X and #materials[1] == size.Y and #materials[1][1] == size.Z, "voxel arrays must match the region")
		VOXEL_WRITES += 1
		VOXEL_COUNT += size.X * size.Y * size.Z
	end
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

-- VIP: grupos de colisión y Game Pass falsos
COLLIDABLE = {}
PASS_OWNERS = {}
PASS_FAIL = false
PURCHASE_PROMPTS = {}
do
	local physics = game:GetService("PhysicsService")
	rawget(physics, "_props").RegisterCollisionGroup = function() end
	rawget(physics, "_props").CollisionGroupSetCollidable = function(_, a, b, v) COLLIDABLE[a .. "|" .. b] = v end
	local market = game:GetService("MarketplaceService")
	rawget(market, "_props").UserOwnsGamePassAsync = function(_, userId, passId)
		task.wait(0.05)
		if PASS_FAIL then error("Marketplace unavailable (simulated)") end
		return PASS_OWNERS[userId .. ":" .. passId] == true
	end
	rawget(market, "_props").PromptGamePassPurchase = function(_, player, passId) table.insert(PURCHASE_PROMPTS, { player, passId }) end
	PRODUCT_PROMPTS = {}
	rawget(market, "_props").PromptProductPurchase = function(_, player, productId) table.insert(PRODUCT_PROMPTS, { player, productId }) end
end

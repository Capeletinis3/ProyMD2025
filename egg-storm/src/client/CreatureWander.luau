--!strict
-- CreatureWander: hace pasear a las criaturas por su hábitat (diseño "Hábitat v3").
-- Cada criatura camina dando saltitos alrededor de su lugar, se queda quieta mirando un rato y a veces se echa a dormir.
-- Lo hace cada cliente en su pantalla (el servidor solo pone la criatura en su lugar), así no se manda movimiento por la red.
-- Mueve los Models con la etiqueta "WanderingCreature" usando su atributo WanderRadius. Las lejanas no se mueven.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local CreatureWander = {}

local WALK_SPEED = 3.2 -- studs por segundo
local TURN_SPEED = 5 -- radianes por segundo
local HOP_HEIGHT = 0.45
local HOP_RATE = 7 -- saltitos por segundo (más o menos)

type Walker = {
	Model: Model,
	Home: CFrame,
	Offset: Vector3, -- dónde está ahora, respecto del lugar
	Target: Vector3,
	Yaw: number,
	State: string, -- "Walk", "Idle" o "Sleep"
	Timer: number,
	Radius: number,
	Phase: number,
	Rng: Random,
}

local walkers: { [Model]: Walker } = {}

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function pickTarget(w: Walker)
	local angle = w.Rng:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(w.Rng:NextNumber(0, 1)) * w.Radius
	w.Target = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	w.State = "Walk"
end

local function rest(w: Walker)
	if w.Rng:NextNumber() < 0.12 then
		w.State = "Sleep"
		w.Timer = w.Rng:NextNumber(8, 16)
	else
		w.State = "Idle"
		w.Timer = w.Rng:NextNumber(1.5, 4.5)
	end
end

local function track(instance: Instance)
	if not instance:IsA("Model") or walkers[instance] then
		return
	end
	local radius = instance:GetAttribute("WanderRadius")
	local home = instance:GetPivot()
	local seed = math.floor(home.Position.X * 13 + home.Position.Z * 7) % 100000
	local w: Walker = {
		Model = instance,
		Home = CFrame.new(home.Position),
		Offset = Vector3.zero,
		Target = Vector3.zero,
		Yaw = yawOf(home),
		State = "Idle",
		Timer = 0,
		Radius = if typeof(radius) == "number" then radius else Config.Habitat.WanderRadius,
		Phase = seed / 1000,
		Rng = Random.new(seed),
	}
	w.Timer = w.Rng:NextNumber(0, 3)
	walkers[instance] = w
end

local function untrack(instance: Instance)
	if instance:IsA("Model") then
		walkers[instance] = nil
	end
end

local function turnTowards(current: number, wanted: number, step: number): number
	local diff = (wanted - current + math.pi) % (math.pi * 2) - math.pi
	return current + math.clamp(diff, -step, step)
end

local function step(w: Walker, dt: number, t: number)
	local hop = 0
	local tilt = 0
	if w.State == "Walk" then
		local toTarget = w.Target - w.Offset
		local distance = toTarget.Magnitude
		if distance < 0.3 then
			rest(w)
		else
			local wanted = math.atan2(-toTarget.X, -toTarget.Z)
			w.Yaw = turnTowards(w.Yaw, wanted, TURN_SPEED * dt)
			-- Camina solo cuando ya mira más o menos para donde va
			local facing = Vector3.new(-math.sin(w.Yaw), 0, -math.cos(w.Yaw))
			if facing:Dot(toTarget.Unit) > 0.6 then
				w.Offset += toTarget.Unit * math.min(distance, WALK_SPEED * dt)
				hop = math.abs(math.sin((t + w.Phase) * HOP_RATE)) * HOP_HEIGHT
			end
		end
	else
		w.Timer -= dt
		if w.State == "Sleep" then
			tilt = math.rad(70) -- echada de costado
			hop = -0.3
		else
			-- Respira (sube y baja apenas)
			hop = math.sin((t + w.Phase) * 2) * 0.06
		end
		if w.Timer <= 0 then
			pickTarget(w)
		end
	end
	w.Model:PivotTo(w.Home * CFrame.new(w.Offset + Vector3.new(0, hop, 0)) * CFrame.Angles(0, w.Yaw, 0) * CFrame.Angles(0, 0, tilt))
end

function CreatureWander.Start()
	for _, model in CollectionService:GetTagged("WanderingCreature") do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal("WanderingCreature"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("WanderingCreature"):Connect(untrack)

	local player = Players.LocalPlayer
	local viewDistance = Config.Habitat.WanderViewDistance
	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		local camera = Workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local eye = if root and root:IsA("BasePart") then root.Position elseif camera then camera.CFrame.Position else Vector3.zero
		for model, w in walkers do
			if not model.Parent then
				walkers[model] = nil
			elseif (w.Home.Position - eye).Magnitude < viewDistance then
				step(w, math.min(dt, 0.1), t)
			end
		end
	end)
end

return CreatureWander

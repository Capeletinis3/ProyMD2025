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

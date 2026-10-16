--!strict
-- WaveVisual: el dibujo de la ola (estilo dibujo animado, como el resto del juego).
-- Vista de costado (la ola avanza hacia -X, el lobby):
--
--            ___
--         .-'   '-.__        ← cresta con espuma que se enrosca hacia adelante
--        (  .-.      '-._
--         \ \  \         '-._     ← lomo que baja despacio hacia atrás
--          ) )  |            '-._
--   ~~~~~~'~'~~~'~~~~~~~~~~~~~~~~~'~~
--   frente (x = 0)                 atrás (x = Largo)
--
-- La arma cada cliente: capas horizontales de agua (más oscuras abajo, más claras arriba), el rulo de la cresta,
-- bolas de espuma, salpicaduras y espuma en la base. Se mueve un poco (ondula) mientras avanza.
-- Solo es lo que se VE: a quién agarra la ola lo decide el servidor (WaveService) con su frente en x = 0.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local WaveVisual = {}

local DEEP = Color3.fromRGB(16, 92, 158)
local MID = Color3.fromRGB(32, 150, 205)
local LIGHT = Color3.fromRGB(110, 214, 240)
local FOAM = Color3.fromRGB(245, 252, 255)

export type Wave = {
	Model: Model,
	Height: number,
	Parts: { BasePart },
	Wobble: { Entry },
	Fade: (Wave) -> (),
	Update: (Wave, number) -> (),
}

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Dónde está el frente y el lomo de la ola a esta altura (t = 0 abajo, 1 arriba), en studs desde el frente
local function frontAt(t: number, height: number): number
	-- abajo un poco hueca (la cara de la ola se mete) y arriba la cresta sale hacia adelante
	return 0.16 * height * math.sin(math.pi * math.min(t / 0.7, 1)) - 0.34 * height * smoothstep(0.55, 0.97, t)
end

local function backAt(t: number, height: number): number
	local length = height * 2.4
	return 0.12 * height + length * (1 - t) ^ 0.75
end

type Entry = { Part: BasePart, Base: CFrame, Amount: number, Phase: number }
local building: { Entry } = {} -- las piezas de la ola que se está armando (todas siguen al frente)

local function newPart(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	local entry: Entry = { Part = p :: BasePart, Base = cf, Amount = 0, Phase = 0 }
	table.insert(building, entry)
	return p
end

-- Hace que la última pieza agregada ondule un poco
local function wobbles(amount: number, phase: number)
	local entry = building[#building]
	entry.Amount = amount
	entry.Phase = phase
end

local function emitter(parent: Instance, name: string, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
end

-- Una tabla girada que va de "a" a "b" (en el plano de costado de la ola) y cruza todo el ancho
local function along(a: Vector3, b: Vector3): CFrame
	local up = (b - a).Unit
	local back = Vector3.new(0, 0, 1)
	return CFrame.fromMatrix((a + b) / 2, up:Cross(back), up, back)
end

local function colorAt(t: number): Color3
	if t < 0.5 then
		return DEEP:Lerp(MID, t / 0.5)
	end
	return MID:Lerp(LIGHT, (t - 0.5) / 0.5)
end

-- Arma la ola. Su "pivote" es el frente, al nivel del piso del cañón y en el medio de su ancho.
function WaveVisual.Build(height: number): Wave
	local width = Config.Waves.Width
	local model = Instance.new("Model")
	model.Name = "Wave"
	local parts: { BasePart } = {}
	building = {}

	local pivot = newPart(model, "Pivot", Vector3.new(1, 1, 1), CFrame.new(), LIGHT, Enum.Material.SmoothPlastic, 1)
	model.PrimaryPart = pivot

	-- Relleno: unos bloques oscuros por dentro (no se ven, tapan los huecos entre las tablas del borde)
	local fills = 14
	for i = 0, fills - 1 do
		local tm = (i + 0.5) / fills
		local t0, t1 = i / fills, (i + 1) / fills
		-- (que no se salga del borde en ninguna parte de su franja)
		local f = math.max(frontAt(t0, height), frontAt(t1, height), frontAt(tm, height)) + 1.5
		local b = math.min(backAt(t0, height), backAt(t1, height)) - 1.5
		if b > f then
			newPart(model, "WaterFill", Vector3.new(b - f, height / fills + 0.5, width - 0.4), CFrame.new((f + b) / 2, tm * height, 0), colorAt(tm * 0.6), Enum.Material.Ice)
			wobbles(0.4 + tm, i * 0.5)
		end
	end

	-- El borde de la ola: una línea de puntos que sube por el frente, da la vuelta en el rulo de la cresta y baja por el lomo.
	-- Cada tramo es una tabla girada, así la silueta queda curva (y no en escalones).
	type Point = { P: Vector3, Color: Color3, Wobble: number }
	local outline: { Point } = {}
	local steps = 14
	for k = 0, steps do
		local t = k / steps * 0.9
		table.insert(outline, { P = Vector3.new(frontAt(t, height), t * height, 0), Color = MID:Lerp(LIGHT, t), Wobble = 0.5 + t })
	end
	-- Rulo: de la punta de la cresta da media vuelta hacia adentro (hacia la cara de la ola)
	local lipX = frontAt(0.97, height)
	local curlCenter = Vector3.new(lipX + 0.13 * height, 0.8 * height, 0)
	local curlRadius = 0.15 * height
	local top = Vector3.new(frontAt(0.97, height) + 0.05 * height, 0.97 * height, 0)
	table.insert(outline, { P = top, Color = LIGHT:Lerp(FOAM, 0.3), Wobble = 1.6 })
	-- (el lomo arranca arriba de la cresta y baja despacio hacia atrás)
	for k = 1, steps do
		local t = 0.97 - k / steps * 0.97
		table.insert(outline, { P = Vector3.new(backAt(t, height), t * height, 0), Color = LIGHT:Lerp(DEEP, 1 - t), Wobble = 0.4 + t * 1.2 })
	end
	local thickness = math.max(2.5, height * 0.06)
	for k = 1, #outline - 1 do
		local a, b = outline[k], outline[k + 1]
		local dir = b.P - a.P
		local cf = along(a.P, b.P)
		newPart(model, "Water", Vector3.new(thickness, dir.Magnitude + thickness * 0.8, width), cf, a.Color:Lerp(b.Color, 0.5), Enum.Material.Ice).Reflectance = 0.06
		wobbles(a.Wobble, k * 0.35)
	end
	-- El rulo que cae adelante de la cara (agua clara, cada vez más espuma)
	local segments = 8
	for s = 0, segments - 1 do
		local a0 = math.rad(80 + s * (200 / segments))
		local a1 = math.rad(80 + (s + 1) * (200 / segments))
		local p0 = curlCenter + Vector3.new(-math.cos(a0) * curlRadius, math.sin(a0) * curlRadius, 0)
		local p1 = curlCenter + Vector3.new(-math.cos(a1) * curlRadius, math.sin(a1) * curlRadius, 0)
		local dir = p1 - p0
		-- (el largo de la pieza, su eje Y, sigue el arco; el ancho, su eje Z, cruza el cañón)
		local cf = along(p0, p1)
		local curlThickness = thickness * (1.2 - s / segments * 0.6)
		newPart(model, "Curl", Vector3.new(curlThickness, dir.Magnitude + 0.8, width), cf, LIGHT:Lerp(FOAM, s / segments * 0.7), Enum.Material.Ice, s / segments * 0.25)
		wobbles(1.4, 3 + s * 0.6)
	end

	-- Espuma: bolas blancas a lo largo de la cresta y en la base del frente
	local foamCount = math.floor(width / 7)
	for k = 0, foamCount do
		local z = -width / 2 + k * (width / foamCount)
		local size = height * (0.13 + 0.05 * math.sin(k * 1.7))
		local crest = CFrame.new(lipX + 0.12 * height, 0.97 * height, z)
		local blob = newPart(model, "CrestFoam", Vector3.new(size * 1.3, size * 0.8, size * 1.4), crest, FOAM, Enum.Material.Snow, 0.05)
		blob.Shape = Enum.PartType.Ball
		table.insert(parts, blob)
		wobbles(1.5, k * 0.9)
		local baseCf = CFrame.new(-0.05 * height, 0.04 * height, z + 3)
		local baseFoam = newPart(model, "BaseFoam", Vector3.new(size * 1.6, size * 0.6, size * 1.6), baseCf, FOAM, Enum.Material.Snow, 0.15)
		baseFoam.Shape = Enum.PartType.Ball
		table.insert(parts, baseFoam)
		wobbles(1, k * 1.3)
	end

	-- Salpicaduras: de la cresta (hacia adelante y arriba) y de la base (rocío que avanza)
	local crestSpray = newPart(model, "CrestSpray", Vector3.new(4, 2, width), CFrame.new(lipX, 0.98 * height, 0), FOAM, Enum.Material.SmoothPlastic, 1)
	emitter(crestSpray, "Spray", {
		Color = ColorSequence.new(FOAM),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(10, 22),
		Acceleration = Vector3.new(0, -30, 0),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Left, -- hacia -X (adelante)
		Rate = 140,
	})
	local baseSpray = newPart(model, "BaseSpray", Vector3.new(2, 2, width), CFrame.new(-2, 1, 0), FOAM, Enum.Material.SmoothPlastic, 1)
	emitter(baseSpray, "Mist", {
		Color = ColorSequence.new(FOAM),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(14, 24),
		SpreadAngle = Vector2.new(25, 15),
		EmissionDirection = Enum.NormalId.Left,
		Rate = 90,
	})
	emitter(baseSpray, "Drops", {
		Color = ColorSequence.new(LIGHT:Lerp(FOAM, 0.5)),
		Size = NumberSequence.new(0.6, 0.2),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(16, 30),
		Acceleration = Vector3.new(0, -50, 0),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
		Rate = 120,
	})

	model.Parent = Workspace

	local wave: Wave = {
		Model = model,
		Height = height,
		Parts = parts,
		Wobble = building,
		Fade = function(self: Wave)
			for _, part in self.Model:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					TweenService:Create(part, TweenInfo.new(Config.Waves.FadeTime), { Transparency = 1 }):Play()
				elseif part:IsA("ParticleEmitter") then
					part.Enabled = false
				end
			end
		end,
		Update = function(self: Wave, frontX: number)
			-- Mueve la ola entera y hace ondular las piezas (cada una con su ritmo)
			local t = os.clock()
			local place = CFrame.new(frontX, Config.Map.FloorY, 0)
			for _, w in self.Wobble do
				local offset = math.sin(t * 3 + w.Phase) * w.Amount
				w.Part.CFrame = if w.Amount > 0 then place * CFrame.new(offset * 0.6, offset * 0.4, 0) * w.Base else place * w.Base
			end
		end,
	}
	return wave
end

return WaveVisual

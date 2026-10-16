--!strict
-- IslandBuilder: arma la isla grande con Terrain (colinas, playas, arrecifes, caleta, península y el volcán).
--
-- Todo sale de UNA función: IslandBuilder.Sample(x, z) dice qué alto tiene el piso en ese punto y de qué tipo es.
-- Con eso:
--   * BuildTerrain escribe el terreno de a pedazos (empezando cerca del lobby, sin congelar el servidor).
--   * MapBuilder pone las palmeras, el faro, el muelle, etc. justo arriba del piso, sin tener que leer el terreno.
--
-- Reglas que nunca se rompen:
--   * Adentro del lobby y del cañón el terreno queda abajo de las Parts (no tapa nada).
--   * Alrededor del lobby el piso queda plano y después sube de a poco.
--   * Al lado de las paredes del cañón hay acantilados de roca.
--
-- Los números están en Config.Island.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local IslandBuilder = {}

local I = Config.Island
local V = I.Volcano
local SEA = I.SeaLevel
local RES = 4 -- tamaño de cada voxel de Terrain
local HIDDEN_Y = -3 -- alto del terreno debajo del lobby y del cañón

local HALF_LOBBY_X = Config.Map.LobbySize.X / 2
local HALF_LOBBY_Z = Config.Map.LobbySize.Y / 2
local CANYON_START = Config.Map.CanyonStartX
local CANYON_END = Config.Map.CanyonStartX + Config.Map.CanyonLength
local CANYON_OUTER_Z = Config.Map.CanyonWidth / 2 + Config.Map.CanyonWallThickness

-- Radio donde la curva del volcán llega al borde del cráter
local RIM_RADIUS = V.Radius * (1 - (V.RimHeight / V.Peak) ^ (1 / V.Power))

-- Tipos de piso que devuelve Sample
-- "Hidden" (abajo del lobby o del cañón), "Sea", "Reef", "Lagoon", "Beach", "Grass", "Jungle", "Cliff", "Volcano", "Crater", "River"
export type Kind = string

local function clamp01(t: number): number
	return math.clamp(t, 0, 1)
end

local function smoothstep(a: number, b: number, x: number): number
	local t = clamp01((x - a) / (b - a))
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Ruido suave entre -1 y 1 (varias capas)
local function fbm(x: number, z: number, seed: number): number
	return math.noise(x, z, seed) * 1.2 + math.noise(x * 2.7, z * 2.7, seed + 11) * 0.5 + math.noise(x * 6.1, z * 6.1, seed + 23) * 0.2
end

local function wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- Distancia a la costa: positiva en tierra (cuántos studs hacia adentro), negativa en el mar
function IslandBuilder.CoastDistance(x: number, z: number): number
	local best = -math.huge
	for _, lobe in I.Lobes do
		local s
		if lobe.Kind == "Capsule" then
			local px = math.clamp(x, lobe.X1 :: number, lobe.X2 :: number)
			local dx, dz = x - px, z - lobe.Z
			s = (lobe.R :: number) - math.sqrt(dx * dx + dz * dz)
		else
			local rx, rz = lobe.RX :: number, lobe.RZ :: number
			local qx, qz = (x - (lobe.X :: number)) / rx, (z - lobe.Z) / rz
			s = (1 - math.sqrt(qx * qx + qz * qz)) * math.min(rx, rz)
		end
		if s > best then
			best = s
		end
	end
	local scale = I.CoastNoiseScale
	local noise = math.noise(x / scale, z / scale, 0.37) * 1.4 + math.noise(x * 3 / scale, z * 3 / scale, 3.1) * 0.5
	return best + I.CoastNoise * noise
end

-- Distancia al rectángulo del lobby (0 adentro)
local function lobbyDistance(x: number, z: number): number
	local dx = math.max(0, math.abs(x) - HALF_LOBBY_X)
	local dz = math.max(0, math.abs(z) - HALF_LOBBY_Z)
	return math.sqrt(dx * dx + dz * dz)
end

local function inCanyon(x: number, z: number): boolean
	return x >= CANYON_START - 4 and x <= CANYON_END + 2 and math.abs(z) < CANYON_OUTER_Z
end

-- Ángulo del río de lava número i a esta distancia del centro (serpentea un poco)
function IslandBuilder.RiverAngle(index: number, r: number): number
	return math.rad(I.LavaRivers[index]) + 0.2 * math.sin(r / 50 + index * 1.7)
end

local function riverWidth(r: number): number
	return 4 + r * 0.018
end

-- Alto del volcán en este punto (0 lejos) y si es cráter o río
local function volcanoHeight(x: number, z: number): (number, Kind?)
	local dx, dz = x - V.X, z - V.Z
	local r = math.sqrt(dx * dx + dz * dz)
	if r >= V.Radius then
		return 0, nil
	end
	if r < RIM_RADIUS then
		-- Cráter hundido: un tazón desde el borde hasta CraterDepth más abajo
		return V.RimHeight - V.CraterDepth * (1 - (r / RIM_RADIUS) ^ 2), "Crater"
	end
	local h = V.Peak * (1 - r / V.Radius) ^ V.Power
	local angle = math.atan2(dz, dx)
	-- Barrancos: surcos que bajan desde la cumbre
	local wave = math.sin(angle * V.Ravines + math.noise(r / 90, angle, 5.5) * 2.5)
	local ravine = math.max(0, wave) ^ 4 * smoothstep(60, 140, r) * (1 - smoothstep(300, 370, r))
	h *= 1 - V.RavineDepth * ravine
	-- Ríos de lava tallados en la ladera
	if r > RIM_RADIUS + 2 and r < V.Radius - 30 then
		for index in I.LavaRivers do
			local d = math.abs(wrapAngle(angle - IslandBuilder.RiverAngle(index, r))) * r
			local w = riverWidth(r)
			if d < w then
				return h - 3 * (1 - (d / w) ^ 2), "River"
			end
		end
	end
	return h, "Volcano"
end

-- Alto del piso en (x, z) y de qué tipo es. El terreno llega hasta esa altura.
-- (El tercer valor es la distancia a la costa, por si sirve.)
function IslandBuilder.Sample(x: number, z: number): (number, Kind, number)
	if lobbyDistance(x, z) <= 0 or inCanyon(x, z) then
		return HIDDEN_Y, "Hidden", 999
	end
	local c = IslandBuilder.CoastDistance(x, z)
	local h: number
	local kind: Kind
	if c < 0 then
		-- Mar: se va haciendo hondo; con manchas de arrecife cerca de la costa
		h = math.max(I.SeaFloor, SEA - 1 + c * I.SeaSlope)
		kind = "Sea"
		if c > -70 and c < -8 then
			local reef = math.noise(x / 80, z / 80, 7.7) * 2
			if reef > I.ReefChance then
				local reefTop = SEA - 3.5 - (1 - clamp01((reef - I.ReefChance) / 0.6)) * 4
				if reefTop > h then
					h, kind = reefTop, "Reef"
				end
			end
		end
	else
		-- Tierra: playa y después colinas
		local amp = lerp(I.WestHills, I.Hills, smoothstep(160, 420, x))
		amp *= lerp(1, 0.55, smoothstep(190, 300, math.abs(z)))
		local inland = smoothstep(I.BeachWidth, I.BeachWidth + 80, c)
		local n = fbm(x / I.HillScale, z / I.HillScale, 1.3)
		local hills = amp * inland * math.clamp(0.55 + 0.6 * n, 0.05, 1.4)
		h = SEA + 3 * clamp01(c / I.BeachWidth) + hills
		kind = if c < I.BeachWidth + 3 and h < 3.5 then "Beach" elseif amp * inland > 18 and h > 6 then "Jungle" else "Grass"

		-- Loma de la caleta (de donde cae la cascada)
		local ridge = I.Ridge
		local rdx, rdz = x - ridge.X, z - ridge.Z
		local bump = ridge.Height * math.exp(-(rdx * rdx + rdz * rdz) / (ridge.Radius * ridge.Radius)) * smoothstep(0, 30, c)
		if bump > 0.5 then
			h += bump
			if h > 6 then
				kind = "Jungle"
			end
		end

		-- Acantilados al lado de las paredes del cañón
		if x > CANYON_START and x < CANYON_END + 40 then
			local d = math.abs(z) - CANYON_OUTER_Z
			local cliff = I.CliffHeight * (1 - smoothstep(0, I.CliffWidth, d)) * smoothstep(CANYON_START, CANYON_START + 80, x)
			cliff += math.noise(x / 30, z / 30, 9.1) * 4
			if cliff > h then
				h, kind = cliff, "Cliff"
			end
		end
	end

	-- Laguna de la caleta norte (queda abajo del nivel del mar: se llena de agua)
	local lagoon = I.Lagoon
	local ldx, ldz = x - lagoon.X, z - lagoon.Z
	local ld = math.sqrt(ldx * ldx + ldz * ldz)
	if ld < lagoon.Radius + 6 then
		local t = smoothstep(lagoon.Radius - 4, lagoon.Radius + 6, ld)
		h = lerp(SEA - 7, h, t)
		if t < 0.5 then
			kind = "Lagoon"
		end
	end

	-- Volcán
	local vh, vkind = volcanoHeight(x, z)
	if vkind and vh > h then
		h, kind = vh, vkind
	end

	-- Alrededor del lobby: plano y después sube de a poco
	local flat = smoothstep(I.LobbyFlatMargin, I.LobbyFlatMargin + I.LobbyBlend, lobbyDistance(x, z))
	if flat < 1 then
		h = lerp(0, h, flat)
		if kind == "Jungle" or kind == "Cliff" then
			kind = if flat < 0.5 then "Grass" else kind
		end
	end
	return h, kind, c
end

-- Material de la superficie según el tipo, la altura y qué tan empinado es
function IslandBuilder.MaterialFor(kind: Kind, h: number, slope: number, x: number, z: number): Enum.Material
	if kind == "Hidden" or kind == "Sea" or kind == "Lagoon" or kind == "Beach" then
		return Enum.Material.Sand
	elseif kind == "Reef" then
		return Enum.Material.Limestone
	elseif kind == "River" then
		return Enum.Material.CrackedLava
	elseif kind == "Crater" then
		return Enum.Material.Basalt
	elseif kind == "Volcano" then
		if h > 170 then
			return Enum.Material.Slate
		elseif h > 70 then
			return Enum.Material.Basalt
		elseif h > 24 then
			return if math.noise(x / 40, z / 40, 4.4) > 0.15 then Enum.Material.Grass else Enum.Material.Rock
		end
		return Enum.Material.LeafyGrass
	elseif kind == "Cliff" then
		return if slope > 0.45 then Enum.Material.Rock else Enum.Material.LeafyGrass
	end
	if slope > 1 then
		return Enum.Material.Rock
	end
	return if kind == "Jungle" then Enum.Material.LeafyGrass else Enum.Material.Grass
end

-- Lo que va debajo de la superficie
local function subsurface(surface: Enum.Material): Enum.Material
	if surface == Enum.Material.Sand or surface == Enum.Material.Limestone then
		return Enum.Material.Sand
	elseif surface == Enum.Material.Grass or surface == Enum.Material.LeafyGrass then
		return Enum.Material.Ground
	elseif surface == Enum.Material.Rock then
		return Enum.Material.Rock
	end
	return Enum.Material.Basalt
end

-- Altura del volcán sin barrancos (para poner cosas arriba: lago de lava, ríos)
function IslandBuilder.VolcanoSurface(x: number, z: number): number
	local h = volcanoHeight(x, z)
	return h
end

IslandBuilder.RimRadius = RIM_RADIUS

-- Camina desde "from" en la dirección "direction" hasta que la distancia a la costa sea "coast" (para ubicar el faro, el muelle...)
function IslandBuilder.FindCoastPoint(from: Vector2, direction: Vector2, coast: number): Vector2
	local dir = direction.Unit
	local point = from
	for _ = 1, 400 do
		if IslandBuilder.CoastDistance(point.X, point.Y) <= coast then
			return point
		end
		point += dir * 4
	end
	return point
end

-- Rocas que asoman del agua (posición y radio), siempre las mismas
function IslandBuilder.ReefRocks(): { { Position: Vector3, Radius: number } }
	local rng = Random.new(I.Seed + 7)
	local rocks = {}
	local tries = 0
	while #rocks < I.ReefRocks and tries < 5000 do
		tries += 1
		local x = rng:NextNumber(I.MinX + 40, I.MaxX - 40)
		local z = rng:NextNumber(I.MinZ + 40, I.MaxZ - 40)
		local c = IslandBuilder.CoastDistance(x, z)
		if c < -14 and c > -90 then
			local radius = rng:NextNumber(4, 9)
			local h = IslandBuilder.Sample(x, z)
			table.insert(rocks, { Position = Vector3.new(x, h + radius * 0.6, z), Radius = radius })
		end
	end
	return rocks
end

-- ===== Escribir el terreno =====

local CHUNK = 32 -- voxels por lado de cada pedazo (128 studs)

local function buildChunk(terrain: Terrain, x0: number, z0: number)
	local n = CHUNK
	-- Alturas de cada columna (con un borde de 1 para calcular la pendiente)
	local heights: { { number } } = {}
	local kinds: { { Kind } } = {}
	local maxH = -math.huge
	for i = 0, n + 1 do
		local hRow: { number } = {}
		local kRow: { Kind } = {}
		for k = 0, n + 1 do
			local h, kind = IslandBuilder.Sample(x0 + (i - 0.5) * RES, z0 + (k - 0.5) * RES)
			hRow[k] = h
			kRow[k] = kind
			if i >= 1 and i <= n and k >= 1 and k <= n and h > maxH then
				maxH = h
			end
		end
		heights[i] = hRow
		kinds[i] = kRow
	end
	if maxH < I.SeaFloor + 2 then
		return -- mar profundo: ya está lleno de agua
	end
	local y0 = I.SeaFloor - RES
	local y1 = math.max(math.ceil((maxH + RES) / RES) * RES, 4)
	local ny = (y1 - y0) // RES

	local materials = table.create(n)
	local occupancy = table.create(n)
	for i = 1, n do
		local mx = table.create(ny)
		local ox = table.create(ny)
		for j = 1, ny do
			mx[j] = table.create(n)
			ox[j] = table.create(n)
		end
		for k = 1, n do
			local h = heights[i][k]
			local slope = math.max(math.abs(heights[i + 1][k] - heights[i - 1][k]), math.abs(heights[i][k + 1] - heights[i][k - 1])) / (2 * RES)
			local x, z = x0 + (i - 0.5) * RES, z0 + (k - 0.5) * RES
			local top = IslandBuilder.MaterialFor(kinds[i][k], h, slope, x, z)
			local below = subsurface(top)
			for j = 1, ny do
				local cellY = y0 + (j - 1) * RES
				local fill = math.clamp((h - cellY) / RES, 0, 1)
				if fill > 0.02 then
					mx[j][k] = if h - cellY > RES * 2 then below else top
					ox[j][k] = fill
				elseif cellY < SEA then
					mx[j][k] = Enum.Material.Water
					ox[j][k] = math.clamp((SEA - cellY) / RES, 0, 1)
				else
					mx[j][k] = Enum.Material.Air
					ox[j][k] = 0
				end
			end
		end
		materials[i] = mx
		occupancy[i] = ox
	end
	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + n * RES, y1, z0 + n * RES))
	terrain:WriteVoxels(region, RES, materials, occupancy)
end

-- Escribe toda la isla. Va de a pedazos (los más cercanos al lobby primero) y hace pausas para no congelar el juego.
-- Al terminar pone Workspace.IslandReady = true.
function IslandBuilder.BuildTerrain(terrain: Terrain)
	for name, color in I.Colors do
		terrain:SetMaterialColor((Enum.Material :: any)[name], color :: Color3)
	end
	type Chunk = { X: number, Z: number, Distance: number }
	local chunks: { Chunk } = {}
	local size = CHUNK * RES
	local startX = math.floor(I.MinX / size) * size
	local startZ = math.floor(I.MinZ / size) * size
	for x = startX, I.MaxX - 1, size do
		for z = startZ, I.MaxZ - 1, size do
			local cx, cz = x + size / 2, z + size / 2
			table.insert(chunks, { X = x, Z = z, Distance = math.sqrt(cx * cx + cz * cz) })
		end
	end
	table.sort(chunks, function(a, b)
		return a.Distance < b.Distance
	end)
	for _, chunk in chunks do
		buildChunk(terrain, chunk.X, chunk.Z)
		task.wait()
	end
	-- Rocas en el mar
	for _, rock in IslandBuilder.ReefRocks() do
		terrain:FillBall(rock.Position, rock.Radius, Enum.Material.Rock)
	end
	Workspace:SetAttribute("IslandReady", true)
end

return IslandBuilder

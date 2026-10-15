--!strict
-- CreatureModels: arma el modelo placeholder de cada mascota con Parts simples.
-- Cuerpo redondo + ojos, y según el estilo: orejas, alas, pico, cuernos o cola.
-- Las variantes (Silver, Golden, Emerald...) pintan la mascota de ese color y material y la hacen brillar.
-- Cuando tengas modelos de verdad, se reemplaza este archivo y el resto del juego sigue igual.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Format = require(ReplicatedStorage.Shared.Format)

type Creature = Creatures.Creature
type Variant = Config.Variant

-- Partes que toman el color de la variante (los ojos, el pico y los cuernos quedan como están)
local TINTED_PARTS: { [string]: boolean } = { Body = true, Ear = true, Wing = true, Tail = true }

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
-- variant: Silver, Golden... (nil o "Normal" = colores de siempre).
function CreatureModels.Build(creature: Creature, cframe: CFrame, variant: Variant?): Model
	local rarity = Config.GetRarity(creature.RarityId)
	local special = variant ~= nil and variant.Id ~= "Normal"
	local rainbow = creature.RarityId == "Secret" or (variant ~= nil and variant.Id == "Rainbow")
	local s = SCALE_BY_RARITY[creature.RarityId] or 1
	local color = creature.Color

	local model = Instance.new("Model")
	model.Name = creature.DisplayName
	model:SetAttribute("CreatureId", creature.Id)
	model:SetAttribute("Variant", if variant then variant.Id else "Normal")

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

	-- Variante: se pinta del color y material de la variante
	if variant and special then
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and TINTED_PARTS[child.Name] then
				child.Color = if child.Name == "Body" then variant.Color else darker(variant.Color, 0.15)
				child.Material = variant.Material
			end
		end
	end

	-- Brillo para las raras y las variantes
	local glowColor = if variant and special then variant.Color elseif rarity then rarity.Color else color
	if special or creature.RarityId == "Legendary" or creature.RarityId == "Secret" then
		local light = Instance.new("PointLight")
		light.Color = if rainbow then Color3.new(1, 1, 1) else glowColor
		light.Brightness = 2
		light.Range = 12
		light.Parent = body

		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = if rainbow then RAINBOW else ColorSequence.new(glowColor)
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
	nameLabel.Text = if variant then Config.WithVariant(variant, creature.DisplayName) else creature.DisplayName
	nameLabel.TextColor3 = if rainbow then Color3.new(1, 1, 1) else glowColor
	nameLabel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = nameLabel
	if rainbow then
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
	incomeLabel.Text = `+{Format.Compact(if rarity then Config.GetIncome(rarity, variant) else 0)} coins/s`
	incomeLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	incomeLabel.Parent = gui
	local stroke2 = Instance.new("UIStroke")
	stroke2.Thickness = 2
	stroke2.Parent = incomeLabel

	return model
end

return CreatureModels

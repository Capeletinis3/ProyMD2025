--!strict
-- Hud: lo que siempre está en pantalla (diseño "HUD del jugador"; los botones están en SideMenu).
--   * Abajo a la izquierda: tu velocidad (con un "+" que abre las mejoras), tu plata y cuánto ganás por segundo.
--   * Arriba a la derecha: cuánto falta para el Súper tsunami, la Lluvia de huevos y las ofertas nuevas del Comerciante.
--   * Abajo al medio: cómo están tus nidos ("Nest 1 00:45", "READY!", "Empty") y los casilleros de los huevos que llevás.
--   * Abajo a la derecha: los mismos relojes con íconos (ola, lluvia de huevos, súper tsunami).
--   * Arriba de la plata: las pociones que tenés activas y cuánto les queda.
--   * Caminar lento: tecla T o la barra del menú (para cruzar con cuidado).
--   * Invitar: abre la ventana de invitar amigos de Roblox; el botón muestra tu bonus por amigos.
-- Lee los atributos que publica el servidor (Coins, Income, WalkSpeed, CarriedEggs, Nest1-3, FriendBonus...)
-- y los relojes de Workspace (PhaseEndsAt, NextSuperAt, NextEggRainAt, MerchantRestockAt).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)

local player = Players.LocalPlayer

local Hud = {}

local YELLOW = Color3.fromRGB(255, 225, 77)
local GREEN = Color3.fromRGB(108, 255, 77)
local PINK = Color3.fromRGB(255, 179, 179)
local DARK = Color3.fromRGB(52, 48, 58)
local EDGE = Color3.fromRGB(17, 17, 17)
local MAX_CARRY = 1 + Config.Upgrades.Carry[#Config.Upgrades.Carry].Extra + Config.Vip.ExtraCarry

local coinsLabel: TextLabel
local incomeLabel: TextLabel
local speedLabel: TextLabel
local coinsScale: UIScale
local timerLines: { TextLabel } = {}
local iconTimes: { TextLabel } = {}
local buffChips: { [string]: TextLabel } = {}
local nestChips: { Frame } = {}
local nestTexts: { TextLabel } = {}
type Slot = { Frame: Frame, Egg: Frame, Name: TextLabel, Lock: TextLabel }
local slots: { Slot } = {}
local lastCoins = 0
local slowWalk = false

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function worldTime(name: string): number?
	local value = Workspace:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
	end
	return string.format("%02d:%02d", s // 60, s % 60)
end

-- ===== Plata y velocidad =====

local function onCoinsChanged()
	local coins = number("Coins")
	coinsLabel.Text = Format.Compact(coins)
	if coins > lastCoins then
		coinsScale.Scale = 1.12
		TweenService:Create(coinsScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	lastCoins = coins
end

local function onIncomeChanged()
	local doubled = Workspace:GetAttribute("Event") == "DoubleCoins"
	local income = number("Income") * (if doubled then Config.Events.DoubleCoinsMultiplier else 1)
	incomeLabel.Text = `+${Format.Compact(income)}/s` .. (if doubled then ` x{Config.Events.DoubleCoinsMultiplier}!` else "")
	incomeLabel.TextColor3 = if doubled then Color3.fromRGB(255, 200, 60) else GREEN
end

local function onSpeedChanged()
	local speed = number("WalkSpeed")
	speedLabel.Text = tostring(if speed > 0 then speed else Config.Upgrades.WalkSpeed[1].Speed)
end

-- ===== Caminar lento =====

local function applySlowWalk()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local normal = number("WalkSpeed")
		humanoid.WalkSpeed = if slowWalk then Config.Controls.SlowWalkSpeed elseif normal > 0 then normal else humanoid.WalkSpeed
	end
	SideMenu.SetText("SlowWalk", `[{Config.Controls.SlowWalkKey.Name}] Slow walk: {if slowWalk then "ON" else "OFF"}`)
end

local function toggleSlowWalk()
	slowWalk = not slowWalk
	applySlowWalk()
end

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		-- Si el servidor le vuelve a poner la velocidad (por ejemplo al mejorarla), seguimos lentos
		humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if slowWalk and humanoid.WalkSpeed ~= Config.Controls.SlowWalkSpeed then
				humanoid.WalkSpeed = Config.Controls.SlowWalkSpeed
			end
		end)
		applySlowWalk()
	end
end

-- ===== Nidos y huevos que llevás =====

local function hex(color: Color3): string
	return string.format("%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local NEST_STYLE: { [string]: { Back: Color3, Border: Color3, Text: Color3 } } = {
	Ready = { Back = Color3.fromRGB(201, 138, 0), Border = YELLOW, Text = Color3.new(1, 1, 1) },
	Hatching = { Back = Color3.fromRGB(201, 138, 0), Border = YELLOW, Text = Color3.new(1, 1, 1) },
	Incubating = { Back = DARK, Border = EDGE, Text = Color3.fromRGB(108, 184, 255) },
	Empty = { Back = DARK, Border = EDGE, Text = Color3.fromRGB(184, 184, 192) },
	Locked = { Back = Color3.fromRGB(40, 38, 44), Border = EDGE, Text = Color3.fromRGB(130, 130, 138) },
}

local function updateNests()
	for i, chip in nestChips do
		local value = player:GetAttribute(`Nest{i}`)
		chip.Visible = typeof(value) == "string"
		if typeof(value) == "string" then
			local state, text = string.match(value, "^(%a+)|(.*)$")
			local style = NEST_STYLE[state or "Empty"] or NEST_STYLE.Empty
			local shown = if state == "Ready" then "READY!"
				elseif state == "Empty" then "Empty"
				elseif state == "Locked" then "🔒"
				else text or ""
			nestTexts[i].Text = `Nest {i} <font color="#{hex(style.Text)}">{shown}</font>`
			chip.BackgroundColor3 = style.Back
			local stroke = chip:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = style.Border
			end
		end
	end
end

local function eggColor(rarity: Config.Rarity, variant: Config.Variant): Color3
	if variant.Id ~= "Normal" then
		return variant.Color
	end
	return if rarity.Id == "Secret" then Color3.fromRGB(196, 160, 255) else rarity.Color
end

local function updateCarry()
	local carried = player:GetAttribute("CarriedEggs")
	local list = if typeof(carried) == "string" then string.split(carried, ",") else {}
	local capacity = Config.CarryCapacity(player)
	for i, slot in slots do
		local entry = list[i]
		local rarityId, variantId = if entry then string.match(entry, "^(%w+)/(%w+)$") else nil, nil
		local rarity = if rarityId then Config.GetRarity(rarityId) else nil
		local locked = i > capacity
		slot.Lock.Visible = locked
		slot.Egg.Visible = rarity ~= nil
		slot.Name.Visible = rarity ~= nil
		slot.Frame.BackgroundTransparency = if locked then 0.4 else 0
		local stroke = slot.Frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if rarity then Color3.new(1, 1, 1) else EDGE
		end
		if rarity then
			local variant = Config.GetVariant(variantId)
			local color = eggColor(rarity, variant)
			slot.Egg.BackgroundColor3 = color
			slot.Name.Text = Config.WithVariant(variant, rarity.DisplayName) .. " Egg"
			slot.Name.TextColor3 = color
		end
	end
end

-- ===== Relojes =====

local function updateTimers()
	local now = Workspace:GetServerTimeNow()
	local function left(name: string): number?
		local at = worldTime(name)
		return if at then math.max(0, at - now) else nil
	end
	local super = left("NextSuperAt")
	local rainEnds = left("EggRainEndsAt")
	local rain = left("NextEggRainAt")
	local merchant = left("MerchantRestockAt")
	timerLines[1].Text = if super then `Super tsunami in {clock(super)}` else ""
	if rainEnds and rainEnds > 0 then
		timerLines[2].Text = `EGG RAIN! {clock(rainEnds)}`
		timerLines[2].TextColor3 = YELLOW
	else
		timerLines[2].Text = if rain then `Egg rain in {clock(rain)}` else ""
		timerLines[2].TextColor3 = Color3.new(1, 1, 1)
	end
	timerLines[3].Text = if merchant then `Merchant in {clock(merchant)}` else ""
	-- Pociones activas
	local row = 0
	for _, id in { "Luck", "FastNest" } do
		local chip = buffChips[id]
		local seconds = number(id .. "Potion")
		chip.Visible = seconds > 0
		if seconds > 0 then
			local info = (Config.Potions :: any)[id]
			chip.Text = `{info.Icon} {info.DisplayName} {clock(seconds)}`
			chip.Position = UDim2.fromOffset(row * 170, 0)
			row += 1
		end
	end

	local wave = left("PhaseEndsAt")
	iconTimes[1].Text = if wave then clock(wave) else "--:--"
	iconTimes[2].Text = if rainEnds and rainEnds > 0 then "NOW!" elseif rain then clock(rain) else "--:--"
	iconTimes[3].Text = if super then clock(super) else "--:--"
end

-- ===== Armado =====

local function build(gui: ScreenGui)
	-- Abajo a la izquierda: velocidad y plata
	local money = Instance.new("Frame")
	money.Name = "Money"
	money.AnchorPoint = Vector2.new(0, 1)
	money.Position = UDim2.new(0, 10, 1, -10)
	money.Size = UDim2.fromOffset(330, 92)
	money.BackgroundTransparency = 1
	money.Parent = gui
	UIKit.HudScale(money)
	UIKit.Icon(money, "Speed", "👟", UDim2.fromOffset(34, 34), UDim2.fromOffset(0, 0), 26)
	speedLabel = UIKit.Label(money, "16", UDim2.fromOffset(52, 34), UDim2.fromOffset(40, 0), 30)
	UIKit.Stroke(speedLabel, 3, EDGE)
	local speedWord = UIKit.Label(money, "speed", UDim2.fromOffset(70, 34), UDim2.fromOffset(94, 1), 17, PINK)
	UIKit.Stroke(speedWord, 2.5, EDGE)
	local plus = UIKit.Button(money, "+", UDim2.fromOffset(28, 28), UDim2.fromOffset(160, 3), 22, DARK)
	plus.Name = "UpgradeSpeed"
	plus.Activated:Connect(function()
		SideMenu.Press("Upgrades")
	end)
	UIKit.Icon(money, "Coin", "💰", UDim2.fromOffset(38, 44), UDim2.fromOffset(0, 44), 30)
	coinsLabel = UIKit.Label(money, "0", UDim2.fromOffset(150, 44), UDim2.fromOffset(42, 44), 34, YELLOW)
	coinsLabel.AutomaticSize = Enum.AutomaticSize.X
	UIKit.Stroke(coinsLabel, 3.5, EDGE)
	coinsScale = Instance.new("UIScale")
	coinsScale.Parent = coinsLabel
	incomeLabel = UIKit.Label(money, "+$0/s", UDim2.fromOffset(200, 44), UDim2.fromOffset(186, 46), 26, GREEN)
	UIKit.Stroke(incomeLabel, 3, EDGE)
	coinsLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
		incomeLabel.Position = UDim2.fromOffset(42 + math.max(80, coinsLabel.TextBounds.X) + 12, 46)
	end)

	-- Arriba de la plata: pociones activas
	local buffs = Instance.new("Frame")
	buffs.Name = "Potions"
	buffs.AnchorPoint = Vector2.new(0, 1)
	buffs.Position = UDim2.new(0, 10, 1, -108)
	buffs.Size = UDim2.fromOffset(340, 28)
	buffs.BackgroundTransparency = 1
	buffs.Parent = gui
	UIKit.HudScale(buffs)
	for _, id in { "Luck", "FastNest" } do
		local info = (Config.Potions :: any)[id]
		local chip = UIKit.Outlined(buffs, "", UDim2.fromOffset(162, 28), UDim2.fromOffset(0, 0), 15, info.Color, 2)
		chip.BackgroundTransparency = 0.15
		chip.BackgroundColor3 = DARK
		chip.Visible = false
		UIKit.Corner(chip, 8)
		buffChips[id] = chip
	end

	-- Arriba a la derecha: relojes en texto
	local timers = Instance.new("Frame")
	timers.Name = "Timers"
	timers.AnchorPoint = Vector2.new(1, 0)
	timers.Position = UDim2.new(1, -14, 0, 6)
	timers.Size = UDim2.fromOffset(320, 84)
	timers.BackgroundTransparency = 1
	timers.Parent = gui
	UIKit.HudScale(timers)
	for i = 1, 3 do
		local line = UIKit.Label(timers, "", UDim2.fromOffset(320, 27), UDim2.fromOffset(0, (i - 1) * 27), 22)
		line.TextXAlignment = Enum.TextXAlignment.Right
		UIKit.Stroke(line, 3, EDGE)
		timerLines[i] = line
	end

	-- Abajo al medio: nidos y casilleros
	local bottom = Instance.new("Frame")
	bottom.Name = "Nests"
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -8)
	bottom.Size = UDim2.fromOffset(380, 104)
	bottom.BackgroundTransparency = 1
	bottom.Parent = gui
	UIKit.HudScale(bottom)
	local chipRow = Instance.new("Frame")
	chipRow.BackgroundTransparency = 1
	chipRow.Size = UDim2.fromOffset(380, 26)
	chipRow.Parent = bottom
	local nestCount = Config.Upgrades.MaxIncubators
	local chipWidth, chipGap = 120, 6
	local chipStart = (380 - (nestCount * chipWidth + (nestCount - 1) * chipGap)) / 2
	for i = 1, nestCount do
		local chip = Instance.new("Frame")
		chip.Name = `Nest{i}`
		chip.Size = UDim2.fromOffset(chipWidth, 24)
		chip.Position = UDim2.fromOffset(chipStart + (i - 1) * (chipWidth + chipGap), 0)
		chip.BackgroundColor3 = DARK
		chip.Visible = false
		chip.Parent = chipRow
		UIKit.Corner(chip, 4)
		UIKit.Stroke(chip, 2, EDGE).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local text = UIKit.Label(chip, `Nest {i}`, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 15)
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.RichText = true
		text.TextTruncate = Enum.TextTruncate.None
		UIKit.Stroke(text, 2, EDGE)
		nestChips[i] = chip
		nestTexts[i] = text
	end
	local slotRow = Instance.new("Frame")
	slotRow.BackgroundTransparency = 1
	slotRow.Position = UDim2.fromOffset(0, 36)
	slotRow.Size = UDim2.fromOffset(380, 64)
	slotRow.Parent = bottom
	local slotStart = (380 - (MAX_CARRY * 62 + (MAX_CARRY - 1) * 4)) / 2
	for i = 1, MAX_CARRY do
		local frame = Instance.new("Frame")
		frame.Name = `Carry{i}`
		frame.Size = UDim2.fromOffset(62, 62)
		frame.Position = UDim2.fromOffset(slotStart + (i - 1) * 66, 0)
		frame.BackgroundColor3 = DARK
		frame.Parent = slotRow
		UIKit.Corner(frame, 3)
		UIKit.Stroke(frame, 2, EDGE).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local n = UIKit.Label(frame, tostring(i), UDim2.fromOffset(14, 14), UDim2.fromOffset(4, 2), 11)
		UIKit.Stroke(n, 1.5, EDGE)
		local egg = Instance.new("Frame")
		egg.AnchorPoint = Vector2.new(0.5, 0)
		egg.Position = UDim2.new(0.5, 0, 0, 10)
		egg.Size = UDim2.fromOffset(20, 26)
		egg.Visible = false
		egg.Parent = frame
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = egg
		UIKit.Stroke(egg, 2, Color3.new(1, 1, 1))
		local name = UIKit.Label(frame, "", UDim2.fromOffset(60, 22), UDim2.fromOffset(1, 38), 10)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextWrapped = true
		name.TextTruncate = Enum.TextTruncate.None
		name.Visible = false
		UIKit.Stroke(name, 1.5, EDGE)
		local lock = UIKit.Label(frame, "🔒", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 22)
		lock.TextXAlignment = Enum.TextXAlignment.Center
		lock.Visible = false
		slots[i] = { Frame = frame, Egg = egg, Name = name, Lock = lock }
	end

	-- Abajo a la derecha: relojes con íconos
	local icons = Instance.new("Frame")
	icons.Name = "TimerIcons"
	icons.AnchorPoint = Vector2.new(1, 1)
	icons.Position = UDim2.new(1, -14, 1, -12)
	icons.Size = UDim2.fromOffset(210, 70)
	icons.BackgroundTransparency = 1
	-- En celulares ahí va el botón de saltar (y los mismos relojes ya están arriba a la derecha)
	icons.Visible = not (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	icons.Parent = gui
	UIKit.HudScale(icons)
	for i, icon in { { "Wave", "🌊" }, { "EggRain", "🥚" }, { "SuperTsunami", "⏰" } } do
		local x = (i - 1) * 70
		UIKit.Icon(icons, icon[1], icon[2], UDim2.fromOffset(70, 44), UDim2.fromOffset(x, 0), 34)
		local time = UIKit.Label(icons, "--:--", UDim2.fromOffset(70, 24), UDim2.fromOffset(x, 44), 18)
		time.TextXAlignment = Enum.TextXAlignment.Center
		UIKit.Stroke(time, 2.5, EDGE)
		iconTimes[i] = time
	end
end

-- Botón Invitar: ventana de Roblox para invitar amigos, y el bonus que te dan los que ya están
local function setupInvite()
	SideMenu.Bind("Invite", function()
		local ok, canInvite = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and canInvite then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		end
	end)
	local function refresh()
		local bonus = number("FriendBonus")
		SideMenu.SetBadge("Invite", `+{math.floor(bonus * 100 + 0.5)}%`, YELLOW)
	end
	player:GetAttributeChangedSignal("FriendBonus"):Connect(refresh)
	refresh()
end

function Hud.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	build(gui)

	player:GetAttributeChangedSignal("Coins"):Connect(onCoinsChanged)
	player:GetAttributeChangedSignal("Income"):Connect(onIncomeChanged)
	player:GetAttributeChangedSignal("WalkSpeed"):Connect(function()
		onSpeedChanged()
		if not slowWalk then
			applySlowWalk()
		end
	end)
	Workspace:GetAttributeChangedSignal("Event"):Connect(onIncomeChanged)
	for i = 1, Config.Upgrades.MaxIncubators do
		player:GetAttributeChangedSignal(`Nest{i}`):Connect(updateNests)
	end
	for _, name in { "CarriedEggs", "CarryLevel", "VIP" } do
		player:GetAttributeChangedSignal(name):Connect(updateCarry)
	end

	-- Caminar lento: tecla T o la barra del menú
	SideMenu.Bind("SlowWalk", toggleSlowWalk)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Config.Controls.SlowWalkKey then
			toggleSlowWalk()
		end
	end)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	setupInvite()

	lastCoins = number("Coins")
	onCoinsChanged()
	onIncomeChanged()
	onSpeedChanged()
	updateNests()
	updateCarry()
	applySlowWalk()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.25 then
			elapsed = 0
			updateTimers()
		end
	end)
	updateTimers()
end

return Hud

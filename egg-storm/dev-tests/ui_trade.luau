local rf = Instance.new("Folder"); rf.Name = "Remotes"; rf.Parent = game:GetService("ReplicatedStorage")
for _, n in { "BuyUpgrade", "Notify", "Hatched", "TutorialAction", "Trade" } do local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = rf end
local ws = game:GetService("Workspace")
rawget(ws, "_props").GetServerTimeNow = function() return NOW end
LOCAL:SetAttribute("Coins", 250000); LOCAL:SetAttribute("Income", 245)
__mod("Hud").Start()
local panel = __mod("TradePanel")
panel.Start()
panel.ShowState({
	Partner = "Bob",
	MyCreatures = {
		{ Slot = 1, CreatureId = "GoldenDragon", Variant = "Golden" },
		{ Slot = 2, CreatureId = "SandBunny", Variant = "Normal" },
		{ Slot = 3, CreatureId = "MagmaSerpent", Variant = "Normal" },
		{ Slot = 4, CreatureId = "PuddleBlob", Variant = "Silver" },
		{ Slot = 5, CreatureId = "SunPhoenix", Variant = "Normal" },
		{ Slot = 6, CreatureId = "BeachChick", Variant = "Emerald" },
		{ Slot = 7, CreatureId = "TikiGolem", Variant = "Normal" },
	},
	MyOffer = { 1, 4 },
	TheirOffer = { { CreatureId = "SunPhoenix", Variant = "Normal" }, { CreatureId = "MagmaSerpent", Variant = "Golden" } },
	MyReady = false,
	TheirReady = true,
	CountdownEndsAt = 0,
})
ADVANCE(0.2)
DUMP_GUI(LOCAL.PlayerGui)

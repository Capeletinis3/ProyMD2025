local rf = Instance.new("Folder"); rf.Name = "Remotes"; rf.Parent = game:GetService("ReplicatedStorage")
for _, n in { "BuyUpgrade", "Notify", "Hatched", "TutorialAction" } do local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = rf end
LOCAL:SetAttribute("BaseId", 1)
LOCAL:SetAttribute("Coins", 1850)
LOCAL:SetAttribute("IncubationSpeedLevel", 2)
LOCAL:SetAttribute("IncubatorCount", 3)
LOCAL:SetAttribute("WalkSpeedLevel", 1)
LOCAL:SetAttribute("BaseLevel", 1)
LOCAL:SetAttribute("Income", 125)
LOCAL:SetAttribute("CarriedEggRarity", "Legendary")
local screen = Instance.new("Part"); screen.Name = "Screen"; screen.CFrame = CFrame.new(0, 0, 0)
local prompt = Instance.new("ProximityPrompt"); prompt:SetAttribute("Shared", true); prompt.Parent = screen
TAGGED.UpgradePrompt = { prompt }
local character = Instance.new("Model"); local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.CFrame = CFrame.new(0, 0, 3); root.Parent = character
LOCAL.Character = character
__mod("UpgradePanel").Start()
__mod("Hud").Start()
local Notifier = __mod("Notifier")
Notifier.Show("Incubation Speed upgraded!")
prompt.Triggered:Fire(LOCAL)
ADVANCE(0.5)
DUMP_GUI(LOCAL.PlayerGui)

STEP = 1
local rf = Instance.new("Folder"); rf.Name = "Remotes"; rf.Parent = game:GetService("ReplicatedStorage")
for _, n in { "BuyUpgrade", "Notify", "Hatched", "TutorialAction" } do local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = rf end
LOCAL:SetAttribute("BaseId", 1); LOCAL:SetAttribute("Coins", 60); LOCAL:SetAttribute("Income", 1)
LOCAL:SetAttribute("TutorialStep", tonumber(STEP))
local character = Instance.new("Model"); local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.CFrame = CFrame.new(0, 3, -20); root.Parent = character
LOCAL.Character = character
game:GetService("Workspace"):SetAttribute("WavePhase", "Calm"); game:GetService("Workspace"):SetAttribute("PhaseEndsAt", NOW + 42)
__mod("WaveClient").Start()
__mod("Hud").Start()
__mod("Tutorial").Start()
game:GetService("RunService").RenderStepped:Fire(0.016)
ADVANCE(0.1)
if STEP == 2 then __mod("Tutorial").ShowStepComplete(100); game:GetService("RunService").RenderStepped:Fire(0.016) end
DUMP_GUI(LOCAL.PlayerGui)

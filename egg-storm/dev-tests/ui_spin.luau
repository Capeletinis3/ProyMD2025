local rf = Instance.new("Folder"); rf.Name = "Remotes"; rf.Parent = game:GetService("ReplicatedStorage")
for _, n in { "BuyUpgrade", "Notify", "Hatched", "TutorialAction", "Spin", "Vip" } do local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = rf end
local ws = game:GetService("Workspace")
LOCAL:SetAttribute("NextFreeSpinAt", 0); LOCAL:SetAttribute("SpinTokens", 2)
local panel = __mod("SpinPanel")
panel.Start()
panel.Open()
ADVANCE(0.2)
DUMP_GUI(LOCAL.PlayerGui)

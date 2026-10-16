local rf = Instance.new("Folder"); rf.Name = "Remotes"; rf.Parent = game:GetService("ReplicatedStorage")
for _, n in { "BuyUpgrade", "Notify", "Hatched", "TutorialAction", "Rebirth", "Vip" } do local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = rf end
LOCAL:SetAttribute("Coins", 125000); LOCAL:SetAttribute("Income", 245)
__mod("Hud").Start()
__mod("RebirthPanel").Start()
__mod("VipClient").Start()
__mod("VipPanel").Open()
ADVANCE(0.2)
DUMP_GUI(LOCAL.PlayerGui)

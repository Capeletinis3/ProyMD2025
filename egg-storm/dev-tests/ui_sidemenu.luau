local rf = Instance.new("Folder"); rf.Name = "Remotes"; rf.Parent = game:GetService("ReplicatedStorage")
for _, n in { "BuyUpgrade", "Notify", "Hatched", "TutorialAction", "Rebirth", "Vip", "Trade" } do local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = rf end
LOCAL:SetAttribute("Coins", 125000); LOCAL:SetAttribute("Income", 245); LOCAL:SetAttribute("Rebirths", 0); LOCAL:SetAttribute("BaseLevel", 1)
LOCAL:SetAttribute("VIP", true)
__mod("Hud").Start()
__mod("RebirthPanel").Start()
__mod("VipClient").Start()
ADVANCE(0.2)
DUMP_GUI(LOCAL.PlayerGui)

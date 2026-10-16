local rf = Instance.new("Folder"); rf.Name = "Remotes"; rf.Parent = game:GetService("ReplicatedStorage")
for _, n in { "BuyUpgrade", "Notify", "Hatched", "TutorialAction", "Trade" } do local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = rf end
local ws = game:GetService("Workspace")
rawget(ws, "_props").GetServerTimeNow = function() return NOW end
LOCAL:SetAttribute("Coins", 250000); LOCAL:SetAttribute("Income", 245)
__mod("Hud").Start()
local panel = __mod("TradePanel")
panel.Start()
panel.ShowInvite("Carl", 903)
ADVANCE(0.2)
DUMP_GUI(LOCAL.PlayerGui)

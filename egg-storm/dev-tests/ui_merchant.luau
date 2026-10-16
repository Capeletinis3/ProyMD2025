local rf = Instance.new("Folder"); rf.Name = "Remotes"; rf.Parent = game:GetService("ReplicatedStorage")
for _, n in { "BuyUpgrade", "Notify", "Hatched", "TutorialAction", "Merchant" } do local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = rf end
local ws = game:GetService("Workspace")
rawget(ws, "_props").GetServerTimeNow = function() return NOW end
ws:SetAttribute("MerchantOffers", "Legendary:Golden:216000;Epic:Normal:15000;Secret:Normal:1800000")
ws:SetAttribute("MerchantRestockAt", NOW + 452)
LOCAL:SetAttribute("Coins", 250000); LOCAL:SetAttribute("Income", 245); LOCAL:SetAttribute("MerchantBought", "2")
__mod("Hud").Start()
local panel = __mod("MerchantPanel")
panel.Start()
panel.Open(nil)
ADVANCE(0.2)
DUMP_GUI(LOCAL.PlayerGui)

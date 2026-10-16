local rf = Instance.new("Folder"); rf.Name = "Remotes"; rf.Parent = game:GetService("ReplicatedStorage")
for _, n in { "BuyUpgrade", "Notify", "Hatched", "TutorialAction", "Merchant" } do local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = rf end
local ws = game:GetService("Workspace")
rawget(ws, "_props").GetServerTimeNow = function() return NOW end
ws:SetAttribute("MerchantRestockAt", NOW + 1299)
LOCAL:SetAttribute("Coins", 2500000); LOCAL:SetAttribute("Income", 3400)
LOCAL:SetAttribute("MerchantOffers", "Egg:Mythic:Normal:360000:3;Mystery:Mystery:Normal:25000:10;Egg:Legendary:Golden:216000:5;Potion:Luck:Normal:1020000:5;Potion:FastNest:Normal:2040000:8;Egg:Secret:Normal:1800000:0")
LOCAL:SetAttribute("MerchantRenewPrice", 1020000)
local panel = __mod("MerchantPanel")
panel.Start()
panel.Open(nil)
ADVANCE(0.2)
DUMP_GUI(LOCAL.PlayerGui)

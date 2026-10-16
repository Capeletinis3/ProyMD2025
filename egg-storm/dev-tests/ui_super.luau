local rf = Instance.new("Folder"); rf.Name = "Remotes"; rf.Parent = game:GetService("ReplicatedStorage")
for _, n in { "BuyUpgrade", "Notify", "Hatched" } do local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = rf end
LOCAL:SetAttribute("Coins", 12850); LOCAL:SetAttribute("Income", 125)
LOCAL:SetAttribute("CarriedEggRarity", "Rare"); LOCAL:SetAttribute("CarriedEggVariant", "Emerald")
local ws = game:GetService("Workspace")
ws:SetAttribute("Event", "")
__mod("Hud").Start()
__mod("WaveClient").Start()
ws:SetAttribute("WavePhase", "Warning"); ws:SetAttribute("WaveKind", "Super"); ws:SetAttribute("PhaseEndsAt", NOW + 12)
rawget(ws, "_props").GetServerTimeNow = function() return NOW end
ADVANCE(1)
game:GetService("RunService").RenderStepped:Fire(0.016)
ADVANCE(0.1)
DUMP_GUI(LOCAL.PlayerGui)

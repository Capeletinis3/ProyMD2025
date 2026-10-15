--@@MAIN
local Config = __mod("Config")
local BaseService = __mod("BaseService")
local BaseFloors = __mod("BaseFloors")
local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
ADVANCE(0.5)
local w, d, gap = Config.Map.PlotWidth, Config.Map.PlotDepth, Config.Map.PlotGap
local lobbyHalf = (Config.Map.BaseCount * w + (Config.Map.BaseCount + 1) * gap) / 2
local bases = BaseService.GetBases()

-- Estantería (siempre está, con o sin la mejora)
local shelf = bases[1].Model:FindFirstChild("Shelf")
check(shelf ~= nil, "every base has a shelf frame")
local roof = shelf and shelf:FindFirstChild("ShelfRoof")
local roofTop = roof and roof.Position.Y + roof.Size.Y / 2 or 0
local sign = bases[1].Model.SignBoard
check(sign.Position.Y - sign.Size.Y / 2 > roofTop, "the name sign is above the shelf roof")
local postsOk = true
for _, p in shelf:GetChildren() do
	if p.Name == "ShelfPost" and math.abs(p.Size.Y - 26) > 0.01 then postsOk = false end
end
check(postsOk, "shelf posts go up to the roof")

for _, base in bases do BaseFloors.Build(base) end

local allInside, noOverlap = true, true
for _, base in bases do
	local floor = base.Model.Floor2
	local center = base.Model.PrimaryPart.CFrame * CFrame.new(0, -base.Model.PrimaryPart.Size.Y / 2, 0)
	local ladder = floor:FindFirstChild("Ladder")
	local platform = floor.Platform
	local platformTop = platform.Position.Y + 0.5
	if base.Id == 1 then
		check(ladder ~= nil and ladder.ClassName == "TrussPart", "the 2nd floor has a ladder (TrussPart)")
		check(ladder.Size.X == 2 and ladder.Size.Z == 2 and ladder.Size.Y % 2 == 0, "ladder size is valid for a TrussPart")
		local bottom = ladder.Position.Y - ladder.Size.Y / 2
		local top = ladder.Position.Y + ladder.Size.Y / 2
		check(math.abs(bottom - center.Position.Y) < 0.01, "ladder starts on the ground")
		check(top >= platformTop and top <= platformTop + 3, string.format("ladder reaches just above the floor (%.1f vs %.1f)", top, platformTop))
		local lp = center:PointToObjectSpace(ladder.Position)
		check(lp.X - 1 >= w / 2 - 0.01, "ladder is outside the plot, on the side")
		check(lp.Z - 1 >= 0 and lp.Z + 1 <= 6, "ladder is next to the opening in the railing")
		local blocked = false
		for _, p in floor:GetChildren() do
			if p.Name == "Rail" then
				local rp = center:PointToObjectSpace(p.Position)
				if math.abs(rp.X - (w / 2 - 0.2)) < 0.3 and rp.Z - p.Size.Z / 2 < 5.9 then blocked = true end
			end
		end
		check(not blocked, "there is an opening in the railing next to the ladder")
		local stripesOk = true
		for _, p in floor:GetChildren() do
			if p.Name == "DeckStripe" and p.CanCollide ~= false then stripesOk = false end
		end
		check(stripesOk and platform.CanCollide ~= false, "the striped deck is solid (stripes are only paint)")
	end
	local half = ladder.Size / 2
	if math.abs(ladder.Position.X) + half.X > lobbyHalf then allInside = false end
	for _, other in bases do
		if other ~= base then
			local edge = other.Model.PrimaryPart
			local p = edge.CFrame:PointToObjectSpace(ladder.Position)
			if math.abs(p.X) < edge.Size.X / 2 + 1 and math.abs(p.Z) < edge.Size.Z / 2 + 1 then noOverlap = false end
		end
	end
end
check(allInside, "all 8 ladders stay inside the lobby walls")
check(noOverlap, "no ladder touches a neighbouring base")
check(#bases[1].CreatureSlots == 14, "the floor still adds 6 creature pads")

-- Dump base 1 and 2 parts for rendering
for _, id in { 1, 2 } do
	for _, p in ALL_PARTS do
		if p.Parent and p.Transparency < 1 and p:GetFullName():find("Base" .. id .. "%.") then
			local c, s, col = p.CFrame, p.Size, p.Color
			print(string.format("PART %s %s %.2f %.2f %.2f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f",
				p.Name, tostring(p.Shape), s.x, s.y, s.z, c.p.x, c.p.y, c.p.z, c.r.x, c.r.y, c.r.z, c.u.x, c.u.y, c.u.z, c.b.x, c.b.y, c.b.z, col.R, col.G, col.B))
		end
	end
end
print(if fails == 0 then "ALL PASSED" else ("FAILURES: " .. fails))

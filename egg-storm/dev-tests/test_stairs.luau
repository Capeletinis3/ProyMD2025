--@@MAIN
local Config = __mod("Config")
local BaseService = __mod("BaseService")
local BaseFloors = __mod("BaseFloors")
local fails = 0
local function check(cond, msg)
	if cond then print("PASS", msg) else fails += 1; print("FAIL", msg) end
end
ADVANCE(0.5)
local w, gap = Config.Map.PlotWidth, Config.Map.PlotGap
local lobbyHalf = (Config.Map.BaseCount * w + (Config.Map.BaseCount + 1) * gap) / 2
local bases = BaseService.GetBases()
for _, base in bases do BaseFloors.Build(base) end

local allInside, noOverlap = true, true
for _, base in bases do
	local floor = base.Model.Floor2
	local center = base.Model.PrimaryPart.CFrame * CFrame.new(0, -base.Model.PrimaryPart.Size.Y / 2, 0)
	local steps = {}
	for _, p in floor:GetChildren() do
		if p.Name == "Step" then table.insert(steps, p) end
	end
	table.sort(steps, function(a, b) return a.Size.Y < b.Size.Y end)
	if base.Id == 1 then
		check(#steps == 13, "13 steps")
		local ok = true
		for i, st in steps do
			local top = st.Position.Y + st.Size.Y / 2
			if math.abs(top - i) > 0.01 then ok = false end
			local lp = center:PointToObjectSpace(st.Position)
			if math.abs(lp.X) - st.Size.X / 2 < w / 2 - 0.01 then ok = false end
		end
		check(ok, "each step is 1 stud higher than the last, and all are outside the plot")
		local platform = floor.Platform
		local landing = floor.Landing
		local lastTop = steps[#steps].Position.Y + steps[#steps].Size.Y / 2
		check(math.abs(lastTop - (platform.Position.Y + 0.5)) < 0.01, "last step reaches the 2nd floor height (" .. lastTop .. ")")
		check(math.abs(landing.Position.Y + 0.5 - lastTop) < 0.01, "landing is level with the floor")
		-- Hueco en la baranda del lado de la escalera: entre z=0 y z=LANDING no hay baranda en x = w/2
		local blocked = false
		for _, p in floor:GetChildren() do
			if p.Name == "Rail" then
				local lp = center:PointToObjectSpace(p.Position)
				if math.abs(lp.X - (w / 2 - 0.2)) < 0.3 and lp.Z - p.Size.Z / 2 < 5.9 then blocked = true end
			end
		end
		check(not blocked, "there is an opening in the floor railing to walk in from the landing")
	end
	-- Ningún escalón choca con otra base ni sale del lobby
	for _, st in steps do
		local half = st.Size / 2
		if math.abs(st.Position.X) + 3 > lobbyHalf then allInside = false end
		for _, other in bases do
			if other ~= base then
				local edge = other.Model.PrimaryPart
				local d = edge.CFrame:PointToObjectSpace(st.Position)
				if math.abs(d.X) < edge.Size.X / 2 + 3 and math.abs(d.Z) < edge.Size.Z / 2 + 1 then noOverlap = false end
			end
		end
	end
end
check(allInside, "all 8 staircases stay inside the lobby walls")
check(noOverlap, "no staircase touches a neighbouring base")
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

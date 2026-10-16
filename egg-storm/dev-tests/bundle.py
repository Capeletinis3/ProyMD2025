"""Bundle mock + real modules into one Luau script, run it, and render a top-down map preview."""
import re, subprocess, sys, pathlib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Circle

sim = pathlib.Path(__file__).parent
src = pathlib.Path(sys.argv[1])
luau = sys.argv[2]
out_png = sys.argv[3]

def module(path, replacements):
    s = (src / path).read_text()
    for a, b in replacements.items():
        s = s.replace(a, b)
    return "(function()\n" + s + "\nend)()"

parts = [(sim / "mock.luau").read_text()]
parts.append("local __Config = " + module("shared/Config.luau", {}))
parts.append("task = task or { spawn = function() end, wait = function() end }")
parts.append("local __Island = " + module("server/Services/IslandBuilder.luau", {"require(ReplicatedStorage.Shared.Config)": "__Config"}))
parts.append("local __HabitatBuilder = " + module("server/Services/HabitatBuilder.luau", {"require(ReplicatedStorage.Shared.Config)": "__Config"}))
parts.append("local __VillageBuilder = " + module("server/Services/VillageBuilder.luau", {"require(ReplicatedStorage.Shared.Config)": "__Config"}))
parts.append("local __MapBuilder = " + module("server/Services/MapBuilder.luau", {"require(ReplicatedStorage.Shared.Config)": "__Config", "require(script.Parent.IslandBuilder)": "__Island", "require(script.Parent.HabitatBuilder)": "__HabitatBuilder", "require(script.Parent.VillageBuilder)": "__VillageBuilder"}))
parts.append("local __BaseService = " + module("server/Services/BaseService.luau", {"require(ReplicatedStorage.Shared.Config)": "__Config"}))
parts.append("""
local map = __MapBuilder.Build()
__BaseService.Init(map)
print("BASES", #__BaseService.GetBases())
for _, p in ALL_PARTS do
  if p.Parent and p.Transparency < 1 then
    local c = p.CFrame
    local s = p.Size
    local col = p.Color
    print(string.format("PART %s %s %.2f %.2f %.2f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f",
      p.Name, tostring(p.Shape), s.x, s.y, s.z, c.p.x, c.p.y, c.p.z, c.r.x, c.r.y, c.r.z, c.u.x, c.u.y, c.u.z, c.b.x, c.b.y, c.b.z, col.R, col.G, col.B))
  end
end
""")
script = sim / "bundle.luau"
script.write_text("\n".join(parts))
res = subprocess.run([luau, str(script)], capture_output=True, text=True)
if res.returncode != 0 or res.stderr:
    print(res.stdout[-3000:]); print(res.stderr); sys.exit(1)

lines = res.stdout.splitlines()
for l in lines:
    if not l.startswith("PART"):
        print(l)
items = []
for l in lines:
    if l.startswith("PART"):
        f = l.split()
        name, shape = f[1], f[2]
        v = list(map(float, f[3:]))
        items.append((name, shape, v))
print("parts:", len(items))

fig, ax = plt.subplots(figsize=(9, 18))
# draw from bottom (low Y top) to top so taller things are painted last
def top_y(v):
    sx, sy, sz, px, py, pz = v[:6]
    return py + abs(v[10]) * sy / 2  # approx
for name, shape, v in sorted(items, key=lambda it: it[2][4] + it[2][1] / 2):
    sx, sy, sz, px, py, pz, rx_, ry_, rz_, ux, uy, uz, bx, by, bz, cr, cg, cb = v
    half = [sx / 2, sy / 2, sz / 2]
    if (shape == "PartType.Cylinder" and abs(ry_) > 0.99) or shape == "PartType.Ball":
        rad = min(sy, sz) / 2
        ax.update_datalim([(px - rad, pz - rad), (px + rad, pz + rad)])
        ax.add_patch(Circle((px, pz), rad, facecolor=(cr, cg, cb), edgecolor=(0, 0, 0, 0.3), linewidth=0.3))
        continue
    axes = [(rx_, rz_), (ux, uz), (bx, bz)]
    # project the box onto XZ: corners of the box
    pts = []
    for i in (-1, 1):
        for j in (-1, 1):
            for k in (-1, 1):
                x = px + i * half[0] * axes[0][0] + j * half[1] * axes[1][0] + k * half[2] * axes[2][0]
                z = pz + i * half[0] * axes[0][1] + j * half[1] * axes[1][1] + k * half[2] * axes[2][1]
                pts.append((x, z))
    # convex hull
    pts = sorted(set((round(a, 3), round(b, 3)) for a, b in pts))
    def cross(o, a, b): return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0: lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0: upper.pop()
        upper.append(p)
    hull = lower[:-1] + upper[:-1]
    if len(hull) < 3:
        continue
    ax.update_datalim(hull)
    ax.add_patch(Polygon(hull, closed=True, facecolor=(cr, cg, cb), edgecolor=(0, 0, 0, 0.3), linewidth=0.3))
ax.autoscale_view()
if len(sys.argv) > 4:
    x0, x1, z0, z1 = map(float, sys.argv[4].split(","))
    ax.set_xlim(x0, x1); ax.set_ylim(z0, z1)
    fig.set_size_inches(9, 9)

ax.set_aspect("equal")
ax.set_xlabel("X")
ax.set_ylabel("Z")
ax.set_title("Egg Storm - vista desde arriba (generada con el codigo real)")
plt.tight_layout()
plt.savefig(out_png, dpi=110)
print("saved", out_png)

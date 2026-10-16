"""Dibujo de la isla v2 desde arriba (terreno + Parts) y corte del volcán, generados con el código real.

Uso:  python3 dev-tests/island_preview.py src <ruta-a-luau> isla.png [volcan.png] [x0,x1,z0,z1]
"""
import subprocess, sys, pathlib
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Circle

sim = pathlib.Path(__file__).parent
src = pathlib.Path(sys.argv[1])
luau = sys.argv[2]
out_png = sys.argv[3]
profile_png = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4].endswith(".png") else None
bbox = sys.argv[-1] if "," in sys.argv[-1] else None
STEP = 6

def module(path, replacements):
    s = (src / path).read_text()
    for a, b in replacements.items():
        s = s.replace(a, b)
    return "(function()\n" + s + "\nend)()"

cfg = {"require(ReplicatedStorage.Shared.Config)": "__Config"}
parts = [(sim / "mock.luau").read_text()]
parts.append("task = { spawn = function() end, wait = function() end }")
parts.append("local __Config = " + module("shared/Config.luau", {}))
parts.append("local __Island = " + module("server/Services/IslandBuilder.luau", cfg))
parts.append("local __HabitatBuilder = " + module("server/Services/HabitatBuilder.luau", {"require(ReplicatedStorage.Shared.Config)": "__Config"}))
parts.append("local __MapBuilder = " + module("server/Services/MapBuilder.luau", {**cfg, "require(script.Parent.IslandBuilder)": "__Island", "require(script.Parent.HabitatBuilder)": "__HabitatBuilder"}))
parts.append(f"""
local map = __MapBuilder.Build()
local I = __Config.Island
for z = I.MinZ, I.MaxZ, {STEP} do
  local row = {{}}
  for x = I.MinX, I.MaxX, {STEP} do
    local h, kind = __Island.Sample(x, z)
    table.insert(row, string.format("%.1f:%s", h, kind))
  end
  print("ROW " .. table.concat(row, " "))
end
for r = 0, 400, 2 do
  local h = __Island.Sample(I.Volcano.X - r, 23)
  local h2 = __Island.Sample(I.Volcano.X + r, 23)
  print(string.format("PROF %d %.2f %.2f", r, h, h2))
end
for _, p in ALL_PARTS do
  if p.Parent and p.Transparency < 1 then
    local c, s, col = p.CFrame, p.Size, p.Color
    print(string.format("PART %s %s %.2f %.2f %.2f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f",
      p.Name, tostring(p.Shape), s.x, s.y, s.z, c.p.x, c.p.y, c.p.z, c.r.x, c.r.y, c.r.z, c.u.x, c.u.y, c.u.z, c.b.x, c.b.y, c.b.z, col.R, col.G, col.B))
  end
end
print(string.format("BOUNDS %d %d %d %d %.2f", I.MinX, I.MaxX, I.MinZ, I.MaxZ, I.SeaLevel))
""")
script = sim / "island_bundle.luau"
script.write_text("\n".join(parts))
res = subprocess.run([luau, str(script)], capture_output=True, text=True)
if res.returncode != 0 or res.stderr:
    print(res.stdout[-3000:]); print(res.stderr); sys.exit(1)

rows, items, prof = [], [], []
for l in res.stdout.splitlines():
    if l.startswith("ROW "):
        rows.append([c.split(":") for c in l[4:].split()])
    elif l.startswith("PART"):
        f = l.split()
        items.append((f[1], f[2], list(map(float, f[3:]))))
    elif l.startswith("PROF"):
        prof.append(tuple(map(float, l.split()[1:])))
    elif l.startswith("BOUNDS"):
        b = l.split()[1:]
        minx, maxx, minz, maxz, sea = map(float, b)

H = np.array([[float(h) for h, _ in r] for r in rows])
K = [[k for _, k in r] for r in rows]
COL = {
    "Sand": (240, 220, 170), "Grass": (108, 192, 74), "Jungle": (46, 139, 62), "Rock": (143, 138, 133),
    "Basalt": (74, 68, 64), "Slate": (58, 54, 52), "Lava": (255, 106, 26), "Reef": (150, 225, 230),
    "Shallow": (90, 205, 225), "Deep": (16, 84, 128), "Ground": (120, 92, 62),
}
img = np.zeros(H.shape + (3,))
gz, gx = np.gradient(H, STEP)
slope = np.maximum(abs(gz), abs(gx))
for i in range(H.shape[0]):
    for j in range(H.shape[1]):
        h, k = H[i, j], K[i][j]
        if k in ("Sea", "Lagoon") or (k == "Hidden" and False):
            depth = sea - h
            t = min(1, max(0, (depth - 2) / 20))
            c = np.array(COL["Shallow"]) * (1 - t) + np.array(COL["Deep"]) * t
        elif k == "Reef":
            c = COL["Reef"]
        elif k == "Hidden":
            c = (246, 221, 176)
        elif k == "Beach":
            c = COL["Sand"]
        elif k == "River":
            c = COL["Lava"]
        elif k == "Crater":
            c = COL["Basalt"]
        elif k == "Volcano":
            c = COL["Slate"] if h > 170 else COL["Basalt"] if h > 70 else COL["Rock"] if h > 24 else COL["Jungle"]
        elif k == "Cliff":
            c = COL["Rock"] if slope[i, j] > 0.45 else COL["Jungle"]
        else:
            c = COL["Rock"] if slope[i, j] > 1 else COL["Jungle"] if k == "Jungle" else COL["Grass"]
        img[i, j] = np.array(c) / 255
# Sombra de relieve (luz desde el noroeste)
shade = np.clip(1 + (-gx - gz) * 0.35, 0.55, 1.3)
land = H > sea
img[land] = np.clip(img[land] * shade[land, None], 0, 1)

fig, ax = plt.subplots(figsize=(16, 7.5))
ax.imshow(img, extent=(minx - STEP / 2, maxx + STEP / 2, maxz + STEP / 2, minz - STEP / 2), interpolation="bilinear")
# Parts (lobby, bases, cañón, faro...) arriba del terreno
for name, shape, v in sorted(items, key=lambda it: it[2][4] + it[2][1] / 2):
    sx, sy, sz, px, py, pz, rx_, ry_, rz_, ux, uy, uz, bx, by, bz, cr, cg, cb = v
    if name in ("Beam",):
        continue
    half = [sx / 2, sy / 2, sz / 2]
    if (shape == "PartType.Cylinder" and abs(ry_) > 0.99) or shape == "PartType.Ball":
        rad = min(sy, sz) / 2
        ax.add_patch(Circle((px, pz), rad, facecolor=(cr, cg, cb), edgecolor=(0, 0, 0, 0.25), linewidth=0.2))
        continue
    axes = [(rx_, rz_), (ux, uz), (bx, bz)]
    pts = []
    for i in (-1, 1):
        for j in (-1, 1):
            for k in (-1, 1):
                pts.append((px + i * half[0] * axes[0][0] + j * half[1] * axes[1][0] + k * half[2] * axes[2][0],
                            pz + i * half[0] * axes[0][1] + j * half[1] * axes[1][1] + k * half[2] * axes[2][1]))
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
    if len(hull) >= 3:
        ax.add_patch(Polygon(hull, closed=True, facecolor=(cr, cg, cb), edgecolor=(0, 0, 0, 0.25), linewidth=0.2))
if bbox:
    x0, x1, z0, z1 = map(float, bbox.split(","))
    ax.set_xlim(x0, x1); ax.set_ylim(z1, z0)
else:
    ax.set_xlim(minx, maxx); ax.set_ylim(maxz, minz)
ax.set_aspect("equal")
ax.set_title("Isla v2 - vista desde arriba (generada con IslandBuilder; -Z = norte, arriba)")
plt.tight_layout()
plt.savefig(out_png, dpi=110)
print("saved", out_png)

if profile_png:
    r = np.array([p[0] for p in prof])
    fig, ax = plt.subplots(figsize=(12, 5))
    ax.fill_between(-r, [p[1] for p in prof], sea - 30, color="#5a4a40")
    ax.fill_between(r, [p[2] for p in prof], sea - 30, color="#5a4a40")
    ax.axhline(sea, color="#2aa0c0", linestyle="--")
    ax.set_title("Volcán - corte de perfil (alto = 330 x (1 - r/380)^1.55, cráter de 38)")
    ax.set_aspect("equal")
    plt.tight_layout()
    plt.savefig(profile_png, dpi=110)
    print("saved", profile_png)

"""Render PART lines (from a flow test) as a top view (X/Z) and a side view (Z/Y)."""
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Circle
lines = [l.split() for l in open(sys.argv[1]) if l.startswith("PART")]
out = sys.argv[2]
front_mode = len(sys.argv) > 3 and sys.argv[3] == "front"
if front_mode:
    fig, front = plt.subplots(1, 1, figsize=(16, 6))
else:
    fig, (top, side) = plt.subplots(1, 2, figsize=(16, 8))
def hull(pts):
    pts = sorted(set((round(a, 3), round(b, 3)) for a, b in pts))
    def cross(o, a, b): return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0: lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0: up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]
items = []
for f in lines:
    v = list(map(float, f[3:])); items.append((f[1], f[2], v))
views = ((front, (0, 1), lambda v: -v[5]),) if front_mode else ((top, (0, 2), lambda v: v[4] + v[1] / 2), (side, (2, 1), lambda v: -v[3]))
for ax, (i0, i1), key in views:
    for name, shape, v in sorted(items, key=lambda it: key(it[2])):
        sx, sy, sz, px, py, pz = v[:6]
        R = [v[6:9], v[9:12], v[12:15]]; col = v[15:18]
        pts = []
        for a in (-1, 1):
            for b in (-1, 1):
                for c in (-1, 1):
                    p = [(px, py, pz)[k] + a*sx/2*R[0][k] + b*sy/2*R[1][k] + c*sz/2*R[2][k] for k in range(3)]
                    pts.append((p[i0], p[i1]))
        h = hull(pts)
        if len(h) >= 3:
            ax.update_datalim(h)
            ax.add_patch(Polygon(h, closed=True, facecolor=col, edgecolor=(0, 0, 0, 0.35), linewidth=0.4, alpha=0.9))
    ax.autoscale_view(); ax.set_aspect("equal")
if front_mode:
    front.set_title("Lobby de frente, mirando hacia el pasillo (X / altura)"); front.set_xlabel("X"); front.set_ylabel("Y (altura)")
else:
    top.set_title("Bases 1 y 2 desde arriba (X / Z)"); top.set_xlabel("X"); top.set_ylabel("Z")
    side.set_title("De costado (Z / altura)"); side.set_xlabel("Z"); side.set_ylabel("Y (altura)")
plt.tight_layout(); plt.savefig(out, dpi=100); print("saved", out)

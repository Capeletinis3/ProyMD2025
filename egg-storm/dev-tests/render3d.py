"""Dibujo 3D con perspectiva de las líneas PART (de una prueba): python3 render3d.py salida.txt foto.png cx,cy,cz camX,camY,camZ [radio]
cx,cy,cz = punto al que mira la cámara; camX.. = dónde está la cámara; radio = solo piezas a esa distancia del punto."""
import sys, math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection

lines = [l.split() for l in open(sys.argv[1]) if l.startswith("PART")]
out = sys.argv[2]
target = np.array(list(map(float, sys.argv[3].split(","))))
eye = np.array(list(map(float, sys.argv[4].split(","))))
radius = float(sys.argv[5]) if len(sys.argv) > 5 else 1e9
W, H, FOV = 1600, 1000, 50

fwd = target - eye; fwd /= np.linalg.norm(fwd)
right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
up = np.cross(right, fwd)
focal = (W / 2) / math.tan(math.radians(FOV / 2))
light = np.array([0.4, 0.8, 0.45]); light /= np.linalg.norm(light)

def project(p):
    d = p - eye
    z = d @ fwd
    if z < 0.5: return None, z
    return (W / 2 + focal * (d @ right) / z, H / 2 - focal * (d @ up) / z), z

polys, colors, depths = [], [], []
def add_face(pts, normal, color):
    c = pts.mean(axis=0)
    if (eye - c) @ normal < 0: return  # cara de atrás
    proj = [project(p) for p in pts]
    if any(q[0] is None for q in proj): return
    shade = 0.55 + 0.45 * max(0, normal @ light)
    polys.append([q[0] for q in proj]); colors.append(np.clip(np.array(color) * shade, 0, 1))
    depths.append(np.linalg.norm(c - eye))

for f in lines:
    name, shape = f[1], f[2]
    v = list(map(float, f[3:]))
    size = np.array(v[0:3]); pos = np.array(v[3:6])
    R = np.array([v[6:9], v[9:12], v[12:15]]).T  # columnas: right, up, back
    color = v[15:18]
    if np.linalg.norm(pos - target) > radius: continue
    if name in ("Front", "Side") and abs(color[0] - 0.498) < 0.01 and abs(color[2] - 0.910) < 0.01: continue  # vidrio (en el juego es transparente)
    if shape == "PartType.Ball":
        n = 10
        r = size.min() / 2
        for i in range(n):
            for j in range(n // 2):
                a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
                b0, b1 = math.pi * j / (n // 2) - math.pi / 2, math.pi * (j + 1) / (n // 2) - math.pi / 2
                def sp(a, b): return np.array([math.cos(b) * math.cos(a), math.sin(b), math.cos(b) * math.sin(a)])
                quad = [sp(a0, b0), sp(a1, b0), sp(a1, b1), sp(a0, b1)]
                nrm = sum(quad) / 4; nrm /= np.linalg.norm(nrm)
                scale = size / 2
                add_face(np.array([pos + R @ (q * scale) for q in quad]), R @ nrm, color)
    elif shape == "PartType.Cylinder":
        n = 12
        L, rad = size[0] / 2, min(size[1], size[2]) / 2
        ring = [np.array([0, math.cos(2 * math.pi * i / n), math.sin(2 * math.pi * i / n)]) for i in range(n)]
        for i in range(n):
            a, b = ring[i], ring[(i + 1) % n]
            quad = [np.array([-L, 0, 0]) + a * rad, np.array([L, 0, 0]) + a * rad, np.array([L, 0, 0]) + b * rad, np.array([-L, 0, 0]) + b * rad]
            nrm = (a + b) / 2; nrm /= np.linalg.norm(nrm)
            add_face(np.array([pos + R @ q for q in quad]), R @ nrm, color)
        for sgn in (-1, 1):
            cap = [np.array([sgn * L, 0, 0]) + r * rad for r in ring]
            add_face(np.array([pos + R @ q for q in cap]), R @ np.array([sgn, 0, 0]), color)
    else:
        hx, hy, hz = size / 2
        corners = {}
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    corners[(sx, sy, sz)] = pos + R @ np.array([sx * hx, sy * hy, sz * hz])
        for axis in range(3):
            for sgn in (-1, 1):
                keys = []
                for a in (-1, 1):
                    for b in ((-1, 1) if a == -1 else (1, -1)):
                        k = [0, 0, 0]; k[axis] = sgn
                        others = [i for i in range(3) if i != axis]
                        k[others[0]] = a; k[others[1]] = b
                        keys.append(tuple(k))
                nrm = np.zeros(3); nrm[axis] = sgn
                add_face(np.array([corners[k] for k in keys]), R @ nrm, color)

order = np.argsort(depths)[::-1]
fig = plt.figure(figsize=(W / 100, H / 100), dpi=100)
ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(0, W); ax.set_ylim(H, 0); ax.axis("off")
ax.add_patch(plt.Rectangle((0, 0), W, H * 0.55, color=(0.6, 0.83, 0.95)))
ax.add_patch(plt.Rectangle((0, H * 0.55), W, H * 0.45, color=(0.86, 0.79, 0.62)))
ax.add_collection(PolyCollection([polys[i] for i in order], facecolors=[colors[i] for i in order], edgecolors=[(0, 0, 0, 0.18)] * len(order), linewidths=0.3))
fig.savefig(out)
print("saved", out, len(polys), "faces")

"""Run real client UI modules in the mock and render the resulting GUI tree to a PNG; flag text that doesn't fit."""
import re, subprocess, sys, pathlib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patheffects
from matplotlib.patches import FancyBboxPatch, Rectangle

sim = pathlib.Path(__file__).parent
src = pathlib.Path(sys.argv[1]); luau = sys.argv[2]; test = pathlib.Path(sys.argv[3]).read_text(); out_png = sys.argv[4]
W, H = int(sys.argv[5]), int(sys.argv[6])
REQ = re.compile(r"require\((?:script\.Parent|ReplicatedStorage\.Shared|Services)\.(\w+)\)")
modules = {}
for f in (src / "shared").glob("*.luau"): modules[f.stem] = f"shared/{f.name}"
for f in (src / "client").glob("*.luau"): modules[f.stem] = f"client/{f.name}"
out = [f"VIEW_W, VIEW_H = {W}, {H}", (sim / "mock.luau").read_text(), (sim / "runtime.luau").read_text(), (sim / "uimock.luau").read_text()]
out.append("local __loaders, __cache = {}, {}")
out.append("local function __req(name) if __cache[name] == nil then __cache[name] = __loaders[name]() end return __cache[name] end")
for name, path in modules.items():
    body = REQ.sub(lambda m: f'__req("{m.group(1)}")', (src / path).read_text())
    body = body.replace("RunService:IsServer()", "false")
    out.append(f"__loaders[{name!r}] = function()\n{body}\nend")
out.append("local function __mod(n) return __req(n) end")
out.append("task.spawn(function()\n" + test + "\nend)")
script = sim / "ui_bundle.luau"; script.write_text("\n".join(out))
res = subprocess.run([luau, str(script)], capture_output=True, text=True)
if res.returncode != 0 or res.stderr:
    print(res.stdout[-2000:]); print(res.stderr); sys.exit(1)

fig = plt.figure(figsize=(W / 100, H / 100), dpi=100)
ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(0, W); ax.set_ylim(H, 0); ax.axis("off")
ax.add_patch(Rectangle((0, 0), W, H, color=(0.55, 0.75, 0.95)))
renderer = fig.canvas.get_renderer()
problems = []
for line in res.stdout.splitlines():
    if not line.startswith("GUI"):
        if line.strip(): print(line)
        continue
    _, cls, x, y, w, h, bg, bt, corner, text, tc, ts, align, scale, name = line.split("\t")
    x, y, w, h, bt, ts = float(x), float(y), float(w), float(h), float(bt), float(ts)
    text = text.replace("\\n", "\n")
    text = re.sub(r"<[^>]+>", "", text)  # RichText: sin las etiquetas (los colores no se dibujan)
    name, wrapped, rot = name.rsplit("|", 2); rot = float(rot); wrapped = wrapped == "true"
    if rot and bg != "-" and bt < 1:
        import matplotlib.transforms as mt
        r, g, b = map(float, bg.split(","))
        rect = Rectangle((x, y), w, h, color=(r, g, b), alpha=(1 - bt) * 0.6, lw=0)
        rect.set_transform(mt.Affine2D().rotate_deg_around(x + w / 2, y + h / 2, rot) + ax.transData)
        ax.add_patch(rect)
        continue
    if bg != "-" and bt < 1:
        r, g, b = map(float, bg.split(","))
        if corner == "true":
            ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle=f"round,pad=0,rounding_size={min(w, h) * 0.2}", color=(r, g, b), alpha=1 - bt, lw=0))
        else:
            ax.add_patch(Rectangle((x, y), w, h, color=(r, g, b), alpha=1 - bt, lw=0))
    if text and cls in ("TextLabel", "TextButton"):
        r, g, b = map(float, tc.split(",")) if tc != "-" else (0, 0, 0)
        ha = {"TextXAlignment.Left": "left", "TextXAlignment.Right": "right"}.get(align, "center")
        tx = x if ha == "left" else (x + w if ha == "right" else x + w / 2)
        if cls == "TextButton": ha, tx = "center", x + w / 2
        def draw(s):
            return ax.text(tx, y + h / 2, s, ha=ha, va="center", fontsize=ts * 0.72, color=(r, g, b), fontweight="bold",
                           multialignment={"left": "left", "right": "right"}.get(ha, "center"),
                           path_effects=[matplotlib.patheffects.withStroke(linewidth=2, foreground="black")])
        t = draw(text)
        if wrapped and t.get_window_extent(renderer).width > w + 2:
            # Como TextWrapped de Roblox: corta en renglones por palabras
            t.remove()
            lines, cur = [], ""
            for word in text.split(" "):
                trial = (cur + " " + word).strip()
                probe = draw(trial); fits = probe.get_window_extent(renderer).width <= w + 2; probe.remove()
                if fits or not cur:
                    cur = trial
                else:
                    lines.append(cur); cur = word
            lines.append(cur)
            text = "\n".join(lines)
            t = draw(text)
        bb = t.get_window_extent(renderer)
        if bb.width > w + 2 or bb.height > h + 6:
            problems.append(f"'{text}' needs {bb.width:.0f}x{bb.height:.0f}px but has {w:.0f}x{h:.0f}")
import matplotlib.patheffects
fig.savefig(out_png)
print("saved", out_png)
print("TEXT FIT:", "OK" if not problems else "\n  " + "\n  ".join(problems))

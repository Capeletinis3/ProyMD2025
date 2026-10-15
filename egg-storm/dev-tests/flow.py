"""Run the real server code (Main.server.luau + services) in the mock runtime with a scripted test."""
import re, subprocess, sys, pathlib

sim = pathlib.Path(__file__).parent
src = pathlib.Path(sys.argv[1])
luau = sys.argv[2]
test = pathlib.Path(sys.argv[3]).read_text()

REQ = re.compile(r"require\((?:script\.Parent|ReplicatedStorage\.Shared|Services)\.(\w+)\)")

modules = {}
for f in (src / "shared").glob("*.luau"):
    modules[f.stem] = f"shared/{f.name}"
for f in (src / "server/Services").glob("*.luau"):
    modules[f.stem] = f"server/Services/{f.name}"

out = [(sim / "mock.luau").read_text(), (sim / "runtime.luau").read_text()]
out.append("local __loaders, __cache = {}, {}")
out.append("local function __req(name) if __cache[name] == nil then __cache[name] = __loaders[name]() end return __cache[name] end")
for name, path in modules.items():
    body = REQ.sub(lambda m: f'__req("{m.group(1)}")', (src / path).read_text())
    out.append(f"__loaders[{name!r}] = function()\n{body}\nend")
main = REQ.sub(lambda m: f'__req("{m.group(1)}")', (src / "server/Main.server.luau").read_text())
main = main.replace("local Services = script.Parent.Services", "")
out.append("local function __mod(n) return __req(n) end")
setup, sep, body = test.partition("--@@MAIN")
if not sep:
    setup, body = "", test
out.append("task.spawn(function()\n" + setup + "\nend)")
out.append("task.spawn(function()\n" + main + "\nend)")
out.append("task.spawn(function()\n" + body + "\nend)")
script = sim / "flow_bundle.luau"
script.write_text("\n".join(out))
res = subprocess.run([luau, str(script)], capture_output=True, text=True)
print(res.stdout)
if res.returncode != 0 or res.stderr:
    print(res.stderr)
    sys.exit(1)

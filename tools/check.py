"""Fail-fast pre-export checks. Run: python3 tools/check.py (exit != 0 fails CI)."""
import re, glob, json, os, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
errs = []

# 1. Exactly one root node per scene (blank 3D on device otherwise)
for f in sorted(glob.glob(BASE + "/scenes/**/*.tscn", recursive=True)):
    src = open(f).read()
    roots = re.findall(r'^\[node name="[^"]+" type="[^"]+"\]', src, re.M)
    if len(roots) != 1:
        errs.append(f"{f}: {len(roots)} root nodes (must be 1)")
    m = re.search(r"load_steps=(\d+)", src)
    ext = len(re.findall(r"\[ext_resource", src))
    sub = len(re.findall(r"\[sub_resource", src))
    if m and int(m.group(1)) not in (ext + sub, ext + sub + 1):
        errs.append(f"{f}: load_steps {m.group(1)} vs ext {ext}+sub {sub}")
    for rm in re.finditer(r'res://[^"]+', src):
        p = rm.group(0)
        if not os.path.exists(BASE + "/" + p[6:]):
            errs.append(f"{f}: missing {p}")

# 2. Landscape lock for 1280x720 HUD design
proj = open(BASE + "/project.godot").read()
if "window/handheld/orientation=0" not in proj:
    errs.append("project.godot: orientation is not 0 (forced landscape)")

# 3. All data JSON parses
for f in sorted(glob.glob(BASE + "/data/*.json")):
    try:
        json.load(open(f))
    except Exception as e:
        errs.append(f"{f}: JSON error {e}")

# 4. Every HUD button wired
tscn = open(BASE + "/scenes/ui/hud.tscn").read()
gd = open(BASE + "/scripts/hud.gd").read()
for b in re.findall(r'\[node name="(\w+)" type="Button"', tscn):
    if b not in gd:
        errs.append(f"hud: button {b} not referenced in hud.gd")

# 5. Spawns must sit over solid floor (infinite-fall guard)
def v3(s):
    m = re.search(r"Vector3\(([^)]+)\)", s)
    return tuple(float(x) for x in m.group(1).split(",")) if m else None

wl = open(BASE + "/scripts/world_loader.gd").read()
spawns = dict(re.findall(r"var (\w+_spawn) := (Vector3\([^)]+\))", wl))
floors = {}
for name, scene in [("school", "scenes/school.tscn"), ("village", "scenes/village.tscn")]:
    src = open(BASE + "/" + scene).read()
    box = re.search(r'\[node name="(Floor|Ground)"[^\]]*\][^\[]*?size = (Vector3\([^)]+\))[^\[]*?position = (Vector3\([^)]+\))', src, re.S)
    if box:
        floors[name] = (v3(box.group(2)), v3(box.group(3)))
for key, scene in [("school_spawn", "school"), ("village_spawn", "village")]:
    if key not in spawns:
        errs.append(f"world_loader: {key} missing")
    elif scene in floors:
        px, _, pz = v3(spawns[key])
        (fx, _, fz), (qx, _, qz) = floors[scene]
        if not (qx - fx / 2 <= px <= qx + fx / 2 and qz - fz / 2 <= pz <= qz + fz / 2):
            errs.append(f"{scene}: spawn {key} off the floor")
main = open(BASE + "/scripts/main.gd").read()
if "Vector3(0, 1, 6)" in main:
    errs.append("main.gd: stale off-floor spawn (0,1,6) still present")

if errs:
    print("CHECK FAILED:")
    for e in errs:
        print(" -", e)
    sys.exit(1)
print("CHECK OK")

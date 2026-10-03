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

if errs:
    print("CHECK FAILED:")
    for e in errs:
        print(" -", e)
    sys.exit(1)
print("CHECK OK")

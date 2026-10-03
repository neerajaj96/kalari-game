"""Fail-fast pre-export checks. Run: python3 tools/check.py.
ERRORs exit 1 (fail CI). WARNs print only (lenient mode)."""
import re, glob, json, os, sys
import xml.etree.ElementTree as ET

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
errs = []
warns = []

GD = {f: open(f).read() for f in sorted(glob.glob(BASE + "/scripts/*.gd"))}
TSCN = {f: open(f).read() for f in sorted(glob.glob(BASE + "/scenes/**/*.tscn", recursive=True))}
DATA = {}
for f in sorted(glob.glob(BASE + "/data/*.json")):
    try:
        DATA[f] = json.load(open(f))
    except Exception as e:
        errs.append(f"{f}: JSON error {e}")

# --- 0. scenes: roots, headers, res:// refs (existing) ---
for f, src in TSCN.items():
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

# --- 1. groups produced vs consumed ---
produced = set()
consumed = set()
for f, src in GD.items():
    produced.update(re.findall(r'add_to_group\("([^"]+)"', src))
    consumed.update(re.findall(r'get_first_node_in_group\("([^"]+)"', src))
    consumed.update(re.findall(r'get_nodes_in_group\("([^"]+)"', src))
    consumed.update(re.findall(r'is_in_group\("([^"]+)"', src))
for g in sorted(consumed - produced):
    errs.append(f"groups: '{g}' consumed but never add_to_group'd")

# --- 2. get_node_or_null paths resolve in matching scene ---
PATH_SCENE = [("player.gd", "scenes/player.tscn"), ("enemy_ai.gd", "scenes/enemy.tscn")]
for gd_name, scene in PATH_SCENE:
    src = GD.get(BASE + "/scripts/" + gd_name, "")
    tsrc = TSCN.get(BASE + "/" + scene, "")
    nodes = set(re.findall(r'\[node name="([^"]+)"', tsrc))
    for p in re.findall(r'get_node_or_null\("([^"]+)"', src):
        head = p.split("/")[0]
        if head not in nodes:
            errs.append(f"{gd_name}: node path '{p}' not in {scene}")

# --- 3. JSON keys read vs present ---
def need_keys(obj, keys, where):
    for k in keys:
        if k not in obj:
            errs.append(f"{where}: missing key '{k}'")

for r in DATA.get(BASE + "/data/gurukkal_ranks.json", {}).get("ranks", []):
    need_keys(r, ["rank", "xp_needed", "title"], "gurukkal_ranks")
for s in DATA.get(BASE + "/data/nitya.json", {}).get("slots", []):
    need_keys(s, ["id", "name", "fetch", "xp"], "nitya")
for p in DATA.get(BASE + "/data/temple_plot.json", {}).get("phases", []):
    need_keys(p, ["id", "n", "name", "rank_needed", "needs", "xp", "brief"], "temple_plot")
for q in DATA.get(BASE + "/data/vama.json", {}).get("quests", []):
    need_keys(q, ["id", "n", "name", "need", "xp", "brief"], "vama")
for t in DATA.get(BASE + "/data/meru_tabs.json", {}).get("tabs", []) + DATA.get(BASE + "/data/user_texts.json", {}).get("tabs", []):
    need_keys(t, ["id", "name_en", "name_ml", "what", "how_in_game", "philosophy", "sources"], "tabs")

# --- 4. tab IDs referenced exist + unique ---
ids = [t.get("id", "") for t in DATA.get(BASE + "/data/meru_tabs.json", {}).get("tabs", []) + DATA.get(BASE + "/data/user_texts.json", {}).get("tabs", [])]
if len(ids) != len(set(ids)):
    errs.append("tabs: duplicate tab id")
for f, src in GD.items():
    for tid in re.findall(r'show_tab_by_id\("([^"]+)"', src):
        if tid not in ids:
            errs.append(f"{f}: tab id '{tid}' not defined")

# --- 5. ranks ascending + xp_sources keys ---
ranks = DATA.get(BASE + "/data/gurukkal_ranks.json", {}).get("ranks", [])
needs = [int(r.get("xp_needed", -1)) for r in ranks]
if needs != sorted(needs) or (needs and needs[0] != 0):
    errs.append("gurukkal_ranks: xp_needed must ascend from 0")
for key in ["meyppayattu_rep", "bandit_defeat", "quest_complete", "daily_uzhichil", "tournament_win"]:
    if key not in DATA.get(BASE + "/data/gurukkal_ranks.json", {}).get("xp_sources", {}):
        warns.append(f"gurukkal_ranks: xp_sources lacks '{key}'")

# --- 6. plot gates reachable, needs keys known ---
maxrank = max([int(r.get("rank", 1)) for r in ranks] or [1])
for p in DATA.get(BASE + "/data/temple_plot.json", {}).get("phases", []):
    if int(p.get("rank_needed", 1)) > maxrank:
        errs.append(f"temple_plot: phase '{p.get('id')}' needs rank {p.get('rank_needed')} > max {maxrank}")
    for k in p.get("needs", {}):
        if k not in ("supply", "kills", "kills_total", "visit_hermitage", "visit_sanctum"):
            warns.append(f"temple_plot: phase '{p.get('id')}' unknown need '{k}'")

# --- 7. combat sanity (warnings) ---
try:
    moves = {m["id"]: m for m in DATA[BASE + "/data/moves.json"]["moves"]}
    weaps = {w["id"]: w for w in DATA[BASE + "/data/weapons.json"]["weapons"]}
    r1 = moves["mey_02_valinjamarnnu"]
    hits = 100.0 / (float(r1["damage"]) * float(weaps["none"]["damage_mult"]))
    if hits > 15 or hits < 2:
        warns.append(f"combat: rank-1 hits-to-kill {hits:.1f} outside 2..15")
    if float(r1["stamina_cost"]) > 100:
        errs.append("combat: rank-1 cost exceeds stamina pool")
except Exception as e:
    warns.append(f"combat sanity skipped: {e}")

# --- 8. sadhana/vama tables match code ---
sj = DATA.get(BASE + "/data/sadhana.json", {}).get("sessions", {})
for k in ["kalari", "temple", "forest"]:
    if k not in sj:
        errs.append(f"sadhana.json: session '{k}' missing (code expects it)")
vj = DATA.get(BASE + "/data/vama.json", {}).get("quests", [])
for vid, vxp in [("tattva", 120), ("kula", 150), ("vira", 180)]:
    hit = [q for q in vj if q.get("id") == vid]
    if not hit:
        errs.append(f"vama.json: quest '{vid}' missing")
    elif int(hit[0].get("xp", -1)) != vxp:
        warns.append(f"vama.json: quest '{vid}' xp {hit[0].get('xp')} != code {vxp}")

# --- 9. version triple ---
env = open(BASE + "/.env").read()
m = re.search(r"^GODOT_VERSION=(\S+)", env, re.M)
bv = open(BASE + "/android/.build_version").read().strip()
proj = open(BASE + "/project.godot").read()
if not m:
    errs.append(".env: GODOT_VERSION line missing")
elif m.group(1).replace("-", ".") != bv:
    errs.append(f"versions: .env {m.group(1)} vs .build_version {bv}")
if '"4.5"' not in proj or "config_version=5" not in proj:
    errs.append("project.godot: expected 4.5 features + config_version=5")

# --- 10. preset <-> workflow cross-match ---
pre = open(BASE + "/export_presets.cfg").read()
wf = open(BASE + "/.github/workflows/android_debug.yml").read()
pm = re.search(r'name="([^"]+)"\nplatform="Android"', pre)
if not pm or f'--export-debug "{pm.group(1)}"' not in wf:
    errs.append("preset name vs workflow --export-debug mismatch")
ep = re.search(r'export_path="([^"]+)"', pre)
if ep:
    if ep.group(1) not in wf or os.path.isabs(ep.group(1)):
        errs.append("export_path not mirrored in workflow or absolute")
for k in ["GODOT_ANDROID_KEYSTORE_DEBUG_PATH", "GODOT_ANDROID_KEYSTORE_DEBUG_USER", "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD"]:
    if k not in wf:
        errs.append(f"workflow: missing {k}")
if wf.find("keytool") > wf.find("--export-debug"):
    errs.append("workflow: keystore step must precede export")
for must in ["contents: write", "export_templates", "--headless --editor --quit", "mkdir -p build/android"]:
    if must not in wf:
        errs.append(f"workflow: missing '{must}'")

# --- 11. package rules ---
um = re.search(r'package/unique_name="([^"]+)"', pre)
if not um or not re.match(r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$", um.group(1)):
    errs.append("package/unique_name invalid (lowercase, 2+ segments)")
cm = re.search(r"version/code=(\d+)", pre)
if not cm or int(cm.group(1)) < 1:
    errs.append("version/code must be int >= 1")
if "architectures/arm64-v8a=true" not in pre:
    errs.append("preset: no arm64-v8a (device cannot install)")
if "architectures/x86_64=true" not in pre:
    warns.append("preset: x86_64 off (no emulator installs)")
if not os.path.exists(BASE + "/icon.svg"):
    errs.append("icon.svg missing")
else:
    try:
        ET.parse(BASE + "/icon.svg")
    except Exception as e:
        errs.append(f"icon.svg XML: {e}")
if "textures/vram_compression/import_etc2_astc=true" not in proj or "graphics/texture_formats/etc2=true" not in pre:
    warns.append("texture flags: etc2 mismatch project vs preset")
if "window/handheld/orientation=0" not in proj:
    errs.append("project.godot: orientation is not 0 (forced landscape)")

# --- 12. hygiene: secrets, endings, apk ---
for f in sorted(glob.glob(BASE + "/**/*.gd", recursive=True) + [BASE + "/.env", BASE + "/export_presets.cfg"]):
    src = open(f, "rb").read()
    if b"BEGIN PRIVATE KEY" in src or b"RELEASE_PASSWORD" in src or b"api_key" in src:
        errs.append(f"{f}: possible secret committed")
    if b"\r" in src or b"\xef\xbb\xbf" in src:
        errs.append(f"{f}: CRLF or BOM found (must be LF)")
    if not src.endswith(b"\n"):
        warns.append(f"{f}: missing trailing newline")
if glob.glob(BASE + "/build/*.apk"):
    errs.append("build/*.apk committed (must stay gitignored)")

print("WARN:")
for w in warns:
    print(" -", w)
if errs:
    print("CHECK FAILED:")
    for e in errs:
        print(" -", e)
    sys.exit(1)
print("CHECK OK")

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
    declared = set(re.findall(r'\[ext_resource[^\]]*id="([^"]+)"', src))
    for ref in set(re.findall(r'ExtResource\("([^"]+)"', src)):
        if ref not in declared:
            errs.append(f"{f}: ExtResource(\"{ref}\") has no ext_resource declaration")

# --- 1b. every CSG must collide (infinite-fall guard) + floor snap ---
for f, src in TSCN.items():
    if "player.tscn" in f or "enemy.tscn" in f or "hud.tscn" in f or "gurukkal" in f or "main.tscn" in f:
        continue
    for b in re.findall(r'(\[node name="[^"]+" type="CSG(?:Box|Sphere)3D"[^]]*\](?:\n(?!\[node ).*)*)', src):
        nm = re.search(r'name="([^"]+)"', b).group(1)
        if "use_collision = true" in b:
            continue
        # visual-only deco (all dims < 0.5) may stay ghost; solid stuff must collide
        dims = [tuple(float(x) for x in m.group(1).split(",")) for m in re.finditer(r"size = Vector3\(([^)]+)\)", b)]
        if dims and max(max(d) for d in dims) < 0.5:
            continue
        errs.append(f"{f}: CSG '{nm}' lacks use_collision (fall-through)")
for f in [BASE + "/scenes/player.tscn", BASE + "/scenes/enemy.tscn"]:
    if "floor_snap_length" not in open(f).read():
        errs.append(f"{f}: floor_snap_length missing (steps catch)")

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
for key in ["meyppayattu_rep", "bandit_defeat", "marma_bonus", "quest_q01", "quest_q02", "quest_q03", "seva_avg", "sadhana_kalari", "sadhana_temple", "sadhana_forest"]:
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
    curve = []
    for mid, wid in [("mey_02_valinjamarnnu", "none"), ("kol_01_kettukari_strike", "kettukari"), ("kol_02_cheruvadi_head", "cheruvadi")]:
        curve.append(float(moves[mid]["damage"]) * float(weaps[wid]["damage_mult"]))
    if curve != sorted(curve):
        errs.append(f"combat: damage curve not ascending {curve}")
    for i, d in enumerate(curve):
        hits = 120.0 / d
        if hits > 15 or hits < 2:
            warns.append(f"combat: rank{i + 1} hits-to-kill {hits:.1f} outside 2..15")
    if float(moves["mey_02_valinjamarnnu"]["stamina_cost"]) > 100:
        errs.append("combat: rank-1 cost exceeds stamina pool")
except Exception as e:
    warns.append(f"combat sanity skipped: {e}")

# --- 7b. rank-4 earnability: pre-festival one-shots must cover rank 4 ---
try:
    pj = DATA[BASE + "/data/temple_plot.json"]["phases"]
    pre = sum(int(p.get("xp", 0)) for p in pj if p.get("id") != "festival")
    one_shots = 120 + 150 + 200 + pre + 120  # q01+q02+q03 + plot + 2 bandits
    r4 = next(int(r["xp_needed"]) for r in ranks if int(r.get("rank", 0)) == 4)
    if one_shots < r4:
        errs.append(f"economy: one-shot total {one_shots} < rank4 {r4}")
except Exception as e:
    warns.append(f"earnability skipped: {e}")

# --- 7c. gates + cooldowns present in code ---
sg = open(BASE + "/scripts/sadhana.gd").read()
if "COOLDOWN" not in sg or "cooldown_t" not in sg:
    errs.append("sadhana: cooldown missing (spam farm)")
pg = open(BASE + "/scripts/player.gd").read()
if "is_in_temple" not in pg:
    errs.append("player: bell lacks sanctum position check")
eg = open(BASE + "/scripts/enemy_ai.gd").read()
m = re.search(r"@export var speed := ([\d.]+)", eg)
if not m or float(m.group(1)) < 3.0:
    errs.append("enemy: bandit too slow (kiting exploit)")
if "max_hp" not in eg:
    warns.append("enemy: max_hp override missing (TTK math assumes 120)")
qj = DATA.get(BASE + "/data/quests.json", {}).get("quests", [])
for qid in ["q01_first_earth", "q02_market_escort", "q03_aromal_debt"]:
    if qid not in [q.get("id") for q in qj]:
        errs.append(f"quests.json: '{qid}' missing (code pays it)")

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

# --- 8b. sadhana XP table must equal data/sadhana.json sessions ---
sj = DATA.get(BASE + "/data/sadhana.json", {}).get("sessions", {})
sg = open(BASE + "/scripts/sadhana.gd").read()
for k in ["kalari", "temple", "forest"]:
    if k not in sj:
        errs.append(f"sadhana.json: session '{k}' missing")
m = re.search(r'var table := \{ "kalari": (\d+), "temple": (\d+), "forest": (\d+) \}', sg)
if not m:
    errs.append("sadhana.gd: XP table not found")
elif [int(m.group(1)), int(m.group(2)), int(m.group(3))] != [int(sj["kalari"]["xp"]), int(sj["temple"]["xp"]), int(sj["forest"]["xp"])]:
    errs.append("sadhana XP table forked from sadhana.json")

# --- 8c. vama stage XP must equal data/vama.json quests ---
vj = DATA.get(BASE + "/data/vama.json", {}).get("quests", [])
vg = open(BASE + "/scripts/vama.gd").read()
for vid, vxp in [("tattva", 120), ("kula", 150), ("vira", 180)]:
    hit = [q for q in vj if isinstance(q, dict) and q.get("id") == vid]
    if not hit:
        errs.append(f"vama.json: quest '{vid}' missing")
    elif int(hit[0].get("xp", -1)) != vxp:
        errs.append(f"vama.json: quest '{vid}' xp {hit[0].get('xp')} != code {vxp}")
if "_finish(120" not in vg or "_finish(150" not in vg or "_finish(180" not in vg:
    errs.append("vama.gd: stage XP calls changed (keep 120/150/180 with vama.json)")

# --- 8d. ped loops live inside village Ground bounds (x±15, z−15..9) ---
zj = DATA.get(BASE + "/data/kerala-zones.json", {})
for z in zj.get("zones", []):
    for loop_id, pts in z.get("ped_loops", {}).items():
        for pt in pts:
            if not (-15.0 <= float(pt[0]) <= 15.0 and -15.0 <= float(pt[2]) <= 9.0):
                errs.append(f"ped_loops: '{loop_id}' point {pt} off the Ground")
wl_src2 = open(BASE + "/scripts/world_loader.gd").read()
if "PED_CAP" not in wl_src2:
    errs.append("world_loader: ped spawner cap missing")

# --- 8e. radar present: panel + draw script + zone label ---
hts = open(BASE + "/scenes/ui/hud.tscn").read()
for rn in ["RadarPanel", "RadarDraw", "ZoneLabel", "scripts/radar.gd"]:
    if rn not in hts:
        errs.append(f"hud: radar '{rn}' missing")

# --- 8f. heat: 0-3 clamp, guard flag, wired in main + HUD ---
hg = open(BASE + "/scripts/heat.gd").read() if os.path.exists(BASE + "/scripts/heat.gd") else ""
if "mini(3" not in hg:
    errs.append("heat: 0-3 clamp missing")
if "is_guard" not in open(BASE + "/scripts/enemy_ai.gd").read():
    errs.append("heat: guard flag missing on enemy")
if "heat.gd" not in open(BASE + "/scripts/main.gd").read():
    errs.append("heat: not attached in main")
if "HeatLabel" not in open(BASE + "/scenes/ui/hud.tscn").read():
    errs.append("heat: HeatLabel node missing")

# --- 8g. save system: keys written == keys read, wired in main ---
sg2 = open(BASE + "/scripts/save_game.gd").read() if os.path.exists(BASE + "/scripts/save_game.gd") else ""
for token in ["user://kalari_save.cfg", "_recompute_rank", "XP", "never stored"]:
    if token not in sg2:
        warns.append(f"save: '{token}' convention missing")
mg = open(BASE + "/scripts/main.gd").read()
if "save_game.gd" not in mg or "apply_save" not in mg:
    errs.append("save: not wired into boot")
if "retain_data_on_uninstall=true" not in open(BASE + "/export_presets.cfg").read():
    errs.append("save: retain_data_on_uninstall must be true")

# --- 8h. quest stages + escort wiring ---
qj = DATA.get(BASE + "/data/quests.json", {}).get("quests", [])
for q in qj:
    for k in ["id", "stages", "xp"]:
        if k not in q:
            errs.append(f"quests.json: '{q.get('id', '?')}' lacks '{k}'")
qg = open(BASE + "/scripts/quests.gd").read()
for token in ["escort_tick", "mark_q01_done", "pendant", "follow"]:
    if token not in qg:
        errs.append(f"quests.gd: mission-graph '{token}' missing")
pg = open(BASE + "/scripts/ped.gd").read()
if "var follow" not in pg or ".follow =" not in open(BASE + "/scripts/quests.gd").read():
    errs.append("ped.gd/quests.gd: follow-mode wiring missing")

# --- 8i. traffic: cart/boat loops inside bounds, capped ride step ---
for f2, pts in [("Cart", [(4.0, -5.0), (4.0, 5.0)]), ("Boat", [(-12.0, 12.0), (12.0, 12.0)])]:
    for (px, pz) in pts:
        if not (-15.0 <= px <= 15.0 and -15.0 <= pz <= 15.0):
            errs.append(f"traffic: {f2} endpoint off-map")
cb = open(BASE + "/scripts/cart_boat.gd").read()
if "ride_height" not in cb or "_blocked" not in cb:
    errs.append("traffic: cart_boat ride/block logic missing")

# --- 8j. LOD: dressing nodes must carry visibility ranges ---
_dress = ["Grass1", "Grass2", "Grass3", "Grass4", "Grass5", "Reed1", "Reed2", "Reed3", "Reed4", "Cloud1", "Cloud2", "TurmericPile", "GreensPile", "Stone1", "Stone2", "Flower1", "Flower2", "Flower3", "TempleFlag", "MarketGoods1"]
for f2 in [BASE + "/scenes/village.tscn", BASE + "/scenes/school.tscn"]:
    _src2 = open(f2).read()
    for _nm in _dress:
        _m2 = re.search(r'\[node name="' + _nm + r'"[^]]*\](?:\n(?!\[node ).*)*', _src2)
        if _m2 is not None and "visibility_range_end" not in _m2.group(0):
            errs.append(f"{f2}: dressing '{_nm}' lacks visibility range")

# --- 8k. ambience: synth beds + hooks, no binary assets ---
ag = open(BASE + "/scripts/ambience.gd").read() if os.path.exists(BASE + "/scripts/ambience.gd") else ""
for token in ["AudioStreamWAV", "toggle_mute", "func bell", "func thock", "func marma_sting"]:
    if token not in ag:
        errs.append(f"ambience: '{token}' missing")
if "ambience.gd" not in open(BASE + "/scripts/main.gd").read():
    errs.append("ambience: not attached in main")
if "MuteButton" not in open(BASE + "/scenes/ui/hud.tscn").read():
    errs.append("ambience: MuteButton missing")

# --- 8l. dialogue: panel nodes + giver briefings + queue wiring ---
hts2 = open(BASE + "/scenes/ui/hud.tscn").read()
for rn in ["DlgPanel", "DlgName", "DlgText"]:
    if rn not in hts2:
        errs.append(f"hud: dialogue '{rn}' missing")
if "dialogue.gd" not in open(BASE + "/scripts/main.gd").read():
    errs.append("dialogue: not attached in main")
qjd = DATA.get(BASE + "/data/quests.json", {}).get("quests", [])
for q in qjd:
    if "briefing" not in q or len(q["briefing"]) != 3:
        errs.append(f"quests.json: '{q.get('id', '?')}' needs 3-line briefing")

# --- 8m. voice texture: blips + drum wired, mute respected ---
ag2 = open(BASE + "/scripts/ambience.gd").read()
for token in ["func blip", "func drum", "BLIP_PITCH"]:
    if token not in ag2:
        errs.append(f"ambience: '{token}' missing")
dg = open(BASE + "/scripts/dialogue.gd").read()
if "blip(" not in dg:
    errs.append("dialogue: blip hook missing")
if "drum()" not in open(BASE + "/scripts/heat.gd").read():
    errs.append("heat: drum hook missing")

# --- 8n. HUD buttons with negative offsets must be edge-anchored (else off-screen) ---
import re as _re2
for _bm in _re2.finditer(r'\[node name="(\w+)" type="Button"[^\]]*\](?:\n(?!\[node ).*)*', hts2 if 'hts2' in dir() else open(BASE + "/scenes/ui/hud.tscn").read()):
    _bnm = _bm.group(1)
    _bb = _bm.group(0)
    _mt = _re2.search(r"offset_top = (-?[\d.]+)", _bb)
    if _mt and float(_mt.group(1)) < 0 and "anchor_top = 1.0" not in _bb:
        errs.append(f"hud: Button '{_bnm}' has negative top offset without anchor_top=1 (off-screen)")

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

# --- 11b. detail-swap convention: hidden CSG keeps collision, MeshBuilder preloaded ---
wl_src = open(BASE + "/scripts/world_loader.gd").read()
if "_detail_swap" not in wl_src or "MeshBuilder" not in wl_src:
    errs.append("world_loader: detail-swap hook missing")
if "mesh_builder.gd" not in wl_src:
    warns.append("world_loader: MeshBuilder not preloaded (class-cache roulette)")

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

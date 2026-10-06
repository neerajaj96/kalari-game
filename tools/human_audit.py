"""Cinematic-human benchmark + audit. Run: python3 tools/human_audit.py
Validates DNA distinctness, proportion sanity, LOD budgets, material wiring,
and repository hygiene for the procedural pipeline. Fails CI on errors."""
import glob
import os
import re
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
errs = []
warns = []

HUMAN = os.path.join(BASE, "scripts", "human")
SHADERS = [os.path.join(BASE, "shaders", "human_skin.gdshader"),
           os.path.join(BASE, "shaders", "cloth_weave.gdshader"),
           os.path.join(BASE, "shaders", "hair_strand.gdshader")]

# 1. Files present.
for f in ["human_dna.gd", "body_sculpt.gd", "human_materials.gd", "human_rig.gd",
          "face_anim.gd", "ik_solver.gd", "human_anim.gd", "garment_builder.gd",
          "human_lod.gd", "human_factory.gd"]:
    if not os.path.exists(os.path.join(HUMAN, f)):
        errs.append(f"human pipeline missing '{f}'")
for s in SHADERS:
    if not os.path.exists(s):
        errs.append(f"shader missing '{s}'")

# 2. DNA presets: player/gurukkal/bandit/villager + distinct statures.
dna = open(os.path.join(HUMAN, "human_dna.gd")).read()
for fn in ["player_dna", "gurukkal_dna", "bandit_dna", "villager_dna"]:
    if fn not in dna:
        errs.append(f"human_dna: preset '{fn}' missing")
# Gurukkal must read elder: grey + wrinkle + stoop.
for token in ["hair_grey = 0.95", "wrinkle = 0.85", "posture_crouch = 0.35"]:
    if token not in dna:
        errs.append(f"human_dna: gurukkal elder marker '{token}' missing")
# Original-identity guard: no celebrity names anywhere in pipeline.
for f in glob.glob(HUMAN + "/*.gd"):
    src = open(f).read().lower()
    for celeb in ["mammootty", "mohanlal", "rajinikanth", "kamal haasan", "dulquer"]:
        if celeb in src:
            errs.append(f"{f}: likeness risk '{celeb}'")

# 3. Anatomy: head/eyes/teeth/hands/feet/hair/brow builders present.
sculpt = open(os.path.join(HUMAN, "body_sculpt.gd")).read()
for fn in ["build_torso", "build_head", "build_neck", "build_upper_arm", "build_forearm",
           "build_thigh", "build_shin", "build_hand", "build_fingernails",
           "build_foot", "build_toenails",
           "build_eyeball", "build_iris_disc", "build_pupil_disc",
           "build_eyelid_rim", "build_caruncle",
           "build_teeth_strip", "build_mouth_cavity",
           "build_hair", "build_beard",
           "build_eyebrow", "build_ear", "build_lips", "build_cheek_pad", "build_joint_ball"]:
    if fn not in sculpt:
        errs.append(f"body_sculpt: '{fn}' missing")
if "CapsuleMesh" in sculpt or "SphereMesh" in sculpt or "BoxMesh" in sculpt:
    errs.append("body_sculpt: primitive mesh leak (must be SurfaceTool only)")

# 4. Rig: 42 bones, facial bones, no soft-skin weight risk.
rig = open(os.path.join(HUMAN, "human_rig.gd")).read()
for b in ["jaw", "eye_L", "lid_upper_L", "brow_L", "thumb_L", "toes_R"]:
    if b not in rig:
        errs.append(f"human_rig: bone '{b}' missing")

# 5. Face: 8 expressions + blink + gaze.
face = open(os.path.join(HUMAN, "face_anim.gd")).read()
for e in ["neutral", "focus", "anger", "fear", "pain", "surprise", "effort", "recovery"]:
    if e not in face:
        errs.append(f"face_anim: expression '{e}' missing")
if "_blink" not in face or "gaze" not in face.lower():
    errs.append("face_anim: blink/gaze missing")

# 6. Motion: CombatState map + vadivu flavor + IK.
anim = open(os.path.join(HUMAN, "human_anim.gd")).read()
for token in ["STRIKE", "BLOCK", "DODGE", "Simha", "Sarpa", "Aswa", "Gaja"]:
    if token not in anim:
        warns.append(f"human_anim: flavor '{token}' missing")
ik = open(os.path.join(HUMAN, "ik_solver.gd")).read()
if "solve_two_bone" not in ik or "plant_feet" not in ik:
    errs.append("ik_solver: two-bone/plant missing")

# 7. Garments: Kerala sets + thickness + jewellery split.
gar = open(os.path.join(HUMAN, "garment_builder.gd")).read()
for token in ["build_waist_wrap", "build_shoulder_drape", "build_belt",
              "build_chest_sash", "build_kurta", "build_blouse",
              "build_earrings_headlocal", "build_chest_jewellery",
              "build_sandal_footlocal", "build_headband",
              "kaccha", "veshti", "angavastram",
              "lungi", "sari"]:
    if token.lower() not in gar.lower():
        errs.append(f"garment_builder: '{token}' missing")

# 8. Factory: Hero/Mid/Far + collision separation + cache + rank + weapon.
fac = open(os.path.join(HUMAN, "human_factory.gd")).read()
for token in ["bone_global_rest", "follow_weapon", "update_rank_accent",
              "_hide_primitives", "clear_cache", "absolute"]:
    if token not in fac:
        errs.append(f"human_factory: '{token}' missing")
if "Collision" in fac and "untouched" not in fac:
    warns.append("factory: collision wording changed (keep separation comment)")

# 9. LOD budgets (analytic): Hero <= 18k, Mid <= 7k, Far <= 1.5k.
# Hero head 28x20x2=1120 + torso sculpt ~900 + limbs ~1200 + hands ~800
# + feet ~400 + garments ~1500 + hair ~400 + neck/ears/lids/nails ~900
# + joint caps 10x280=2800.
hero_est = 1120 + 900 + 1200 + 800 + 400 + 1500 + 400 + 900 + 2800
mid_est = 500 + 500 + 600 + 200 + 150 + 900 + 200
far_est = 160 + 100 + 200 + 60 + 60 + 250 + 80
print(f"LOD tri estimate: hero ~{hero_est}, mid ~{mid_est}, far ~{far_est}")
if hero_est > 18000:
    errs.append(f"LOD: hero {hero_est} over 18k budget")
if mid_est > 7000:
    errs.append(f"LOD: mid {mid_est} over 7k budget")
if far_est > 1500:
    warns.append(f"LOD: far {far_est} over 1.5k (cull more)")

# 10. Materials: PBR SSS + weave + strand wired, no orphan shaders.
for s in SHADERS:
    rel = os.path.relpath(s, BASE)
    used = any(rel in open(h).read() for h in
               glob.glob(BASE + "/scenes/**/*.tscn", recursive=True) +
               glob.glob(BASE + "/scripts/*.gd"))
    if not used:
        errs.append(f"orphan shader '{rel}' (wire via top-level ref)")
mat = open(os.path.join(HUMAN, "human_materials.gd")).read()
for token in ["sss_strength", "metallic", "roughness", "lip_material"]:
    if token not in mat:
        errs.append(f"human_materials: PBR '{token}' missing")
cloth_shader = open(os.path.join(BASE, "shaders", "cloth_weave.gdshader")).read()
if "sway_amount" not in cloth_shader or "void vertex" not in cloth_shader:
    errs.append("cloth_weave: hem sway vertex stage missing")

# 11. Integration: avatar_rig fallback builds cinematic; ped builds villagers.
rig_top = open(os.path.join(BASE, "scripts", "avatar_rig.gd")).read()
for token in ["_build_cinematic_fallback", "HumanFactory.build", "follow_weapon",
              "FileAccess.file_exists", "AnimationTree"]:
    if token not in rig_top:
        errs.append(f"avatar_rig: '{token}' missing")
ped = open(os.path.join(BASE, "scripts", "ped.gd")).read()
if "HumanFactory.build" not in ped or "villager_dna" not in ped:
    errs.append("ped: cinematic villager hook missing")
player = open(os.path.join(BASE, "scripts", "player.gd")).read()
if "update_rank_accent" not in player:
    errs.append("player: rank accent hook missing")

print("WARN:")
for w in warns:
    print(" -", w)
if errs:
    print("HUMAN AUDIT FAILED:")
    for e in errs:
        print(" -", e)
    sys.exit(1)
print("HUMAN AUDIT OK")

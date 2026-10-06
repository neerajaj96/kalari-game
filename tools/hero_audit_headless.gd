extends SceneTree
# Headless pipeline validation: runs WITHOUT a renderer via
#   godot --headless --path . -s res://tools/hero_audit_headless.gd
# Validates DNA presets, skeleton layout, sculpted-geometry builders and
# material/shader wiring. This is the HEADLESS tier only: it proves the
# pipeline constructs, it NEVER proves visual quality (see
# docs/HERO_RUNTIME_AUDIT_PENDING.md for the PC/Android close-up audit).
# Exit code 0 = constructed, 1 = defect.

func _init() -> void:
	var fails := 0
	fails += _check_dna()
	fails += _check_rig()
	fails += _check_geometry()
	fails += _check_materials()
	if fails == 0:
		print("[HERO_AUDIT_HEADLESS] OK (construction only, NOT a visual pass)")
	else:
		print("[HERO_AUDIT_HEADLESS] FAILED with %d defect(s)" % fails)
	quit(1 if fails > 0 else 0)

func _check_dna() -> int:
	var HumanDNA = load("res://scripts/human/human_dna.gd")
	var bad := 0
	for dna in [HumanDNA.player_dna(), HumanDNA.gurukkal_dna(), HumanDNA.bandit_dna(0), HumanDNA.villager_dna(3)]:
		if dna.stature < 1.4 or dna.stature > 2.0:
			print("[HERO_AUDIT_HEADLESS] bad stature %s" % str(dna.stature))
			bad += 1
		if dna.melanin < 0.0 or dna.melanin > 1.0:
			print("[HERO_AUDIT_HEADLESS] bad melanin")
			bad += 1
	var ages := [HumanDNA.player_dna().age_years, HumanDNA.gurukkal_dna().age_years]
	if not (ages[0] < 30.0 and ages[1] > 55.0):
		print("[HERO_AUDIT_HEADLESS] hero/elder age identity broken")
		bad += 1
	print("[HERO_AUDIT_HEADLESS] dna ok")
	return bad

func _check_rig() -> int:
	var HumanRig = load("res://scripts/human/human_rig.gd")
	var bones: Array = HumanRig.bone_list()
	if bones.size() != 42:
		print("[HERO_AUDIT_HEADLESS] bone count %d != 42" % bones.size())
		return 1
	for b in ["jaw", "eye_L", "lid_upper_L", "brow_L", "thumb_L", "toes_R"]:
		if not (b in bones):
			print("[HERO_AUDIT_HEADLESS] missing bone " + b)
			return 1
	print("[HERO_AUDIT_HEADLESS] rig ok (42 bones incl. face/hands/feet)")
	return 0

func _check_geometry() -> int:
	var HumanDNA = load("res://scripts/human/human_dna.gd")
	var BodySculpt = load("res://scripts/human/body_sculpt.gd")
	var GarmentBuilder = load("res://scripts/human/garment_builder.gd")
	var dna = HumanDNA.player_dna()
	var bad := 0
	var meshes := [
		BodySculpt.build_torso(dna, 0), BodySculpt.build_head(dna, 0),
		BodySculpt.build_neck(dna, 0), BodySculpt.build_hand(dna, 0),
		BodySculpt.build_foot(dna, 0), BodySculpt.build_hair(dna, 0),
		BodySculpt.build_eyeball(0), BodySculpt.build_iris_disc(),
		BodySculpt.build_eyelid_rim(true, 0), BodySculpt.build_ear(dna, 1.0, 0),
		BodySculpt.build_lips(dna, true), BodySculpt.build_cheek_pad(), BodySculpt.build_teeth_strip(),
		GarmentBuilder.build_waist_wrap(dna, 0), GarmentBuilder.build_belt(dna, 0),
		GarmentBuilder.build_chest_sash(dna, 0), GarmentBuilder.build_headband(dna, 0),
	]
	for m in meshes:
		if m == null or (m as ArrayMesh).get_surface_count() < 1:
			print("[HERO_AUDIT_HEADLESS] null/empty mesh")
			bad += 1
	print("[HERO_AUDIT_HEADLESS] geometry ok (%d hero meshes construct)" % meshes.size())
	return bad

func _check_materials() -> int:
	var bad := 0
	for p in ["res://shaders/human_skin.gdshader", "res://shaders/cloth_weave.gdshader", "res://shaders/hair_strand.gdshader"]:
		if not FileAccess.file_exists(p):
			print("[HERO_AUDIT_HEADLESS] missing " + p)
			bad += 1
	# Shader compile is a render-tier concern; existence is the headless contract.
	print("[HERO_AUDIT_HEADLESS] materials ok (shader files present)")
	return bad

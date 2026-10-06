extends RefCounted
# HumanMaterials: shared PBR material cache. Meshes/materials/rigs are
# reused across villagers by DNA hash; per-instance variation rides on
# shader params + bone scale, not duplicate resources.
class_name HumanMaterials

static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache.clear()

static func _key(dna: HumanDNA, kind: String) -> String:
	return "%s_%d_%d" % [kind, dna.seed, dna.garment_set]

static func skin_material(dna: HumanDNA) -> ShaderMaterial:
	var k := "skin_%d_%d_%d_%d_%d_%d" % [int(dna.melanin * 20.0), int(dna.wrinkle * 10.0), int(dna.scar_amount * 10.0), int(dna.skin_mottle * 10.0), int(dna.skin_warm * 10.0), dna.beard_style]
	if _cache.has(k):
		return _cache[k]
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/human_skin.gdshader")
	var base := BodySculpt.skin_tone(dna)
	sm.set_shader_parameter("albedo", Color(base.r, base.g, base.b, 1.0))
	sm.set_shader_parameter("albedo_deep", Color(base.r * 0.55, base.g * 0.52, base.b * 0.50, 1.0))
	sm.set_shader_parameter("melanin", clampf(dna.melanin, 0.0, 1.0))
	sm.set_shader_parameter("age_wrinkle", clampf(dna.wrinkle, 0.0, 1.0))
	sm.set_shader_parameter("scar_amount", clampf(dna.scar_amount, 0.0, 1.0))
	sm.set_shader_parameter("mottle", clampf(dna.skin_mottle, 0.0, 1.0))
	sm.set_shader_parameter("sss_strength", 0.32)
	sm.set_shader_parameter("wrap_light", 0.45)
	sm.set_shader_parameter("pore_strength", 0.4)
	sm.set_shader_parameter("wrinkle_strength", 0.55)
	var stub := 0.0
	if dna.beard_style == 1:
		stub = 0.55
	elif dna.beard_style == 0 and not dna.is_female:
		stub = 0.22
	elif dna.beard_style == 2:
		stub = 0.35
	sm.set_shader_parameter("stubble", clampf(stub, 0.0, 1.0))
	_cache[k] = sm
	return sm

static func iris_material(dna: HumanDNA) -> StandardMaterial3D:
	var k := "iris_%d" % [dna.seed % 4]
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = browns[dna.seed % browns.size()]
	m.roughness = 0.12
	m.metallic_specular = 0.8
	_cache[k] = m
	return m

static func pupil_material() -> StandardMaterial3D:
	if _cache.has("pupil"):
		return _cache["pupil"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.015, 0.015, 1.0)
	m.roughness = 0.08
	_cache["pupil"] = m
	return m

static func cornea_material() -> StandardMaterial3D:
	if _cache.has("cornea"):
		return _cache["cornea"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.96, 0.98, 1.0)
	m.roughness = 0.05
	m.metallic_specular = 0.9
	_cache["cornea"] = m
	return m

static func caruncle_material(dna: HumanDNA) -> StandardMaterial3D:
	var skin := BodySculpt.skin_tone(dna)
	var k := "caruncle_%d_%d" % [int(skin.r * 20.0), int(skin.g * 20.0)]
	if _cache.has(k):
		return _cache[k]
	var skin := BodySculpt.skin_tone(dna)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(clampf(skin.r * 0.75, 0.0, 1.0), clampf(skin.g * 0.42, 0.0, 1.0), clampf(skin.b * 0.40, 0.0, 1.0), 1.0)
	m.roughness = 0.45
	_cache[k] = m
	return m

static func nail_material() -> StandardMaterial3D:
	if _cache.has("nail"):
		return _cache["nail"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.62, 0.52, 1.0)
	m.roughness = 0.32
	m.metallic_specular = 0.4
	_cache["nail"] = m
	return m

static func teeth_material() -> StandardMaterial3D:
	if _cache.has("teeth"):
		return _cache["teeth"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.93, 0.89, 0.80, 1.0)
	m.roughness = 0.28
	_cache["teeth"] = m
	return m

static func mouth_inner_material() -> StandardMaterial3D:
	if _cache.has("mouth_inner"):
		return _cache["mouth_inner"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.12, 0.10, 1.0)
	m.roughness = 0.55
	_cache["mouth_inner"] = m
	return m

static func lip_material(dna: HumanDNA) -> StandardMaterial3D:
	var k := "lip_%d" % [int(dna.lip_full * 5.0) + 10]
	if _cache.has(k):
		return _cache[k]
	var skin := BodySculpt.skin_tone(dna)
	var m := StandardMaterial3D.new()
	# Lips: deeper + redder than skin, lower roughness (moist highlight).
	m.albedo_color = Color(clampf(skin.r * 0.72, 0.0, 1.0), clampf(skin.g * 0.45, 0.0, 1.0), clampf(skin.b * 0.42, 0.0, 1.0), 1.0)
	m.roughness = 0.38
	m.metallic_specular = 0.55
	_cache[k] = m
	return m

static func hair_material(dna: HumanDNA) -> ShaderMaterial:
	var k := "hair_%d" % [int(dna.hair_grey * 10.0)]
	if _cache.has(k):
		return _cache[k]
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/hair_strand.gdshader")
	sm.set_shader_parameter("grey_amount", clampf(dna.hair_grey, 0.0, 1.0))
	_cache[k] = sm
	return sm

static func cloth_material(dna: HumanDNA, accent_border: float = 0.0) -> ShaderMaterial:
	var k := "cloth_%s_%s_%d_%d_%d" % [str(dna.cloth_primary.to_html()), str(dna.cloth_accent.to_html()), int(accent_border * 10.0), int(dna.cloth_wear * 10.0), int(dna.cloth_dirt * 10.0)]
	if _cache.has(k):
		return _cache[k]
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/cloth_weave.gdshader")
	sm.set_shader_parameter("albedo", dna.cloth_primary)
	sm.set_shader_parameter("accent", dna.cloth_accent)
	sm.set_shader_parameter("wear_amount", clampf(dna.cloth_wear, 0.0, 1.0))
	sm.set_shader_parameter("dirt_amount", clampf(dna.cloth_dirt, 0.0, 1.0))
	sm.set_shader_parameter("border_accent", accent_border)
	_cache[k] = sm
	return sm

static func metal_material(tone: Color, rough: float = 0.32) -> StandardMaterial3D:
	var k := "metal_%s" % tone.to_html()
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = tone
	m.metallic = 0.85
	m.roughness = rough
	m.metallic_specular = 0.65
	_cache[k] = m
	return m

static func leather_material() -> StandardMaterial3D:
	if _cache.has("leather"):
		return _cache["leather"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.20, 0.11, 1.0)
	m.roughness = 0.72
	m.metallic_specular = 0.35
	_cache["leather"] = m
	return m

static func wood_material() -> StandardMaterial3D:
	if _cache.has("wood_dark"):
		return _cache["wood_dark"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.23, 0.12, 1.0)
	m.roughness = 0.68
	m.metallic_specular = 0.4
	_cache["wood_dark"] = m
	return m

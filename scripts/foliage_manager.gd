extends RefCounted
# Foliage manager: many instances, very few draw calls. Grass 150 + reeds 30
# + bushes 20 + palms 10 (trunk/crown twin MultiMeshes sharing one transform
# set); the 2 CSG palms stay as collision anchors. Second sway phase via
# duplicated materials so the field doesn't breathe in perfect sync.
class_name FoliageManager

const GRASS_N := 150
const REED_N := 30
const BUSH_N := 20
const PALM_N := 10
# Ksetra grounds (kept far under the same caps): swept courts stay clear,
# planting lives outside Maryada + kulam banks + kavu edge.
const KSETRA_GRASS_N := 60
const KSETRA_REED_N := 12
const KSETRA_BUSH_N := 8

static func setup(world: Node) -> void:
	_setup_grass(world)
	setup_reeds(world)
	_setup_bushes(world)
	setup_palms(world)

static func setup_ksetra(world: Node) -> void:
	# Courtyard verges + tank bank + grove edge; temple courts stay swept bare.
	var grass := BoxMesh.new()
	grass.size = Vector3(0.3, 0.4, 0.3)
	var mat: ShaderMaterial = load("res://shaders/sway_leaf.tres")
	_kmake(world, "KsetraGrass", grass, mat, KSETRA_GRASS_N, 101, 0.2, 0)
	var reed := BoxMesh.new()
	reed.size = Vector3(0.12, 1.0, 0.12)
	_kmake(world, "KsetraReeds", reed, mat, KSETRA_REED_N, 102, 0.5, 1)
	var bush := BoxMesh.new()
	bush.size = Vector3(0.9, 0.55, 0.9)
	_kmake(world, "KsetraBush", bush, mat, KSETRA_BUSH_N, 103, 0.28, 2)

static func _kblocked(x: float, z: float, band: int) -> bool:
	# band 0 verge ring outside Maryada; 1 kulam bank; 2 kavu edge.
	if band == 1:
		return Vector2(x, z).distance_to(Vector2(-13.3, 13.3)) > 7.0
	if band == 2:
		return Vector2(x, z).distance_to(Vector2(-15.0, -15.0)) > 5.0
	var r := Vector2(x, z).length()
	return r < 27.5 or r > 34.0

static func _kmake(world: Node, mm_name: String, mesh: Mesh, mat: Material,
		count: int, seed_off: int, base_y: float, band: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321 + seed_off
	var placed := 0
	var guard := 0
	while placed < count and guard < count * 60:
		guard += 1
		var x := 0.0
		var z := 0.0
		if band == 0:
			var ang := rng.randf_range(0.0, TAU)
			var rad := rng.randf_range(27.5, 34.0)
			x = cos(ang) * rad
			z = sin(ang) * rad
		elif band == 1:
			var ang2 := rng.randf_range(0.0, TAU)
			var rad2 := rng.randf_range(4.0, 7.0)
			x = -13.3 + cos(ang2) * rad2
			z = 13.3 + sin(ang2) * rad2
		else:
			x = rng.randf_range(-19.0, -11.0)
			z = rng.randf_range(-19.0, -11.0)
		if _kblocked(x, z, band):
			continue
		var s := rng.randf_range(0.7, 1.3)
		var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s)), Vector3(x, base_y * s, z))
		mm.set_instance_transform(placed, t)
		placed += 1
	mm.instance_count = placed
	var mmi := MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	mmi.visibility_range_begin = 0.0
	mmi.visibility_range_end = 45.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if mat:
		mmi.material_override = mat
	world.add_child(mmi)

static func _setup_grass(world: Node) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.3, 0.4, 0.3)
	var mat: ShaderMaterial = load("res://shaders/sway_leaf.tres")
	var mat2: ShaderMaterial = null
	if mat:
		mat2 = mat.duplicate()
		mat2.set_shader_parameter("speed", 2.6)
	_make(world, "GrassFieldA", mesh, mat, GRASS_N / 2, 0, 0.2)
	_make(world, "GrassFieldB", mesh, mat2, GRASS_N - GRASS_N / 2, 7, 0.2)

static func setup_reeds(world: Node) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 1.0, 0.12)
	var mat: ShaderMaterial = load("res://shaders/sway_leaf.tres")
	_make(world, "ReedBed", mesh, mat, REED_N, 0, 0.5, true)
	for n in ["Reed1", "Reed2", "Reed3", "Reed4"]:
		var old := world.get_node_or_null(n)
		if old:
			old.visible = false

static func _setup_bushes(world: Node) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.55, 0.9)
	var mat: ShaderMaterial = load("res://shaders/sway_leaf.tres")
	var mat2: ShaderMaterial = null
	if mat:
		mat2 = mat.duplicate()
		mat2.set_shader_parameter("speed", 1.2)
	_make(world, "BushFieldA", mesh, mat, BUSH_N / 2, 31, 0.28)
	_make(world, "BushFieldB", mesh, mat2, BUSH_N - BUSH_N / 2, 43, 0.28)

static func setup_palms(world: Node) -> void:
	# Twin MultiMeshes, one transform set: same seed + same exclusions give
	# trunks and crowns identical footprints (trunk center 2.5, crown 5.0).
	var trunk := BoxMesh.new()
	trunk.size = Vector3(0.35, 5.0, 0.35)
	var crown := BoxMesh.new()
	crown.size = Vector3(2.2, 0.4, 2.2)
	var bark: StandardMaterial3D = load("res://materials/wood.tres")
	var leaf: ShaderMaterial = load("res://shaders/sway_leaf.tres")
	_make(world, "PalmTrunks", trunk, bark, PALM_N, 21, 2.5, false, true)
	_make(world, "PalmCrowns", crown, leaf, PALM_N, 21, 5.0, false, true)

static func _make(world: Node, mm_name: String, mesh: Mesh, mat: Material, count: int, seed_off: int, base_y: float, reeds: bool = false, bank: bool = false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + seed_off
	var placed := 0
	var guard := 0
	while placed < count and guard < count * 40:
		guard += 1
		var x := rng.randf_range(-14.0, 14.0)
		var z := rng.randf_range(-14.0, 8.0) if not reeds else rng.randf_range(8.3, 9.3)
		if bank:
			z = rng.randf_range(9.0, 13.0)
		if _blocked(x, z) or (bank and _palm_blocked(x, z)):
			continue
		var s := rng.randf_range(0.7, 1.3)
		var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s)), Vector3(x, base_y * s, z))
		mm.set_instance_transform(placed, t)
		placed += 1
	mm.instance_count = placed
	var mmi := MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat
	world.add_child(mmi)
	for n in ["Grass1", "Grass2", "Grass3", "Grass4", "Grass5"]:
		var old := world.get_node_or_null(n)
		if old:
			old.visible = false

static func _blocked(x: float, z: float) -> bool:
	# Houses, temple complex, market stalls, paths stay clear.
	if x > -10.0 and x < -6.0 and z > -8.0 and z < -4.0:
		return true
	if x > 6.0 and x < 10.0 and z > -8.0 and z < -4.0:
		return true
	if x > -8.0 and x < 15.0 and z > -17.0 and z < -3.0:
		return true
	if x > -5.0 and x < 5.0 and z > -1.0 and z < 5.0:
		return true
	if absf(x - 4.0) < 1.5 and z > -6.0 and z < 6.0:
		return true
	return false

static func _palm_blocked(x: float, z: float) -> bool:
	# Boat lane stays navigable; the 2 CSG palms keep their footprints.
	if absf(x + 12.0) < 2.5:
		return true
	if Vector2(x, z).distance_to(Vector2(-4.0, 6.0)) < 2.0:
		return true
	if Vector2(x, z).distance_to(Vector2(6.0, 7.0)) < 2.0:
		return true
	return false

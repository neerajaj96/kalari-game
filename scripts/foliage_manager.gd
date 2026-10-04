extends RefCounted
# Foliage manager: many instances, very few draw calls. Two MultiMeshes
# (grass 150, reeds 30) replace the individual CSG tufts; originals are
# hidden (their collision was deco-exempt anyway). Second sway phase via
# a duplicated material so the field doesn't breathe in perfect sync.
class_name FoliageManager

const GRASS_N := 150
const REED_N := 30

static func setup(world: Node) -> void:
	_setup_grass(world)
	setup_reeds(world)

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

static func _make(world: Node, mm_name: String, mesh: Mesh, mat: Material, count: int, seed_off: int, base_y: float, reeds: bool = false) -> void:
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
		if _blocked(x, z):
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

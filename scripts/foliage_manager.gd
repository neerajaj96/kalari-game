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

static var _card_cache := {}

static func _blade_tex() -> ImageTexture:
	if _card_cache.has("blade"):
		return _card_cache["blade"]
	var w := 32
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for b in range(7):
		var bx := rng.randf_range(3.0, 29.0)
		var bw := rng.randf_range(2.0, 4.0)
		var bh := rng.randf_range(30.0, 62.0)
		var lean := rng.randf_range(-6.0, 6.0)
		var shade := rng.randf_range(0.7, 1.05)
		for yy in range(h):
			for xx in range(w):
				var t := float(yy) / float(h)
				var cx := bx + lean * t
				if absf(float(xx) - cx) < bw * (1.0 - t * 0.6) and float(yy) > float(h) - bh:
					img.set_pixel(xx, yy, Color(0.2 * shade, 0.5 * shade, 0.2 * shade, 1.0))
	var tex := ImageTexture.create_from_image(img)
	_card_cache["blade"] = tex
	return tex

static func _leaf_tex() -> ImageTexture:
	if _card_cache.has("fleck"):
		return _card_cache["fleck"]
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for li in range(22):
		var cx := rng.randf_range(8.0, 56.0)
		var cy := rng.randf_range(8.0, 56.0)
		var rx := rng.randf_range(4.0, 9.0)
		var ry := rng.randf_range(3.0, 6.0)
		var rot := rng.randf_range(0.0, TAU)
		var shade := rng.randf_range(0.7, 1.1)
		for yy in range(s):
			for xx in range(s):
				var dx := float(xx) - cx
				var dy := float(yy) - cy
				var lx := dx * cos(rot) + dy * sin(rot)
				var ly := -dx * sin(rot) + dy * cos(rot)
				var e := (lx * lx) / (rx * rx) + (ly * ly) / (ry * ry)
				if e <= 1.0:
					img.set_pixel(xx, yy, Color(0.14 * shade, 0.44 * shade, 0.17 * shade, 1.0))
	var tex2 := ImageTexture.create_from_image(img)
	_card_cache["fleck"] = tex2
	return tex2

static func _cross_quad(w: float, h: float) -> ArrayMesh:
	var key := "cross_%.2f_%.2f" % [w, h]
	if _card_cache.has(key):
		return _card_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w / 2.0
	var hh := h / 2.0
	var quads := [
		[Vector3(-hw, -hh, 0), Vector3(hw, -hh, 0), Vector3(hw, hh, 0), Vector3(-hw, hh, 0)],
		[Vector3(0, -hh, -hw), Vector3(0, -hh, hw), Vector3(0, hh, hw), Vector3(0, hh, -hw)],
	]
	for q in quads:
		var a: Vector3 = q[0]
		var b: Vector3 = q[1]
		var c: Vector3 = q[2]
		var d: Vector3 = q[3]
		st.set_uv(Vector2(0, 1))
		st.add_vertex(a)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(b)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(c)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(a)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(c)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(d)
	st.generate_normals()
	var mesh := st.commit()
	_card_cache[key] = mesh
	return mesh

static func _card_mat(tex: ImageTexture, speed: float) -> ShaderMaterial:
	var base: ShaderMaterial = load("res://shaders/sway_leaf.tres")
	var m := base.duplicate() as ShaderMaterial
	m.set_shader_parameter("use_card", true)
	m.set_shader_parameter("card_tex", tex)
	m.set_shader_parameter("speed", speed)
	return m

static func setup(world: Node) -> void:
	_setup_grass(world)
	setup_reeds(world)
	_setup_bushes(world)
	setup_palms(world)

static func setup_ksetra(world: Node) -> void:
	# Courtyard verges + tank bank + grove edge; temple courts stay swept bare.
	var grass := _cross_quad(0.35, 0.45)
	var mat := _card_mat(_blade_tex(), 1.8)
	_kmake(world, "KsetraGrass", grass, mat, KSETRA_GRASS_N, 101, 0.2, 0)
	var reed := _cross_quad(0.25, 1.0)
	_kmake(world, "KsetraReeds", reed, mat, KSETRA_REED_N, 102, 0.5, 1)
	var bush := _cross_quad(1.0, 0.7)
	var bushmat := _card_mat(_leaf_tex(), 1.8)
	_kmake(world, "KsetraBush", bush, bushmat, KSETRA_BUSH_N, 103, 0.28, 2)

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
	var mesh := _cross_quad(0.35, 0.45)
	var mat := _card_mat(_blade_tex(), 1.8)
	var mat2 := _card_mat(_blade_tex(), 2.6)
	_make(world, "GrassFieldA", mesh, mat, GRASS_N / 2, 0, 0.2)
	_make(world, "GrassFieldB", mesh, mat2, GRASS_N - GRASS_N / 2, 7, 0.2)

static func setup_reeds(world: Node) -> void:
	var mesh := _cross_quad(0.25, 1.0)
	var mat := _card_mat(_blade_tex(), 1.8)
	_make(world, "ReedBed", mesh, mat, REED_N, 0, 0.5, true)
	for n in ["Reed1", "Reed2", "Reed3", "Reed4"]:
		var old := world.get_node_or_null(n)
		if old:
			old.visible = false

static func _setup_bushes(world: Node) -> void:
	var mesh := _cross_quad(1.0, 0.7)
	var mat := _card_mat(_leaf_tex(), 1.8)
	var mat2 := _card_mat(_leaf_tex(), 1.2)
	_make(world, "BushFieldA", mesh, mat, BUSH_N / 2, 31, 0.28)
	_make(world, "BushFieldB", mesh, mat2, BUSH_N - BUSH_N / 2, 43, 0.28)

static func setup_palms(world: Node) -> void:
	# Twin MultiMeshes, one transform set: same seed + same exclusions give
	# trunks and crowns identical footprints (trunk center 2.5, crown 5.0).
	var trunk := BoxMesh.new()
	trunk.size = Vector3(0.35, 5.0, 0.35)
	var bark: StandardMaterial3D = load("res://materials/wood.tres")
	var leaf := _card_mat(_leaf_tex(), 1.8)
	var crown := _cross_quad(2.4, 1.0)
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

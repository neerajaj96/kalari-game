extends Node3D
# World loader: school <-> village. Keeps XP persistent via group call.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const FoliageManager = preload("res://scripts/foliage_manager.gd")

const SCHOOL := "res://scenes/school.tscn"
const VILLAGE := "res://scenes/village.tscn"
const KSETRA := "res://scenes/ksetra.tscn"

var current: Node = null
var school_path := SCHOOL
var village_path := VILLAGE
var ksetra_path := KSETRA
# Spawn points verified over solid floor in each scene.
var school_spawn := Vector3(0, 1, 0)
var village_spawn := Vector3(0, 1, 4)
var ksetra_spawn := Vector3(18, 1, 0)

func _ready() -> void:
	_resolve_zones()
	load_world(school_path)

func _resolve_zones() -> void:
	# Single source: data/kerala-zones.json; consts are fallback.
	var f := FileAccess.open("res://data/kerala-zones.json", FileAccess.READ)
	if f == null:
		return
	var j = JSON.parse_string(f.get_as_text())
	if not (j is Dictionary):
		return
	for z in j.get("zones", []):
		if z.get("id") == "school_kuzhi" and z.get("scene", "") != "":
			school_path = str(z["scene"])
		elif z.get("id") == "village_chirakkal" and z.get("scene", "") != "":
			village_path = str(z["scene"])
		elif z.get("id") == "ksetra_vishnu" and z.get("scene", "") != "":
			ksetra_path = str(z["scene"])

func load_world(path: String) -> void:
	if current != null:
		remove_child(current)
		current.queue_free()
		current = null
	var ps: PackedScene = load(path)
	if ps == null:
		push_error("world missing: " + path)
		return
	current = ps.instantiate()
	add_child(current)
	_detail_swap(current)
	if path == village_path:
		FoliageManager.setup(current)
	var game1 = get_tree().get_first_node_in_group("game")
	if game1 and game1.get("shadows_on") == false:
		var sun1 := current.get_node_or_null("Sun") as DirectionalLight3D
		if sun1:
			sun1.shadow_enabled = false
	var game0 = get_tree().get_first_node_in_group("game")
	if game0 and game0.get("save") != null and game0.save.has_method("save_game"):
		game0.save.save_game()
	_spawn_peds(path)
	# Fresh world, fresh flags: stale zone state never crosses worlds.
	# An active breath session ends at the border (place changed its meaning).
	var game = get_tree().get_first_node_in_group("game")
	if game:
		if game.get("sadhana") != null:
			if game.sadhana.has_method("set_zone"):
				game.sadhana.set_zone(false, false)
			if game.sadhana.get("active") == true and game.sadhana.has_method("stop"):
				game.sadhana.stop()
				if game.get("hud") != null:
					game.hud.say("Session released at the border.")
	_place_player()

const PED_SCENE := "res://scenes/ped.tscn"
const PED_CAP := 6
const PED_DESPAWN := 25.0
var _topup_t := 0.0

func _spawn_peds(path: String) -> void:
	# Ambient villagers for the village only; the pit stays sacred-empty.
	if path != village_path:
		return
	var loops := _ped_loops()
	if loops.is_empty():
		return
	var ps: PackedScene = load(PED_SCENE)
	if ps == null:
		push_warning("ped.tscn missing, streets stay empty")
		return
	var names := loops.keys()
	for i in range(mini(PED_CAP, 6)):
		var ped := ps.instantiate()
		ped.add_to_group("ped")
		current.add_child(ped)
		var pts: Array = loops[names[i % names.size()]]
		var verts: Array = []
		for pt in pts:
			verts.append(Vector3(float(pt[0]), float(pt[1]), float(pt[2])))
		ped.loop = verts
		ped.position = verts[0] + Vector3(0, 1.0, 0)
		ped.wp = i % verts.size()

func _ped_loops() -> Dictionary:
	var f := FileAccess.open("res://data/kerala-zones.json", FileAccess.READ)
	if f == null:
		return {}
	var j = JSON.parse_string(f.get_as_text())
	if not (j is Dictionary):
		return {}
	for z in j.get("zones", []):
		if z.get("id") == "village_chirakkal":
			return z.get("ped_loops", {})
	return {}

func _top_up_peds() -> void:
	# Refill to cap at loop starts (OW7 streaming will take over later).
	var alive := 0
	for ped in get_tree().get_nodes_in_group("ped"):
		if is_instance_valid(ped):
			alive += 1
	if alive >= PED_CAP or current == null:
		return
	var loops := _ped_loops()
	if loops.is_empty():
		return
	var ps: PackedScene = load(PED_SCENE)
	if ps == null:
		return
	var names := loops.keys()
	var start := randi() % names.size()
	for i in range(PED_CAP - alive):
		var ped := ps.instantiate()
		ped.add_to_group("ped")
		current.add_child(ped)
		var pts: Array = loops[names[(start + i) % names.size()]]
		var verts: Array = []
		for pt in pts:
			verts.append(Vector3(float(pt[0]), float(pt[1]), float(pt[2])))
		ped.loop = verts
		ped.position = verts[0] + Vector3(0, 1.0, 0)
		ped.wp = 0

func _process(_delta: float) -> void:
	# Despawn peds far from camera; top up back to cap at loop starts.
	if current == null:
		return
	var cam = get_tree().get_first_node_in_group("main_camera")
	if cam == null:
		return
	for ped in get_tree().get_nodes_in_group("ped"):
		if is_instance_valid(ped) and ped.global_position.distance_to(cam.global_position) > PED_DESPAWN:
			ped.queue_free()
	_topup_t += _delta
	if _topup_t >= 20.0:
		_topup_t = 0.0
		_top_up_peds()

func _place_player() -> void:	# Player persists across worlds; seat it on this world's spawn.
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	if current != null and "School" in str(current.name):
		p.position = school_spawn
	elif current != null and "Ksetra" in str(current.name):
		p.position = ksetra_spawn
	else:
		p.position = village_spawn
	p.velocity = Vector3.ZERO

func go_school() -> void:
	load_world(school_path)

func go_village() -> void:
	load_world(village_path)

func go_ksetra() -> void:
	load_world(ksetra_path)

func _detail_swap(world: Node) -> void:
	# Showcase nodes get generated-mesh visuals; the hidden CSG original
	# keeps collision (CSG collision stays active while hidden).
	var jobs := [
		["TempleComplex/RoofMain", "pyramid", [4.6, 4.6, 1.2, 0.65], -0.125],
		["TempleComplex/Shikhara", "stepped", [1.6, 5, 0.17], -0.4],
		["TempleComplex/Kalasham", "lathe", [], -0.22],
		["Ground", "ground", [30.0, 24.0, 0.15, 8.0], 0.1],
		["House1Roof", "pyramid", [4.6, 4.6, 0.9, 0.4], -0.15],
		["House2Roof", "pyramid", [4.6, 4.6, 0.9, 0.4], -0.15],
	]
	for j in jobs:
		var orig := world.get_node_or_null(j[0]) as CSGShape3D
		if orig == null:
			continue
		var mesh: ArrayMesh = null
		if j[1] == "pyramid":
			mesh = MeshBuilder.pyramid_roof(j[2][0], j[2][1], j[2][2], j[2][3])
		elif j[1] == "stepped":
			mesh = MeshBuilder.stepped_shikhara(j[2][0], j[2][1], j[2][2])
		elif j[1] == "lathe":
			mesh = MeshBuilder.lathed_kalasham()
		elif j[1] == "ground":
			mesh = MeshBuilder.noisy_ground(j[2][0], j[2][1], j[2][2], j[2][3])
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = str(j[0]).split("/")[-1] + "_visual"
		mi.mesh = mesh
		mi.material_override = orig.material
		mi.position = orig.position + Vector3(0, j[3], 0)
		mi.rotation = orig.rotation
		# LOD: hero visuals cull past 45m with fade; collision originals stay.
		mi.visibility_range_begin = 0.0
		mi.visibility_range_end = 45.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# LOD follows the hidden original so dressing culls as one.
		if "visibility_range_end" in orig:
			mi.visibility_range_begin = orig.visibility_range_begin
			mi.visibility_range_end = orig.visibility_range_end
			mi.visibility_range_fade_mode = orig.visibility_range_fade_mode
		orig.visible = false
		orig.get_parent().add_child(mi)

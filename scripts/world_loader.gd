extends Node3D
# World loader: school <-> village. Keeps XP persistent via group call.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")

const SCHOOL := "res://scenes/school.tscn"
const VILLAGE := "res://scenes/village.tscn"

var current: Node = null
var school_path := SCHOOL
var village_path := VILLAGE
# Spawn points verified over solid floor in each scene.
var school_spawn := Vector3(0, 1, 0)
var village_spawn := Vector3(0, 1, 4)

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

func _place_player() -> void:	# Player persists across worlds; seat it on this world's spawn.
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	if current != null and "School" in str(current.name):
		p.position = school_spawn
	else:
		p.position = village_spawn
	p.velocity = Vector3.ZERO

func go_school() -> void:
	load_world(school_path)

func go_village() -> void:
	load_world(village_path)

func _detail_swap(world: Node) -> void:
	# Showcase nodes get generated-mesh visuals; the hidden CSG original
	# keeps collision (CSG collision stays active while hidden).
	var jobs := [
		["TempleComplex/RoofMain", "pyramid", [4.6, 4.6, 1.2, 0.5], -0.125],
		["TempleComplex/Shikhara", "stepped", [1.6, 3, 0.27], -0.4],
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
		orig.visible = false
		orig.get_parent().add_child(mi)

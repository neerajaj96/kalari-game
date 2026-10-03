extends Node3D
# World loader: school <-> village. Keeps XP persistent via group call.

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

func _place_player() -> void:
	# Player persists across worlds; seat it on this world's spawn.
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

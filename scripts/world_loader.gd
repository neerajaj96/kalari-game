extends Node3D
# World loader: school <-> village. Keeps XP persistent via group call.

const SCHOOL := "res://scenes/school.tscn"
const VILLAGE := "res://scenes/village.tscn"

var current: Node = null
var school_path := SCHOOL
var village_path := VILLAGE

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

func go_school() -> void:
	load_world(school_path)

func go_village() -> void:
	load_world(village_path)

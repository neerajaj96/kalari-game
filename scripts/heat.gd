extends Node
# Kolathiri heat 0-3: open kills +1, marma kills +2. Guards hunt while hot.
# Exits: seva completion clears, or 5 calm minutes decay. Guard kills pay
# no XP/quest (death spiral would never end); heat caps at 3.
class_name Heat

var heat := 0
var _calm := 0.0

const GUARD_POSTS := [Vector3(14, 1, 2), Vector3(9, 1, -6), Vector3(3, 1, 5)]

func add(n: int) -> void:
	var before := heat
	heat = mini(3, heat + n)
	_calm = 0.0
	if heat > before:
		_spawn_guards()
		_say("Kolathiri guards move in! Heat %d/3." % heat)

func clear_why(msg: String) -> void:
	if heat <= 0:
		return
	heat = 0
	_say(msg + " Heat cleared.")

func _process(delta: float) -> void:
	if heat <= 0:
		return
	_calm += delta
	if _calm >= 60.0:
		_calm = 0.0
		heat -= 1
		if heat <= 0:
			_say("The village forgets. Heat cleared.")

func _spawn_guards() -> void:
	var want := heat
	var have := 0
	for b in get_tree().get_nodes_in_group("bandit"):
		if is_instance_valid(b) and b.get("is_guard") == true:
			have += 1
	if have >= want:
		return
	var ps: PackedScene = load("res://scenes/enemy.tscn")
	if ps == null:
		return
	var world = get_tree().get_first_node_in_group("world")
	if world == null or world.get("current") == null:
		return
	if "School" in str(world.current.name):
		return # pit stays clean; heat is a village affair
	for i in range(want - have):
		var g = ps.instantiate()
		g.set("is_guard", true)
		world.current.add_child(g)
		g.global_position = GUARD_POSTS[(have + i) % GUARD_POSTS.size()]
		var sash := g.get_node_or_null("Sash") as MeshInstance3D
		if sash:
			sash.material_override = load("res://materials/leaf.tres")
		g.scale = Vector3(1.1, 1.1, 1.1)

func _say(msg: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say(msg)

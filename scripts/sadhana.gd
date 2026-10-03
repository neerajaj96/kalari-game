extends Node
# Sadhana: silent breath counting. Breathe button = half-breath, 11 breaths = session.
# Place variants: school pit (pranayama/stamina), sanctum door (upasana/marma),
# hermitage (dhyana/both, needs Rank 2). Symbolic, with safety text.
class_name Sadhana

var active := false
var kind := "kalari"
var count := 0 # half-breaths; 22 = done
var half := false # false=inhale next, true=exhale next

const TARGET := 22

var cooldown_t := 0.0
const COOLDOWN := 45.0

func _process(delta: float) -> void:
	if cooldown_t > 0.0:
		cooldown_t = maxf(0.0, cooldown_t - delta)

func start(place: String) -> String:
	if active:
		return "Session ongoing: %d/11 breaths. Breathe." % (count / 2)
	if place == "":
		return "No ground here: stand in the pit, at the door, or on the mat."
	if cooldown_t > 0.0:
		return "Breath settles... rest %ds before next session." % int(cooldown_t)
	var game = get_tree().get_first_node_in_group("game")
	var rank := 1
	if game and game.get("xp_rank") != null:
		rank = game.xp_rank.rank
	if place == "forest" and rank < 2:
		return "Forest dhyana needs Rank 2 (Meithari-cleared). Train first."
	active = true
	kind = place
	count = 0
	half = false
	var names := { "kalari": "Kalari Pranayama", "temple": "Bhadrakali Upasana", "forest": "Forest Dhyana" }
	return "%s: 11 silent breaths. Tap Breathe in, out, steady. Stop if dizzy." % names.get(place, "Sadhana")

func tap() -> String:
	if not active:
		return "Start Sadhana first (Sadhana button)."
	count += 1
	half = not half
	if count >= TARGET:
		return _complete()
	var phase := "in..." if not half else "out..."
	return "%s breath %d/11" % [phase, count / 2 + 1]

func stop() -> String:
	if not active:
		return ""
	active = false
	return "Session released. (%d/11 done)" % (count / 2)

func _complete() -> String:
	active = false
	cooldown_t = COOLDOWN
	var table := { "kalari": 30, "temple": 50, "forest": 80 }
	var xp_gain: int = int(table.get(kind, 30))
	var game = get_tree().get_first_node_in_group("game")
	if game and game.get("xp_rank") != null:
		var up: bool = game.xp_rank.add_xp(xp_gain)
		if up and game.get("hud") != null:
			game.hud.say("Rank up! %s" % game.xp_rank.title())
	# Stamina blessing for kalari/forest kinds; marma eye for temple/forest.
	var p = get_tree().get_first_node_in_group("player")
	if kind in ["kalari", "forest"] and p and p.has_method("add_buff"):
		p.add_buff("regen", 1.25, 300.0)
	if kind in ["temple", "forest"] and p and p.has_method("add_buff"):
		p.add_buff("marma", 1.1, 300.0)
	if kind in ["kalari", "forest"] and p and p.get("combat") != null:
		p.combat.stamina = 100.0
	var names := { "kalari": "Pranayama", "temple": "Upasana", "forest": "Dhyana" }
	var done_msg := "%s complete (+%d XP). Steady breath, steady hand." % [names.get(kind, ""), xp_gain]
	var game2 = get_tree().get_first_node_in_group("game")
	if kind == "forest" and game2 and game2.get("vama") != null and game2.vama.has_method("on_forest_dhyana"):
		game2.vama.on_forest_dhyana()
	return done_msg

func place_of_player() -> String:
	# Hermitage flag set by zone; sanctum proximity by trigger area handled via last_zone.
	if _forest:
		return "forest"
	if _temple:
		return "temple"
	var w = get_tree().get_first_node_in_group("world")
	if w and w.get("current") != null and "School" in str(w.current.name):
		return "kalari"
	return ""

var _forest := false
var _temple := false

func set_zone(forest: bool, temple: bool) -> void:
	_forest = forest
	_temple = temple

func is_in_forest() -> bool:
	return _forest

func is_in_temple() -> bool:
	return _temple

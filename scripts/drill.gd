extends Node
# Kalari drill mode: Gurukkal calls Strike/Block/Dodge, 3s windows.
# Clean hits score reps; 5 clean reps = +25 XP + praise. Anywhere, pit-flavored.
class_name Drill

var active := false
var call := ""
var reps := 0
var window_t := 0.0
var _t := 0.0

const CALLS := ["strike", "block", "dodge"]
const WINDOW := 3.0
const LINES := {
	"strike": "Gurukkal: Strike! (Attack)",
	"block": "Gurukkal: Guard! (Block)",
	"dodge": "Gurukkal: Slip! (Dodge)",
}
const PRAISE := ["Clean! Again.", "Good hips.", "Breath leads!", "The pit approves.", "Sharp as monsoon rain."]

func toggle() -> String:
	active = not active
	if active:
		reps = 0
		_call()
		return "Drill on. Answer the calls."
	_say("Drill off. Rest.")
	return "Drill off."

func _call() -> void:
	call = CALLS[randi() % CALLS.size()]
	window_t = WINDOW
	_say(LINES[call])

func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	if _t < 0.2:
		return
	_t = 0.0
	window_t -= 0.2
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.get("combat") == null:
		return
	var st: int = p.combat.state
	# Strike flashes past the 5Hz sampler: latch via cooldown as well as pose.
	var struck := st == 2 or (call == "strike" and p.combat.strike_cd > 0.3)
	var hit := (call == "strike" and struck) or (call == "block" and st == 3) or (call == "dodge" and st == 4)
	if hit:
		reps += 1
		if reps % 5 == 0:
			var game = get_tree().get_first_node_in_group("game")
			if game and game.get("xp_rank") != null and game.xp_rank.has_method("add_xp"):
				game.xp_rank.add_xp(25)
			_say(PRAISE[randi() % PRAISE.size()] + " (+25 XP)")
			_call()
		else:
			_say(PRAISE[randi() % PRAISE.size()] + " (%d/5)" % (reps % 5))
			_call()
	elif window_t <= 0.0:
		_say("Too slow. " + LINES[call])
		_call()

func _say(msg: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say(msg)

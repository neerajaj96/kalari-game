extends Node
# Kalari drill mode: Gurukkal calls Strike/Block/Dodge, 3s windows.
# Clean hits score reps; 5 clean reps = +25 XP + praise. Anywhere, pit-flavored.
class_name Drill

const CombatState = preload("res://scripts/combat_state.gd")

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

var _last_call := ""

func _call() -> void:
	# Uniform among the calls that AREN'T the last one (no predictable ping-pong).
	var pool: Array = CALLS.filter(func(c: String) -> bool: return c != _last_call)
	call = pool[randi() % pool.size()] if not pool.is_empty() else CALLS[randi() % CALLS.size()]
	_last_call = call
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
	# Strike outlives the 5Hz sampler: latch via cooldown for the full pose
	# life (0.45s cd down to the 0.15s settle), not just its first half.
	var struck := st == CombatState.S.STRIKE or (call == "strike" and p.combat.strike_cd > 0.15)
	var hit := (call == "strike" and struck) or (call == "block" and st == CombatState.S.BLOCK) or (call == "dodge" and st == CombatState.S.DODGE)
	if hit:
		reps += 1
		if reps % 5 == 0:
			var game = get_tree().get_first_node_in_group("game")
			if game and game.get("xp_rank") != null and game.xp_rank.has_method("add_xp"):
				var up: bool = game.xp_rank.add_xp(25)
				if up and game.get("audio") != null and game.audio.has_method("fanfare"):
					game.audio.fanfare()
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
	var game = get_tree().get_first_node_in_group("game")
	if game and game.get("audio") != null and game.audio.has_method("blip"):
		game.audio.blip("Gurukkal")

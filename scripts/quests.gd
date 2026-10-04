extends Node
# Mission graph: offered -> active -> done | failed -> offered (retry free).
# q01 reps, q02 Kunjiraman escort (marma-kill fails honour), q03 pair hunt.

var quests: Array = []
var kills: int = 0
var reps: int = 0
var q02_done := false
var q03_done := false
var _shamed := false
var stage := {"q01": "offered", "q02": "offered", "q03": "offered"}
var _pendant = null

const GIVER := {
	"q01": "Gurukkal",
	"q02": "Unniyarcha",
	"q03": "Aromal",
}

func _ready() -> void:
	var f := FileAccess.open("res://data/quests.json", FileAccess.READ)
	if f == null:
		return
	var j = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		quests = j.get("quests", [])

func add_kill(marma: bool = false) -> int:
	kills += 1
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("xp_rank") == null or not game.xp_rank.has_method("add_xp"):
		return kills
	if kills >= 1 and not q02_done and not marma:
		q02_done = true
		stage["q02"] = "done"
		_dismiss_pendant()
		game.xp_rank.add_xp(150)
		_say("Unniyarcha: Openly done, like a Chekavar. (+150 XP)")
	elif kills >= 1 and not q02_done and marma:
		stage["q02"] = "failed"
		if not _shamed:
			_shamed = true
			_say("Unniyarcha turns away: hidden knife shames the escort. Walk with me again — openly this time.")
		else:
			_say("q02 failed honour. Escort again: one open kill.")
		stage["q02"] = "offered"
	if kills >= 2 and not q03_done:
		q03_done = true
		stage["q03"] = "done"
		game.xp_rank.add_xp(200)
		_say("Aromal: Debt cleared. (+200 XP) Return to the Gurukkal in the pit.")
	return kills

func add_reps(n: int = 1) -> int:
	reps += n
	return reps

func escort_tick() -> void:
	# Called from _process: keep Kunjiraman pendant near the player in village.
	var game = get_tree().get_first_node_in_group("game")
	if game == null:
		return
	if q02_done:
		_dismiss_pendant()
		return
	var w = get_tree().get_first_node_in_group("world")
	if w == null or w.get("current") == null:
		return
	if "Village" not in str(w.current.name):
		_dismiss_pendant()
		return
	if _pendant != null and is_instance_valid(_pendant):
		return
	var ps: PackedScene = load("res://scenes/ped.tscn")
	if ps == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_pendant = ps.instantiate()
	w.current.add_child(_pendant)
	_pendant.global_position = player.global_position + Vector3(2, 1, 2)
	_pendant.loop = []
	_pendant.follow = player
	_pendant.chatter = ["Stay close...", "Is that a bandit?!", "Unniyarcha sent you? Good."]
	stage["q02"] = "active"
	_say("Unniyarcha: Walk with Kunjiraman. One open kill — no hidden knife.")

func _dismiss_pendant() -> void:
	if _pendant != null and is_instance_valid(_pendant):
		_pendant.queue_free()
	_pendant = null

func status() -> String:
	var bits := []
	bits.append("q01[%s] reps %d/5" % [stage.get("q01", "?"), mini(reps, 5)])
	bits.append("q02[%s] kills %d" % [stage.get("q02", "?"), kills])
	bits.append("q03[%s]" % [stage.get("q03", "?")])
	return "Quests: " + " · ".join(bits)

func mark_q01_done() -> void:
	stage["q01"] = "done"

func _process(_delta: float) -> void:
	escort_tick()

func _say(msg: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say(msg)

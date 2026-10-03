extends Node
# Quest state: q01 reps, q02/q03 kill bonuses (open kills only — marma shames the escort).

var quests: Array = []
var kills: int = 0
var reps: int = 0
var q02_done := false
var q03_done := false

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
	if game == null or game.get("xp_rank") == null:
		return kills
	if kills >= 1 and not q02_done and not marma:
		q02_done = true
		game.xp_rank.add_xp(150)
		_say("Quest q02 done openly (+150 XP). No hidden knife — Unniyarcha nods.")
	elif kills >= 1 and not q02_done and marma:
		_say("Back-stab pays marma XP, but q02 needs an open kill.")
	if kills >= 2 and not q03_done:
		q03_done = true
		game.xp_rank.add_xp(200)
		_say("Quest q03 done (+200 XP). Return to the Gurukkal in the pit.")
	return kills

func add_reps(n: int = 1) -> int:
	reps += n
	return reps

func _say(msg: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say(msg)

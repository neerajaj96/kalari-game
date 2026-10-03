extends Node
# Quest state: 3 slice quests from data/quests.json. Kill counting via enemy death signal.

var quests: Array = []
var kills: int = 0
var reps: int = 0

func _ready() -> void:
	var f := FileAccess.open("res://data/quests.json", FileAccess.READ)
	if f == null:
		return
	var j = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		quests = j.get("quests", [])

func add_kill() -> int:
	kills += 1
	return kills

func add_reps(n: int = 1) -> int:
	reps += n
	return reps

extends Node
# Gurukkal rank + XP. Data-driven from data/gurukkal_ranks.json.
class_name XPRank

var xp: int = 0
var rank: int = 1
var ranks: Array = []
var xp_sources: Dictionary = {}

func _ready() -> void:
	load_data()

func load_data() -> void:
	var f := FileAccess.open("res://data/gurukkal_ranks.json", FileAccess.READ)
	if f == null:
		push_warning("gurukkal_ranks.json missing, using defaults")
		ranks = [{ "rank": 1, "title": "Vidhyarthi", "xp_needed": 0 }, { "rank": 2, "title": "Meithari", "xp_needed": 300 }, { "rank": 3, "title": "Kolthari", "xp_needed": 800 }]
		return
	var j = JSON.parse_string(f.get_as_text())
	if not (j is Dictionary):
		push_warning("gurukkal_ranks.json malformed, using defaults")
		ranks = [{ "rank": 1, "title": "Vidhyarthi", "xp_needed": 0 }, { "rank": 2, "title": "Meithari", "xp_needed": 300 }, { "rank": 3, "title": "Kolthari", "xp_needed": 800 }]
		return
	ranks = []
	xp_sources = j.get("xp_sources", {})
	for r in j.get("ranks", []):
		if r is Dictionary and r.has("rank") and r.has("xp_needed") and r.has("title"):
			ranks.append(r)
		else:
			push_warning("gurukkal_ranks: skipping malformed rank entry")
	if ranks.is_empty():
		push_warning("gurukkal_ranks.json empty, using defaults")
		ranks = [{ "rank": 1, "title": "Vidhyarthi", "xp_needed": 0 }, { "rank": 2, "title": "Meithari", "xp_needed": 300 }, { "rank": 3, "title": "Kolthari", "xp_needed": 800 }]

func add_xp(amount: int) -> bool:
	xp += amount
	var up := false
	for r in ranks:
		if xp >= int(r["xp_needed"]) and int(r["rank"]) > rank:
			rank = int(r["rank"])
			up = true
	return up

func title() -> String:
	for r in ranks:
		if int(r["rank"]) == rank:
			return str(r["title"])
	return "Vidhyarthi"

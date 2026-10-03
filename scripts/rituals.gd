extends Node
# Sevaka ritual loop: FETCH (MarketZone) -> OFFER (SanctumTrigger zone, bell timing) -> XP.
# Slots cycle usha->pantheeradi->ucha->deeparadhana->athazha from data/nitya.json.
class_name Rituals

var slots: Array = []
var idx := 0
var phase := "IDLE" # IDLE, FETCH, OFFER
var window_t := 0.0

const WINDOW := 6.0

func _ready() -> void:
	var f := FileAccess.open("res://data/nitya.json", FileAccess.READ)
	if f == null:
		return
	var j = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		slots = j.get("slots", [])

func current() -> Dictionary:
	if slots.is_empty():
		return {}
	return slots[idx % slots.size()]

func start() -> String:
	if phase != "IDLE" or slots.is_empty():
		return "Finish current seva first."
	phase = "FETCH"
	var c: Dictionary = current()
	var hint := ""
	var w = get_tree().get_first_node_in_group("world")
	if w != null and w.get("current") != null and "School" in str(w.current.name):
		hint = " (market is in the Village — travel first)"
	return "%s: bring %s from market stall, then come to the temple door.%s" % [c.get("name", "Seva"), c.get("fetch", "flowers"), hint]

func on_market_zone() -> String:
	if phase != "FETCH":
		return ""
	phase = "OFFER"
	window_t = WINDOW
	return "Got %s. Go to the sanctum door and press Attack as bell within %ds." % [current().get("fetch", "flowers"), int(WINDOW)]

func on_sanctum_zone() -> String:
	if phase != "OFFER":
		return ""
	return "Ring now! (Attack)"

func on_bell() -> String:
	# Called from player strike: counts as bell ring if in OFFER window.
	if phase != "OFFER":
		return ""
	return _complete()

func _complete() -> String:
	var c: Dictionary = current()
	var up := false
	var game = get_tree().get_first_node_in_group("game")
	if game and game.get("xp_rank") != null:
		up = game.xp_rank.add_xp(int(c.get("xp", 40)))
		if up and game.get("hud") != null:
			game.hud.say("Rank up! %s" % game.xp_rank.title())
	phase = "IDLE"
	idx += 1
	var nxt := "..."
	if not slots.is_empty():
		nxt = str(slots[idx % slots.size()].get("name", "?"))
	return "%s done (+%d XP). Next: %s." % [c.get("name", "Seva"), int(c.get("xp", 40)), nxt]

func _process(delta: float) -> void:
	if phase == "OFFER":
		window_t -= delta
		if window_t <= 0.0:
			phase = "FETCH"
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("say"):
				hud.say("Bell missed. Fetch again from market.")

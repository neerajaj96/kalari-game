extends Area3D
# Sanctum trigger: explains tantri-only rule when the sevaka approaches.
# No entry: StaticBody barrier blocks; this Area only teaches via i-tab text.

@export var tab_title := "Srikovil — only Tantri and Melshanti enter"
@export var tab_body := "The sanctum is the deity's head (garbha = head). After prana-pratishtha, only the Tantri (ritual authority) and Melshanti (chief priest) cross the sopanam. You serve from Namaskara Mandapam: flowers, ghee, guard duty. Dwarapalakas (door guardians) enforce it."

var _shown := false
var _dwell := 0.0

func _ready() -> void:
	body_entered.connect(_on_body)
	body_exited.connect(_on_exit)

func _on_exit(b: Node) -> void:
	if b.is_in_group("player"):
		var game = get_tree().get_first_node_in_group("game")
		if game and game.get("sadhana") != null and game.sadhana.has_method("set_zone") and game.sadhana.has_method("is_in_forest"):
			game.sadhana.set_zone(game.sadhana.is_in_forest(), false)

func _on_body(b: Node) -> void:
	if b.is_in_group("player"):
		var game = get_tree().get_first_node_in_group("game")
		var rmsg := ""
		if game and game.get("rituals") != null and game.rituals.has_method("on_sanctum_zone"):
			rmsg = game.rituals.on_sanctum_zone()
		if game and game.get("sadhana") != null and game.sadhana.has_method("set_zone") and game.sadhana.has_method("is_in_forest"):
			game.sadhana.set_zone(game.sadhana.is_in_forest(), true)
		if game and game.get("plot") != null and game.plot.has_method("on_visit"):
			game.plot.on_visit("sanctum")
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("say"):
			if rmsg != "":
				hud.say(rmsg)
				return
			if not _shown:
				_shown = true
				_dwell = 0.0
				hud.say(tab_title + " — " + tab_body)

func _process(delta: float) -> void:
	# Long dwellers re-hear the rule every ~30s instead of once per visit.
	if not _shown:
		return
	_dwell += delta
	if _dwell < 30.0:
		return
	var inside := false
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			inside = true
			break
	if inside:
		_dwell = 0.0
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("say"):
			hud.say(tab_title + " — " + tab_body)
	else:
		_shown = false

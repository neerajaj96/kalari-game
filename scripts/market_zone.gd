extends Area3D
# Market fetch zone: grants ritual item when sevaka walks to the stall.
# Re-fires every 3s while inside so a missed bell window needs no exit/re-enter.

var _t := 0.0

func _ready() -> void:
	body_entered.connect(_on_body)

func _on_body(b: Node) -> void:
	_fire(b)

func _process(delta: float) -> void:
	_t += delta
	if _t < 8.0:
		return
	_t = 0.0
	for b in get_overlapping_bodies():
		_fire(b)

func _fire(b: Node) -> void:
	if not b.is_in_group("player"):
		return
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("rituals") == null or not game.rituals.has_method("on_market_zone"):
		return
	var msg: String = game.rituals.on_market_zone()
	if game.get("plot") != null and game.plot.has_method("on_supply"):
		game.plot.on_supply()
	if msg != "":
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("say"):
			hud.say(msg)

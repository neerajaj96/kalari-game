extends Area3D
# Market fetch zone: grants ritual item when sevaka walks to the stall.
# Re-arm on exit: after a missed bell window the pilgrim walks back out and
# in again — standing AFK inside never re-picks.

var _armed := true

func _ready() -> void:
	body_entered.connect(_on_body)
	body_exited.connect(_on_exit)

func _on_body(b: Node) -> void:
	if not _armed:
		return
	if _fire(b):
		_armed = false

func _on_exit(b: Node) -> void:
	if b.is_in_group("player"):
		_armed = true

func _fire(b: Node) -> bool:
	if not b.is_in_group("player"):
		return false
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("rituals") == null or not game.rituals.has_method("on_market_zone"):
		return false
	var msg: String = game.rituals.on_market_zone()
	# Supply counts only on a real FETCH pickup: standing AFK in the stall
	# (IDLE phase, empty "") must not max temple phases, nor re-fire while
	# camping inside (phase already flipped to OFFER by the first pickup).
	if msg == "":
		return false
	if game.get("plot") != null and game.plot.has_method("on_supply"):
		game.plot.on_supply()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say(msg)
	return true

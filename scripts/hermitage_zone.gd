extends Area3D
# Hermitage zone: marks forest variant for sadhana while inside.

func _ready() -> void:
	body_entered.connect(_on_in)
	body_exited.connect(_on_out)

func _on_in(b: Node) -> void:
	if b.is_in_group("player"):
		_apply_zone(true)
		var game = get_tree().get_first_node_in_group("game")
		if game and game.get("plot") != null and game.plot.has_method("on_visit"):
			game.plot.on_visit("hermitage")

func _on_out(b: Node) -> void:
	if b.is_in_group("player"):
		_apply_zone(false)

func _apply_zone(v: bool) -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("sadhana") == null:
		return
	game.sadhana.set_zone(v, game.sadhana.is_in_temple())

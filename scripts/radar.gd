extends Control
# North-up minimap radar, 5Hz redraw. World x±16, z−16..16 maps to the disc.
# Player arrow rotates; bandits show within 15m; plot target pulses gold.

var _t := 0.0
const R := 75.0
const CX := 75.0
const CY := 75.0

func _ready() -> void:
	set_process(true)

func _extent() -> float:
	# Village/school fit ±16m; Ksetra spans 70m. Scale the disc to the world
	# so plot targets and bandits stay on-disc instead of clamping to the rim.
	var w = get_tree().get_first_node_in_group("world")
	if w != null and w.get("current") != null and "Ksetra" in str(w.current.name):
		return 36.0
	return 16.0

func _w2m(p: Vector3) -> Vector2:
	var e := _extent()
	var x: float = clampf(p.x, -e, e) / e
	var z: float = clampf(p.z, -e, e) / e
	return Vector2(CX + x * R, CY + z * R)

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.2:
		return
	_t = 0.0
	queue_redraw()

func _draw() -> void:
	# disc + ground
	draw_circle(Vector2(CX, CY), R, Color(0.05, 0.08, 0.06, 0.85))
	draw_arc(Vector2(CX, CY), R, 0, TAU, 48, Color(0.83, 0.63, 0.09, 0.9), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(CX - 5, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.85, 0.7))
	# water strip south (village z 9..15)
	draw_rect(Rect2(_w2m(Vector3(-15, 0, 9)), _w2m(Vector3(15, 0, 15)) - _w2m(Vector3(-15, 0, 9))), Color(0.16, 0.42, 0.55, 0.8))
	# temple gold square + market dot (village landmarks)
	draw_rect(Rect2(_w2m(Vector3(-1, 0, -11)) , Vector2(6, 6)), Color(0.83, 0.63, 0.09, 0.9))
	draw_circle(_w2m(Vector3(-3, 0, 2)), 3.0, Color(0.2, 0.75, 0.3))
	# plot target pulse
	var game = get_tree().get_first_node_in_group("game")
	var tp: Variant = _plot_target(game)
	if tp != null:
		var tpp: Vector3 = tp
		var pr: float = 4.0 + sin(Time.get_ticks_msec() / 300.0) * 1.5
		draw_circle(_w2m(tpp), pr, Color(1.0, 0.85, 0.3))
	# peds faint, bandits red within 15m, player arrow last
	var player = get_tree().get_first_node_in_group("player")
	var pp := Vector2(CX, CY)
	if player:
		pp = _w2m(player.global_position)
	for ped in get_tree().get_nodes_in_group("ped"):
		if is_instance_valid(ped):
			draw_circle(_w2m(ped.global_position), 2.0, Color(1, 1, 1, 0.5))
	if player:
		var hot := false
		var game0 = get_tree().get_first_node_in_group("game")
		if game0 and game0.get("heat") != null and game0.heat.get("heat") != null:
			hot = game0.heat.heat > 0
		for b in get_tree().get_nodes_in_group("bandit"):
			if is_instance_valid(b) and not b.is_in_group("ped"):
				if hot or b.global_position.distance_to(player.global_position) <= 15.0:
					draw_circle(_w2m(b.global_position), 3.0, Color(0.9, 0.2, 0.15))
	if player:
		var yaw: float = player.rotation.y
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var side := Vector2(-fwd.y, fwd.x)
		var c := pp
		draw_colored_polygon([c - fwd * 3.0 + side * 4.0, c - fwd * 3.0 - side * 4.0, c + fwd * 6.0], Color(1, 1, 1))

func _plot_target(game: Node) -> Variant:
	# Market stall, sanctum door, or hermitage mat by plot phase.
	if game == null or game.get("plot") == null or game.plot.get("phase") == null:
		return null
	var ph: int = game.plot.phase
	if ph <= 1:
		return Vector3(-3, 0, 1)
	if ph <= 3:
		return Vector3(4.2, 0, -10)
	return Vector3(-8, 0, 8.5)

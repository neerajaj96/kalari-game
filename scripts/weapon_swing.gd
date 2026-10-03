extends Node3D
# Weapon swing: fast 0.12s arc out, 0.23s ease back. No textures.
# Triggered once per STRIKE entry (edge), not every frame.

var rest := Vector3(0.3, 0.0, -0.5)
var swing := Vector3(0.3, 0.0, 1.8)
var t := 1.0
var _was_strike := false

const OUT := 0.12
const TOTAL := 0.35

func _process(delta: float) -> void:
	var p = get_parent()
	var striking := false
	if "combat" in p and p.combat != null:
		striking = p.combat.state == 2 # STRIKE
	if striking and not _was_strike:
		t = 0.0
	_was_strike = striking
	if t >= TOTAL:
		rotation = rest
		return
	t = minf(TOTAL, t + delta)
	if t <= OUT:
		var e: float = 1.0 - pow(1.0 - t / OUT, 3.0)
		rotation = rest.lerp(swing, e)
	else:
		var k: float = (t - OUT) / (TOTAL - OUT)
		rotation = swing.lerp(rest, k * k)

extends Node3D
# Weapon swing: fast 0.12s arc out, 0.23s ease back. No textures.
# Triggered once per STRIKE entry (edge), not every frame.
# Slash arc: gold billboard quad riding the pivot, visible only during the
# strike, fading with the ease-back. Pure code, no scene edits.

var rest := Vector3(0.3, 0.0, -0.5)
var swing := Vector3(0.3, 0.0, 1.8)
var t := 1.0
var _was_strike := false
var _arc: MeshInstance3D
var _arc_mat: StandardMaterial3D

const OUT := 0.12
const TOTAL := 0.35
const ARC_ALPHA := 0.55

func _ready() -> void:
	_arc_mat = StandardMaterial3D.new()
	_arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arc_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.0)
	_arc_mat.emission_enabled = true
	_arc_mat.emission = Color(1.0, 0.75, 0.3, 1.0)
	_arc_mat.emission_energy_multiplier = 1.5
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.4, 0.5)
	_arc = MeshInstance3D.new()
	_arc.mesh = quad
	_arc.material_override = _arc_mat
	_arc.visible = false
	add_child(_arc)

func _process(delta: float) -> void:
	var p = get_parent()
	var striking := false
	if "combat" in p and p.combat != null:
		striking = p.combat.state == 2 # STRIKE
	if striking and not _was_strike:
		t = 0.0
		_arc.visible = true
	_was_strike = striking
	if t >= TOTAL:
		rotation = rest
		_arc.visible = false
		return
	t = minf(TOTAL, t + delta)
	if t <= OUT:
		var e: float = 1.0 - pow(1.0 - t / OUT, 3.0)
		rotation = rest.lerp(swing, e)
		_set_arc_alpha(ARC_ALPHA)
	else:
		var k: float = (t - OUT) / (TOTAL - OUT)
		rotation = swing.lerp(rest, k * k)
		_set_arc_alpha(ARC_ALPHA * (1.0 - k))

func _set_arc_alpha(a: float) -> void:
	var c := _arc_mat.albedo_color
	_arc_mat.albedo_color = Color(c.r, c.g, c.b, a)

extends Node
# FaceAnim: blink scheduler, gaze saccades, jaw/brow/cheek expression
# poses, micro-expression noise. Operates on HumanRig facial bones so it
# works with procedural skeletons and any future GLB with same bone names.
# Expression states: neutral/focus/anger/fear/pain/surprise/effort/recovery.
class_name FaceAnim

var _sk: Skeleton3D
var _dna: HumanDNA
var _blink_t := 2.0
var _blink_phase := 1.0
var _gaze_t := 0.0
var _gaze_target := Vector3.ZERO
var _expr := "neutral"
var _expr_w := 0.0
var _micro_t := 0.0
var _pain_flash := 0.0

static func expressions() -> Array:
	return ["neutral", "focus", "anger", "fear", "pain", "surprise", "effort", "recovery"]

func setup(sk: Skeleton3D, dna: HumanDNA) -> void:
	_sk = sk
	_dna = dna
	_blink_t = randf_range(1.8, 4.2)

func set_expression(name_: String) -> void:
	if name_ == _expr:
		return
	_expr = name_
	_expr_w = 0.0

func flash_pain() -> void:
	_pain_flash = 1.0

func _process(delta: float) -> void:
	if _sk == null:
		return
	_tick_blink(delta)
	_tick_gaze(delta)
	_tick_expr(delta)

func _bone_pose(bone: String, rot: Vector3, pos: Vector3) -> void:
	var i := _sk.find_bone(bone)
	if i < 0:
		return
	var rest: Transform3D = _sk.get_bone_rest(i)
	_sk.set_bone_pose_position(i, rest.origin + pos)
	_sk.set_bone_pose_rotation(i, Quaternion(Basis.from_euler(rot) * rest.basis))

func _tick_blink(delta: float) -> void:
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.2, 5.2)
		_blink_phase = 0.0
	if _blink_phase < 0.13:
		_blink_phase += delta
		var close := sin(clampf(_blink_phase / 0.13, 0.0, 1.0) * PI)
		var drop := Vector3(0, -0.008 * close, 0.002 * close)
		_bone_pose("lid_upper_L", Vector3(0.5 * close, 0, 0), drop)
		_bone_pose("lid_upper_R", Vector3(0.5 * close, 0, 0), drop)
	else:
		var open_l := Vector3.ZERO
		# Focus narrows lids; surprise/fear widens.
		if _expr == "focus" or _expr == "anger":
			open_l = Vector3(0.10, 0, 0)
		elif _expr == "surprise" or _expr == "fear":
			open_l = Vector3(-0.12, 0, 0)
		_bone_pose("lid_upper_L", open_l, Vector3.ZERO)
		_bone_pose("lid_upper_R", open_l, Vector3.ZERO)
		_bone_pose("lid_lower_L", Vector3.ZERO, Vector3.ZERO)
		_bone_pose("lid_lower_R", Vector3.ZERO, Vector3.ZERO)

func _tick_gaze(delta: float) -> void:
	_gaze_t -= delta
	if _gaze_t <= 0.0:
		_gaze_t = randf_range(0.7, 2.4)
		_gaze_target = Vector3(randf_range(-0.12, 0.12), randf_range(-0.06, 0.08), 0)
	var k: float = minf(1.0, 8.0 * delta)
	var li := _sk.find_bone("eye_L")
	var ri := _sk.find_bone("eye_R")
	for bi in [li, ri]:
		if bi < 0:
			continue
		var cur: Vector3 = _sk.get_bone_pose_position(bi)
		var rest: Vector3 = _sk.get_bone_rest(bi).origin
		var goal: Vector3 = rest + _gaze_target
		_sk.set_bone_pose_position(bi, cur.lerp(goal, k))

func _tick_expr(delta: float) -> void:
	_expr_w = minf(1.0, _expr_w + delta * 5.0)
	_pain_flash = maxf(0.0, _pain_flash - delta * 2.0)
	_micro_t += delta
	var micro := sin(_micro_t * 1.7) * 0.02 + sin(_micro_t * 3.9) * 0.012
	var jaw_open := 0.0
	var brow := Vector3.ZERO
	var brow_pos := Vector3.ZERO
	match _expr:
		"focus":
			brow = Vector3(0.12, 0, 0)
			brow_pos = Vector3(0, -0.003, -0.002)
			jaw_open = 0.02
		"anger":
			brow = Vector3(0.0, 0, -0.18)
			brow_pos = Vector3(0, -0.005, -0.003)
			jaw_open = 0.06 + micro
		"fear":
			brow = Vector3(-0.22, 0, 0)
			brow_pos = Vector3(0, 0.005, 0.0)
			jaw_open = 0.10
		"pain", "effort":
			brow = Vector3(0.18, 0, 0.10)
			jaw_open = 0.16 + _pain_flash * 0.12
		"surprise":
			brow = Vector3(-0.28, 0, 0)
			brow_pos = Vector3(0, 0.007, 0.0)
			jaw_open = 0.18
		"recovery":
			brow = Vector3(0.05, 0, 0)
			jaw_open = 0.08
		_:
			jaw_open = 0.015 + micro * 0.4
	var ji := _sk.find_bone("jaw")
	if ji >= 0:
		var rest: Transform3D = _sk.get_bone_rest(ji)
		_sk.set_bone_pose_position(ji, rest.origin + Vector3(0, -jaw_open * 0.05, -jaw_open * 0.02))
		_sk.set_bone_pose_rotation(ji, Quaternion(Basis(Vector3(1, 0, 0), jaw_open * 0.9) * rest.basis))
	_bone_pose("brow_L", brow + Vector3(micro * 0.3, 0, 0), brow_pos)
	_bone_pose("brow_R", Vector3(brow.x, brow.y, -brow.z) + Vector3(-micro * 0.3, 0, 0), brow_pos)

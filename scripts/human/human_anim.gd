extends Node
# HumanAnim: procedural locomotion + combat animation. Maps CombatState ints
# + planar velocity onto the shared Skeleton3D. Non-root-motion: displacement
# stays owned by player.gd / enemy_ai.gd / ped.gd move_and_slide.
# States: IDLE 0, STANCE 1, STRIKE 2, BLOCK 3, DODGE 4, HIT 5, DOWN 6.
# Vadivu flavor preserved: Simha(block) turtle, Sarpa(dodge) slip,
# Aswa(strike) lunge, Gaja(stance) neutral.
class_name HumanAnim

const HumanDNA = preload("res://scripts/human/human_dna.gd")
const FaceAnim = preload("res://scripts/human/face_anim.gd")
const IKSolver = preload("res://scripts/human/ik_solver.gd")

var _sk: Skeleton3D
var _dna: HumanDNA
var _face: FaceAnim
var _ik: IKSolver
var _phase := 0.0
var _breath := 0.0
var _strike_t := 1.0
var _hit_t := 1.0
var _last_state := 1
var _down_blend := 0.0

func setup(sk: Skeleton3D, dna: HumanDNA, face: FaceAnim, ik: IKSolver) -> void:
	_sk = sk
	_dna = dna
	_face = face
	_ik = ik
	_phase = randf() * TAU

func animate(delta: float, state: int, planar_speed: float, move_dir_local: Vector3, face_lock: String = "") -> void:
	if _sk == null:
		return
	_breath += delta * (1.1 + _dna.idle_energy * 0.6)
	if state != _last_state:
		if state == 2:
			_strike_t = 0.0
		if state == 5:
			_hit_t = 0.0
			if _face != null:
				_face.flash_pain()
		_last_state = state
	_strike_t = minf(1.0, _strike_t + delta / 0.38)
	_hit_t = minf(1.0, _hit_t + delta / 0.45)
	_down_blend = clampf(_down_blend + (delta if state == 6 else -delta * 2.0), 0.0, 1.0)
	_pose_root(delta, state, planar_speed)
	_pose_legs(delta, state, planar_speed, move_dir_local)
	_pose_arms(delta, state, planar_speed)
	_pose_spine_head(delta, state)
	if face_lock != "":
		if _face != null:
			_face.set_expression(face_lock)
	else:
		_map_face(state)
	if _ik != null and state != 6:
		_ik.foot_plant = 1.0 if planar_speed < 0.6 else 0.55
		_ik.plant_feet(0.0, _phase, clampf(planar_speed / 4.0, 0.0, 1.0))

func _set_rot(bone: String, euler: Vector3, speed: float, delta: float) -> void:
	var i := _sk.find_bone(bone)
	if i < 0:
		return
	var cur: Quaternion = _sk.get_bone_pose_rotation(i)
	# Pose composes with rest inside the engine: store pure euler rotation.
	var goal := Quaternion(Basis.from_euler(euler))
	var k: float = minf(1.0, speed * delta)
	_sk.set_bone_pose_rotation(i, cur.slerp(goal, k))

func _set_pos(bone: String, pos: Vector3, speed: float, delta: float) -> void:
	var i := _sk.find_bone(bone)
	if i < 0:
		return
	var cur: Vector3 = _sk.get_bone_pose_position(i)
	if cur == Vector3.ZERO:
		cur = _sk.get_bone_rest(i).origin
	var k: float = minf(1.0, speed * delta)
	_sk.set_bone_pose_position(i, cur.lerp(pos, k))

func _pose_root(delta: float, state: int, planar: float) -> void:
	var dy := 0.0
	var lean := 0.0
	match state:
		3:
			dy = -0.14
		4:
			dy = -0.22
		5:
			dy = -0.07
		6:
			dy = -0.42
		_:
			dy = sin(_breath * 1.6) * 0.008 - clampf(planar / 8.0, 0.0, 1.0) * 0.03
			lean = clampf(planar / 6.0, 0.0, 1.0) * 0.10
	_set_pos("pelvis", _sk.get_bone_rest(_sk.find_bone("pelvis")).origin + Vector3(0, dy, 0), 10.0, delta)
	_set_rot("pelvis", Vector3(lean + _down_blend * 1.25, 0, 0), 8.0, delta)

func _pose_legs(delta: float, state: int, planar: float, _dir: Vector3) -> void:
	if state == 6:
		_set_rot("thigh_L", Vector3(-1.2, 0, 0.15), 6.0, delta)
		_set_rot("thigh_R", Vector3(-1.1, 0, -0.15), 6.0, delta)
		_set_rot("shin_L", Vector3(1.4, 0, 0), 6.0, delta)
		_set_rot("shin_R", Vector3(1.3, 0, 0), 6.0, delta)
		return
	if state == 3: # Simha: deep horse stance.
		_set_rot("thigh_L", Vector3(-0.85, 0, 0.45), 9.0, delta)
		_set_rot("thigh_R", Vector3(-0.85, 0, -0.45), 9.0, delta)
		_set_rot("shin_L", Vector3(1.05, 0, 0), 9.0, delta)
		_set_rot("shin_R", Vector3(1.05, 0, 0), 9.0, delta)
		_set_rot("foot_L", Vector3(-0.2, 0, 0), 9.0, delta)
		_set_rot("foot_R", Vector3(-0.2, 0, 0), 9.0, delta)
		return
	if state == 4: # Sarpa: low slip, legs folded.
		_set_rot("thigh_L", Vector3(-1.0, 0, 0.3), 10.0, delta)
		_set_rot("thigh_R", Vector3(-0.5, 0, -0.35), 10.0, delta)
		_set_rot("shin_L", Vector3(1.35, 0, 0), 10.0, delta)
		_set_rot("shin_R", Vector3(0.9, 0, 0), 10.0, delta)
		return
	if state == 2: # Aswa lunge: front leg forward, back leg extended.
		var e := _strike_curve()
		_set_rot("thigh_L", Vector3(-0.9 * e, 0, 0.12), 14.0, delta)
		_set_rot("thigh_R", Vector3(0.45 * e, 0, -0.12), 14.0, delta)
		_set_rot("shin_L", Vector3(0.7 * e, 0, 0), 14.0, delta)
		_set_rot("shin_R", Vector3(0.25 * e, 0, 0), 14.0, delta)
		return
	if planar > 0.4:
		_phase += delta * (4.2 + planar * 1.6) * (0.9 + _dna.gait_bounce * 0.2)
		var s := sin(_phase)
		var c := sin(_phase + PI)
		var amp := clampf(planar / 4.5, 0.25, 1.0) * (0.55 + _dna.gait_sway * 0.15)
		_set_rot("thigh_L", Vector3(s * amp, 0, 0.04), 12.0, delta)
		_set_rot("thigh_R", Vector3(c * amp, 0, -0.04), 12.0, delta)
		_set_rot("shin_L", Vector3(maxf(0.0, -c) * amp * 1.2 + 0.08, 0, 0), 12.0, delta)
		_set_rot("shin_R", Vector3(maxf(0.0, -s) * amp * 1.2 + 0.08, 0, 0), 12.0, delta)
		_set_rot("foot_L", Vector3(-s * amp * 0.5, 0, 0), 12.0, delta)
		_set_rot("foot_R", Vector3(-c * amp * 0.5, 0, 0), 12.0, delta)
	else:
		# Gaja neutral: soft knees, weight shift sway.
		var sway := sin(_breath * 0.7) * 0.03
		_set_rot("thigh_L", Vector3(-0.06, 0, 0.05 + sway), 7.0, delta)
		_set_rot("thigh_R", Vector3(-0.06, 0, -0.05 + sway), 7.0, delta)
		_set_rot("shin_L", Vector3(0.10, 0, 0), 7.0, delta)
		_set_rot("shin_R", Vector3(0.10, 0, 0), 7.0, delta)
		_set_rot("foot_L", Vector3(-0.04, 0, 0), 7.0, delta)
		_set_rot("foot_R", Vector3(-0.04, 0, 0), 7.0, delta)

func _pose_arms(delta: float, state: int, planar: float) -> void:
	var guard_l := Vector3(-0.9, 0, 0.55)
	var guard_r := Vector3(-0.9, 0, -0.55)
	if state == 6:
		_set_rot("upperarm_L", Vector3(0.5, 0, 0.9), 5.0, delta)
		_set_rot("upperarm_R", Vector3(0.5, 0, -0.9), 5.0, delta)
		_set_rot("forearm_L", Vector3(0.3, 0, 0), 5.0, delta)
		_set_rot("forearm_R", Vector3(0.3, 0, 0), 5.0, delta)
		return
	if state == 3: # guard high (FK + hand IK assist for weapon/guard lock).
		_set_rot("upperarm_L", guard_l, 10.0, delta)
		_set_rot("upperarm_R", guard_r, 10.0, delta)
		_set_rot("forearm_L", Vector3(-1.15, 0, 0), 10.0, delta)
		_set_rot("forearm_R", Vector3(-1.15, 0, 0), 10.0, delta)
		_assist_hands(Vector3(-0.16, 1.32, -0.34), Vector3(0.16, 1.32, -0.34))
		return
	if state == 4:
		_set_rot("upperarm_L", Vector3(0.55, 0, 0.35), 10.0, delta)
		_set_rot("upperarm_R", Vector3(0.55, 0, -0.35), 10.0, delta)
		_set_rot("forearm_L", Vector3(-0.3, 0, 0), 10.0, delta)
		_set_rot("forearm_R", Vector3(-0.3, 0, 0), 10.0, delta)
		return
	if state == 2:
		var e := _strike_curve()
		# Right arm chops overhead->down; left chambers back.
		_set_rot("upperarm_R", Vector3(lerpf(-2.4, -0.7, e), 0, -0.25), 16.0, delta)
		_set_rot("forearm_R", Vector3(lerpf(-0.4, -0.15, e), 0, 0), 16.0, delta)
		_set_rot("upperarm_L", Vector3(lerpf(0.3, -0.5, e), 0, 0.5), 16.0, delta)
		_set_rot("forearm_L", Vector3(-0.9 + e * 0.4, 0, 0), 16.0, delta)
		return
	if state == 5:
		var fl := (1.0 - _hit_t) * 0.6
		_set_rot("upperarm_L", Vector3(-0.4 + fl, 0, 0.7), 12.0, delta)
		_set_rot("upperarm_R", Vector3(-0.4 + fl, 0, -0.7), 12.0, delta)
		_set_rot("forearm_L", Vector3(-0.8, 0, 0), 12.0, delta)
		_set_rot("forearm_R", Vector3(-0.8, 0, 0), 12.0, delta)
		return
	if planar > 0.4:
		var s := sin(_phase) * clampf(planar / 4.5, 0.0, 1.0) * 0.5
		# Kalari walk: hands stay half-guard, swing small.
		_set_rot("upperarm_L", Vector3(s * 0.6 - 0.25, 0, 0.18), 10.0, delta)
		_set_rot("upperarm_R", Vector3(-s * 0.6 - 0.25, 0, -0.18), 10.0, delta)
		_set_rot("forearm_L", Vector3(-0.45, 0, 0), 10.0, delta)
		_set_rot("forearm_R", Vector3(-0.45, 0, 0), 10.0, delta)
	else:
		var b := sin(_breath * 1.6) * 0.04
		# Individual ready pose: player high guard, elder low, others mid.
		var ready := 0.35 + _dna.idle_energy * 0.45
		_set_rot("upperarm_L", Vector3(-0.25 * ready + b, 0, 0.16), 7.0, delta)
		_set_rot("upperarm_R", Vector3(-0.25 * ready - b, 0, -0.16), 7.0, delta)
		_set_rot("forearm_L", Vector3(-0.35 * ready, 0, 0), 7.0, delta)
		_set_rot("forearm_R", Vector3(-0.35 * ready, 0, 0), 7.0, delta)

func _pose_spine_head(delta: float, state: int) -> void:
	match state:
		3:
			_set_rot("spine", Vector3(0.18, 0, 0), 8.0, delta)
			_set_rot("chest", Vector3(0.12, 0, 0), 8.0, delta)
			_set_rot("head", Vector3(-0.15, 0, 0), 8.0, delta)
		4:
			_set_rot("spine", Vector3(0.30, 0.25, 0), 9.0, delta)
			_set_rot("chest", Vector3(0.15, 0.15, 0), 9.0, delta)
			_set_rot("head", Vector3(-0.2, -0.2, 0), 9.0, delta)
		2:
			var e := _strike_curve()
			_set_rot("spine", Vector3(0.22 * e, 0, 0), 12.0, delta)
			_set_rot("chest", Vector3(0.12 * e, -0.2 * e, 0), 12.0, delta)
			_set_rot("head", Vector3(-0.08 * e, 0.1 * e, 0), 12.0, delta)
		5:
			_set_rot("spine", Vector3(-0.18 * (1.0 - _hit_t), 0, 0.1), 12.0, delta)
			_set_rot("head", Vector3(-0.25 * (1.0 - _hit_t), 0, 0), 12.0, delta)
		6:
			_set_rot("spine", Vector3(0.3, 0, 0), 5.0, delta)
			_set_rot("head", Vector3(0.4, 0.3, 0), 5.0, delta)
		_:
			_set_rot("spine", Vector3(0.03 + sin(_breath * 1.6) * 0.012, sin(_breath * 0.5) * 0.02, 0), 6.0, delta)
			_set_rot("chest", Vector3(0.02, 0, 0), 6.0, delta)
			_set_rot("head", Vector3(sin(_breath * 0.9) * 0.015, sin(_breath * 0.4) * 0.03, 0), 6.0, delta)

func _strike_curve() -> float:
	if _strike_t >= 1.0:
		return 0.0
	if _strike_t < 0.34:
		var t := _strike_t / 0.34
		return 1.0 - pow(1.0 - t, 3.0)
	var r := (_strike_t - 0.34) / 0.66
	return 1.0 - r * r

func _assist_hands(target_l: Vector3, target_r: Vector3) -> void:
	# Hand IK assist: snap guard hands to targets (scaled by stature).
	if _ik == null or _sk == null:
		return
	var s := _dna.stature / 1.70
	_ik.solve_two_bone("upperarm_L", "forearm_L", "hand_L", target_l * s, Vector3(0, -1, 0.5))
	_ik.solve_two_bone("upperarm_R", "forearm_R", "hand_R", target_r * s, Vector3(0, -1, 0.5))

func _map_face(state: int) -> void:
	if _face == null:
		return
	match state:
		2:
			_face.set_expression("effort")
		3:
			_face.set_expression("focus")
		4:
			_face.set_expression("focus")
		5:
			_face.set_expression("pain")
		6:
			_face.set_expression("pain")
		_:
			_face.set_expression("neutral")

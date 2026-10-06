extends Node
# IKSolver: analytic two-bone IK for arms/legs + foot ground planting.
# Runs after HumanAnim poses the skeleton each physics frame. Headless-safe
# (pure math, no physics queries): feet plant to ground plane y=0 in local
# character space with step-height lift during swing phase.
class_name IKSolver

var _sk: Skeleton3D
var enabled := true
var foot_plant := 1.0 # 0 free .. 1 planted
var hand_target_L: Vector3 = Vector3.ZERO
var hand_target_R: Vector3 = Vector3.ZERO
var hand_ik_w := 0.0 # weapon/guard blending weight

func setup(sk: Skeleton3D) -> void:
	_sk = sk

# Analytic two-bone solve in skeleton local space. upper/mid/end bone names,
# target in skeleton-local coords, pole hint direction.
func solve_two_bone(upper: String, mid: String, end: String, target: Vector3, pole: Vector3) -> void:
	if not enabled or _sk == null:
		return
	var iu := _sk.find_bone(upper)
	var im := _sk.find_bone(mid)
	var ie := _sk.find_bone(end)
	if iu < 0 or im < 0 or ie < 0:
		return
	var pu := _bone_global(iu)
	var pm := _bone_global(im)
	var pe := _bone_global(ie)
	var a := (pm - pu).length()
	var b := (pe - pm).length()
	if a < 0.01 or b < 0.01:
		return
	var to_t: Vector3 = target - pu
	var dist := clampf(to_t.length(), 0.05, a + b - 0.005)
	var dir := to_t.normalized() if to_t.length() > 0.001 else Vector3(0, -1, 0)
	# Knee/elbow bend plane from pole hint.
	var bend := (pole - (pole.dot(dir)) * dir)
	if bend.length() < 0.001:
		bend = Vector3(0, 0, 1)
	bend = bend.normalized()
	# Angle at upper joint via law of cosines.
	var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var ang_a := acos(cos_a)
	var upper_dir := (dir * cos(ang_a) + bend * sin(ang_a)).normalized()
	var new_mid := pu + upper_dir * a
	var new_end := pu + dir * dist
	_aim_bone(iu, pm - pu, new_mid - pu)
	_aim_bone(im, pe - pm, new_end - new_mid)

func _bone_global(i: int) -> Vector3:
	# Skeleton-local global (rest chain + current pose). Approximate by
	# walking parents — cheap for 42 bones at 60fps.
	var xform := Transform3D.IDENTITY
	var chain: Array = []
	var c := i
	while c >= 0:
		chain.push_front(c)
		c = _sk.get_bone_parent(c)
	for bi in chain:
		var rest: Transform3D = _sk.get_bone_rest(bi)
		var pos: Vector3 = _sk.get_bone_pose_position(bi)
		var rot: Quaternion = _sk.get_bone_pose_rotation(bi)
		# Pose position overrides rest origin when set; rest basis kept.
		var t := Transform3D(Basis(rot) * rest.basis, pos if _sk.get_bone_pose_position(bi) != Vector3.ZERO else rest.origin)
		# NOTE: Godot returns rest origin when pose untouched; the check above
		# collapses to rest in that case — deterministic either way.
		xform = xform * t
	return xform.origin

func _aim_bone(i: int, from_dir: Vector3, to_dir: Vector3) -> void:
	if from_dir.length() < 0.001 or to_dir.length() < 0.001:
		return
	var q := Quaternion(from_dir.normalized(), to_dir.normalized())
	var cur: Quaternion = _sk.get_bone_pose_rotation(i)
	var rest: Transform3D = _sk.get_bone_rest(i)
	_sk.set_bone_pose_rotation(i, q * cur)

func plant_feet(skel_local_ground: float = 0.0, swing_phase: float = 0.0, stride: float = 0.0) -> void:
	if not enabled or _sk == null:
		return
	# Gentle snap: pull foot bones toward ground plane, lift swing foot.
	for side in ["L", "R"]:
		var fi := _sk.find_bone("foot_" + side)
		if fi < 0:
			continue
		var p: Vector3 = _sk.get_bone_pose_position(fi)
		if p == Vector3.ZERO:
			p = _sk.get_bone_rest(fi).origin
		var lift := 0.0
		if stride > 0.05:
			var ph := swing_phase + (0.0 if side == "L" else PI)
			lift = maxf(0.0, sin(ph)) * 0.06 * minf(stride, 1.0)
		var gy := skel_local_ground + lift
		# Blend toward planted height (sole thickness) without snapping the leg.
		var cur_y := p.y
		p.y = lerpf(cur_y, gy + 0.012, foot_plant * 0.5)
		_sk.set_bone_pose_position(fi, p)

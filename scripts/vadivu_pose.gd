extends Node
# Procedural vadivu poses + limb animation. Maps CombatState -> Body scale/offset,
# plus walk cycle, attack arcs, guard, idle breath on sibling limbs.
# Simha(block)=turtle crouch, Sarpa(dodge)=low slip, Aswa(strike)=lunge tall,
# Gaja(stance)=neutral, Hit=flinch, Down=fallen. No rig/textures needed.
class_name VadivuPose

@export var body_path := "Body"
@export var speed := 12.0

var _body: MeshInstance3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _leg_l: MeshInstance3D
var _leg_r: MeshInstance3D
var _base_y := 0.9
var _phase := 0.0
var _breath := 0.0
var _strike_t := 1.0
var _was_strike := false
var _eye_l: MeshInstance3D
var _eye_r: MeshInstance3D
var _teeth: MeshInstance3D
var _blink_t := 0.0
var _blink_phase := 1.0 # >=0.12 means open

# Rest rotations so walk/attack always ease home.
var _arm_rest_l := Vector3.ZERO
var _arm_rest_r := Vector3.ZERO

func _ready() -> void:
	var p := get_parent()
	_body = p.get_node_or_null(body_path) as MeshInstance3D
	_arm_l = p.get_node_or_null("ArmL") as MeshInstance3D
	_arm_r = p.get_node_or_null("ArmR") as MeshInstance3D
	_leg_l = p.get_node_or_null("LegL") as MeshInstance3D
	_leg_r = p.get_node_or_null("LegR") as MeshInstance3D
	if _body:
		_base_y = _body.position.y
	if _arm_l:
		_arm_rest_l = _arm_l.rotation
	if _arm_r:
		_arm_rest_r = _arm_r.rotation
	_eye_l = p.get_node_or_null("EyeL") as MeshInstance3D
	_eye_r = p.get_node_or_null("EyeR") as MeshInstance3D
	_teeth = p.get_node_or_null("Teeth") as MeshInstance3D
	_blink_t = randf_range(1.5, 4.0) # desync fighters

func _process(delta: float) -> void:
	if _body == null:
		return
	if not _body.visible:
		return # cinematic body carries the frame; legacy limbs stay parked.
	var p = get_parent()
	var st: int = 1 # STANCE default
	if "combat" in p and p.combat != null:
		st = p.combat.state
	var planar := 0.0
	if p.get("velocity") != null:
		var v: Vector3 = p.velocity
		planar = Vector2(v.x, v.z).length()
	_pose_body(delta, st)
	_limbs(delta, st, planar)
	_blink(delta, st)
	_yell(st)

func _blink(delta: float, st: int) -> void:
	# Eyelids: squash eye spheres 0.12s every few seconds. Wide-eyed in
	# STRIKE/BLOCK/DODGE. Gurukkal has no Vadivu node, so he never blinks.
	if _eye_l == null or _eye_r == null:
		return
	if st in [1, 0]: # IDLE/STANCE only; flinch never blinks
		_blink_t -= delta
		if _blink_t <= 0.0:
			_blink_t = randf_range(2.5, 5.0)
			_blink_phase = 0.0
	if _blink_phase < 0.12:
		_blink_phase += delta
		_eye_l.scale.y = 0.1
		_eye_r.scale.y = 0.1
	else:
		_eye_l.scale.y = lerpf(_eye_l.scale.y, 1.0, minf(1.0, 14.0 * delta))
		_eye_r.scale.y = lerpf(_eye_r.scale.y, 1.0, minf(1.0, 14.0 * delta))

func _yell(st: int) -> void:
	# Strike yell: teeth slit flashes during swing-out, vanishes after.
	if _teeth == null:
		return
	if st == 2 and _strike_t < 0.39:
		_teeth.scale.y = 1.0
	else:
		_teeth.scale.y = 0.05

func _pose_body(delta: float, st: int) -> void:
	var goal_scale := Vector3.ONE
	var goal_dy := 0.0
	match st:
		3: # BLOCK = Simha
			goal_scale = Vector3(1.15, 0.8, 1.15)
			goal_dy = -0.2
		4: # DODGE = Sarpa
			goal_scale = Vector3(1.1, 0.65, 1.1)
			goal_dy = -0.35
		2: # STRIKE = Aswa lunge
			goal_scale = Vector3(0.95, 1.05, 1.1)
			goal_dy = 0.0
		5: # HIT flinch
			goal_scale = Vector3(1.05, 0.9, 1.05)
			goal_dy = -0.1
		6: # DOWN fallen
			goal_scale = Vector3(1.2, 0.5, 1.2)
			goal_dy = -0.4
		_: # IDLE/STANCE = Gaja neutral + idle breath (game-time, freezes in hitstop)
			_breath += delta
			var b := 1.0 + sin(_breath * 1.6) * 0.015
			goal_scale = Vector3(1.0, b, 1.0)
			goal_dy = 0.0
	var k: float = minf(1.0, speed * delta)
	_body.scale = _body.scale.lerp(goal_scale, k)
	_body.position.y = lerpf(_body.position.y, _base_y + goal_dy, k)
	# Head rides the crouch so Simha/Sarpa never detach it (bob owns x only).
	var head := get_parent().get_node_or_null("Head") as MeshInstance3D
	if head:
		head.position.y = lerpf(head.position.y, 1.8 + goal_dy, k)

func _limbs(delta: float, st: int, planar: float) -> void:
	if _arm_l == null or _arm_r == null:
		return
	var k: float = minf(1.0, 10.0 * delta)
	var striking := st == 2
	if striking and not _was_strike:
		_strike_t = 0.0
	_was_strike = striking
	_strike_t = minf(1.0, _strike_t + delta / 0.35)
	if _strike_t < 1.0:
		var e: float
		if _strike_t < 0.34:
			e = 1.0 - pow(1.0 - _strike_t / 0.34, 3.0)
			_arm_r.rotation.x = lerpf(_arm_rest_r.x, -1.8, e)
			_arm_l.rotation.x = lerpf(_arm_rest_l.x, 0.5, e)
		else:
			var r: float = (_strike_t - 0.34) / 0.66
			_arm_r.rotation.x = lerpf(-1.8, _arm_rest_r.x, r * r)
			_arm_l.rotation.x = lerpf(0.5, _arm_rest_l.x, r * r)
		_set_legs(k)
		return
	if st == 3: # BLOCK: both arms forward guard
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -1.2, k)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -1.2, k)
		_set_legs(k)
		return
	if st == 4 or st == 6: # DODGE/DOWN: arms trail
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.6, k)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 0.6, k)
		_set_legs(k)
		return
	if planar > 0.5: # walk cycle, phase tracks speed
		_phase += delta * planar * 2.4
		var s := sin(_phase) * 0.5
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, s, k)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -s, k)
		if _leg_l:
			_leg_l.rotation.x = lerpf(_leg_l.rotation.x, -s * 0.8, k)
		if _leg_r:
			_leg_r.rotation.x = lerpf(_leg_r.rotation.x, s * 0.8, k)
	else: # ease home
		_arm_l.rotation = _arm_l.rotation.lerp(_arm_rest_l, k)
		_arm_r.rotation = _arm_r.rotation.lerp(_arm_rest_r, k)
		_set_legs(k)

func _set_legs(k: float) -> void:
	if _leg_l:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.0, k)
	if _leg_r:
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.0, k)

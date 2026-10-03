extends Node
# Procedural vadivu poses: maps CombatState -> Body scale/offset, lerped.
# Simha(block)=turtle crouch, Sarpa(dodge)=low slip, Aswa(strike)=lunge tall,
# Gaja(stance)=neutral, Hit=flinch, Down=fallen. No rig/textures needed.
class_name VadivuPose

@export var body_path := "Body"
@export var speed := 12.0

var _body: MeshInstance3D
var _base_y := 0.9

func _ready() -> void:
	_body = get_parent().get_node_or_null(body_path) as MeshInstance3D
	if _body:
		_base_y = _body.position.y

func _process(delta: float) -> void:
	if _body == null:
		return
	var p = get_parent()
	var st: int = 1 # STANCE default
	if "combat" in p and p.combat != null:
		st = p.combat.state
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
		_: # IDLE/STANCE = Gaja neutral
			goal_scale = Vector3.ONE
			goal_dy = 0.0
	var k: float = minf(1.0, speed * delta)
	_body.scale = _body.scale.lerp(goal_scale, k)
	var py: float = lerpf(_body.position.y, _base_y + goal_dy, k)
	_body.position.y = py

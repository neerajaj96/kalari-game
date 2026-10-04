extends Node3D
# Ping-pong mover: bullock carts on paths, boats on backwater.
# Constant speed, pauses for the player ahead, carries deck riders by
# applying its own frame displacement (no reparenting — physics stays stable).
class_name CartBoat

@export var speed := 2.5
@export var pa_x := -3.0
@export var pa_z := -5.0
@export var pb_x := 3.0
@export var pb_z := 5.0
@export var ride_height := 0.6

var _t := 0.0
var _dir := 1.0
var _prev := Vector3.ZERO

func _ready() -> void:
	_prev = global_position

func _physics_process(delta: float) -> void:
	var a := Vector3(pa_x, global_position.y, pa_z)
	var b := Vector3(pb_x, global_position.y, pb_z)
	var target: Vector3 = b if _dir > 0.0 else a
	var to: Vector3 = target - global_position
	to.y = 0.0
	if to.length() < 0.4:
		_dir = -_dir
		return
	if _blocked():
		return
	var step: Vector3 = to.normalized() * speed * delta
	global_position += step
	if step.length() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(-step.x, -step.z), 6.0 * delta)
	_carry(step)

func _blocked() -> bool:
	# Stop only for someone standing ahead in the path (not riders on deck).
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return false
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	if to.length() > 2.5:
		return false
	var a := Vector3(pa_x, 0, pa_z)
	var b := Vector3(pb_x, 0, pb_z)
	var heading: Vector3 = (b - a).normalized() * _dir
	return heading.dot(to.normalized()) > 0.3 and absf((player.global_position.y - global_position.y)) < 1.0

func _carry(step: Vector3) -> void:
	# Riders step up onto the deck by walking into it, then ride along.
	# Deck top ~0.75 (cart) / ~0.5 (boat).
	for b in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(b):
			continue
		var rel: Vector3 = b.global_position - global_position
		if absf(rel.x) < 1.2 and absf(rel.z) < 1.2 and rel.y < 1.6:
			if rel.y < 0.5:
				b.global_position.y = global_position.y + 0.8
			b.global_position += step
	_prev = global_position

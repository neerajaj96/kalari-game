extends Camera3D
# Follow + trauma shake. Follows group "player", keeps pit/village offset.
# Strike adds 0.25 kick, hurt adds 0.5. Dodge briefly widens FOV. Mobile: no smoothing stack.

@export var offset := Vector3(0, 6.0, 9.0)
@export var follow_speed := 5.0

var trauma := 0.0
var base_fov := 60.0
var fov_kick := 0.0

func _ready() -> void:
	add_to_group("main_camera")
	base_fov = 60.0
	fov = base_fov

func add_shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func kick_fov(amount: float = 5.0) -> void:
	fov_kick = amount

func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		var goal: Vector3 = p.global_position + offset
		# Clamp to village bounds (pit sits inside them) so we never show void.
		goal.x = clampf(goal.x, -13.0, 13.0)
		goal.z = clampf(goal.z, -12.0, 14.0)
		global_position = global_position.lerp(goal, minf(1.0, follow_speed * delta))
	trauma = maxf(0.0, trauma - delta * 1.6)
	if trauma > 0.0:
		var s := trauma * trauma
		h_offset = randf_range(-s, s) * 0.6
		v_offset = randf_range(-s, s) * 0.4
	else:
		h_offset = 0.0
		v_offset = 0.0
	if fov_kick > 0.1:
		fov_kick = lerpf(fov_kick, 0.0, minf(1.0, 6.0 * delta))
		fov = base_fov + fov_kick
	else:
		fov = base_fov

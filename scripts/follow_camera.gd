extends Camera3D
# Follow + trauma shake + combat feel. Follows group "player".
# Explore FOV 55, combat FOV 62, dodge kick +6, strike kick +4, hurt shake 0.5.
# Combat lowers the eye for drama. No roll (motion-sickness guard).

@export var offset := Vector3(0, 6.0, 9.0)
@export var follow_speed := 5.0

var trauma := 0.0
var base_fov := 55.0
var fov_kick := 0.0
var _combat := 0.0

func _ready() -> void:
	add_to_group("main_camera")
	base_fov = 55.0
	fov = base_fov

func add_shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func kick_fov(amount: float = 5.0) -> void:
	fov_kick = amount

func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var want_combat := 0.0
	var eye := offset
	if p:
		# Combat when the fighter acts/hurts, or a bandit closes in.
		var fighting := false
		if p.get("combat") != null:
			fighting = p.combat.state in [2, 3, 5]
		if not fighting:
			for b in get_tree().get_nodes_in_group("bandit"):
				if is_instance_valid(b) and b.global_position.distance_to(p.global_position) < 6.0:
					fighting = true
					break
		want_combat = 1.0 if fighting else 0.0
		_combat = lerpf(_combat, want_combat, minf(1.0, 3.0 * delta))
		eye = Vector3(offset.x, lerpf(offset.y, offset.y - 1.0, _combat), offset.z)
		var goal: Vector3 = p.global_position + eye
		# Clamp to the active world so we never show void (village default, ksetra wide).
		var bx := 13.0
		var bz0 := -12.0
		var bz1 := 14.0
		var w := get_tree().get_first_node_in_group("world")
		if w != null and w.get("current") != null and "Ksetra" in str(w.current.name):
			bx = 28.0
			bz0 = -28.0
			bz1 = 28.0
		goal.x = clampf(goal.x, -bx, bx)
		goal.z = clampf(goal.z, bz0, bz1)
		# Wall-clip guard: pull the eye to the first obstruction so close-range
		# inspection never sinks into mandapa walls/roofs. Player capsule skipped
		# (ray starts inside it, hit_from_inside=false).
		var pq := PhysicsRayQueryParameters3D.create(
			p.global_position + Vector3(0, 1.5, 0), goal + Vector3(0, 0.5, 0))
		var phit := get_world_3d().direct_space_state.intersect_ray(pq)
		if not phit.is_empty():
			var hp: Vector3 = phit["position"]
			var back: Vector3 = (goal + Vector3(0, 0.5, 0) - hp).normalized()
			goal = hp - Vector3(0, 0.5, 0) - back * 0.45
		global_position = global_position.lerp(goal, minf(1.0, follow_speed * delta))
	base_fov = lerpf(55.0, 62.0, _combat)
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

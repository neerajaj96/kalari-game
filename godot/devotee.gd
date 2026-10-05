extends CharacterBody3D
## Ambient devotee: walks the pradakshina ring, pauses at bali stones during
## sreebali windows. No combat, no dialogue. Provenance: TS sreebali/utsava-bali
## program (PRAYOGA-P6V01-parivara stations; TS-P2V2-yoni balikkal ring).
class_name KsetraDevotee

var ring_r := 12.0
var angle := 0.0
var speed := 0.5  # rad/s unhurried circuit
var pause_t := 0.0
var stone_every := PI / 4.0  # 8 balikkal stations

func _physics_process(delta: float) -> void:
	if pause_t > 0.0:
		pause_t -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		return
	angle += speed * delta
	var target := Vector3(cos(angle) * ring_r, 0, sin(angle) * ring_r)
	var to: Vector3 = target - global_position
	to.y = 0.0
	if to.length() > 0.3:
		var dir: Vector3 = to.normalized()
		velocity.x = dir.x * 1.2
		velocity.z = dir.z * 1.2
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 6.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = -0.5
	move_and_slide()
	# pause briefly at each bali station (darshana beat)
	var station := fmod(angle, stone_every)
	if station < speed * delta * 1.5:
		pause_t = 2.0

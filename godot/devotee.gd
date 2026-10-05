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
var greet_cd := 0.0
var slot_note := ""  # set by demo from scheduler slot (darshana context)

var GREETS := [
	"Vanakkam.",
	"Vishnu's flag flies high today.",
	"The lamps will be lit soon.",
	"Walk softly near the balikkal.",
]

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
	greet_cd = maxf(0.0, greet_cd - delta)
	_greet()

func _greet() -> void:
	if greet_cd > 0.0:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	if to.length() > 2.5:
		return
	greet_cd = 8.0
	var line: String = GREETS[randi() % GREETS.size()]
	if slot_note != "":
		line = slot_note
	_say3d(line)

func _say3d(msg: String) -> void:
	var tag := get_node_or_null("GreetTag") as Label3D
	if tag == null:
		tag = Label3D.new()
		tag.name = "GreetTag"
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0, 2.0, 0)
		tag.font_size = 48
		add_child(tag)
	tag.text = msg

extends CharacterBody3D
# Ambient villager: wanders waypoint loops, greets, flees when struck.
# No combat, no HP bar. Joins "bandit" group so melee cleave scares it;
# apply_hit only frightens. School world spawns none (sacred training space).

const CombatState = preload("res://scripts/combat_state.gd")

@export var speed := 2.0
@export var flee_speed := 4.2

var combat = CombatState.new()
var loop: Array = []
var wp := 0
var wait_t := 0.0
var flee_t := 0.0
var greet_cd := 0.0
var _dead := false
var follow: Node3D = null

var GREETS := [
	"Vanakkam, traveler.",
	"Fresh fish today!",
	"The temple flag flies high.",
	"Blessings of Bhadrakali on you.",
	"Mind the bandits past the market.",
]
var chatter: Array = [] # pendant override (e.g. Kunjiraman)

func _ready() -> void:
	add_to_group("bandit")
	add_child(combat)
	combat.state = CombatState.S.STANCE
	wait_t = randf_range(0.0, 2.0)

func apply_hit(_dmg: float, _marma: bool = false) -> void:
	# Struck: flee, never fight back. (Heat consequences arrive in OW3.)
	flee_t = 3.0

func _physics_process(delta: float) -> void:
	combat.tick(delta)
	greet_cd = maxf(0.0, greet_cd - delta)
	var player = get_tree().get_first_node_in_group("player")
	if flee_t > 0.0 and is_instance_valid(player):
		flee_t -= delta
		var away: Vector3 = global_position - player.global_position
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3(1, 0, 0)
		velocity.x = away.normalized().x * flee_speed
		velocity.z = away.normalized().z * flee_speed
		rotation.y = lerp_angle(rotation.y, atan2(-away.x, -away.z), 8.0 * delta)
		velocity.y = -0.5
		move_and_slide()
		return
	if loop.is_empty() and (follow == null or not is_instance_valid(follow)):
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.5
		move_and_slide()
		return
	if follow != null and is_instance_valid(follow):
		var fto: Vector3 = follow.global_position - global_position
		fto.y = 0.0
		if fto.length() > 3.0:
			var fdir: Vector3 = fto.normalized()
			velocity.x = fdir.x * speed
			velocity.z = fdir.z * speed
			rotation.y = lerp_angle(rotation.y, atan2(-fdir.x, -fdir.z), 6.0 * delta)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		velocity.y = -0.5
		move_and_slide()
		_greet(follow if follow.is_in_group("player") else null)
		return
	if wait_t > 0.0:
		wait_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.5
		move_and_slide()
		_greet(player)
		return
	var target: Vector3 = loop[wp % loop.size()]
	var to: Vector3 = target - global_position
	to.y = 0.0
	if to.length() < 0.6:
		wp += 1
		wait_t = randf_range(2.0, 4.0)
		return
	var dir: Vector3 = to.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 6.0 * delta)
	velocity.y = -0.5
	move_and_slide()
	_greet(player)

func _greet(player: Node) -> void:
	if greet_cd > 0.0 or player == null or not is_instance_valid(player):
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	if to.length() > 2.0:
		return
	greet_cd = 8.0
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		var pool: Array = chatter if not chatter.is_empty() else GREETS
		hud.say("Kunjiraman: " + pool[randi() % pool.size()] if not chatter.is_empty() else "Villager: " + pool[randi() % pool.size()])

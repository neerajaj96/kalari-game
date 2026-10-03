extends CharacterBody3D
# Simple deterministic bandit AI: chase -> strike in range -> cooldown. No ML.

@export var speed := 2.8
@export var attack_range := 2.2
@export var damage := 10.0

var combat := CombatState.new()
var target: Node3D = null
var think_cd := 0.0

func _ready() -> void:
	add_to_group("bandit")
	add_child(combat)
	combat.state = CombatState.S.STANCE

var _dead := false

func apply_hit(dmg: float, is_marma: bool = false) -> void:
	if _dead:
		return
	combat.take_hit(dmg, is_marma)
	_flash()
	_hitstop()
	if combat.state == CombatState.S.DOWN:
		_die(is_marma)

func _flash() -> void:
	var body := get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var orig = body.material_override
	body.material_override = load("res://materials/shrine_yellow.tres")
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(body):
		body.material_override = orig

func _hitstop() -> void:
	Engine.time_scale = 0.15
	await get_tree().create_timer(0.05, true, false, true).timeout
	if is_inside_tree():
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _die(marma: bool) -> void:
	_dead = true
	var cam = get_tree().get_first_node_in_group("main_camera")
	if cam and cam.has_method("add_shake"):
		cam.add_shake(0.4)
	# Pay XP + quest kill. 60 bandit + 30 marma bonus (matches xp_sources).
	var game = get_tree().get_first_node_in_group("game")
	if game:
		if game.get("xp_rank") != null:
			var up: bool = game.xp_rank.add_xp(90 if marma else 60)
			if up and game.get("hud") != null:
				game.hud.say("Rank up! %s" % game.xp_rank.title())
		if game.get("quest_log") != null and game.quest_log.has_method("add_kill"):
			var k: int = game.quest_log.add_kill()
			if game.get("hud") != null:
				game.hud.say("Bandit down (%d). %s" % [k, "MARMA!" if marma else ""])
	# Fall + free. Rotation tween keeps it headless-safe (no particles needed).
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", -1.4, 0.4)
	tw.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	combat.tick(delta)
	if _dead:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.5
		move_and_slide()
		return
	think_cd -= delta
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player")
	if target == null:
		return
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist := to.magnitude()
	if dist > attack_range:
		var dir: Vector3 = to.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if think_cd <= 0.0:
			think_cd = 1.1
			if combat.try_strike(10.0) and target.has_method("apply_hit"):
				# Counter marma: exposed mid-swing target takes 1.5x.
				var exposed: bool = target.get("combat") != null and target.combat.state == CombatState.S.STRIKE
				target.apply_hit(damage, exposed)
	velocity.y = -0.5
	move_and_slide()

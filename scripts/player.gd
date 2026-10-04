extends CharacterBody3D
# Player: joystick (left) + buttons (right). Keyboard WASD/arrows fallback for PC test.
# Vadivu: block = Simha turtle, dodge = Sarpa slip.

const CombatState = preload("res://scripts/combat_state.gd")

@export var speed := 4.5
@export var turn_speed := 10.0

var combat := CombatState.new()
var move_vec := Vector2.ZERO
var want_strike := false
var want_block := false
var want_dodge := false
var cur_damage := 8.0
var cur_cost := 10.0

func _ready() -> void:
	add_child(combat)
	combat.state = CombatState.S.STANCE

func set_move(v: Vector2) -> void:
	move_vec = v

func request_strike(damage: float = 8.0, cost: float = 10.0) -> void:
	cur_damage = damage
	cur_cost = cost
	want_strike = true

func apply_hit(dmg: float, is_marma: bool = false) -> void:
	combat.take_hit(dmg, is_marma)
	_hitstop(0.05)
	_shake(0.5)
	if is_marma:
		_say("MARMA! +50%")

func _hitstop(dur: float = 0.06) -> void:
	# 60ms freeze frames the hit on mobile without particles.
	Engine.time_scale = 0.15
	await get_tree().create_timer(dur, true, false, true).timeout
	if is_inside_tree():
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0

var _dead := false

func _respawn_fall() -> void:
	# Kill-floor: any fall below the world seats the fighter back on spawn.
	_respawn_to_spawn()
	velocity = Vector3.ZERO
	_say("Gurukkal steadies you. Watch the pit edge.")

func _respawn_to_spawn() -> void:
	var w = get_tree().get_first_node_in_group("world")
	if w != null and w.get("current") != null:
		if "School" in str(w.current.name) and w.get("school_spawn") != null:
			position = w.school_spawn
			return
		if w.get("village_spawn") != null:
			position = w.village_spawn
			return
	position = Vector3(0, 1, 0)

func _check_death() -> void:
	if combat.state != CombatState.S.DOWN or _dead:
		return
	_dead = true
	_say("You fall. Gurukkal lifts you up...")
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	combat.hp = 100.0
	combat.stamina = 100.0
	combat.state = CombatState.S.STANCE
	_respawn_to_spawn()
	_dead = false
	_say("Back on your feet. Breathe.")

func _say(msg: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say(msg)

func _shake(amount: float) -> void:
	var cam = get_tree().get_first_node_in_group("main_camera")
	if cam and cam.has_method("add_shake"):
		cam.add_shake(amount)

func _count_rep() -> void:
	# Tutorial reps: Attack strikes inside the school pit count as mey reps.
	# At 5 reps the first quest pays out once.
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("quest_log") == null or not game.quest_log.has_method("add_reps"):
		return
	var w = get_tree().get_first_node_in_group("world")
	var in_school := w != null and w.get("current") != null and "School" in str(w.current.name)
	if not in_school:
		return
	var n: int = game.quest_log.add_reps(1)
	if n == 1 and game.quest_log.has_method("brief"):
		game.quest_log.brief("q01_first_earth")
	if game.get("xp_rank") != null and game.xp_rank.has_method("add_xp"):
		if n == 5:
			game.xp_rank.add_xp(120)
			if game.quest_log.has_method("mark_q01_done"):
				game.quest_log.mark_q01_done()
			_say("5 reps! Gurukkal nods. First quest done (+120 XP). Go Village.")
		elif n > 5:
			game.xp_rank.add_xp(1)

func _hit_sound(marma: bool) -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("audio") == null:
		return
	if marma and game.audio.has_method("marma_sting"):
		game.audio.marma_sting()
	elif game.audio.has_method("thock"):
		game.audio.thock()

func _ring_bell() -> void:	# Attack doubles as temple bell only at the sanctum door (OFFER phase).
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("rituals") == null:
		return
	if game.get("sadhana") == null or not game.sadhana.has_method("is_in_temple") or not game.sadhana.is_in_temple():
		return
	if not game.rituals.has_method("on_bell"):
		return
	var msg: String = game.rituals.on_bell()
	if msg != "":
		_say(msg)

var _rank_shown := 0

func set_rank(r: int) -> void:
	if r == _rank_shown:
		return
	_rank_shown = r
	var sash := get_node_or_null("RankSash") as MeshInstance3D
	if sash == null:
		return
	# Rank 1 white, 2 red, 3+ yellow (Gurukkal blessing). Preloaded at runtime, no extra APK weight.
	if r >= 3:
		sash.material_override = load("res://materials/shrine_yellow.tres")
	elif r == 2:
		sash.material_override = load("res://materials/sash_red.tres")
	else:
		sash.material_override = load("res://materials/cloth_white.tres")
	_equip_weapon(r)

func _equip_weapon(r: int) -> void:
	var pivot := get_node_or_null("WeaponPivot")
	var weapon := get_node_or_null("WeaponPivot/Weapon") as MeshInstance3D
	if pivot == null or weapon == null:
		return
	if r <= 1:
		weapon.visible = false # Verumkai fists
	elif r == 2:
		weapon.visible = true # Kettukari long staff
		weapon.scale = Vector3.ONE
	else:
		weapon.visible = true # Cheruvadi short stick
		weapon.scale = Vector3(1.4, 1.4, 0.45)

var _step_dist := 0.0
var _bob_t := 0.0
var _buff_regen := 1.0
var _buff_regen_t := 0.0
var _buff_marma := 1.0
var _buff_marma_t := 0.0

func add_buff(kind: String, mult: float, dur: float) -> void:
	if kind == "regen":
		_buff_regen = mult
		_buff_regen_t = dur
	elif kind == "marma":
		_buff_marma = mult
		_buff_marma_t = dur

func _physics_process(delta: float) -> void:
	combat.tick(delta)
	if position.y < -10.0:
		_respawn_fall()
		return
	if _buff_regen_t > 0.0:
		_buff_regen_t -= delta
		combat.regen_mult = _buff_regen
		if _buff_regen_t <= 0.0:
			combat.regen_mult = 1.0
			_buff_regen = 1.0
	if _buff_marma_t > 0.0:
		_buff_marma_t -= delta
		if _buff_marma_t <= 0.0:
			_buff_marma = 1.0
	var input_dir := Vector3(move_vec.x, 0, move_vec.y)
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	# Block/dodge slow movement (Simha root)
	var spd := speed
	if combat.state == CombatState.S.BLOCK:
		spd *= 0.2
	var target_vx := input_dir.x * spd
	var target_vz := input_dir.z * spd
	# Acceleration: heavy Kalari root, not ice-slide. 12/s ground, 3/s in HIT.
	var accel := 12.0 if combat.state != CombatState.S.HIT else 3.0
	var k: float = minf(1.0, accel * delta)
	velocity.x = lerpf(velocity.x, target_vx, k)
	velocity.z = lerpf(velocity.z, target_vz, k)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 9.8 * delta
	if input_dir.length() > 0.1:
		var target_yaw := atan2(-input_dir.x, -input_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)
	move_and_slide()

	# Footstep bob + dust: distance-driven so it matches speed, pauses in block.
	var planar := Vector2(velocity.x, velocity.z).length()
	_step_dist += planar * delta
	if planar > 0.5 and is_on_floor() and combat.state != CombatState.S.BLOCK:
		_bob_t += delta * planar * 2.2
		var dust := get_node_or_null("Dust") as CPUParticles3D
		if dust:
			dust.emitting = true
	else:
		var dust2 := get_node_or_null("Dust") as CPUParticles3D
		if dust2:
			dust2.emitting = false
	_apply_bob()

	if want_strike:
		want_strike = false
		if combat.try_strike(cur_cost):
			# Aswa lunge: 3.5 m/s forward burst so strikes connect.
			var fwd := -global_transform.basis.z
			fwd.y = 0.0
			velocity += fwd.normalized() * 3.5
			_shake(0.2)
			_ring_bell()
			_count_rep()
			var spark := get_node_or_null("HitSpark") as CPUParticles3D
			if spark:
				spark.restart()
			_deal_melee_delayed()
	if want_block:
		combat.try_block()
		want_block = false
	if want_dodge:
		want_dodge = false
		if combat.try_dodge():
			var cam = get_tree().get_first_node_in_group("main_camera")
			if cam and cam.has_method("kick_fov"):
				cam.kick_fov(6.0)
	_check_death()

func _apply_bob() -> void:
	# X-only sway: Vadivu owns all Y (crouch + base) so they never fight.
	var head := get_node_or_null("Head") as MeshInstance3D
	if head == null:
		return
	head.position.x = sin(_bob_t) * 0.02

func _deal_melee_delayed() -> void:
	await get_tree().create_timer(0.12, true, false, true).timeout
	if is_inside_tree():
		_deal_melee()

func _deal_melee() -> void:
	# 2.4m frontal 90-degree arc (dot 0.7). Back-stab = marma (1.5x).
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for e in get_tree().get_nodes_in_group("bandit"):
		if not is_instance_valid(e) or e.get("combat") == null:
			continue
		if e.combat.state == CombatState.S.DOWN: # already down
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() > 2.4:
			continue
		if fwd.dot(to.normalized()) < 0.7:
			continue
		# Marma if player is behind enemy (enemy facing away)
		var e_fwd: Vector3 = -e.global_transform.basis.z
		e_fwd.y = 0.0
		var behind: bool = e_fwd.normalized().dot((-to).normalized()) < -0.5
		if e.has_method("apply_hit"):
			e.apply_hit(cur_damage * _buff_marma, behind)
			_hit_sound(behind)
			if behind:
				_say("MARMA back-stab!")

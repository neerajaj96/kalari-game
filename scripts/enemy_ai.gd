extends CharacterBody3D
# Simple deterministic bandit AI: chase -> strike in range -> cooldown. No ML.

const CombatState = preload("res://scripts/combat_state.gd")
const FLASH_MAT = preload("res://materials/shrine_yellow.tres")

@export var speed := 3.6
@export var attack_range := 2.2
@export var damage := 10.0
@export var max_hp := 120.0
# Archetype presets (tscn overrides per spawn; default = current club bandit).
# spear: long reach, softer hits, slower feet. swift: fast feet, slips often, frail.
@export var archetype := "club"

var combat := CombatState.new()
var target: Node3D = null
var think_cd := 0.0
var _pending_hit := false
var is_guard := false

func _ready() -> void:
	add_to_group("bandit")
	add_child(combat)
	_apply_archetype()
	combat.hp = max_hp
	combat.state = CombatState.S.STANCE
	think_cd = randf_range(0.3, 1.1) # stagger pack attacks

func _apply_archetype() -> void:
	match archetype:
		"spear":
			# Long-limb lunger: steps in from outside club range. (No staff
			# prop yet — range stays honest to barehand visuals; a spear mesh
			# lands with the runtime weapon pass.)
			speed = 3.0
			attack_range = 2.6
			damage = 8.0
			max_hp = 100.0
		"swift":
			speed = 4.2
			attack_range = 2.0
			damage = 8.0
			max_hp = 80.0
		_:
			pass
	# Rank scaling: late-game bandits stay relevant as the player ranks up.
	var game = get_tree().get_first_node_in_group("game")
	if game != null and game.get("xp_rank") != null and game.xp_rank.get("rank") != null:
		var r: float = maxf(1.0, float(game.xp_rank.rank))
		max_hp = max_hp * (1.0 + 0.15 * (r - 1.0))
		damage = damage * (1.0 + 0.10 * (r - 1.0))

var _dead := false

func apply_hit(dmg: float, is_marma: bool = false) -> bool:
	if _dead:
		return false
	# Slip check FIRST: a successful dodge puts us in DODGE, which take_hit
	# then honors with zero damage (rolling after HIT could never fire).
	var slip := 0.6 if archetype == "swift" else 0.35
	if combat.state != CombatState.S.DOWN and randf() < slip:
		combat.try_dodge() # slip back, uses own stamina
	if not combat.take_hit(dmg, is_marma):
		return false # i-frames: no flash, freeze or sound on immune frames
	_flash(is_marma)
	_hitstop(is_marma)
	if combat.state == CombatState.S.DOWN:
		_die(is_marma)
	return true

func _flash(is_marma: bool = false) -> void:
	# Flash the VISIBLE body: cinematic segments when the rig built them,
	# else the legacy primitive. (Primitives hide under the cinematic body.)
	var targets := _visible_bodies()
	if targets.is_empty():
		return
	var origs: Array = []
	for mi in targets:
		origs.append(mi.material_override)
		mi.material_override = FLASH_MAT
	if is_marma:
		var cam = get_tree().get_first_node_in_group("main_camera")
		if cam and cam.has_method("add_shake"):
			cam.add_shake(0.35)
		await get_tree().create_timer(0.15).timeout
	else:
		await get_tree().create_timer(0.1).timeout
	for i in range(targets.size()):
		if is_instance_valid(targets[i]):
			targets[i].material_override = origs[i]

func _chain_visible(n: Node) -> bool:
	# LOD toggles ancestors, not the mesh: walk up to the skeleton.
	var c: Node = n
	while c != null and not (c is Skeleton3D):
		if c is BoneAttachment3D and not (c as BoneAttachment3D).visible:
			return false
		if c is MeshInstance3D and not (c as MeshInstance3D).visible:
			return false
		c = c.get_parent()
	return true

func _visible_bodies() -> Array:
	var out: Array = []
	var body := find_child("CinematicBody", true, false) as Node3D
	if body != null:
		var sk := body.find_child("HumanSkeleton", true, false) as Skeleton3D
		if sk != null:
			for ba in sk.get_children():
				if ba is BoneAttachment3D and str(ba.name).begins_with("Attach_chest"):
					for mi in ba.get_children():
						if mi is MeshInstance3D and _chain_visible(mi):
							out.append(mi)
							break
					if not out.is_empty():
						break
	if out.is_empty():
		var legacy := get_node_or_null("Body") as MeshInstance3D
		if legacy != null:
			out.append(legacy)
	return out

func _hitstop(marma: bool = false) -> void:
	await CombatState.hitstop(get_tree(), 0.08 if marma else 0.05)

func _exit_tree() -> void:
	CombatState.release_hitstop()

func _die(marma: bool) -> void:
	_dead = true
	var mark := get_node_or_null("MarmaMark") as Label3D
	if mark != null:
		mark.visible = false
	var cam = get_tree().get_first_node_in_group("main_camera")
	if cam and cam.has_method("add_shake"):
		cam.add_shake(0.4)
	# Pay XP + quest kill. 60 bandit + 30 marma bonus (matches xp_sources).
	# Guards pay nothing (spiral guard) but raise heat instead.
	var game = get_tree().get_first_node_in_group("game")
	if game:
		if is_guard:
			if game.get("heat") != null and game.heat.has_method("add"):
				game.heat.add(1)
			if game.get("hud") != null:
				game.hud.say("Guard down! Heat rises.")
		else:
			if game.get("xp_rank") != null and game.xp_rank.has_method("add_xp"):
				var up: bool = game.xp_rank.add_xp(90 if marma else 60)
				if up and game.get("hud") != null:
					game.hud.say("Rank up! %s" % game.xp_rank.title())
				if up and game.get("audio") != null and game.audio.has_method("fanfare"):
					game.audio.fanfare()
			if game.get("quest_log") != null and game.quest_log.has_method("add_kill"):
				var k: int = game.quest_log.add_kill(marma)
				if game.get("hud") != null:
					game.hud.say("Bandit down (%d). %s" % [k, "MARMA!" if marma else ""])
			if game.get("heat") != null and game.heat.has_method("add"):
				game.heat.add(2 if marma else 1)
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
	if target.get("combat") != null and int(target.combat.state) == CombatState.S.DOWN:
		# Victor's patience: stand ground while Gurukkal lifts the player.
		# Drop any primed windup so no stale hit fires after the wake-up.
		_pending_hit = false
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.5
		move_and_slide()
		_marma_mark(null)
		return
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > attack_range:
		var dir: Vector3 = to.normalized()
		# Pack separation: bandits steer off each other so the pack doesn't
		# merge into one body on the chase.
		var sep := Vector3.ZERO
		for b in get_tree().get_nodes_in_group("bandit"):
			if b == self or not is_instance_valid(b) or not (b is Node3D):
				continue
			var off: Vector3 = global_position - (b as Node3D).global_position
			off.y = 0.0
			var d := off.length()
			if d > 0.01 and d < 1.6:
				sep += off.normalized() * (1.6 - d)
		var heading: Vector3 = (dir + sep * 0.8).normalized() if sep.length() > 0.01 else dir
		velocity.x = heading.x * speed
		velocity.z = heading.z * speed
		rotation.y = lerp_angle(rotation.y, atan2(-heading.x, -heading.z), 8.0 * delta)
		_marma_mark(null)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		# Track the player in range so strikes (and the marma tell) face true.
		var fto: Vector3 = target.global_position - global_position if target != null and is_instance_valid(target) else Vector3.ZERO
		fto.y = 0.0
		if fto.length() > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(-fto.x, -fto.z), 8.0 * delta)
		_marma_mark(target)
		if think_cd <= 0.0:
			# Desync pack rhythm so volleys don't land on the same frame.
			think_cd = randf_range(0.9, 1.3)
			if combat.try_strike(10.0):
				_telegraph()
				_deal_delayed()
		if _pending_hit:
			_pending_hit = false
			_land_hit()

func _marma_mark(target: Node3D) -> void:
	# Gold "!" while the player holds side/back: teaches flanking without words.
	var mark := get_node_or_null("MarmaMark") as Label3D
	if mark == null or target == null or not is_instance_valid(target) or _dead:
		if mark != null:
			mark.visible = false
		return
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	if to.length() < 0.01:
		mark.visible = false
		return
	var e_fwd: Vector3 = -global_transform.basis.z
	e_fwd.y = 0.0
	mark.visible = e_fwd.normalized().dot((-to).normalized()) < 0.0

func _telegraph() -> void:
	# Fair windup cue: brief white flash on the VISIBLE body so mobile players
	# can read the incoming strike and block/dodge in time.
	var targets := _visible_bodies()
	if targets.is_empty():
		return
	var wink: StandardMaterial3D = load("res://materials/cloth_white.tres")
	var origs: Array = []
	for mi in targets:
		origs.append(mi.material_override)
		mi.material_override = wink
	var game0 = get_tree().get_first_node_in_group("game")
	if game0 != null and game0.get("audio") != null and game0.audio.has_method("whoosh"):
		game0.audio.whoosh()
	# Flash spans the full 0.3s windup so the cue never drops before the hit.
	await get_tree().create_timer(0.28, true, false, true).timeout
	if _dead:
		return
	for i in range(targets.size()):
		if is_instance_valid(targets[i]):
			targets[i].material_override = origs[i]

func _deal_delayed() -> void:
	# 0.3s windup reads fairly on mobile, then the hit lands. Undilated timer
	# so hitstop never stretches the telegraph; damage applied in physics.
	await get_tree().create_timer(0.3, true, false, true).timeout
	if not is_inside_tree() or _dead:
		return
	_pending_hit = true

func _land_hit() -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.get("combat") != null and int(target.combat.state) == CombatState.S.DOWN:
		return # fallen foe: hold, don't juggle the downed body
	var lto: Vector3 = target.global_position - global_position
	lto.y = 0.0
	if lto.length() > attack_range + 0.4 or not target.has_method("apply_hit"):
		return
	# Counter marma: exposed mid-swing target takes 1.5x.
	var exposed: bool = target.get("combat") != null and target.combat.state == CombatState.S.STRIKE
	target.apply_hit(damage, exposed)

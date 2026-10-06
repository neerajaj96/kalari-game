extends CharacterBody3D
# Ambient villager: wanders waypoint loops, greets, flees when struck.
# No combat, no HP bar. Joins "bandit" group so melee cleave scares it;
# apply_hit only frightens. School world spawns none (sacred training space).

const CombatState = preload("res://scripts/combat_state.gd")
const HumanDNA = preload("res://scripts/human/human_dna.gd")
const HumanFactory = preload("res://scripts/human/human_factory.gd")
# Wired cinematic PBR assets: shaders/human_skin.gdshader, shaders/cloth_weave.gdshader, shaders/hair_strand.gdshader

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

var EXCHANGES := [
	["Fish prices today?", "The Kolathiri taxed the catch again."],
	["Did you see the flag?", "The Dwaja climbs higher each week."],
	["Monsoon took the road.", "Walk the high bund, friend."],
	["Gurukkal has a new student.", "Then the pit dust rises again."],
	["Bandits past the market?", "Keep your staff ready, walk in pairs."],
	["Festival soon, they say.", "Bhadrakali willing, we will dance."],
]
var _talk_t := 0.0
var _talk_cd := 0.0
var _reply := ""
var _reply_t := 0.0
var _storm_told := false
var _cinematic: Node3D = null

func start_reply(line: String) -> void:
	_reply = line
	_reply_t = 1.5
	wait_t = maxf(wait_t, 2.0)

func _ready() -> void:
	add_to_group("bandit")
	add_child(combat)
	combat.state = CombatState.S.STANCE
	wait_t = randf_range(0.0, 2.0)
	_build_cinematic()

func _build_cinematic() -> void:
	# Deterministic per-villager identity from instance id (stable per spawn).
	var variant: int = abs(int(get_instance_id()) % 8)
	var dna: Resource = HumanDNA.villager_dna(variant)
	_cinematic = HumanFactory.build(self, dna)

func _process(delta: float) -> void:
	if _cinematic != null and is_instance_valid(_cinematic):
		var planar := Vector2(velocity.x, velocity.z).length()
		var local := Vector3.ZERO
		if planar > 0.01:
			local = global_transform.basis.inverse() * velocity
		var st := int(combat.state) if combat != null else 1
		# Fleeing villagers show fear; idlers stay neutral.
		HumanFactory.drive(_cinematic, delta, st, planar, local)
		var face := _cinematic.get_node_or_null("FaceAnim")
		if face != null and face.has_method("set_expression"):
			if flee_t > 0.0:
				face.set_expression("fear")
			elif _reply != "":
				face.set_expression("surprise")

func apply_hit(_dmg: float, _marma: bool = false) -> bool:
	# Struck: scream, flee, never fight back. Raising hands on villagers
	# draws Kolathiri heat.
	flee_t = 3.0
	_say("Ayyo! Guard! Guard!" if randf() < 0.5 else "Ayyo! My cart!")
	var game = get_tree().get_first_node_in_group("game")
	if game != null and game.get("heat") != null and game.heat.has_method("add"):
		game.heat.add(1)
	return true

func _physics_process(delta: float) -> void:
	combat.tick(delta)
	greet_cd = maxf(0.0, greet_cd - delta)
	_talk(delta)
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
	var pool: Array = chatter if not chatter.is_empty() else _gossip_pool()
	_say(("Kunjiraman: " if not chatter.is_empty() else "Villager: ") + pool[randi() % pool.size()])

func _gossip_pool() -> Array:
	# Quest-aware talk: streets discuss live plot + heat state.
	var game = get_tree().get_first_node_in_group("game")
	var pool: Array = GREETS.duplicate()
	if game:
		if game.get("plot") != null and game.plot.get("phase") != null and game.plot.phase >= 4:
			pool.append("They raised the Dwaja yesterday!")
		if game.get("heat") != null and game.heat.get("heat") != null and game.heat.heat > 0:
			pool.append("Keep your blade sheathed, friend.")
	return pool

func _talk(delta: float) -> void:
	# Ped-to-ped exchanges with a nearby idler; storm remark once per storm.
	if _reply != "":
		_reply_t -= delta
		if _reply_t <= 0.0:
			_say("Villager: " + _reply)
			_reply = ""
	_talk_t += delta
	_talk_cd = maxf(0.0, _talk_cd - delta)
	if _storm_watch(delta):
		return
	if _talk_t < 4.0 or _talk_cd > 0.0:
		return
	_talk_t = 0.0
	if not chatter.is_empty():
		return # pendant stays in role
	for b in get_tree().get_nodes_in_group("ped"):
		if b == self or not is_instance_valid(b):
			continue
		if b.global_position.distance_to(global_position) > 3.0:
			continue
		if not b.has_method("start_reply"):
			continue
		_talk_cd = 25.0
		wait_t = maxf(wait_t, 2.0)
		var pair: Array = EXCHANGES[randi() % EXCHANGES.size()]
		_say("Villager: " + pair[0])
		b.start_reply(pair[1])
		return

func _storm_watch(_delta: float) -> bool:
	var game = get_tree().get_first_node_in_group("game")
	var storm := 0.0
	if game:
		var w = get_tree().get_first_node_in_group("world")
		if w != null and w.get("current") != null:
			# Storm lives on the world root, except ksetra where DayNight owns it.
			if w.current.get("storm") != null:
				storm = float(w.current.storm)
			else:
				var dn: Node = w.current.get_node_or_null("DayNight")
				if dn != null and dn.get("storm") != null:
					storm = float(dn.get("storm"))
	if storm >= 0.5 and not _storm_told:
		_storm_told = true
		_say("Rain takes the road — walk high ground.")
		return true
	if storm < 0.5:
		_storm_told = false
	return false

func _say(msg: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say(msg)

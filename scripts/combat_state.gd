extends Node
# Deterministic FSM - no ML (Laya/Jev deliberately NOT used for 60fps combat).
# States: Idle/Stance/Strike/Block/Dodge/Hit. Marma crit on side/back hits.
class_name CombatState

enum S { IDLE, STANCE, STRIKE, BLOCK, DODGE, HIT, DOWN }

var state: int = S.IDLE
var stamina: float = 100.0
var hp: float = 100.0
var strike_cd: float = 0.0
var recover_cd: float = 0.0 # hold time for BLOCK/DODGE/HIT poses
var dodge_cd: float = 0.0 # anti-turtle: dodge chains gated
var hurt_cd: float = 0.0 # post-hit i-frames: alternating attackers can't stunlock

const STAMINA_REGEN := 18.0
var regen_mult := 1.0

static var _hitstop_locks := 0

static func hitstop(tree: SceneTree, dur: float = 0.06) -> void:
	# Central freeze-frame: simultaneous player+enemy hits ref-count instead
	# of racing Engine.time_scale back to 1.0 early.
	_hitstop_locks += 1
	Engine.time_scale = 0.15
	await tree.create_timer(dur, true, false, true).timeout
	_hitstop_locks -= 1
	if _hitstop_locks <= 0:
		_hitstop_locks = 0
		Engine.time_scale = 1.0

static func release_hitstop() -> void:
	# Scene exit during a freeze: drop leaked locks so time never sticks.
	# Accepted tradeoff: this also cuts a concurrent other's remaining ~60ms
	# freeze short. Correctness (never stuck at 0.15x) beats 60ms of slow-mo.
	_hitstop_locks = 0
	Engine.time_scale = 1.0

func can_act() -> bool:
	return state == S.IDLE or state == S.STANCE

func try_strike(cost: float) -> bool:
	if stamina < cost or strike_cd > 0.0:
		return false
	if not can_act():
		return false
	stamina -= cost
	state = S.STRIKE
	strike_cd = 0.45
	return true

func try_block(hold: float = 0.6) -> bool:
	if not can_act():
		return false
	state = S.BLOCK
	recover_cd = hold
	return true

func try_dodge(cost: float = 12.0, hold: float = 0.5) -> bool:
	if stamina < cost or dodge_cd > 0.0 or not can_act():
		return false
	stamina -= cost
	state = S.DODGE
	recover_cd = hold
	dodge_cd = 0.8
	return true

func take_hit(dmg: float, is_marma: bool = false) -> bool:
	if state == S.DOWN:
		return false # corpses don't flinch
	if hurt_cd > 0.0 and not is_marma:
		return false # i-frames: already reeling, extra hits don't chain
	var guard_broke := false
	if state == S.BLOCK:
		if stamina >= 12.0:
			stamina -= 12.0
			dmg *= 0.25
		else:
			guard_broke = true # guard broken: full damage + long stagger
	elif state == S.DODGE:
		dmg = 0.0
	if is_marma:
		dmg *= 1.5
	hp -= dmg
	if hp <= 0.0:
		hp = 0.0
		state = S.DOWN
	elif dmg > 0.0:
		state = S.HIT
		recover_cd = 0.8 if guard_broke else 0.4
		hurt_cd = 0.6
	return dmg > 0.0 or state == S.DOWN

func tick(delta: float) -> void:
	strike_cd = maxf(0.0, strike_cd - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	hurt_cd = maxf(0.0, hurt_cd - delta)
	recover_cd = maxf(0.0, recover_cd - delta)
	# Braced guard breathes slowly: turtling drains against focus pressure.
	var regen := STAMINA_REGEN * regen_mult
	if state == S.BLOCK:
		regen *= 0.35
	stamina = minf(100.0, stamina + regen * delta)
	if state == S.STRIKE and strike_cd <= 0.15:
		state = S.STANCE
	elif state in [S.HIT, S.BLOCK, S.DODGE] and recover_cd <= 0.0:
		state = S.STANCE

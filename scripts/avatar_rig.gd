extends Node
# Rig host for the Quaternius era. Until art/characters/player/regular_male.glb
# lands, this is a pure no-op: the primitive bodies (posed by vadivu_pose.gd)
# carry the frame. With the GLB present: instance the rig under the character
# root, hide the primitives (collision untouched), and drive a code-built
# AnimationTree from CombatState ints. Non-root-motion clips only: player.gd
# owns displacement (Aswa lunge + move_and_slide).
class_name AvatarRig

const HumanDNA = preload("res://scripts/human/human_dna.gd")
const HumanFactory = preload("res://scripts/human/human_factory.gd")
# Wired cinematic PBR assets (kept as refs so export packaging includes them):
# shaders/human_skin.gdshader, shaders/cloth_weave.gdshader, shaders/hair_strand.gdshader

@export var rig_path := "res://art/characters/player/regular_male.glb"
const ANIM_DIR := "res://art/animations/"
# CombatState S ints: IDLE 0, STANCE 1, STRIKE 2, BLOCK 3, DODGE 4, HIT 5, DOWN 6.
const ANIMS := {
	0: "idle.glb", 1: "idle.glb",
	2: "attack_1.glb", 3: "block.glb", 4: "dodge.glb",
	5: "hit.glb", 6: "death.glb",
}
const STATE_NODES := {
	0: "idle", 1: "idle", 2: "strike", 3: "block",
	4: "dodge", 5: "hit", 6: "death",
}
# Primitive roots hidden when the rig takes over (guards skip any missing).
const PRIMITIVES := ["Body", "Head", "ArmL", "ArmR", "LegL", "LegR", "FootL", "FootR", "Beard", "Angavastram"]

var active := false
var _tree: AnimationTree
var _last_state := -1
var _cinematic: Node3D = null
var _cinematic_active := false

func _dna_for_path() -> Resource:
	var rp := str(rig_path)
	var p := get_parent()
	var inst := abs(int(p.get_instance_id()) % 8) if p != null else 0
	if rp.find("gurukkal") >= 0 or rp.find("elder") >= 0:
		return HumanDNA.gurukkal_dna()
	if rp.find("bandit") >= 0 or rp.find("brute") >= 0:
		# Archetype-stable faces: clubs brawl scarred, spears lean, swifts wiry.
		var arch := str(p.get("archetype")) if p != null and p.get("archetype") != null else "club"
		if arch == "spear":
			return HumanDNA.bandit_dna(2)
		if arch == "swift":
			return HumanDNA.bandit_dna(3)
		return HumanDNA.bandit_dna(inst % 2)
	if rp.find("ped") >= 0 or rp.find("villager") >= 0:
		return HumanDNA.villager_dna(inst)
	return HumanDNA.player_dna()

func _ready() -> void:
	if not FileAccess.file_exists(rig_path):
		_build_cinematic_fallback()
		return
	var ps: PackedScene = load(rig_path)
	if ps == null:
		return
	var p := get_parent()
	var rig := ps.instantiate()
	rig.name = "RiggedBody"
	p.add_child(rig)
	for n in PRIMITIVES:
		var old := p.get_node_or_null(n) as VisualInstance3D
		if old:
			old.visible = false
	if _build_tree(p, rig):
		active = true

func _build_cinematic_fallback() -> void:
	# Cinematic procedural human: replaces visible primitives with sculpted
	# Hero/Mid/Far geometry + skeleton + PBR. Collision untouched.
	var p := get_parent()
	if p == null:
		return
	var dna: Resource = _dna_for_path()
	_cinematic = HumanFactory.build(p, dna)
	_cinematic_active = _cinematic != null

func _build_tree(p: Node, rig: Node) -> bool:
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return false
	_tree = AnimationTree.new()
	_tree.anim_player = rig.get_path_to(player)
	var sm := AnimationNodeStateMachine.new()
	for sname in ["idle", "strike", "block", "dodge", "hit", "death"]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = StringName(sname)
		sm.add_node(sname, clip)
	sm.start_node = "idle"
	for sname in ["strike", "block", "dodge", "hit", "death"]:
		var out := AnimationNodeStateMachineTransition.new()
		var back := AnimationNodeStateMachineTransition.new()
		sm.add_transition("idle", sname, out)
		sm.add_transition(sname, "idle", back)
	_tree.tree_root = sm
	p.add_child(_tree)
	_tree.active = true
	return true

func _process(delta: float) -> void:
	if _cinematic_active and _cinematic != null and is_instance_valid(_cinematic):
		_drive_cinematic(delta)
	if not active:
		return
	var p = get_parent()
	if p == null:
		return
	if p.get("combat") == null:
		_tree.travel("idle") # non-combat characters rest in idle.
		active = false # one-shot; no state to track.
		return
	var st: int = p.combat.state
	if st == _last_state:
		return
	_last_state = st
	_tree.travel(STATE_NODES.get(st, "idle"))

func _drive_cinematic(delta: float) -> void:
	var p = get_parent()
	if p == null:
		return
	var st := 1
	if p.get("combat") != null:
		st = int(p.combat.state)
	var planar := 0.0
	var local := Vector3.ZERO
	if p.get("velocity") != null:
		var v: Vector3 = p.velocity
		planar = Vector2(v.x, v.z).length()
		if planar > 0.01:
			local = p.global_transform.basis.inverse() * v
	HumanFactory.drive(_cinematic, delta, st, planar, local)
	HumanFactory.follow_weapon(p)

extends Node
# Rig host for the Quaternius era. Until art/characters/player/regular_male.glb
# lands, this is a pure no-op: the primitive bodies (posed by vadivu_pose.gd)
# carry the frame. With the GLB present: instance the rig under the character
# root, hide the primitives (collision untouched), and drive a code-built
# AnimationTree from CombatState ints. Non-root-motion clips only: player.gd
# owns displacement (Aswa lunge + move_and_slide).
class_name AvatarRig

const RIG_PATH := "res://art/characters/player/regular_male.glb"
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
const PRIMITIVES := ["Body", "Head", "ArmL", "ArmR", "LegL", "LegR", "FootL", "FootR"]

var active := false
var _tree: AnimationTree
var _last_state := -1

func _ready() -> void:
	if not FileAccess.file_exists(RIG_PATH):
		return # fallback era: primitives carry the frame.
	var ps: PackedScene = load(RIG_PATH)
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

func _process(_delta: float) -> void:
	if not active:
		return
	var p = get_parent()
	if p == null or p.get("combat") == null:
		return
	var st: int = p.combat.state
	if st == _last_state:
		return
	_last_state = st
	_tree.travel(STATE_NODES.get(st, "idle"))

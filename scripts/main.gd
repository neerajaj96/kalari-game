extends Node3D
# Main: world + player + xp + hud wiring. Player persists across world switches.

const XPRank = preload("res://scripts/xp_rank.gd")

var xp_rank = XPRank.new()
var quest_log := Node.new()
var rituals := Node.new()
var sadhana := Node.new()
var plot := Node.new()
var vama := Node.new()
var player: CharacterBody3D
var hud: CanvasLayer

func _ready() -> void:
	add_to_group("game")
	add_child(xp_rank)
	_attach(quest_log, "res://scripts/quests.gd")
	_attach(rituals, "res://scripts/rituals.gd")
	_attach(sadhana, "res://scripts/sadhana.gd")
	_attach(plot, "res://scripts/temple_plot.gd")
	_attach(vama, "res://scripts/vama.gd")
	# HUD first so load failures always have a voice.
	var hs: PackedScene = load("res://scenes/ui/hud.tscn")
	if hs == null:
		push_error("hud.tscn missing")
		return
	hud = hs.instantiate()
	hud.add_to_group("hud")
	add_child(hud)
	hud.say("Loading Kalari...")
	var world := Node3D.new()
	world.add_to_group("world")
	if not _attach(world, "res://scripts/world_loader.gd"):
		hud.say("BOOT ERROR: world loader missing. Note this text and report it.")
		return
	# Player
	var ps: PackedScene = load("res://scenes/player.tscn")
	if ps == null:
		hud.say("BOOT ERROR: player scene missing. Note this text and report it.")
		return
	player = ps.instantiate()
	player.add_to_group("player")
	add_child(player)
	player.position = Vector3(0, 1, 0)
	if world.has_method("_place_player"):
		world._place_player()
	hud.bind(player, xp_rank)
	hud.say("Vanakkam. Touch earth: do 5 reps (Attack) then go Village.")

func _attach(n: Node, path: String) -> bool:
	var s: Script = load(path)
	if s == null:
		push_error("missing script " + path)
		return false
	n.set_script(s)
	add_child(n)
	return true

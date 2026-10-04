extends Node3D
# Main: world + player + xp + hud wiring. Player persists across world switches.

const XPRank = preload("res://scripts/xp_rank.gd")

var xp_rank = XPRank.new()
var quest_log := Node.new()
var rituals := Node.new()
var sadhana := Node.new()
var plot := Node.new()
var vama := Node.new()
var heat := Node.new()
var save := Node.new()
var audio := Node.new()
var dialogue := Node.new()
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
	_attach(heat, "res://scripts/heat.gd")
	_attach(audio, "res://scripts/ambience.gd")
	_attach(dialogue, "res://scripts/dialogue.gd")
	_attach(save, "res://scripts/save_game.gd")
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
	if save.has_method("load_game") and save.has_method("apply_save"):
		var d: Dictionary = save.load_game()
		if not d.is_empty():
			save.apply_save(d, self)
			if str(d.get("world", "")) == "Village" and world.has_method("go_village"):
				world.go_village()
				if world.has_method("_place_player"):
					world._place_player()
			hud.say("Welcome back. Progress restored.")
		else:
			_overture()
	else:
		hud.say("Vanakkam. Touch earth: do 5 reps (Attack) then go Village.")

var _ov_lines := [
	"Gurukkal: This is Chirakkal. The pit made warriors; the temple will make them endure.",
	"Gurukkal: Train your breath, your hands, your eyes. The bandits test all three.",
	"Gurukkal: The temple rises — if you help raise it. Touch earth: 5 reps (Attack).",
]
var _ov_i := -1

func _overture() -> void:
	if audio != null and audio.has_method("overture"):
		audio.overture()
	_ov_i = 0
	hud.say(_ov_lines[0])

func _unhandled_input(event: InputEvent) -> void:
	# Intro advance only for taps the GUI didn't consume (buttons work first),
	# and never from the joystick zone (movement isn't dialogue).
	if _ov_i < 0 or _ov_i >= _ov_lines.size():
		return
	var pos := Vector2(-1, -1)
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pos = event.position
	else:
		return
	if pos.x >= 0.0 and pos.x < get_viewport().get_visible_rect().size.x * 0.4:
		return
	_ov_i += 1
		if _ov_i < _ov_lines.size():
			hud.say(_ov_lines[_ov_i])
			if audio != null and audio.has_method("bell") and _ov_i == 2:
				audio.bell()
		else:
			_ov_i = -1
			hud.say("Vanakkam. Touch earth: do 5 reps (Attack) then go Village.")

func _attach(n: Node, path: String) -> bool:
	var s: Script = load(path)
	if s == null:
		push_error("missing script " + path)
		return false
	n.set_script(s)
	add_child(n)
	return true

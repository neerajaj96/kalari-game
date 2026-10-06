extends Node3D
# HeroAudit: close-up runtime validation harness for the cinematic player hero.
# Runs unmodified on PC (Forward+) and Android ARM64 (Mobile), and stays safe
# headless (fast self-cycle + optional auto-quit for CI logs).
# NOT a gameplay scene: visual audit only. Gameplay collision, CombatState and
# world wiring are untouched; open with: godot --path . res://scenes/hero_audit.tscn
# Controls (PC): 1/2/3 views, SPACE next pose, E next expression, M march,
#   L LOD pin (auto/hero/mid/far), S/F12 screenshot to user://,
#   single click advances view.
# Controls (Android): single tap advances view, two-finger tap screenshots.
# Auto pose/expression/view cycling runs on all platforms so the audit works
# with zero input (required for device + headless runs).
class_name HeroAudit

const HumanDNA = preload("res://scripts/human/human_dna.gd")
const HumanFactory = preload("res://scripts/human/human_factory.gd")

const VIEW_NAMES := ["front", "three_quarter", "profile"]
const POSE_STATES := [1, 2, 3, 4, 5, 0, 6, -1]
const POSE_NAMES := ["STANCE", "STRIKE", "BLOCK", "DODGE", "HIT", "IDLE", "DOWN", "MARCH"]
const EXPRESSIONS := ["neutral", "focus", "anger", "fear", "pain", "surprise", "effort", "recovery"]

const POSE_HOLD := 3.0
const EXPR_HOLD := 3.0
const VIEW_HOLD := 9.0
const MARCH_SPEED := 2.2

var _body: Node3D = null
var _face: Node = null
var _cam: Camera3D = null
var _label: Label = null
var _view := 0
var _pose_i := 0
var _expr_i := 0
var _t_pose := 0.0
var _t_expr := 0.0
var _t_view := 0.0
var _t_run := 0.0
var _t_label := 0.0
var _shots := 0
var _auto_quit := false
var _headless := false
var _pin_lod := -1
var _seen_views := {}
var _seen_poses := {}
var _seen_exprs := {}

func _ready() -> void:
	_cam = get_node_or_null("Camera3D") as Camera3D
	_headless = DisplayServer.get_name() == "headless"
	_auto_quit = "--audit-quit" in OS.get_cmdline_user_args()
	var dna: Resource = HumanDNA.player_dna()
	_body = HumanFactory.build(self, dna)
	if _body != null:
		_face = _body.get_node_or_null("FaceAnim")
	_make_overlay()
	_apply_view()
	_log("ready headless=%s auto_quit=%s (v0.30.0-cinematic baseline, NOT validated)" % [str(_headless), str(_auto_quit)])

func _process(delta: float) -> void:
	if _body == null or not is_instance_valid(_body):
		return
	_t_run += delta
	_t_pose += delta
	_t_expr += delta
	_t_view += delta
	if _t_pose >= POSE_HOLD:
		_t_pose = 0.0
		_pose_i = (_pose_i + 1) % POSE_STATES.size()
		_apply_pose()
	if _t_expr >= EXPR_HOLD:
		_t_expr = 0.0
		_expr_i = (_expr_i + 1) % EXPRESSIONS.size()
		_apply_expr()
	if _t_view >= VIEW_HOLD:
		_t_view = 0.0
		_view = (_view + 1) % VIEW_NAMES.size()
		_apply_view()
		if _auto_quit:
			# Headless coverage includes LOD pins (auto/hero/mid/far).
			var order := [-1, 0, 1, 2]
			_pin_lod = order[(order.find(_pin_lod) + 1) % order.size()]
			_apply_lod_pin()
	_drive(delta)
	_tick_label(delta)
	if _auto_quit and _t_run >= 40.0:
		_log("auto-quit coverage views=%d/3 poses=%d/8 exprs=%d/8 (headless log only, NOT a visual pass)" % [_seen_views.size(), _seen_poses.size(), _seen_exprs.size()])
		get_tree().quit()

func _drive(delta: float) -> void:
	var slot: int = POSE_STATES[_pose_i]
	var st := slot
	var planar := 0.0
	var lock := ""
	if slot == -1:
		st = 1
		planar = MARCH_SPEED
		lock = EXPRESSIONS[_expr_i]
	elif slot == 0 or slot == 1:
		lock = EXPRESSIONS[_expr_i]
	elif slot == 2 or slot == 5:
		# Re-pulse strike/hit so the motion (not just the settle pose) is observable.
		st = slot if fmod(_t_pose, 1.0) < 0.55 else 1
	HumanFactory.drive(_body, delta, st, planar, Vector3.ZERO, lock)

func _apply_view() -> void:
	if _cam == null:
		return
	match VIEW_NAMES[_view]:
		"front":
			_cam.position = Vector3(0, 1.55, -2.3)
		"three_quarter":
			_cam.position = Vector3(-1.7, 1.7, -1.7)
		_:
			_cam.position = Vector3(-2.4, 1.55, 0.1)
	_cam.look_at(Vector3(0, 1.25, 0))
	_seen_views[_view] = true
	_log("view=%s" % VIEW_NAMES[_view])

func _apply_pose() -> void:
	_t_pose = 0.0
	_seen_poses[_pose_i] = true
	_log("pose=%s" % POSE_NAMES[_pose_i])

func _apply_expr() -> void:
	_t_expr = 0.0
	_seen_exprs[_expr_i] = true
	if _face != null and _face.has_method("set_expression"):
		_face.set_expression(EXPRESSIONS[_expr_i])
	_log("expression=%s" % EXPRESSIONS[_expr_i])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if event.index > 0:
			_shot("touch")
		else:
			_view = (_view + 1) % VIEW_NAMES.size()
			_t_view = 0.0
			_apply_view()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_view = (_view + 1) % VIEW_NAMES.size()
		_t_view = 0.0
		_apply_view()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_view = 0
				_t_view = 0.0
				_apply_view()
			KEY_2:
				_view = 1
				_t_view = 0.0
				_apply_view()
			KEY_3:
				_view = 2
				_t_view = 0.0
				_apply_view()
			KEY_SPACE:
				_pose_i = (_pose_i + 1) % POSE_STATES.size()
				_apply_pose()
			KEY_E:
				_expr_i = (_expr_i + 1) % EXPRESSIONS.size()
				_apply_expr()
			KEY_S, KEY_F12:
				_shot("key")
			KEY_L:
				# LOD pin cycle: auto -> hero -> mid -> far (pop inspection).
				var order := [-1, 0, 1, 2]
				_pin_lod = order[(order.find(_pin_lod) + 1) % order.size()]
				_apply_lod_pin()

func _apply_lod_pin() -> void:
	if _body != null:
		var lod = _body.get_node_or_null("HumanLOD")
		if lod != null and lod.get("force_lod") != null:
			lod.set("force_lod", _pin_lod)
	_log("lod_pin=%s" % ("auto" if _pin_lod < 0 else str(_pin_lod)))

func _shot(tag: String) -> void:
	if _headless:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shots += 1
	var path := "user://hero_audit_%s_%02d.png" % [tag, _shots]
	if img.save_png(path) == OK:
		_log("screenshot " + path)
	else:
		_log("screenshot FAILED " + path)

func _make_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AuditOverlay"
	add_child(layer)
	_label = Label.new()
	_label.name = "AuditLabel"
	_label.add_theme_font_size_override("font_size", 20)
	_label.position = Vector2(16, 16)
	layer.add_child(_label)

func _tick_label(delta: float) -> void:
	_t_label += delta
	if _t_label < 0.25 or _label == null:
		return
	_t_label = 0.0
	var fps := Engine.get_frames_per_second()
	_label.text = "HERO AUDIT (PENDING, not validated)\nview=%s pose=%s expr=%s lod=%s fps=%d shots=%d\ntap/click=view 2-finger/S=screenshot L=lod-pin" % [
		VIEW_NAMES[_view], POSE_NAMES[_pose_i], EXPRESSIONS[_expr_i], ("auto" if _pin_lod < 0 else str(_pin_lod)), fps, _shots]

func _log(msg: String) -> void:
	print("[HERO_AUDIT] " + msg)

extends Node3D
# Playable Vishnu-dvitala demo: orbit/zoom camera, click any member for its
# OBJECT -> RULE -> SOURCE chain. Launched directly (no HUD/world changes).
# Provenance: TS-P2V1-measure (massing), TS-P2V2-yoni (pairing), TS-P3V1-material.

const Builder = preload("res://godot/ksetra_builder.gd")
const Sched = preload("res://godot/scheduler.gd")
const Prov = preload("res://godot/provenance_lookup.gd")
const Inv = preload("res://godot/inventory.gd")
const Devotee = preload("res://godot/devotee.gd")

var _yaw := 0.6
var _pitch := 0.5
var _dist := 26.0
var _target := Vector3(0, 2.5, 0)
var _cam: Camera3D
var _label: Label
var _prov = RefCounted.new()
var _slices := ["res://data/ksetra_vishnu_dvitala.json", "res://data/ksetra_shiva_ekatala.json"]
var _slice_i := 0
var _built: Node3D = null

func _ready() -> void:
	_cam = get_node_or_null("Camera") as Camera3D
	_label = get_node_or_null("ProvenanceUI/ProvenanceLabel") as Label
	var inv := Node.new()
	inv.set_script(Inv)
	inv.name = "KsetraInventory"
	add_child(inv)
	var sched := Node.new()
	sched.set_script(Sched)
	sched.name = "KsetraScheduler"
	add_child(sched)
	sched.inventory = inv
	sched.slot_opened.connect(func(id: String) -> void: _say("Nitya slot open: " + id + ". " + inv.summary()))
	sched.slot_opened.connect(_on_slot)
	sched.rite_stepped.connect(func(id: String) -> void: _say("Adhivasa rite: " + id + ". " + inv.summary()))
	sched.step_waiting.connect(func(id: String, why: String) -> void: _say("Waiting: " + id + " — " + why + ". " + inv.summary()))
	_build_slice(0)
	print("KSETRA DEMO OK: built + scheduler + provenance index live")

func _build_slice(i: int) -> void:
	_slice_i = i
	if _built != null:
		_built.queue_free()
		_built = null
	var b := Node3D.new()
	b.set_script(Builder)
	add_child(b)
	if not b.build_from(_slices[_slice_i]):
		_say("BUILD FAIL: " + str(b.errors))
		return
	_built = b
	var f := FileAccess.open(_slices[_slice_i], FileAccess.READ)
	var spec: Dictionary = JSON.parse_string(f.get_as_text())
	_prov.set_script(Prov)
	if not _prov.load_index(spec, "res://data/ksetra_rules.json"):
		_say("Provenance index missing.")
		return
	var meta: Dictionary = spec.get("meta", {})
	_spawn_devotees(float(spec.get("prasada", {}).get("uttara_hasta", 12.0)) * 0.72 + 2.5)
	_say(str(meta.get("name", "?")) + " (K = toggle slice. Drag orbit, wheel zoom, click member.)")

var _crowd: Array = []

func _on_slot(slot_id: String) -> void:
	# Crowd responds to the ritual clock: lamp slots gather attention, all note the hour.
	var notes := {
		"deeparadhana": "Deeparadhana — lamps lit.",
		"ucha": "Ucha — midday offerings.",
		"athazha": "Athazha — night rest.",
		"usha": "Usha — dawn worship.",
		"pantheeradi": "Pantheeradi — morning rite.",
	}
	for d in _crowd:
		if is_instance_valid(d):
			d.set("slot_note", str(notes.get(slot_id, "")))
			if slot_id in ["deeparadhana", "ucha"] and d.get("pause_t") != null:
				d.set("pause_t", 5.0)  # darshana beat for grand slots

func _spawn_devotees(ring_r: float) -> void:
	# Ambient pradakshina crowd (6 sevakas); cleared and re-seeded per slice.
	_crowd.clear()
	for c in get_children():
		if c is CharacterBody3D and c.has_method("_physics_process") and c.get_script() == Devotee:
			c.queue_free()
	for i in range(6):
		var d := CharacterBody3D.new()
		d.set_script(Devotee)
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.6
		col.shape = cap
		col.position = Vector3(0, 0.8, 0)
		d.add_child(col)
		var body := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.3
		mesh.height = 1.2
		body.mesh = mesh
		body.position = Vector3(0, 0.9, 0)
		d.add_child(body)
		add_child(d)
		d.ring_r = ring_r
		d.angle = TAU * float(i) / 6.0
		d.global_position = Vector3(cos(d.angle) * ring_r, 0.1, sin(d.angle) * ring_r)
		d.set_meta("provenance", ["TS-P2V2-yoni"])
		_crowd.append(d)

func _process(_delta: float) -> void:
	if _cam == null:
		return
	var off := Vector3(cos(_pitch) * cos(_yaw), sin(_pitch), cos(_pitch) * sin(_yaw)) * _dist
	_cam.global_position = _target + off
	_cam.look_at(_target)

func _hud_zone(xy: Vector2) -> bool:
	# Left 40% belongs to the HUD joystick/movement; orbit/pick stay right.
	return xy.x < get_viewport().get_visible_rect().size.x * 0.4

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _hud_zone((event as InputEventMouseMotion).position):
		return
	if event is InputEventMouseButton and _hud_zone((event as InputEventMouseButton).position):
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_K:
			_build_slice((_slice_i + 1) % _slices.size())
			return
		if (event as InputEventKey).keycode == KEY_A:
			var sched := get_node_or_null("KsetraScheduler")
			if sched and sched.has_method("start_adhivasa"):
				_say("Adhivasa program begun: " + str(sched.start_adhivasa()))
			return
		if (event as InputEventKey).keycode == KEY_X:
			# Defilement drill (SESHA-P6V01): sthana-shuddhi then pratima-shuddhi, remedy cycles.
			_say("Defilement reported. Prayaschitta at once: sthana-shuddhi, then pratima-shuddhi. Remedies cycle: khanana, harana, daha, purana, go-nivasana.")
			return
		if (event as InputEventKey).keycode == KEY_F:
			# Seva fetch: restock the current slot's offering (mirrors market FETCH loop).
			var sched2 = get_node_or_null("KsetraScheduler")
			var inv := get_node_or_null("KsetraInventory")
			if sched2 and inv and inv.has_method("fetch"):
				var cur: Dictionary = sched2.current() if sched2.has_method("current") else {}
				var item := str(cur.get("fetch", "flowers"))
				inv.fetch(item, 3)
				_say("Fetched 3 " + item + ". " + (inv.summary() if inv.has_method("summary") else ""))
			return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= (event as InputEventMouseMotion).relative.x * 0.008
		_pitch = clampf(_pitch + (event as InputEventMouseMotion).relative.y * 0.008, 0.15, 1.3)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = clampf(_dist - 1.5, 8.0, 60.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = clampf(_dist + 1.5, 8.0, 60.0)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_pick(mb.position)

func _pick(screen_xy: Vector2) -> void:
	if _cam == null:
		return
	var from := _cam.project_ray_origin(screen_xy)
	var to := from + _cam.project_ray_normal(screen_xy) * 120.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var n: Node = hit.get("collider")
	while n != null and not n.has_meta("provenance"):
		n = n.get_parent()
	if n == null:
		return
	var prov: Array = n.get_meta("provenance")
	_say(str(n.name) + ": " + _prov.chain_for(str(prov[0])))

func _say(msg: String) -> void:
	if _label:
		_label.text = msg
	print(msg)

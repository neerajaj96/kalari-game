extends CanvasLayer
# Touch HUD: left joystick area + right buttons. Works with mouse on PC.

@onready var xp_label: Label = $Root/XPLabel
@onready var hp_label: Label = $Root/HPLabel
@onready var heat_label: Label = $Root/HeatLabel
@onready var msg_label: Label = $Root/MsgLabel
@onready var hp_bar: ProgressBar = $Root/HPBar
@onready var st_bar: ProgressBar = $Root/STBar
@onready var xp_bar: ProgressBar = $Root/XPBar
@onready var knob: Panel = $Root/JoyBase/Knob
@onready var vignette: ColorRect = $Root/DamageVignette
@onready var tabs_panel: Panel = $Root/TabsPanel
@onready var tabs_list: OptionButton = $Root/TabsPanel/TabsList
@onready var tabs_text: RichTextLabel = $Root/TabsPanel/TabsText

var _tabs: Array = []

var _last_hp := 100.0
var _flash := 0.0
var _last_hp_text := ""
var _last_xp_text := ""
var _boot_warned := false
var _boot_t := 0.0
var _boot_checked := false
var _moves: Array = []
var _weapons: Array = []

var player: Node = null
var xp: Node = null
var joy_active := false
var joy_origin := Vector2.ZERO
var joy_id := -1

func _ready() -> void:
	for b in ["AttackButton", "BlockButton", "DodgeButton", "VillageButton",
			"SchoolButton", "RainButton", "RitualButton", "SadhanaButton",
			"BreatheButton", "TabsButton", "PlotButton", "MargaButton",
			"SaveButton", "MuteButton", "DrillButton", "SettingsButton"]:
		var btn := get_node_or_null("Root/" + b) as Button
		if btn == null:
			push_warning("HUD missing " + b)
			continue
		btn.pressed.connect(_on_hud_button.bind(b))
	var close_btn := get_node_or_null("Root/TabsPanel/TabsClose") as Button
	if close_btn:
		close_btn.pressed.connect(_on_tabs_close)
	for sb in ["SoundButton", "ShadowButton", "ResetButton", "SettingsClose"]:
		var sbtn := get_node_or_null("Root/SettingsPanel/" + sb) as Button
		if sbtn:
			sbtn.pressed.connect(_on_settings_button.bind(sb))
	tabs_list.item_selected.connect(_on_tab_selected)
	_load_tabs()
	_load_arsenal()

func _load_arsenal() -> void:
	var f := FileAccess.open("res://data/moves.json", FileAccess.READ)
	if f != null:
		var j = JSON.parse_string(f.get_as_text())
		if j is Dictionary:
			_moves = j.get("moves", [])
	var w := FileAccess.open("res://data/weapons.json", FileAccess.READ)
	if w != null:
		var k = JSON.parse_string(w.get_as_text())
		if k is Dictionary:
			_weapons = k.get("weapons", [])

func _strike_for_rank() -> Vector2:
	# damage, cost from data: move by rank, multiplied by unlocked weapon.
	var rank := 1
	if xp:
		rank = xp.rank
	var move_id := "mey_02_valinjamarnnu"
	var weapon_id := "none"
	if rank >= 3:
		move_id = "kol_02_cheruvadi_head"
		weapon_id = "cheruvadi"
	elif rank == 2:
		move_id = "kol_01_kettukari_strike"
		weapon_id = "kettukari"
	var dmg := 8.0
	var cost := 10.0
	for m in _moves:
		if str(m.get("id", "")) == move_id:
			dmg = float(m.get("damage", dmg))
			cost = float(m.get("stamina_cost", cost))
	var mult := 1.0
	for wpn in _weapons:
		if str(wpn.get("id", "")) == weapon_id:
			mult = float(wpn.get("damage_mult", mult))
	return Vector2(dmg * mult, cost)

func _on_hud_button(b: String) -> void:
	match b:
		"AttackButton": _on_attack()
		"BlockButton": _on_block()
		"DodgeButton": _on_dodge()
		"VillageButton": _on_village()
		"SchoolButton": _on_school()
		"RainButton": _on_rain()
		"RitualButton": _on_ritual()
		"SadhanaButton": _on_sadhana()
		"BreatheButton": _on_breathe()
		"TabsButton": _on_tabs()
		"PlotButton": _on_plot()
		"MargaButton": _on_marga()
		"SaveButton": _on_save()
		"MuteButton": _on_mute()
		"DrillButton": _on_drill()
		"SettingsButton": _on_settings()

func bind(p, x) -> void:
	player = p
	xp = x

func _on_attack() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game and game.get("dialogue") != null and game.dialogue.has_method("advance"):
		if game.dialogue.advance():
			return
	if player:
		var s := _strike_for_rank()
		player.request_strike(s.x, s.y)

func _on_block() -> void:
	if player:
		player.want_block = true

func _on_dodge() -> void:
	if player:
		player.want_dodge = true

func _on_village() -> void:
	var w = get_tree().get_first_node_in_group("world")
	if w:
		w.go_village()
	_set_zone("Chirakkal Village")

func _on_school() -> void:
	var w = get_tree().get_first_node_in_group("world")
	if w:
		w.go_school()
	_set_zone("Kuzhi-Kalari")

func _set_zone(name: String) -> void:
	var zl := get_node_or_null("Root/RadarPanel/ZoneLabel") as Label
	if zl:
		zl.text = name

var _monsoon := false

func _on_rain() -> void:
	# Monsoon toggle: rain particles + overcast preset in village, back to noon off.
	_monsoon = not _monsoon
	var w = get_tree().get_first_node_in_group("world")
	if w == null or w.get("current") == null:
		return
	var cur: Node = w.current
	var rain = cur.get_node_or_null("Rain") as CPUParticles3D
	if rain:
		rain.emitting = _monsoon
	else:
		say("Rain lives in the village (no sky here in the pit).")
		_monsoon = false
		if cur.has_method("apply"):
			cur.apply(1)
		if cur.has_method("set_storm"):
			cur.set_storm(0.0)
		return
	if cur.has_method("apply"):
		cur.apply(2 if _monsoon else 1)
	if cur.has_method("set_storm"):
		cur.set_storm(1.0 if _monsoon else 0.0)
	say("Monsoon ON — slippery Kalari" if _monsoon else "Noon sun")

func _on_ritual() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("rituals") == null or not game.rituals.has_method("start"):
		say("Seva unavailable.")
		return
	say(game.rituals.start())

func _on_sadhana() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("sadhana") == null or not game.sadhana.has_method("start"):
		say("Sadhana unavailable.")
		return
	say(game.sadhana.start(game.sadhana.place_of_player()))

func _on_breathe() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("sadhana") == null or not game.sadhana.has_method("tap"):
		return
	say(game.sadhana.tap())

func _load_tabs() -> void:
	var f := FileAccess.open("res://data/meru_tabs.json", FileAccess.READ)
	if f == null:
		return
	var mj = JSON.parse_string(f.get_as_text())
	if mj is Dictionary:
		_tabs = []
		for t in mj.get("tabs", []):
			if t is Dictionary:
				_tabs.append(t)
			else:
				push_warning("meru_tabs: skipping non-dict entry")
	var uj_tabs: Array = []
	var u := FileAccess.open("res://data/user_texts.json", FileAccess.READ)
	if u != null:
		var ujd = JSON.parse_string(u.get_as_text())
		if ujd is Dictionary:
			for t in ujd.get("tabs", []):
				if t is Dictionary:
					uj_tabs.append(t)
	_tabs.append_array(uj_tabs)
	if tabs_list == null:
		push_warning("HUD missing TabsList, encyclopedia off")
		return
	tabs_list.clear()
	for i in _tabs.size():
		var entry: Dictionary = _tabs[i]
		tabs_list.add_item(str(entry.get("name_en", "Tab %d" % i)), i)
	if not _tabs.is_empty():
		_show_tab(0)

func _on_tabs() -> void:
	tabs_panel.visible = not tabs_panel.visible

func _on_plot() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("plot") == null or not game.plot.has_method("status"):
		say("Plot unavailable.")
		return
	var msg: String = game.plot.status()
	if game.get("quest_log") != null and game.quest_log.has_method("status"):
		msg += "\n" + game.quest_log.status()
	say(msg)

func _on_marga() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("vama") == null or not game.vama.has_method("toggle"):
		say("Marga unavailable.")
		return
	var msg: String = game.vama.toggle()
	if game.vama.enabled and game.vama.has_method("status"):
		msg += " " + game.vama.status()
	say(msg)

func _on_save() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("save") == null or not game.save.has_method("save_game"):
		say("Save unavailable.")
		return
	game.save.save_game()
	say("Progress saved.")

func _on_mute() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("audio") == null or not game.audio.has_method("toggle_mute"):
		say("Sound unavailable.")
		return
	say(game.audio.toggle_mute())

func _on_drill() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("drill") == null or not game.drill.has_method("toggle"):
		say("Drill unavailable.")
		return
	say(game.drill.toggle())

func _on_settings() -> void:
	var p := get_node_or_null("Root/SettingsPanel") as Panel
	if p:
		p.visible = not p.visible

func _on_tabs_close() -> void:
	tabs_panel.visible = false

func _on_settings_button(b: String) -> void:
	var game = get_tree().get_first_node_in_group("game")
	if b == "SettingsClose":
		var p := get_node_or_null("Root/SettingsPanel") as Panel
		if p:
			p.visible = false
	elif b == "SoundButton":
		_on_mute()
		var sb := get_node_or_null("Root/SettingsPanel/SoundButton") as Button
		if sb and game and game.get("audio") != null:
			sb.text = "Sound: off" if game.audio.muted else "Sound: on"
	elif b == "ShadowButton":
		var w = get_tree().get_first_node_in_group("world")
		var sun = w.current.get_node_or_null("Sun") if w and w.get("current") else null
		if sun:
			sun.shadow_enabled = not sun.shadow_enabled
			if game:
				game.set("shadows_on", sun.shadow_enabled)
			var sh := get_node_or_null("Root/SettingsPanel/ShadowButton") as Button
			if sh:
				sh.text = "Shadows: on" if sun.shadow_enabled else "Shadows: off"
	elif b == "ResetButton":
		if FileAccess.file_exists("user://kalari_save.cfg"):
			DirAccess.remove_absolute("user://kalari_save.cfg")
		get_tree().reload_current_scene()

func _on_tab_selected(i: int) -> void:
	_show_tab(i)

func _show_tab(i: int) -> void:
	if i < 0 or i >= _tabs.size() or not (_tabs[i] is Dictionary):
		return
	var t: Dictionary = _tabs[i]
	var src := ""
	if t.get("sources") != null:
		src = "\nSources: " + ", ".join(t["sources"])
	tabs_text.text = "%s (%s)\n\nWhat: %s\n\nIn game: %s\n\nWhy: %s%s" % [
		t.get("name_en", ""), t.get("name_ml", ""),
		t.get("what", ""), t.get("how_in_game", ""),
		t.get("philosophy", ""), src
	]

func show_tab_by_id(tab_id: String) -> void:
	for i in _tabs.size():
		if not (_tabs[i] is Dictionary):
			continue
		if str(_tabs[i].get("id", "")) == tab_id:
			tabs_list.select(i)
			_show_tab(i)
			tabs_panel.visible = true
			return

func _deadzone(v: Vector2) -> Vector2:
	# 0.15 stick deadzone; rescale so full deflection still reaches 1.0.
	var l := v.length()
	if l < 0.15:
		return Vector2.ZERO
	return v.normalized() * minf(1.0, (l - 0.15) / 0.85)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# PC mouse mirrors touch so the comment 'works with mouse' holds.
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.4 and joy_id == -1:
			joy_active = true
			joy_id = -2
			joy_origin = event.position
		elif not event.pressed and joy_id == -2:
			joy_active = false
			joy_id = -1
			if player:
				player.set_move(Vector2.ZERO)
			if knob:
				knob.position = Vector2(58, 58)
		return
	if event is InputEventMouseMotion and joy_id == -2:
		var md: Vector2 = _deadzone((event.position - joy_origin) / 90.0)
		if player:
			player.set_move(Vector2(md.x, md.y))
		if knob:
			knob.position = Vector2(58, 58) + md * 45.0
		return
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.4 and joy_id == -1:
			joy_active = true
			joy_id = event.index
			joy_origin = event.position
		elif not event.pressed and event.index == joy_id:
			joy_active = false
			joy_id = -1
			if player:
				player.set_move(Vector2.ZERO)
			if knob:
				knob.position = Vector2(58, 58)
	elif event is InputEventScreenDrag and event.index == joy_id:
		var d: Vector2 = _deadzone((event.position - joy_origin) / 90.0)
		# Screen y-down -> world z-down mapping
		if player:
			player.set_move(Vector2(d.x, d.y))
		if knob:
			knob.position = Vector2(58, 58) + d * 45.0

func _process(_delta: float) -> void:
	if not _boot_checked:
		_boot_t += _delta
		var w0 = get_tree().get_first_node_in_group("world")
		var loaded := w0 != null and w0.get("current") != null
		if loaded:
			_boot_checked = true
		elif _boot_t >= 6.0:
			_boot_checked = true
			say("BOOT ERROR: 3D world failed to load. Note this text and report it.")
			return
		elif _boot_t >= 2.0 and not _boot_warned:
			_boot_warned = true
			say("Loading Kalari... (slow storage, hold on)")
	# Keyboard fallback
	if player and joy_id == -1:
		var kv := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if kv.length() > 0.05:
			player.set_move(kv)
	if player and xp and player.get("combat") != null and xp.has_method("title") and xp.get("rank") != null:
		var hp: float = player.combat.hp
		var st: float = player.combat.stamina
		var hp_text := "HP %.0f  ST %.0f" % [hp, st]
		if hp_text != _last_hp_text:
			_last_hp_text = hp_text
			hp_label.text = hp_text
		var xp_text := "Rank %d %s  XP %d" % [xp.rank, xp.title(), xp.xp]
		if xp_text != _last_xp_text:
			_last_xp_text = xp_text
			xp_label.text = xp_text
		if player.has_method("set_rank"):
			player.set_rank(xp.rank)
		hp_bar.value = hp
		st_bar.value = st
		var need := 800.0
		if xp.ranks is Array:
			for r in xp.ranks:
				if r is Dictionary and int(r.get("xp_needed", 0)) > xp.xp:
					need = float(r.get("xp_needed", need))
					break
		xp_bar.max_value = need
		xp_bar.value = minf(xp.xp, need)
		if hp < _last_hp:
			_flash = 0.55
		_last_hp = hp
		var game0 = get_tree().get_first_node_in_group("game")
		if game0 and game0.get("heat") != null and game0.heat.get("heat") != null:
			var h: int = game0.heat.heat
			heat_label.text = "Heat " + "●".repeat(h) + "○".repeat(3 - h) if h > 0 else ""
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - _delta * 1.8)
		vignette.color = Color(0.6, 0, 0, _flash * 0.6)

func say(msg: String) -> void:
	msg_label.text = msg

func show_dialogue(speaker: String, text: String, show: bool, color: Color = Color(0.7, 0.7, 0.7)) -> void:
	var panel := get_node_or_null("Root/DlgPanel") as Panel
	var nm := get_node_or_null("Root/DlgPanel/DlgName") as Label
	var tx := get_node_or_null("Root/DlgPanel/DlgText") as Label
	if panel == null or nm == null or tx == null:
		if show:
			msg_label.text = (speaker + ": " if speaker != "" else "") + text
		return
	panel.visible = show
	if show:
		nm.text = speaker
		nm.add_theme_color_override("font_color", color)
		tx.text = text + "  (Attack ▸)"

extends Node
## Data-driven ritual scheduler: no hardcoded scripts.
## Slots from kalari data/nitya.json (5 pujas) + TS timing anchors
## (adhivasa offsets 12/9/7/5 days, night-after-yama window).
## Emits signals; the world (lamps/crowds/audio) subscribes.
class_name KsetraScheduler

signal slot_opened(slot_id: String)
signal slot_closed(slot_id: String)
signal rite_stepped(step_id: String)
signal step_waiting(step_id: String, missing: String)

var inventory: Node = null  # optional KsetraInventory; steps wait if stock is short

var slots: Array = []
var idx := 0
var adhivasa_offsets := [12, 9, 7, 5]  # TS-P3V1 (uttama/madhyama.../kartur-anurupa)
# Consecration-eve program, order per TS Patala 4 (each cites its rule).
var adhivasa_steps := [
	{"id": "kautuka_bandhana", "rule": "TS-P3V38B-kautuka"},
	{"id": "mandapa_shuddhi", "rule": "TS-P4V01-mandapashuddhi"},
	{"id": "shayya_build", "rule": "TS-P4V52-shayya"},
	{"id": "deepa_light", "rule": "TS-P4V64-deepa"},
	{"id": "ghrita_madhu", "rule": "TS-P4V76-ghrita"},
	{"id": "shayana", "rule": "TS-P4V114B-shayana"},
]
# Hospitality sequence, TS P4V101B order (dhyana -> gayatri-touch).
var upachara_steps := [
	{"id": "avahana", "rule": "TS-P4V101B-upachara"},
	{"id": "padya_achamana", "rule": "TS-P4V101B-upachara"},
	{"id": "gandha_ambara", "rule": "TS-P4V101B-upachara"},
	{"id": "pushpa_dhupa_deepa", "rule": "TS-P4V101B-upachara"},
	{"id": "gayatri_touch", "rule": "TS-P4V101B-upachara"},
]
# Homa prelude, SESHA P2V33B order (Matri-context kunda-agni).
var homa_prelude_steps := [
	{"id": "kunda_shosha", "rule": "SESHA-P2V33B-kundaagni"},
	{"id": "pitha_shakti", "rule": "SESHA-P2V33B-kundaagni"},
	{"id": "agni_adhana", "rule": "SESHA-P2V33B-kundaagni"},
	{"id": "ghee_archana", "rule": "SESHA-P2V33B-kundaagni"},
]
# Seed-sowing program, TS Patala 3 order (runs days before adhivasa).
var ankurarpana_steps := [
	{"id": "palika_place", "rule": "TS-P3V02B-palika16"},
	{"id": "bija_sow", "rule": "TS-P3V03B-bija"},
]
var _program: Array = []
var _step_i := -1  # -1 = nitya mode; >=0 steps through adhivasa program
var _t := 0.0
var _period := 90.0  # demo full nitya cycle, seconds (real temple = solar day)

func _ready() -> void:
	_load_slots()

func _load_slots() -> void:
	var f := FileAccess.open("res://data/nitya.json", FileAccess.READ)
	if f == null:
		slots = [
			{"id": "usha", "fetch": "flowers"}, {"id": "pantheeradi", "fetch": "ghee"},
			{"id": "ucha", "fetch": "oil"}, {"id": "deeparadhana", "fetch": "flowers"},
			{"id": "athazha", "fetch": "ghee"}]
		return
	var j = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		slots = j.get("slots", [])

func current() -> Dictionary:
	if slots.is_empty():
		return {}
	return slots[idx % slots.size()]

func _gate(step_id: String) -> bool:
	# Inventory gate: consume stock if a ledger is attached, else pass through.
	if inventory != null and inventory.has_method("consume"):
		if not inventory.consume(step_id):
			step_waiting.emit(step_id, "offering stock short — fetch (F) first")
			return false
	return true

func start_adhivasa() -> String:
	# Consecration-eve program (TS P4 batch). Returns first step id.
	return _start_program(adhivasa_steps)

func start_ankurarpana() -> String:
	# Seed-sowing program (TS P3 batch, days before adhivasa). Returns first step id.
	return _start_program(ankurarpana_steps)

func start_upachara() -> String:
	# Hospitality program (TS P4V101B). Returns first step id.
	return _start_program(upachara_steps)

func start_homa_prelude() -> String:
	# Homa prelude (SESHA P2V33B). Returns first step id.
	return _start_program(homa_prelude_steps)

func _start_program(prog: Array) -> String:
	_program = prog
	_step_i = 0
	_t = 0.0
	var id0 := str(_program[0].get("id", "?"))
	if _gate(id0):
		rite_stepped.emit(id0)
	return id0

func _process(delta: float) -> void:
	if _step_i >= 0:
		_t += delta
		if _t >= _period / 4.0:
			_t = 0.0
			var nxt := _step_i + 1
			if nxt >= _program.size():
				_step_i = -1  # program complete, back to nitya mode
				return
			var nid := str(_program[nxt].get("id", "?"))
			if _gate(nid):
				_step_i = nxt
				rite_stepped.emit(nid)
			# else: hold current step and retry (step_waiting already emitted)
		return
	if slots.is_empty():
		return
	_t += delta
	if _t >= _period / float(slots.size()):
		_t = 0.0
		slot_closed.emit(str(current().get("id", "?")))
		idx += 1
		var nid2 := str(current().get("id", "?"))
		if _gate(nid2):
			slot_opened.emit(nid2)

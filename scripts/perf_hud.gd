extends Node
# Runtime performance readout: FPS/frame-time, draw calls, triangles,
# texture/buffer memory, node cost. Debug builds only; release stays clean.
# Polled at 0.5Hz so measurement never costs frames. Toggled from Settings.
class_name PerfHUD

var _layer: CanvasLayer
var _label: Label
var _on := false
var _t := 0.0

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	_label = Label.new()
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.offset_left = -330.0
	_label.offset_top = 70.0
	_label.offset_right = -16.0
	_label.offset_bottom = 170.0
	_label.autowrap_mode = 2
	_label.visible = false
	_layer.add_child(_label)

func toggle() -> String:
	if not OS.is_debug_build():
		return "Perf readout needs a debug build."
	if not _on:
		_on = true
		_label.visible = true
		_sample()
		return "Perf overlay on."
	if not bench:
		start_benchmark()
		return "Perf benchmark running: 7 stations."
	_on = false
	_label.visible = false
	return "Perf overlay off."

# Deterministic benchmark: teleport-settle-sample across 7 ksetra stations,
# log to user://benchmark.json. Fixed 1.0s settle per station, 0.5Hz-safe.
var bench := false
var bench_i := 0
var bench_t := 0.0
var bench_log: Array = []
const BENCH_STATIONS := [
	["exterior", Vector3(28, 1, 0)],
	["gopura", Vector3(16, 1, 4)],
	["courtyard", Vector3(10, 1, 3)],
	["mandapa", Vector3(6, 1, 2)],
	["sanctum", Vector3(3.5, 1.5, 0)],
	["kulam", Vector3(-13, 1, 10)],
	["kavu", Vector3(-14, 1, -13)],
]

func start_benchmark() -> String:
	var w = get_tree().get_first_node_in_group("world")
	if w == null or w.get("current") == null or not ("Ksetra" in str(w.current.name)):
		return "Benchmark needs the Ksetra world."
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return "Benchmark needs the player."
	bench = true
	bench_i = 0
	bench_t = 0.0
	bench_log = []
	return "Benchmark started."

func _process(delta: float) -> void:
	if bench:
		_bench_step(delta)
		return
	if not _on:
		return
	_t += delta
	if _t < 2.0:
		return
	_t = 0.0
	_sample()

func _bench_step(delta: float) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		bench = false
		return
	if bench_t == 0.0:
		p.global_position = (BENCH_STATIONS[bench_i] as Array)[1]
	bench_t += delta
	if bench_t < 1.0:
		return
	bench_t = 0.0
	bench_log.append(_metrics(str((BENCH_STATIONS[bench_i] as Array)[0])))
	bench_i += 1
	_label.text = "BENCH %d/7 ..." % bench_i
	if bench_i >= BENCH_STATIONS.size():
		bench = false
		var f := FileAccess.open("user://benchmark.json", FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"build": "ksetra", "stations": bench_log}, "\t"))
		var fps_sum := 0.0
		for m in bench_log:
			fps_sum += float((m as Dictionary).get("fps", 0))
		_label.text = "BENCH done avg %.0f FPS (user://benchmark.json)" % (fps_sum / maxf(1.0, float(bench_log.size())))

func _metrics(station: String) -> Dictionary:
	var fps := Engine.get_frames_per_second()
	return {"station": station,
		"fps": fps,
		"ms": 1000.0 / maxf(1.0, float(fps)),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"tris_k": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)) / 1000,
		"tex_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"buf_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		"mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"nodes": get_tree().get_node_count()}

func _sample() -> void:
	var fps := Engine.get_frames_per_second()
	var ms := 1000.0 / maxf(1.0, float(fps))
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var tris := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var texm := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	var bufm := Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0
	var memm := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var nodes := get_tree().get_node_count()
	var wname := "?"
	var w = get_tree().get_first_node_in_group("world")
	if w != null and w.get("current") != null:
		wname = str(w.current.name)
	_label.text = "PERF %s\n%d FPS %.1fms\n%d draws %dk tris\ntex %.1fMB buf %.1fMB mem %.1fMB\nnodes %d" % [
		wname, fps, ms, int(draws), int(tris) / 1000, texm, bufm, memm, nodes]

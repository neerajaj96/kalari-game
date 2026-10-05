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
	_on = not _on
	_label.visible = _on
	if _on:
		_sample()
	return "Perf overlay on." if _on else "Perf overlay off."

func _process(delta: float) -> void:
	if not _on:
		return
	_t += delta
	if _t < 2.0:
		return
	_t = 0.0
	_sample()

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

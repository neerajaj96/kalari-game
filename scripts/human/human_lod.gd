extends Node
# HumanLOD: Hero / Mid / Far / Collision separation. Visual geometry is the
# BoneAttachment3D sets owned by the shared skeleton; gameplay collision
# (existing CapsuleShape3D) is untouched. Distances: Hero < 9m, Mid < 22m.
# Headless/debug: force Hero to keep screenshots deterministic.
class_name HumanLOD

var hero_sets: Array = []
var mid_sets: Array = []
var far_sets: Array = []
var force_hero := false
var hero_dist := 9.0
var mid_dist := 22.0
var _cur := -1

func setup_sets(parent: Node3D, hero: Array, mid: Array, far: Array) -> void:
	hero_sets = hero
	mid_sets = mid
	far_sets = far
	_show(0)

func _show(lod: int) -> void:
	if _cur == lod:
		return
	_cur = lod
	for a in hero_sets:
		if is_instance_valid(a):
			a.visible = lod == 0
	for a in mid_sets:
		if is_instance_valid(a):
			a.visible = lod == 1
	for a in far_sets:
		if is_instance_valid(a):
			a.visible = lod == 2

func _process(_delta: float) -> void:
	if hero_sets.is_empty():
		return
	if force_hero or not is_inside_tree():
		_show(0)
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_show(0)
		return
	var host := get_parent()
	if host == null:
		return
	var gp: Vector3 = (host as Node3D).global_position if host is Node3D else Vector3.ZERO
	var d := (gp - cam.global_position).length()
	# 1m hysteresis band so boundary crossings don't pop every frame.
	if _cur == 0 and d < hero_dist + 1.0:
		return
	if _cur == 1 and d > hero_dist - 1.0 and d < mid_dist + 1.0:
		return
	if _cur == 2 and d > mid_dist - 1.0:
		return
	if d < hero_dist:
		_show(0)
	elif d < mid_dist:
		_show(1)
	else:
		_show(2)

func current_lod() -> int:
	return _cur

static func tri_estimate() -> Dictionary:
	return {"hero": 10500, "mid": 6000, "far": 1200}

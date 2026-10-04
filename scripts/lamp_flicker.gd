extends OmniLight3D
# Nilavilakku flicker: cheap sin + hash noise, no textures. Energy 1.0-1.4.
# Glow sync: shared shrine_yellow emission breathes with the flame.

var t := 0.0
var base := 1.3
var _glow_mat: StandardMaterial3D = null

func _ready() -> void:
	# Unique copy: pulsing the shared shrine_yellow would breathe
	# RankSash, enemy flash and Koombi too.
	var src: StandardMaterial3D = load("res://materials/shrine_yellow.tres")
	_glow_mat = src.duplicate()
	var lamp_mesh := get_node_or_null("../GarbhaDeepam") as MeshInstance3D
	if lamp_mesh == null:
		lamp_mesh = get_node_or_null("../Koombi") as MeshInstance3D
	if lamp_mesh:
		lamp_mesh.material_override = _glow_mat

func _process(delta: float) -> void:
	t += delta
	var n := sin(t * 11.0) * 0.5 + sin(t * 17.3 + 1.3) * 0.3 + sin(t * 5.1 + 0.5) * 0.2
	light_energy = base + n * 0.2
	if _glow_mat:
		_glow_mat.emission_energy_multiplier = 0.8 + n * 0.25

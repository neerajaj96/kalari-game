extends OmniLight3D
# Nilavilakku flicker: cheap sin + hash noise, no textures. Energy 1.0-1.4.

var t := 0.0
var base := 1.2

func _process(delta: float) -> void:
	t += delta
	var n := sin(t * 11.0) * 0.5 + sin(t * 23.7 + 1.3) * 0.3 + sin(t * 5.1 + 0.5) * 0.2
	light_energy = base + n * 0.15

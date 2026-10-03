extends Node3D
# Lighting presets for stylized Kerala. 0=morning warm, 1=noon bright, 2=monsoon overcast.
# Applies to sibling Sun + WorldEnvironment on _ready. Lamp flicker stays separate.
# Mobile-safe: no glow, no SSAO, Color background (no sky shader).

@export var preset := 1

func _ready() -> void:
	apply(preset)

func apply(p: int) -> void:
	preset = p
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	var wenv := get_node_or_null("WorldEnv") as WorldEnvironment
	if sun:
		match p:
			0: # morning: low warm
				sun.rotation = Vector3(-0.6, 0.6, 0)
				sun.light_energy = 0.9
				sun.light_color = Color(1.0, 0.85, 0.7)
			1: # noon: high neutral
				sun.rotation = Vector3(-0.9, 0.3, 0)
				sun.light_energy = 1.1
				sun.light_color = Color(1.0, 0.96, 0.9)
			2: # monsoon: flat grey
				sun.rotation = Vector3(-0.5, 0.2, 0)
				sun.light_energy = 0.55
				sun.light_color = Color(0.75, 0.8, 0.85)
	if wenv and wenv.environment:
		var env: Environment = wenv.environment
		match p:
			0:
				env.background_color = Color(0.55, 0.65, 0.8)
				env.ambient_light_color = Color(1.0, 0.85, 0.7)
				env.ambient_light_energy = 0.5
			1:
				env.background_color = Color(0.53, 0.75, 0.95)
				env.ambient_light_color = Color(0.9, 0.95, 1.0)
				env.ambient_light_energy = 0.6
			2:
				env.background_color = Color(0.45, 0.5, 0.55)
				env.ambient_light_color = Color(0.7, 0.75, 0.8)
				env.ambient_light_energy = 0.7

extends Node3D
# Day-night + weather director for stylized Kerala. Continuously blends
# keyframed light (dawn/noon/dusk/night/monsoon) instead of hard preset jumps.
# Storm factor from the monsoon toggle; lamps auto-light after dusk.
# Floors: energies never below 0.3x noon, ambient never below 0.35.

@export var preset := 1
@export var cycle := true
@export var day_length := 720.0 # seconds per full day

var day_t := 0.35
var storm := 0.0
var _storm_goal := 0.0
var _frame_t := 0.0
var _last_rain := -1
var _last_lamp := -1.0

# sun_rot, sun_energy, sun_color, ambient_color, ambient_energy, bg, fog_density, fog_color
const KEYS := [
	[0.0, Vector3(-0.45, 0.75, 0), 0.85, Color(1.0, 0.8, 0.62), Color(1.0, 0.85, 0.7), 0.55, Color(0.5, 0.6, 0.78), 0.006, Color(0.5, 0.55, 0.65)],
	[0.35, Vector3(-0.75, 0.45, 0), 1.15, Color(1.0, 0.96, 0.9), Color(0.9, 0.95, 1.0), 0.5, Color(0.53, 0.75, 0.95), 0.005, Color(0.65, 0.78, 0.9)],
	[0.6, Vector3(-0.5, 0.2, 0), 0.65, Color(0.72, 0.79, 0.87), Color(0.7, 0.75, 0.8), 0.75, Color(0.45, 0.5, 0.55), 0.008, Color(0.5, 0.55, 0.6)],
	[0.8, Vector3(-0.35, 0.85, 0), 0.7, Color(1.0, 0.6, 0.4), Color(0.9, 0.65, 0.5), 0.5, Color(0.45, 0.35, 0.35), 0.007, Color(0.5, 0.38, 0.32)],
	[0.95, Vector3(-0.3, 0.1, 0), 0.4, Color(0.5, 0.6, 0.9), Color(0.45, 0.55, 0.8), 0.35, Color(0.12, 0.16, 0.28), 0.01, Color(0.1, 0.13, 0.22)],
]

func _ready() -> void:
	day_t = [0.1, 0.35, 0.6][clampi(preset, 0, 2)]
	_apply_frame()

func _process(delta: float) -> void:
	# 2Hz throttle: light moves too slowly to need per-frame writes, and
	# rain.amount reallocs on change — never touch it 60x/sec.
	var dirty := false
	if cycle:
		day_t = fmod(day_t + delta / day_length, 1.0)
	if not is_equal_approx(storm, _storm_goal):
		storm = lerpf(storm, _storm_goal, minf(1.0, 2.0 * delta))
		dirty = true
	_frame_t += delta
	if cycle or dirty:
		if _frame_t >= 0.5:
			_frame_t = 0.0
			_apply_frame()

func apply(p: int) -> void:
	# Instant jump (kept for Rain toggle + plot callers).
	preset = p
	day_t = [0.1, 0.35, 0.6][clampi(p, 0, 2)]
	_apply_frame()

func set_storm(v: float) -> void:
	_storm_goal = clampf(v, 0.0, 1.0)

func _sample(t: float) -> Array:
	var a: Array = KEYS[0]
	var b: Array = KEYS[KEYS.size() - 1]
	if t > float(KEYS[KEYS.size() - 1][0]):
		# wrap segment: night blends back into dawn, no snap
		a = KEYS[KEYS.size() - 1]
		b = KEYS[0]
		var span: float = 1.0 - float(a[0])
		var k: float = clampf((t - float(a[0])) / maxf(0.0001, span), 0.0, 1.0)
		return _mix(a, b, k)
	for i in range(KEYS.size() - 1):
		if KEYS[i][0] <= t and t <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var span2: float = maxf(0.0001, float(b[0]) - float(a[0]))
	var k2: float = clampf((t - float(a[0])) / span2, 0.0, 1.0)
	return _mix(a, b, k2)

func _mix(a: Array, b: Array, k: float) -> Array:
	return [
		(a[1] as Vector3).lerp(b[1], k),
		lerpf(float(a[2]), float(b[2]), k),
		(a[3] as Color).lerp(b[3], k),
		(a[4] as Color).lerp(b[4], k),
		lerpf(float(a[5]), float(b[5]), k),
		(a[6] as Color).lerp(b[6], k),
		lerpf(float(a[7]), float(b[7]), k),
		(a[8] as Color).lerp(b[8], k),
	]

func _apply_frame() -> void:
	var f := _sample(day_t)
	# Storm drags everything toward the overcast keyframe (index 2).
	var o: Array = KEYS[2]
	f[1] = lerpf(float(f[1]), float(o[2]), storm)
	f[2] = (f[2] as Color).lerp(o[3], storm)
	f[3] = (f[3] as Color).lerp(o[4], storm)
	f[4] = lerpf(float(f[4]), float(o[5]), storm)
	f[5] = (f[5] as Color).lerp(o[6], storm)
	f[7] = (f[7] as Color).lerp(o[8], storm)
	f[1] = maxf(float(f[1]), 0.35)
	f[4] = maxf(float(f[4]), 0.35)
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.rotation = f[0]
		sun.light_energy = f[1]
		sun.light_color = f[2]
		sun.shadow_bias = 0.06
		sun.shadow_opacity = 0.85
	var wenv := get_node_or_null("WorldEnv") as WorldEnvironment
	if wenv and wenv.environment:
		var env: Environment = wenv.environment
		env.ambient_light_color = f[3]
		env.ambient_light_energy = f[4]
		env.background_color = f[5]
		env.fog_density = f[6]
		env.fog_light_color = f[7]
	# Lamp auto-light after dusk + storm gloom (write only on change).
	var lamp = get_node_or_null("Lamp")
	if lamp and lamp.get("base") != null:
		var night: float = clampf((day_t - 0.75) / 0.2, 0.0, 1.0)
		var want_lamp: float = 1.3 + night * 0.4 + storm * 0.2
		if not is_equal_approx(want_lamp, _last_lamp):
			_last_lamp = want_lamp
			lamp.base = want_lamp
	# Vegetation gusts follow storm (shared sway material, write on change).
	var sway = load("res://shaders/sway_leaf.tres") as ShaderMaterial
	if sway:
		sway.set_shader_parameter("strength", 0.06 + storm * 0.1)
	# Rain heaviness follows storm (amount reallocates — write only on change).
	var rain = get_node_or_null("Rain") as CPUParticles3D
	if rain:
		var want_rain := int(lerpf(150.0, 300.0, storm))
		if want_rain != _last_rain:
			_last_rain = want_rain
			rain.amount = want_rain

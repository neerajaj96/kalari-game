extends Node
# Code-generated ambience: no binary assets. 8kHz mono loop buffers built
# once at boot (~32KB each): market murmur, temple drone, water lap,
# monsoon wash, night insects. Plus bell/hit/marma one-shots.
# Zone-blended by player XZ every 0.5s; storm + night read from director.
class_name Ambience

const RATE := 8000

var muted := false
var _players := {}
var _t := 0.0

const ZONES := {
	"market": Vector3(-3, 0, 2),
	"temple": Vector3(4, 0, -10),
	"water": Vector3(0, 0, 9),
	"pit": Vector3(0, 0, 0),
}

func _ready() -> void:
	for name in ["murmur", "drone", "lap", "wash", "insects"]:
		var p := AudioStreamPlayer.new()
		p.name = "Bed_" + name
		p.volume_db = -60.0
		add_child(p)
		_players[name] = p
	var beds := {"murmur": _murmur(), "drone": _drone(), "lap": _lap(), "wash": _wash(), "insects": _insects()}
	for name in beds:
		beds[name].loop = true
		_players[name].stream = beds[name]
		_players[name].play()

func toggle_mute() -> String:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	return "Sound off." if muted else "Sound on."

func bell() -> void:
	_sting(_bell_buf(), -12.0)

func thock() -> void:
	_sting(_thock_buf(), -18.0)

func marma_sting() -> void:
	_sting(_marma_buf(), -14.0)

func _sting(stream: AudioStreamWAV, db: float) -> void:
	if muted:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func _mk(dur: float) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = PackedByteArray()
	s.data.resize(int(dur * RATE) * 2)
	return s

func _put(s: AudioStreamWAV, i: int, v: float) -> void:
	var c := int(clampf(v, -1.0, 1.0) * 32767.0)
	s.data.encode_s16(i * 2, c)

func _murmur() -> AudioStreamWAV:
	# crowd wash: wandering brown noise
	var s := _mk(4.0)
	var last := 0.0
	for i in range(4 * RATE):
		var t := float(i) / RATE
		last = (last + 0.02 * (randf() * 2.0 - 1.0)) / 1.02
		var wander := 0.5 + 0.5 * sin(t * 0.9) * sin(t * 0.37 + 1.0)
		_put(s, i, last * 3.0 * (0.4 + 0.6 * wander))
	return s

func _drone() -> AudioStreamWAV:
	# temple fifth Sa-Pa + soft octave
	var s := _mk(4.0)
	for i in range(4 * RATE):
		var t := float(i) / RATE
		var v := sin(TAU * 136.0 * t) * 0.35 + sin(TAU * 204.0 * t) * 0.22 + sin(TAU * 272.0 * t) * 0.1
		_put(s, i, v * 0.5)
	return s

func _lap() -> AudioStreamWAV:
	# backwater swells at 0.2Hz
	var s := _mk(5.0)
	var last := 0.0
	for i in range(5 * RATE):
		var t := float(i) / RATE
		last = (last + 0.05 * (randf() * 2.0 - 1.0)) / 1.05
		_put(s, i, last * 2.0 * (0.3 + 0.7 * (0.5 + 0.5 * sin(TAU * 0.2 * t)))))
	return s

func _wash() -> AudioStreamWAV:
	# monsoon white-noise bed (gain ridden by storm factor)
	var s := _mk(3.0)
	var last := 0.0
	for i in range(3 * RATE):
		last = last * 0.94 + (randf() * 2.0 - 1.0) * 0.06
		_put(s, i, last * 8.0)
	return s

func _insects() -> AudioStreamWAV:
	# night chirp triplets at 4.2kHz
	var s := _mk(3.0)
	for i in range(3 * RATE):
		var t := float(i) / RATE
		var gate := 1.0 if fmod(t, 0.9) < 0.24 else 0.0
		var chirp := sin(TAU * 4200.0 * t) * gate
		_put(s, i, chirp * 0.12)
	return s

func _bell_buf() -> AudioStreamWAV:
	var s := _mk(1.5)
	for i in range(int(1.5 * RATE)):
		var t := float(i) / RATE
		var env := exp(-t * 3.0)
		var v := sin(TAU * 660.0 * t) * 0.5 + sin(TAU * 990.0 * t) * 0.25 + sin(TAU * 1320.0 * t) * 0.12
		_put(s, i, v * env)
	return s

func _thock_buf() -> AudioStreamWAV:
	var s := _mk(0.15)
	for i in range(int(0.15 * RATE)):
		var t := float(i) / RATE
		_put(s, i, sin(TAU * 180.0 * t) * exp(-t * 30.0) * 0.8)
	return s

func _marma_buf() -> AudioStreamWAV:
	var s := _mk(0.6)
	for i in range(int(0.6 * RATE)):
		var t := float(i) / RATE
		var env := exp(-t * 6.0)
		_put(s, i, (sin(TAU * 523.0 * t) * 0.4 + sin(TAU * 784.0 * t) * 0.3) * env)
	return s

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	var pp: Vector3 = player.global_position
	var wmarket := _w(pp, ZONES["market"], 8.0)
	var wtemple := _w(pp, ZONES["temple"], 8.0)
	var wwater := _w(pp, ZONES["water"], 7.0)
	var storm := 0.0
	var night := 0.0
	var w = get_tree().get_first_node_in_group("world")
	if w != null and w.get("current") != null:
		var cur: Node = w.current
		if cur.get("storm") != null:
			storm = clampf(float(cur.storm), 0.0, 1.0)
		if cur.get("day_t") != null:
			var dt := float(cur.day_t)
			night = clampf((dt - 0.8) / 0.15, 0.0, 1.0)
	_set("murmur", -26.0 + wmarket * 12.0)
	_set("drone", -60.0 + wtemple * 46.0)
	_set("lap", -60.0 + wwater * 44.0)
	_set("wash", -60.0 + storm * 44.0)
	_set("insects", -60.0 + night * 40.0)

func _w(pp: Vector3, c: Vector3, r: float) -> float:
	var d: Vector3 = pp - c
	d.y = 0.0
	return clampf(1.0 - d.length() / r, 0.0, 1.0)

func _set(name: String, db: float) -> void:
	if _players.has(name):
		_players[name].volume_db = clampf(db, -60.0, -8.0)

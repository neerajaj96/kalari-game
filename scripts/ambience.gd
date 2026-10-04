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
		beds[name].loop_mode = AudioStreamWAV.LOOP_FORWARD
		_players[name].stream = beds[name]
		_players[name].play()

func toggle_mute() -> String:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	return "Sound off." if muted else "Sound on."

func bell(db: float = -12.0) -> void:
	_sting(_bell_buf(), db)

func thock() -> void:
	_sting(_thock_buf(), -18.0)

func marma_sting() -> void:
	_sting(_marma_buf(), -14.0)

const BLIP_PITCH := {
	"Gurukkal": 180.0, "Unniyarcha": 260.0, "Aromal": 220.0,
	"Villager": 300.0, "Kunjiraman": 300.0, "Crier": 340.0,
	"Watchman": 150.0, "System": 120.0,
}

func blip(speaker: String) -> void:
	# Syllable chirp per dialogue line. Mute-aware via bus.
	_sting(_blip_buf(float(BLIP_PITCH.get(speaker, 240.0))), -20.0)

func drum() -> void:
	_sting(_drum_buf(), -12.0)

func _blip_buf(freq: float) -> AudioStreamWAV:
	var s := _mk(0.09)
	var bytes := _bytes(0.09)
	var n := int(0.09 * RATE)
	for i in range(n):
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.01) * exp(-t * 25.0)
		_put(bytes, i, (sin(TAU * freq * t) * 0.5 + sin(TAU * freq * 2.0 * t) * 0.2) * env)
	s.data = bytes
	return s

func _drum_buf() -> AudioStreamWAV:
	var s := _mk(0.4)
	var bytes := _bytes(0.4)
	var n := int(0.4 * RATE)
	var last := 0.0
	for i in range(n):
		var t := float(i) / RATE
		last = last * 0.9 + (randf() * 2.0 - 1.0) * 0.1
		_put(bytes, i, (sin(TAU * 90.0 * t) * 0.7 + last * 0.5) * exp(-t * 8.0))
	s.data = bytes
	return s

func overture() -> void:
	# Boot cinematic: conch swell over 3s, then drone takes over.
	_sting(_conch_buf(), -10.0)

func _conch_buf() -> AudioStreamWAV:
	# Shankh-like rise: stacked fifths swelling in, breath noise under.
	var s := _mk(3.0)
	var bytes := _bytes(3.0)
	var n := int(3.0 * RATE)
	for i in range(n):
		var t := float(i) / RATE
		var swell: float = minf(1.0, t / 2.2) * minf(1.0, (3.0 - t) / 0.8)
		var v := sin(TAU * 174.0 * t) * 0.4 + sin(TAU * 261.0 * t) * 0.3 + sin(TAU * 348.0 * t) * 0.15
		v += (randf() * 2.0 - 1.0) * 0.05 * swell
		_put(bytes, i, v * swell * 0.8)
	s.data = bytes
	return s

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
	return s

func _bytes(dur: float) -> PackedByteArray:
	# Local buffer: engine data getters do not reflect in-place writes,
	# so build locally and assign once via s.data = bytes (see builders).
	var bytes := PackedByteArray()
	bytes.resize(int(dur * RATE) * 2)
	return bytes

func _put(bytes: PackedByteArray, i: int, v: float) -> void:
	var c := int(clampf(v, -1.0, 1.0) * 32767.0)
	bytes.encode_s16(i * 2, c)

func _murmur() -> AudioStreamWAV:
	# crowd wash: wandering brown noise
	var s := _mk(4.0)
	var bytes := _bytes(4.0)
	var last := 0.0
	for i in range(4 * RATE):
		var t := float(i) / RATE
		last = (last + 0.02 * (randf() * 2.0 - 1.0)) / 1.02
		var wander := 0.5 + 0.5 * sin(t * 0.9) * sin(t * 0.37 + 1.0)
		_put(bytes, i, last * 3.0 * (0.4 + 0.6 * wander))
	s.data = bytes
	return s

func _drone() -> AudioStreamWAV:
	# temple fifth Sa-Pa + soft octave
	var s := _mk(4.0)
	var bytes := _bytes(4.0)
	for i in range(4 * RATE):
		var t := float(i) / RATE
		var v := sin(TAU * 136.0 * t) * 0.35 + sin(TAU * 204.0 * t) * 0.22 + sin(TAU * 272.0 * t) * 0.1
		_put(bytes, i, v * 0.5)
	s.data = bytes
	return s

func _lap() -> AudioStreamWAV:
	# backwater swells at 0.2Hz
	var s := _mk(5.0)
	var bytes := _bytes(5.0)
	var last := 0.0
	for i in range(5 * RATE):
		var t := float(i) / RATE
		last = (last + 0.05 * (randf() * 2.0 - 1.0)) / 1.05
		_put(bytes, i, last * 2.0 * (0.3 + 0.7 * (0.5 + 0.5 * sin(TAU * 0.2 * t))))
	s.data = bytes
	return s

func _wash() -> AudioStreamWAV:
	# monsoon white-noise bed (gain ridden by storm factor)
	var s := _mk(3.0)
	var bytes := _bytes(3.0)
	var last := 0.0
	for i in range(3 * RATE):
		last = last * 0.94 + (randf() * 2.0 - 1.0) * 0.06
		_put(bytes, i, last * 8.0)
	s.data = bytes
	return s

func _insects() -> AudioStreamWAV:
	# night chirp triplets at 4.2kHz
	var s := _mk(3.0)
	var bytes := _bytes(3.0)
	for i in range(3 * RATE):
		var t := float(i) / RATE
		var gate := 1.0 if fmod(t, 0.9) < 0.24 else 0.0
		var chirp := sin(TAU * 4200.0 * t) * gate
		_put(bytes, i, chirp * 0.12)
	s.data = bytes
	return s

func _bell_buf() -> AudioStreamWAV:
	var s := _mk(1.5)
	var bytes := _bytes(1.5)
	for i in range(int(1.5 * RATE)):
		var t := float(i) / RATE
		var env := exp(-t * 3.0)
		var v := sin(TAU * 660.0 * t) * 0.5 + sin(TAU * 990.0 * t) * 0.25 + sin(TAU * 1320.0 * t) * 0.12
		_put(bytes, i, v * env)
	s.data = bytes
	return s

func _thock_buf() -> AudioStreamWAV:
	var s := _mk(0.15)
	var bytes := _bytes(0.15)
	for i in range(int(0.15 * RATE)):
		var t := float(i) / RATE
		_put(bytes, i, sin(TAU * 180.0 * t) * exp(-t * 30.0) * 0.8)
	s.data = bytes
	return s

func _marma_buf() -> AudioStreamWAV:
	var s := _mk(0.6)
	var bytes := _bytes(0.6)
	for i in range(int(0.6 * RATE)):
		var t := float(i) / RATE
		var env := exp(-t * 6.0)
		_put(bytes, i, (sin(TAU * 523.0 * t) * 0.4 + sin(TAU * 784.0 * t) * 0.3) * env)
	s.data = bytes
	return s

func _thunder_buf() -> AudioStreamWAV:
	# Monsoon crack: sharp attack, rolling brown decay.
	var s := _mk(1.2)
	var bytes := _bytes(1.2)
	var n := int(1.2 * RATE)
	var last := 0.0
	for i in range(n):
		var t := float(i) / RATE
		last = last * 0.97 + (randf() * 2.0 - 1.0) * 0.03
		_put(bytes, i, last * 10.0 * exp(-t * 2.5))
	s.data = bytes
	return s

func _events(delta: float, wmarket: float, wtemple: float, storm: float, night: float) -> void:
	_bell_t += delta
	_crier_t += delta
	_watch_t += delta
	if wtemple > 0.5 and _bell_t >= 120.0:
		_bell_t = 0.0
		bell()
	if wmarket > 0.5 and _crier_t >= 75.0:
		_crier_t = 0.0
		_crier()
	if storm >= 0.5 and not _storm_was:
		_storm_was = true
		storm_count += 1
		_sting(_thunder_buf(), -10.0)
		if storm_count == 3:
			_say("Lightning split the lamp row! The Tantri will ask for oil and guards.")
	elif storm < 0.5:
		_storm_was = false
	if night >= 0.8 and _watch_t >= 120.0:
		_watch_t = 0.0
		_say("Watchman: All is well. Sleep, Chirakkal.")

var _bell_t := 90.0
var _crier_t := 50.0
var _watch_t := 100.0
var _storm_was := false
var storm_count := 0

const CRIES := [
	"Crier: Fresh karimeen! Morning catch!",
	"Crier: Oil, ghee, lamp oil — best price!",
	"Crier: Turmeric, straight from Wayanad!",
]

func _crier() -> void:
	_say(CRIES[randi() % CRIES.size()])

func _say(msg: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say(msg)

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
	_set_db("murmur", -26.0 + wmarket * 12.0)
	_set_db("drone", -60.0 + wtemple * 46.0)
	_set_db("lap", -60.0 + wwater * 44.0)
	_set_db("wash", -60.0 + storm * 44.0)
	_set_db("insects", -60.0 + night * 40.0)
	_events(delta, wmarket, wtemple, storm, night)

func _w(pp: Vector3, c: Vector3, r: float) -> float:
	var d: Vector3 = pp - c
	d.y = 0.0
	return clampf(1.0 - d.length() / r, 0.0, 1.0)

func _set_db(name: String, db: float) -> void:
	if _players.has(name):
		_players[name].volume_db = clampf(db, -60.0, -8.0)

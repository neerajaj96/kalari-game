extends Node
# Dialogue queue: named speakers, tap-Attack advance, auto-hide when empty.
# Quest/giver lines queue with priority over ambient chatter; combat and
# system feedback stay transient (say) and never queue.
class_name Dialogue

var queue: Array = []
var showing := false

const COLORS := {
	"Gurukkal": Color(1.0, 0.75, 0.3),
	"Unniyarcha": Color(0.4, 0.9, 0.45),
	"Aromal": Color(0.65, 0.75, 0.9),
	"Villager": Color(0.96, 0.93, 0.85),
	"Kunjiraman": Color(0.96, 0.93, 0.85),
	"Crier": Color(0.95, 0.85, 0.55),
	"Watchman": Color(0.7, 0.75, 0.85),
	"System": Color(0.7, 0.7, 0.7),
}

func say(speaker: String, lines: Array, priority: bool = false) -> void:
	for ln in lines:
		var item := {"speaker": speaker, "text": str(ln)}
		if priority:
			queue.push_front(item)
		else:
			queue.append(item)
	_next()

func advance() -> bool:
	# Returns true if a line was consumed (caller should swallow the tap).
	if not showing or queue.is_empty():
		return false
	queue.pop_front()
	_next()
	return true

func _next() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("show_dialogue"):
		return
	if queue.is_empty():
		showing = false
		hud.show_dialogue("", "", false)
		return
	showing = true
	var item: Dictionary = queue[0]
	var sp := str(item.get("speaker", ""))
	var game = get_tree().get_first_node_in_group("game")
	if game and game.get("audio") != null and game.audio.has_method("blip"):
		game.audio.blip(sp)
	if sp == "Gurukkal" and game and game.get("audio") != null and game.audio.has_method("bell"):
		game.audio.bell(-22.0)
	hud.show_dialogue(sp, str(item.get("text", "")), true, COLORS.get(sp, COLORS["System"]))

func clear() -> void:
	queue.clear()
	showing = false
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_dialogue"):
		hud.show_dialogue("", "", false)

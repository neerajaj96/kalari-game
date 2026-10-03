extends Area3D
# Gurukkal counsel: Tamil Agama / Agastyar / Siddha body lore.
# Rotating lines by rank: breath, marma, vayu, rest. No temple tantra here —
# that belongs to the Tantri-guru; this guru owns the body.

var lines := [
	"Agastyar's first lesson: breath leads, body follows. (Try Sadhana in the pit.)",
	"Vayu moves in ten winds; watch which one rises when you strike.",
	"Marmam hides where vessels knot — ankle, temple, ribs. Strike true, never cruel.",
	"Siddha rule: oil the body (uzhichil), rest the joints, eat after sweat dries.",
	"Vadivu is animal memory: Simha guards, Gaja charges, Aswa lunges, Sarpa slips, Kukkuda kicks.",
	"Tamil Agamas say the deity also sits in the spine — Meru within, temple without.",
]

var _visits := 0

func _ready() -> void:
	body_entered.connect(_on_body)

func _on_body(b: Node) -> void:
	if not b.is_in_group("player"):
		return
	_visits += 1
	var game = get_tree().get_first_node_in_group("game")
	var rank := 1
	if game and game.get("xp_rank") != null:
		rank = game.xp_rank.rank
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say("Gurukkal: " + lines[(rank + _visits) % lines.size()])

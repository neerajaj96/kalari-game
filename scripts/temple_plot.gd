extends Node
# Kolathiri temple-build plot: 7 phases, rank-gated. Polls quest state 2x/sec.
# Supply = MarketZone visits during supply phases. Kills = quest_log.kills.
# Visits tracked via sadhana zone flags + sanctum entries.
class_name TemplePlot

var phases: Array = []
var phase := 0 # index into phases; 7 = done (festival locked shows at 6)
var supply := 0
var visited_hermitage := false
var visited_sanctum := false
var _t := 0.0

func _ready() -> void:
	var f := FileAccess.open("res://data/temple_plot.json", FileAccess.READ)
	if f == null:
		return
	var j = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		for p in j.get("phases", []):
			if p is Dictionary and p.has("id") and p.has("rank_needed") and p.has("needs") and p.has("xp"):
				phases.append(p)
			else:
				push_warning("temple_plot: skipping malformed phase")

func on_supply() -> void:
	supply += 1

func on_visit(which: String) -> void:
	if which == "hermitage":
		visited_hermitage = true
	elif which == "sanctum":
		visited_sanctum = true

func status() -> String:
	if phases.is_empty():
		return "No plot."
	if phase >= phases.size():
		return "Temple stands. Festival awaits Rank 4."
	var p: Dictionary = phases[phase]
	var game = get_tree().get_first_node_in_group("game")
	var rank := 1
	if game and game.get("xp_rank") != null and game.xp_rank.get("rank") != null:
		rank = game.xp_rank.rank
	var lock := ""
	if rank < int(p.get("rank_needed", 1)):
		lock = " [LOCKED: needs Rank %d, you are %d]" % [int(p.get("rank_needed", 1)), rank]
	var extra := ""
	var needs: Dictionary = p.get("needs", {})
	var want_kills := maxi(int(needs.get("kills", 0)), int(needs.get("kills_total", 0)))
	if want_kills > 0 and game and game.get("quest_log") != null and game.quest_log.get("kills") != null:
		extra = " (bandits down: %d/%d)" % [game.quest_log.kills, want_kills]
	return "Phase %d/7 %s%s: %s (supply %d)%s" % [int(p.get("n", 0)), p.get("name", "?"), lock, p.get("brief", ""), supply, extra]

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	if phases.is_empty() or phase >= phases.size():
		return
	var p: Dictionary = phases[phase]
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("xp_rank") == null or game.xp_rank.get("rank") == null:
		return
	if game.xp_rank.rank < int(p.get("rank_needed", 1)):
		return
	if _done(p, game):
		_finish(p, game)

func _done(p: Dictionary, game: Node) -> bool:
	var needs: Dictionary = p.get("needs", {})
	if str(p.get("id", "")) == "sthala":
		return visited_hermitage and visited_sanctum
	if needs.has("supply") and supply < int(needs["supply"]):
		return false
	if needs.has("kills") or needs.has("kills_total"):
		if game.get("quest_log") == null or game.quest_log.get("kills") == null:
			return false
		var kills: int = game.quest_log.kills
		if needs.has("kills") and kills < int(needs["kills"]):
			return false
		if needs.has("kills_total") and kills < int(needs["kills_total"]):
			return false
		return true
	if needs.has("supply"):
		return true
	return true

func _finish(p: Dictionary, game: Node) -> void:
	if game.get("xp_rank") == null or not game.xp_rank.has_method("add_xp"):
		return
	game.xp_rank.add_xp(int(p.get("xp", 100)))
	# Keep overflow: extra loads count toward the next supply phase.
	var need_supply := int(p.get("needs", {}).get("supply", 0))
	supply = maxi(0, supply - need_supply)
	phase += 1
	if game.get("save") != null and game.save.has_method("save_game"):
		game.save.save_game()
	var hud = get_tree().get_first_node_in_group("hud")
	if phase >= phases.size():
		if hud and hud.has_method("say"):
			hud.say("Bhadrakali temple stands! Festival awaits Rank 4. (+%d XP)" % int(p.get("xp", 100)))
		return
	var nxt: Dictionary = phases[phase]
	if hud and hud.has_method("say"):
		hud.say("Phase %d done (+%d XP). Next: %s — %s" % [int(p.get("n", 0)), int(p.get("xp", 100)), nxt.get("name", "?"), nxt.get("brief", "")])
	if hud and hud.has_method("show_tab_by_id") and str(p.get("id", "")) == "dwaja":
		hud.show_tab_by_id("kula_kundalini")

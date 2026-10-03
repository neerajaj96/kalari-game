extends Node
# Vama/Kaula symbolic track. Adult-gated (default OFF), Rank 3+, tantri permission.
# No explicit content anywhere: flower/water symbols, text verses, fade-to-black.
# Progress polls: forest dhyana count, sanctum visits, bandit kills.
class_name Vama

var enabled := false
var stage := 0 # 0 locked, 1 tattva, 2 kula, 3 vira, 4 done
var forest_done := 0
var kills_at_kula := -1
var _t := 0.0

func toggle() -> String:
	enabled = not enabled
	if enabled:
		return "Marga track ON (18+): symbolic philosophy only. No explicit acts. Tantri permission still needed (Rank 3 + 3 sevas)."
	return "Marga track OFF."

func status() -> String:
	if not enabled:
		return "Marga track OFF (18+ symbolic). Toggle Marga to read the disclaimer."
	var game = get_tree().get_first_node_in_group("game")
	var rank := 1
	var sevas := 0
	if game:
		if game.get("xp_rank") != null:
			rank = game.xp_rank.rank
		if game.get("rituals") != null:
			sevas = game.rituals.idx
	if rank < 3:
		return "Marga: needs Rank 3 (you %d). Train Kalari first." % rank
	if sevas < 3:
		return "Marga: needs tantri trust, 3 sevas done (you %d). Serve at temple." % sevas
	var names := ["", "Five Elements Contemplation: do Forest Dhyana.", "Kula axis: stand at sanctum door.", "Vira resolve: defeat 1 bandit.", "Complete. Carry it quietly."]
	return "Marga %d/3: %s" % [mini(stage, 3), names[mini(stage, 4)]]

func on_forest_dhyana() -> void:
	forest_done += 1

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	if not enabled or stage >= 4:
		return
	var game = get_tree().get_first_node_in_group("game")
	if game == null or game.get("xp_rank") == null or game.xp_rank.get("rank") == null:
		return
	if game.xp_rank.rank < 3:
		return
	if game.get("rituals") == null or game.rituals.get("idx") == null or game.rituals.idx < 3:
		return
	if stage == 0:
		stage = 1
		_say("Tantri nods. Begin: Five Elements Contemplation (Forest Dhyana).")
	elif stage == 1 and forest_done >= 1:
		_finish(120, "vama_dakshina_equal", "Tattva seen. Next: stand at the dwaja line (sanctum door).")
		stage = 2
	elif stage == 2 and game.get("sadhana") != null and game.sadhana.has_method("is_in_temple") and game.sadhana.is_in_temple():
		_finish(150, "kula_kundalini", "Axis felt: mooladhara to sahasrara. Next: defeat 1 bandit steadily.")
		stage = 3
		if game.get("quest_log") != null and game.quest_log.get("kills") != null:
			kills_at_kula = game.quest_log.kills
	elif stage == 3:
		if game.get("quest_log") != null and game.quest_log.get("kills") != null and kills_at_kula >= 0 and game.quest_log.kills > kills_at_kula:
			_finish(180, "kamya_defense_only", "Vira resolve proven. Carry it quietly; protect, never flaunt.")
			stage = 4

func _finish(xp_gain: int, tab: String, msg: String) -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game and game.get("xp_rank") != null and game.xp_rank.has_method("add_xp"):
		game.xp_rank.add_xp(xp_gain)
	_say("%s (+%d XP)" % [msg, xp_gain])
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_tab_by_id"):
		hud.show_tab_by_id(tab)

func _say(msg: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say(msg)

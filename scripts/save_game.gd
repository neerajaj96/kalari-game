extends Node
# Save system: ConfigFile at user://kalari_save.cfg. Rank derived from XP
# (never stored). Heat intentionally not saved (fresh slate each launch).
# Corrupt/missing file -> clean defaults, never crash.
class_name SaveGame

const PATH := "user://kalari_save.cfg"

func save_game() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game == null:
		return
	var cfg := ConfigFile.new()
	if game.get("xp_rank") != null:
		cfg.set_value("progress", "xp", game.xp_rank.xp)
	if game.get("quest_log") != null:
		cfg.set_value("progress", "kills", game.quest_log.kills)
		cfg.set_value("progress", "reps", game.quest_log.reps)
		cfg.set_value("progress", "q02", game.quest_log.q02_done)
		cfg.set_value("progress", "q03", game.quest_log.q03_done)
	if game.get("rituals") != null:
		cfg.set_value("progress", "sevas", game.rituals.idx)
	if game.get("plot") != null:
		cfg.set_value("progress", "phase", game.plot.phase)
		cfg.set_value("progress", "supply", game.plot.supply)
		cfg.set_value("progress", "visit_h", game.plot.visited_hermitage)
		cfg.set_value("progress", "visit_s", game.plot.visited_sanctum)
	if game.get("vama") != null:
		cfg.set_value("progress", "vama_stage", game.vama.stage)
		cfg.set_value("progress", "vama_on", game.vama.enabled)
		cfg.set_value("progress", "vama_forest", game.vama.forest_done)
	var w = get_tree().get_first_node_in_group("world")
	if w != null and w.get("current") != null:
		cfg.set_value("progress", "world", str(w.current.name))
	cfg.save(PATH)

func load_game() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return {}
	var d := {}
	for k in ["xp", "kills", "reps", "q02", "q03", "sevas", "phase", "supply", "visit_h", "visit_s", "vama_stage", "vama_on", "vama_forest", "world"]:
		d[k] = cfg.get_value("progress", k, null)
	return d

func apply_save(d: Dictionary, game: Node) -> void:
	if d.is_empty():
		return
	if game.get("xp_rank") != null and d.get("xp") != null:
		game.xp_rank.xp = int(d["xp"])
		_recompute_rank(game)
	if game.get("quest_log") != null:
		if d.get("kills") != null:
			game.quest_log.kills = int(d["kills"])
		if d.get("reps") != null:
			game.quest_log.reps = int(d["reps"])
		if d.get("q02") != null:
			game.quest_log.q02_done = bool(d["q02"])
			game.quest_log.stage["q02"] = "done" if bool(d["q02"]) else "offered"
		if d.get("q03") != null:
			game.quest_log.q03_done = bool(d["q03"])
			game.quest_log.stage["q03"] = "done" if bool(d["q03"]) else "offered"
		if d.get("reps", 0) and int(d.get("reps", 0)) >= 5:
			game.quest_log.stage["q01"] = "done"
	if game.get("rituals") != null and d.get("sevas") != null:
		game.rituals.idx = int(d["sevas"])
	if game.get("plot") != null:
		if d.get("phase") != null:
			game.plot.phase = int(d["phase"])
		if d.get("supply") != null:
			game.plot.supply = int(d["supply"])
		if d.get("visit_h") != null:
			game.plot.visited_hermitage = bool(d["visit_h"])
		if d.get("visit_s") != null:
			game.plot.visited_sanctum = bool(d["visit_s"])
	if game.get("vama") != null:
		if d.get("vama_stage") != null:
			game.vama.stage = int(d["vama_stage"])
		if d.get("vama_on") != null:
			game.vama.enabled = bool(d["vama_on"])
		if d.get("vama_forest") != null:
			game.vama.forest_done = int(d["vama_forest"])

func _recompute_rank(game: Node) -> void:
	# Rank derives from XP against thresholds (never stored).
	var ranks: Array = game.xp_rank.ranks
	var r := 1
	for entry in ranks:
		if entry is Dictionary and game.xp_rank.xp >= int(entry.get("xp_needed", 0)):
			r = maxi(r, int(entry.get("rank", 1)))
	game.xp_rank.rank = r

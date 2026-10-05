extends RefCounted
## Provenance lookup: GAME OBJECT -> RULE -> KNOWLEDGE ENTITY -> SOURCE.
## Built from spec provenance_index + kg rule YAMLs (exported to JSON at build).
class_name ProvenanceLookup

var _index: Dictionary = {}
var _rules: Dictionary = {}

func load_index(spec: Dictionary, rules_json_path: String) -> bool:
	_index = spec.get("provenance_index", {})
	var f := FileAccess.open(rules_json_path, FileAccess.READ)
	if f == null:
		return false
	var j = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		_rules = j
		return true
	return false

## Human-readable chain for one object id (or rule id).
func chain_for(obj_or_rule: String) -> String:
	var rid := obj_or_rule
	if _rules.has(obj_or_rule):
		rid = obj_or_rule
	elif _index.has(obj_or_rule):
		rid = obj_or_rule
	var r: Dictionary = _rules.get(rid, {})
	if r.is_empty():
		# maybe object id: find spec node? caller resolves; fallback:
		return "No rule '%s' in index (object ids resolve via spec node provenance)." % obj_or_rule
	var s: Dictionary = r.get("source", {})
	return "OBJECT %s -> RULE %s [%s] -> %s Patala %s verse %s (%s) -> %s" % [
		obj_or_rule, rid, str(r.get("rule_type", "?")),
		str(s.get("work", "?")), str(s.get("patala", "?")), str(s.get("verse", "?")),
		str(r.get("layer", "?")), str(s.get("edition", s.get("note", "?")))]

func rule_ids() -> Array:
	return _rules.keys()

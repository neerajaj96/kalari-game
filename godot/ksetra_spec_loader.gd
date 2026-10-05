extends RefCounted
## Ksetra spec loader + fail-closed constraint gate.
## GAME OBJECT -> RULE -> ENTITY -> SOURCE: every check cites provenance.
class_name KsetraSpecLoader

const ANGULA_M := 0.03
const HASTA_ANGULA := 24.0

static func hasta_to_m(h: float) -> float:
	return h * HASTA_ANGULA * ANGULA_M

static func load_spec(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "errors": ["spec missing: " + path]}
	var j = JSON.parse_string(f.get_as_text())
	if not (j is Dictionary):
		return {"ok": false, "errors": ["spec JSON malformed"]}
	return {"ok": true, "spec": j}

## Returns Array[String] errors (empty = PASS). Never invents defaults.
static func validate(spec: Dictionary) -> Array:
	var errs: Array = []
	var u: Dictionary = spec.get("units", {})
	if float(u.get("hasta_angula", 0.0)) != HASTA_ANGULA:
		errs.append("K-ANGULA: hasta_angula must be 24 (TS-P2V1-measure)")
	if abs(float(u.get("angula_m", 0.0)) - ANGULA_M) > 0.0001:
		errs.append("K-ANGULA: angula_m must be 0.03 (TS-P2V1-measure)")
	var pr: Dictionary = spec.get("prasada", {})
	# Plan branches implemented in ksetra_builder.gd: square, circular.
	# hexagonal/octagonal/oblong/apsidal are banked (rules exist) but unbuilt: fail closed.
	var plan := str(pr.get("plan", "square"))
	if plan != "square" and plan != "circular":
		errs.append("PLAN: '%s' has banked rules but no builder branch yet (see TS-P2V69B/70B/66B/67B)" % plan)
	var uh := float(pr.get("uttara_hasta", 0.0))
	# Alpa/ekatala band 2.75..~15h (TS-P2V1-measure); Jati mahaprasada to 70h (TS-P2V62B-jati).
	if uh < 2.75 or uh > 70.5:
		errs.append("K-RANGE-UTTARA: uttara_hasta %.2f outside 2.75..70 (TS-P2V1-measure + TS-P2V62B-jati)" % uh)
	elif uh > 15.2 and int(pr.get("tala", 1)) < 3:
		errs.append("K-RANGE-UTTARA: uttara_hasta %.2f > 15 needs tala>=3 Jati scope (TS-P2V62B-jati)" % uh)
	var meta: Dictionary = spec.get("meta", {})
	var facing := str(meta.get("facing", ""))
	var yoni := str(meta.get("yoni", ""))
	if facing == "east" and yoni != "vrisha":
		errs.append("K-YONI-PAIR: east-facing prasada must carry vrisha-yoni (TS-P2V2-yoni)")
	if facing == "west" and yoni != "dhvaja":
		errs.append("K-YONI-PAIR: west-facing prasada must carry dhvaja-yoni (TS-P2V2-yoni)")
	for lv in pr.get("levels", []):
		if not (lv is Dictionary and (lv.get("provenance", []) as Array).size() > 0):
			errs.append("provenance: level '%s' lacks rule ids" % str(lv.get("id", "?")))
	for nd in (spec.get("complex", {}) as Dictionary).get("nodes", []):
		if not (nd is Dictionary and (nd.get("provenance", []) as Array).size() > 0):
			errs.append("provenance: node '%s' lacks rule ids" % str(nd.get("id", "?")))
	for c in spec.get("constraints", []):
		if not (c is Dictionary and (c.get("provenance", []) as Array).size() > 0):
			errs.append("provenance: constraint '%s' lacks rule ids" % str(c.get("id", "?")))
	return errs

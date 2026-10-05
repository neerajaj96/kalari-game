extends Node
## Data-driven offering inventory: stocks consumed by rite steps, restocked by seva fetch.
## Fail-closed: consume() returns false when stock is short; the rite step waits.
## Provenance: TS-P4V76-ghrita (ghee+honey goblet), TS-P3V02B-palika16 (fills/adornments),
## SESHA-P5V02-savanatraya + P5V07-balikrama (bali rice), SESHA-P9V02/V03 (flag cloth),
## SESHA-P8V05-digbandha (shuddhi water/ghee).
class_name KsetraInventory

var stock := {
	"flowers": 12, "ghee": 6, "oil": 6, "rice": 10, "honey": 4,
	"milk": 4, "durva": 8, "thread": 8, "cloth": 4, "sandal": 2,
	"mud": 8, "sand": 8, "water": 12, "gandha": 6,
}

# Per scheduler step id: items consumed (from nitya fetch + P4 material rules).
var step_cost := {
	"usha": {"flowers": 1},
	"pantheeradi": {"ghee": 1},
	"ucha": {"oil": 1, "rice": 1},
	"deeparadhana": {"oil": 2, "flowers": 1},
	"athazha": {"ghee": 1, "rice": 1},
	"kautuka_bandhana": {"thread": 1},
	"mandapa_shuddhi": {"flowers": 2, "cloth": 1},
	"shayya_build": {"rice": 1, "cloth": 1},
	"deepa_light": {"oil": 2},
	"ghrita_madhu": {"ghee": 1, "honey": 1},
	"shayana": {},
	"palika_place": {"mud": 2, "sand": 2, "thread": 2, "durva": 2},
	"bija_sow": {"rice": 2, "milk": 1},
	"avahana": {},
	"padya_achamana": {"water": 2},
	"gandha_ambara": {"gandha": 1, "cloth": 1},
	"pushpa_dhupa_deepa": {"flowers": 2, "oil": 1},
	"gayatri_touch": {"sandal": 1},
	"kunda_shosha": {},
	"pitha_shakti": {"flowers": 1},
	"agni_adhana": {},
	"ghee_archana": {"ghee": 2},
	"savana_bali": {"rice": 1},
	"dvara_bali": {"rice": 1, "flowers": 1},
	"kshetrapala_bali": {"rice": 2},
	"dhvaja_aropana": {"cloth": 1, "flowers": 1},
	"pataka_puja": {"flowers": 1, "ghee": 1},
	"dig_bandha": {},
	"nadi_shuddhi": {"water": 1, "ghee": 1},
}

func consume(step_id: String) -> bool:
	var cost: Dictionary = step_cost.get(step_id, {})
	for k in cost:
		if int(stock.get(k, 0)) < int(cost[k]):
			return false
	for k in cost:
		stock[k] = int(stock[k]) - int(cost[k])
	return true

func fetch(item: String, n: int = 2) -> void:
	stock[item] = int(stock.get(item, 0)) + n

func summary() -> String:
	var bits: Array = []
	for k in ["flowers", "ghee", "oil", "rice", "honey"]:
		bits.append("%s %d" % [k, int(stock.get(k, 0))])
	return "Stock: " + ", ".join(bits)

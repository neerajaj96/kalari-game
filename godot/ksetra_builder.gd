extends Node3D
## Procedural Vishnu-dvitala ksetra builder (code-first, no static imports).
## Reads vishnu-dvitala.v1.json via KsetraSpecLoader, validates fail-closed,
## then generates every semantic node with metadata provenance (rule ids).
## Collision: solid CSG keeps use_collision; dressing gets visibility ranges.
class_name KsetraBuilder

const Loader = preload("res://godot/ksetra_spec_loader.gd")

var spec: Dictionary = {}
var errors: Array = []

func build_from(path: String) -> bool:
	var r: Dictionary = Loader.load_spec(path)
	if not bool(r.get("ok", false)):
		errors = r.get("errors", ["load failed"])
		return false
	spec = r["spec"]
	errors = Loader.validate(spec)
	if not errors.is_empty():
		return false
	_build_all()
	return true

func _m(hasta: float) -> float:
	return Loader.hasta_to_m(hasta)

func _box(parent: Node, nm: String, mat: Material, size: Vector3, pos: Vector3,
		prov: Array, collide := true, lod_end := 0.0) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = nm
	b.material = mat
	b.size = size
	b.position = pos
	b.use_collision = collide
	if lod_end > 0.0:
		b.visibility_range_begin = 0.0
		b.visibility_range_end = lod_end
		b.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	b.set_meta("provenance", prov)
	parent.add_child(b)
	return b

func _pyramid(parent: Node, nm: String, mat: Material, w: float, d: float, h: float,
		pos: Vector3, prov: Array) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w / 2.0
	var hd := d / 2.0
	var apex := Vector3(0, h, 0)
	var corners := [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd),
		Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]
	for i in range(4):
		_tri(st, corners[i], apex, corners[(i + 1) % 4])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	mi.set_meta("provenance", prov)
	parent.add_child(mi)
	return mi

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_uv(Vector2(a.x + a.z, a.y))
	st.add_vertex(a)
	st.set_uv(Vector2(b.x + b.z, b.y))
	st.add_vertex(b)
	st.set_uv(Vector2(c.x + c.z, c.y))
	st.add_vertex(c)

func _cone(parent: Node, nm: String, mat: Material, radius: float, h: float,
		pos: Vector3, prov: Array, segs := 16) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var apex := Vector3(0, h, 0)
	for i in range(segs):
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		_tri(st, Vector3(cos(a0) * radius, 0, sin(a0) * radius), apex,
			Vector3(cos(a1) * radius, 0, sin(a1) * radius))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	mi.set_meta("provenance", prov)
	parent.add_child(mi)
	return mi

func _cyl(parent: Node, nm: String, mat: Material, radius: float, height: float,
		pos: Vector3, prov: Array, collide := true) -> CSGCylinder3D:
	var c := CSGCylinder3D.new()
	c.name = nm
	c.material = mat
	c.radius = radius
	c.height = height
	c.sides = 24
	c.position = pos
	c.use_collision = collide
	c.set_meta("provenance", prov)
	parent.add_child(c)
	return c

func _mat(color: Color, rough := 0.8, metal := 0.0, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

func _build_all() -> void:
	var pr: Dictionary = spec["prasada"]
	var gh := _m(float(pr["garbha_hasta"]))
	var uh := _m(float(pr["uttara_hasta"]))
	var prov_pr: Array = pr.get("provenance", [])
	var granite := _mat(Color(0.42, 0.43, 0.46), 0.8, 0.1)
	var laterite := _mat(Color(0.48, 0.22, 0.13), 0.8)
	var timber := _mat(Color(0.38, 0.24, 0.13), 0.7)
	var copper := _mat(Color(0.78, 0.48, 0.22), 0.3, 0.85)
	var cream := _mat(Color(0.93, 0.87, 0.76), 0.85)
	var leaf := _mat(Color(0.13, 0.42, 0.16), 0.85)
	var water_mat := _mat(Color(0.16, 0.48, 0.55, 0.94), 0.12, 0.15)

	var plan := str(pr.get("plan", "square"))
	var west: bool = str((spec.get("meta", {}) as Dictionary).get("facing", "east")) == "west"
	var door_prov: Array = prov_pr + ["TS-P2V28B-doorwidth", "TS-P2V29B-doorheight", "TS-P2V30B-doorplank"]
	var root := Node3D.new()
	root.name = "KsetraCircular" if plan == "circular" else "KsetraDvitala"
	root.set_meta("provenance", prov_pr)
	add_child(root)
	if plan == "circular":
		_build_circular_ksetra(root, gh, uh, west, granite, laterite, timber, copper, cream, leaf, water_mat, prov_pr)
		return

	# --- adhishthana mouldings, granite (TS-P2V16B-nishkrama: jagati=1.0h,
	# kumuda=same, kampa/pati/vedi in {0.75,0.5,0.25}h; paduka off jagati line) ---
	var y := 0.0
	var mould_h := _m(1.5) / 6.0
	var names := ["Paduka", "Jagati", "Kumuda", "Kampa", "Pati", "Vedi"]
	var factors := [1.0, 1.0, 1.0, 0.75, 0.5, 0.25]
	for i in range(6):
		var w: float = gh + 2.0 * mould_h * float(factors[i])
		if i == 0:
			w = gh + 2.0 * mould_h * 1.0 + 0.12  # paduka footing off jagati line
		_box(root, "Adhisthana_" + names[i], granite,
			Vector3(w, mould_h, w), Vector3(0, y + mould_h / 2.0, 0), prov_pr)
		y += mould_h
	# --- tala1 pada: hollow laterite walls (inner t = garbha/8 per TS-P2V19B),
	# east door gap with lintel (divisors/height/planks TS-P2V28B/29B/30B) ---
	var h1 := _m(3.0)
	var wt := gh / 8.0
	var wall_prov: Array = prov_pr + ["TS-P2V19B-walls"] if not prov_pr.has("TS-P2V19B-walls") else prov_pr
	_box(root, "PadaT1_N", laterite, Vector3(gh, h1, wt), Vector3(0, y + h1 / 2.0, -gh / 2.0 + wt / 2.0), wall_prov)
	_box(root, "PadaT1_S", laterite, Vector3(gh, h1, wt), Vector3(0, y + h1 / 2.0, gh / 2.0 - wt / 2.0), wall_prov)
	_box(root, "PadaT1_W", laterite, Vector3(wt, h1, gh - 2.0 * wt), Vector3(-gh / 2.0 + wt / 2.0, y + h1 / 2.0, 0), wall_prov)
	var dw := gh / 4.0
	var dh := h1 * 0.85
	var segw := (gh - 2.0 * wt - dw) / 2.0
	_box(root, "PadaT1_E_N", laterite, Vector3(wt, h1, segw),
		Vector3(gh / 2.0 - wt / 2.0, y + h1 / 2.0, -(dw / 2.0 + segw / 2.0)), door_prov)
	_box(root, "PadaT1_E_S", laterite, Vector3(wt, h1, segw),
		Vector3(gh / 2.0 - wt / 2.0, y + h1 / 2.0, dw / 2.0 + segw / 2.0), door_prov)
	_box(root, "PadaT1_Lintel", laterite, Vector3(wt, h1 - dh, dw),
		Vector3(gh / 2.0 - wt / 2.0, y + dh + (h1 - dh) / 2.0, 0), door_prov)
	# garbhagriha interior: padma-pitha + standing Vishnu (stylized massing;
	# height/width/diadem per V121B/V123B/V109B, tala grades V86B; darshana
	# through the east door; Tantri-only crossing per K-TANTRI-ONLY)
	var bimba_prov: Array = ["TS-P2V121B-bimbaheight", "TS-P2V123B-bimbawidth", "TS-P2V109B-diadem", "TS-P2V117B-padmapitha"]
	_box(root, "Pitha", granite, Vector3(1.0, 0.4, 1.0), Vector3(0, y + 0.2, 0), bimba_prov)
	_cyl(root, "PadmaCapital", cream, 0.42, 0.15, Vector3(0, y + 0.47, 0), bimba_prov, false)
	_box(root, "BimbaBody", granite, Vector3(0.5, 1.1, 0.35), Vector3(0, y + 1.1, 0), bimba_prov, false)
	_box(root, "BimbaHead", granite, Vector3(0.28, 0.3, 0.28), Vector3(0, y + 1.8, 0), bimba_prov, false)
	_box(root, "BimbaDiadem", copper, Vector3(0.34, 0.22, 0.34), Vector3(0, y + 2.0, 0), bimba_prov, false)
	_box(root, "BimbaArmL", granite, Vector3(0.14, 0.7, 0.14), Vector3(-0.36, y + 1.15, 0), bimba_prov, false)
	_box(root, "BimbaArmR", granite, Vector3(0.14, 0.7, 0.14), Vector3(0.36, y + 1.15, 0), bimba_prov, false)
	# dvarapalas flanking the east door (spec dvarapala_L/R, TS-P2V2-yoni)
	var dvara_prov: Array = ["TS-P2V2-yoni"]
	_box(root, "DvarapalaL", granite, Vector3(0.35, 1.4, 0.35), Vector3(gh / 2.0 + 0.35, y + 0.7, -0.85), dvara_prov)
	_box(root, "DvarapalaR", granite, Vector3(0.35, 1.4, 0.35), Vector3(gh / 2.0 + 0.35, y + 0.7, 0.85), dvara_prov)
	# ghanadvaras: solid false doors on non-main faces (TS-P2V26B-bhittivibhaga)
	var ghana_prov: Array = prov_pr + ["TS-P2V26B-bhittivibhaga"] if not prov_pr.has("TS-P2V26B-bhittivibhaga") else prov_pr
	_box(root, "Ghanadvara_N", laterite, Vector3(0.88, 1.75, 0.1),
		Vector3(0, y + h1 * 0.45, -gh / 2.0 - 0.02), ghana_prov)
	_box(root, "Ghanadvara_S", laterite, Vector3(0.88, 1.75, 0.1),
		Vector3(0, y + h1 * 0.45, gh / 2.0 + 0.02), ghana_prov)
	_box(root, "Ghanadvara_W", laterite, Vector3(0.1, 1.75, 0.88),
		Vector3(-gh / 2.0 - 0.02, y + h1 * 0.45, 0), ghana_prov)
	# kudya-stambhas: 12 (4 corners + 2 between each, equal spacing; TS-P2V23B-kudyastambha)
	var kudya_prov: Array = prov_pr + ["TS-P2V23B-kudyastambha"] if not prov_pr.has("TS-P2V23B-kudyastambha") else prov_pr
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(root, "PilasterT1_c_%d%d" % [sx, sz], laterite,
				Vector3(0.25, h1, 0.25), Vector3(sx * gh / 2.0, y + h1 / 2.0, sz * gh / 2.0), kudya_prov)
	for t in [-1.0 / 6.0, 1.0 / 6.0]:
		_box(root, "PilasterT1_n_%d" % int(t * 6.0), laterite,
			Vector3(0.25, h1, 0.25), Vector3(t * gh, y + h1 / 2.0, -gh / 2.0), kudya_prov)
		_box(root, "PilasterT1_s_%d" % int(t * 6.0), laterite,
			Vector3(0.25, h1, 0.25), Vector3(t * gh, y + h1 / 2.0, gh / 2.0), kudya_prov)
		_box(root, "PilasterT1_w_%d" % int(t * 6.0), laterite,
			Vector3(0.25, h1, 0.25), Vector3(-gh / 2.0, y + h1 / 2.0, t * gh), kudya_prov)
		_box(root, "PilasterT1_e_%d" % int(t * 6.0), laterite,
			Vector3(0.25, h1, 0.25), Vector3(gh / 2.0, y + h1 / 2.0, t * gh), kudya_prov)
	y += h1
	# --- prastara t1 (9 mouldings as thin bands) ---
	var ph1 := _m(1.5) / 9.0
	for i in range(9):
		_box(root, "PrastaraT1_%d" % (i + 1), laterite,
			Vector3(gh + 0.5 - 0.02 * i, ph1, gh + 0.5 - 0.02 * i),
			Vector3(0, y + ph1 / 2.0, 0), prov_pr)
	y += _m(1.5)
	# --- hara aedicules (kuta/sala/panjara alternating) ---
	var hh := _m(1.0)
	for i in range(8):
		var kind: String = ["kuta", "sala", "panjara", "sala"][i % 4]
		var a := (gh + 0.5) / 2.0 + 0.1
		var ang := TAU * float(i) / 8.0
		_box(root, "Hara_%s_%d" % [kind, i], laterite,
			Vector3(0.5, hh, 0.5), Vector3(cos(ang) * a, y + hh / 2.0, sin(ang) * a), prov_pr)
	y += hh
	# --- tala2 + directional murtis (TS-P2V60B-tala2: Brahma E, Dakshinamurti S,
	# Narasimha W, Krishna N, wood/stone; corner kuta + cardinal sala + nasi pairs
	# already in hara ring above; roof mahanasis ride the shikhara) ---
	var h2 := _m(2.0)
	_box(root, "PadaT2", laterite, Vector3(gh * 0.72, h2, gh * 0.72),
		Vector3(0, y + h2 / 2.0, 0), prov_pr)
	var murti_prov: Array = (prov_pr + ["TS-P2V60B-tala2"]) if not prov_pr.has("TS-P2V60B-tala2") else prov_pr
	var hw2 := gh * 0.72 / 2.0 + 0.08
	var murti_y := y + h2 / 2.0
	_box(root, "Murti_Brahma_E", laterite, Vector3(0.16, 0.9, 0.5), Vector3(hw2, murti_y, 0), murti_prov)
	_box(root, "Murti_Dakshinamurti_S", laterite, Vector3(0.5, 0.9, 0.16), Vector3(0, murti_y, hw2), murti_prov)
	_box(root, "Murti_Narasimha_W", laterite, Vector3(0.16, 0.9, 0.5), Vector3(-hw2, murti_y, 0), murti_prov)
	_box(root, "Murti_Krishna_N", laterite, Vector3(0.5, 0.9, 0.16), Vector3(0, murti_y, -hw2), murti_prov)
	y += h2
	_box(root, "PrastaraT2", laterite, Vector3(gh * 0.72 + 0.4, _m(1.0), gh * 0.72 + 0.4),
		Vector3(0, y + _m(1.0) / 2.0, 0), prov_pr)
	y += _m(1.0)
	# --- timber pyramidal roof + copper kalasha ---
	_pyramid(root, "ShikharaRoof", timber, gh + 1.6, gh + 1.6, _m(3.0), Vector3(0, y, 0), prov_pr)
	y += _m(3.0)
	_box(root, "StupiKalasha", copper, Vector3(0.3, _m(0.75), 0.3), Vector3(0, y + _m(0.75) / 2.0, 0), prov_pr)

	# --- east axis: sopana steps, mukhamandapa, namaskara, balikkal, dwaja ---
	var ex := gh / 2.0
	# sopana: three granite steps rising to the door (TS-P2V33B-sopana)
	var sopana_prov: Array = prov_pr + ["TS-P2V33B-sopana"] if not prov_pr.has("TS-P2V33B-sopana") else prov_pr
	_box(root, "Sopana1", granite, Vector3(0.6, 0.15, 2.0), Vector3(ex + 0.5, 0.075, 0), sopana_prov)
	_box(root, "Sopana2", granite, Vector3(0.6, 0.3, 2.0), Vector3(ex + 1.0, 0.15, 0), sopana_prov)
	_box(root, "Sopana3", granite, Vector3(0.6, 0.45, 2.0), Vector3(ex + 1.5, 0.225, 0), sopana_prov)
	# mukhamandapa: 4 pillars + slab + pyramid
	var mx := ex + 3.0
	for px in [mx - 1.0, mx + 1.0]:
		for pz in [-1.0, 1.0]:
			_pillar(root, "MukhaPillar", timber, Vector3(px, 0, pz), 0.25, 2.2, prov_pr)
	_box(root, "MukhaSlab", timber, Vector3(3.0, 0.25, 3.0), Vector3(mx, 2.3, 0), door_prov)
	_pyramid(root, "MukhaRoof", timber, 3.6, 3.6, 1.0, Vector3(mx, 2.42, 0), prov_pr)
	# namaskara mandapa (detached square)
	var nx := ex + 6.5
	for px in [nx - 1.1, nx + 1.1]:
		for pz in [-1.1, 1.1]:
			_pillar(root, "NamaskaraPillar", timber, Vector3(px, 0, pz), 0.28, 2.4, prov_pr)
	_box(root, "NamaskaraSlab", granite, Vector3(3.0, 0.4, 3.0), Vector3(nx, 0.2, 0), prov_pr)
	_box(root, "NamaskaraRoofBase", timber, Vector3(3.4, 0.25, 3.4), Vector3(nx, 2.5, 0), prov_pr)
	_pyramid(root, "NamaskaraRoof", timber, 4.0, 4.0, 1.1, Vector3(nx, 2.62, 0), prov_pr)
	# valia balikkal + 8 bali stones along pradakshina
	_box(root, "ValiaBalikkal", granite, Vector3(0.8, 1.2, 0.8), Vector3(nx + 3.0, 0.6, 0), prov_pr)
	var bali_names := ["Ishan", "Indra", "Agni", "Yama", "Nirriti", "Varuna", "Vayu", "Soma"]
	for i in range(8):
		var ang := TAU * float(i) / 8.0 - PI / 8.0
		var br := uh + 2.5
		_box(root, "Bali_" + bali_names[i], granite, Vector3(0.4, 0.5, 0.4),
			Vector3(cos(ang) * br, 0.25, sin(ang) * br), prov_pr, true, 30.0)
	# dwaja: 8-sided areca pole (spec dwaja.sides=8) + copper kavacha top
	_cyl(root, "DwajaPole", timber, 0.18, 6.0, Vector3(nx + 5.0, 3.0, 0), prov_pr).sides = 8
	_box(root, "DwajaTop", copper, Vector3(0.5, 0.5, 0.5), Vector3(nx + 5.0, 6.2, 0), prov_pr)
	_box(root, "DeepaStambha", granite, Vector3(0.3, 3.0, 0.3), Vector3(nx + 6.5, 1.5, 1.5), prov_pr)
	# rishabha vahana at the dwaja base (SESHA-P9V02: bull for the deity)
	var dhvaja_prov: Array = prov_pr + ["SESHA-P9V02-dhvajavahana", "SESHA-P9V03-dhvasthapana"]
	_box(root, "RishabhaBase", granite, Vector3(1.0, 0.3, 0.6), Vector3(nx + 5.0, 0.15, 1.4), dhvaja_prov)
	_box(root, "Rishabha", cream, Vector3(0.8, 0.6, 0.4), Vector3(nx + 5.0, 0.6, 1.4), dhvaja_prov)

	# --- flagship v2 micro-objects (all provenance-tagged, dressing LOD) ---
	# foundation deposit set at the adhishthana north-east base (buried program shown exposed)
	var deposit_prov: Array = ["TS-P1V74B-nidhipot", "TS-P1V77B-kurmashila", "TS-P1V79B-silverlotus", "TS-P1V81B-bricks"]
	_cyl(root, "NidhiKumbha", copper, 0.22, 0.35, Vector3(ex + 0.4, 0.18, -1.6), deposit_prov, false)
	_box(root, "KurmaShila", granite, Vector3(0.5, 0.12, 0.5), Vector3(ex + 0.4, 0.41, -1.6), deposit_prov, false)
	_box(root, "SilverLotus", cream, Vector3(0.3, 0.08, 0.3), Vector3(ex + 0.4, 0.5, -2.1), deposit_prov, false)
	_box(root, "DepositBricks", laterite, Vector3(0.6, 0.25, 0.6), Vector3(ex + 0.4, 0.12, -2.6), deposit_prov, false)
	# palika-16 sowing grid south of mukhamandapa (TS-P3V02B/V03B)
	var palika_prov: Array = ["TS-P3V02B-palika16", "TS-P3V03B-bija"]
	for pi in range(16):
		var px := 4.0 + float(pi % 4) * 0.5
		var pz := 3.0 + float(pi / 4) * 0.5
		_box(root, "Palika_%d" % pi, laterite, Vector3(0.28, 0.22, 0.28),
			Vector3(px, 0.11, pz), palika_prov, false, 30.0)
	# kautuka stand + shayya platform north of mukhamandapa (TS-P3V38B/V114B)
	var kautuka_prov: Array = ["TS-P3V38B-kautuka", "TS-P4V114B-shayana"]
	_box(root, "ShayyaPlatform", cream, Vector3(2.0, 0.5, 1.0), Vector3(mx, 0.25, -3.5), kautuka_prov)
	_box(root, "KautukaStand", timber, Vector3(0.3, 0.6, 0.3), Vector3(mx, 0.3, -2.5), kautuka_prov)
	# brahma-kalasha vessel row by the thidappalli (SESHA-P4V02/V04 + V41B fills)
	var kalasha_prov: Array = ["SESHA-P4V02-brahmakalasha", "SESHA-P4V04-parikalasha", "SESHA-P7V41B-kalashafill"]
	for ki in range(5):
		_cyl(root, "BrahmaKalasha_%d" % ki, copper, 0.15, 0.4,
			Vector3(4.5 + float(ki) * 0.5, 0.2, -4.5), kalasha_prov, false)
	# kshetrapala guardian stone NE (SESHA-P8V04 ten-direction retinue)
	_box(root, "Kshetrapala", granite, Vector3(0.6, 1.0, 0.6), Vector3(9.0, 0.5, -9.0),
		["SESHA-P5V02-savanatraya", "SESHA-P5V07-balikrama", "SESHA-P8V04-kshetrapala"], true, 30.0)
	# eight lokapala parita flags inside the lamp ring (SESHA-P9V03)
	for fi in range(8):
		var fang := TAU * float(fi) / 8.0
		_box(root, "ParitaFlag_%d" % fi, cream, Vector3(0.3, 0.6, 0.05),
			Vector3(cos(fang) * 17.5, 1.6, sin(fang) * 17.5), dhvaja_prov, false, 40.0)
	# shuddhi platform + poles by the east gate (SESHA-P8V05 dig-bandha/nadi)
	var shuddhi_prov: Array = ["SESHA-P8V05-digbandha"]
	_box(root, "ShuddhiPlatform", granite, Vector3(1.6, 0.3, 1.6), Vector3((uh + 18.0) / 2.0, 0.15, 3.0), shuddhi_prov)
	_box(root, "ShuddhiPoleL", timber, Vector3(0.15, 2.0, 0.15), Vector3((uh + 18.0) / 2.0, 1.15, 2.5), shuddhi_prov)
	_box(root, "ShuddhiPoleR", timber, Vector3(0.15, 2.0, 0.15), Vector3((uh + 18.0) / 2.0, 1.15, 3.5), shuddhi_prov)
	# japa mandapa SW for mantra-anga practice (SESHA-P3V02/V04)
	var mantra_prov: Array = ["SESHA-P3V02-mantramula", "SESHA-P3V04-mantraanga"]
	_build_hall(root, "JapaMandapa", Vector3(-5.0, 0, 5.0), timber, cream, mantra_prov)

	# --- prakara rings (nalambalam rect, vilakkumadam, sivelipura path, maryada+gopura) ---
	_build_ring(root, "Nalambalam", uh + 6.0, 2.2, cream, prov_pr)
	_box(root, "Thidappalli", cream, Vector3(3.0, 2.0, 3.0),
		Vector3((uh + 6.0) / 2.0 - 1.0, 1.0, -((uh + 6.0) / 2.0 - 1.0)), prov_pr)
	_build_ring(root, "Vilakkumadam", uh + 10.0, 1.2, timber, prov_pr)
	_build_ring(root, "MaryadaWall", uh + 18.0, 1.5, laterite, prov_pr)
	# east gopura (2 storeys + roof)
	var gx := (uh + 18.0) / 2.0
	_box(root, "GopuraBase", cream, Vector3(2.0, 3.0, 5.0), Vector3(gx, 1.5, 0), prov_pr)
	_box(root, "GopuraTop", cream, Vector3(2.4, 2.0, 5.6), Vector3(gx, 4.0, 0), prov_pr)
	_pyramid(root, "GopuraRoof", timber, 3.0, 6.2, 1.4, Vector3(gx, 5.0, 0), prov_pr)
	# koothambalam NW: plinth + pillars + roof
	_build_hall(root, "Koothambalam", Vector3(-(uh / 2.0 + 6.0), 0, -(uh / 2.0 + 4.0)), timber, cream, prov_pr)
	# ootupura + well NE + kulam + kavu
	_build_hall(root, "Ootupura", Vector3(-(uh / 2.0 + 4.0), 0, uh / 2.0 + 6.0), timber, cream, prov_pr)
	_box(root, "WellNE", granite, Vector3(1.6, 1.0, 1.6),
		Vector3((uh + 6.0) / 2.0 - 1.0, 0.5, (uh + 6.0) / 2.0 - 1.0), prov_pr)
	_box(root, "KulamWater", water_mat, Vector3(6.0, 0.1, 6.0),
		Vector3(-(uh / 2.0 + 9.0), 0.05, uh / 2.0 + 9.0), prov_pr, false)
	# kavu trees (dressing LOD)
	for i in range(6):
		var tx := -(uh / 2.0 + 11.0) + float(i % 3) * 2.0
		var tz := -(uh / 2.0 + 11.0) + float(i / 3) * 2.0
		_box(root, "KavuTrunk_%d" % i, timber, Vector3(0.35, 4.0, 0.35), Vector3(tx, 2.0, tz), prov_pr, false, 40.0)
		_box(root, "KavuCrown_%d" % i, leaf, Vector3(2.4, 0.6, 2.4), Vector3(tx, 4.2, tz), prov_pr, false, 40.0)

func _build_ring(parent: Node, nm: String, half: float, h: float, mat: Material, prov: Array, gate_side := 1.0) -> void:
	# gate_side +1: gate on east wall; -1: gate on west wall (3 m opening at axis).
	var t := 0.3
	_box(parent, nm + "_N", mat, Vector3(half * 2.0, h, t), Vector3(0, h / 2.0, -half), prov)
	_box(parent, nm + "_S", mat, Vector3(half * 2.0, h, t), Vector3(0, h / 2.0, half), prov)
	var seg := half - 1.5
	if gate_side > 0.0:
		_box(parent, nm + "_W", mat, Vector3(t, h, half * 2.0), Vector3(-half, h / 2.0, 0), prov)
		_box(parent, nm + "_E_N", mat, Vector3(t, h, seg), Vector3(half, h / 2.0, -(1.5 + seg / 2.0)), prov)
		_box(parent, nm + "_E_S", mat, Vector3(t, h, seg), Vector3(half, h / 2.0, (1.5 + seg / 2.0)), prov)
	else:
		_box(parent, nm + "_E", mat, Vector3(t, h, half * 2.0), Vector3(half, h / 2.0, 0), prov)
		_box(parent, nm + "_W_N", mat, Vector3(t, h, seg), Vector3(-half, h / 2.0, -(1.5 + seg / 2.0)), prov)
		_box(parent, nm + "_W_S", mat, Vector3(t, h, seg), Vector3(-half, h / 2.0, (1.5 + seg / 2.0)), prov)

func _build_circular_ksetra(root: Node, gh: float, uh: float, west: bool,
		granite: Material, laterite: Material, timber: Material, copper: Material,
		cream: Material, leaf: Material, water_mat: Material, prov_pr: Array) -> void:
	# Shiva circular ekatala: cylinder massing + conical timber roof + linga/pitha/nala.
	# Provenance: TS-P2V1-measure (range), TS-P2V2-yoni (west+dhvaja pairing),
	# TS-P2V16B-nishkrama (moulding projections), TS-P2V17B-garbhawall (shell),
	# TS-P2V119B-linga14 (4-hasta linga), TS-P2V118B-nala (round Shaiva stem).
	var sgn := -1.0 if west else 1.0
	var door_prov: Array = prov_pr + ["TS-P2V28B-doorwidth", "TS-P2V29B-doorheight", "TS-P2V30B-doorplank"]
	var y := 0.0
	var mould_h := _m(1.5) / 6.0
	var factors := [1.0, 1.0, 1.0, 0.75, 0.5, 0.25]
	var names := ["Paduka", "Jagati", "Kumuda", "Kampa", "Pati", "Vedi"]
	for i in range(6):
		var r: float = gh / 2.0 + mould_h * float(factors[i])
		if i == 0:
			r = gh / 2.0 + mould_h * 1.0 + 0.06
		_cyl(root, "Adhisthana_" + names[i], granite, r, mould_h,
			Vector3(0, y + mould_h / 2.0, 0), prov_pr)
		y += mould_h
	# circular pada: hollow 10-segment ring (inner t = garbha/8 per TS-P2V19B)
	# with door gap on the facing axis; linga darshana through the gap.
	# (Prastara band above stays solid: Rudra crown rises into the roof
	# undercroft — recorded approximation, as with the timber assembly.)
	var h1 := _m(3.0)
	var cwt := gh / 8.0
	var cwall_prov: Array = prov_pr + ["TS-P2V19B-walls"] if not prov_pr.has("TS-P2V19B-walls") else prov_pr
	var door_ang := PI if west else 0.0
	var chord := 2.0 * (gh / 2.0) * sin(PI / 10.0) + 0.06
	for k in range(10):
		var ang := TAU * float(k) / 10.0
		if absf(wrapf(ang - door_ang, -PI, PI)) < PI / 10.0:
			continue  # door gap on the facing axis
		var seg := _box(root, "PadaRing_%d" % k, laterite, Vector3(chord, h1, cwt),
			Vector3(cos(ang) * gh / 2.0, y + h1 / 2.0, sin(ang) * gh / 2.0), cwall_prov)
		seg.rotation.y = -ang
	for k in range(8):
		var ang := TAU * float(k) / 8.0
		if absf(wrapf(ang - door_ang, -PI, PI)) < PI / 9.0:
			continue  # keep the door gap clear of pilasters
		_box(root, "PilasterT1_%d" % k, laterite, Vector3(0.25, h1, 0.25),
			Vector3(cos(ang) * gh / 2.0, y + h1 / 2.0, sin(ang) * gh / 2.0), prov_pr)
	_box(root, "DoorFrame", timber, Vector3(0.2, 2.0, 1.4),
		Vector3(sgn * (gh / 2.0 + cwt / 2.0 + 0.05), y + 1.0, 0), door_prov)
	var ghana_prov: Array = prov_pr + ["TS-P2V26B-bhittivibhaga"] if not prov_pr.has("TS-P2V26B-bhittivibhaga") else prov_pr
	_box(root, "Ghanadvara_E", laterite, Vector3(0.1, 1.75, 0.88),
		Vector3(gh / 2.0 + cwt / 2.0 + 0.02, y + h1 * 0.45, 0), ghana_prov)
	_box(root, "Ghanadvara_N", laterite, Vector3(0.88, 1.75, 0.1),
		Vector3(0, y + h1 * 0.45, -gh / 2.0 - cwt / 2.0 - 0.02), ghana_prov)
	_box(root, "Ghanadvara_S", laterite, Vector3(0.88, 1.75, 0.1),
		Vector3(0, y + h1 * 0.45, gh / 2.0 + cwt / 2.0 + 0.02), ghana_prov)
	y += h1
	# prastara: 9 thin cylinders
	var ph1 := _m(1.5) / 9.0
	for i in range(9):
		_cyl(root, "PrastaraT1_%d" % (i + 1), laterite, gh / 2.0 + 0.25 - 0.01 * i, ph1,
			Vector3(0, y + ph1 / 2.0, 0), prov_pr)
	y += _m(1.5)
	# conical timber roof + kalasha
	_cone(root, "ShikharaRoof", timber, gh / 2.0 + 0.8, _m(3.5), Vector3(0, y, 0), prov_pr)
	y += _m(3.5)
	_box(root, "StupiKalasha", copper, Vector3(0.3, _m(0.75), 0.3),
		Vector3(0, y + _m(0.75) / 2.0, 0), prov_pr)
	# linga tripartite on pitha + round nala stem to north (TS-P2V122B: equal
	# thirds square/octagonal/circular; TS-P2V119B 4-hasta set).
	var linga_h := _m(4.0)
	var linga_base := _m(1.5) + 0.4
	var third := linga_h / 3.0
	_cyl(root, "Pitha", granite, 0.9, 0.4, Vector3(0, _m(1.5) + 0.2, 0), prov_pr)
	_box(root, "LingaBrahma", granite, Vector3(0.5, third, 0.5),
		Vector3(0, linga_base + third / 2.0, 0), prov_pr)
	_cyl(root, "LingaVishnu", granite, 0.25, third,
		Vector3(0, linga_base + third + third / 2.0, 0), prov_pr).sides = 8
	_cyl(root, "LingaRudra", granite, 0.25, third,
		Vector3(0, linga_base + third * 2.0 + third / 2.0, 0), prov_pr)
	_box(root, "NalaStem", granite, Vector3(0.3, 0.25, 1.0), Vector3(0, _m(1.5) + 0.35, -(0.9 + 0.5)), prov_pr)
	# west axis: sopana, mukhamandapa, namaskara, balikkal, dwaja, deepa
	var ex := sgn * gh / 2.0
	_box(root, "Sopana", granite, Vector3(1.2, 0.3, 2.0), Vector3(ex + sgn * 0.9, 0.15, 0), prov_pr)
	var mx := ex + sgn * 3.0
	for px in [mx - 1.0, mx + 1.0]:
		for pz in [-1.0, 1.0]:
			_pillar(root, "MukhaPillar", timber, Vector3(px, 0, pz), 0.25, 2.2, prov_pr)
	_box(root, "MukhaSlab", timber, Vector3(3.0, 0.25, 3.0), Vector3(mx, 2.3, 0), prov_pr)
	_pyramid(root, "MukhaRoof", timber, 3.6, 3.6, 1.0, Vector3(mx, 2.42, 0), prov_pr)
	var nx := ex + sgn * 6.5
	for px in [nx - 1.1, nx + 1.1]:
		for pz in [-1.1, 1.1]:
			_pillar(root, "NamaskaraPillar", timber, Vector3(px, 0, pz), 0.28, 2.4, prov_pr)
	_box(root, "NamaskaraSlab", granite, Vector3(3.0, 0.4, 3.0), Vector3(nx, 0.2, 0), prov_pr)
	_pyramid(root, "NamaskaraRoof", timber, 4.0, 4.0, 1.1, Vector3(nx, 2.62, 0), prov_pr)
	_box(root, "ValiaBalikkal", granite, Vector3(0.8, 1.2, 0.8), Vector3(nx + sgn * 3.0, 0.6, 0), prov_pr)
	_box(root, "DwajaPole", timber, Vector3(0.3, 6.0, 0.3), Vector3(nx + sgn * 5.0, 3.0, 0), prov_pr)
	_box(root, "DwajaTop", copper, Vector3(0.5, 0.5, 0.5), Vector3(nx + sgn * 5.0, 6.2, 0), prov_pr)
	# rings with west gate + west gopura + support buildings
	var gate := -1.0 if west else 1.0
	_build_ring(root, "Nalambalam", uh + 6.0, 2.2, cream, prov_pr, gate)
	_build_ring(root, "Vilakkumadam", uh + 10.0, 1.2, timber, prov_pr, gate)
	_build_ring(root, "MaryadaWall", uh + 18.0, 1.5, laterite, prov_pr, gate)
	var gx := sgn * (uh + 18.0) / 2.0
	_box(root, "GopuraBase", cream, Vector3(2.0, 3.0, 5.0), Vector3(gx, 1.5, 0), prov_pr)
	_box(root, "GopuraTop", cream, Vector3(2.4, 2.0, 5.6), Vector3(gx, 4.0, 0), prov_pr)
	_pyramid(root, "GopuraRoof", timber, 3.0, 6.2, 1.4, Vector3(gx, 5.0, 0), prov_pr)
	_box(root, "Thidappalli", cream, Vector3(3.0, 2.0, 3.0),
		Vector3((uh + 6.0) / 2.0 - 1.0, 1.0, -((uh + 6.0) / 2.0 - 1.0)), prov_pr)
	_box(root, "WellNE", granite, Vector3(1.6, 1.0, 1.6),
		Vector3((uh + 6.0) / 2.0 - 1.0, 0.5, (uh + 6.0) / 2.0 - 1.0), prov_pr)

func _pillar(parent: Node, nm: String, mat: Material, pos_base: Vector3,
		w: float, h: float, prov: Array) -> void:
	# Stambha with oma pedestal (TS-P2V25B: oma twice pillar width, half width high).
	_box(parent, nm + "_Oma", mat, Vector3(w * 2.0, w / 2.0, w * 2.0),
		pos_base + Vector3(0, w / 4.0, 0), prov)
	_box(parent, nm, mat, Vector3(w, h, w),
		pos_base + Vector3(0, w / 2.0 + h / 2.0, 0), prov)

func _build_hall(parent: Node, nm: String, at: Vector3, wood: Material, base_mat: Material, prov: Array) -> void:
	_box(parent, nm + "_Plinth", base_mat, Vector3(5.0, 0.4, 4.0), at + Vector3(0, 0.2, 0), prov)
	for ox in [-2.0, 2.0]:
		for oz in [-1.5, 1.5]:
			_pillar(parent, nm + "_Pillar", wood, at + Vector3(ox, 0.4, oz), 0.25, 2.3, prov)
	_box(parent, nm + "_Roof", wood, Vector3(5.6, 0.25, 4.6), at + Vector3(0, 2.8, 0), prov)
	_pyramid(parent, nm + "_Top", wood, 6.0, 5.0, 1.0, at + Vector3(0, 2.92, 0), prov)

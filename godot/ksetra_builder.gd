extends Node3D
## Procedural Vishnu-dvitala ksetra builder (code-first, no static imports).
## Reads vishnu-dvitala.v1.json via KsetraSpecLoader, validates fail-closed,
## then generates every semantic node with metadata provenance (rule ids).
## Collision: solid CSG keeps use_collision; dressing gets visibility ranges.
class_name KsetraBuilder

const Loader = preload("res://godot/ksetra_spec_loader.gd")

var spec: Dictionary = {}
var errors: Array = []
var _timber_batch: Array = []

func _aimed_batch(a: Vector3, b: Vector3, w: float, h: float) -> void:
	var d := b - a
	var length := d.length() + 0.15
	_timber_batch.append(Transform3D(Basis.looking_at(d.normalized()).scaled(Vector3(w, h, length)), (a + b) / 2.0))

func _flush_timber(parent: Node, mat: Material, prov: Array) -> void:
	# One instanced draw for all dressed-pillar corbels + struts batched above.
	if _timber_batch.is_empty():
		return
	_mmi(parent, "DressedJoinerySet", _shared_box("unit_beam", Vector3.ONE),
		_timber_batch, mat, prov, 0.0, CRAFT_TIMBER)
	_timber_batch.clear()

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
		prov: Array, collide := true, lod_end := 0.0, craft := {}) -> CSGBox3D:
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
	if not craft.is_empty():
		b.set_meta("craft_visual", craft)
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
		pos: Vector3, prov: Array, collide := true, lod_end := 0.0) -> CSGCylinder3D:
	var c := CSGCylinder3D.new()
	c.name = nm
	c.material = mat
	c.radius = radius
	c.height = height
	c.sides = 24
	c.position = pos
	c.use_collision = collide
	if lod_end > 0.0:
		c.visibility_range_begin = 0.0
		c.visibility_range_end = lod_end
		c.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	c.set_meta("provenance", prov)
	parent.add_child(c)
	return c

func _lod(n: Node, lod_end: float) -> Node:
	# Far dressing cull for small overlays (regalia, knobs, spokes, horns).
	# Works on any GeometryInstance3D (CSG or mesh); returns the node.
	if n is GeometryInstance3D and lod_end > 0.0:
		n.set("visibility_range_begin", 0.0)
		n.set("visibility_range_end", lod_end)
		n.set("visibility_range_fade_mode", GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF)
	return n

func _lathe(parent: Node, nm: String, mat: Material, radius: float, h: float,
		profile: Array, pos: Vector3, prov: Array, segs := 12) -> MeshInstance3D:
	# Lathed vessel/finial/figure: profile = Array[Vector2] radius-fraction x height-fraction,
	# revolved around Y. No collision (dressing/hero overlay); provenance-tagged.
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = _lathe_mesh(profile, radius, h, segs)
	mi.material_override = mat
	mi.position = pos
	mi.set_meta("provenance", prov)
	parent.add_child(mi)
	return mi

static var _shared_mesh := {}

static func _shared_box(key: String, size: Vector3) -> BoxMesh:
	if not _shared_mesh.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_shared_mesh[key] = bm
	return _shared_mesh[key]

static func _shared_lathe(key: String, profile: Array, radius: float, h: float, segs := 12) -> ArrayMesh:
	if not _shared_mesh.has(key):
		_shared_mesh[key] = _lathe_mesh(profile, radius, h, segs)
	return _shared_mesh[key]

static func _lathe_mesh(profile: Array, radius: float, h: float, segs := 12) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector2] = [Vector2(0.0, 0.0)]
	for p in profile:
		pts.append(Vector2(float(p.x) * radius, float(p.y) * h))
	for i in range(pts.size() - 1):
		for s in range(segs):
			var a0 := TAU * float(s) / segs
			var a1 := TAU * float(s + 1) / segs
			var p00 := Vector3(cos(a0) * pts[i].x, pts[i].y, sin(a0) * pts[i].x)
			var p01 := Vector3(cos(a1) * pts[i].x, pts[i].y, sin(a1) * pts[i].x)
			var p10 := Vector3(cos(a0) * pts[i + 1].x, pts[i + 1].y, sin(a0) * pts[i + 1].x)
			var p11 := Vector3(cos(a1) * pts[i + 1].x, pts[i + 1].y, sin(a1) * pts[i + 1].x)
			_tri(st, p00, p11, p01)
			_tri(st, p00, p10, p11)
	st.generate_normals()
	return st.commit()

static func _mmi(parent: Node, nm: String, mesh: Mesh, transforms: Array, mat: Material,
		prov: Array, lod_end := 0.0, craft := {}) -> MultiMeshInstance3D:
	# Instanced dressing: one draw for N repeats (palikas, kavu, flags, vessels).
	# No collision (dressing only); LOD + provenance + optional craft on the set.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = mat
	if lod_end > 0.0:
		mmi.visibility_range_begin = 0.0
		mmi.visibility_range_end = lod_end
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.set_meta("provenance", prov)
	if not craft.is_empty():
		mmi.set_meta("craft_visual", craft)
	mmi.position = Vector3.ZERO
	parent.add_child(mmi)
	return mmi

func _ball(parent: Node, nm: String, mat: Material, radius: float, h: float,
		pos: Vector3, prov: Array) -> MeshInstance3D:
	# SphereMesh head/knob/fruit overlay. No collision; provenance-tagged.
	var mi := MeshInstance3D.new()
	mi.name = nm
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = h
	sm.radial_segments = 12
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.set_meta("provenance", prov)
	parent.add_child(mi)
	return mi

func _eave_pyramid(parent: Node, nm: String, mat: Material, w: float, d: float, h: float,
		pos: Vector3, prov: Array, lip := 0.3) -> MeshInstance3D:
	# Tiled-slope pyramid with overhang lip + eave skirt (no see-through gap).
	# Same construction contract as _pyramid: overlay only, no collision.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w / 2.0 + lip
	var hd := d / 2.0 + lip
	var apex := Vector3(0, h, 0)
	var corners := [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd),
		Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]
	for i in range(4):
		_tri(st, corners[i], apex, corners[(i + 1) % 4])
	for i in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		_tri(st, Vector3(a.x, -0.12, a.z), Vector3(a.x, 0, a.z), Vector3(b.x, 0, b.z))
		_tri(st, Vector3(a.x, -0.12, a.z), Vector3(b.x, 0, b.z), Vector3(b.x, -0.12, b.z))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	mi.set_meta("provenance", prov)
	parent.add_child(mi)
	return mi

func _mat(color: Color, rough := 0.8, metal := 0.0, emission := 0.0, detail := "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if detail == "stone" or detail == "grain" or detail == "moss":
		# Procedural craft microdetail (never canon): grayscale/tinted albedo
		# with cavity bake + heightmap relief + roughness + Sobel normal,
		# generated once and shared. No binary assets.
		m.albedo_texture = _detail_albedo(detail)
		m.heightmap_enabled = true
		m.heightmap_texture = _detail_height(detail)
		m.heightmap_scale = 0.02
		m.roughness_texture = _detail_rough(detail)
		m.normal_enabled = true
		m.normal_texture = _detail_normal(detail)
		m.normal_scale = 0.6
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

static var _detail_cache := {}

static func _value_noise(gx: int, gy: int, seed: int) -> float:
	# Deterministic lattice hash in [0,1).
	var h := gx * 374761393 + gy * 668265263 + seed * 144665
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7fffffff) / float(0x7fffffff)

static func _noise_at(x: float, y: float, cells: int, seed: int) -> float:
	var xi: int = int(floor(x))
	var yi: int = int(floor(y))
	var xf: float = x - floor(x)
	var yf: float = y - floor(y)
	var u: float = xf * xf * (3.0 - 2.0 * xf)
	var v: float = yf * yf * (3.0 - 2.0 * yf)
	var a := _value_noise(posmod(xi, cells), posmod(yi, cells), seed)
	var b := _value_noise(posmod(xi + 1, cells), posmod(yi, cells), seed)
	var c := _value_noise(posmod(xi, cells), posmod(yi + 1, cells), seed)
	var d := _value_noise(posmod(xi + 1, cells), posmod(yi + 1, cells), seed)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)

static func _detail_images(kind: String) -> Array:
	if _detail_cache.has(kind):
		return _detail_cache[kind]
	# 128px three-map set: grayscale albedo (with moss/dirt two-tone + cavity
	# bake), height relief, roughness variation. "moss" kind adds green-brown
	# age patches for footings, grove stones and tank curbs. Runtime-only,
	# no binary assets. NOTE: Godot 4 name is normal_texture (see below).
	var moss_kind := kind == "moss"
	var seed := 1234
	var cells := 8
	var cells_y := 8
	if kind == "grain":
		seed = 987
		cells = 6
		cells_y = 12  # directional anisotropy: stretched plank figure
	if moss_kind:
		seed = 4321
	var size := 128
	var alb := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var hgt: Array = []
	for yy in range(size + 1):
		hgt.append([])
		for xx in range(size + 1):
			var fx := float(xx) / size * cells
			var fy := float(yy) / size * cells_y
			var n := _noise_at(fx, fy, cells, seed)
			n = n * 0.65 + _noise_at(fx * 2.7, fy * 2.7, cells * 2, seed + 7) * 0.35
			if kind == "grain":
				n = n * 0.5 + (0.5 + 0.5 * sin(fy * 6.28 + n * 9.0)) * 0.5
			else:
				# age blotches: low-frequency damp/moss darkening on stone
				var blotch := _noise_at(fx * 0.5 + 3.1, fy * 0.5 + 7.7, 4, seed + 31)
				n = n * 0.8 + blotch * 0.2
			hgt[yy].append(n)
	var hgt_img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rgh_img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var nrm_img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for yy in range(size):
		for xx in range(size):
			var hv: float = hgt[yy][xx]
			# cavity bake: pits read darker (occluded-dirt feel in albedo)
			var cav: float = clampf(0.72 + hv * 0.38, 0.0, 1.0)
			if moss_kind:
				var moss_n := _noise_at(float(xx) / size * 5.0 + 11.0, float(yy) / size * 5.0 + 5.0, 5, seed + 77)
				var moss_m: float = clampf((moss_n - 0.45) * 2.2, 0.0, 1.0)
				alb.set_pixel(xx, yy, Color(cav * (0.75 - moss_m * 0.25), cav * (0.82 - moss_m * 0.08), cav * 0.62, 1.0))
			else:
				var g := (0.88 + hv * 0.12) * cav
				alb.set_pixel(xx, yy, Color(g, g, g, 1.0))
			hgt_img.set_pixel(xx, yy, Color(hv, hv, hv, 1.0))
			var rv := 0.72 + hv * 0.28
			rgh_img.set_pixel(xx, yy, Color(rv, rv, rv, 1.0))
			var nx: float = float(hgt[yy][mini(xx + 1, size)]) - float(hgt[yy][maxi(xx - 1, 0)])
			var ny: float = float(hgt[mini(yy + 1, size)][xx]) - float(hgt[maxi(yy - 1, 0)][xx])
			var nv := Vector3(-nx * 1.4, -ny * 1.4, 1.0).normalized()
			nrm_img.set_pixel(xx, yy, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5, 1.0))
	var out := [ImageTexture.create_from_image(alb), ImageTexture.create_from_image(hgt_img),
		ImageTexture.create_from_image(rgh_img), ImageTexture.create_from_image(nrm_img)]
	_detail_cache[kind] = out
	return out

static func _detail_albedo(kind: String) -> ImageTexture:
	return _detail_images(kind)[0]

static func _detail_height(kind: String) -> ImageTexture:
	return _detail_images(kind)[1]

static func _detail_rough(kind: String) -> ImageTexture:
	return _detail_images(kind)[2]

static func _detail_normal(kind: String) -> ImageTexture:
	return _detail_images(kind)[3]

static var _card_cache := {}

static func _leaf_card() -> ArrayMesh:
	# Procedural leaf-cluster card (alpha): two crossed quads with painted
	# leaflets. Runtime-only, no binary assets. For MultiMesh canopies.
	if _card_cache.has("leaf"):
		return _card_cache["leaf"]
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for li in range(14):
		var cx := rng.randf_range(12.0, 52.0)
		var cy := rng.randf_range(12.0, 52.0)
		var rx := rng.randf_range(5.0, 11.0)
		var ry := rng.randf_range(3.0, 6.0)
		var rot := rng.randf_range(0.0, TAU)
		var shade := rng.randf_range(0.75, 1.1)
		for yy in range(size):
			for xx in range(size):
				var dx := float(xx) - cx
				var dy := float(yy) - cy
				var lx := dx * cos(rot) + dy * sin(rot)
				var ly := -dx * sin(rot) + dy * cos(rot)
				var e := (lx * lx) / (rx * rx) + (ly * ly) / (ry * ry)
				if e <= 1.0:
					var edge := clampf((1.0 - e) * 3.0, 0.35, 1.0)
					img.set_pixel(xx, yy, Color(0.13 * shade, 0.42 * shade, 0.16 * shade, edge))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.5
	# quad 1 (XY plane)
	_tri_uv(st, Vector3(-0.5, -h, 0), Vector3(0.5, -h, 0), Vector3(0.5, h, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0))
	_tri_uv(st, Vector3(-0.5, -h, 0), Vector3(0.5, h, 0), Vector3(-0.5, h, 0), Vector2(0, 1), Vector2(1, 0), Vector2(0, 0))
	# quad 2 (ZY plane, crossed)
	_tri_uv(st, Vector3(0, -h, -0.5), Vector3(0, -h, 0.5), Vector3(0, h, 0.5), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0))
	_tri_uv(st, Vector3(0, -h, -0.5), Vector3(0, h, 0.5), Vector3(0, h, -0.5), Vector2(0, 1), Vector2(1, 0), Vector2(0, 0))
	st.generate_normals()
	var mesh := st.commit()
	_card_cache["leaf_tex"] = ImageTexture.create_from_image(img)
	_card_cache["leaf"] = mesh
	return mesh

static func _leaf_card_mat() -> StandardMaterial3D:
	if _card_cache.has("leaf_mat"):
		return _card_cache["leaf_mat"]
	_leaf_card()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.6, 0.45)
	m.albedo_texture = _card_cache["leaf_tex"]
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_card_cache["leaf_mat"] = m
	return m

static func _tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2) -> void:
	st.set_uv(uva)
	st.add_vertex(a)
	st.set_uv(uvb)
	st.add_vertex(b)
	st.set_uv(uvc)
	st.add_vertex(c)

static func _craft(node: Node, kind: String, basis: String, replaces: String) -> void:
	# CRAFT-VISUAL metadata (visual craft only, never canon; see kg/ontology.md).
	# kind: profile|massing|material|placement. Faces/tala/yoni/dimensions stay prov-only.
	node.set_meta("craft_visual", {"kind": kind, "basis": basis,
		"status": "OPEN-adjacent", "replaces": replaces})

const CRAFT_ROOF := {"kind": "massing", "basis": "Kerala field convention",
	"status": "OPEN-adjacent", "replaces": "solid pyramid approximation (TS-P2V48B timber note)"}
const CRAFT_GABLE := {"kind": "massing", "basis": "Kerala field convention",
	"status": "OPEN-adjacent", "replaces": "bare gabled eave (rectangular plan needs ridge, not pyramid)"}

func _gable_assembly(parent: Node, nm: String, mat: Material, center: Vector3,
		half_span: float, half_len: float, h: float, prov: Array) -> void:
	# Gabled tile roof for rectangular footprints: ridge beam + 2x4 slope
	# rafters + 2 batten bands per slope + gable fascia boards. Overlay only.
	var ridge_a := center + Vector3(0, h, -half_len)
	var ridge_b := center + Vector3(0, h, half_len)
	var members: Array = []
	_aimed(members, ridge_a, ridge_b, 0.12, 0.14)
	for zi in range(4):
		var z := lerpf(-half_len + 0.3, half_len - 0.3, float(zi) / 3.0)
		for sgn in [-1.0, 1.0]:
			_aimed(members, center + Vector3(sgn * half_span, 0, z),
				center + Vector3(0, h, z), 0.09, 0.12)
	for esgn in [-1.0, 1.0]:
		_aimed(members, center + Vector3(0, 0.05, esgn * (half_len + 0.1)),
			center + Vector3(0, h, esgn * (half_len - 0.2)), 0.1, 0.14)
	_mmi(parent, nm + "_Members", _shared_box("unit_beam", Vector3.ONE),
		members, mat, prov, 0.0, CRAFT_GABLE)
	var gbattens: Array = []
	for t in range(2):
		var frac := float(t + 1) / 3.0
		var bx := half_span * (1.0 - frac) + 0.06
		var by := h * frac
		for sgn in [-1.0, 1.0]:
			gbattens.append(Transform3D(Basis.from_scale(Vector3(0.12, 0.07, half_len * 2.0 - 0.2)),
				center + Vector3(sgn * bx, by, 0)))
	_mmi(parent, nm + "_Battens", _shared_box("unit_beam", Vector3.ONE),
		gbattens, mat, prov, 0.0, CRAFT_GABLE)
const CRAFT_PROFILE := {"kind": "profile", "basis": "Kerala field convention",
	"status": "OPEN-adjacent", "replaces": "flat stepped slabs (TS-P2V16B widths kept exact)"}

func _slope_shell(parent: Node, nm: String, mat: Material, w_bot: float, w_top: float,
		y0: float, h: float, prov: Array, craft := {}) -> MeshInstance3D:
	# Sloped moulding face ring: square ring rising from half-width w_bot to
	# w_top (ogee/cove/chamfer/batter by caller widths). Open quads only, never
	# coplanar with the structural course inside; no collision (overlay).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cb := w_bot / 2.0
	var ct := w_top / 2.0
	var c := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
	for i in range(4):
		var b0 := Vector3(c[i].x * cb, y0, c[i].z * cb)
		var b1 := Vector3(c[(i + 1) % 4].x * cb, y0, c[(i + 1) % 4].z * cb)
		var t0 := Vector3(c[i].x * ct, y0 + h, c[i].z * ct)
		var t1 := Vector3(c[(i + 1) % 4].x * ct, y0 + h, c[(i + 1) % 4].z * ct)
		_tri(st, b0, t0, t1)
		_tri(st, b0, t1, b1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = Vector3.ZERO
	mi.set_meta("provenance", prov)
	if not craft.is_empty():
		mi.set_meta("craft_visual", craft)
	parent.add_child(mi)
	return mi

func _beam_to(parent: Node, nm: String, mat: Material, a: Vector3, b: Vector3,
		thick: Vector2, prov: Array, craft := {}) -> CSGBox3D:
	# Timber member between two points (rafter/hip/strut/beam): z-axis box aimed
	# with look_at. No collision (overlay joinery); provenance + optional craft.
	var beam := CSGBox3D.new()
	beam.name = nm
	beam.material = mat
	var length := a.distance_to(b) + 0.15
	beam.size = Vector3(thick.x, thick.y, length)
	parent.add_child(beam)
	beam.position = (a + b) / 2.0
	if (a - b).length() > 0.001:
		beam.look_at(b, Vector3.UP)
	beam.use_collision = false
	beam.set_meta("provenance", prov)
	if not craft.is_empty():
		beam.set_meta("craft_visual", craft)
	return beam

static func _aimed(xf: Array, a: Vector3, b: Vector3, w: float, h: float) -> void:
	# Aimed-member transform for the shared unit-beam mesh: z-axis along a->b.
	var d := b - a
	var length := d.length() + 0.15
	xf.append(Transform3D(Basis.looking_at(d.normalized()).scaled(Vector3(w, h, length)), (a + b) / 2.0))

static func _unit_box(parent: Node, nm: String, transforms: Array, mat: Material,
		prov: Array, lod_end := 0.0, craft := {}) -> MultiMeshInstance3D:
	return _mmi(parent, nm, _shared_box("unit_beam", Vector3.ONE), transforms, mat, prov, lod_end, craft)

func _roof_assembly(parent: Node, nm: String, mat: Material, center: Vector3,
		half_w: float, h: float, per_side: int, bands: int, prov: Array) -> void:
	# Layered Kerala timber-and-tile assembly over a pyramid footprint:
	# per-side kazhukkol rafters to the apex + 4 hip ribs + tile batten rings.
	# Two instanced draws (members + battens); overlay only (no collision);
	# eave shell underneath keeps weather line.
	var apex := center + Vector3(0, h, 0)
	var members: Array = []
	for s in range(4):
		var yaw := float(s) * PI / 2.0
		for k in range(per_side):
			var xi := lerpf(-half_w + 0.35, half_w - 0.35, float(k) / float(maxi(per_side - 1, 1)))
			_aimed(members, center + Vector3(xi, 0, half_w).rotated(Vector3.UP, yaw), apex, 0.09, 0.12)
		_aimed(members, center + Vector3(half_w, 0, half_w).rotated(Vector3.UP, yaw), apex, 0.12, 0.14)
	_mmi(parent, nm + "_Members", _shared_box("unit_beam", Vector3.ONE),
		members, mat, prov, 0.0, CRAFT_ROOF)
	var battens: Array = []
	for t in range(bands):
		var frac := float(t + 1) / float(bands + 1)
		var bw := half_w * (1.0 - frac) + 0.1
		var by := h * frac
		battens.append(Transform3D(Basis.from_scale(Vector3(bw * 2.0 + 0.1, 0.07, 0.14)), center + Vector3(0, by, -bw)))
		battens.append(Transform3D(Basis.from_scale(Vector3(bw * 2.0 + 0.1, 0.07, 0.14)), center + Vector3(0, by, bw)))
		battens.append(Transform3D(Basis.from_scale(Vector3(0.14, 0.07, bw * 2.0 + 0.1)), center + Vector3(bw, by, 0)))
		battens.append(Transform3D(Basis.from_scale(Vector3(0.14, 0.07, bw * 2.0 + 0.1)), center + Vector3(-bw, by, 0)))
	if not battens.is_empty():
		_mmi(parent, nm + "_Battens", _shared_box("unit_beam", Vector3.ONE),
			battens, mat, prov, 0.0, CRAFT_ROOF)

func _tile_field(parent: Node, nm: String, mat: Material, center: Vector3,
		half_w: float, h: float, courses: int, prov: Array) -> void:
	# Tile-by-tile instanced courses on the four pyramid slopes: one draw for
	# the whole field. Tiles ride 5cm proud of the weather line; pitch matches
	# the slope. Craft massing over the V48B timber program.
	var alpha := atan2(half_w, h)
	var tiles: Array = []
	for t in range(courses):
		var frac := float(t + 1) / float(courses + 1)
		var hw := half_w * (1.0 - frac)
		var hy := h * frac
		var n := maxi(int(2.0 * hw / 0.3), 1)
		for s in range(4):
			var yaw := float(s) * PI / 2.0
			var rot := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, alpha)
			for k in range(n):
				var xi := lerpf(-hw + 0.15, hw - 0.15, float(k) / float(maxi(n - 1, 1)))
				var base := center + Vector3(xi, hy, hw).rotated(Vector3.UP, yaw)
				var lift := Vector3(0, h, half_w).rotated(Vector3.UP, yaw).normalized() * 0.05
				tiles.append(Transform3D(rot.scaled(Vector3(0.28, 0.04, 0.38)), base + lift))
	_mmi(parent, nm + "_Tiles", _shared_box("unit_beam", Vector3.ONE),
		tiles, mat, prov, 0.0, CRAFT_ROOF)

func _build_all() -> void:
	var pr: Dictionary = spec["prasada"]
	var gh := _m(float(pr["garbha_hasta"]))
	var uh := _m(float(pr["uttara_hasta"]))
	var prov_pr: Array = pr.get("provenance", [])
	var granite := _mat(Color(0.42, 0.43, 0.46), 0.8, 0.1, 0.0, "stone")
	var moss := _mat(Color(0.42, 0.43, 0.40), 0.95, 0.0, 0.0, "moss")
	var laterite := _mat(Color(0.48, 0.22, 0.13), 0.8, 0.0, 0.0, "stone")
	var timber := _mat(Color(0.38, 0.24, 0.13), 0.7, 0.0, 0.0, "grain")
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
	# Structural courses keep exact canon widths + collision; sloped shells give
	# the ogee/cove/chamfer faces (2mm+ proud, never coplanar). Kumuda gets a
	# two-slope ogee bulge; course names follow the spec mouldings list.
	var y := 0.0
	var mould_h := _m(1.5) / 6.0
	var names := ["Paduka", "Jagati", "Kumuda", "Gala", "Pati", "Vedi"]
	var factors := [1.0, 1.0, 1.0, 0.75, 0.5, 0.25]
	for i in range(6):
		var w: float = gh + 2.0 * mould_h * float(factors[i])
		if i == 0:
			w = gh + 2.0 * mould_h * 1.0 + 0.12  # paduka footing off jagati line
		_box(root, "Adhisthana_" + names[i], granite,
			Vector3(w, mould_h, w), Vector3(0, y + mould_h / 2.0, 0), prov_pr)
		# mid-course arris bead: thin proud ring at the joint line (craft bevel).
		_box(root, "Adhisthana_Bead_%d" % i, granite,
			Vector3(w + 0.03, 0.03, w + 0.03), Vector3(0, y + mould_h - 0.015, 0), prov_pr)
		var hw := w / 2.0
		if names[i] == "Kumuda":
			_slope_shell(root, "Adhisthana_Kumuda_BulgeLo", granite,
				w + 0.004, w + 0.07, y, mould_h / 2.0, prov_pr, CRAFT_PROFILE)
			_slope_shell(root, "Adhisthana_Kumuda_BulgeHi", granite,
				w + 0.07, w + 0.004, y + mould_h / 2.0, mould_h / 2.0, prov_pr, CRAFT_PROFILE)
		elif names[i] == "Pati":
			_slope_shell(root, "Adhisthana_Pati_Band", granite,
				w + 0.05, w + 0.05, y, mould_h, prov_pr, CRAFT_PROFILE)
		elif names[i] == "Vedi":
			_slope_shell(root, "Adhisthana_Vedi_Cove", granite,
				w + 0.04, w + 0.004, y, mould_h, prov_pr, CRAFT_PROFILE)
		elif names[i] == "Gala":
			_slope_shell(root, "Adhisthana_Gala_Fillet", granite,
				w + 0.004, w + 0.04, y, mould_h, prov_pr, CRAFT_PROFILE)
		else:
			_slope_shell(root, "Adhisthana_" + names[i] + "_Face", granite,
				w + 0.004, w + 0.004, y, mould_h, prov_pr, CRAFT_PROFILE)
		y += mould_h
	# --- tala1 pada: hollow laterite walls (inner t = garbha/8 per TS-P2V19B),
	# east door gap with lintel (divisors/height/planks TS-P2V28B/29B/30B) ---
	var h1 := _m(3.0)
	var wt := gh / 8.0
	var wall_prov: Array = prov_pr + ["TS-P2V19B-walls"] if not prov_pr.has("TS-P2V19B-walls") else prov_pr
	_box(root, "PadaT1_N", laterite, Vector3(gh, h1, wt), Vector3(0, y + h1 / 2.0, -gh / 2.0 + wt / 2.0), wall_prov)
	_box(root, "PadaT1_S", laterite, Vector3(gh, h1, wt), Vector3(0, y + h1 / 2.0, gh / 2.0 - wt / 2.0), wall_prov)
	_box(root, "PadaT1_W", laterite, Vector3(wt, h1, gh - 2.0 * wt), Vector3(-gh / 2.0 + wt / 2.0, y + h1 / 2.0, 0), wall_prov)
	var dw := gh / 3.0
	var dh := h1 * 0.85
	var segw := (gh - 2.0 * wt - dw) / 2.0
	_box(root, "PadaT1_E_N", laterite, Vector3(wt, h1, segw),
		Vector3(gh / 2.0 - wt / 2.0, y + h1 / 2.0, -(dw / 2.0 + segw / 2.0)), door_prov)
	_box(root, "PadaT1_E_S", laterite, Vector3(wt, h1, segw),
		Vector3(gh / 2.0 - wt / 2.0, y + h1 / 2.0, dw / 2.0 + segw / 2.0), door_prov)
	_box(root, "PadaT1_Lintel", laterite, Vector3(wt, h1 - dh, dw),
		Vector3(gh / 2.0 - wt / 2.0, y + dh + (h1 - dh) / 2.0, 0), door_prov)
	# door furniture: 3-strip sakha jambs, open leaves folded to the outer
	# faces (passage stays walkable), threshold sill. Plank grain reads from
	# the timber maps (TS-P2V30B); leaf positions are craft (open for darshana).
	for jsgn in [-1.0, 1.0]:
		for ji in range(3):
			_box(root, "DoorJamb_%d_%d" % [jsgn, ji], timber,
				Vector3(0.08, dh, 0.12),
				Vector3(gh / 2.0 + 0.04, y + dh / 2.0, jsgn * (dw / 2.0 + 0.1 + float(ji) * 0.14)),
				door_prov, true, 0.0, CRAFT_TIMBER)
	for lsgn in [-1.0, 1.0]:
		var leaf_x: float = gh / 2.0 + 0.05
		var leaf_z: float = lsgn * (dw / 2.0 + 0.42)
		_box(root, "DoorLeaf_%d" % lsgn, timber, Vector3(0.06, dh - 0.1, 0.55),
			Vector3(leaf_x, y + dh / 2.0, leaf_z),
			door_prov, true, 0.0, CRAFT_TIMBER)
		for hy in [-1.0, 1.0]:
			_box(root, "DoorHinge_%d_%d" % [lsgn, hy], copper, Vector3(0.03, 0.12, 0.1),
				Vector3(leaf_x + 0.045, y + dh / 2.0 + hy * dh * 0.3, leaf_z - lsgn * 0.2),
				door_prov, false, 0.0, CRAFT_TIMBER)
		_box(root, "DoorBolt_%d" % lsgn, copper, Vector3(0.04, 0.05, 0.4),
			Vector3(leaf_x + 0.05, y + dh / 2.0, leaf_z),
			door_prov, false, 0.0, CRAFT_TIMBER)
	_box(root, "DoorSill", granite, Vector3(wt + 0.2, 0.08, dw),
		Vector3(gh / 2.0 - wt / 2.0, y + 0.04, 0), door_prov)
	# garbhagriha interior: padma-pitha + standing Vishnu (stylized massing;
	# height/width/diadem per V121B/V123B/V109B, tala grades V86B; darshana
	# through the east door; Tantri-only crossing per K-TANTRI-ONLY)
	var bimba_prov: Array = ["TS-P2V121B-bimbaheight", "TS-P2V123B-bimbawidth", "TS-P2V109B-diadem", "TS-P2V117B-padmapitha"]
	_box(root, "Pitha", granite, Vector3(1.0, 0.4, 1.0), Vector3(0, y + 0.2, 0), bimba_prov)
	_cyl(root, "PadmaCapital", cream, 0.42, 0.15, Vector3(0, y + 0.47, 0), bimba_prov, false)
	# hero Vishnu (stylized massing, no invented face): tapered lathe body,
	# sphere head, lathe diadem, four stub arms with four emblems
	# (shankha/chakra/gada/padma per meta iconography).
	_lathe(root, "BimbaBody", granite, 0.28, 1.1,
		[Vector2(1.0, 0.0), Vector2(0.72, 1.0)], Vector3(0, y + 0.55, 0), bimba_prov)
	# sacred-thread + waistband relief rings (craft bands on the canon massing)
	_cyl(root, "BimbaThread", cream, 0.26, 0.05, Vector3(0, y + 1.35, 0), bimba_prov, false)
	_cyl(root, "BimbaWaistband", copper, 0.28, 0.07, Vector3(0, y + 0.75, 0), bimba_prov, false)
	_ball(root, "BimbaHead", granite, 0.16, 0.32, Vector3(0, y + 1.8, 0), bimba_prov)
	_lathe(root, "BimbaDiadem", copper, 0.2, 0.22,
		[Vector2(1.0, 0.0), Vector2(0.9, 0.4), Vector2(0.7, 0.7), Vector2(0.0, 1.0)], Vector3(0, y + 1.89, 0), bimba_prov)
	_lod(_ball(root, "BimbaUshnisha", copper, 0.07, 0.1, Vector3(0, y + 2.14, 0), bimba_prov), 25.0)
	_box(root, "BimbaArmL1", granite, Vector3(0.14, 0.7, 0.14), Vector3(-0.36, y + 1.15, 0.1), bimba_prov, false)
	_box(root, "BimbaArmR1", granite, Vector3(0.14, 0.7, 0.14), Vector3(0.36, y + 1.15, 0.1), bimba_prov, false)
	_box(root, "BimbaArmL2", granite, Vector3(0.14, 0.7, 0.14), Vector3(-0.36, y + 1.15, -0.12), bimba_prov, false)
	_box(root, "BimbaArmR2", granite, Vector3(0.14, 0.7, 0.14), Vector3(0.36, y + 1.15, -0.12), bimba_prov, false)
	_lod(_ball(root, "EmblemShankha", cream, 0.07, 0.14, Vector3(-0.36, y + 0.78, 0.15), bimba_prov), 25.0)
	_lod(_cyl(root, "EmblemChakra", copper, 0.09, 0.03, Vector3(0.36, y + 0.78, 0.15), bimba_prov, false), 25.0)
	for spi in range(8):
		var sang := float(spi) * PI / 4.0
		_lod(_box(root, "ChakraSpoke_%d" % spi, copper, Vector3(0.02, 0.16, 0.02),
			Vector3(0.36 + cos(sang) * 0.05, y + 0.78 + sin(sang) * 0.05, 0.15), bimba_prov, false), 25.0)
	_lod(_box(root, "EmblemGadaKnob", copper, Vector3(0.1, 0.1, 0.1),
		Vector3(-0.36, y + 1.02, -0.12), bimba_prov, false), 25.0)
	for ppi in range(8):
		var pang := float(ppi) * PI / 4.0 + PI / 8.0
		_lod(_box(root, "PadmaPetal_%d" % ppi, cream, Vector3(0.05, 0.04, 0.12),
			Vector3(0.36 + cos(pang) * 0.09, y + 0.8, -0.12 + sin(pang) * 0.09), bimba_prov, false), 25.0)
	_lod(_cyl(root, "EmblemGada", copper, 0.05, 0.3, Vector3(-0.36, y + 0.85, -0.12), bimba_prov, false), 25.0)
	_lod(_lathe(root, "EmblemPadma", cream, 0.08, 0.16,
		[Vector2(0.4, 0.0), Vector2(1.0, 0.6), Vector2(0.0, 1.0)], Vector3(0.36, y + 0.78, -0.12), bimba_prov), 25.0)
	# dvarapala figures flanking the east door (spec dvarapala_L/R, TS-P2V2-yoni)
	var dvara_prov: Array = ["TS-P2V2-yoni"]
	for dsgn in [-1.0, 1.0]:
		var dnm := "DvarapalaL" if dsgn < 0.0 else "DvarapalaR"
		var dx: float = gh / 2.0 + 0.35
		var dz: float = dsgn * 1.0
		_box(root, dnm + "_Oma", granite, Vector3(0.5, 0.15, 0.5), Vector3(dx, y + 0.075, dz), dvara_prov)
		_box(root, dnm + "_Body", granite, Vector3(0.3, 1.1, 0.3), Vector3(dx, y + 0.55 + 0.1, dz), dvara_prov)
		_ball(root, dnm + "_Head", granite, 0.13, 0.26, Vector3(dx, y + 1.23 + 0.1, dz), dvara_prov)
		_box(root, dnm + "_Diadem", copper, Vector3(0.3, 0.12, 0.3), Vector3(dx, y + 1.42 + 0.1, dz), dvara_prov)
		_box(root, dnm + "_Staff", timber, Vector3(0.06, 1.3, 0.06), Vector3(dx + 0.28, y + 0.65, dz), dvara_prov)
	# sanctum barrier: solid StaticBody across the door gap (K-TANTRI-ONLY —
	# Tantri/Melshanti cross; sevaka serves from namaskara-mandapa).
	# The trigger teaching lives in-scene (SanctumTrigger Area); builder owns collision only.
	var barrier := StaticBody3D.new()
	barrier.name = "SanctumBarrier"
	var bcol := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(0.3, dh, dw + 0.06)
	bcol.shape = bshape
	barrier.position = Vector3(gh / 2.0, y + dh / 2.0, 0)
	barrier.set_meta("provenance", ["OBSERVED-tantri-only", "TS-P1V04B-yajamana"])
	barrier.add_child(bcol)
	root.add_child(barrier)
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
	# kapota drip course + alinga bead below it (craft profiles over the
	# named 9-band prastara; band widths stay canonical).
	var kap_w := gh + 0.5 - 0.02 * 4
	_box(root, "Prastara_KapotaDrip", laterite, Vector3(kap_w + 0.12, ph1 * 0.6, kap_w + 0.12),
		Vector3(0, y - _m(1.5) + ph1 * 4.7, 0), prov_pr, false, 0.0, CRAFT_PROFILE)
	_box(root, "Prastara_AlingaBead", laterite, Vector3(kap_w + 0.06, ph1 * 0.5, kap_w + 0.06),
		Vector3(0, y - _m(1.5) + ph1 * 5.6, 0), prov_pr, false, 0.0, CRAFT_PROFILE)
	# --- hara aedicules (kuta/sala/panjara alternating) ---
	# Kuta gets a lathe dome + stupi knob, sala a mini eave cap, panjara a
	# gavaksha frame pair (craft massing over the V38B ornament program).
	var hh := _m(1.0)
	for i in range(8):
		var kind: String = ["kuta", "sala", "panjara", "sala"][i % 4]
		var a := (gh + 0.5) / 2.0 + 0.1
		var ang := TAU * float(i) / 8.0
		var apos := Vector3(cos(ang) * a, y + hh / 2.0, sin(ang) * a)
		_box(root, "Hara_%s_%d" % [kind, i], laterite,
			Vector3(0.5, hh, 0.5), apos, prov_pr)
		if kind == "kuta":
			_lathe(root, "Hara_KutaDome_%d" % i, laterite, 0.3, 0.3,
				[Vector2(1.0, 0.0), Vector2(0.7, 0.5), Vector2(0.0, 1.0)],
				apos + Vector3(0, hh / 2.0, 0), prov_pr)
			_lod(_ball(root, "Hara_KutaStupi_%d" % i, copper, 0.06, 0.12,
				apos + Vector3(0, hh / 2.0 + 0.36, 0), prov_pr), 25.0)
		elif kind == "sala":
			_eave_pyramid(root, "Hara_SalaCap_%d" % i, laterite, 0.7, 0.7, 0.25,
				apos + Vector3(0, hh / 2.0, 0), prov_pr, 0.08)
		else:
			var out := Vector3(cos(ang), 0, sin(ang))
			var lat := Vector3(-sin(ang), 0, cos(ang))
			_box(root, "Hara_PanjaraJambL_%d" % i, laterite, Vector3(0.08, 0.6, 0.08),
				apos + out * 0.28 + lat * -0.2 + Vector3(0, 0.05, 0), prov_pr, false, 0.0, CRAFT_PROFILE)
			_box(root, "Hara_PanjaraJambR_%d" % i, laterite, Vector3(0.08, 0.6, 0.08),
				apos + out * 0.28 + lat * 0.2 + Vector3(0, 0.05, 0), prov_pr, false, 0.0, CRAFT_PROFILE)
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
	# directional niche figures: slab relief + head knob (stylized, canon-safe),
	# each framed by kudya jambs + lintel (craft joinery on the V60B program).
	_box(root, "Murti_Brahma_E", laterite, Vector3(0.16, 0.9, 0.5), Vector3(hw2, murti_y, 0), murti_prov)
	_ball(root, "Murti_Brahma_E_Head", laterite, 0.1, 0.2, Vector3(hw2 + 0.08, murti_y + 0.3, 0), murti_prov)
	_box(root, "Murti_Dakshinamurti_S", laterite, Vector3(0.5, 0.9, 0.16), Vector3(0, murti_y, hw2), murti_prov)
	_ball(root, "Murti_Dakshinamurti_S_Head", laterite, 0.1, 0.2, Vector3(0, murti_y + 0.3, hw2 + 0.08), murti_prov)
	_box(root, "Murti_Narasimha_W", laterite, Vector3(0.16, 0.9, 0.5), Vector3(-hw2, murti_y, 0), murti_prov)
	_ball(root, "Murti_Narasimha_W_Head", laterite, 0.1, 0.2, Vector3(-hw2 - 0.08, murti_y + 0.3, 0), murti_prov)
	_box(root, "Murti_Krishna_N", laterite, Vector3(0.5, 0.9, 0.16), Vector3(0, murti_y, -hw2), murti_prov)
	_ball(root, "Murti_Krishna_N_Head", laterite, 0.1, 0.2, Vector3(0, murti_y + 0.3, -hw2 - 0.08), murti_prov)
	for mface in range(4):
		var mang := float(mface) * PI / 2.0
		var mout := Vector3(cos(mang), 0, sin(mang))
		var mlat := Vector3(-sin(mang), 0, cos(mang))
		var mcen := mout * hw2 + Vector3(0, murti_y, 0)
		_box(root, "MurtiNiche_JambL_%d" % mface, laterite, Vector3(0.12, 1.0, 0.12),
			mcen + mlat * -0.38 + mout * 0.02, murti_prov, true, 0.0, CRAFT_PROFILE)
		_box(root, "MurtiNiche_JambR_%d" % mface, laterite, Vector3(0.12, 1.0, 0.12),
			mcen + mlat * 0.38 + mout * 0.02, murti_prov, true, 0.0, CRAFT_PROFILE)
		var lspan := Vector3(0.9, 0.12, 0.14) if mface % 2 == 1 else Vector3(0.14, 0.12, 0.9)
		_box(root, "MurtiNiche_Lintel_%d" % mface, laterite, lspan,
			mcen + Vector3(0, 0.56, 0), murti_prov, true, 0.0, CRAFT_PROFILE)
		var bspan := Vector3(0.7, 1.1, 0.06) if mface % 2 == 1 else Vector3(0.06, 1.1, 0.7)
		_box(root, "MurtiNiche_Backplate_%d" % mface, laterite, bspan,
			mcen - mout * 0.06, murti_prov, true, 0.0, CRAFT_PROFILE)
	y += h2
	_box(root, "PrastaraT2", laterite, Vector3(gh * 0.72 + 0.4, _m(1.0), gh * 0.72 + 0.4),
		Vector3(0, y + _m(1.0) / 2.0, 0), prov_pr)
	y += _m(1.0)
	# --- timber pyramidal roof with tiled eave + copper lotus-bud kalasha ---
	_eave_pyramid(root, "ShikharaRoof", timber, gh + 1.6, gh + 1.6, _m(3.0), Vector3(0, y, 0), prov_pr)
	var rafter_prov: Array = prov_pr + ["TS-P2V48B-rafters"] if not prov_pr.has("TS-P2V48B-rafters") else prov_pr
	_roof_assembly(root, "Shikhara", timber, Vector3(0, y, 0), (gh + 1.6) / 2.0, _m(3.0), 4, 4, rafter_prov)
	_tile_field(root, "Shikhara", timber, Vector3(0, y, 0), (gh + 1.6) / 2.0, _m(3.0), 8, rafter_prov)
	y += _m(3.0)
	_lathe(root, "StupiKalasha", copper, 0.28, _m(0.75),
		[Vector2(0.5, 0.02), Vector2(0.85, 0.12), Vector2(0.6, 0.3), Vector2(0.9, 0.5),
		Vector2(0.55, 0.68), Vector2(0.25, 0.82), Vector2(0.12, 0.92), Vector2(0.0, 1.0)],
		Vector3(0, y, 0), prov_pr)

	# --- east axis: sopana steps, mukhamandapa, namaskara, balikkal, dwaja ---
	var ex := gh / 2.0
	# sopana: five granite tread plates riding the walk ramp (TS-P2V33B-sopana).
	# Plates are non-colliding visuals flush on the ramp (+0.045); the hidden
	# ramp is the sole collider (26 deg, within floor_max_angle: the fighter
	# has no jump, so solid risers would wall off the climb).
	var sopana_prov: Array = prov_pr + ["TS-P2V33B-sopana"] if not prov_pr.has("TS-P2V33B-sopana") else prov_pr
	var tread_mesh := _shared_box("sopana_tread", Vector3(0.44, 0.06, 1.4))
	for si in range(5):
		var tx := ex + 2.14 - float(si) * 0.4
		var ty := -0.13 + (5.12 - tx) * 0.44366 + 0.015
		var tread := MeshInstance3D.new()
		tread.name = "SopanaTread_%d" % (si + 1)
		tread.mesh = tread_mesh
		tread.material_override = granite
		tread.position = Vector3(tx, ty, 0)
		tread.rotation.z = -0.417
		tread.set_meta("provenance", sopana_prov)
		root.add_child(tread)
	var ramp := CSGBox3D.new()
	ramp.name = "SopanaRamp"
	ramp.material = granite
	ramp.size = Vector3(3.1, 0.15, 1.4)
	ramp.position = Vector3(3.7, 0.5, 0)
	ramp.rotation.z = -0.417
	ramp.use_collision = true
	ramp.visible = false
	ramp.set_meta("provenance", sopana_prov)
	root.add_child(ramp)
	# mukhamandapa: 4 tall pillars + slab + pyramid (clear height over the
	# adhishthana-top approach >= 2.0 for the climbing devotee; craft massing)
	var mx := ex + 3.0
	for px in [mx - 1.0, mx + 1.0]:
		for pz in [-1.0, 1.0]:
			_pillar(root, "MukhaPillar", timber, Vector3(px, 0, pz), 0.25, 3.0, prov_pr, true)
	_box(root, "MukhaSlab", timber, Vector3(3.0, 0.25, 3.0), Vector3(mx, 3.18, 0), door_prov)
	_eave_pyramid(root, "MukhaRoof", timber, 3.6, 3.6, 1.0, Vector3(mx, 3.3, 0), prov_pr)
	_roof_assembly(root, "Mukha", timber, Vector3(mx, 3.3, 0), 1.8, 1.0, 3, 2, rafter_prov)
	# namaskara mandapa (detached square)
	var nx := ex + 6.5
	for px in [nx - 1.1, nx + 1.1]:
		for pz in [-1.1, 1.1]:
			_pillar(root, "NamaskaraPillar", timber, Vector3(px, 0, pz), 0.28, 2.4, prov_pr, true)
	_box(root, "NamaskaraSlab", granite, Vector3(3.0, 0.4, 3.0), Vector3(nx, 0.2, 0), prov_pr)
	_box(root, "NamaskaraRoofBase", timber, Vector3(3.4, 0.25, 3.4), Vector3(nx, 2.5, 0), prov_pr)
	_eave_pyramid(root, "NamaskaraRoof", timber, 4.0, 4.0, 1.1, Vector3(nx, 2.62, 0), prov_pr)
	_roof_assembly(root, "Namaskara", timber, Vector3(nx, 2.62, 0), 2.0, 1.1, 3, 2, rafter_prov)
	_flush_timber(root, timber, prov_pr)
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
	# rishabha vahana at the dwaja base (SESHA-P9V02: bull for the deity;
	# recumbent massing: body + head + hump + horns, canon-safe)
	var dhvaja_prov: Array = prov_pr + ["SESHA-P9V02-dhvajavahana", "SESHA-P9V03-dhvasthapana"]
	_box(root, "RishabhaBase", granite, Vector3(1.0, 0.3, 0.6), Vector3(nx + 5.0, 0.15, 1.4), dhvaja_prov)
	_box(root, "RishabhaBody", cream, Vector3(0.8, 0.5, 0.4), Vector3(nx + 5.0, 0.55, 1.4), dhvaja_prov)
	_box(root, "RishabhaHead", cream, Vector3(0.3, 0.35, 0.3), Vector3(nx + 5.4, 0.65, 1.4), dhvaja_prov)
	_box(root, "RishabhaHump", cream, Vector3(0.25, 0.2, 0.3), Vector3(nx + 4.85, 0.85, 1.4), dhvaja_prov)
	_lod(_box(root, "RishabhaHornL", copper, Vector3(0.05, 0.2, 0.05), Vector3(nx + 5.4, 0.9, 1.3), dhvaja_prov, false), 25.0)
	_lod(_box(root, "RishabhaHornR", copper, Vector3(0.05, 0.2, 0.05), Vector3(nx + 5.4, 0.9, 1.5), dhvaja_prov, false), 25.0)
	_box(root, "RishabhaDewlap", cream, Vector3(0.2, 0.25, 0.15), Vector3(nx + 5.45, 0.45, 1.4), dhvaja_prov, false)
	_box(root, "RishabhaTail", cream, Vector3(0.05, 0.4, 0.05), Vector3(nx + 4.55, 0.5, 1.4), dhvaja_prov, false)
	_box(root, "RishabhaHoof", granite, Vector3(0.85, 0.08, 0.45), Vector3(nx + 5.0, 0.34, 1.4), dhvaja_prov)

	# --- flagship v2 micro-objects (all provenance-tagged, dressing LOD) ---
	# foundation deposit set at the adhishthana north-east base (buried program shown exposed)
	var deposit_prov: Array = ["TS-P1V74B-nidhipot", "TS-P1V77B-kurmashila", "TS-P1V79B-silverlotus", "TS-P1V81B-bricks"]
	_lathe(root, "NidhiKumbha", copper, 0.22, 0.35,
		[Vector2(0.6, 0.02), Vector2(0.9, 0.2), Vector2(0.5, 0.5), Vector2(0.7, 0.7),
		Vector2(0.2, 0.85), Vector2(0.0, 1.0)], Vector3(ex + 0.4, 0.0, -1.6), deposit_prov)
	_box(root, "KurmaShila", granite, Vector3(0.5, 0.12, 0.5), Vector3(ex + 0.4, 0.41, -1.6), deposit_prov, false)
	_box(root, "SilverLotus", cream, Vector3(0.3, 0.08, 0.3), Vector3(ex + 0.4, 0.5, -2.1), deposit_prov, false)
	_box(root, "DepositBricks", laterite, Vector3(0.6, 0.25, 0.6), Vector3(ex + 0.4, 0.12, -2.6), deposit_prov, false)
	# palika-16 sowing grid south of mukhamandapa (TS-P3V02B/V03B), one draw
	var palika_prov: Array = ["TS-P3V02B-palika16", "TS-P3V03B-bija"]
	var palika_xf: Array = []
	for pi in range(16):
		palika_xf.append(Transform3D(Basis(),
			Vector3(4.0 + float(pi % 4) * 0.5, 0.11, 3.0 + float(pi / 4) * 0.5)))
	_mmi(root, "PalikaSet", _shared_box("palika", Vector3(0.28, 0.22, 0.28)),
		palika_xf, laterite, palika_prov, 30.0)
	# kautuka stand + shayya platform north of mukhamandapa (TS-P3V38B/V114B)
	var kautuka_prov: Array = ["TS-P3V38B-kautuka", "TS-P4V114B-shayana"]
	_box(root, "ShayyaPlatform", cream, Vector3(2.0, 0.5, 1.0), Vector3(mx, 0.25, -3.5), kautuka_prov)
	_box(root, "KautukaStand", timber, Vector3(0.3, 0.6, 0.3), Vector3(mx, 0.3, -2.5), kautuka_prov)
	# brahma-kalasha vessel row by the thidappalli (SESHA-P4V02/V04 + V41B fills), one draw
	var kalasha_prov: Array = ["SESHA-P4V02-brahmakalasha", "SESHA-P4V04-parikalasha", "SESHA-P7V41B-kalashafill"]
	var kalasha_prof := [Vector2(0.6, 0.02), Vector2(0.9, 0.2), Vector2(0.5, 0.5), Vector2(0.7, 0.7),
		Vector2(0.2, 0.85), Vector2(0.0, 1.0)]
	var kalasha_xf: Array = []
	for ki in range(5):
		kalasha_xf.append(Transform3D(Basis(), Vector3(4.5 + float(ki) * 0.5, 0.0, -4.5)))
	_mmi(root, "BrahmaKalashaSet", _shared_lathe("kalasha", kalasha_prof, 0.15, 0.4),
		kalasha_xf, copper, kalasha_prov, 30.0)
	# kshetrapala guardian stone NE (SESHA-P8V04 ten-direction retinue)
	_box(root, "Kshetrapala", granite, Vector3(0.6, 1.0, 0.6), Vector3(9.0, 0.5, -9.0),
		["SESHA-P5V02-savanatraya", "SESHA-P5V07-balikrama", "SESHA-P8V04-kshetrapala"], true, 30.0)
	# eight lokapala parita flags inside the lamp ring (SESHA-P9V03), one draw
	var parita_xf: Array = []
	for fi in range(8):
		var fang := TAU * float(fi) / 8.0
		parita_xf.append(Transform3D(Basis(Vector3.UP, -fang),
			Vector3(cos(fang) * 17.5, 1.6, sin(fang) * 17.5)))
	_mmi(root, "ParitaFlagSet", _shared_box("parita", Vector3(0.3, 0.6, 0.05)),
		parita_xf, cream, dhvaja_prov, 40.0)
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
	# east gopura: jambs with 3m axis gap (walkable) + upper storey + roof
	var gx := (uh + 18.0) / 2.0
	_box(root, "GopuraJambL", cream, Vector3(2.0, 3.0, 1.0), Vector3(gx, 1.5, -2.0), prov_pr)
	_box(root, "GopuraJambR", cream, Vector3(2.0, 3.0, 1.0), Vector3(gx, 1.5, 2.0), prov_pr)
	_box(root, "GopuraTop", cream, Vector3(2.4, 2.0, 5.6), Vector3(gx, 4.0, 0), prov_pr)
	_eave_pyramid(root, "GopuraRoof", timber, 3.0, 6.2, 1.4, Vector3(gx, 5.0, 0), prov_pr, 0.4)
	_gable_assembly(root, "Gopura", timber, Vector3(gx, 5.0, 0), 1.5, 3.1, 1.4, prov_pr)
	# gopura crown: tier band + corner stupi balls + open passage leaves (craft).
	_box(root, "GopuraTierBand", cream, Vector3(2.5, 0.25, 5.7), Vector3(gx, 5.1, 0), prov_pr, false, 0.0, CRAFT_PROFILE)
	_eave_pyramid(root, "GopuraSalaCapL", cream, 0.9, 0.9, 0.3, Vector3(gx, 5.35, -1.8), prov_pr, 0.1)
	_eave_pyramid(root, "GopuraSalaCapR", cream, 0.9, 0.9, 0.3, Vector3(gx, 5.35, 1.8), prov_pr, 0.1)
	_ball(root, "GopuraRidgeKnob", copper, 0.1, 0.2, Vector3(gx, 6.5, 0), prov_pr)
	for gfi in range(4):
		_lod(_ball(root, "GopuraStupi_%d" % gfi, copper, 0.09, 0.18,
			Vector3(gx + (0.9 if gfi % 2 == 0 else -0.9), 5.3, 2.5 if gfi < 2 else -2.5), prov_pr), 25.0)
	for glsgn in [-1.0, 1.0]:
		_box(root, "GopuraLeaf_%d" % glsgn, timber, Vector3(0.8, 2.2, 0.06),
			Vector3(gx - 0.5, 1.1, glsgn * 1.44), prov_pr, true, 0.0, CRAFT_TIMBER)
	# koothambalam NW: plinth + pillars + roof (set back so the pradakshina
	# ring r=uh+2.5 stays walkable; traverse-proven)
	_build_hall(root, "Koothambalam", Vector3(-(uh / 2.0 + 9.0), 0, -(uh / 2.0 + 7.0)), timber, cream, prov_pr)
	# ootupura + well NE + kulam + kavu
	_build_hall(root, "Ootupura", Vector3(-(uh / 2.0 + 4.0), 0, uh / 2.0 + 6.0), timber, cream, prov_pr)
	_box(root, "WellNE", granite, Vector3(1.6, 1.0, 1.6),
		Vector3((uh + 6.0) / 2.0 - 1.0, 0.5, (uh + 6.0) / 2.0 - 1.0), prov_pr)
	_box(root, "KulamWater", water_mat, Vector3(6.0, 0.1, 6.0),
		Vector3(-(uh / 2.0 + 9.0), 0.05, uh / 2.0 + 9.0), prov_pr, false)
	# stepped tank curb ring (TS-P1V39B-supadma water architecture; 0.2 rises)
	var kcx := -(uh / 2.0 + 9.0)
	var kcz := uh / 2.0 + 9.0
	_box(root, "KulamCurbN", moss, Vector3(6.6, 0.2, 0.3), Vector3(kcx, 0.1, kcz - 3.15), prov_pr)
	_box(root, "KulamCurbS", moss, Vector3(6.6, 0.2, 0.3), Vector3(kcx, 0.1, kcz + 3.15), prov_pr)
	_box(root, "KulamCurbE", moss, Vector3(0.3, 0.2, 6.6), Vector3(kcx + 3.15, 0.1, kcz), prov_pr)
	_box(root, "KulamCurbW", moss, Vector3(0.3, 0.2, 6.6), Vector3(kcx - 3.15, 0.1, kcz), prov_pr)
	# kavu trees (dressing LOD) + naaga stones at the grove edge, three draws
	var trunk_xf: Array = []
	for i in range(6):
		var tx := -(uh / 2.0 + 11.0) + float(i % 3) * 2.0
		var tz := -(uh / 2.0 + 11.0) + float(i / 3) * 2.0
		trunk_xf.append(Transform3D(Basis(), Vector3(tx, 2.0, tz)))
	_mmi(root, "KavuTrunkSet", _shared_box("kavutrunk", Vector3(0.35, 4.0, 0.35)),
		trunk_xf, timber, prov_pr, 40.0)
	var crown_xfs: Array = []
	var crown_top_xfs: Array = []
	for i in range(6):
		var tx2 := -(uh / 2.0 + 11.0) + float(i % 3) * 2.0
		var tz2 := -(uh / 2.0 + 11.0) + float(i / 3) * 2.0
		crown_xfs.append(Transform3D(Basis.from_scale(Vector3(2.6, 1.1, 2.6)),
			Vector3(tx2, 4.1, tz2)))
		crown_top_xfs.append(Transform3D(Basis.from_scale(Vector3(1.7, 0.8, 1.7)),
			Vector3(tx2 + 0.3, 4.8, tz2 - 0.3)))
	_mmi(root, "KavuCrownSet", _leaf_card(), crown_xfs, _leaf_card_mat(), prov_pr, 40.0)
	_mmi(root, "KavuCrownTopSet", _leaf_card(), crown_top_xfs, _leaf_card_mat(), prov_pr, 40.0)
	var kavu_prov: Array = ["TS-P3V1-material", "TS-P1V39B-supadma"]
	for ni in range(3):
		_box(root, "NaagaStone_%d" % ni, moss, Vector3(0.4, 0.5, 0.2),
			Vector3(-14.5 - float(ni) * 0.5, 0.25, -13.8 - float(ni) * 0.4), kavu_prov, false, 40.0)
	# grove floor dressing: trunk roots, fallen-leaf litter, worksite tile debris.
	# Craft placement on prov ground; three instanced draws, LOD40.
	var root_xf: Array = []
	for ri in range(6):
		var rtx := -(uh / 2.0 + 11.0) + float(ri % 2) * 4.0
		var rtz := -(uh / 2.0 + 11.0) - 0.5
		var rang := float(ri) * 1.047
		root_xf.append(Transform3D(Basis(Vector3.UP, rang).scaled(Vector3(0.09, 0.07, 1.3)),
			Vector3(rtx + cos(rang) * 0.8, 0.035, rtz + sin(rang) * 0.8)))
	_mmi(root, "KavuRootSet", _shared_box("unit_beam", Vector3.ONE),
		root_xf, timber, kavu_prov, 40.0)
	var litter_xf: Array = []
	for li in range(20):
		var lang := float(li) * 0.628
		var lrad := 2.0 + float(li % 5) * 0.55
		litter_xf.append(Transform3D(Basis(Vector3.UP, lang * 2.0).scaled(Vector3(0.12, 0.02, 0.08)),
			Vector3(-13.3 + cos(lang) * lrad, 0.015, -14.3 + sin(lang) * lrad)))
	_mmi(root, "LeafLitterSet", _shared_box("unit_beam", Vector3.ONE),
		litter_xf, leaf, kavu_prov, 40.0)
	var debris_xf: Array = []
	for di in range(8):
		debris_xf.append(Transform3D(Basis(Vector3.UP, float(di) * 0.785).scaled(Vector3(0.15, 0.06, 0.2)),
			Vector3((uh + 18.0) / 2.0 + 2.2 + float(di % 4) * 0.45, 0.03, 3.4 + float(di / 4) * 0.5)))
	_mmi(root, "TileDebrisSet", _shared_box("unit_beam", Vector3.ONE),
		debris_xf, laterite, prov_pr, 40.0,
		{"kind": "placement", "basis": "craft interpolation", "status": "OPEN-adjacent", "replaces": "bare swept court"})

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
	var names := ["Paduka", "Jagati", "Kumuda", "Gala", "Pati", "Vedi"]
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
	# conical timber roof + lathe lotus-bud kalasha
	_cone(root, "ShikharaRoof", timber, gh / 2.0 + 0.8, _m(3.5), Vector3(0, y, 0), prov_pr)
	var crafter_prov: Array = prov_pr + ["TS-P2V48B-rafters"] if not prov_pr.has("TS-P2V48B-rafters") else prov_pr
	var cmembers: Array = []
	for ri in range(12):
		var rang := TAU * float(ri) / 12.0
		_aimed(cmembers,
			Vector3(cos(rang) * (gh / 2.0 + 0.8), y, sin(rang) * (gh / 2.0 + 0.8)),
			Vector3(0, y + _m(3.5), 0), 0.09, 0.12)
	_mmi(root, "ConeRafterSet", _shared_box("unit_beam", Vector3.ONE),
		cmembers, timber, crafter_prov, 0.0, CRAFT_ROOF)
	# cone tile batten rings + eave fascia ring (craft courses on the cone)
	var cone_dress: Array = []
	for ci in range(2):
		var cfrac := float(ci + 1) / 3.0
		var crr := (gh / 2.0 + 0.8) * (1.0 - cfrac) + 0.06
		var cyy := y + _m(3.5) * cfrac
		for cj in range(8):
			var cang := TAU * float(cj) / 8.0 + float(ci) * PI / 8.0
			var cchord := 2.0 * crr * sin(PI / 8.0) + 0.05
			cone_dress.append(Transform3D(Basis(Vector3.UP, -cang).scaled(Vector3(cchord, 0.07, 0.14)),
				Vector3(cos(cang) * crr, cyy, sin(cang) * crr)))
	var frr := gh / 2.0 + 0.86
	for fi in range(8):
		var fang := TAU * float(fi) / 8.0
		var fchord := 2.0 * frr * sin(PI / 8.0) + 0.05
		cone_dress.append(Transform3D(Basis(Vector3.UP, -fang).scaled(Vector3(fchord, 0.18, 0.12)),
			Vector3(cos(fang) * frr, y + 0.02, sin(fang) * frr)))
	_mmi(root, "ConeDressSet", _shared_box("unit_beam", Vector3.ONE),
		cone_dress, timber, crafter_prov, 0.0, CRAFT_ROOF)
	y += _m(3.5)
	_lathe(root, "StupiKalasha", copper, 0.28, _m(0.75),
		[Vector2(0.5, 0.02), Vector2(0.85, 0.12), Vector2(0.6, 0.3), Vector2(0.9, 0.5),
		Vector2(0.55, 0.68), Vector2(0.25, 0.82), Vector2(0.12, 0.92), Vector2(0.0, 1.0)],
		Vector3(0, y, 0), prov_pr)
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
	# west axis: sopana treads, mukhamandapa, namaskara, balikkal, dwaja, deepa
	var ex := sgn * gh / 2.0
	var tread_mesh_c := _shared_box("sopana_tread", Vector3(0.44, 0.06, 1.4))
	for si in range(3):
		var tx := sgn * (3.9 - float(si) * 0.6)
		var tdist := (tx - sgn * 4.2) * (-sgn)
		var ty := -0.1 + tdist * 0.4138 + 0.015
		var tread := MeshInstance3D.new()
		tread.name = "SopanaTread_%d" % (si + 1)
		tread.mesh = tread_mesh_c
		tread.material_override = granite
		tread.position = Vector3(tx, ty, 0)
		tread.rotation.z = -sgn * 0.393
		tread.set_meta("provenance", prov_pr)
		root.add_child(tread)
	# walk ramp to the adhishthana top (same contract as the square slice:
	# steps are visual provenance, the hidden ramp carries motion).
	var cramp := CSGBox3D.new()
	cramp.name = "SopanaRamp"
	cramp.material = granite
	cramp.size = Vector3(2.9, 0.15, 1.4)
	cramp.position = Vector3(sgn * 2.75, 0.5, 0)
	cramp.rotation.z = -sgn * 0.393
	cramp.use_collision = true
	cramp.visible = false
	cramp.set_meta("provenance", prov_pr)
	root.add_child(cramp)
	var mx := ex + sgn * 3.0
	for px in [mx - 1.0, mx + 1.0]:
		for pz in [-1.0, 1.0]:
			_pillar(root, "MukhaPillar", timber, Vector3(px, 0, pz), 0.25, 3.0, prov_pr)
	_box(root, "MukhaSlab", timber, Vector3(3.0, 0.25, 3.0), Vector3(mx, 3.18, 0), prov_pr)
	_eave_pyramid(root, "MukhaRoof", timber, 3.6, 3.6, 1.0, Vector3(mx, 3.3, 0), prov_pr)
	var nx := ex + sgn * 6.5
	for px in [nx - 1.1, nx + 1.1]:
		for pz in [-1.1, 1.1]:
			_pillar(root, "NamaskaraPillar", timber, Vector3(px, 0, pz), 0.28, 2.4, prov_pr)
	_box(root, "NamaskaraSlab", granite, Vector3(3.0, 0.4, 3.0), Vector3(nx, 0.2, 0), prov_pr)
	_eave_pyramid(root, "NamaskaraRoof", timber, 4.0, 4.0, 1.1, Vector3(nx, 2.62, 0), prov_pr)
	_box(root, "ValiaBalikkal", granite, Vector3(0.8, 1.2, 0.8), Vector3(nx + sgn * 3.0, 0.6, 0), prov_pr)
	var dwaja_proxy := _box(root, "DwajaPole", timber, Vector3(0.3, 6.0, 0.3), Vector3(nx + sgn * 5.0, 3.0, 0), prov_pr)
	dwaja_proxy.visible = false  # hidden collision proxy; render post is octagonal below
	_cyl(root, "DwajaPoleOct", timber, 0.18, 6.0, Vector3(nx + sgn * 5.0, 3.0, 0), prov_pr, false).sides = 8
	_box(root, "DwajaTop", copper, Vector3(0.5, 0.5, 0.5), Vector3(nx + sgn * 5.0, 6.2, 0), prov_pr)
	# rings with west gate + west gopura + support buildings
	var gate := -1.0 if west else 1.0
	_build_ring(root, "Nalambalam", uh + 6.0, 2.2, cream, prov_pr, gate)
	_build_ring(root, "Vilakkumadam", uh + 10.0, 1.2, timber, prov_pr, gate)
	_build_ring(root, "MaryadaWall", uh + 18.0, 1.5, laterite, prov_pr, gate)
	var gx := sgn * (uh + 18.0) / 2.0
	_box(root, "GopuraJambL", cream, Vector3(2.0, 3.0, 1.0), Vector3(gx, 1.5, -2.0), prov_pr)
	_box(root, "GopuraJambR", cream, Vector3(2.0, 3.0, 1.0), Vector3(gx, 1.5, 2.0), prov_pr)
	_box(root, "GopuraTop", cream, Vector3(2.4, 2.0, 5.6), Vector3(gx, 4.0, 0), prov_pr)
	_eave_pyramid(root, "GopuraRoof", timber, 3.0, 6.2, 1.4, Vector3(gx, 5.0, 0), prov_pr, 0.4)
	_gable_assembly(root, "Gopura", timber, Vector3(gx, 5.0, 0), 1.5, 3.1, 1.4, prov_pr)
	_box(root, "GopuraTierBand", cream, Vector3(2.5, 0.25, 5.7), Vector3(gx, 5.1, 0), prov_pr, false, 0.0, CRAFT_PROFILE)
	_eave_pyramid(root, "GopuraSalaCapL", cream, 0.9, 0.9, 0.3, Vector3(gx, 5.35, -1.8), prov_pr, 0.1)
	_eave_pyramid(root, "GopuraSalaCapR", cream, 0.9, 0.9, 0.3, Vector3(gx, 5.35, 1.8), prov_pr, 0.1)
	_ball(root, "GopuraRidgeKnob", copper, 0.1, 0.2, Vector3(gx, 6.5, 0), prov_pr)
	for gfi in range(4):
		_lod(_ball(root, "GopuraStupi_%d" % gfi, copper, 0.09, 0.18,
			Vector3(gx + (0.9 if gfi % 2 == 0 else -0.9), 5.3, 2.5 if gfi < 2 else -2.5), prov_pr), 25.0)
	for glsgn in [-1.0, 1.0]:
		_box(root, "GopuraLeaf_%d" % glsgn, timber, Vector3(0.8, 2.2, 0.06),
			Vector3(gx - sgn * 0.5, 1.1, glsgn * 1.44), prov_pr, true, 0.0, CRAFT_TIMBER)
	_box(root, "Thidappalli", cream, Vector3(3.0, 2.0, 3.0),
		Vector3((uh + 6.0) / 2.0 - 1.0, 1.0, -((uh + 6.0) / 2.0 - 1.0)), prov_pr)
	_box(root, "WellNE", granite, Vector3(1.6, 1.0, 1.6),
		Vector3((uh + 6.0) / 2.0 - 1.0, 0.5, (uh + 6.0) / 2.0 - 1.0), prov_pr)

func _pillar(parent: Node, nm: String, mat: Material, pos_base: Vector3,
		w: float, h: float, prov: Array, dress := false) -> void:
	# Stambha with oma pedestal (TS-P2V25B: oma twice pillar width, half width high).
	# dress=true adds bhadra corbel capital + diagonal struts (Kerala field
	# convention joinery; craft-tagged, member rule covers the stambha).
	_box(parent, nm + "_Oma", mat, Vector3(w * 2.0, w / 2.0, w * 2.0),
		pos_base + Vector3(0, w / 4.0, 0), prov)
	_box(parent, nm, mat, Vector3(w, h, w),
		pos_base + Vector3(0, w / 2.0 + h / 2.0, 0), prov)
	if dress:
		# Batched into one instanced joinery set at end of build (see _flush_timber).
		# (Batch entries are bare Transform3Ds; all dressed pillars hang off root.)
		var top_y := pos_base.y + w / 2.0 + h
		var cc := pos_base + Vector3(0, 0, 0)
		_timber_batch.append(Transform3D(Basis.from_scale(Vector3(w + 0.14, 0.09, w + 0.14)),
			Vector3(cc.x, top_y + 0.045, cc.z)))
		_timber_batch.append(Transform3D(Basis.from_scale(Vector3(w + 0.26, 0.09, w + 0.26)),
			Vector3(cc.x, top_y + 0.135, cc.z)))
		_aimed_batch(Vector3(cc.x - w / 2.0 - 0.3, top_y - 0.55, cc.z),
			Vector3(cc.x - w / 2.0 + 0.02, top_y + 0.05, cc.z), 0.08, 0.1)
		_aimed_batch(Vector3(cc.x + w / 2.0 + 0.3, top_y - 0.55, cc.z),
			Vector3(cc.x + w / 2.0 - 0.02, top_y + 0.05, cc.z), 0.08, 0.1)

const CRAFT_TIMBER := {"kind": "massing", "basis": "Kerala field convention",
	"status": "OPEN-adjacent", "replaces": "bare post stambha (TS-P2V25B member kept)"}

func _build_hall(parent: Node, nm: String, at: Vector3, wood: Material, base_mat: Material, prov: Array) -> void:
	_box(parent, nm + "_Plinth", base_mat, Vector3(5.0, 0.4, 4.0), at + Vector3(0, 0.2, 0), prov)
	for ox in [-2.0, 2.0]:
		for oz in [-1.5, 1.5]:
			_pillar(parent, nm + "_Pillar", wood, at + Vector3(ox, 0.4, oz), 0.25, 2.3, prov)
	_box(parent, nm + "_Roof", wood, Vector3(5.6, 0.25, 4.6), at + Vector3(0, 2.8, 0), prov)
	_eave_pyramid(parent, nm + "_Top", wood, 6.0, 5.0, 1.0, at + Vector3(0, 2.92, 0), prov)
	var hapex := at + Vector3(0, 3.92, 0)
	var hprov: Array = prov + ["TS-P2V48B-rafters"]
	var hmembers: Array = []
	for hx in [-1.0, 1.0]:
		for hz in [-1.0, 1.0]:
			_aimed(hmembers, at + Vector3(hx * 2.8, 2.92, hz * 2.3), hapex, 0.12, 0.14)
	for hi in range(2):
		var hxi := lerpf(-2.2, 2.2, float(hi + 1) / 3.0)
		for hsgn in [-1.0, 1.0]:
			_aimed(hmembers, at + Vector3(hxi, 2.92, hsgn * 2.5),
				at + Vector3(hxi * 0.2, 3.92, 0), 0.09, 0.12)
	_mmi(parent, nm + "_Members", _shared_box("unit_beam", Vector3.ONE),
		hmembers, wood, hprov, 0.0, CRAFT_ROOF)

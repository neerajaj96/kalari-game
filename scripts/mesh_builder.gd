extends RefCounted
# Procedural detail meshes: temple roofs with real slopes, stepped shikhara,
# lathed kalasham dome, gently noisy ground. SurfaceTool + generate_normals,
# planar UVs for a future texture day. Pure code, no imports.
class_name MeshBuilder

static func pyramid_roof(w: float, d: float, h: float, lip: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w / 2.0 + lip
	var hd := d / 2.0 + lip
	var y0 := 0.0
	var apex := Vector3(0, h, 0)
	var corners := [Vector3(-hw, y0, -hd), Vector3(hw, y0, -hd), Vector3(hw, y0, hd), Vector3(-hw, y0, hd)]
	for i in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		_tri(st, a, apex, b)
	# flat skirt under the eaves so no see-through gap
	for i in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		_tri(st, Vector3(a.x, y0 - 0.12, a.z), Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z))
		_tri(st, Vector3(a.x, y0 - 0.12, a.z), Vector3(b.x, y0, b.z), Vector3(b.x, y0 - 0.12, b.z))
	st.generate_normals()
	return st.commit()

static func stepped_shikhara(base: float, levels: int, step_h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := 0.0
	var half: float = base / 2.0
	for lv in range(levels):
		var nh := half * 0.72
		_box(st, Vector3(0, y + step_h / 2.0, 0), half * 2.0, step_h, half * 2.0)
		y += step_h
		half = nh
	# cap knob
	_box(st, Vector3(0, y + 0.1, 0), 0.24, 0.2, 0.24)
	st.generate_normals()
	return st.commit()

static func lathed_kalasham(rings: int = 8, radius: float = 0.22, height: float = 0.44) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector2] = []
	pts.append(Vector2(0.0, 0.0)) # closed base center
	for i in range(1, rings + 1):
		var t := float(i) / rings
		# double-bulb dome profile: bulb, waist, bulb, pinch, point
		var r := radius * (0.35 + 0.5 * sin(t * PI * 0.85) + 0.15 * sin(t * PI * 2.2))
		if t > 0.85:
			r = radius * 0.18 * (1.0 - (t - 0.85) / 0.15)
		r = maxf(r, 0.0)
		pts.append(Vector2(r, t * height))
	var segs := 12
	# pts holds base-center + rings profile points: rings bands total.
	for i in range(rings):
		for s in range(segs):
			var a0 := 2.0 * PI * float(s) / segs
			var a1 := 2.0 * PI * float(s + 1) / segs
			var p00 := Vector3(cos(a0) * pts[i].x, pts[i].y, sin(a0) * pts[i].x)
			var p01 := Vector3(cos(a1) * pts[i].x, pts[i].y, sin(a1) * pts[i].x)
			var p10 := Vector3(cos(a0) * pts[i + 1].x, pts[i + 1].y, sin(a0) * pts[i + 1].x)
			var p11 := Vector3(cos(a1) * pts[i + 1].x, pts[i + 1].y, sin(a1) * pts[i + 1].x)
			var u0 := float(s) / segs
			var u1 := float(s + 1) / segs
			_tri_uv(st, p00, p11, p01, Vector2(u0, i), Vector2(u1, i + 1), Vector2(u1, i))
			_tri_uv(st, p00, p10, p11, Vector2(u0, i), Vector2(u0, i + 1), Vector2(u1, i + 1))
	st.generate_normals()
	return st.commit()

static func noisy_ground(w: float, d: float, amp: float, flat_r: float = 3.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 24
	var nz := 24
	var grid: Array = []
	for iz in range(nz + 1):
		var row: Array = []
		for ix in range(nx + 1):
			var x := (float(ix) / nx - 0.5) * w
			var z := (float(iz) / nz - 0.5) * d
			var r := Vector2(x, z).length()
			var h := 0.0
			if r > flat_r:
				var k: float = minf(1.0, (r - flat_r) / 6.0)
				h = (sin(x * 0.8) * cos(z * 0.7) * 0.5 + sin(x * 0.23 + 1.7) * cos(z * 0.31) * 0.5) * amp * k
			row.append(Vector3(x, h, z))
		grid.append(row)
	for iz in range(nz):
		for ix in range(nx):
			var a: Vector3 = grid[iz][ix]
			var b: Vector3 = grid[iz][ix + 1]
			var c: Vector3 = grid[iz + 1][ix + 1]
			var e: Vector3 = grid[iz + 1][ix]
			var u0 := float(ix) / nx
			var u1 := float(ix + 1) / nx
			var v0 := float(iz) / nz
			var v1 := float(iz + 1) / nz
			_tri_uv(st, a, c, b, Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0))
			_tri_uv(st, a, e, c, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1))
	st.generate_normals()
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_uv(Vector2(a.x + a.z, a.y))
	st.add_vertex(a)
	st.set_uv(Vector2(b.x + b.z, b.y))
	st.add_vertex(b)
	st.set_uv(Vector2(c.x + c.z, c.y))
	st.add_vertex(c)

static func _tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2) -> void:
	st.set_uv(uva)
	st.add_vertex(a)
	st.set_uv(uvb)
	st.add_vertex(b)
	st.set_uv(uvc)
	st.add_vertex(c)

static func _box(st: SurfaceTool, center: Vector3, w: float, h: float, d: float) -> void:
	var x := [center.x - w / 2.0, center.x + w / 2.0]
	var y := [center.y - h / 2.0, center.y + h / 2.0]
	var z := [center.z - d / 2.0, center.z + d / 2.0]
	var v := [
		Vector3(x[0], y[0], z[0]), Vector3(x[1], y[0], z[0]), Vector3(x[1], y[1], z[0]), Vector3(x[0], y[1], z[0]),
		Vector3(x[0], y[0], z[1]), Vector3(x[1], y[0], z[1]), Vector3(x[1], y[1], z[1]), Vector3(x[0], y[1], z[1]),
	]
	var faces := [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [4, 5, 1, 0], [3, 2, 6, 7]]
	for f in faces:
		_tri(st, v[f[0]], v[f[3]], v[f[2]])
		_tri(st, v[f[0]], v[f[2]], v[f[1]])

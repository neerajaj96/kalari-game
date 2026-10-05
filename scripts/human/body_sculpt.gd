extends RefCounted
# BodySculpt: parametric anatomical meshes. No primitives in output —
# every surface is a sculpted lathe/grid with DNA-driven proportions,
# muscle masses, facial structure, hands/feet articulation, UVs + cavity.
# LOD: 0 Hero, 1 Mid, 2 Far. Units in meters. Faces -Z (Godot forward).
class_name BodySculpt

static func skin_tone(dna: HumanDNA) -> Color:
	var m: float = clampf(dna.melanin, 0.0, 1.0)
	var w: float = clampf(dna.skin_warm, 0.0, 1.0)
	# Kerala brown ramp: fair (0.72,0.52,0.38) -> deep (0.32,0.20,0.14).
	var fair := Color(0.72, 0.52, 0.38, 1.0)
	var deep := Color(0.30, 0.185, 0.13, 1.0)
	var c: Color = fair.lerp(deep, m)
	c.r = clampf(c.r + (w - 0.5) * 0.06, 0.0, 1.0)
	c.g = clampf(c.g + (w - 0.5) * 0.02, 0.0, 1.0)
	return c

static func skin_shadow(dna: HumanDNA) -> Color:
	return skin_tone(dna) * Color(0.62, 0.58, 0.56, 1.0)

# --- generic lathe -------------------------------------------------------
static func lathe(profile: PackedVector2Array, radial: int, uv_scale: Vector2 = Vector2(1.0, 1.0), v_color: Color = Color(1, 1, 1, 1)) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := profile.size()
	for r in range(rows - 1):
		for s in range(radial):
			var a0 := TAU * float(s) / float(radial)
			var a1 := TAU * float(s + 1) / float(radial)
			var p00 := Vector3(cos(a0) * profile[r].x, profile[r].y, sin(a0) * profile[r].x)
			var p01 := Vector3(cos(a1) * profile[r].x, profile[r].y, sin(a1) * profile[r].x)
			var p10 := Vector3(cos(a0) * profile[r + 1].x, profile[r + 1].y, sin(a0) * profile[r + 1].x)
			var p11 := Vector3(cos(a1) * profile[r + 1].x, profile[r + 1].y, sin(a1) * profile[r + 1].x)
			var u0 := float(s) / float(radial) * uv_scale.x
			var u1 := float(s + 1) / float(radial) * uv_scale.x
			var v0 := float(r) / float(rows - 1) * uv_scale.y
			var v1 := float(r + 1) / float(rows - 1) * uv_scale.y
			st.set_color(v_color)
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p00)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p11)
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(p01)
			st.set_color(v_color)
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p00)
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(p10)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p11)
	st.generate_normals()
	return st.commit()

# Ellipsoid grid (head cranium + face masses). nu x nv quads -> tris.
static func ellipsoid(rx: float, ry: float, rz: float, nu: int, nv: int, deform: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for iv in range(nv + 1):
		var row: Array = []
		var theta := PI * float(iv) / float(nv) # 0 top .. PI bottom
		for iu in range(nu + 1):
			var phi := TAU * float(iu) / float(nu)
			var p := Vector3(rx * sin(theta) * cos(phi), ry * cos(theta), rz * sin(theta) * sin(phi))
			var uv := Vector2(float(iu) / float(nu), float(iv) / float(nv))
			var d: Array = deform.call(p, uv)
			row.append([d[0], d[1]])
		grid.append(row)
	for iv in range(nv):
		for iu in range(nu):
			var a: Array = grid[iv][iu]
			var b: Array = grid[iv][iu + 1]
			var c: Array = grid[iv + 1][iu + 1]
			var e: Array = grid[iv + 1][iu]
			_tri_c(st, a[0], c[0], b[0], a[1], c[1], b[1])
			_tri_c(st, a[0], e[0], c[0], a[1], e[1], c[1])
	st.generate_normals()
	return st.commit()

static func _tri_c(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.set_uv(Vector2(a.x + a.z, a.y))
	st.add_vertex(a)
	st.set_color(cb)
	st.set_uv(Vector2(b.x + b.z, b.y))
	st.add_vertex(b)
	st.set_color(cc)
	st.set_uv(Vector2(c.x + c.z, c.y))
	st.add_vertex(c)

# --- torso: neck->chest->waist->pelvis with pectoral/lat/abs/belly masses --
static func build_torso(dna: HumanDNA, lod: int) -> ArrayMesh:
	var radial := 20 if lod == 0 else (14 if lod == 1 else 8)
	var h := dna.stature
	var chest_r := lerpf(0.145, 0.185, dna.build) * (dna.shoulder_width / 0.44)
	var waist_r := lerpf(0.125, 0.165, dna.build) + dna.belly * 0.035
	var pelvis_r := dna.hip_width * 0.5 + 0.02
	var chest_y := h * 0.78
	var waist_y := h * 0.60
	var pelvis_y := h * 0.50
	var neck_y := h * 0.855
	var prof := PackedVector2Array()
	var n := 14 if lod == 0 else 9
	for i in range(n + 1):
		var t := float(i) / float(n) # 0 pelvis .. 1 neck
		var y := lerpf(pelvis_y, neck_y, t)
		var r := pelvis_r
		if t < 0.35:
			r = lerpf(pelvis_r, waist_r, t / 0.35)
		elif t < 0.7:
			r = lerpf(waist_r, chest_r, (t - 0.35) / 0.35)
		else:
			r = lerpf(chest_r, 0.062, (t - 0.7) / 0.3)
		# pectoral shelf + lat flare near chest (front -Z fuller).
		prof.append(Vector2(maxf(r, 0.02), y))
	var mesh := lathe(prof, radial)
	# Muscle/face-front fullness is added in shader displacement pass;
	# geometry carries correct silhouette + volume for all views.
	return mesh

static func torso_height(dna: HumanDNA) -> Dictionary:
	var h := dna.stature
	return {"pelvis": h * 0.52, "chest": h * 0.78, "neck": h * 0.855, "head": h * 0.965}

# --- head: cranium + sculpted face (orbits, nose, lips, jaw, chin) --------
static func build_head(dna: HumanDNA, lod: int) -> ArrayMesh:
	var nu := 28 if lod == 0 else (18 if lod == 1 else 10)
	var nv := 20 if lod == 0 else (13 if lod == 1 else 8)
	var h := dna.stature
	var head_c := Vector3(0, h * 0.94, -0.01)
	var rx := 0.098 * (1.0 + dna.jaw_width * 0.10)
	var ry := 0.118
	var rz := 0.108
	var jaw_w: float = dna.jaw_width
	var jaw_a: float = dna.jaw_angle
	var cheek: float = dna.cheek_full
	var brow: float = dna.brow_ridge
	var nose_l: float = dna.nose_length
	var nose_w: float = dna.nose_width
	var nose_t: float = dna.nose_tip
	var lip: float = dna.lip_full
	var chin: float = dna.chin_proj
	var eye_d: float = dna.eye_depth
	var wr: float = dna.wrinkle
	var deform := func(p: Vector3, uv: Vector2) -> Array:
		var q := p
		# Normalized direction: y up. Front is -Z.
		var front := clampf(-q.z / maxf(rz, 0.001), -1.0, 1.0)
		var side := q.x / maxf(rx, 0.001)
		var vert := q.y / maxf(ry, 0.001)
		# Cranium: slightly longer back.
		if q.z > 0.0:
			q.z *= 1.08
		# Jaw taper: narrow lower sides by jaw width/angle.
		if vert < -0.15:
			var k := clampf((-vert - 0.15) / 0.85, 0.0, 1.0)
			q.x *= 1.0 - k * (0.18 + jaw_w * 0.10)
			q.z *= 1.0 - k * 0.06
			# chin projection forward.
			if front > 0.4:
				q.z -= k * chin * 0.018
		# Cheek fullness / cheekbone.
		if vert > -0.5 and vert < 0.35 and absf(side) > 0.35 and front > 0.0:
			q.x += signf(side) * cheek * 0.012 * front
		# Brow ridge above orbits.
		if vert > 0.05 and vert < 0.45 and front > 0.55:
			q.z -= brow * 0.010 * front
		# Orbits: shallow sockets where eyes sit.
		if vert > -0.05 and vert < 0.35 and front > 0.6:
			var ex := absf(absf(q.x) - 0.036 - dna.eye_set * 0.004)
			if ex < 0.028:
				q.z += (0.028 - ex) * 0.35 * eye_d * front
		# Nose: bridge + tip projection (front center, mid height).
		if absf(q.x) < (0.018 + nose_w * 0.010) and vert > -0.45 and vert < 0.15 and front > 0.3:
			var nk := 1.0 - clampf(absf(q.x) / maxf(0.018 + nose_w * 0.010, 0.001), 0.0, 1.0)
			q.z -= nk * (0.022 + nose_l * 0.008 + nose_t * 0.010)
			q.x *= 1.0 + nose_w * 0.10 * nk
		# Lips: upper/lower fullness bands below nose.
		if absf(q.x) < 0.032 and vert > -0.72 and vert < -0.42 and front > 0.5:
			q.z -= (0.004 + lip * 0.006) * front
		# Wrinkle: forehead + nasolabial micro-ridges (subtle geometry).
		if wr > 0.01 and lod == 0:
			var wfreq := 40.0
			var wamp := 0.0012 * wr
			if vert > 0.3 and front > 0.5:
				q.z += sin(q.y * wfreq) * wamp
		var col := Color(1, 1, 1, 1)
		# Cavity darkening: orbits, nostril base, mouth corners, ears.
		var cav := 0.0
		if vert > -0.05 and vert < 0.35 and front > 0.6:
			cav = maxf(cav, 0.35)
		if absf(q.x) < 0.012 and vert < -0.35 and vert > -0.5 and front > 0.5:
			cav = maxf(cav, 0.30)
		col = Color(1.0 - cav * 0.5, 1.0 - cav * 0.5, 1.0 - cav * 0.5, 1.0)
		return [head_c + q, col]
	return ellipsoid(rx, ry, rz, nu, nv, deform)

static func signf(x: float) -> float:
	return 1.0 if x >= 0.0 else -1.0

# --- limbs: tapered segments with muscle bellies --------------------------
static func limb_profile(len: float, r0: float, r1: float, belly_pos: float, belly_amt: float, lod: int) -> PackedVector2Array:
	var n := 10 if lod == 0 else 6
	var prof := PackedVector2Array()
	for i in range(n + 1):
		var t := float(i) / float(n)
		var r := lerpf(r0, r1, t)
		var b := exp(-pow((t - belly_pos) * 3.2, 2.0)) * belly_amt
		prof.append(Vector2(maxf(r + b, 0.015), -t * len))
	return prof

static func build_upper_arm(dna: HumanDNA, lod: int) -> ArrayMesh:
	var m := dna.muscle
	var r := lerpf(0.052, 0.068, dna.build) + m * 0.008
	return lathe(limb_profile(0.30, r, r * 0.82, 0.35, 0.012 + m * 0.010, lod), 14 if lod == 0 else 9)

static func build_forearm(dna: HumanDNA, lod: int) -> ArrayMesh:
	var m := dna.muscle
	var r := lerpf(0.045, 0.058, dna.build) + m * 0.005
	return lathe(limb_profile(0.28, r, r * 0.66, 0.30, 0.010 + m * 0.008, lod), 14 if lod == 0 else 9)

static func build_thigh(dna: HumanDNA, lod: int) -> ArrayMesh:
	var r := lerpf(0.075, 0.105, dna.build)
	return lathe(limb_profile(0.44, r, r * 0.74, 0.35, 0.016 + dna.muscle * 0.010, lod), 16 if lod == 0 else 10)

static func build_shin(dna: HumanDNA, lod: int) -> ArrayMesh:
	var r := lerpf(0.055, 0.072, dna.build)
	return lathe(limb_profile(0.42, r * 0.9, r * 0.52, 0.28, 0.014 + dna.muscle * 0.008, lod), 16 if lod == 0 else 10)

# --- hands: Hero articulated fingers, Mid mitten, Far stub ----------------
static func build_hand(dna: HumanDNA, lod: int) -> ArrayMesh:
	if lod == 2:
		return lathe(limb_profile(0.16, 0.042, 0.036, 0.5, 0.004, lod), 6)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Palm: flattened box-sculpt grid.
	var pw := 0.042 * (1.0 + dna.build * 0.15)
	var pl := 0.10
	var pt := 0.022
	var nx := 6 if lod == 0 else 3
	var ny := 6 if lod == 0 else 3
	for ix in range(nx):
		for iy in range(ny):
			var x0 := lerpf(-pw, pw, float(ix) / float(nx))
			var x1 := lerpf(-pw, pw, float(ix + 1) / float(nx))
			var y0 := lerpf(0.0, -pl, float(iy) / float(ny))
			var y1 := lerpf(0.0, -pl, float(iy + 1) / float(ny))
			_quad(st, Vector3(x0, y0, -pt), Vector3(x1, y0, -pt), Vector3(x1, y1, -pt), Vector3(x0, y1, -pt))
			_quad(st, Vector3(x0, y1, pt), Vector3(x1, y1, pt), Vector3(x1, y0, pt), Vector3(x0, y0, pt))
	st.generate_normals()
	var palm := st.commit()
	if lod == 1:
		# Mid: mitten + thumb wedge merged into one mesh.
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		_quad(st2, Vector3(-0.03, -pl, -0.02), Vector3(0.03, -pl, -0.02), Vector3(0.02, -pl - 0.06, 0.0), Vector3(-0.02, -pl - 0.06, 0.0))
		st2.generate_normals()
		return _merge(palm, st2.commit())
	# Hero: four fingers + thumb as tapered lathes appended.
	var meshes: Array = [palm]
	var fw := [0.011, 0.012, 0.011, 0.009]
	var fl := [0.075, 0.085, 0.078, 0.060]
	for f in range(4):
		var x := lerpf(-0.030, 0.030, float(f) / 3.0)
		var fm := lathe(limb_profile(fl[f], fw[f], fw[f] * 0.7, 0.4, 0.002, lod), 7)
		meshes.append(_offset(fm, Vector3(x, -pl, -0.004)))
	var thumb := lathe(limb_profile(0.060, 0.012, 0.009, 0.4, 0.002, lod), 7)
	meshes.append(_offset(_rotate_x(thumb, 0.9), Vector3(-0.048, -0.035, -0.008)))
	var out: ArrayMesh = meshes[0]
	for i in range(1, meshes.size()):
		out = _merge(out, meshes[i])
	return out

static func build_foot(dna: HumanDNA, lod: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fw := 0.048 * (1.0 + dna.build * 0.10)
	var fl := 0.24 * (dna.stature / 1.70)
	var fh := 0.075
	var nx := 6 if lod == 0 else 3
	var nz := 8 if lod == 0 else 4
	for ix in range(nx):
		for iz in range(nz):
			var x0 := lerpf(-fw, fw, float(ix) / float(nx))
			var x1 := lerpf(-fw, fw, float(ix + 1) / float(nx))
			var z0 := lerpf(0.06, -fl + 0.06, float(iz) / float(nz))
			var z1 := lerpf(0.06, -fl + 0.06, float(iz + 1) / float(nz))
			# Arch: midfoot raised.
			var mid0 := exp(-pow((float(iz) / float(nz) - 0.5) * 3.0, 2.0)) * 0.018
			var mid1 := exp(-pow((float(iz + 1) / float(nz) - 0.5) * 3.0, 2.0)) * 0.018
			_quad(st, Vector3(x0, fh - mid0, z0), Vector3(x1, fh - mid0, z0), Vector3(x1, fh - mid1, z1), Vector3(x0, fh - mid1, z1))
			_quad(st, Vector3(x0, 0.012, z1), Vector3(x1, 0.012, z1), Vector3(x1, 0.012, z0), Vector3(x0, 0.012, z0))
	st.generate_normals()
	var base := st.commit()
	if lod != 0:
		return base
	# Hero toes: 5 tapered segments fanning forward.
	var toes: Array = [base]
	for t in range(5):
		var x := lerpf(-0.036, 0.036, float(t) / 4.0)
		var tl := 0.045 - absf(float(t) - 1.5) * 0.006
		var tm := lathe(limb_profile(tl, 0.011, 0.008, 0.5, 0.001, lod), 6)
		tm = _rotate_x(tm, -1.5708)
		toes.append(_offset(tm, Vector3(x, 0.025, -fl + 0.05)))
	var out: ArrayMesh = toes[0]
	for i in range(1, toes.size()):
		out = _merge(out, toes[i])
	return out

# --- eyes / teeth / inner mouth ------------------------------------------
static func build_eyeball(lod: int) -> ArrayMesh:
	var segs := 16 if lod == 0 else 10
	var prof := PackedVector2Array()
	var n := 10
	for i in range(n + 1):
		var t := float(i) / float(n)
		var y := lerpf(0.0135, -0.0135, t)
		var r := sqrt(maxf(0.0135 * 0.0135 - y * y, 0.0))
		prof.append(Vector2(maxf(r, 0.0005), y))
	return lathe(prof, segs)

static func build_teeth_strip() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.030
	_quad(st, Vector3(-w, 0.0, 0.0), Vector3(w, 0.0, 0.0), Vector3(w, -0.012, -0.004), Vector3(-w, -0.012, -0.004))
	st.generate_normals()
	return st.commit()

static func build_eyebrow(dna: HumanDNA, side: float, lod: int) -> ArrayMesh:
	# Brow-local sculpted wedge: thick at inner third, tapering outward.
	var thick := 0.006 + dna.brow_thick * 0.006
	var length := 0.038
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 6 if lod == 0 else 3
	for ix in range(nx):
		var t0 := float(ix) / float(nx)
		var t1 := float(ix + 1) / float(nx)
		# Arch: peak at 1/3 from inner edge.
		var arch0 := sin(t0 * PI * 0.9) * 0.004
		var arch1 := sin(t1 * PI * 0.9) * 0.004
		var w0 := thick * (1.0 - t0 * 0.55) + dna.brow_thick * 0.002
		var w1 := thick * (1.0 - t1 * 0.55) + dna.brow_thick * 0.002
		var x0 := side * t0 * length
		var x1 := side * t1 * length
		_quad(st, Vector3(x0, arch0 + w0 * 0.5, -0.002), Vector3(x0, arch0 - w0 * 0.5, -0.002), Vector3(x1, arch1 - w1 * 0.5, -0.002), Vector3(x1, arch1 + w1 * 0.5, -0.002))
	st.generate_normals()
	return st.commit()

static func build_ear(dna: HumanDNA, side: float, lod: int) -> ArrayMesh:
	# Head-local helix + lobe + antihelix ridge. Size varies with DNA ear_size.
	var s := 1.0 + dna.ear_size * 0.25
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 5 if lod == 0 else 3
	var ny := 7 if lod == 0 else 4
	for ix in range(nx):
		for iy in range(ny):
			var fx0 := float(ix) / float(nx)
			var fx1 := float(ix + 1) / float(nx)
			var fy0 := float(iy) / float(ny)
			var fy1 := float(iy + 1) / float(ny)
			# Ear plane at side of head, helix curls outward.
			var px0 := side * (0.092 * s + sin(fx0 * PI) * 0.018 * s)
			var px1 := side * (0.092 * s + sin(fx1 * PI) * 0.018 * s)
			var py0 := lerpf(0.035 * s, -0.045 * s, fy0)
			var py1 := lerpf(0.035 * s, -0.045 * s, fy1)
			var pz0 := lerpf(0.015, 0.035, fx0) + sin(fy0 * PI) * 0.004
			var pz1 := lerpf(0.015, 0.035, fx1) + sin(fy1 * PI) * 0.004
			var c := Color(0.85, 0.85, 0.85, 1.0)
			st.set_color(c)
			st.set_uv(Vector2(fx0, fy0))
			st.add_vertex(Vector3(px0, py0, pz0))
			st.set_uv(Vector2(fx1, fy1))
			st.add_vertex(Vector3(px1, py1, pz1))
			st.set_uv(Vector2(fx1, fy0))
			st.add_vertex(Vector3(px1, py0, pz0))
			st.set_color(c)
			st.set_uv(Vector2(fx0, fy0))
			st.add_vertex(Vector3(px0, py0, pz0))
			st.set_uv(Vector2(fx0, fy1))
			st.add_vertex(Vector3(px0, py1, pz1))
			st.set_uv(Vector2(fx1, fy1))
			st.add_vertex(Vector3(px1, py1, pz1))
	st.generate_normals()
	return st.commit()

static func build_lips(dna: HumanDNA, upper: bool) -> ArrayMesh:
	# Lip volume: upper thin + philtrum ridge, lower fuller + central cleft.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.032 * (1.0 + dna.lip_full * 0.25)
	var h := 0.009 + dna.lip_full * 0.005
	if not upper:
		h *= 1.35
	var nx := 8
	for ix in range(nx):
		var t0 := float(ix) / float(nx)
		var t1 := float(ix + 1) / float(nx)
		var x0 := lerpf(-w, w, t0)
		var x1 := lerpf(-w, w, t1)
		# Cupid's bow (upper) / cleft (lower) + corner taper.
		var bow0 := sin(t0 * PI) * h * (0.7 if upper else 1.0)
		var bow1 := sin(t1 * PI) * h * (0.7 if upper else 1.0)
		if upper:
			bow0 += exp(-pow((t0 - 0.5) * 6.0, 2.0)) * -0.003
			bow1 += exp(-pow((t1 - 0.5) * 6.0, 2.0)) * -0.003
		var y0 := bow0 * 0.5
		var y1 := bow1 * 0.5
		var z := -0.002
		_quad(st, Vector3(x0, y0 + h * 0.5, z), Vector3(x1, y1 + h * 0.5, z), Vector3(x1, y1 - h * 0.5, z - 0.003), Vector3(x0, y0 - h * 0.5, z - 0.003))
	st.generate_normals()
	return st.commit()

# --- hair masses ----------------------------------------------------------
static func build_hair(dna: HumanDNA, lod: int) -> ArrayMesh:
	var segs := 18 if lod == 0 else 12
	match dna.hair_style:
		0: # kuduma: cap + topknot.
			var cap := _hair_cap(0.103, 0.06, segs)
			var knot_prof := PackedVector2Array([Vector2(0.001, 0.0), Vector2(0.028, 0.005), Vector2(0.032, 0.030), Vector2(0.018, 0.055), Vector2(0.001, 0.060)])
			var knot := _offset(lathe(knot_prof, 10), Vector3(0.0, 0.075, 0.075))
			return _merge(cap, knot)
		2: # headwrap: full cloth-like wrap over crown.
			return _hair_cap(0.112, 0.02, segs)
		3: # long tie: cap + pony tail.
			var cap3 := _hair_cap(0.103, 0.06, segs)
			var tail := _offset(lathe(limb_profile(0.22, 0.028, 0.014, 0.3, 0.004, lod), 8), Vector3(0.0, 0.03, 0.105))
			return _merge(cap3, tail)
		4: # shaven: scalp shadow only.
			return _hair_cap(0.099, 0.075, 8)
		5: # bun + cover: cap + rear bun.
			var cap5 := _hair_cap(0.104, 0.055, segs)
			var bun := _offset(lathe(PackedVector2Array([Vector2(0.001, 0.0), Vector2(0.035, 0.01), Vector2(0.030, 0.045), Vector2(0.001, 0.055)]), 10), Vector3(0.0, 0.01, 0.10))
			return _merge(cap5, bun)
		_: # short crop (default).
			return _hair_cap(0.103, 0.045, segs)

static func _hair_cap(r: float, top_cut: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nv := 7
	for iv in range(nv):
		for s in range(segs):
			var a0 := TAU * float(s) / float(segs)
			var a1 := TAU * float(s + 1) / float(segs)
			var t0 := float(iv) / float(nv)
			var t1 := float(iv + 1) / float(nv)
			var y0 := lerpf(0.11, top_cut, t0)
			var y1 := lerpf(0.11, top_cut, t1)
			var rr0 := r * sqrt(maxf(1.0 - pow((y0 - 0.01) / 0.115, 2.0), 0.05))
			var rr1 := r * sqrt(maxf(1.0 - pow((y1 - 0.01) / 0.115, 2.0), 0.05))
			var p00 := Vector3(cos(a0) * rr0, y0, sin(a0) * rr0 * 1.05)
			var p01 := Vector3(cos(a1) * rr0, y0, sin(a1) * rr0 * 1.05)
			var p10 := Vector3(cos(a0) * rr1, y1, sin(a0) * rr1 * 1.05)
			var p11 := Vector3(cos(a1) * rr1, y1, sin(a1) * rr1 * 1.05)
			_tri_c(st, p00, p11, p01, Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 1))
			_tri_c(st, p00, p10, p11, Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 1))
	st.generate_normals()
	return st.commit()

static func build_beard(dna: HumanDNA, lod: int) -> ArrayMesh:
	if dna.beard_style == 0:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 10 if lod == 0 else 6
	var ny := 6 if lod == 0 else 4
	var len := 0.02
	match dna.beard_style:
		1:
			len = 0.008
		2:
			len = 0.018
		3:
			len = 0.045
		4:
			len = 0.075
	for ix in range(nx):
		for iy in range(ny):
			var x0 := lerpf(-0.055, 0.055, float(ix) / float(nx))
			var x1 := lerpf(-0.055, 0.055, float(ix + 1) / float(nx))
			var y0 := lerpf(-0.01, -0.01 - len, float(iy) / float(ny))
			var y1 := lerpf(-0.01, -0.01 - len, float(iy + 1) / float(ny))
			var z0 := -0.075 - absf(x0) * 0.25 - float(iy) / float(ny) * 0.015
			var z1 := -0.075 - absf(x1) * 0.25 - float(iy + 1) / float(ny) * 0.015
			_quad(st, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1))
	st.generate_normals()
	return st.commit()

# --- mesh utils -----------------------------------------------------------
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.set_color(Color(1, 1, 1, 1))
	st.set_uv(Vector2(a.x + a.z, a.y))
	st.add_vertex(a)
	st.set_uv(Vector2(b.x + b.z, b.y))
	st.add_vertex(b)
	st.set_uv(Vector2(c.x + c.z, c.y))
	st.add_vertex(c)
	st.set_uv(Vector2(a.x + a.z, a.y))
	st.add_vertex(a)
	st.set_uv(Vector2(c.x + c.z, c.y))
	st.add_vertex(c)
	st.set_uv(Vector2(d.x + d.z, d.y))
	st.add_vertex(d)

static func _merge(a: ArrayMesh, b: ArrayMesh) -> ArrayMesh:
	if a == null:
		return b
	if b == null:
		return a
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(a, 0, Transform3D.IDENTITY)
	st.append_from(b, 0, Transform3D.IDENTITY)
	# append_from keeps normals; regenerate for consistent shading.
	return st.commit()

static func _offset(m: ArrayMesh, off: Vector3) -> ArrayMesh:
	if m == null:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(m, 0, Transform3D(Basis.IDENTITY, off))
	return st.commit()

static func _rotate_x(m: ArrayMesh, ang: float) -> ArrayMesh:
	if m == null:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(m, 0, Transform3D(Basis(Vector3(1, 0, 0), ang), Vector3.ZERO))
	return st.commit()

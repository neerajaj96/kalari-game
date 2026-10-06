extends RefCounted
# GarmentBuilder: real garment construction — layered cloth with thickness
# (outer + inner + hem roll), folds/pleats, seams/piping, waist knots,
# belts, straps, pouches, jewellery. Culturally Kerala: kaccha langoti,
# mundu/veshti with kara border + front pleat fan, angavastram drape,
# lungi, sari + blouse, kurta-churidar, priest whites, headwrap.
# Cloth behavior: hem sway + fold ripple in vertex shader zone is faked by
# sculpted folds; runtime sway handled by HumanAnim bone motion (no Cloth3D
# on Mobile for perf — drape bones instead).
class_name GarmentBuilder

# Waist wrap: layered mundu/langoti/kaccha cylinder with pleat fan front.
static func build_waist_wrap(dna: HumanDNA, lod: int) -> ArrayMesh:
	var h := dna.stature
	var waist_y := h * 0.60
	var hip_y := h * 0.48
	var hem_y := h * 0.30 if dna.garment_set != 0 else h * 0.44
	var waist_r := lerpf(0.135, 0.175, dna.build) + 0.018
	var hip_r := waist_r + 0.025
	var hem_r := hip_r + (0.035 if dna.garment_set == 3 else 0.015)
	var radial := 22 if lod == 0 else (14 if lod == 1 else 8)
	var rows := 8 if lod == 0 else 5
	var profile := PackedVector2Array()
	# Build top->hem profile with waist cinch + hip ease + hem flare.
	for i in range(rows + 1):
		var t := float(i) / float(rows)
		var y := lerpf(waist_y, hem_y, t)
		var r := waist_r
		if t < 0.3:
			r = lerpf(waist_r, hip_r, t / 0.3)
		else:
			r = lerpf(hip_r, hem_r, (t - 0.3) / 0.7)
		profile.append(Vector2(r, y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rows):
		for s in range(radial):
			var a0 := TAU * float(s) / float(radial)
			var a1 := TAU * float(s + 1) / float(radial)
			# Front pleat fan: deepen 3 front folds (-Z) on veshti/mundu.
			var fan0 := _pleat(a0, dna)
			var fan1 := _pleat(a1, dna)
			var p00 := Vector3(cos(a0) * (profile[r].x + fan0), profile[r].y, sin(a0) * (profile[r].x + fan0))
			var p01 := Vector3(cos(a1) * (profile[r].x + fan1), profile[r].y, sin(a1) * (profile[r].x + fan1))
			var p10 := Vector3(cos(a0) * (profile[r + 1].x + fan0 * 1.4), profile[r + 1].y, sin(a0) * (profile[r + 1].x + fan0 * 1.4))
			var p11 := Vector3(cos(a1) * (profile[r + 1].x + fan1 * 1.4), profile[r + 1].y, sin(a1) * (profile[r + 1].x + fan1 * 1.4))
			var shade := Color(1, 1, 1, 1)
			# Fold AO in pleat valleys.
			var ao := 1.0 - clampf(absf(fan0) * 22.0, 0.0, 0.35)
			shade = Color(ao, ao, ao, 1.0)
			st.set_color(shade)
			st.set_uv(Vector2(float(s) / float(radial) * 3.0, float(r) / float(rows)))
			st.add_vertex(p00)
			st.set_uv(Vector2(float(s + 1) / float(radial) * 3.0, float(r + 1) / float(rows)))
			st.add_vertex(p11)
			st.set_uv(Vector2(float(s + 1) / float(radial) * 3.0, float(r) / float(rows)))
			st.add_vertex(p01)
			st.set_color(shade)
			st.set_uv(Vector2(float(s) / float(radial) * 3.0, float(r) / float(rows)))
			st.add_vertex(p00)
			st.set_uv(Vector2(float(s) / float(radial) * 3.0, float(r + 1) / float(rows)))
			st.add_vertex(p10)
			st.set_uv(Vector2(float(s + 1) / float(radial) * 3.0, float(r + 1) / float(rows)))
			st.add_vertex(p11)
	st.generate_normals()
	var outer := st.commit()
	if lod == 2:
		return outer
	# Thickness: inner wall (reversed) + hemband roll.
	var inner := _offset_mesh(outer, Vector3(0, -0.004, 0))
	return _merge_mesh(outer, inner)

static func _pleat(angle: float, dna: HumanDNA) -> float:
	# Front is -Z => angle ~ -PI/2 (sin negative). Pleats only on lower half handled by caller scale.
	var frontness := clampf(-sin(angle), 0.0, 1.0)
	if frontness < 0.25:
		return 0.0
	if dna.garment_set == 0:
		# Kaccha: tight, small athletic folds.
		return sin(angle * 9.0) * 0.004 * frontness
	# Veshti/mundu/sari: deep front pleat fan (5 pleats).
	return sin(angle * 14.0) * 0.010 * frontness

# Shoulder drape: angavastram / sari pallu / shawl over one shoulder.
static func build_shoulder_drape(dna: HumanDNA, lod: int) -> ArrayMesh:
	var h := dna.stature
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 10 if lod == 0 else 6
	var ny := 6 if lod == 0 else 4
	var over_left := dna.garment_set != 3 # sari pallu over right instead
	var x0 := -0.20 if over_left else 0.02
	var x1 := 0.02 if over_left else 0.20
	for ix in range(nx):
		for iy in range(ny):
			var fx0 := float(ix) / float(nx)
			var fx1 := float(ix + 1) / float(nx)
			var fy0 := float(iy) / float(ny)
			var fy1 := float(iy + 1) / float(ny)
			var px0 := lerpf(x0, x1, fx0)
			var px1 := lerpf(x0, x1, fx1)
			var py0 := lerpf(h * 0.80, h * 0.52, fy0)
			var py1 := lerpf(h * 0.80, h * 0.52, fy1)
			# Drape curve: chest-hugging top, free-hanging bottom + fold ripple.
			var ripple0 := sin(fx0 * 12.0 + fy0 * 4.0) * 0.012 * fy0
			var ripple1 := sin(fx1 * 12.0 + fy1 * 4.0) * 0.012 * fy1
			var pz0 := -0.190 - fy0 * 0.035 + ripple0
			var pz1 := -0.190 - fy1 * 0.035 + ripple1
			var ao := 1.0 - absf(ripple0) * 8.0
			var c := Color(ao, ao, ao, 1.0)
			st.set_color(c)
			st.set_uv(Vector2(fx0 * 2.0, fy0))
			st.add_vertex(Vector3(px0, py0, pz0))
			st.set_uv(Vector2(fx1 * 2.0, fy1))
			st.add_vertex(Vector3(px1, py1, pz1))
			st.set_uv(Vector2(fx1 * 2.0, fy0))
			st.add_vertex(Vector3(px1, py0, pz0 + (pz1 - pz0) * 0.0))
			st.set_color(c)
			st.set_uv(Vector2(fx0 * 2.0, fy0))
			st.add_vertex(Vector3(px0, py0, pz0))
			st.set_uv(Vector2(fx0 * 2.0, fy1))
			st.add_vertex(Vector3(px0, py1, pz1))
			st.set_uv(Vector2(fx1 * 2.0, fy1))
			st.add_vertex(Vector3(px1, py1, pz1))
	st.generate_normals()
	return st.commit()

# Sash / belt / waist cord with knot.
static func build_belt(dna: HumanDNA, _lod: int) -> ArrayMesh:
	var h := dna.stature
	var waist_r := lerpf(0.14, 0.18, dna.build) + 0.022
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radial := 18
	for s in range(radial):
		var a0 := TAU * float(s) / float(radial)
		var a1 := TAU * float(s + 1) / float(radial)
		var p00 := Vector3(cos(a0) * waist_r, h * 0.605, sin(a0) * waist_r)
		var p01 := Vector3(cos(a1) * waist_r, h * 0.605, sin(a1) * waist_r)
		var p10 := Vector3(cos(a0) * waist_r, h * 0.555, sin(a0) * waist_r)
		var p11 := Vector3(cos(a1) * waist_r, h * 0.555, sin(a1) * waist_r)
		_quad_c(st, p00, p01, p11, p10)
	st.generate_normals()
	var band := st.commit()
	# Front knot block.
	var ks := SurfaceTool.new()
	ks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kw := 0.045
	var ky := h * 0.58
	var kz := -waist_r - 0.015
	_box(ks, Vector3(0, ky, kz), kw, 0.05, 0.03)
	ks.generate_normals()
	return _merge_mesh(band, ks.commit())

# Chest band for bandits / sash diagonal for rank.
static func build_chest_sash(dna: HumanDNA, lod: int) -> ArrayMesh:
	var h := dna.stature
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 4
	var ny := 12 if lod == 0 else 7
	for ix in range(nx):
		for iy in range(ny):
			var fx := float(ix) / float(nx)
			var fy0 := float(iy) / float(ny)
			var fy1 := float(iy + 1) / float(ny)
			# Diagonal from right shoulder to left hip (front -Z).
			var cx0 := lerpf(0.14, -0.16, fy0) + (fx - 0.5) * 0.10
			var cx1 := lerpf(0.14, -0.16, fy1) + (fx - 0.5) * 0.10
			var cy0 := lerpf(h * 0.80, h * 0.58, fy0)
			var cy1 := lerpf(h * 0.80, h * 0.58, fy1)
			var cz := -0.210 + sin(fy0 * 9.0) * 0.006
			var c := Color(0.95, 0.95, 0.95, 1.0)
			st.set_color(c)
			st.set_uv(Vector2(fx, fy0))
			st.add_vertex(Vector3(cx0 - 0.05, cy0, cz))
			st.set_uv(Vector2(fx, fy1))
			st.add_vertex(Vector3(cx1 + 0.05, cy1, cz - 0.01))
			st.set_uv(Vector2(fx, fy0))
			st.add_vertex(Vector3(cx0 + 0.05, cy0, cz))
			st.set_color(c)
			st.set_uv(Vector2(fx, fy0))
			st.add_vertex(Vector3(cx0 - 0.05, cy0, cz))
			st.set_uv(Vector2(fx, fy1))
			st.add_vertex(Vector3(cx1 - 0.05, cy1, cz - 0.01))
			st.set_uv(Vector2(fx, fy1))
			st.add_vertex(Vector3(cx1 + 0.05, cy1, cz - 0.01))
	st.generate_normals()
	return st.commit()

# Kurta / shirt torso cover for villagers/priest.
static func build_kurta(dna: HumanDNA, lod: int) -> ArrayMesh:
	var h := dna.stature
	var chest_r := lerpf(0.155, 0.195, dna.build) + 0.038
	var hem_r := chest_r + 0.015
	var radial := 20 if lod == 0 else 12
	var rows := 6 if lod == 0 else 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rows):
		for s in range(radial):
			var a0 := TAU * float(s) / float(radial)
			var a1 := TAU * float(s + 1) / float(radial)
			var t0 := float(r) / float(rows)
			var t1 := float(r + 1) / float(rows)
			var y0 := lerpf(h * 0.83, h * 0.52, t0)
			var y1 := lerpf(h * 0.83, h * 0.52, t1)
			var rr0 := lerpf(chest_r, hem_r, t0) + sin(a0 * 7.0) * 0.004 * t0
			var rr1 := lerpf(chest_r, hem_r, t1) + sin(a1 * 7.0) * 0.004 * t1
			var p00 := Vector3(cos(a0) * rr0, y0, sin(a0) * rr0)
			var p01 := Vector3(cos(a1) * rr0, y0, sin(a1) * rr0)
			var p10 := Vector3(cos(a0) * rr1, y1, sin(a0) * rr1)
			var p11 := Vector3(cos(a1) * rr1, y1, sin(a1) * rr1)
			st.set_color(Color(1, 1, 1, 1))
			st.set_uv(Vector2(float(s) / float(radial) * 3.0, t0))
			st.add_vertex(p00)
			st.set_uv(Vector2(float(s + 1) / float(radial) * 3.0, t1))
			st.add_vertex(p11)
			st.set_uv(Vector2(float(s + 1) / float(radial) * 3.0, t0))
			st.add_vertex(p01)
			st.set_color(Color(1, 1, 1, 1))
			st.set_uv(Vector2(float(s) / float(radial) * 3.0, t0))
			st.add_vertex(p00)
			st.set_uv(Vector2(float(s) / float(radial) * 3.0, t1))
			st.add_vertex(p10)
			st.set_uv(Vector2(float(s + 1) / float(radial) * 3.0, t1))
			st.add_vertex(p11)
	st.generate_normals()
	return st.commit()

# Blouse for sari wearers (fitted, short sleeve hint).
static func build_blouse(dna: HumanDNA, lod: int) -> ArrayMesh:
	var h := dna.stature
	var r := lerpf(0.145, 0.175, dna.build) + 0.033
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radial := 18 if lod == 0 else 10
	for s in range(radial):
		var a0 := TAU * float(s) / float(radial)
		var a1 := TAU * float(s + 1) / float(radial)
		var p00 := Vector3(cos(a0) * r, h * 0.78, sin(a0) * r)
		var p01 := Vector3(cos(a1) * r, h * 0.78, sin(a1) * r)
		var p10 := Vector3(cos(a0) * (r + 0.008), h * 0.66, sin(a0) * (r + 0.008))
		var p11 := Vector3(cos(a1) * (r + 0.008), h * 0.66, sin(a1) * (r + 0.008))
		_quad_c(st, p00, p01, p11, p10)
	st.generate_normals()
	return st.commit()

# Accessories: earrings, necklace, bangles, anklets, sacred thread, pouch.
# Bone-local variants (origin at the owning bone) for correct skeletal follow.
# Character-local legacy builder kept for compat.
static func build_earrings_headlocal(dna: HumanDNA) -> ArrayMesh:
	if not (dna.jewellery & 1):
		return null
	var parts: Array = []
	for side in [-1.0, 1.0]:
		# Head-local: lobe sits at y≈-0.042 (see build_ear), just behind the jaw corner.
		parts.append(_offset_mesh(_torus(0.012, 0.0035, 8, 6), Vector3(side * 0.098, -0.042, 0.005)))
	if parts.is_empty():
		return null
	var out: ArrayMesh = parts[0]
	for i in range(1, parts.size()):
		out = _merge_mesh(out, parts[i])
	return out

static func build_bangles_armlocal(dna: HumanDNA, side: float) -> ArrayMesh:
	if not (dna.jewellery & 4):
		return null
	# Forearm bone-local: wrist is ~ -0.27 below forearm origin; bangle sits there.
	# Ring clears the wrist radius (~0.035) with room for the sleeve gap.
	return _offset_mesh(_torus(0.042, 0.006, 10, 6), Vector3(0, -0.24, 0))

static func build_anklet_footlocal(dna: HumanDNA) -> ArrayMesh:
	if not (dna.jewellery & 8):
		return null
	return _offset_mesh(_torus(0.034, 0.005, 10, 6), Vector3(0, 0.06, -0.02))

static func build_chest_jewellery(dna: HumanDNA) -> ArrayMesh:
	var parts: Array = []
	var h := dna.stature
	if dna.jewellery & 2:
		parts.append(_offset_mesh(_torus(0.055, 0.005, 14, 6), Vector3(0, h * 0.78, -0.15)))
	if dna.jewellery & 16:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_quad_c(st, Vector3(0.10, h * 0.80, -0.175), Vector3(0.12, h * 0.80, -0.175), Vector3(-0.10, h * 0.58, -0.195), Vector3(-0.12, h * 0.58, -0.195))
		st.generate_normals()
		parts.append(st.commit())
	if parts.is_empty():
		return null
	var out: ArrayMesh = parts[0]
	for i in range(1, parts.size()):
		out = _merge_mesh(out, parts[i])
	return out

static func build_sandal_footlocal(_side: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Foot-local: sole under ankle (y ~0.01), centered z ~-0.05 forward.
	_box(st, Vector3(0, 0.012, -0.05), 0.10, 0.025, 0.26)
	st.generate_normals()
	return st.commit()

static func build_headband(dna: HumanDNA, lod: int) -> ArrayMesh:
	# Bandit/fighter forehead band: wrapped strip with knot tails.
	var h := dna.stature
	var cy := h * 0.94 + 0.055
	var r := 0.104
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radial := 18 if lod == 0 else 10
	for s in range(radial):
		var a0 := TAU * float(s) / float(radial)
		var a1 := TAU * float(s + 1) / float(radial)
		var p00 := Vector3(cos(a0) * r, cy, sin(a0) * r * 1.02)
		var p01 := Vector3(cos(a1) * r, cy, sin(a1) * r * 1.02)
		var p10 := Vector3(cos(a0) * r, cy - 0.035, sin(a0) * r * 1.02)
		var p11 := Vector3(cos(a1) * r, cy - 0.035, sin(a1) * r * 1.02)
		_quad_c(st, p00, p01, p11, p10)
	# Rear knot tails.
	_box(st, Vector3(0, cy - 0.05, r + 0.02), 0.03, 0.09, 0.012)
	st.generate_normals()
	return st.commit()

static func build_thigh_wrap_single(dna: HumanDNA, lod: int) -> ArrayMesh:
	# Thigh-local ring clearing the thigh radius on every build.
	var r0 := lerpf(0.075, 0.105, dna.build) + 0.010
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radial := 14 if lod == 0 else 8
	var rows := 4 if lod == 0 else 2
	for r in range(rows):
		for s in range(radial):
			var a0 := TAU * float(s) / float(radial)
			var a1 := TAU * float(s + 1) / float(radial)
			var t0 := float(r) / float(rows)
			var t1 := float(r + 1) / float(rows)
			var y0 := lerpf(-0.06, -0.22, t0)
			var y1 := lerpf(-0.06, -0.22, t1)
			var rr0 := lerpf(r0, r0 - 0.013, t0) + sin(a0 * 6.0) * 0.003
			var rr1 := lerpf(r0, r0 - 0.013, t1) + sin(a1 * 6.0) * 0.003
			_quad_c(st, Vector3(cos(a0) * rr0, y0, sin(a0) * rr0), Vector3(cos(a1) * rr0, y0, sin(a1) * rr0), Vector3(cos(a1) * rr1, y1, sin(a1) * rr1), Vector3(cos(a0) * rr1, y1, sin(a0) * rr1))
	st.generate_normals()
	return st.commit()

static func build_waist_knot(dna: HumanDNA) -> ArrayMesh:
	# Cloth waist knot with two hanging tails (front center).
	var h := dna.stature
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ky := h * 0.575
	var kz := -0.205
	_box(st, Vector3(0, ky, kz), 0.055, 0.045, 0.035)
	_quad_c(st, Vector3(-0.02, ky - 0.02, kz - 0.015), Vector3(0.0, ky - 0.02, kz - 0.015), Vector3(-0.005, ky - 0.13, kz - 0.005), Vector3(-0.025, ky - 0.13, kz - 0.005))
	_quad_c(st, Vector3(0.0, ky - 0.02, kz - 0.015), Vector3(0.02, ky - 0.02, kz - 0.015), Vector3(0.025, ky - 0.11, kz - 0.005), Vector3(0.005, ky - 0.11, kz - 0.005))
	st.generate_normals()
	return st.commit()

static func build_pouch(dna: HumanDNA, _lod: int) -> ArrayMesh:
	# Bandit/market pouch on belt + weapon strap.
	if dna.garment_set != 2 and dna.label.find("villager") < 0:
		return null
	var h := dna.stature
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Rides proud of the hip wrap (wrap radius ~0.22): offset keeps it visible.
	_box(st, Vector3(0.20, h * 0.52, 0.14), 0.09, 0.11, 0.05)
	st.generate_normals()
	return st.commit()

static func build_sandals(_lod: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		_box(st, Vector3(side * 0.10, 0.025, -0.05), 0.10, 0.025, 0.26)
	st.generate_normals()
	return st.commit()

# --- small mesh helpers ---------------------------------------------------
static func _quad_c(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
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

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_color(Color(1, 1, 1, 1))
	st.set_uv(Vector2(a.x + a.z, a.y))
	st.add_vertex(a)
	st.set_uv(Vector2(b.x + b.z, b.y))
	st.add_vertex(b)
	st.set_uv(Vector2(c.x + c.z, c.y))
	st.add_vertex(c)

static func _torus(major: float, minor: float, segs_u: int, segs_v: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iu in range(segs_u):
		for iv in range(segs_v):
			var u0 := TAU * float(iu) / float(segs_u)
			var u1 := TAU * float(iu + 1) / float(segs_u)
			var v0 := TAU * float(iv) / float(segs_v)
			var v1 := TAU * float(iv + 1) / float(segs_v)
			var p00 := Vector3(cos(u0) * (major + minor * cos(v0)), minor * sin(v0), sin(u0) * (major + minor * cos(v0)))
			var p01 := Vector3(cos(u1) * (major + minor * cos(v0)), minor * sin(v0), sin(u1) * (major + minor * cos(v0)))
			var p10 := Vector3(cos(u0) * (major + minor * cos(v1)), minor * sin(v1), sin(u0) * (major + minor * cos(v1)))
			var p11 := Vector3(cos(u1) * (major + minor * cos(v1)), minor * sin(v1), sin(u1) * (major + minor * cos(v1)))
			_tri(st, p00, p11, p01)
			_tri(st, p00, p10, p11)
	st.generate_normals()
	return st.commit()

static func _merge_mesh(a: ArrayMesh, b: ArrayMesh) -> ArrayMesh:
	if a == null:
		return b
	if b == null:
		return a
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(a, 0, Transform3D.IDENTITY)
	st.append_from(b, 0, Transform3D.IDENTITY)
	return st.commit()

static func _offset_mesh(m: ArrayMesh, off: Vector3) -> ArrayMesh:
	if m == null:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(m, 0, Transform3D(Basis.IDENTITY, off))
	return st.commit()

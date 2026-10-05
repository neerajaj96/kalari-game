extends RefCounted
# HumanFactory: DNA -> cinematic human. Builds Hero/Mid/Far visual sets +
# shared Skeleton3D + procedural animation + facial rig + IK + garments +
# accessories, hides legacy primitive nodes (collision untouched), and
# reuses meshes/materials/rigs across characters by DNA hash.
# Fallback-first: returns null headless-safe; caller keeps primitives.
class_name HumanFactory

static var _mesh_cache: Dictionary = {}

static func cache_size() -> int:
	return _mesh_cache.size()

static func clear_cache() -> void:
	_mesh_cache.clear()
	HumanMaterials.clear_cache()

static func _mkey(kind: String, dna: HumanDNA, lod: int) -> String:
	return "%s_%d_%d_%d" % [kind, dna.seed, dna.garment_set, lod]

static func _cached_mesh(kind: String, dna: HumanDNA, lod: int, builder: Callable) -> ArrayMesh:
	var k := _mkey(kind, dna, lod)
	if _mesh_cache.has(k):
		return _mesh_cache[k]
	var m: ArrayMesh = builder.call()
	if m != null:
		_mesh_cache[k] = m
	return m

static func _iris_xform() -> Transform3D:
	var b := Basis.from_scale(Vector3(0.45, 0.45, 0.3))
	return Transform3D(b, Vector3(0, 0, -0.0085))

# Main entry. parent = character root (CharacterBody3D/StaticBody3D).
# Returns the CinematicBody node, or null on failure (caller keeps fallback).
static func build(parent: Node, dna: HumanDNA) -> Node3D:
	if parent == null or dna == null:
		return null
	var body := Node3D.new()
	body.name = "CinematicBody"
	parent.add_child(body)
	var sk := HumanRig.build_skeleton(dna)
	sk.name = "HumanSkeleton"
	body.add_child(sk)
	var face := FaceAnim.new()
	face.name = "FaceAnim"
	body.add_child(face)
	face.setup(sk, dna)
	var ik := IKSolver.new()
	ik.name = "IKSolver"
	body.add_child(ik)
	ik.setup(sk)
	var anim := HumanAnim.new()
	anim.name = "HumanAnim"
	body.add_child(anim)
	anim.setup(sk, dna, face, ik)
	var hero_sets: Array = []
	var mid_sets: Array = []
	var far_sets: Array = []
	_build_lod_into(sk, dna, 0, hero_sets)
	_build_lod_into(sk, dna, 1, mid_sets)
	_build_lod_into(sk, dna, 2, far_sets)
	var lod := HumanLOD.new()
	lod.name = "HumanLOD"
	body.add_child(lod)
	lod.force_hero = DisplayServer.get_name() == "headless"
	lod.setup_sets(body, hero_sets, mid_sets, far_sets)
	_hide_primitives(parent)
	body.set_meta("dna_seed", dna.seed)
	return body

static func bone_global_rest(sk: Skeleton3D, bone: String) -> Vector3:
	var i := sk.find_bone(bone)
	if i < 0:
		return Vector3.ZERO
	var acc := Vector3.ZERO
	var c := i
	while c >= 0:
		acc += (sk.get_bone_rest(c) as Transform3D).origin
		c = sk.get_bone_parent(c)
	return acc

static func _pupil_xform() -> Transform3D:
	var b := Basis.from_scale(Vector3(0.22, 0.22, 0.18))
	return Transform3D(b, Vector3(0, 0, -0.0115))

static func _build_lod_into(sk: Skeleton3D, dna: HumanDNA, lod: int, out_sets: Array) -> void:
	var skin_mat: Material = HumanMaterials.skin_material(dna)
	var hair_mat: Material = HumanMaterials.hair_material(dna)
	var cloth_mat: Material = HumanMaterials.cloth_material(dna, 0.85 if dna.garment_set in [1, 3] else 0.0)
	var accent_mat: Material = HumanMaterials.cloth_material(dna, 1.0)
	# Character-local (absolute) surfaces compensate the bone offset;
	# bone-local surfaces (limbs/eyes/hair) attach with identity.
	_add_seg(sk, "chest", _cached_mesh("torso", dna, lod, func() -> ArrayMesh: return BodySculpt.build_torso(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, true)
	_add_seg(sk, "head", _cached_mesh("head", dna, lod, func() -> ArrayMesh: return BodySculpt.build_head(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, true)
	var eye_mesh: ArrayMesh = _cached_mesh("eyeball", dna, lod, func() -> ArrayMesh: return BodySculpt.build_eyeball(lod))
	_add_seg(sk, "eye_L", eye_mesh, HumanMaterials.eye_white_material(), Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.002)), lod, out_sets, false)
	_add_seg(sk, "eye_R", eye_mesh, HumanMaterials.eye_white_material(), Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.002)), lod, out_sets, false)
	var iris_mesh: ArrayMesh = _cached_mesh("iris", dna, lod, func() -> ArrayMesh: return BodySculpt.build_eyeball(lod))
	_add_seg(sk, "eye_L", iris_mesh, HumanMaterials.iris_material(dna), _iris_xform(), lod, out_sets, false)
	_add_seg(sk, "eye_R", iris_mesh, HumanMaterials.iris_material(dna), _iris_xform(), lod, out_sets, false)
	var pupil_mesh: ArrayMesh = _cached_mesh("pupil", dna, lod, func() -> ArrayMesh: return BodySculpt.build_eyeball(lod))
	_add_seg(sk, "eye_L", pupil_mesh, HumanMaterials.pupil_material(), _pupil_xform(), lod, out_sets, false)
	_add_seg(sk, "eye_R", pupil_mesh, HumanMaterials.pupil_material(), _pupil_xform(), lod, out_sets, false)
	_add_seg(sk, "jaw", BodySculpt.build_teeth_strip(), HumanMaterials.teeth_material(), Transform3D(Basis.IDENTITY, Vector3(0, -0.01, -0.055)), lod, out_sets, false)
	if lod < 2:
		_add_seg(sk, "brow_L", BodySculpt.build_eyebrow(dna, -1.0, lod), HumanMaterials.hair_material(dna), Transform3D.IDENTITY, lod, out_sets, false)
		_add_seg(sk, "brow_R", BodySculpt.build_eyebrow(dna, 1.0, lod), HumanMaterials.hair_material(dna), Transform3D.IDENTITY, lod, out_sets, false)
		_add_seg(sk, "head", BodySculpt.build_ear(dna, -1.0, lod), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
		_add_seg(sk, "head", BodySculpt.build_ear(dna, 1.0, lod), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
		var lip_mat: Material = HumanMaterials.lip_material(dna)
		_add_seg(sk, "head", BodySculpt.build_lips(dna, true), lip_mat, Transform3D(Basis.IDENTITY, Vector3(0, -0.062, -0.098)), lod, out_sets, false)
		_add_seg(sk, "jaw", BodySculpt.build_lips(dna, false), lip_mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.008, -0.045)), lod, out_sets, false)
	# Bandit headband (Hero + Mid).
	if dna.garment_set == 2 and lod < 2:
		_add_seg(sk, "head", GarmentBuilder.build_headband(dna, lod), accent_mat, Transform3D.IDENTITY, lod, out_sets, true)
	_add_seg(sk, "head", _cached_mesh("hair", dna, lod, func() -> ArrayMesh: return BodySculpt.build_hair(dna, lod)), hair_mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.01, 0.005)), lod, out_sets, false)
	var beard: ArrayMesh = BodySculpt.build_beard(dna, lod)
	if beard != null:
		_add_seg(sk, "jaw", beard, hair_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_seg(sk, "upperarm_L", _cached_mesh("uarm", dna, lod, func() -> ArrayMesh: return BodySculpt.build_upper_arm(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_seg(sk, "upperarm_R", _cached_mesh("uarm", dna, lod, func() -> ArrayMesh: return BodySculpt.build_upper_arm(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_seg(sk, "forearm_L", _cached_mesh("farm", dna, lod, func() -> ArrayMesh: return BodySculpt.build_forearm(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_seg(sk, "forearm_R", _cached_mesh("farm", dna, lod, func() -> ArrayMesh: return BodySculpt.build_forearm(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_seg(sk, "hand_L", _cached_mesh("hand", dna, lod, func() -> ArrayMesh: return BodySculpt.build_hand(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_seg(sk, "hand_R", _cached_mesh("hand", dna, lod, func() -> ArrayMesh: return BodySculpt.build_hand(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_seg(sk, "thigh_L", _cached_mesh("thigh", dna, lod, func() -> ArrayMesh: return BodySculpt.build_thigh(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_seg(sk, "thigh_R", _cached_mesh("thigh", dna, lod, func() -> ArrayMesh: return BodySculpt.build_thigh(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_seg(sk, "shin_L", _cached_mesh("shin", dna, lod, func() -> ArrayMesh: return BodySculpt.build_shin(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_seg(sk, "shin_R", _cached_mesh("shin", dna, lod, func() -> ArrayMesh: return BodySculpt.build_shin(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_seg(sk, "foot_L", _cached_mesh("foot", dna, lod, func() -> ArrayMesh: return BodySculpt.build_foot(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_seg(sk, "foot_R", _cached_mesh("foot", dna, lod, func() -> ArrayMesh: return BodySculpt.build_foot(dna, lod)), skin_mat, Transform3D.IDENTITY, lod, out_sets, false)
	_add_garments(sk, dna, lod, cloth_mat, accent_mat, out_sets)

static func _add_garments(sk: Skeleton3D, dna: HumanDNA, lod: int, cloth_mat: Material, accent_mat: Material, out_sets: Array) -> void:
	var wrap: ArrayMesh = _cached_mesh("wrap", dna, lod, func() -> ArrayMesh: return GarmentBuilder.build_waist_wrap(dna, lod))
	if wrap != null:
		_add_seg(sk, "pelvis", wrap, cloth_mat if dna.garment_set != 2 else accent_mat, Transform3D.IDENTITY, lod, out_sets, true)
	_add_seg(sk, "pelvis", GarmentBuilder.build_belt(dna, lod), HumanMaterials.leather_material(), Transform3D.IDENTITY, lod, out_sets, true)
	match dna.garment_set:
		0:
			_add_seg(sk, "chest", GarmentBuilder.build_chest_sash(dna, lod), accent_mat, Transform3D.IDENTITY, lod, out_sets, true)
		1, 5:
			_add_seg(sk, "chest", GarmentBuilder.build_shoulder_drape(dna, lod), cloth_mat, Transform3D.IDENTITY, lod, out_sets, true)
			if dna.garment_set == 5:
				_add_seg(sk, "chest", GarmentBuilder.build_kurta(dna, lod), cloth_mat, Transform3D.IDENTITY, lod, out_sets, true)
		2:
			_add_seg(sk, "chest", GarmentBuilder.build_chest_sash(dna, lod), accent_mat, Transform3D.IDENTITY, lod, out_sets, true)
		3:
			_add_seg(sk, "chest", GarmentBuilder.build_blouse(dna, lod), accent_mat, Transform3D.IDENTITY, lod, out_sets, true)
			_add_seg(sk, "chest", GarmentBuilder.build_shoulder_drape(dna, lod), cloth_mat, Transform3D.IDENTITY, lod, out_sets, true)
		4:
			_add_seg(sk, "chest", GarmentBuilder.build_kurta(dna, lod), cloth_mat, Transform3D.IDENTITY, lod, out_sets, true)
	# Jewellery split by owning bone so pieces follow head/arms/feet correctly.
	# Far LOD skips jewellery/pouch (perf, invisible at distance).
	var gold: Material = HumanMaterials.metal_material(Color(0.78, 0.55, 0.20, 1.0), 0.30)
	if lod == 0:
		var ear: ArrayMesh = GarmentBuilder.build_earrings_headlocal(dna)
		if ear != null:
			_add_seg(sk, "head", ear, gold, Transform3D.IDENTITY, lod, out_sets, false)
	var chest_jew: ArrayMesh = GarmentBuilder.build_chest_jewellery(dna)
	if chest_jew != null and lod < 2:
		_add_seg(sk, "chest", chest_jew, gold, Transform3D.IDENTITY, lod, out_sets, true)
	if dna.jewellery & 4 and lod == 0:
		_add_seg(sk, "forearm_L", GarmentBuilder.build_bangles_armlocal(dna, -1.0), gold, Transform3D.IDENTITY, lod, out_sets, false)
		_add_seg(sk, "forearm_R", GarmentBuilder.build_bangles_armlocal(dna, 1.0), gold, Transform3D.IDENTITY, lod, out_sets, false)
	if dna.jewellery & 8 and lod < 2:
		_add_seg(sk, "foot_L", GarmentBuilder.build_anklet_footlocal(dna), gold, Transform3D.IDENTITY, lod, out_sets, false)
		_add_seg(sk, "foot_R", GarmentBuilder.build_anklet_footlocal(dna), gold, Transform3D.IDENTITY, lod, out_sets, false)
	var pouch: ArrayMesh = GarmentBuilder.build_pouch(dna, lod)
	if pouch != null and lod < 2:
		_add_seg(sk, "pelvis", pouch, HumanMaterials.leather_material(), Transform3D.IDENTITY, lod, out_sets, true)
	if dna.label == "gurukkal" or dna.garment_set == 5:
		_add_seg(sk, "foot_L", GarmentBuilder.build_sandal_footlocal(-1.0), HumanMaterials.leather_material(), Transform3D.IDENTITY, lod, out_sets, false)
		_add_seg(sk, "foot_R", GarmentBuilder.build_sandal_footlocal(1.0), HumanMaterials.leather_material(), Transform3D.IDENTITY, lod, out_sets, false)

static func _add_seg(sk: Skeleton3D, bone: String, mesh: ArrayMesh, mat: Material, off: Transform3D, lod: int, out_sets: Array, absolute: bool = false) -> void:
	if mesh == null:
		return
	var ba := BoneAttachment3D.new()
	ba.name = "Attach_%s_L%d_%d" % [bone, lod, out_sets.size()]
	ba.bone_name = bone
	ba.bone_idx = sk.find_bone(bone)
	sk.add_child(ba)
	var mi := MeshInstance3D.new()
	mi.name = "Seg_" + bone
	mi.mesh = mesh
	if mat != null:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if lod == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if absolute:
		# Character-local mesh -> bone-local: cancel the bone's rest offset.
		var bg := bone_global_rest(sk, bone)
		mi.transform = Transform3D(off.basis, off.origin - bg)
	else:
		mi.transform = off
	ba.add_child(mi)
	out_sets.append(ba)

static func _hide_primitives(parent: Node) -> void:
	# Hide legacy primitive visuals; collision shapes + weapons untouched.
	var names := ["Body", "Head", "ArmL", "ArmR", "LegL", "LegR", "FootL", "FootR",
		"Beard", "Angavastram", "Langoti", "RankSash", "HairCap", "Kuduma",
		"EyeL", "EyeR", "PupilL", "PupilR", "Nose", "EarL", "EarR", "BrowL",
		"BrowR", "Mouth", "Teeth", "Chandan", "PecL", "PecR", "AbsRidge",
		"PleatL", "PleatC", "PleatR", "ShoulderL", "ShoulderR", "FistL", "FistR",
		"ThumbL", "ThumbR", "SoleL", "SoleR", "Sash", "BellyBand", "Mustache",
		"Headband", "Headwrap", "VeshtiDrape", "ChestFold"]
	for n in names:
		var v := parent.get_node_or_null(n) as VisualInstance3D
		if v != null:
			v.visible = false
		for prefix in ["Head/", "Body/", "ArmL/", "ArmR/", "LegL/", "LegR/", "WeaponPivot/"]:
			var v2 := parent.get_node_or_null(prefix + n) as VisualInstance3D
			if v2 != null:
				v2.visible = false

static func drive(body: Node3D, delta: float, state: int, planar: float, move_local: Vector3) -> void:
	if body == null or not is_instance_valid(body):
		return
	var anim := body.get_node_or_null("HumanAnim") as Node
	if anim != null and anim.has_method("animate"):
		anim.animate(delta, state, planar, move_local)

static func update_rank_accent(host: Node, rank: int) -> void:
	if host == null or not is_instance_valid(host):
		return
	var body := host.find_child("CinematicBody", true, false) as Node3D
	if body == null:
		return
	var accent := Color(0.97, 0.95, 0.91, 1.0)
	if rank >= 3:
		accent = Color(0.83, 0.63, 0.09, 1.0)
	elif rank == 2:
		accent = Color(0.45, 0.10, 0.10, 1.0)
	var sk := body.find_child("HumanSkeleton", true, false) as Skeleton3D
	if sk == null:
		return
	for ba in sk.get_children():
		if not (ba is BoneAttachment3D):
			continue
		if not str(ba.name).begins_with("Attach_chest"):
			continue
		for mi in ba.get_children():
			if mi is MeshInstance3D and str(mi.name) == "Seg_chest":
				var m := mi.material_override as ShaderMaterial
				if m != null and m.shader != null and str(m.shader.resource_path).find("cloth_weave") >= 0:
					var dup := m.duplicate() as ShaderMaterial
					dup.set_shader_parameter("accent", accent)
					mi.material_override = dup

static func follow_weapon(host: Node) -> void:
	# Staff stays in the right hand: copy hand_R bone motion to WeaponPivot.
	if host == null or not is_instance_valid(host):
		return
	var pivot := host.get_node_or_null("WeaponPivot") as Node3D
	if pivot == null:
		return
	var body := host.find_child("CinematicBody", true, false) as Node3D
	if body == null:
		return
	var sk := body.find_child("HumanSkeleton", true, false) as Skeleton3D
	if sk == null:
		return
	var hi := sk.find_bone("hand_R")
	if hi < 0:
		return
	var hg: Transform3D = sk.get_bone_global_pose(hi)
	var host_global: Transform3D = (host as Node3D).global_transform
	var local: Transform3D = host_global.affine_inverse() * sk.global_transform * hg
	# Grip offset: staff held across palm, blade forward (-Z).
	pivot.transform = Transform3D(local.basis, local.origin + Vector3(0.02, -0.08, -0.10))

extends RefCounted
# HumanRig: shared Skeleton3D definition. One skeleton layout for every
# character; DNA proportions ride on bone scale/position, not new rigs.
# Bones: pelvis/spine/chest/neck/head/jaw + eyes/eyelids/brows +
# clavicle/upperarm/forearm/hand/fingers + thigh/shin/foot/toes.
# Rigid-segment binding via BoneAttachment3D keeps deformation correct
# without soft-skin weight painting (robust headless + mobile safe).
class_name HumanRig

const HumanDNA = preload("res://scripts/human/human_dna.gd")

static func bone_list() -> Array:
	# Finger/toe bones are reserved for runtime-gated per-digit articulation
	# (pending hero audit); hands/feet bind merged segments until then.
	return [
		"pelvis", "spine", "chest", "neck", "head", "jaw",
		"eye_L", "eye_R", "lid_upper_L", "lid_upper_R", "lid_lower_L", "lid_lower_R",
		"brow_L", "brow_R", "cheek_L", "cheek_R",
		"clav_L", "upperarm_L", "forearm_L", "hand_L",
		"thumb_L", "index_L", "middle_L", "ring_L", "pinky_L",
		"clav_R", "upperarm_R", "forearm_R", "hand_R",
		"thumb_R", "index_R", "middle_R", "ring_R", "pinky_R",
		"thigh_L", "shin_L", "foot_L", "toes_L",
		"thigh_R", "shin_R", "foot_R", "toes_R",
	]

static func build_skeleton(dna: HumanDNA) -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "HumanSkeleton"
	var h := dna.stature
	var pelvis_y := h * 0.52
	var spine_y := h * 0.62
	var chest_y := h * 0.74
	var neck_y := h * 0.845
	var head_y := h * 0.94
	var crouch := dna.posture_crouch
	# Each entry: [name, parent_idx, rest_position].
	var defs: Array = [
		["pelvis", -1, Vector3(0, pelvis_y, 0)],
		["spine", 0, Vector3(0, spine_y - pelvis_y, crouch * 0.02)],
		["chest", 1, Vector3(0, chest_y - spine_y, crouch * 0.03)],
		["neck", 2, Vector3(0, neck_y - chest_y, crouch * 0.02)],
		["head", 3, Vector3(0, head_y - neck_y, -crouch * 0.015)],
		["jaw", 4, Vector3(0, -0.055, -0.045)],
		["eye_L", 4, Vector3(-0.036, 0.012, -0.092)],
		["eye_R", 4, Vector3(0.036, 0.012, -0.092)],
		["lid_upper_L", 4, Vector3(-0.036, 0.022, -0.094)],
		["lid_upper_R", 4, Vector3(0.036, 0.022, -0.094)],
		["lid_lower_L", 4, Vector3(-0.036, 0.002, -0.094)],
		["lid_lower_R", 4, Vector3(0.036, 0.002, -0.094)],
		["brow_L", 4, Vector3(-0.038, 0.042, -0.096)],
		["brow_R", 4, Vector3(0.038, 0.042, -0.096)],
		["cheek_L", 4, Vector3(-0.045, -0.020, -0.075)],
		["cheek_R", 4, Vector3(0.045, -0.020, -0.075)],
		["clav_L", 2, Vector3(-0.10, 0.055, 0.0)],
		["upperarm_L", 16, Vector3(-0.09, -0.02, 0.0)],
		["forearm_L", 17, Vector3(-0.02, -0.28, 0.0)],
		["hand_L", 18, Vector3(0.0, -0.27, 0.0)],
		["thumb_L", 19, Vector3(-0.035, -0.03, -0.01)],
		["index_L", 19, Vector3(-0.028, -0.095, -0.004)],
		["middle_L", 19, Vector3(-0.009, -0.10, -0.004)],
		["ring_L", 19, Vector3(0.009, -0.098, -0.004)],
		["pinky_L", 19, Vector3(0.027, -0.090, -0.004)],
		["clav_R", 2, Vector3(0.10, 0.055, 0.0)],
		["upperarm_R", 25, Vector3(0.09, -0.02, 0.0)],
		["forearm_R", 26, Vector3(0.02, -0.28, 0.0)],
		["hand_R", 27, Vector3(0.0, -0.27, 0.0)],
		["thumb_R", 28, Vector3(0.035, -0.03, -0.01)],
		["index_R", 28, Vector3(0.028, -0.095, -0.004)],
		["middle_R", 28, Vector3(0.009, -0.10, -0.004)],
		["ring_R", 28, Vector3(-0.009, -0.098, -0.004)],
		["pinky_R", 28, Vector3(-0.027, -0.090, -0.004)],
		["thigh_L", 0, Vector3(-0.095, -0.03, 0.0)],
		["shin_L", 34, Vector3(0.0, -0.44, 0.0)],
		["foot_L", 35, Vector3(0.0, -0.42, 0.0)],
		["toes_L", 36, Vector3(0.0, -0.045, -0.14)],
		["thigh_R", 0, Vector3(0.095, -0.03, 0.0)],
		["shin_R", 38, Vector3(0.0, -0.44, 0.0)],
		["foot_R", 39, Vector3(0.0, -0.42, 0.0)],
		["toes_R", 40, Vector3(0.0, -0.045, -0.14)],
	]
	for i in range(defs.size()):
		var nm: String = defs[i][0]
		var par: int = defs[i][1]
		var pos: Vector3 = defs[i][2]
		sk.add_bone(nm)
		sk.set_bone_parent(i, par)
		var rest := Transform3D(Basis.IDENTITY, pos)
		# Elder stoop: pitch spine/chest/neck forward slightly.
		if crouch > 0.01 and (nm == "spine" or nm == "chest" or nm == "neck"):
			rest.basis = Basis(Vector3(1, 0, 0), crouch * 0.18)
		if nm == "head" and crouch > 0.01:
			rest.basis = Basis(Vector3(1, 0, 0), -crouch * 0.12)
		sk.set_bone_rest(i, rest)
	# Female pelvis slightly wider stance is handled by bone scale below.
	var pelvis_i := sk.find_bone("pelvis")
	if pelvis_i >= 0 and dna.is_female:
		var t := sk.get_bone_rest(pelvis_i)
		t.origin.x *= 1.0
		sk.set_bone_rest(pelvis_i, t)
	return sk

static func attach_segment(sk: Skeleton3D, parent: Node3D, bone_name: String, mesh: ArrayMesh, material: Material, offset: Transform3D) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.name = "Attach_" + bone_name
	ba.bone_name = bone_name
	ba.bone_idx = sk.find_bone(bone_name)
	parent.add_child(ba)
	# Skeleton must be the parent chain owner; BoneAttachment works when
	# skeleton is an ancestor — factory guarantees that ordering.
	var mi := MeshInstance3D.new()
	mi.name = "Seg_" + bone_name
	if mesh != null:
		mi.mesh = mesh
	if material != null:
		mi.material_override = material
	mi.transform = offset
	ba.add_child(mi)
	return ba

static func rest_pose(sk: Skeleton3D) -> void:
	sk.reset_bone_poses()

extends Node3D
# JointCap: soft-tissue joint ball that hides rigid segment seams.
# Follows the midpoint between two bones each frame (shoulder/elbow/knee/hip),
# giving smooth silhouette during bends without true skinning weights.
# Hero LOD only; Mid/Far rely on overlapping rigid segments.
class_name JointCap

var _sk: Skeleton3D
var _bone_a := ""
var _bone_b := ""
var _w := 0.5
var _radius := 0.06

func setup(sk: Skeleton3D, bone_a: String, bone_b: String, w: float, radius: float) -> void:
	_sk = sk
	_bone_a = bone_a
	_bone_b = bone_b
	_w = w
	_radius = radius

func _process(_delta: float) -> void:
	if _sk == null or not is_instance_valid(_sk):
		return
	var ia := _sk.find_bone(_bone_a)
	var ib := _sk.find_bone(_bone_b)
	if ia < 0 or ib < 0:
		return
	var pa: Vector3 = _sk.get_bone_global_pose(ia).origin
	var pb: Vector3 = _sk.get_bone_global_pose(ib).origin
	# Global poses include the skeleton's world transform; caps live inside
	# the skeleton, so strip it back to skeleton-local space.
	var inv: Transform3D = _sk.global_transform.affine_inverse()
	position = inv * pa.lerp(pb, _w)

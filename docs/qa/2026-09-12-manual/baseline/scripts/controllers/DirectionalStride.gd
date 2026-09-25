extends SkeletonModifier3D
## Keep each blended foot swing in its travel plane. Quaternion blending can
## align ground contact while sending the lifted part of a diagonal stride
## sideways. A two-bone correction preserves height, leg lengths and the torso.
var actor: CharacterBody3D

func _process_modification() -> void:
	if not is_instance_valid(actor) or not actor.on_ground or actor.in_water: return
	if actor._locomotion_amount < 0.001 or Vector2(actor.velocity.x, actor.velocity.z).length() < 0.1: return
	var sk := get_skeleton()
	var world_direction: Vector3 = actor.global_basis * DirectionalLocomotion.travel_direction(
		actor._animation_direction, actor._animation_forward_stride)
	var direction := (sk.global_basis.inverse() * world_direction).normalized()
	direction.y = 0.0
	direction = direction.normalized()
	if direction.length_squared() < 0.001: return
	for side in ["l", "r"]:
		var upper := sk.find_bone("upperleg." + side)
		var lower := sk.find_bone("lowerleg." + side)
		var foot := sk.find_bone("foot." + side)
		if mini(upper, mini(lower, foot)) < 0: continue
		var original := sk.get_bone_global_pose(foot)
		var anchor := sk.get_bone_global_rest(foot).origin
		var offset := original.origin - anchor
		var target := anchor + direction * offset.dot(direction)
		target.y = original.origin.y
		target = original.origin.lerp(target, actor._locomotion_amount)
		_solve_leg(sk, upper, lower, foot, target, original.basis)

static func _solve_leg(sk: Skeleton3D, upper: int, lower: int, foot: int, target: Vector3, foot_basis: Basis) -> void:
	var hip := sk.get_bone_global_pose(upper).origin
	var knee := sk.get_bone_global_pose(lower).origin
	var ankle := sk.get_bone_global_pose(foot).origin
	var thigh := hip.distance_to(knee)
	var shin := knee.distance_to(ankle)
	if minf(thigh, shin) < 0.00001: return
	var reach := target - hip
	if reach.length_squared() < 0.000001: return
	var distance := clampf(reach.length(), absf(thigh-shin)+0.00001, thigh+shin-0.00001)
	var axis := reach.normalized()
	var pole := (knee-hip) - axis * (knee-hip).dot(axis)
	if pole.length_squared() < 0.000001:
		var reference := Vector3.RIGHT if absf(axis.dot(Vector3.FORWARD)) > 0.9 else Vector3.FORWARD
		pole = reference - axis * reference.dot(axis)
	pole = pole.normalized()
	var along := (thigh*thigh + distance*distance - shin*shin) / (2.0*distance)
	var bend := sqrt(maxf(thigh*thigh-along*along,0.0))
	var solved_knee := hip + axis*along + pole*bend
	_rotate_joint(sk, upper, knee-hip, solved_knee-hip)
	var new_knee := sk.get_bone_global_pose(lower).origin
	var new_ankle := sk.get_bone_global_pose(foot).origin
	_rotate_joint(sk, lower, new_ankle-new_knee, hip+axis*distance-new_knee)
	var corrected := sk.get_bone_global_pose(foot)
	corrected.basis = foot_basis
	sk.set_bone_global_pose(foot, corrected)

static func _rotate_joint(sk: Skeleton3D, bone: int, from: Vector3, to: Vector3) -> void:
	if minf(from.length_squared(),to.length_squared()) < 0.000001: return
	var pose := sk.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion(from.normalized(),to.normalized())) * pose.basis
	sk.set_bone_global_pose(bone,pose)

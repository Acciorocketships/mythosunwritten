class_name DirectionalLocomotion
extends RefCounted
const CALIBRATION := preload("res://scripts/controllers/DirectionalBlendCalibration.gd")
## One normalized gait cycle, aligned by the measured left/right foot-height
## signal. Offsets are NORMALIZED timeline seconds (see docs/qa/2026-09-10-tactical).
const WALK_OFFSET := 0.166666667
const BACKWARD_OFFSET := 0.75
# Median planted-foot displacement per cycle, measured on the actual model.
const RUN_STRIDE := 2.10
const STRAFE_STRIDE := 2.33
const BACKWARD_STRIDE := 0.80
const WALK_STRIDE := 0.75
const RUN_CADENCE := 2.0

static func install(tree: AnimationTree, player: AnimationPlayer) -> void:
	var skeleton := player.get_node(player.root_node).get_node("Rig_Medium/Skeleton3D") as Skeleton3D
	# Source resources are nonlooping. Loop-wrap interpolation must be enabled
	# on private copies, otherwise the last keys clamp despite node loop mode.
	var library := player.get_animation_library("CharacterAnimationLibrary").duplicate() as AnimationLibrary
	for name in ["Idle_A", "Walking_A", "Running_A", "Walking_Backwards", "Running_Strafe_Left", "Running_Strafe_Right"]:
		var animation := library.get_animation(name).duplicate() as Animation
		animation.loop_mode = Animation.LOOP_LINEAR
		if name.begins_with("Running_Strafe_"):
			_retarget_strafe(animation, deg_to_rad(30.0 if name.ends_with("Left") else -30.0), skeleton)
		library.remove_animation(name)
		library.add_animation(name, animation)
	player.remove_animation_library("CharacterAnimationLibrary")
	player.add_animation_library("CharacterAnimationLibrary", library)
	# AnimationTree caches the player's library when anim_player is assigned.
	# Rebind after replacing it so the private loops and corrected tracks are used.
	tree.anim_player = NodePath()
	tree.anim_player = player.get_path()
	# The editor-visible graph owns source phases and the airborne state machine.
	tree.tree_root = tree.tree_root.duplicate(true)

static func _retarget_strafe(animation: Animation, yaw: float, skeleton: Skeleton3D) -> void:
	# The supplied "strafe" rotates the whole rig 60 degrees. Put its corrected
	# 90-degree travel in the leg branches, retaining ordinary hip sockets and
	# the original upper-body pose. A shared root frame can then blend with the
	# backward clip without interpolating an unrelated whole-rig turn.
	var source := animation.duplicate() as Animation
	var prefix := "Rig_Medium/Skeleton3D:"
	var root_track := source.find_track(NodePath(prefix + "root"), Animation.TYPE_ROTATION_3D)
	var hips_track := source.find_track(NodePath(prefix + "hips"), Animation.TYPE_ROTATION_3D)
	var hips_position_track := source.find_track(NodePath(prefix + "hips"), Animation.TYPE_POSITION_3D)
	for bone in ["upperleg.l", "upperleg.r", "spine", "root"]:
		var path := NodePath(prefix + bone)
		var source_track := source.find_track(path, Animation.TYPE_ROTATION_3D)
		var track := animation.find_track(path, Animation.TYPE_ROTATION_3D)
		if track >= 0: animation.remove_track(track)
		track = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, path)
		for frame in 120:
			var time := animation.length * frame / 120.0
			var root := source.rotation_track_interpolate(root_track, time)
			var hips := source.rotation_track_interpolate(hips_track, time)
			var pose := source.rotation_track_interpolate(source_track, time) if source_track >= 0 else Quaternion.IDENTITY
			if bone == "root": pose = Quaternion.IDENTITY
			else:
				var correction := Quaternion(Vector3.UP, yaw) if bone.begins_with("upperleg") else Quaternion.IDENTITY
				pose = hips.inverse() * correction * root * hips * pose
			animation.rotation_track_insert_key(track, time, pose.normalized())
		if bone == "root": continue
		var position_track := source.find_track(path, Animation.TYPE_POSITION_3D)
		if position_track < 0 and bone != "spine": continue
		track = animation.find_track(path, Animation.TYPE_POSITION_3D)
		if track >= 0: animation.remove_track(track)
		track = animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(track, path)
		var anchor := skeleton.get_bone_rest(skeleton.find_bone(bone)).origin if bone.begins_with("upperleg") else Vector3.ZERO
		for frame in 120:
			var time := animation.length * frame / 120.0
			var root := source.rotation_track_interpolate(root_track, time)
			var hips := source.rotation_track_interpolate(hips_track, time)
			var correction := Quaternion(Vector3.UP, yaw) if bone.begins_with("upperleg") else Quaternion.IDENTITY
			var position := source.position_track_interpolate(position_track, time) if position_track >= 0 else skeleton.get_bone_rest(skeleton.find_bone(bone)).origin
			position = anchor + (hips.inverse() * correction * root * hips) * (position - anchor)
			if bone == "spine":
				var hips_position := source.position_track_interpolate(hips_position_track, time)
				position += hips.inverse() * (root * hips_position - hips_position)
			animation.position_track_insert_key(track, time, position)

static func blend_direction(world_velocity: Vector3, facing_basis: Basis, forward_stride: float = RUN_STRIDE) -> Vector2:
	var local := facing_basis.inverse() * world_velocity
	if Vector2(local.x,local.z).length_squared() < 0.000001: return Vector2.ZERO
	var angle := rad_to_deg(atan2(absf(local.x),local.z))
	var side := -signf(local.x)
	if local.z < 0.0:
		var weight := _weight_for_angle(angle, CALIBRATION.BACK, CALIBRATION.BACK, 0.0)
		return Vector2(side * (1.0-weight), weight)
	var gait := clampf((forward_stride-WALK_STRIDE)/(RUN_STRIDE-WALK_STRIDE), 0.0, 1.0)
	var weight := _weight_for_angle(angle, CALIBRATION.WALK if gait < 0.5 else CALIBRATION.MIXED,
		CALIBRATION.MIXED if gait < 0.5 else CALIBRATION.RUN, gait*2 if gait < 0.5 else (gait-0.5)*2)
	return Vector2(side * weight, -(1.0-weight))

static func _weight_for_angle(angle: float, lower: Array, upper: Array, gait: float) -> float:
	if angle <= lower[0]: return 0.0
	if angle >= lower[-1]: return 1.0
	var previous: float = lower[0]
	for i in range(1, lower.size()):
		var next := lerpf(lower[i],upper[i],gait)
		if angle <= next:
			return (i-1 + inverse_lerp(previous,next,angle)) / (lower.size()-1)
		previous = next
	return 1.0

static func stride_length(world_direction: Vector3, facing_basis: Basis, forward_stride: float = RUN_STRIDE) -> float:
	var local := facing_basis.inverse() * world_direction.normalized()
	var reciprocal := absf(local.x) / STRAFE_STRIDE 		+ absf(local.z) / (forward_stride if local.z >= 0.0 else BACKWARD_STRIDE)
	return 1.0 / reciprocal if reciprocal > 0.0001 else RUN_STRIDE

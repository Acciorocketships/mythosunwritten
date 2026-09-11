extends GutTest
const CHARACTER := preload("res://characters/character.tscn")

func test_planted_feet_sweep_opposite_actual_travel_in_all_directions() -> void:
	var actor := _character()
	for gait in [0.0, 0.25, 0.5, 0.75, 1.0]:
		_check_contact_directions(actor, gait)

func _check_contact_directions(actor: CharacterBody3D, gait: float) -> void:
	for i in 16:
		var angle := float(i) * TAU / 16
		var travel := Vector3(sin(angle), 0, cos(angle))
		actor.anim_tree.set("parameters/BlendTree/Direction/blend_position",
			DirectionalLocomotion.blend_direction(travel, Basis.IDENTITY,
				lerpf(DirectionalLocomotion.WALK_STRIDE, DirectionalLocomotion.RUN_STRIDE, gait)))
		actor.anim_tree.set("parameters/BlendTree/IdleMotion/blend_amount", 1.0)
		actor.anim_tree.set("parameters/BlendTree/Direction/0/blend_position", gait)
		actor.anim_tree.set("parameters/BlendTree/RunSpeed/scale", 1.0)
		var observed := stance_travel(actor)
		var error := absf(rad_to_deg(Vector2(observed.x,observed.z).angle_to(Vector2(travel.x,travel.z))))
		assert_lt(error, 6.0, "Foot contact sweep must follow travel at yaw %.1f / gait %.2f; error %.1f" % [rad_to_deg(angle),gait,error])

func stance_travel(actor: CharacterBody3D) -> Vector3:
	var samples := stance_samples(actor)
	return median_travel(samples[0] + samples[1])

func stance_samples(actor: CharacterBody3D) -> Array:
	var sk: Skeleton3D = actor.skeleton
	var samples: Array = [[], []]
	for frame in 121:
		actor.anim_tree.advance(1.0/120)
		actor.stride_modifier._process_modification()
		sk.force_update_all_bone_transforms()
		for i in 2:
			samples[i].append(sk.get_bone_global_pose(sk.find_bone("foot.l" if i == 0 else "foot.r")).origin)
	var velocities := []
	for foot: Array in samples:
		var planted := []
		var heights: Array[float] = []
		for point: Vector3 in foot: heights.append(point.y)
		heights.sort()
		for frame in 120:
			if foot[frame].y > heights[24]: continue
			var velocity: Vector3 = (foot[frame + 1] - foot[frame]) * 120
			planted.append(-velocity)
		velocities.append(planted)
	return velocities

func median_travel(velocities: Array) -> Vector3:
	var x: Array[float] = []
	var z: Array[float] = []
	for velocity: Vector3 in velocities:
		x.append(velocity.x)
		z.append(velocity.z)
	x.sort()
	z.sort()
	return Vector3(x[x.size()/2], 0, z[z.size()/2])

func test_each_foot_follows_backward_diagonal_travel() -> void:
	var actor := _character()
	for degrees in [110.0,135.0,160.0,200.0,225.0,250.0]:
		var angle := deg_to_rad(degrees)
		var travel := Vector3(sin(angle),0,cos(angle))
		actor.anim_tree.set("parameters/BlendTree/Direction/blend_position", DirectionalLocomotion.blend_direction(travel, Basis.IDENTITY))
		actor.anim_tree.set("parameters/BlendTree/IdleMotion/blend_amount", 1.0)
		actor.anim_tree.set("parameters/BlendTree/Direction/0/blend_position", 1.0)
		actor.anim_tree.set("parameters/BlendTree/RunSpeed/scale", 1.0)
		for samples: Array in stance_samples(actor):
			var observed := median_travel(samples)
			var error := absf(rad_to_deg(Vector2(observed.x,observed.z).angle_to(Vector2(travel.x,travel.z))))
			assert_lt(error, 10.0, "Each planted foot must follow the backward diagonal independently")

func test_feet_keep_world_travel_direction_while_aim_turns_through_back_diagonals() -> void:
	var actor := _character()
	actor.on_ground = true
	actor.velocity = Vector3.BACK * 10.0
	actor.anim_tree.set("parameters/BlendTree/IdleMotion/blend_amount", 1.0)
	for tick in 60:
		actor.rotation.y = deg_to_rad((tick + 1) * 3.0)
		actor.movement_animation(10.0, 1.0/60)
		if tick not in [29,44,54]: continue
		actor.anim_tree.set("parameters/BlendTree/RunSpeed/scale", 1.0)
		var observed := actor.global_basis * stance_travel(actor)
		var error := absf(rad_to_deg(Vector2(observed.x,observed.z).angle_to(Vector2.DOWN)))
		assert_lt(error, 10.0, "Foot motion must remain aligned with world travel while the character aims through yaw %s" % rad_to_deg(actor.rotation.y))

func test_full_foot_stride_tracks_camera_backward_with_diagonal_aim() -> void:
	var actor := _character()
	for aim_degrees in [135.0, 225.0]:
		actor.rotation.y = deg_to_rad(aim_degrees)
		actor.on_ground = true
		actor.velocity = Vector3.BACK * 10.0
		for tick in 120:
			actor.movement_animation(10.0, 1.0/60)
			actor.anim_tree.advance(1.0/60)
		for foot_name in ["foot.l", "foot.r"]:
			var samples: Array[Vector2] = []
			var mean := Vector2.ZERO
			for frame in 240:
				actor.anim_tree.advance(1.0/240)
				actor.stride_modifier._process_modification()
				actor.skeleton.force_update_all_bone_transforms()
				var point: Vector3 = actor.skeleton.global_basis * actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(foot_name)).origin
				var flat := Vector2(point.x,point.z)
				samples.append(flat)
				mean += flat / 240.0
			var xx := 0.0
			var zz := 0.0
			var xz := 0.0
			for point in samples:
				var centred := point - mean
				xx += centred.x * centred.x
				zz += centred.y * centred.y
				xz += centred.x * centred.y
			var axis := 0.5 * atan2(2.0*xz,xx-zz)
			var error := absf(rad_to_deg(Vector2(cos(axis),sin(axis)).angle_to(Vector2.DOWN)))
			error = minf(error, 180.0-error)
			print("FULL_STRIDE aim=",aim_degrees," foot=",foot_name," error=",error)
			assert_lt(error,10.0,"The entire visible foot stride must track camera-backward travel, not only planted contact")

func test_runtime_stride_modifier_preserves_head_height_and_leg_lengths() -> void:
	var actor := _character()
	actor.rotation.y = deg_to_rad(225)
	actor.on_ground = true
	actor.velocity = Vector3.BACK * 10
	for frame in 90:
		actor.movement_animation(10,1.0/60)
		actor.anim_tree.advance(1.0/60)
	var sk: Skeleton3D = actor.skeleton
	var head := sk.find_bone("head")
	var before_head := sk.get_bone_global_pose(head)
	var before := []
	for side in ["l","r"]:
		before.append([sk.get_bone_global_pose(sk.find_bone("upperleg."+side)).origin,
			sk.get_bone_global_pose(sk.find_bone("lowerleg."+side)).origin,
			sk.get_bone_global_pose(sk.find_bone("foot."+side)).origin])
	var observations := []
	actor.stride_modifier.modification_processed.connect(func():
		var feet := []
		for side in ["l","r"]:
			feet.append([sk.get_bone_global_pose(sk.find_bone("upperleg."+side)).origin,
				sk.get_bone_global_pose(sk.find_bone("lowerleg."+side)).origin,
				sk.get_bone_global_pose(sk.find_bone("foot."+side)).origin])
		observations.append([sk.get_bone_global_pose(head),feet]))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(observations.size(),0,"The production SkeletonModifier callback must run automatically")
	if observations.is_empty(): return
	var result: Array = observations[-1]
	assert_almost_eq(result[0].origin,before_head.origin,Vector3.ONE*0.00001)
	assert_lt(result[0].basis.get_rotation_quaternion().angle_to(before_head.basis.get_rotation_quaternion()),0.0001)
	for i in 2:
		var after: Array = result[1][i]
		assert_almost_eq(after[2].y,before[i][2].y,0.005,"Foot lift is preserved")
		assert_almost_eq(after[0].distance_to(after[1]),before[i][0].distance_to(before[i][1]),0.0001)
		assert_almost_eq(after[1].distance_to(after[2]),before[i][1].distance_to(before[i][2]),0.0001)

func _character() -> CharacterBody3D:
	var actor := CHARACTER.instantiate() as CharacterBody3D
	add_child_autofree(actor)
	actor.set_physics_process(false)
	actor.on_ground = true
	actor.anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.anim_tree.advance(0.01)
	return actor

func test_retargeted_legs_preserve_the_authored_head_pose() -> void:
	var actor := _character()
	var original := load("res://characters/animations/CharacterAnimationLibrary.tres") as AnimationLibrary
	var corrected: AnimationLibrary = actor.anim_player.get_animation_library("CharacterAnimationLibrary")
	var sk: Skeleton3D = actor.skeleton
	var head := sk.find_bone("head")
	for clip in ["Running_Strafe_Left", "Running_Strafe_Right"]:
		var worst_angle := 0.0
		var worst_position := 0.0
		for frame in 60:
			var poses: Array[Transform3D] = []
			for library in [original, corrected]:
				var animation: Animation = library.get_animation(clip)
				_apply_pose(sk, animation, animation.length * frame / 60.0)
				poses.append(sk.get_bone_global_pose(head))
			worst_angle = maxf(worst_angle, poses[0].basis.get_rotation_quaternion().angle_to(poses[1].basis.get_rotation_quaternion()))
			worst_position = maxf(worst_position, poses[0].origin.distance_to(poses[1].origin))
		assert_lt(rad_to_deg(worst_angle), 0.1, "Leg correction retains source head orientation")
		assert_lt(worst_position, 0.001, "Leg correction retains source head position")

func _apply_pose(sk: Skeleton3D, animation: Animation, time: float) -> void:
	sk.reset_bone_poses()
	for track in animation.get_track_count():
		var path := animation.track_get_path(track)
		if path.get_subname_count() == 0: continue
		var bone := sk.find_bone(path.get_subname(0))
		if bone < 0: continue
		match animation.track_get_type(track):
			Animation.TYPE_POSITION_3D: sk.set_bone_pose_position(bone, animation.position_track_interpolate(track,time))
			Animation.TYPE_ROTATION_3D: sk.set_bone_pose_rotation(bone, animation.rotation_track_interpolate(track,time))
			Animation.TYPE_SCALE_3D: sk.set_bone_pose_scale(bone, animation.scale_track_interpolate(track,time))
	sk.force_update_all_bone_transforms()

func test_actual_tree_keeps_diagonal_gaits_lifted_and_loop_seams_continuous() -> void:
	var actor := _character()
	var sk: Skeleton3D = actor.skeleton
	var feet: Array[int] = [sk.find_bone("foot.l"), sk.find_bone("foot.r")]
	for direction in [Vector2.UP, Vector2(0.5,-0.5), Vector2.RIGHT, Vector2(0.5,0.5), Vector2.DOWN, Vector2(-0.5,0.5), Vector2.LEFT, Vector2(-0.5,-0.5)]:
		actor.anim_tree.set("parameters/BlendTree/Direction/blend_position", direction)
		actor.anim_tree.set("parameters/BlendTree/IdleMotion/blend_amount", 1.0)
		actor.anim_tree.set("parameters/BlendTree/Direction/0/blend_position", 1.0)
		actor.anim_tree.set("parameters/BlendTree/RunSpeed/scale", 1.0)
		var previous: Array[Vector3] = []
		var min_height := INF
		var max_step := 0.0
		var max_lift := 0.0
		for tick in 241:
			actor.anim_tree.advance(1.0/120)
			sk.force_update_all_bone_transforms()
			var positions: Array[Vector3] = []
			for foot in feet: positions.append(sk.get_bone_global_pose(foot).origin)
			if tick > 2:
				for i in 2:
					min_height = minf(min_height, positions[i].y)
					max_step = maxf(max_step, previous[i].distance_to(positions[i]))
				max_lift = maxf(max_lift, absf(positions[0].y - positions[1].y))
			previous = positions
		assert_gt(min_height, 0.06, "No ankle sinks into the floor: %s" % direction)
		assert_lt(max_step, 0.10, "No discontinuity at wrap or cancelled directional pose: %s" % direction)
		assert_gt(max_lift, 0.08, "Both opposing legs must retain a readable stride: %s" % direction)

func test_alignment_fixes_the_source_foot_phase_not_only_the_duration() -> void:
	var actor := _character()
	var library: AnimationLibrary = actor.anim_player.get_animation_library("CharacterAnimationLibrary")
	var root := actor.anim_tree.tree_root as AnimationNodeStateMachine
	var blend := root.get_node("BlendTree") as AnimationNodeBlendTree
	var directions := blend.get_node("Direction") as AnimationNodeBlendSpace2D
	var forward := directions.get_blend_point_node(0) as AnimationNodeBlendSpace1D
	assert_almost_eq((forward.get_blend_point_node(0) as AnimationNodeAnimation).start_offset, DirectionalLocomotion.WALK_OFFSET, 0.00001)
	assert_almost_eq((directions.get_blend_point_node(1) as AnimationNodeAnimation).start_offset, DirectionalLocomotion.BACKWARD_OFFSET, 0.00001)

	var run := _signal(actor.skeleton, library.get_animation("Running_A"), 0.0)
	var backward := library.get_animation("Walking_Backwards")
	var walk := library.get_animation("Walking_A")
	var backward_before := _error(run, _signal(actor.skeleton, backward, 0.0))
	var backward_after := _error(run, _signal(actor.skeleton, backward, DirectionalLocomotion.BACKWARD_OFFSET))
	var walk_before := _error(run, _signal(actor.skeleton, walk, 0.0))
	var walk_after := _error(run, _signal(actor.skeleton, walk, DirectionalLocomotion.WALK_OFFSET))
	assert_gt(backward_before, 1.8, "Pin the reported mismatch before phase correction")
	assert_lt(backward_after, backward_before * 0.03)
	assert_gt(walk_before, 0.9)
	assert_lt(walk_after, walk_before * 0.06)

func test_tree_instances_do_not_share_mutable_blend_parameters_or_libraries() -> void:
	var a := _character()
	var b := _character()
	a.anim_tree.set("parameters/BlendTree/Direction/blend_position", Vector2.RIGHT)
	b.anim_tree.set("parameters/BlendTree/Direction/blend_position", Vector2.DOWN)
	assert_ne(a.anim_tree.tree_root, b.anim_tree.tree_root)
	assert_ne(a.anim_player.get_animation_library("CharacterAnimationLibrary"), b.anim_player.get_animation_library("CharacterAnimationLibrary"))
	assert_eq(a.anim_tree.get("parameters/BlendTree/Direction/blend_position"), Vector2.RIGHT)
	assert_eq(b.anim_tree.get("parameters/BlendTree/Direction/blend_position"), Vector2.DOWN)

func _signal(skeleton: Skeleton3D, animation: Animation, offset: float) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	skeleton.reset_bone_poses()
	for frame in 120:
		var t := fposmod(float(frame)/120.0 + offset, 1.0) * animation.length
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			if path.get_subname_count() == 0: continue
			var bone := skeleton.find_bone(path.get_subname(0))
			if bone < 0: continue
			match animation.track_get_type(track):
				Animation.TYPE_POSITION_3D: skeleton.set_bone_pose_position(bone, animation.position_track_interpolate(track,t))
				Animation.TYPE_ROTATION_3D: skeleton.set_bone_pose_rotation(bone, animation.rotation_track_interpolate(track,t))
				Animation.TYPE_SCALE_3D: skeleton.set_bone_pose_scale(bone, animation.scale_track_interpolate(track,t))
		skeleton.force_update_all_bone_transforms()
		result.append(skeleton.get_bone_global_pose(skeleton.find_bone("foot.l")).origin.y \
			- skeleton.get_bone_global_pose(skeleton.find_bone("foot.r")).origin.y)
	var norm := 0.0
	for value in result: norm += value * value
	for i in result.size(): result[i] /= sqrt(norm)
	return result

func _error(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	var result := 0.0
	for i in a.size(): result += (a[i]-b[i]) * (a[i]-b[i])
	return result

func test_reversals_and_strafing_changes_blend_without_pose_teleports() -> void:
	var actor := _character()
	var sk: Skeleton3D = actor.skeleton
	var foot := sk.find_bone("foot.l")
	var previous := Vector3.ZERO
	var worst := 0.0
	var ticks := 0
	for direction in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK]:
		actor.velocity = direction * DirectionalLocomotion.stride_length(direction, Basis.IDENTITY) * 2.0
		for tick in 60:
			actor.movement_animation(actor.velocity.length(), 1.0/60)
			actor.anim_tree.advance(1.0/60)
			actor.stride_modifier._process_modification()
			sk.force_update_all_bone_transforms()
			var point := sk.get_bone_global_pose(foot).origin
			if ticks > 60: worst = maxf(worst, point.distance_to(previous))
			previous = point
			ticks += 1
	assert_lt(worst, 0.22, "Direction reversals may not teleport the foot between source poses")

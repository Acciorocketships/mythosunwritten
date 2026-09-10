extends GutTest
const CHARACTER := preload("res://characters/character.tscn")

func _character() -> CharacterBody3D:
	var actor := CHARACTER.instantiate() as CharacterBody3D
	add_child_autofree(actor)
	actor.set_physics_process(false)
	actor.anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.anim_tree.advance(0.01)
	return actor

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
			sk.force_update_all_bone_transforms()
			var point := sk.get_bone_global_pose(foot).origin
			if ticks > 60: worst = maxf(worst, point.distance_to(previous))
			previous = point
			ticks += 1
	assert_lt(worst, 0.22, "Direction reversals may not teleport the foot between source poses")

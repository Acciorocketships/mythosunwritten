extends GutTest

func _character() -> CharacterBody3D:
	var player := (load("res://characters/character.tscn") as PackedScene).instantiate() as CharacterBody3D
	add_child_autofree(player)
	player.set_physics_process(false)
	player.anim_tree.callback_mode_process=2
	player.anim_tree.advance(0.01)
	return player

func _advance(player: CharacterBody3D, ticks: int) -> void:
	for tick in ticks:
		player.jump_animation(false)
		player.movement_animation(0)
		player.anim_tree.advance(1.0/60)

func test_water_entry_releases_airborne_pose_even_without_ground_contact() -> void:
	var player := _character()
	for cycle in 3:
		player.in_water=false
		player.on_ground=false
		player.velocity=Vector3.ZERO
		player.jump_animation(true)
		_advance(player,40)
		assert_true(player.anim_tree.get("parameters/BlendTree/OneShot/active"),"dry airborne animation still plays")
		player.in_water=true
		_advance(player,180)
		assert_false(player.anim_tree.get("parameters/BlendTree/OneShot/active"),"water entry must release JumpIdle even when the ground ray never hits")

func test_underwater_impulse_does_not_start_dry_jump_pose() -> void:
	var player := _character()
	player.in_water=true
	player.velocity=Vector3.UP*3
	player.jump_animation(true)
	_advance(player,60)
	assert_false(player.anim_tree.get("parameters/BlendTree/OneShot/active"),"swim thrust uses the continuous base pose")
	var animated_bones := 0
	for i in player.skeleton.get_bone_count():
		if player.skeleton.get_bone_pose_rotation(i).angle_to(Quaternion.IDENTITY)>0.15:animated_bones+=1
	assert_gt(animated_bones,4,"the resolved skeleton has a real animated pose rather than rest/T-pose")

func test_water_entry_clears_a_pending_landing_overlay() -> void:
	var player := _character()
	player.in_water=false
	player.jump_animation(true)
	_advance(player,40)
	var playback = player.anim_tree.get("parameters/BlendTree/OneShots/playback")
	playback.travel("JumpLand")
	player.anim_tree.advance(0.05)
	player.in_water=true
	_advance(player,120)
	assert_false(player.anim_tree.get("parameters/BlendTree/OneShot/active"),"a shallow-water landing cannot retain an ended overlay")

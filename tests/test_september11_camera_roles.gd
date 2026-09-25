extends GutTest
const CAMERA := preload("res://scripts/camera/camera.gd")

func _rig() -> Array:
	var world := Node3D.new()
	add_child_autofree(world)
	var target := Node3D.new()
	world.add_child(target)
	var camera := Camera3D.new()
	camera.set_script(CAMERA)
	camera.target = target
	camera.position = Vector3(0,16,26)
	camera.visibility_bubble_enabled = false
	world.add_child(camera)
	camera.make_current()
	camera.set_physics_process(false)
	return [target,camera]

func test_tactical_left_right_motion_turns_the_orbit_and_idle_does_not() -> void:
	for direction in [-1.0,1.0]:
		var rig := _rig()
		var target: Node3D = rig[0]
		var camera: Camera3D = rig[1]
		camera._physics_process(1.0/60)
		for tick in 60:
			target.position.x += direction/6.0
			camera._physics_process(1.0/60)
		assert_gt(-camera._yaw*direction,.1,"Tactical yaw trails left/right travel")
		assert_almost_eq(Vector2(camera.position.x-target.position.x,camera.position.z-target.position.z).length(),26.0,.001)
		camera.reset_orbit()
		var yaw: float = camera._yaw
		for tick in 60: camera._physics_process(1.0/60)
		assert_almost_eq(camera._yaw,yaw,.00001,"Idle must not keep spinning")

func test_close_view_mouse_look_crosshair_and_release() -> void:
	var rig := _rig()
	var camera: Camera3D = rig[1]
	if DisplayServer.get_name() != "headless":
		get_window().grab_focus()
		await get_tree().process_frame
		await get_tree().process_frame
	camera.toggle_view()
	assert_eq(Input.mouse_mode,Input.MOUSE_MODE_CAPTURED,"F7 enters mouse look")
	assert_eq(camera.pointing_position(),camera.get_viewport().get_visible_rect().size/2,"Aim uses center crosshair")
	var before: Basis = camera.global_basis
	var motion := InputEventMouseMotion.new()
	motion.position = camera.get_viewport().get_visible_rect().size/2
	motion.relative = Vector2(100,-80)
	camera.get_viewport().push_input(motion,true)
	camera._physics_process(1.0/60)
	assert_gt((-camera.global_basis.z).x,(-before.z).x+.01,"Right mouse motion turns right")
	assert_gt((-camera.global_basis.z).y,(-before.z).y+.01,"Upward mouse motion looks upward")
	for vertical in [-100000.0,100000.0]:
		motion.relative = Vector2(0,vertical)
		camera.get_viewport().push_input(motion,true)
		camera._physics_process(1.0/60)
		assert_almost_eq(camera._pitch,deg_to_rad(-60 if vertical < 0 else 75),.00001,"Mouse pitch is bounded")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	camera.get_viewport().push_input(escape,true)
	assert_eq(Input.mouse_mode,Input.MOUSE_MODE_VISIBLE,"Escape releases mouse look")
	var released: Basis = camera.global_basis
	camera.get_viewport().push_input(motion,true)
	camera._physics_process(1.0/60)
	assert_almost_eq(camera.global_basis.z,released.z,Vector3.ONE*.00001,"Released pointer does not turn camera")

func test_close_view_travel_does_not_override_mouse_heading() -> void:
	var rig := _rig()
	var target: Node3D = rig[0]
	var camera: Camera3D = rig[1]
	camera.toggle_view()
	var heading := Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
	for tick in 60:
		target.position.x += 1.0/6.0
		camera._physics_process(1.0/60)
	assert_almost_eq(Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized(),heading,Vector2.ONE*.001,"Mouse heading survives strafing")

func test_tactical_heading_matches_original_close_follow_at_multiple_tick_rates() -> void:
	var original_script := preload("res://scripts/camera/legacy_camera_view.gd")
	for rate in [30,60,120]:
		var rig := _rig()
		var target: Node3D = rig[0]
		var camera: Camera3D = rig[1]
		var original_camera := Camera3D.new()
		target.get_parent().add_child(original_camera)
		original_camera.position = Vector3(0,5,8)
		var original := original_script.new()
		original.camera = original_camera
		original.target = target
		original.collision_enabled = false
		target.get_parent().add_child(original)
		camera._physics_process(0.0)
		original.update_view(0.0)
		var maximum_error := 0.0
		for tick in rate*3:
			target.position += Vector3(8,0,-4)/rate
			camera._physics_process(1.0/rate)
			original.update_view(1.0/rate)
			var offset := original_camera.position-target.position
			maximum_error = maxf(maximum_error,absf(wrapf(camera._yaw-atan2(offset.x,offset.z),-PI,PI)))
		assert_lt(maximum_error,.0001,"Original angular response retained at %d Hz" % rate)

func test_close_pitch_limits_and_above_horizon_facing_remain_finite() -> void:
	var rig := _rig()
	var camera: Camera3D = rig[1]
	camera.toggle_view()
	for pitch in [deg_to_rad(-60),deg_to_rad(75)]:
		camera._pitch = pitch
		camera._yaw = 1.2
		camera._physics_process(0.0)
		var aim: Vector2 = camera.facing_direction(rig[0].global_position)
		assert_almost_eq(aim,Vector2(-sin(1.2),-cos(1.2)),Vector2.ONE*.0001)
		assert_true(camera.global_transform.is_finite())

func test_heading_survives_switches_and_focus_pause_release() -> void:
	var rig := _rig()
	var camera: Camera3D = rig[1]
	if DisplayServer.get_name() != "headless":
		get_window().grab_focus()
		await get_tree().process_frame
		await get_tree().process_frame
	camera._yaw = 1.1
	camera._physics_process(0.0)
	for notification in [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,Node.NOTIFICATION_PAUSED]:
		camera.toggle_view()
		assert_almost_eq(camera._yaw,1.1,.0001,"F7 preserves chosen heading")
		assert_true(camera._crosshair.visible)
		camera._notification(notification)
		assert_false(camera._look_captured)
		assert_eq(Input.mouse_mode,Input.MOUSE_MODE_VISIBLE)
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = camera.pointing_position()
		camera.get_viewport().push_input(click,true)
		assert_true(camera._look_captured,"Game click reacquires released look")
		camera.toggle_view()
		assert_false(camera._crosshair.visible)
		assert_false(camera._look_captured)
		assert_almost_eq(camera._yaw,1.1,.0001)

func test_mouse_boom_resolves_walls_and_ground_in_four_orientations() -> void:
	var rig := _rig()
	var camera: Camera3D = rig[1]
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20,20,.5)
	collision.shape = shape
	wall.add_child(collision)
	rig[0].get_parent().add_child(wall)
	camera.toggle_view()
	for yaw in [0.0,PI/2,PI,-PI/2]:
		wall.position = Vector3(sin(yaw)*3,0,cos(yaw)*3)
		wall.rotation.y = yaw
		await get_tree().physics_frame
		await get_tree().physics_frame
		camera._yaw = yaw
		camera._pitch = .4
		camera._close.reset()
		camera._physics_process(0.0)
		assert_lt(Vector2(camera.position.x,camera.position.z).length(),2.5,"Camera sphere stays ahead of wall")
		assert_almost_eq(Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized(),Vector2(sin(yaw),cos(yaw)),Vector2.ONE*.0001)
	wall.rotation = Vector3.ZERO
	wall.position = Vector3(0,-.25,0)
	shape.size = Vector3(50,.5,50)
	await get_tree().physics_frame
	await get_tree().physics_frame
	camera._pitch = deg_to_rad(-60)
	camera._close.reset()
	camera._physics_process(0.0)
	assert_gt(camera.position.y,.29,"Looking upward cannot push camera through ground")

func test_reset_uses_explicitly_relocated_eye() -> void:
	var rig := _rig()
	var camera: Camera3D = rig[1]
	camera.position = rig[0].position+Vector3(26,16,0)
	camera.reset_orbit()
	camera._physics_process(0.0)
	assert_almost_eq(camera._yaw,PI/2,.0001)
	assert_almost_eq(camera.position,rig[0].position+Vector3(26,16,0),Vector3.ONE*.001)

func test_close_crosshair_clears_avatar_hat_in_initial_framing() -> void:
	var rig := _rig()
	var camera: Camera3D = rig[1]
	camera.toggle_view()
	var hat_top := camera.unproject_position(rig[0].position+Vector3.UP*2.8)
	assert_gt(hat_top.y,camera.pointing_position().y+10.0,"Center reticle clears the mage hat")
	assert_almost_eq(camera.position,rig[0].position+Vector3(0,5,8),Vector3.ONE*.001,"Initial eye stays at the original close distance")

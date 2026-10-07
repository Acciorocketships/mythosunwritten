extends GutTest
const CameraScript = preload("res://scripts/camera/camera.gd")

func test_native_capture_begins_in_the_free_centre_before_any_edge_can_lose_focus() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var target := Node3D.new()
	world.add_child(target)
	var camera := Camera3D.new()
	camera.set_script(CameraScript)
	camera.target = target
	camera.visibility_bubble_enabled = false
	world.add_child(camera)
	camera.make_current()
	camera.set_physics_process(false)
	if DisplayServer.get_name() != "headless":
		get_window().grab_focus()
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(get_window().has_focus(), "Native acquisition requires a focused game window")
	_motion(camera, camera.get_viewport().get_visible_rect().size / 2, Vector2(2,0))
	assert_true(camera._edge_captured, "Acquire raw input before native side exits can steal keyboard focus")
	assert_true(camera._edge_cursor.visible, "The visible virtual pointer must be present in the centre")
	assert_eq(camera._mouse_orbit, 0.0, "Centre motion does not rotate")
	camera._release_edge()

func test_player_input_preserves_original_speed_independent_of_facing() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	var actor := (load("res://characters/character.tscn") as PackedScene).instantiate() as CharacterBody3D
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.controller = PlayerController.new()
	for yaw in [0.0, PI / 2, PI]:
		camera.rotation = Vector3(-0.52, yaw, 0)
		actor.rotation.y = yaw + PI / 2
		for actions in [["forward"], ["backward"], ["left"], ["right"], ["forward", "right"]]:
			for action in actions: Input.action_press(action)
			assert_almost_eq(actor.controller.get_move_vector(actor, 1.0 / 60).length(), 1.0, 0.0001)
			assert_almost_eq(actor.streaming_velocity().length(), 10.0, 0.001,
				"Player speed and streaming intent retain the original 10 m/s cap")
			for action in actions: Input.action_release(action)

func test_drag_starts_only_beyond_the_actual_edge_and_counts_overflow() -> void:
	assert_eq(CameraScript.edge_drag(850, 100, 1000), 0.0, "The former outer zone is ordinary pointer space")
	assert_eq(CameraScript.edge_drag(950, 49, 1000), 0.0, "Reaching the last pixel alone does not rotate")
	assert_eq(CameraScript.edge_drag(950, 89, 1000), 40.0)
	assert_eq(CameraScript.edge_drag(999, 40, 1000), 40.0, "A clamped cursor still has outward motion")
	assert_eq(CameraScript.edge_drag(10, -50, 1000), -40.0)
	assert_eq(CameraScript.edge_drag(0, -40, 1000), -40.0)
	assert_eq(CameraScript.edge_drag(999, 0, 1000), 0.0, "Dwelling never rotates")
	assert_eq(CameraScript.edge_drag(999, -400, 1000), 0.0, "Returning inward does not undo rotation")
	assert_eq(CameraScript.edge_drag(0, 400, 1000), 0.0)
	assert_eq(CameraScript.edge_drag(950, 149, 1000),
		CameraScript.edge_drag(950, 79, 1000) + CameraScript.edge_drag(999, 70, 1000))

func test_drag_gain_tracks_field_of_view_and_viewport_scaling() -> void:
	var size := Vector2(1280,800)
	var gain := CameraScript.drag_radians_per_pixel(size, 50)
	assert_almost_eq(rad_to_deg(gain * size.x), 73.44, 0.1)
	assert_lt(rad_to_deg(gain * 100), 6.0, "100 pixels no longer turns 34 degrees")
	assert_almost_eq(gain * 100, CameraScript.drag_radians_per_pixel(size * 2, 50) * 200, 0.00001)
	assert_almost_eq(CameraScript.drag_radians_per_pixel(size, 75, true) * size.x, deg_to_rad(75), 0.00001)

func _motion(camera: Camera3D, position: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	camera.get_viewport().push_input(event, true)

func test_virtual_cursor_keeps_raw_input_across_edges_inward_motion_and_clicks() -> void:
	var viewport
	if DisplayServer.get_name() == "headless":
		viewport = SubViewport.new()
	else:
		viewport = Window.new()
		viewport.hide()
		viewport.force_native = true
	viewport.size = Vector2i(1920,1080)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	if viewport is Window: viewport.show()
	var target := Node3D.new()
	viewport.add_child(target)
	var camera := Camera3D.new()
	camera.set_script(CameraScript)
	camera.target = target
	camera.visibility_bubble_enabled = false
	viewport.add_child(camera)
	camera.make_current()
	camera.set_physics_process(false)
	if viewport is Window: viewport.grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	var size: Vector2 = viewport.get_visible_rect().size
	var centre := size / 2
	var edge := Vector2(size.x-camera._pointer_pixel_size().x, centre.y)
	Input.action_press("forward")
	_motion(camera, centre, Vector2(2,0))
	assert_true(camera._edge_captured)
	assert_true(camera._edge_cursor.visible)
	if DisplayServer.get_name() != "headless": assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED)
	_motion(camera, centre, edge-centre)
	assert_eq(camera.pointing_position(), edge)
	assert_eq(camera._mouse_orbit, 0.0, "Reaching the final pixel alone does not turn")
	_motion(camera, centre, Vector2(100,0))
	var expected: float = -100 * CameraScript.drag_radians_per_pixel(size,50) * camera.mouse_sensitivity
	assert_almost_eq(camera._mouse_orbit,expected,0.00001)
	_motion(camera, centre, Vector2(-400,0))
	assert_true(camera._edge_captured, "Returning inward must not change native mode or keyboard focus")
	assert_almost_eq(camera._mouse_orbit,expected,0.00001)
	assert_true(Input.is_action_pressed("forward"))
	camera._process(0.0)
	assert_almost_eq(camera._yaw,expected,0.00001)
	assert_gt((-camera.global_basis.z).x,0.0)
	var pointer: Vector2 = camera.pointing_position()
	var button := Button.new()
	button.position = pointer-Vector2(20,20)
	button.size = Vector2(40,40)
	viewport.add_child(button)
	await get_tree().process_frame
	var clicks := [0]
	button.pressed.connect(func(): clicks[0] += 1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = centre
	viewport.push_input(click,true)
	click = click.duplicate()
	click.position = pointer
	click.pressed = false
	viewport.push_input(click,true)
	assert_eq(clicks[0],1,"Clicks address the drawn pointer, not the native capture centre")
	assert_false(camera._edge_captured)
	button.free()
	_motion(camera,pointer,Vector2(2,0))
	assert_true(camera._edge_captured)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	viewport.push_input(escape,true)
	assert_false(camera._edge_captured)
	assert_false(camera._edge_cursor.visible)
	assert_eq(Input.mouse_mode,Input.MOUSE_MODE_VISIBLE)
	_motion(camera,centre,Vector2(20,0))
	assert_false(camera._edge_captured,"Escape releases until a game click")
	click.pressed = true
	viewport.push_input(click,true)
	click = click.duplicate()
	click.pressed = false
	viewport.push_input(click,true)
	_motion(camera,centre,Vector2(20,0))
	assert_true(camera._edge_captured)
	camera.toggle_view()
	assert_false(camera._edge_captured)
	camera.toggle_view()
	_motion(camera,centre,Vector2(20,0))
	assert_true(camera._edge_captured)
	camera._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_false(camera._edge_captured)
	assert_eq(Input.mouse_mode,Input.MOUSE_MODE_VISIBLE)
	Input.action_release("forward")
	assert_false(Input.is_action_pressed("forward"))

func test_camera_relative_wasd_and_diagonal_speed_in_every_quadrant() -> void:
	for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.8)
		var move := PlayerController.camera_relative(Vector2.UP, basis)
		var expected := -basis.z
		expected.y = 0
		expected = expected.normalized()
		assert_almost_eq(move, Vector2(expected.x, expected.z), Vector2.ONE * 0.0001)
		assert_almost_eq(PlayerController.camera_relative(Vector2(1,-1).normalized(), basis).length(), 1.0, 0.0001)

func test_facing_is_independent_of_travel_and_uses_global_camera_transform() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	world.position = Vector3(30,10,-20)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(4,16,14)
	var feet := world.global_position
	camera.look_at(feet)
	for offset in [Vector3(3,0,0), Vector3(-3,0,0), Vector3(0,0,3), Vector3(0,0,-3)]:
		var cursor := camera.unproject_position(feet + offset)
		assert_almost_eq(PlayerController.cursor_direction(camera, cursor, feet),
			Vector2(offset.x, offset.z).normalized(), Vector2.ONE * 0.001)

func test_directional_blend_addresses_model_right_and_adjacent_diagonals() -> void:
	assert_eq(DirectionalLocomotion.blend_direction(Vector3(0,0,10), Basis.IDENTITY), Vector2.UP)
	assert_eq(DirectionalLocomotion.blend_direction(Vector3(0,0,-10), Basis.IDENTITY), Vector2.DOWN)
	assert_eq(DirectionalLocomotion.blend_direction(Vector3(-10,0,0), Basis.IDENTITY), Vector2.RIGHT)
	assert_eq(DirectionalLocomotion.blend_direction(Vector3(10,0,0), Basis.IDENTITY), Vector2.LEFT)
	var diagonal := DirectionalLocomotion.blend_direction(Vector3(-10,0,10), Basis.IDENTITY)
	assert_gt(diagonal.x, 0.0)
	assert_lt(diagonal.y, 0.0)
	assert_almost_eq(absf(diagonal.x) + absf(diagonal.y), 1.0, 0.0001)

class AimController extends CharacterController:
	var movement := Vector2.ZERO
	var facing := Vector2.RIGHT
	func get_move_vector(_c: CharacterBody3D, _dt: float) -> Vector2: return movement
	func get_facing_vector(_c: CharacterBody3D, _dt: float) -> Vector2: return facing

func test_character_faces_aim_while_standing_and_strafes_without_changing_travel() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40,1,40)
	collision.shape = shape
	collision.position.y = -0.5
	floor.add_child(collision)
	world.add_child(floor)
	var actor := (load("res://characters/character.tscn") as PackedScene).instantiate() as CharacterBody3D
	var controller := AimController.new()
	actor.controller = controller
	world.add_child(actor)
	actor.set_physics_process(false)
	for tick in 45:
		await get_tree().physics_frame
		actor._physics_process(1.0/60)
	assert_almost_eq(actor.global_rotation.y, PI/2, 0.001, "Aim turns the stationary character")
	controller.movement = Vector2.DOWN
	for tick in 45:
		await get_tree().physics_frame
		actor._physics_process(1.0/60)
	assert_gt(actor.global_position.z, 5.0)
	assert_lt(absf(actor.global_position.x), 0.01, "Facing must not steer the travel vector")
	assert_almost_eq(actor.global_rotation.y, PI/2, 0.001)
	assert_almost_eq(actor.anim_tree.get("parameters/BlendTree/Direction/blend_position"), Vector2.RIGHT, Vector2.ONE*0.001)

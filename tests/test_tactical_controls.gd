extends GutTest
const CameraScript = preload("res://scripts/camera/camera.gd")

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

func test_drag_reserves_centre_and_is_proportional_to_motion() -> void:
	assert_eq(CameraScript.edge_drag(400, 600, 1000, 0.6), 0.0)
	assert_eq(CameraScript.edge_drag(850, 890, 1000, 0.6), 40.0)
	assert_eq(CameraScript.edge_drag(190, 100, 1000, 0.6), -90.0)
	assert_eq(CameraScript.edge_drag(780, 850, 1000, 0.6), 50.0)
	assert_eq(CameraScript.edge_drag(900, 900, 1000, 0.6), 0.0)
	assert_eq(CameraScript.edge_drag(900, 500, 1000, 0.6), 0.0, "Returning to clicks preserves the chosen view")
	assert_eq(CameraScript.edge_drag(100, 500, 1000, 0.6), 0.0)
	assert_eq(CameraScript.edge_drag(500,900,1000,0.6) + CameraScript.edge_drag(900,500,1000,0.6)
		+ CameraScript.edge_drag(500,900,1000,0.6), 200.0, "Repeated gestures can orbit indefinitely")
	assert_eq(CameraScript.edge_drag(780, 850, 1000, 0.6),
		CameraScript.edge_drag(780, 810, 1000, 0.6) + CameraScript.edge_drag(810, 850, 1000, 0.6))

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
	assert_almost_eq(diagonal.x * DirectionalLocomotion.STRAFE_STRIDE,
		-diagonal.y * DirectionalLocomotion.RUN_STRIDE, 0.0001,
		"The blended planted-foot displacement follows the requested diagonal")
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

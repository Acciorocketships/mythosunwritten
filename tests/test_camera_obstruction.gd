extends GutTest

func test_f7_switches_original_and_wider_tactical_views_without_key_repeat() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var target := Node3D.new()
	world.add_child(target)
	var camera := Camera3D.new()
	camera.set_script(load("res://scripts/camera/camera.gd"))
	camera.target = target
	camera.visibility_bubble_enabled = false
	camera.position = Vector3(0, 5, 8)
	world.add_child(camera)
	camera.make_current()
	camera.set_physics_process(false)
	assert_almost_eq(camera.position, Vector3(0,16,26), Vector3.ONE * 0.001)
	assert_almost_eq(rad_to_deg(-camera.rotation.x), 30.0, 0.1)
	var key := InputEventKey.new()
	key.keycode = KEY_F7
	key.pressed = true
	key.echo = true
	camera._unhandled_input(key)
	assert_true(camera.tactical_view)
	key.echo = false
	camera._unhandled_input(key)
	assert_false(camera.tactical_view)
	assert_eq(camera.fov, 75.0)
	assert_almost_eq(camera.position, Vector3(0,5,8), Vector3.ONE * 0.001)
	# The old camera still resolves its boom against real collision.
	_box(world, Vector3(0,5,4), Vector3(6,6,0.5))
	await get_tree().physics_frame
	camera._process(1.0 / 60)
	assert_lt(camera.position.z, 3.5)
	camera._unhandled_input(key)
	assert_true(camera.tactical_view)
	assert_eq(camera.fov, 50.0)
	assert_almost_eq(camera.position, Vector3(0,16,26), Vector3.ONE * 0.001)

func _box(parent: Node3D, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	node.shape = shape
	body.add_child(node)
	parent.add_child(body)
	return body

func test_unobstructed_boom_reaches_the_requested_pose() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	await get_tree().physics_frame
	var solver := CameraObstructionSolver.new()
	var pivot := Vector3(0.0, 2.0, 0.0)
	var desired := Vector3(0.0, 2.0, 8.0)
	assert_eq(solver.resolve_boom(world.get_world_3d().direct_space_state,
		pivot, desired), desired)

func test_swept_sphere_stops_the_boom_before_a_wall() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	_box(world, Vector3(0.0, 2.0, 4.0), Vector3(6.0, 4.0, 0.5))
	await get_tree().physics_frame
	var solver := CameraObstructionSolver.new(0.3, 1, 0.02, 0.05)
	var resolved := solver.resolve_boom(
		world.get_world_3d().direct_space_state,
		Vector3(0.0, 2.0, 0.0), Vector3(0.0, 2.0, 8.0))
	assert_lt(resolved.z, 3.5,
		"the camera sphere remains in front of the wall and its safety skin")
	assert_gt(resolved.z, 3.1,
		"the boom shortens only as much as the obstruction requires")

func test_ceiling_probe_lowers_the_pivot_but_preserves_head_level() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	_box(world, Vector3(0.0, 3.0, 0.0), Vector3(6.0, 0.5, 6.0))
	await get_tree().physics_frame
	var solver := CameraObstructionSolver.new(0.3, 1, 0.02, 0.05)
	var resolved := solver.resolve_ceiling(
		world.get_world_3d().direct_space_state, Vector3.ZERO, 1.35, 5.0)
	assert_gt(resolved.y, 2.25)
	assert_lt(resolved.y, 2.45,
		"the pivot sits below the ceiling by sphere radius, margin, and skin")

func test_excluded_body_cannot_collapse_its_own_camera_boom() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var body := _box(world, Vector3(0.0, 2.0, 2.0), Vector3(1.0, 3.0, 1.0))
	await get_tree().physics_frame
	var desired := Vector3(0.0, 2.0, 5.0)
	var excluded: Array[RID] = [body.get_rid()]
	assert_eq(CameraObstructionSolver.new().resolve_boom(
		world.get_world_3d().direct_space_state,
		Vector3(0.0, 2.0, 0.0), desired, excluded), desired)

func test_world_camera_uses_visibility_bubble_without_collapsing_tactical_orbit() -> void:
	var world := load("res://scenes/world.tscn").instantiate() as Node3D
	var camera := world.get_node("Camera3D") as Camera3D
	assert_true(bool(camera.get("visibility_bubble_enabled")))
	assert_gte(float(camera.get("height")), 14.0)
	assert_gte(float(camera.get("distance")), 12.0)
	world.free()

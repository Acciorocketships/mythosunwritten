extends GutTest

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

func test_world_camera_enables_the_general_collision_contract() -> void:
	var world := load("res://scenes/world.tscn").instantiate() as Node3D
	var camera := world.get_node("Camera3D") as Camera3D
	assert_true(bool(camera.get("collision_enabled")))
	assert_eq(int(camera.get("collision_mask")), 1)
	assert_lt(float(camera.get("minimum_pivot_height")),
		TraversalEnvelope.MIN_HEADROOM)
	world.free()

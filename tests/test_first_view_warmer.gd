extends GutTest
const WARMER := preload("res://scripts/terrain/field/FirstViewWarmer.gd")

func test_stationary_pose_finishes_and_new_geometry_invalidates_it() -> void:
	var warmer := WARMER.new()
	assert_false(warmer._next_orbit_due(Vector3.ZERO,499))
	for now in [500,1000,1500]: assert_true(warmer._next_orbit_due(Vector3.ZERO,now))
	assert_false(warmer._next_orbit_due(Vector3.ZERO,2000))
	assert_false(warmer._next_orbit_due(Vector3.ZERO,120000),"elapsed time alone does not require rendering the same world again")
	warmer.warm(Vector3(192,0,0))
	assert_eq(warmer.pending(),1)
	assert_true(warmer._next_orbit_due(Vector3.ZERO,120000),"new chunk geometry refreshes the player's unseen headings")
	warmer.free()

func test_motion_refreshes_views_without_camera_bob_triggering_them() -> void:
	var warmer := WARMER.new()
	for now in [500,1000,1500]: warmer._next_orbit_due(Vector3.ZERO,now)
	assert_false(warmer._next_orbit_due(Vector3(.2,.1,.2),2000))
	assert_true(warmer._next_orbit_due(Vector3(8,0,0),2000))
	assert_false(warmer._next_orbit_due(Vector3(16,0,0),2100),"motion does not bypass the interval cap")
	assert_true(warmer._next_orbit_due(Vector3(16,0,0),2500))
	assert_true(warmer._next_orbit_due(Vector3(16,0,0),3000))
	assert_true(warmer._next_orbit_due(Vector3(16,0,0),3500))
	assert_false(warmer._next_orbit_due(Vector3(16,0,0),4000))
	warmer.free()

func test_slices_cover_the_original_perspective_without_gaps() -> void:
	var full := SubViewport.new()
	full.size = WARMER.SIZE
	add_child_autofree(full)
	var reference := Camera3D.new()
	reference.fov = WARMER.FOV
	full.add_child(reference)
	var part := SubViewport.new()
	part.size = WARMER.SIZE / WARMER.SLICE_GRID
	add_child_autofree(part)
	var camera := Camera3D.new()
	part.add_child(camera)
	await get_tree().process_frame
	for index in 4:
		WARMER.configure_slice(camera, WARMER.FOV, index)
		# Frustum offsets use up-positive coordinates; screen pixels use down.
		var tile := Vector2(index % WARMER.SLICE_GRID.x, WARMER.SLICE_GRID.y - 1 - index / WARMER.SLICE_GRID.x)
		for corner: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.ONE,Vector2(.5,.5)]:
			var point := reference.project_position((tile + corner) * Vector2(part.size),5.0)
			var projected := camera.unproject_position(point)
			assert_lt(projected.distance_to(corner * Vector2(part.size)),0.0001,"slice %d point %s" % [index,corner])

func test_each_queued_view_finishes_before_the_next_pose_starts() -> void:
	var warmer := WARMER.new()
	add_child_autofree(warmer)
	warmer.setup(get_viewport().world_3d,Viewport.MSAA_DISABLED)
	warmer.set_process(false)
	warmer.warm(Vector3(192,0,0))
	warmer._process(0.0)
	var first_pose: Transform3D = warmer._camera.global_transform
	warmer.warm(Vector3(384,40,0))
	for i in 3:
		assert_eq(warmer.warmed,0)
		warmer._process(0.0)
		assert_eq(warmer._camera.global_transform,first_pose,"a queued view cannot interrupt the active one")
	assert_eq(warmer.warmed,1)
	assert_eq(warmer.pending(),1)
	warmer._process(0.0)
	assert_ne(warmer._camera.global_transform,first_pose)
	for i in 3: warmer._process(0.0)
	assert_eq(warmer.warmed,2)
	assert_eq(warmer.rendered_slices,8)
	assert_eq(warmer.pending(),0)

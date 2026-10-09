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

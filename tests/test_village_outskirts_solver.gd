extends GutTest

## The outskirts solver was deleted October 7; these two checks cover the live
## street fillet and warren contact geometry its world-road connection uses.


func test_house_street_bend_matches_the_main_road_fillet() -> void:
	var shapes := PathProgram.filleted_path_shapes(
		[Vector2(12, 0), Vector2.ZERO, Vector2(0, 12)] as Array[Vector2],
		PathProgram.PATH_HALF_WIDTH, FeatureGroundField.WORN_PATH, 100,
		&"test.fillet")
	var house_path := FeatureGroundField.new(shapes, [], 0.0)
	var main_path := FeatureGroundField.new([], [], 0.0, {Vector2i.ZERO: 5})
	var mismatch := 0
	# Avoid the analytic boundary itself; the arc tessellation has a <1 cm error.
	for z in range(-7, 32):
		for x in range(-7, 32):
			var point := Vector2(x * 0.25 + 0.03, z * 0.25 + 0.03)
			if house_path.surface_at(point) != main_path.surface_at(point):
				mismatch += 1
	assert_eq(mismatch, 0,
		"house streets and world roads must share the same constant-width rounded bend")


func test_warren_contact_geometry_uses_the_public_cell_centre_phase() -> void:
	var spec := {
		"cells": [Vector3i(0, 0, 0), Vector3i(0, 0, 1)] as Array[Vector3i],
		"outward": Vector3i.LEFT,
		"lateral": Vector3i.BACK,
	}
	var contact := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
	assert_eq(contact.street_centre, Vector3(0.0, 0.0, 0.75),
		"adjacent public cells are centre-indexed, not corner-indexed")
	assert_eq(contact.inner_centre, Vector3(-0.75, 0.0, 0.75),
		"the handoff begins exactly on the finished street edge")
	assert_eq(contact.outer_centre, Vector3(-2.25, 0.0, 0.75),
		"the outskirts road starts at the terrain side of that same ramp")
	assert_almost_eq(float(contact.half_width), 1.5, 0.0001)


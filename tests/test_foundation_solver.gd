extends GutTest

class WetWater extends WaterFieldContext:
	func is_wet(_point: Vector2) -> bool:
		return true

func _flat_region(height: float = 0.0) -> HeightfieldRegion:
	var plan := HeightfieldPlan.new(81, 1.0, 1, "mean")
	plan.set_raw_height_override(func(_x: int, _z: int) -> float: return height)
	return plan.compute_region(0, 0, 8)

func _request(max_depth: float = 4.0,
		door_outside: Vector2 = Vector2(0.0, -6.0),
		half_extent: float = 3.0) -> FoundationRequest:
	return FoundationRequest.new(&"village.test.house", Vector2.ZERO,
		Vector2.ONE * half_extent, 0.0, Vector2.ZERO,
		Vector2.ONE * half_extent, 0.0, Vector2(0.0, -half_extent),
		door_outside,
		max_depth, &"foundation.rock.1m", 1.5, 0.6, 1.0, 1.0, 0.05)

func test_flat_legal_threshold_needs_no_decorative_foundation_ring() -> void:
	var region := _flat_region()
	var plan := FoundationSolver.solve(_request(), region)
	assert_true(plan.accepted)
	assert_gt(float(plan.floor_y), float(plan.terrain_bounds.y))
	for z_index in 25:
		for x_index in 25:
			var point := Vector2(-3.0 + 6.0 * float(x_index) / 24.0,
				-3.0 + 6.0 * float(z_index) / 24.0)
			assert_lt(TerrainSurfaceField.surface_y(region, point.x, point.y),
				float(plan.floor_y))
	assert_true(plan.foundation_pieces.is_empty(),
		"a legal natural threshold must not expose a mostly-buried wall outline")
	assert_eq(plan.connector.kind, &"threshold")

func test_visible_drop_uses_fixed_modules_and_preserves_the_doorway_bay() -> void:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-5, 6):
		for x in range(-5, 6):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 1 if z >= 0 else 0
	var region := HeightfieldRegion.new(storeys, levels)
	var plan := FoundationSolver.solve(
		_request(4.0, Vector2(0.0, -18.0), 12.0), region)
	assert_true(plan.accepted)
	assert_gt(plan.foundation_pieces.size(), 0)
	var top_contacts := 0
	for piece: Dictionary in plan.foundation_pieces:
		assert_eq((piece.transform as Transform3D).basis.get_scale(), Vector3.ONE,
			"collision-bearing foundations are never non-uniformly scaled")
		var top_y := (piece.transform as Transform3D).origin.y + 1.0
		assert_lte(top_y, float(plan.floor_y) + 0.0001)
		if is_equal_approx(top_y, float(plan.floor_y)):
			top_contacts += 1
		assert_lte(maxf(absf((piece.transform as Transform3D).origin.x),
			absf((piece.transform as Transform3D).origin.z)), 11.7001,
			"the module outside face, not its centreline, owns the perimeter")
	assert_gt(top_contacts, 0,
		"each emitted stack makes exact contact with the finished floor")
	assert_eq(plan.connector.kind, &"stairs")

func test_relief_uses_a_bounded_fixed_stack_and_legal_stairs() -> void:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-5, 6):
		for x in range(-5, 6):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 1 if z >= 0 else 0
	var region := HeightfieldRegion.new(storeys, levels)
	var plan := FoundationSolver.solve(
		_request(4.0, Vector2(0.0, -18.0), 12.0), region)
	assert_true(plan.accepted)
	assert_gt(plan.foundation_pieces.size(), 0)
	assert_eq(plan.connector.kind, &"stairs")
	assert_lte(float(plan.connector.max_step),
		TraversalEnvelope.MAX_PLANNED_STEP)
	assert_gt(plan.connector.contacts.size(), 2)

func test_depth_water_and_module_grid_fail_with_no_partial_plan() -> void:
	var region := _flat_region()
	var shallow := FoundationSolver.solve(_request(0.01), region)
	assert_false(shallow.accepted)
	assert_eq(shallow.reason, &"foundation_depth")
	assert_true(shallow.foundation_pieces.is_empty())
	var wet := FoundationSolver.solve(_request(), region, WetWater.new())
	assert_false(wet.accepted)
	assert_eq(wet.reason, &"water")
	var off_grid := FoundationRequest.new(&"village.test.off_grid", Vector2.ZERO,
		Vector2(2.8, 3.0), 0.0, Vector2.ZERO, Vector2(2.8, 3.0), 0.0,
		Vector2(0.0, -3.0), Vector2(0.0, -6.0),
		4.0, &"foundation.rock.1m", 1.5, 0.6, 1.0)
	var rejected := FoundationSolver.solve(off_grid, region)
	assert_false(rejected.accepted)
	assert_eq(rejected.reason, &"module_grid")

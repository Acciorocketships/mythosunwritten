extends GutTest

func test_finished_turf_cannot_follow_an_unexposed_structural_block() -> void:
	# September 5 D2: the next column is lower retained structure, not a
	# selected ground owner. It must not supply a one-band slope control.
	var capped := {Vector3i(2,3,-9):true, Vector3i(3,3,-9):true,
		Vector3i(2,3,-10):true, Vector3i(3,3,-10):true}
	var level_planks := {Vector3i(3,4,-8):true}
	var region := SettlementFabricAssembler.maze_terrain_surface_region(capped, level_planks)
	assert_eq(region.storey_at(2,-8), 2, "unowned columns are exterior, not hidden masonry tops")
	for z in range(21):
		for x in range(21):
			var height := TerrainSurfaceField.surface_y(region,
				3.0 + float(x)/20.0*0.75, -13.5 + float(z)/20.0*0.75)
			assert_almost_eq(height, 6.0, 0.0001,
				"the finished lawn remains above its level substrate throughout the corner")

func test_two_real_turf_levels_still_use_the_shared_slope() -> void:
	var capped: Dictionary = {}
	for z in range(-1,2):
		for x in range(-1,3):
			capped[Vector3i(x,3 if x <= 0 else 2,z)] = true
	var region := SettlementFabricAssembler.maze_terrain_surface_region(capped)
	assert_eq(region.storey_at(0,0), 4)
	assert_eq(region.storey_at(1,0), 3)
	assert_lt(TerrainSurfaceField.surface_y(region,0.6,0), 6.0)

func test_straight_and_corner_lips_use_the_same_uniform_scale() -> void:
	var edge := SettlementFabricAssembler._maze_green_rim_transform(
		Vector3i.ZERO, Vector3i.BACK, 0.5, 0.0)
	var corner := SettlementFabricAssembler._maze_green_rim_corner_transform(
		Vector3i.ZERO, Vector2i.ONE)
	assert_eq(edge.basis.get_scale(), corner.basis.get_scale(),
		"straight grass rolls cannot be twice as tall as their corner pieces")
	assert_eq(edge.origin.y, corner.origin.y)

func test_planned_lawn_does_not_invent_equal_height_neighbours() -> void:
	var plan := SettlementFabricPlan.new(&"turf-test")
	plan.planned_plaza_cells[Vector3i.ZERO] = true
	var controls := SettlementFabricAssembler.maze_terrain_control_surface_cells(plan)
	assert_false(controls.has(Vector3i(1, 1, 0)),
		"a phantom control ring suppresses the lawn's actual cliff lips")

func test_turf_retaining_corner_uses_the_matching_terrain_wall() -> void:
	var east := SettlementFabricAssembler.STONE_FACE_DIRECTIONS.find(Vector3i.RIGHT)
	var south := SettlementFabricAssembler.STONE_FACE_DIRECTIONS.find(Vector3i.BACK)
	var faces := {Vector4i(0, 0, 0, east): Vector3i.ZERO,
		Vector4i(0, 0, 0, south): Vector3i.ZERO}
	var treatments: Dictionary = {}
	for face in faces:
		treatments[face] = SettlementFabricAssembler.SkinTreatment.MASONRY
	var payload := SettlementFabricAssembler.maze_stone_walls({}, {}, {}, {}, {},
		{"faces": faces, "treatments": treatments, "exposed": faces}, 0,
		{Vector3i.ZERO: true})
	assert_true(payload.batches.has(&"kaykit.cliff.outer_wall"),
		"a turf turn needs the wall authored to meet the same rounded lip")
	assert_false(payload.batches.has(SettlementFabricAssembler.MAZE_STONE_MODULE),
		"the square masonry nose must not protrude through the rounded grass")
	assert_eq(payload.instance_count, 1, "one corner closes both faces without overlap")
	assert_eq(payload.collision_boxes.size(), 2,
		"visual-only terrain dressing still needs both logical retaining walls")
	for box: Dictionary in payload.collision_boxes:
		var bounds := AABB(-(box.size as Vector3) * 0.5, box.size as Vector3)
		bounds = (box.transform as Transform3D) * bounds
		assert_almost_eq(bounds.end.y, FabricRecipe.CELL_SIZE, 0.0001)
		assert_lte(bounds.end.x, FabricRecipe.CELL_SIZE * 0.5 + 0.0001)
		assert_lte(bounds.end.z, FabricRecipe.CELL_SIZE * 0.5 + 0.0001)

func test_suspended_plaza_is_a_connected_floor_not_hanging_stone() -> void:
	var plan := SettlementFabricPlan.new(&"suspended-green")
	var cell := Vector3i(0, 3, 0)
	plan.planned_plaza_cells[cell] = true
	plan.retained_terrace_cells[cell] = SettlementFabricAssembler.MAZE_STONE_TAG
	var suspended := SettlementFabricAssembler.suspended_plaza_cells(plan, {})
	assert_true(suspended.has(cell))
	plan.retained_terrace_cells[cell + Vector3i.DOWN] = \
		SettlementFabricAssembler.MAZE_STONE_TAG
	assert_false(SettlementFabricAssembler.suspended_plaza_cells(plan, {}).has(cell),
		"real grounded retaining courses must be preserved")

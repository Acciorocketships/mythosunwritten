extends GutTest

class WetWater extends WaterFieldContext:
	func is_wet(_point: Vector2) -> bool:
		return true

func _flat_region() -> HeightfieldRegion:
	var plan := HeightfieldPlan.new(82, 1.0, 1, "mean")
	plan.set_raw_height_override(func(_x: int, _z: int) -> float: return 0.0)
	return plan.compute_region(0, 0, 8)

func _modules() -> Array[SupportModule]:
	return [
		SupportModule.new(&"support.1m", 1.0, Vector2(0.4, 0.4)),
		SupportModule.new(&"support.1_5m", 1.5, Vector2(0.45, 0.45)),
	]

func test_fixed_stack_hits_deck_with_bounded_bottom_burial() -> void:
	var anchors: Array[Vector2] = [Vector2(-2.0, 0.0), Vector2(2.0, 0.0)]
	var request := SupportRequest.new(&"village.test.deck", anchors,
		3.7, 0.0, _modules(), 0.45, 0.1, 0.3)
	var result := SupportSolver.solve(request, _flat_region())
	assert_true(result.accepted)
	assert_eq(result.stacks.size(), 2)
	for stack: Dictionary in result.stacks:
		assert_almost_eq(float(stack.height), 4.0, 0.0001)
		assert_almost_eq(float(stack.burial), 0.3, 0.0001)
	for piece: Dictionary in result.pieces:
		assert_eq((piece.transform as Transform3D).basis.get_scale(), Vector3.ONE)

func test_stack_selection_is_deterministic_under_module_input_order() -> void:
	var anchors: Array[Vector2] = [Vector2.ZERO]
	var forward := _modules()
	var reverse := _modules()
	reverse.reverse()
	var a := SupportSolver.solve(SupportRequest.new(&"deck", anchors, 3.7,
		0.0, forward, 0.4, 0.1, 0.3), _flat_region())
	var b := SupportSolver.solve(SupportRequest.new(&"deck", anchors, 3.7,
		0.0, reverse, 0.4, 0.1, 0.3), _flat_region())
	var a_ids: Array = a.pieces.map(func(piece: Dictionary) -> String:
		return String(piece.asset_id))
	var b_ids: Array = b.pieces.map(func(piece: Dictionary) -> String:
		return String(piece.asset_id))
	assert_eq(a_ids, b_ids)

func test_no_stack_water_and_cliff_relief_reject_atomically() -> void:
	var anchors: Array[Vector2] = [Vector2.ZERO]
	var impossible_modules: Array[SupportModule] = [
		SupportModule.new(&"support.2m", 2.0, Vector2(0.4, 0.4)),
	]
	var impossible := SupportRequest.new(&"impossible", anchors, 3.7, 0.0,
		impossible_modules, 0.4, 0.1, 0.1)
	assert_eq(SupportSolver.solve(impossible, _flat_region()).reason,
		&"no_fixed_stack")
	var wet := SupportRequest.new(&"wet", anchors, 3.7, 0.0,
		_modules(), 0.4, 0.1, 0.3)
	assert_eq(SupportSolver.solve(wet, _flat_region(), WetWater.new()).reason,
		&"water")
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-3, 4):
		for x in range(-3, 4):
			# A one-storey seam is the ordinary rendered slope vocabulary. Use
			# a genuine cliff discontinuity so the narrow support stencil proves
			# the intended cross-face ground-span rejection.
			storeys[Vector2i(x, z)] = 2 if x <= 0 else 0
			levels[Vector2i(x, z)] = 0
	var cliff := HeightfieldRegion.new(storeys, levels)
	var cliff_anchors: Array[Vector2] = [Vector2(12.0, 0.0)]
	var cliff_request := SupportRequest.new(&"cliff", cliff_anchors, 12.0,
		0.0, _modules(), 1.0, 0.5, 0.3)
	assert_eq(SupportSolver.solve(cliff_request, cliff).reason, &"ground_span")

func test_occupancy_failure_leaves_the_whole_group_uncommitted() -> void:
	var occupancy := VillageOccupancy.new()
	assert_true(occupancy.add(VillageOccupancyVolume.new(
		VillageOccupancy.Role.HEADROOM, Vector2(2.0, 0.0), Vector2.ONE,
		0.0, 0.0, 3.0, &"protected.passage")))
	var anchors: Array[Vector2] = [Vector2(-2.0, 0.0), Vector2(2.0, 0.0)]
	var request := SupportRequest.new(&"occupied", anchors, 3.7, 0.0,
		_modules(), 0.4, 0.1, 0.3)
	var result := SupportSolver.solve(request, _flat_region(), null, occupancy)
	assert_false(result.accepted)
	assert_eq(result.reason, &"occupancy")
	assert_eq(occupancy.volumes().size(), 1,
		"the valid first support cannot leak out of a rejected atomic group")


func test_lowest_ground_reference_seals_a_sloped_stone_base() -> void:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-3, 4):
		for x in range(-3, 4):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 1 if x > 0 else 0
	var region := HeightfieldRegion.new(storeys, levels)
	var stone: Array[SupportModule] = [
		SupportModule.new(&"stone.3m", 3.0, Vector2(1.0, 0.5)),
	]
	var request := SupportRequest.new(&"sloped.stone", [Vector2.ZERO],
		4.0, 0.0, stone, 1.0, 1.5, 2.95, 3,
		SupportRequest.GroundReference.LOWEST)
	var result := SupportSolver.solve(request, region)
	assert_true(result.accepted)
	assert_lte(float(result.stacks[0].maximum_burial), 2.95)
	var piece: Dictionary = result.pieces[-1]
	var bottom_y := (piece.transform as Transform3D).origin.y \
		+ stone[0].local_bottom_y
	assert_lte(bottom_y, float(result.stacks[0].ground_bounds.x) + 0.001,
		"the fixed base reaches the low side instead of floating across it")

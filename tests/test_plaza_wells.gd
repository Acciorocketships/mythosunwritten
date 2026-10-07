extends GutTest
## Town taste knobs task 4: wells only on ground-level greens, and `well_scale`.

const WELL := &"sfv.well.001"

func _town(seed_value: int, scale: StringName, overrides: Dictionary) -> Dictionary:
	var profile := WarrenVillageScaleProfile.for_id(scale)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	program.town_odds = program.town_odds.with_overrides(overrides)
	var spatial := WarrenVolumetricSolver.generate(seed_value, {}, program, profile)
	assert_not_null(spatial)
	var fabric := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric, false)
	var centres: Array[Dictionary] = []
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		for index in (batch.ids as Array).size():
			var id := String(batch.ids[index])
			if not id.begins_with("maze-plaza-centre/"): continue
			var parts := id.split("/")
			centres.append({"asset": asset, "transform": batch.transforms[index],
				"cell": Vector3i(int(parts[1]), int(parts[2]), int(parts[3]))})
	return {"fabric": fabric, "centres": centres}

func _wells(town: Dictionary) -> Array[Dictionary]:
	return (town.centres as Array[Dictionary]).filter(func(c: Dictionary) -> bool:
		return c.asset == WELL)

func test_a_raised_green_never_gets_a_well() -> void:
	var town := _town(53, &"grand", {&"clearing_count": 3.0})
	var raised: Dictionary = (town.fabric as SettlementFabricPlan).raised_green_cells
	assert_false(raised.is_empty(), "53:grand has a raised green (clearing.00, floor 2)")
	for well: Dictionary in _wells(town):
		assert_false(raised.has(well.cell), "well at %s stands on a raised green" % [well.cell])

func _bed(n: int) -> Dictionary:
	var bed := {}
	for x in n:
		for z in n: bed[Vector3i(x, 0, z)] = true
	return bed

func _bounds() -> Dictionary:
	var catalog := EnvironmentCatalog.load_default()
	var bounds := {}
	for asset: StringName in SettlementFabricAssembler.PLAZA_WIDE_FEATURES + SettlementFabricAssembler.PLAZA_COURT_TREES:
		bounds[asset] = catalog.descriptor(asset).measured_aabb
	return bounds

func _centre(seed_value: int, on_ground: bool, well_scale: float) -> Dictionary:
	return SettlementFabricAssembler.maze_plaza_centre_feature(_bed(6), {},
		{"asset_bounds": _bounds()}, [] as Array[AABB], {}, false, seed_value, on_ground, well_scale)

func test_raised_green_falls_through_to_another_piece() -> void:
	var wells := 0
	for seed_value in range(1, 25):
		var ground := _centre(seed_value, true, 1.0)
		var raised := _centre(seed_value, false, 1.0)
		assert_ne(raised.get("asset", &""), WELL)
		if ground.get("asset", &"") == WELL:
			wells += 1
			assert_false(raised.is_empty(), "the next piece in the rotation stands instead")
		else:
			assert_eq(raised, ground, "a seed that never picked a well is unchanged")
	assert_gt(wells, 0, "some seed picks the well on the ground")

func test_well_scale_shrinks_the_well_and_stays_clear() -> void:
	var bounds := _bounds()
	var checked := 0
	for seed_value in range(1, 25):
		var full := _centre(seed_value, true, 1.0)
		if full.get("asset", &"") != WELL: continue
		var small := _centre(seed_value, true, 0.7)
		assert_eq(small.asset, WELL)
		assert_eq(small.cell, full.cell)
		var boxes := SettlementFabricAssembler.maze_plaza_feature_boxes(small, {"asset_bounds": bounds}, seed_value)
		var base := SettlementFabricAssembler.maze_plaza_feature_boxes(full, {"asset_bounds": bounds}, seed_value)
		assert_almost_eq(boxes[0].size.x / base[0].size.x, 0.7, 0.01)
		assert_almost_eq(boxes[0].size.y / base[0].size.y, 0.7, 0.01)
		assert_true(SettlementFabricAssembler._maze_plaza_feature_is_clear(small,
			{"asset_bounds": bounds}, [] as Array[AABB], seed_value))
		checked += 1
	assert_gt(checked, 0)

func test_default_well_scale_is_one() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"grand")
	assert_eq(TownCharacter.of(profile, 53).value(&"well_scale"), 1.0)

func test_sloped_ground_plaza_stays_eligible_and_a_plinth_is_raised() -> void:
	# Floor 3 over a hillside: 2 columns at 3, 4 at 2, 2 cut to 0 -- only the
	# two deepest cuts stand more than one band under the floor.
	assert_false(WarrenVolumetricSolver.green_is_raised(3, [3, 3, 2, 2, 2, 2, 0, 0] as Array[int]))
	assert_true(WarrenVolumetricSolver.green_is_raised(9, [0, 0, 0, 0, 0, 0, 0, 0, 0] as Array[int]))
	assert_true(WarrenVolumetricSolver.green_is_raised(2, [0, 0, 0, 0] as Array[int]))
	assert_false(WarrenVolumetricSolver.green_is_raised(2, [0, 0, 1, 1, 2, 2] as Array[int]), "exactly half is not more than half")

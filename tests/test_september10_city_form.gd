extends GutTest

func test_town_rims_step_down_to_one_storey_and_admit_open_ground_streets() -> void:
	for scale_id: StringName in WarrenVillageScaleProfile.IDS:
		for seed_value in range(1, 13):
			var mass := WarrenMassifBuilder.build(seed_value, {},
				WarrenVillageScaleProfile.for_id(scale_id))
			assert_not_null(mass)
			for column: Vector2i in mass.columns:
				var rim := false
				for direction: Vector2i in WarrenMassifBuilder.DIRECTIONS:
					rim = rim or not mass.has_column(column + direction)
				if not rim:
					continue
				assert_lte(mass.layer_at(column), WarrenBuildingParcel.STOREY_BANDS)
				var floor := Vector3i(column.x, mass.base_at(column), column.y)
				assert_true(WarrenPassageLatticeRules.slot_is_borable(mass,
					WarrenExcavation.new(seed_value), floor,
					WarrenPassageLatticeRules.HEADROOM_BANDS))
				assert_false(WarrenPassageLatticeRules.slot_is_borable(mass,
					WarrenExcavation.new(seed_value), floor - Vector3i.UP,
					WarrenPassageLatticeRules.HEADROOM_BANDS))

func test_source_city_shapes_include_courts_open_bays_and_low_ridges() -> void:
	var kinds: Dictionary = {}
	var enclosed := 0
	var low := 0
	for seed in range(1, 33):
		var massif := WarrenMassifBuilder.build(seed, {},
			WarrenVillageScaleProfile.for_id(&"standard"))
		var kind: Variant = massif.get("form_id")
		if kind != null:
			kinds[kind] = true
		if massif._find_interior_hole() != null:
			enclosed += 1
		if massif.core_top_bands <= 12:
			low += 1
		assert_true(massif.validate_construction(), massif.last_rejection)
	assert_gte(kinds.size(), 4, "source generation must declare distinct city forms")
	assert_gt(enclosed, 0, "an enclosed open court must be real missing mass")
	assert_gt(low, 0, "some cities must have a lower skyline")


func test_enclosed_court_is_not_a_world_road_exit() -> void:
	var columns: Dictionary = {}
	for z in range(-4, 5):
		for x in range(-4, 5):
			if absi(x) <= 1 and absi(z) <= 1:
				continue
			columns[Vector2i(x, z)] = {"base": 0, "top": 8, "terrace": 8}
	var massif := WarrenMassif.with_columns(1, columns, 8)
	assert_false(WarrenPassageLatticeRules.exterior_approach_is_clear(
		massif, Vector3i(-2, 0, 0), Vector2i.RIGHT),
		"the far bank of a courtyard blocks a world-road handoff")
	assert_true(WarrenPassageLatticeRules.exterior_approach_is_clear(
		massif, Vector3i(-4, 0, 0), Vector2i.LEFT))


func test_reserved_native_houses_have_real_public_doorsteps() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.solve(1, {}, program,
		WarrenVillageScaleProfile.for_id(&"standard"))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
	var promised := 0
	for record: Dictionary in source.audit.get("plot_outcomes", {}).get("assets", []):
		promised += int(record.get("realisable", false))
	assert_gt(promised, 0, "this town has room for native houses along its streets")
	assert_gte(int(spatial.audit.get("prefab_landmark_count", 0)), promised,
		"a source reservation must survive the real public-floor and stair checks")


func test_new_shapes_preserve_complete_roof_construction() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for case: Array in [[9, &"standard"], [11, &"large"], [3, &"large"], [12, &"compact"]]:
		var spatial := WarrenVolumetricSolver.solve(case[0], {}, program,
			WarrenVillageScaleProfile.for_id(case[1]))
		assert_not_null(spatial, "%s: %s" % [case, WarrenVolumetricSolver.last_failure])
		if spatial != null:
			assert_true(spatial.compiled_fabric_cache().is_sealed())


func test_optional_bay_supports_clear_the_crossing_between_public_cells() -> void:
	# The lower city's actual brace crosses this edge despite clearing both
	# standing centres. Rotate the same physical arrangement through every hand.
	for yaw in 4:
		var turn := Basis(Vector3.UP, yaw * PI * 0.5)
		var native_key := Vector3(2, 3, 4)
		var rotated_key := turn * native_key
		var outward := Vector3i((turn * Vector3(SettlementFabricAssembler.STONE_FACE_DIRECTIONS[2])).round())
		var side := SettlementFabricAssembler.STONE_FACE_DIRECTIONS.find(outward)
		var key := Vector4i(roundi(rotated_key.x), 3, roundi(rotated_key.z), side)
		var walked: Dictionary = {}
		for point: Vector3 in [Vector3(1, 0, 3), Vector3(2, 0, 3)]:
			walked[Vector3i((turn * point).round())] = true
		assert_false(SettlementFabricAssembler._maze_facade_outcrop_bearers_clear(
			key, SettlementFabricAssembler.FacadeOutcrop.BAY, walked),
			"the whole crossing, including its middle, must clear the actual support")


func test_declared_court_does_not_hide_unrelated_holes() -> void:
	var massif := WarrenMassifBuilder.build(2, {}, WarrenVillageScaleProfile.for_id(&"standard"))
	assert_true(massif.validate_construction())
	var damaged := WarrenMassif.with_columns(2, massif.columns.duplicate(true), massif.core_top_bands)
	damaged.form_id = massif.form_id
	damaged.open_court = massif.open_court.duplicate()
	damaged.columns.erase(Vector2i(-2, 0))
	assert_false(damaged.validate_construction(), "an unrelated missing inner column is still a defect")
	var overlap := WarrenMassif.with_columns(2, massif.columns.duplicate(true), massif.core_top_bands)
	overlap.open_court = {Vector2i.ZERO: true}
	assert_false(overlap.validate_construction(), "a court cannot also carry construction")


func test_native_foundation_clearance_has_an_exterior_band_below_ground() -> void:
	var massif := WarrenMassifBuilder.build(1, {}, WarrenVillageScaleProfile.for_id(&"standard"))
	var bounds := WarrenVolumetricSolver._grid_bounds(massif)
	assert_eq((bounds.minimum as Vector3i).y, -1)
	assert_eq(massif.bearing_at(Vector2i.ZERO), 0, "the extra grid band does not lower natural bearing")


func test_frontage_subtraction_discards_inverted_empty_intervals() -> void:
	assert_eq(VillageFrontageDomain.subtract_interval([Vector2(4, -4)] as Array[Vector2],
		Vector2(8, 9)), [] as Array[Vector2], "a house wider than the street has no legal coordinate")


func test_native_houses_share_inner_and_outer_town_street_frontage() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-24, 25):
		for x in range(-24, 25):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 0
	var terrain := VillageTerrainView.from_region(HeightfieldRegion.new(storeys, levels))
	var spatial := WarrenVolumetricSolver.solve(2, {}, program.settlement_fabric_program,
		WarrenVillageScaleProfile.for_id(&"standard"))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var fabric := spatial.compiled_fabric_cache()
	var placement := VillageWarrenFabricSolver._placement(terrain, spatial, Vector2.ZERO, Vector2.DOWN)
	placement["local_bounds"] = VillageWarrenFabricSolver._local_bounds(fabric)
	var urban := VillageWarrenFabricSolver._materialize(terrain, &"form.2", spatial,
		fabric, placement, program, 2)
	var outskirts := VillageOutskirtsConstruction.generate(terrain, &"form.2", Vector2.ZERO,
		Vector2.DOWN, &"village", &"blue", program, urban, null)
	var domain: FeatureGroundShape
	for shape: FeatureGroundShape in outskirts.surfaces:
		if String(shape.stable_id).ends_with(".street-domain"):
			domain = shape
	assert_not_null(domain)
	var inside := 0
	var families: Dictionary = {}
	for house: VillageMassingPlacement in outskirts.placements:
		inside += int(domain.signed_distance(house.solid_centre) < 0.0)
		families[house.asset_id] = true
	assert_gte(inside, 2, "native houses must occupy open space inside the city boundary")
	assert_gt(outskirts.placements.size() - inside, 0, "both sides of the shared street participate")
	assert_gte(families.size(), 3, "the combined neighborhood uses varied complete native houses")
	assert_true(outskirts.validate(program.outskirts_program, &"village"))
	var physical: Array[VillageOccupancyVolume] = []
	for volume: VillageOccupancyVolume in urban.volumes:
		if volume.role != VillageOccupancy.Role.GROUND_EXCLUSIVE:
			physical.append(volume)
	assert_eq(VillageOccupancy.first_cross_conflict(outskirts.volumes, physical), {},
		"complete houses and approaches remain clear of the finished warren")

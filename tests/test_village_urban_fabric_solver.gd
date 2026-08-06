extends GutTest


func _terraced_region() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			var cell := Vector2i(x, z)
			storeys[cell] = 0 if x <= -1 else (1 if x == 0 else 2)
			levels[cell] = 0
	return HeightfieldRegion.new(storeys, levels)


func test_dense_terrain_led_village_is_one_atomic_structural_transaction() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var result := VillageUrbanFabricSolver.solve(
		VillageTerrainView.from_region(_terraced_region()), &"urban.test",
		Vector2.ZERO, Vector2.RIGHT, &"village", &"blue", program)
	assert_true(result.accepted, "%s\n%s" % [String(result.reason),
		JSON.stringify(result.candidate_audit, "  ")])
	if not result.accepted:
		return
	assert_true(result.validate(program, &"village"))
	assert_gte(result.buildings.size(),
		program.massing_program.minimum_buildings(&"village"))
	assert_gte(result.natural_building_count, 1)
	assert_gte(result.retained_building_count, 1)
	assert_gt(result.rock_piece_count, 0)
	assert_gt(result.timber.cells.size(), 0)
	assert_gt(result.timber.railing_count, 0)
	assert_gt(result.timber.support_count, 0)
	assert_lt(result.timber.support_count,
		result.timber.cells.size() / 2,
		"thin elevated streets use sparse structural stacks, not a post forest")
	assert_gt(result.entrance_stair_count, 0)
	assert_gt(result.public_stair_count, 0)
	assert_true(result.route_stairs.validate())
	assert_eq(result.route_stairs.railing_count,
		result.public_stair_count * 2,
		"every steep public stair module has two structural side rails")
	assert_gt(result.surfaces.size(), 0)
	assert_gt(result.clearances.size(), result.surfaces.size())
	_assert_ground_stairs_follow_their_frozen_terrain_edges(result)
	var occupancy := VillageOccupancy.new()
	assert_true(occupancy.add_all(result.volumes),
		"the sealed result must remain conflict-free as one transaction")
	for entry: Dictionary in result.entries:
		assert_true((entry.transform as Transform3D).basis.get_scale(
			).is_equal_approx(Vector3.ONE),
			"the urban fabric never rescales collision-bearing assets")


func _assert_ground_stairs_follow_their_frozen_terrain_edges(
		result: VillageUrbanFabricPlan) -> void:
	for link: VillageCirculationLink in result.circulation.links:
		if link.kind != VillageCirculationLink.Kind.GROUND_STAIR:
			continue
		var runs := result.route_stairs.runs_for(link.stable_key)
		assert_eq(runs.size(), link.stair_transitions.size())
		var cumulative := PackedFloat32Array([0.0])
		for sample_index in range(1, link.samples.size()):
			cumulative.append(cumulative[-1] + Vector2(
				link.samples[sample_index].x,
				link.samples[sample_index].z).distance_to(Vector2(
				link.samples[sample_index - 1].x,
				link.samples[sample_index - 1].z)))
		for index in mini(runs.size(), link.stair_transitions.size()):
			var run: VillageRouteStairRun = runs[index]
			var transition: VillageStairTransition = link.stair_transitions[index]
			assert_almost_eq(run.from_y,
				link.samples[transition.segment_index - 1].y, 0.001,
				"a ground flight freezes the lower route-edge landing")
			assert_almost_eq(run.to_y,
				link.samples[transition.segment_index].y, 0.001,
				"a ground flight freezes the upper route-edge landing")
			var transition_distance := (cumulative[
				transition.segment_index - 1] + cumulative[
				transition.segment_index]) * 0.5
			assert_true(transition_distance >= run.start_distance - 0.001 \
				and transition_distance <= run.end_distance + 0.001,
				"a ground flight may not migrate to a different terrain edge")
			var midpoint3 := link.samples[
				transition.segment_index - 1].lerp(
					link.samples[transition.segment_index], 0.5)
			var midpoint := Vector2(midpoint3.x, midpoint3.z)
			var painted := false
			for surface: FeatureGroundShape in result.surfaces:
				if surface.contains(midpoint):
					painted = true
					break
			assert_true(painted,
				"the worn public street remains continuous beneath stair flights")

extends GutTest


func test_inspection_reports_missing_headroom_without_discarding_the_walk() -> void:
	var excavation := WarrenExcavation.new(17)
	excavation.route.assign([Vector3i.ZERO, Vector3i.RIGHT])
	excavation.portals.append(Vector3i.ZERO)
	excavation.transitions.append({"from": Vector3i.ZERO, "to": Vector3i.RIGHT,
		"kind": WarrenVolumeTransition.Kind.LEVEL})
	excavation.carved[Vector3i.ZERO] = true
	var route_before := excavation.route.duplicate()
	var carved_before := excavation.carved.duplicate()
	excavation.finish_construction()
	assert_true(excavation.is_sealed())
	assert_false(excavation.validate_construction())
	assert_string_contains(excavation.last_rejection, "headroom")
	assert_eq(excavation.route, route_before)
	assert_eq(excavation.carved, carved_before)
	assert_true(excavation.is_sealed(), "inspection cannot withdraw the published construction")


func test_constructed_source_walks_pass_independent_inspection() -> void:
	for profile_id: StringName in [&"compact", &"standard", &"large", &"grand"]:
		var profile := WarrenVillageScaleProfile.for_id(profile_id)
		var source := WarrenMazeSitePlanner.plan(17, {}, profile)
		assert_not_null(source, WarrenMazeSitePlanner.last_failure)
		if source == null:
			continue
		var before := source.excavation.route.duplicate()
		assert_true(source.excavation.validate_construction(),
			"%s: %s" % [profile_id, source.excavation.last_rejection])
		assert_eq(source.excavation.route, before)


func test_optional_source_diagnostics_cannot_change_construction() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"grand")
	var generated := WarrenMazeSitePlanner.plan(17, {}, profile, &"", false)
	var inspected := WarrenMazeSitePlanner.plan(17, {}, profile, &"", true)
	assert_not_null(generated, WarrenMazeSitePlanner.last_failure)
	assert_not_null(inspected, WarrenMazeSitePlanner.last_failure)
	if generated == null or inspected == null:
		return
	assert_eq(generated.deterministic_signature(), inspected.deterministic_signature())
	assert_true(generated.excavation.validate_construction(), generated.excavation.last_rejection)
	assert_true(generated.validate_construction(), generated.last_rejection)


func test_volume_projection_preserves_the_bore_with_diagnostics_disabled() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"standard")
	var source := WarrenMazeSitePlanner.plan(17, {}, profile, &"", false)
	var generated := WarrenMazeVolumeAdapter.to_volume_plan(source, false)
	var inspected := WarrenMazeVolumeAdapter.to_volume_plan(source, true)
	assert_not_null(generated, WarrenMazeVolumeAdapter.last_failure)
	assert_not_null(inspected, WarrenMazeVolumeAdapter.last_failure)
	if generated == null or inspected == null:
		return
	assert_true(generated.audit.is_empty(), "production must not run a complete volume audit")
	assert_eq(generated.deterministic_signature(), inspected.deterministic_signature())
	assert_eq(generated.mass_cells, inspected.mass_cells)
	assert_eq(generated.exact_route_surface_cells(), inspected.exact_route_surface_cells())
	assert_true(generated.validate_construction(), generated.last_rejection)
	var before := generated.deterministic_signature()
	var headroom := generated.walk_cells[0] + Vector3i.UP
	generated._air_set.erase(headroom)
	assert_false(generated.validate_construction())
	assert_string_contains(generated.last_rejection, "headroom")
	assert_true(generated.is_sealed(), "inspection cannot withdraw a constructed volume")
	assert_false(generated._air_set.has(headroom), "inspection cannot repair the defect it reports")
	assert_eq(generated.deterministic_signature(), before)


func test_a_legal_short_branch_retains_its_walk_and_headroom() -> void:
	var columns: Dictionary = {}
	for x in range(-3, 4):
		for z in range(-3, 4):
			columns[Vector2i(x, z)] = {"base": 0, "top": 12}
	var massif := WarrenMassif.with_columns(17, columns, 12)
	assert_true(massif.seal())
	var excavation := WarrenExcavation.new(17)
	excavation.route.append(Vector3i.ZERO)
	for band in WarrenPassageLatticeRules.HEADROOM_BANDS:
		excavation.carved[Vector3i(0, band, 0)] = true
	var public := {Vector3i.ZERO: true}
	var lane := WarrenMazeCarver._grow_alley(17, massif, excavation,
		public, {}, Vector3i.ZERO, 1)
	assert_false(lane.is_empty(), "a one-cell address does not need a three-cell alley")
	if lane.is_empty():
		return
	assert_eq((lane.cells as Array).size(), 1)
	var endpoint := (lane.cells as Array)[0] as Vector3i
	assert_has(public, endpoint)
	for band in WarrenPassageLatticeRules.HEADROOM_BANDS:
		assert_has(excavation.carved, endpoint + Vector3i.UP * band)
	assert_eq(lane.transitions[0].from, Vector3i.ZERO)
	assert_eq(lane.transitions[0].to, endpoint)


func test_alley_growth_keeps_prior_bore_and_reserved_house_space() -> void:
	var columns: Dictionary = {}
	for x in range(-4, 5):
		for z in range(-4, 5): columns[Vector2i(x, z)] = {"base": 0, "top": 12}
	var massif := WarrenMassif.with_columns(17, columns, 12)
	assert_true(massif.seal())
	var excavation := WarrenExcavation.new(17)
	excavation.route.append(Vector3i.ZERO)
	for band in WarrenPassageLatticeRules.HEADROOM_BANDS:
		excavation.carved[Vector3i.UP * band] = true
	for band in WarrenMazeCarver.MIN_HOUSE_BANDS:
		excavation.frontage_reservations[Vector3i(1, band, 0)] = true
	var previous_bore := excavation.carved.duplicate()
	var public := {Vector3i.ZERO: true}
	var lane := WarrenMazeCarver._grow_alley(17, massif, excavation,
		public, {}, Vector3i.ZERO, 8)
	assert_false(lane.is_empty(), "the free domain still supplies a street")
	for cell: Vector3i in previous_bore:
		assert_has(excavation.carved, cell, "construction cannot roll back earlier walk")
	for cell: Vector3i in excavation.frontage_reservations:
		assert_false(excavation.carved.has(cell), "housing is reserved before later excavation")

func test_secondary_gate_turns_are_part_of_the_route_domain() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	var source := WarrenMazeSitePlanner.plan(3, {}, profile)
	assert_not_null(source, WarrenMazeSitePlanner.last_failure)
	if source == null: return
	assert_gte(source.excavation.portals.size(), 2,
		"the connected large-town street domain has a separated second gate")
	for lane: Dictionary in source.excavation.lanes:
		if lane.get("feature_kind", &"") != &"secondary_gate": continue
		var walk: Array[Vector3i] = [lane.anchor]
		walk.append_array(lane.cells)
		assert_lte(WarrenMazeSourcePlan._max_straight_run(walk),
			WarrenMazeSourcePlan.MAX_ALLEY_STRAIGHT_RUN)

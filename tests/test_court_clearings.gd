extends GutTest

func _setup(seed_value: int, scale: StringName, count: float) -> Dictionary:
	var profile := WarrenVillageScaleProfile.for_id(scale)
	TownCharacter.attach(profile, TownOddsProgram.builtin().with_overrides({&"clearing_count": count}), seed_value)
	var plan := WarrenMazeSitePlanner.plan(seed_value, {}, profile, &"carve")
	return {"profile": profile, "plan": plan}

func test_default_table_proposes_nothing() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	TownCharacter.attach(profile, TownOddsProgram.builtin(), 31)
	var plan := WarrenMazeSitePlanner.plan(31, {}, profile, &"carve")
	assert_eq(WarrenCourtClearings.propose(31, plan.massif, plan.excavation, profile).size(), 0)

func test_proposals_are_deterministic_disjoint_and_wide_enough() -> void:
	var s := _setup(31, &"large", 3.0)
	var plan: WarrenMazeSourcePlan = s.plan
	var first := WarrenCourtClearings.propose(31, plan.massif, plan.excavation, s.profile)
	var second := WarrenCourtClearings.propose(31, plan.massif, plan.excavation, s.profile)
	assert_eq(first, second)
	assert_gt(first.size(), 0)
	var used := {}
	var empty := WarrenMazeSourcePlan.new(31, s.profile, plan.massif, plan.excavation)
	var blocked := WarrenPlotPlanner.blocked_columns(empty)
	var street := WarrenCourtClearings.street_distance(plan.massif, plan.excavation)
	for clearing: Dictionary in first:
		for column: Vector2i in clearing.cells:
			assert_false(used.has(column), "clearings overlap")
			used[column] = true
			assert_gt(int(street.get(column, 1)), 0, "not a public column")
			assert_true(WarrenPlotReservations._deck_column_ok(empty, column, int(clearing.floor), {}, blocked, 6))
			var wide := false
			for dx in [-1, 0]:
				for dz in [-1, 0]:
					var all_in := true
					for ox in 2:
						for oz in 2:
							all_in = all_in and clearing.cells.has(column + Vector2i(dx + ox, dz + oz))
					wide = wide or all_in
			assert_true(wide, "every clearing cell belongs to a 2x2 block")

func _streets_only(seed_value: int, scale: StringName, count: float) -> Dictionary:
	## Streets built without clearings; the profile then carries `count`, so
	## propose() sees a network none of its own clearings have reserved yet.
	var profile := WarrenVillageScaleProfile.for_id(scale)
	TownCharacter.attach(profile, TownOddsProgram.builtin(), seed_value)
	var plan := WarrenMazeSitePlanner.plan(seed_value, {}, profile, &"carve")
	TownCharacter.attach(profile, TownOddsProgram.builtin().with_overrides({&"clearing_count": count}), seed_value)
	return {"profile": profile, "plan": plan}

func test_thick_blocks_are_preferred() -> void:
	var s := _streets_only(53, &"grand", 4.0)
	var plan: WarrenMazeSourcePlan = s.plan
	var street := WarrenCourtClearings.street_distance(plan.massif, plan.excavation)
	var chosen := 0.0
	var count := 0
	for clearing: Dictionary in WarrenCourtClearings.propose(53, plan.massif, plan.excavation, s.profile):
		for column: Vector2i in clearing.cells:
			chosen += float(street.get(column, 0))
			count += 1
	assert_gt(count, 0)
	var all := 0.0
	var n := 0
	for column: Vector2i in plan.massif.columns:
		if street.get(column, 0) > 0:
			all += float(street[column])
			n += 1
	assert_gt(chosen / maxf(1.0, float(count)), all / float(maxi(1, n)))

func test_area_reached_and_floor_has_a_street_at_its_band() -> void:
	for pair: Array in [[31, &"large"], [53, &"grand"], [12, &"compact"]]:
		var s := _setup(pair[0], pair[1], 3.0)
		var plan: WarrenMazeSourcePlan = s.plan
		var by_band := {}
		for cell: Vector3i in plan.excavation.public_cells():
			if not by_band.has(cell.y):
				by_band[cell.y] = {}
			by_band[cell.y][Vector2i(cell.x, cell.z)] = true
		for clearing: Dictionary in WarrenCourtClearings.propose(pair[0], plan.massif, plan.excavation, s.profile):
			assert_gte(clearing.cells.size(), maxi(4, int(clearing.area) / 2), "%s area" % [pair])
			# Ground and raised floors alike: the centre column (one of the
			# cells) lies within a level street's reach at the clearing's band.
			var near := false
			var at: Dictionary = by_band.get(int(clearing.floor), {})
			for cell: Vector2i in clearing.cells:
				for c: Vector2i in at:
					near = near or absi(c.x - cell.x) + absi(c.y - cell.y) <= WarrenCourtClearings.STREET_REACH
			assert_true(near, "floor has a street at its band within reach")

func test_carved_clearings_are_reachable_and_reserved() -> void:
	var s := _setup(53, &"grand", 3.0)
	var plan: WarrenMazeSourcePlan = s.plan
	assert_gt(plan.excavation.court_clearings.size(), 0)
	var walk := {}
	for cell: Vector3i in WarrenMazeCarver._walk_nodes(plan.excavation):
		walk[cell] = true
	for clearing: Dictionary in plan.excavation.court_clearings:
		assert_true(walk.has(clearing.door_walk), "door is a walk node")
		var touches := false
		for column: Vector2i in clearing.cells:
			touches = touches or absi(column.x - clearing.door_walk.x) + absi(column.y - clearing.door_walk.z) == 1
			for band in range(int(clearing.floor) - 1, int(clearing.floor) + WarrenMazeSourcePlan.MIN_HOUSE_BANDS):
				assert_true(plan.excavation.construction_reservations.has(Vector3i(column.x, band, column.y)))
		assert_true(touches, "door is beside the clearing")
		assert_eq(int(clearing.door_walk.y), int(clearing.floor), "door is at the clearing floor")
		assert_gte(int(clearing.links), 1)

func test_unconnectable_clearing_leaves_no_trace() -> void:
	# Every clearing access lane serves a kept clearing.
	var total_lanes := 0
	for spec: Array in [[53, &"grand"], [103, &"standard"]]:
		var s := _setup(spec[0], spec[1], 3.0)
		var plan: WarrenMazeSourcePlan = s.plan
		var clearing_doors := {}
		for clearing: Dictionary in plan.excavation.court_clearings:
			assert_eq((clearing.doors as Array).size(), int(clearing.links))
			for door: Vector3i in clearing.doors:
				clearing_doors[door] = true
		for lane: Dictionary in plan.excavation.lanes:
			if lane.get("feature_kind", &"") != &"court_clearing_access":
				continue
			total_lanes += 1
			assert_true(clearing_doors.has((lane.cells as Array).back()),
				"every clearing lane ends at a kept clearing's door")
	assert_gt(total_lanes, 0)
	# Carving again over a finished street network: proposals no street reaches
	# at their floor are withdrawn whole -- no reservation, lane or carved cell.
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	TownCharacter.attach(profile, TownOddsProgram.builtin(), 31)
	var base := WarrenMazeSitePlanner.plan(31, {}, profile, &"carve")
	TownCharacter.attach(profile, TownOddsProgram.builtin().with_overrides({&"clearing_count": 3.0}), 31)
	var excavation := WarrenExcavation.new(31)
	for key: String in ["route", "transitions", "lanes", "loop_edges", "carved", "covered", "portals",
			"bridge_spans", "bridge_span_audit", "bridge_bearing_columns", "bridge_directions",
			"construction_reservations", "frontage_reservations", "tunnel_cells", "tunnel_attrition",
			"court_clearings"]:
		excavation.set(key, base.excavation.get(key).duplicate(true))
	var proposals := WarrenCourtClearings.propose(31, base.massif, excavation, profile)
	assert_gt(proposals.size(), 0)
	var lanes_before := excavation.lanes.size()
	var carved_before := excavation.carved.duplicate()
	var reserved_before := excavation.construction_reservations.duplicate()
	WarrenCourtClearings.carve(31, base.massif, excavation, {}, profile)
	var kept := {}
	for clearing: Dictionary in excavation.court_clearings:
		kept[clearing.cells] = true
	var withdrawn := 0
	for proposal: Dictionary in proposals:
		if kept.has(proposal.cells):
			continue
		withdrawn += 1
		for column: Vector2i in proposal.cells:
			for band in range(int(proposal.floor) - 1, int(proposal.floor) + WarrenMazeSourcePlan.MIN_HOUSE_BANDS):
				var cell := Vector3i(column.x, band, column.y)
				assert_eq(excavation.construction_reservations.has(cell), reserved_before.has(cell),
					"a withdrawn clearing leaves no reservation")
	assert_gt(withdrawn, 0, "the fixture exercises a withdrawal")
	var links := 0
	for clearing: Dictionary in excavation.court_clearings:
		links += int(clearing.links)
	assert_lte(excavation.lanes.size() - lanes_before, links, "only kept clearings add lanes")
	var lane_cells := {}
	for lane: Dictionary in excavation.lanes.slice(lanes_before):
		for cell: Vector3i in lane.cells:
			lane_cells[Vector2i(cell.x, cell.z)] = true
	for cell: Vector3i in excavation.carved:
		if not carved_before.has(cell):
			assert_true(lane_cells.has(Vector2i(cell.x, cell.z)), "new air belongs to a kept clearing's lane")

func test_clearing_lanes_survive_destination_pruning() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"standard")
	TownCharacter.attach(profile, TownOddsProgram.builtin().with_overrides({&"clearing_count": 3.0}), 103)
	var plan := WarrenMazeSitePlanner.plan(103, {}, profile)
	assert_not_null(plan)
	assert_gt(plan.excavation.court_clearings.size(), 0)
	var walk := {}
	for cell: Vector3i in WarrenMazeCarver._walk_nodes(plan.excavation):
		walk[cell] = true
	for clearing: Dictionary in plan.excavation.court_clearings:
		assert_true(walk.has(clearing.door_walk), "a kept clearing keeps its door on the public realm")

func test_default_table_carves_no_clearings() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	TownCharacter.attach(profile, TownOddsProgram.builtin(), 31)
	var plan := WarrenMazeSitePlanner.plan(31, {}, profile, &"carve")
	assert_eq(plan.excavation.court_clearings.size(), 0)
	assert_eq(plan.excavation.lanes.filter(func(l: Dictionary) -> bool:
		return l.get("feature_kind", &"") == &"court_clearing_access").size(), 0)

func _copy_excavation(source: WarrenExcavation) -> WarrenExcavation:
	var excavation := WarrenExcavation.new(source.world_seed)
	for key: String in ["route", "transitions", "lanes", "loop_edges", "carved", "covered", "portals",
			"bridge_spans", "bridge_span_audit", "bridge_bearing_columns", "bridge_directions",
			"construction_reservations", "frontage_reservations", "tunnel_cells", "tunnel_attrition",
			"court_clearings"]:
		excavation.set(key, source.get(key).duplicate(true))
	return excavation

func test_clearings_never_share_another_reservation() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"grand")
	TownCharacter.attach(profile, TownOddsProgram.builtin(), 53)
	var base := WarrenMazeSitePlanner.plan(53, {}, profile, &"carve")
	TownCharacter.attach(profile, TownOddsProgram.builtin().with_overrides({&"clearing_count": 3.0}), 53)
	var excavation := _copy_excavation(base.excavation)
	var first := WarrenCourtClearings.propose(53, base.massif, excavation, profile)
	assert_gt(first.size(), 0)
	# Pre-reserve one column of the first proposal at its floor (a foreign envelope).
	var column: Vector2i = first[0].cells[0]
	var foreign := Vector3i(column.x, int(first[0].floor), column.y)
	excavation.construction_reservations[foreign] = true
	var reserved_before := excavation.construction_reservations.duplicate()
	var second := WarrenCourtClearings.propose(53, base.massif, excavation, profile)
	for proposal: Dictionary in second:
		for c: Vector2i in proposal.cells:
			for band in range(int(proposal.floor) - 1, int(proposal.floor) + WarrenMazeSourcePlan.MIN_HOUSE_BANDS):
				assert_false(reserved_before.has(Vector3i(c.x, band, c.y)), "proposal overlaps a reservation")
	WarrenCourtClearings.carve(53, base.massif, excavation, {}, profile)
	for cell: Vector3i in reserved_before:
		assert_true(excavation.construction_reservations.has(cell), "carving never releases a foreign reservation")
	for clearing: Dictionary in excavation.court_clearings:
		var span := range(int(clearing.floor) - 1, int(clearing.floor) + WarrenMazeSourcePlan.MIN_HOUSE_BANDS)
		assert_false((clearing.cells as Array).has(column) and span.has(foreign.y),
			"the pre-reserved cell is in no clearing's span")

func test_clearing_doors_are_never_flight_treads() -> void:
	var s := _setup(103, &"standard", 3.0)
	var plan: WarrenMazeSourcePlan = s.plan
	assert_gt(plan.excavation.court_clearings.size(), 0)
	var flights := plan.excavation.flight_cells()
	for clearing: Dictionary in plan.excavation.court_clearings:
		for door: Vector3i in clearing.doors:
			assert_false(flights.has(door), "a door is never a flight tread")
			assert_eq(door.y, int(clearing.floor))

func _clearing_plots(plan: WarrenMazeSourcePlan) -> Array:
	return plan.plots.filter(func(p: Dictionary) -> bool: return String(p.id).begins_with("clearing."))

func test_clearings_become_court_plots_and_greens_are_lawns() -> void:
	# Seed 31 keeps no clearing after Task 9's guardrails; 103 standard keeps some.
	var profile := WarrenVillageScaleProfile.for_id(&"standard")
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	program.town_odds = program.town_odds.with_overrides({&"clearing_count": 3.0})
	var spatial := WarrenVolumetricSolver.generate(103, {}, program, profile)
	assert_not_null(spatial)
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	var courts := _clearing_plots(source)
	assert_gt(courts.size(), 0)
	assert_eq(courts.size(), source.excavation.court_clearings.size())
	for plot: Dictionary in courts:
		assert_eq(plot.kind, WarrenMazeSourcePlan.PLOT_DECK)
		assert_eq(WarrenPlotReservations.is_green_court(plot), plot.purpose == &"green")

func test_plaza_is_still_green() -> void:
	assert_true(WarrenPlotReservations.is_green_court({"id": WarrenPlotReservations.PLAZA_PLOT_ID}))
	assert_false(WarrenPlotReservations.is_green_court({"id": &"deck.00"}))

func test_clearing_plots_match_kept_clearings_and_nothing_builds_on_them() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"standard")
	TownCharacter.attach(profile, TownOddsProgram.builtin().with_overrides({&"clearing_count": 3.0}), 103)
	var plan := WarrenMazeSitePlanner.plan(103, {}, profile)
	assert_not_null(plan)
	var courts := _clearing_plots(plan)
	assert_gt(courts.size(), 0)
	assert_eq(courts.size(), plan.excavation.court_clearings.size())
	for plot: Dictionary in courts:
		var matched := false
		for clearing: Dictionary in plan.excavation.court_clearings:
			var cells: Array[Vector2i] = []
			cells.assign(clearing.cells)
			matched = matched or (cells == plot.cells and int(clearing.floor) == int(plot.floor))
		assert_true(matched, "clearing plot %s has a kept clearing" % plot.id)
		for column: Vector2i in plot.cells:
			for index: int in plan.plots_at(column):
				var other: Dictionary = plan.plots[index]
				if other.id == plot.id: continue
				# Only retained support (a wall room) may stand BELOW a court.
				assert_true(int(WarrenMazeSourcePlan._plot_reserved_top(other)) <= int(plot.floor),
					"%s stands on court %s" % [other.id, plot.id])
	var records: Array = WarrenPlotPlanner.outcomes(plan).get("clearings", [])
	assert_gt(records.size(), 0)

func test_withdrawn_clearing_withdraws_its_plot() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"standard")
	TownCharacter.attach(profile, TownOddsProgram.builtin().with_overrides({&"clearing_count": 3.0}), 103)
	var plan := WarrenMazeSitePlanner.plan(103, {}, profile, &"reserve")
	var courts := _clearing_plots(plan)
	assert_gt(courts.size(), 0)
	var gone: Dictionary = courts[0]
	var kept: Array[Dictionary] = []
	for clearing: Dictionary in plan.excavation.court_clearings:
		var cells: Array[Vector2i] = []
		cells.assign(clearing.cells)
		if cells != gone.cells: kept.append(clearing)
	plan.excavation.court_clearings = kept
	WarrenPlotReservations.withdraw_orphan_clearings(plan)
	assert_eq(_clearing_plots(plan).size(), courts.size() - 1)
	for column: Vector2i in gone.cells:
		for index: int in plan.plots_at(column):
			assert_ne(plan.plots[index].id, gone.id)

func _green_features(seed_value: int, scale: StringName, count: float) -> Dictionary:
	var profile := WarrenVillageScaleProfile.for_id(scale)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	if count > 0.0:
		program.town_odds = program.town_odds.with_overrides({&"clearing_count": count})
	var spatial := WarrenVolumetricSolver.generate(seed_value, {}, program, profile)
	assert_not_null(spatial)
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	var facts := WarrenSpatialFabricCompiler.construction_diagnostics(spatial,
		spatial.compiled_fabric_cache(), program)
	var plaza_columns := {}
	for plot: Dictionary in source.plots:
		if plot.id == WarrenPlotReservations.PLAZA_PLOT_ID:
			for column: Vector2i in plot.cells: plaza_columns[column] = true
	var plaza_feature := {}
	for feature: Dictionary in facts.get("maze_plaza_centre_features", []):
		var cell := feature.cell as Vector3i
		if plaza_columns.has(Vector2i(floori(cell.x / 2.0), floori(cell.z / 2.0))):
			plaza_feature = feature
	return {"facts": facts, "plaza_columns": plaza_columns, "plaza_feature": plaza_feature,
		"greens": source.plots.filter(func(p: Dictionary) -> bool: return WarrenPlotReservations.is_green_court(p)).size()}

func test_every_green_gets_its_own_centre_feature_and_the_plaza_keeps_its_own() -> void:
	var on := _green_features(53, &"grand", 3.0)
	var facts: Dictionary = on.facts
	var features: Array = facts.get("maze_plaza_centre_features", [])
	assert_gte(int(on.greens), 2, "the town carries the plaza and a green clearing")
	assert_eq(int(facts.get("maze_green_component_count", 0)), int(on.greens))
	assert_eq(int(facts.get("maze_plaza_centre_feature_count", -1)), features.size())
	assert_gte(features.size(), 2, "a green clearing that fits a feature gets one beside the plaza's")
	var components := {}
	for feature: Dictionary in features:
		var cell := feature.cell as Vector3i
		var key := Vector2i(floori(cell.x / 2.0), floori(cell.z / 2.0))
		assert_false(components.has(key))
		components[key] = true
	var off := _green_features(53, &"grand", 0.0)
	assert_false((off.plaza_feature as Dictionary).is_empty())
	if on.plaza_columns == off.plaza_columns:
		assert_eq(on.plaza_feature, off.plaza_feature, "the plaza keeps its own centrepiece")

func _assert_centre_features_never_overlap(seed_value: int, scale: StringName) -> void:
	var on := _green_features(seed_value, scale, 3.0)
	var features: Array = (on.facts as Dictionary).get("maze_plaza_centre_features", [])
	assert_gte(features.size(), 2, "%d/%s furnishes more than one green" % [seed_value, scale])
	for i in features.size():
		assert_false((features[i].boxes as Array).is_empty())
		for j in range(i + 1, features.size()):
			for a: AABB in features[i].boxes:
				for b: AABB in features[j].boxes:
					assert_false(SettlementFabricAssembler._boxes_share_volume(a, b),
						"%d/%s centre features %s and %s overlap" % [seed_value, scale,
							features[i].asset, features[j].asset])

func test_centre_features_never_overlap_103_standard() -> void:
	_assert_centre_features_never_overlap(103, &"standard")

func test_centre_features_never_overlap_53_grand() -> void:
	_assert_centre_features_never_overlap(53, &"grand")

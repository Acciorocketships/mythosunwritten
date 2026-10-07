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

func test_thick_blocks_are_preferred() -> void:
	var s := _setup(53, &"grand", 4.0)
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
			var column: Vector2i = clearing.cells[0]
			if int(clearing.floor) != plan.massif.bearing_at(column):
				# The site's centre column is one of the cells and was the one checked.
				var near := false
				var at: Dictionary = by_band.get(int(clearing.floor), {})
				for cell: Vector2i in clearing.cells:
					for c: Vector2i in at:
						near = near or absi(c.x - cell.x) + absi(c.y - cell.y) <= WarrenCourtClearings.STREET_REACH
				assert_true(near, "raised floor has a street within reach")

func test_carved_clearings_are_reachable_and_reserved() -> void:
	var s := _setup(31, &"large", 3.0)
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
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	TownCharacter.attach(profile, TownOddsProgram.builtin().with_overrides({&"clearing_count": 3.0}), 31)
	var plan := WarrenMazeSitePlanner.plan(31, {}, profile)
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

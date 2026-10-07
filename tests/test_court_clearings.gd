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

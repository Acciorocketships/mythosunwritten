extends GutTest

## The plot model (2026-08-21 plot-model design, task B1): plots, the one
## support rule, the rock derived beneath them, and the sealed stack
## invariant. The edit ledger these tests deliberately ignore is deleted in a
## later task, so nothing here may lean on it.


func _unsealed_fixture() -> WarrenMazeSourcePlan:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(12, {}, profile)
	return WarrenMazeCarver.carve(12, massif, profile, false)


func _plot(id: StringName, cells: Array[Vector2i], floor_band: int,
		top_band: int, kind: StringName = &"house") -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"cells": cells,
		"floor": floor_band,
		"top": top_band,
		"door_walk": Vector3i.ZERO,
		"building_id": id,
	}


func _sorted_columns(plan: WarrenMazeSourcePlan) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(plan.massif.columns.keys())
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or a.y == b.y and a.x < b.x)
	return out


func _clean_columns(plan: WarrenMazeSourcePlan, wanted: int,
		bands: int) -> Array[Vector2i]:
	## Massif columns the carver never touched at all, carrying at least
	## `bands` bands of envelope. Measured straight off excavation.carved so a
	## fixture search never leans on the rule under test.
	var out: Array[Vector2i] = []
	for column: Vector2i in _sorted_columns(plan):
		var base := plan.massif.base_at(column)
		var top := plan.massif.top_at(column)
		if top - base < bands:
			continue
		var clear := true
		for band in range(base, top):
			if plan.excavation.carved.has(Vector3i(column.x, band, column.y)):
				clear = false
				break
		if clear:
			out.append(column)
		if out.size() == wanted:
			break
	return out


func _tunnel_roof_site(plan: WarrenMazeSourcePlan) -> Dictionary:
	## The first covered passage cell whose retained roof slab carries the
	## bands a house needs above it -- {cell, floor}, empty when the fixture
	## has none. Read off excavation.carved, never off the support rule.
	for cell: Vector3i in plan.passage_cells():
		if not bool(plan.excavation.covered.get(cell, false)):
			continue
		var floor_band := plan.passage_headroom_top(cell) + 1
		var clear := true
		for band in range(floor_band,
				floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS):
			if plan.excavation.carved.has(Vector3i(cell.x, band, cell.z)):
				clear = false
				break
		if clear:
			return {"cell": cell, "floor": floor_band}
	return {}


func _under_street_site(plan: WarrenMazeSourcePlan) -> Dictionary:
	## The first elevated passage cell standing on rock -- {cell, floor} for a
	## plot one band under it, whose own clearance therefore runs straight into
	## the street. Empty when the fixture has none.
	for cell: Vector3i in plan.passage_cells():
		var column := Vector2i(cell.x, cell.z)
		if cell.y - 2 < plan.massif.base_at(column):
			continue
		if plan.excavation.carved.has(Vector3i(cell.x, cell.y - 1, cell.z)) \
				or plan.excavation.carved.has(Vector3i(cell.x, cell.y - 2,
					cell.z)):
			continue
		return {"cell": cell, "floor": cell.y - 1}
	return {}


func test_add_plot_enforces_support_and_headroom() -> void:
	var plan := _unsealed_fixture()
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	var street := plan.passage_cells()[0]
	var street_column := Vector2i(street.x, street.z)
	var headroom_top := plan.passage_headroom_top(street)
	assert_gt(headroom_top, street.y, "a passage owns a carved slot")
	assert_false(plan.add_plot(_plot(&"in_the_slot",
		[street_column] as Array[Vector2i], street.y + 1,
		street.y + 1 + WarrenMazeSourcePlan.MIN_HOUSE_BANDS)),
		"a plot may not stand inside a passage's own headroom")
	assert_string_contains(plan.last_rejection, "support rule 1")
	assert_false(plan.add_plot(_plot(&"on_the_headroom_top",
		[street_column] as Array[Vector2i], headroom_top,
		headroom_top + WarrenMazeSourcePlan.MIN_HOUSE_BANDS)),
		"a plot may not sit AT a headroom top -- the band below it is carved")
	assert_string_contains(plan.last_rejection, "support rule 1")
	var under := _under_street_site(plan)
	assert_false(under.is_empty(), "the compact fixture climbs off its grade")
	if not under.is_empty():
		var under_cell: Vector3i = under.cell
		var under_floor: int = under.floor
		assert_false(plan.add_plot(_plot(&"under_the_street",
			[Vector2i(under_cell.x, under_cell.z)] as Array[Vector2i],
			under_floor,
			under_floor + WarrenMazeSourcePlan.MIN_HOUSE_BANDS)),
			"a plot needs its own clearance, not just something solid below")
		assert_string_contains(plan.last_rejection, "support rule 2")
	assert_eq(plan.plots.size(), 0, "a rejected plot is never stored")
	var site := _tunnel_roof_site(plan)
	assert_false(site.is_empty(),
		"the compact fixture keeps a covered market passage")
	if site.is_empty():
		return
	var roof_cell: Vector3i = site.cell
	var roof_floor: int = site.floor
	var roof_column := Vector2i(roof_cell.x, roof_cell.z)
	assert_true(plan.plot_support_ok(roof_column, roof_floor),
		"one band above a tunnel's headroom is a solid roof slab")
	assert_true(plan.add_plot(_plot(&"tunnel_roof",
		[roof_column] as Array[Vector2i], roof_floor,
		roof_floor + WarrenMazeSourcePlan.MIN_HOUSE_BANDS)),
		plan.last_rejection)
	assert_eq(plan.plots.size(), 1)
	assert_true(bool(plan.plot_facts(plan.plots[0]).bears_on_rock),
		"the retained roof slab is the plot's rock")
	assert_true(plan.seal(), plan.last_rejection)


func test_solid_at_derives_rock_under_plots_and_air_above() -> void:
	var plan := _unsealed_fixture()
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	var columns := _clean_columns(plan, 1, 9)
	assert_eq(columns.size(), 1, "the compact fixture keeps a deep clean column")
	if columns.is_empty():
		return
	var column := columns[0]
	var base := plan.massif.base_at(column)
	var floor_band := base + 2
	var top_band := floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS
	assert_true(plan.solid_at(Vector3i(column.x, top_band, column.y)),
		"the envelope stands on a column with no plot")
	assert_true(plan.add_plot(_plot(&"grounded", [column] as Array[Vector2i],
		floor_band, top_band)), plan.last_rejection)
	assert_true(plan.solid_at(Vector3i(column.x, base - 1, column.y)),
		"terrain below the sampled band is solid ground")
	assert_true(plan.solid_at(Vector3i(column.x, base, column.y)),
		"rock fills the column from terrain up to the lowest plot floor")
	assert_true(plan.solid_at(Vector3i(column.x, floor_band - 1, column.y)),
		"rock reaches the band the plot bears on")
	for band in range(floor_band, top_band):
		assert_true(plan.solid_at(Vector3i(column.x, band, column.y)),
			"band %d is inside the plot" % band)
	assert_false(plan.solid_at(Vector3i(column.x, top_band, column.y)),
		"the envelope above a plot's top is air, not leftover rock")
	var facts: Dictionary = plan.plot_facts(plan.plots[0])
	assert_true(bool(facts.bears_on_rock), "the plot's floor stands on rock")
	assert_true(bool(facts.roofed), "no plot stands on this plot's top")
	var street := plan.passage_cells()[0]
	assert_false(plan.solid_at(street), "a carved street cell is air")
	for band in range(street.y, plan.passage_headroom_top(street)):
		assert_false(plan.solid_at(Vector3i(street.x, band, street.z)),
			"passage headroom band %d is air" % band)
	assert_false(plan.solid_at(Vector3i(1 << 20, base, 1 << 20)),
		"a column outside the massif is air everywhere")
	assert_eq(plan.rock_shoulder(column), floor_band,
		"a column carrying a plot answers with its own lowest floor")
	var neighbour := column
	for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
		if plan.massif.has_column(column + direction):
			neighbour = column + direction
			break
	assert_ne(neighbour, column, "the fixture column has a massif neighbour")
	assert_eq(plan.rock_shoulder(neighbour), plan.massif.top_at(neighbour),
		"the envelope stands on a no-plot column while the plan is open")
	assert_true(plan.seal(), plan.last_rejection)
	assert_eq(plan.rock_shoulder(neighbour), floor_band,
		"sealing steps leftover rock down to the plot bordering its region")
	assert_false(plan.solid_at(Vector3i(neighbour.x, floor_band, neighbour.y)),
		"nothing stands above a sealed shoulder")


func test_stack_invariant_rejects_a_floating_plot_at_seal() -> void:
	var grounded := _unsealed_fixture()
	assert_not_null(grounded, WarrenMazeCarver.last_failure)
	var columns := _clean_columns(grounded, 1, 11)
	assert_eq(columns.size(), 1, "the compact fixture keeps a deep clean column")
	if columns.is_empty():
		return
	var column := columns[0]
	var base := grounded.massif.base_at(column)
	# The envelope supports a plot anywhere while the plan is unsealed, so a
	# single high plot is legal: the rock below it derives down to terrain.
	assert_true(grounded.add_plot(_plot(&"upper",
		[column] as Array[Vector2i], base + 6, base + 10)),
		grounded.last_rejection)
	assert_true(grounded.seal(), grounded.last_rejection)
	var floating := _unsealed_fixture()
	var floating_column := _clean_columns(floating, 1, 11)[0]
	var floating_base := floating.massif.base_at(floating_column)
	assert_eq(floating_column, column, "both fixtures pick the same column")
	assert_true(floating.add_plot(_plot(&"upper",
		[floating_column] as Array[Vector2i], floating_base + 6,
		floating_base + 10)), floating.last_rejection)
	# Adding a lower plot pulls the derived rock down to ITS floor, which
	# strands the upper plot over three bands of open air.
	assert_true(floating.add_plot(_plot(&"lower",
		[floating_column] as Array[Vector2i], floating_base,
		floating_base + 3)), floating.last_rejection)
	assert_false(floating.solid_at(Vector3i(floating_column.x,
		floating_base + 5, floating_column.y)), "the gap is real air")
	assert_false(floating.seal(), "a floating plot may not seal")
	assert_string_contains(floating.last_rejection, "floats")
	assert_false(floating.is_sealed())


func test_signature_covers_plots() -> void:
	var bare := _unsealed_fixture()
	assert_not_null(bare, WarrenMazeCarver.last_failure)
	assert_true(bare.seal(), bare.last_rejection)
	assert_false(bare.deterministic_signature().contains("plot:"),
		"a town with no plots signs no plot lines")
	var first := _unsealed_fixture()
	var second := _unsealed_fixture()
	var sites := _clean_columns(first, 2, 8)
	assert_eq(sites.size(), 2, "the compact fixture keeps two clean columns")
	if sites.size() < 2:
		return
	var alpha := _plot(&"alpha", [sites[0]] as Array[Vector2i],
		first.massif.base_at(sites[0]),
		first.massif.base_at(sites[0]) + WarrenMazeSourcePlan.MIN_HOUSE_BANDS)
	var beta := _plot(&"beta", [sites[1]] as Array[Vector2i],
		first.massif.base_at(sites[1]),
		first.massif.base_at(sites[1]) + WarrenMazeSourcePlan.MIN_HOUSE_BANDS)
	assert_true(first.add_plot(alpha), first.last_rejection)
	assert_true(first.add_plot(beta), first.last_rejection)
	assert_true(second.add_plot(beta), second.last_rejection)
	assert_true(second.add_plot(alpha), second.last_rejection)
	assert_true(first.seal(), first.last_rejection)
	assert_true(second.seal(), second.last_rejection)
	assert_true(first.deterministic_signature().contains("plot:alpha:house:"),
		"a plot signs its id and kind")
	assert_eq(first.deterministic_signature(),
		second.deterministic_signature(),
		"plot lines sort by id, so the order they were added cannot show")
	assert_ne(bare.deterministic_signature(),
		first.deterministic_signature(),
		"a plot must change the sealed identity")

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
	# ...but it never steps down THROUGH a street. Every passage keeps the
	# mass it stands on and every covered passage keeps its roof slab, on
	# columns that carry no plot of their own. A cell whose own floor band is
	# carved is a lower street's headroom eating an upper street's floor --
	# the plot layer cannot repair that, so it is counted, not asserted away.
	var undercut := 0
	var ungrounded := 0
	var covered_count := 0
	var roofless := 0
	for street_cell: Vector3i in plan.passage_cells():
		var below := Vector3i(street_cell.x, street_cell.y - 1, street_cell.z)
		if plan.excavation.carved.has(below):
			undercut += 1
		elif not plan.solid_at(below):
			ungrounded += 1
		if not bool(plan.excavation.covered.get(street_cell, false)):
			continue
		covered_count += 1
		if not plan.solid_at(Vector3i(street_cell.x,
				plan.passage_headroom_top(street_cell), street_cell.z)):
			roofless += 1
	assert_gt(covered_count, 0, "the fixture keeps covered passages")
	assert_eq(ungrounded, 0,
		"a sealed shoulder never cuts the ground from under a street")
	assert_eq(roofless, 0, "a covered passage keeps its retained roof slab")
	assert_eq(int(plan.audit.street_floor_gaps), undercut,
		"street_floor_gaps audits exactly the undercut streets")


func test_add_plot_on_a_sealed_plan_changes_nothing() -> void:
	var plan := _unsealed_fixture()
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	var columns := _clean_columns(plan, 2, 8)
	assert_eq(columns.size(), 2, "the compact fixture keeps two clean columns")
	if columns.size() < 2:
		return
	var column := columns[0]
	var floor_band := plan.massif.base_at(column) + 2
	assert_true(plan.add_plot(_plot(&"only", [column] as Array[Vector2i],
		floor_band, floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS)),
		plan.last_rejection)
	assert_true(plan.seal(), plan.last_rejection)
	var bare := columns[1]
	var shoulder := plan.rock_shoulder(bare)
	var probe := Vector3i(bare.x, shoulder, bare.y)
	assert_eq(shoulder, floor_band,
		"the sealed shoulder steps down to the only plot in town")
	assert_false(plan.solid_at(probe), "nothing stands above a shoulder")
	# A plot that would have been perfectly legal an instant before the seal.
	var bare_base := plan.massif.base_at(bare)
	assert_false(plan.add_plot(_plot(&"too_late", [bare] as Array[Vector2i],
		bare_base, bare_base + WarrenMazeSourcePlan.MIN_HOUSE_BANDS)),
		"a sealed plan accepts no plot")
	assert_string_contains(plan.last_rejection, "sealed")
	assert_eq(plan.plots.size(), 1, "the sealed town keeps its one plot")
	assert_eq(plan.rock_shoulder(bare), shoulder,
		"a refused plot may not move a sealed plan's derived rock")
	assert_false(plan.solid_at(probe),
		"a refused plot may not raise a sealed plan's derived rock")


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
	# A rejected seal leaves the plan exactly as open as it found it: the
	# shoulders that attempt computed must not outlive it, or the next plot
	# would be judged against a town that never sealed.
	var spare := _clean_columns(floating, 3, 8)
	assert_gte(spare.size(), 2, "the fixture keeps spare clean columns")
	if spare.size() < 2:
		return
	var open_column := spare[1] if spare[0] == floating_column else spare[0]
	assert_eq(floating.rock_shoulder(open_column),
		floating.massif.top_at(open_column),
		"the envelope stands again after a rejected seal")
	var open_base := floating.massif.base_at(open_column)
	assert_true(floating.add_plot(_plot(&"after_the_failure",
		[open_column] as Array[Vector2i], open_base + 2,
		open_base + 2 + WarrenMazeSourcePlan.MIN_HOUSE_BANDS)),
		floating.last_rejection)


func test_add_plot_rejects_a_plot_overlapping_one_already_standing() -> void:
	## Ported from the deleted constructive suite's
	## test_seal_rejects_pairwise_overlapping_claims (task B4): claims are gone,
	## but their disjointness rule survives as the plot model's own, and it is
	## now checked in BOTH directions -- add_plot refuses the newcomer, and
	## seal re-derives the same rule over a town doctored behind add_plot's
	## back, so the gate is never the only thing standing between the model and
	## two buildings in the same band.
	var plan := _unsealed_fixture()
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	var columns := _clean_columns(plan, 2, 10)
	assert_eq(columns.size(), 2, "the compact fixture keeps two clean columns")
	if columns.size() < 2:
		return
	var column := columns[0]
	var base := plan.massif.base_at(column)
	var span := WarrenMazeSourcePlan.MIN_HOUSE_BANDS
	assert_true(plan.add_plot(_plot(&"first", [column] as Array[Vector2i],
		base, base + span)), plan.last_rejection)
	# Straddling: its floor sits inside the first plot's own band interval.
	assert_false(plan.add_plot(_plot(&"straddler",
		[column] as Array[Vector2i], base + span - 1, base + 2 * span)),
		"a plot may not share a band with one already on the column")
	assert_string_contains(plan.last_rejection, "overlaps plot first")
	assert_eq(plan.plots.size(), 1, "a refused plot is never stored")
	# Flush above is not an overlap: [floor, top) is half-open, so a second
	# plot starting exactly at the first one's top is a legal upper storey.
	assert_true(plan.add_plot(_plot(&"stacked", [column] as Array[Vector2i],
		base + span, base + 2 * span)), plan.last_rejection)
	# A deck reserves its single floor band even though it adds no mass, so
	# nothing else may claim that band either.
	assert_true(plan.add_plot(_plot(&"roof_deck",
		[column] as Array[Vector2i], base + 2 * span, base + 2 * span,
		WarrenMazeSourcePlan.PLOT_DECK)), plan.last_rejection)
	assert_false(plan.add_plot(_plot(&"over_the_deck",
		[column] as Array[Vector2i], base + 2 * span,
		base + 2 * span + span)),
		"a deck's own floor band is reserved against everything else")
	assert_string_contains(plan.last_rejection, "overlaps plot roof_deck")
	# Seal re-derives the rule rather than trusting add_plot ever ran: a plot
	# appended straight onto `plots` must still be rejected.
	plan.plots.append({"id": &"smuggled",
		"kind": WarrenMazeSourcePlan.PLOT_HOUSE,
		"cells": [column] as Array[Vector2i], "floor": base,
		"top": base + span, "door_walk": Vector3i.ZERO,
		"building_id": &"smuggled"})
	assert_false(plan.seal(), "a smuggled overlapping plot may not seal")
	assert_string_contains(plan.last_rejection, "overlaps plot")


func test_passage_headroom_is_a_per_cell_fact_not_a_constant() -> void:
	## Ported from the deleted constructive suite (task B4), re-derived against
	## plots instead of the ledger. `passage_headroom_top` is cell.y +
	## excavation.slot_bands(cell) -- NOT cell.y +
	## WarrenExcavation.HEADROOM_BANDS, which undercounts a stair/ramp
	## intermediate stride cell's own taller carved slot (it carries both
	## treads). The corpus must contain such a cell, and the band the flat
	## constant would have called free above it -- really still inside the
	## carved slot -- must carry no plot and no derived mass.
	var taller_slots := 0
	var probed := 0
	for spec: Dictionary in PLANNER_SEEDS:
		var seed_value := int(spec["seed"])
		var scale := StringName(spec["scale"])
		var plan := _sealed_town(seed_value, scale)
		assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
		if plan == null:
			continue
		for cell: Vector3i in plan.passage_cells():
			var slot := plan.excavation.slot_bands(cell)
			assert_eq(plan.passage_headroom_top(cell), cell.y + slot,
				"passage_headroom_top is the cell's own carved slot")
			if slot <= WarrenExcavation.HEADROOM_BANDS:
				continue
			taller_slots += 1
			# The exact band the constant would have freed. It is inside the
			# real slot, so it is carved: no plot may claim it and nothing
			# derives mass there.
			var column := Vector2i(cell.x, cell.z)
			var band := cell.y + WarrenExcavation.HEADROOM_BANDS
			probed += 1
			assert_false(plan.solid_at(Vector3i(column.x, band, column.y)),
				("seed %d %s: band %d over passage %s is inside its real " \
					+ "carved slot (%d bands) and may not be solid") \
					% [seed_value, scale, band, cell, slot])
			for plot: Dictionary in plan.plots:
				if not (plot["cells"] as Array).has(column):
					continue
				var floor_band := int(plot["floor"])
				var reserved := maxi(int(plot["top"]), floor_band + 1)
				assert_false(band >= floor_band and band < reserved,
					("seed %d %s: plot %s covers band %d, inside passage " \
						+ "%s's own %d-band carved slot") \
						% [seed_value, scale, plot["id"], band, cell, slot])
	assert_gt(taller_slots, 0,
		"the corpus must carve at least one stair/ramp cell whose real slot " \
			+ "exceeds HEADROOM_BANDS, or the flat constant is never wrong")
	gut.p("passage cells with a slot taller than HEADROOM_BANDS: %d (%d probed)" \
		% [taller_slots, probed])


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
	# Every field a plot signs has to reach the signature: two towns whose
	# plots differ in exactly one of them may not sign alike.
	for field: String in ["door_walk", "building_id"]:
		var variant := _unsealed_fixture()
		var changed := alpha.duplicate()
		changed[field] = Vector3i(3, 4, 5) if field == "door_walk" \
			else &"another_building"
		assert_true(variant.add_plot(changed), variant.last_rejection)
		assert_true(variant.add_plot(beta), variant.last_rejection)
		assert_true(variant.seal(), variant.last_rejection)
		assert_ne(first.deterministic_signature(),
			variant.deterministic_signature(),
			"%s is part of a plot's sealed identity" % field)


# --- WarrenPlotPlanner (task B2) --------------------------------------------
# P3 (assets, decks) and P4 (houses, heights, bridges). Every fact below is
# measured off the sealed plan and falsified against an independent
# re-derivation from the still-unsealed carve-stage plan, never against the
# planner's own bookkeeping.

## The four (seed, scale) towns the plot-planner facts are measured on. Two
## compact and two standard: enough spread for tiers and bridges to appear
## without pushing the file past its ~60 s budget.
const PLANNER_SEEDS: Array[Dictionary] = [
	{"seed": 12, "scale": &"compact"},
	{"seed": 4, "scale": &"compact"},
	{"seed": 3, "scale": &"standard"},
	{"seed": 9, "scale": &"standard"},
]
## Measured share of buildable columns that end up inside a plot, minus a 0.05
## guard. Re-pin upward only, and never silently: a drop is a regression to
## report. See test_partition_fills_every_street_fronting_column.
##
## History: 0.954, then 0.892 when the review round rolled each building its own
## footprint cap and refused asset sites that would leave a street's floor
## hanging, now 0.965 -- the orphan sweep hands every still-joinable free column
## to the smallest building beside it, cap or no cap, because coverage beats
## size variation.
const BUILDABLE_COVERAGE_FLOOR := 0.91
## Measured share of street-fronting (column, band) slots that carry a plot at
## that band, minus a 0.05 guard. Same discipline: re-pin upward only.
const FRONTING_SLOT_FLOOR := 0.85
## Measured mean house footprint in macro columns, minus a 0.2 guard. A seed
## whose streets isolate their columns keeps single-column houses -- legal 1x1
## towers -- so this is pinned from the weakest measured town (2.06), not from
## an aspiration.
const FOOTPRINT_FLOOR := 1.8

static var _sealed_plans: Dictionary = {}
static var _carved_plans: Dictionary = {}
static var _volumes: Dictionary = {}
static var _parcel_plans: Dictionary = {}
static var _parcel_failures: Dictionary = {}


func _sealed_town(seed_value: int, scale: StringName) -> WarrenMazeSourcePlan:
	## One sealed plan per (seed, scale), built once and shared by every test
	## in this file -- the whole pipeline is pure, so a cached plan is the same
	## plan a fresh call would build.
	var key := "%d/%s" % [seed_value, scale]
	if not _sealed_plans.has(key):
		_sealed_plans[key] = WarrenMazeSitePlanner.plan(seed_value, {},
			WarrenVillageScaleProfile.for_id(scale))
	return _sealed_plans[key] as WarrenMazeSourcePlan


func _carved_town(seed_value: int, scale: StringName) -> WarrenMazeSourcePlan:
	## The same town stopped straight after the bore: no plot has been placed,
	## so it answers "what did the massif and the excavation alone allow here"
	## without any of the planner's own decisions folded in.
	var key := "%d/%s" % [seed_value, scale]
	if not _carved_plans.has(key):
		_carved_plans[key] = WarrenMazeSitePlanner.plan(seed_value, {},
			WarrenVillageScaleProfile.for_id(scale), &"carve")
	return _carved_plans[key] as WarrenMazeSourcePlan


func _plots_of_kind(plan: WarrenMazeSourcePlan,
		kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for plot: Dictionary in plan.plots:
		if StringName(plot["kind"]) == kind:
			out.append(plot)
	return out


func _template_for(kind_id: StringName) -> Dictionary:
	for template: Dictionary in WarrenPlotReservations.ASSET_TEMPLATES:
		if StringName(template["kind_id"]) == kind_id:
			return template
	return {}


func _street_bands(plan: WarrenMazeSourcePlan) -> Dictionary:
	## Vector2i column -> Array[int] of the bands a passage walks there.
	var out: Dictionary = {}
	for cell: Vector3i in plan.passage_cells():
		var column := Vector2i(cell.x, cell.z)
		var bands: Array = out.get(column, [])
		if not bands.has(cell.y):
			bands.append(cell.y)
		out[column] = bands
	return out


func _asset_sites(plan: WarrenMazeSourcePlan) -> Array[Dictionary]:
	## Every street-fronting, supportable asset site on a plot-free plan, with
	## its terrain-modification cost -- the test's own enumeration of the
	## candidate set the planner claims to have taken a minimum over.
	var out: Array[Dictionary] = []
	var streets := _street_bands(plan)
	var columns := _sorted_columns(plan)
	for template: Dictionary in WarrenPlotReservations.ASSET_TEMPLATES:
		var height := int(template["height_bands"])
		for orientation in 2:
			var width := int(template["width"]) if orientation == 0 \
				else int(template["depth"])
			var depth := int(template["depth"]) if orientation == 0 \
				else int(template["width"])
			for anchor: Vector2i in columns:
				var footprint: Array[Vector2i] = []
				var inside := true
				for dz in depth:
					for dx in width:
						var member := anchor + Vector2i(dx, dz)
						if not plan.massif.has_column(member):
							inside = false
							break
						footprint.append(member)
					if not inside:
						break
				if not inside:
					continue
				var members: Dictionary = {}
				for member: Vector2i in footprint:
					members[member] = true
				var datums: Dictionary = {}
				for member: Vector2i in footprint:
					for direction: Vector2i in \
							WarrenPassageLatticeRules.DIRECTIONS:
						var next := member + direction
						if members.has(next):
							continue
						for band: int in streets.get(next, []) as Array:
							datums[band] = true
				var bands: Array = datums.keys()
				bands.sort()
				for datum: int in bands:
					var cost := 0
					var supported := true
					for member: Vector2i in footprint:
						var hanging := false
						for band: int in streets.get(member, []) as Array:
							hanging = hanging or band >= datum \
								and band != datum + height
						if hanging or not plan.plot_support_ok(member, datum) \
								or plan.first_carved_band(member, datum,
									datum + height) >= 0:
							supported = false
							break
						cost += absi(plan.massif.top_at(member) - datum)
					if not supported:
						continue
					out.append({"kind_id": StringName(template["kind_id"]),
						"orientation": orientation, "anchor": anchor,
						"datum": datum, "cost": cost,
						"cells": footprint.duplicate()})
	return out


func test_asset_templates_match_the_catalog() -> void:
	# ASSET_TEMPLATES is a table so the planner stays program-free: it may
	# never load the catalog at runtime. This is the only thing that keeps the
	# table honest -- it re-derives the macro footprints straight from the
	# compiled fabric program and demands the table equal them exactly.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert_not_null(program, "the settlement fabric program must compile")
	if program == null:
		return
	var expected: Array[Dictionary] = []
	var seen: Dictionary = {}
	for recipe_value: FabricRecipe in program.recipes():
		if not recipe_value.has_tag(&"prefab_anchor"):
			continue
		var fine := recipe_value.local_clearance_bounds.size \
			/ FabricRecipe.CELL_SIZE
		var footprint := Vector3i(ceili(fine.x / 2.0), ceili(fine.z / 2.0),
			ceili(fine.y))
		if seen.has(footprint):
			continue
		seen[footprint] = true
		expected.append({"kind_id": recipe_value.recipe_id,
			"width": footprint.x, "depth": footprint.y,
			"height_bands": footprint.z})
	assert_gt(expected.size(), 0, "the catalog ships prefab anchor recipes")
	assert_eq(WarrenPlotReservations.ASSET_TEMPLATES.size(), expected.size(),
		"one template per unique macro footprint in the catalog")
	for index in mini(WarrenPlotReservations.ASSET_TEMPLATES.size(),
			expected.size()):
		var actual := WarrenPlotReservations.ASSET_TEMPLATES[index] \
			as Dictionary
		var wanted := expected[index] as Dictionary
		assert_eq(StringName(actual.get("kind_id", &"")),
			StringName(wanted["kind_id"]),
			"template %d names its catalog recipe" % index)
		for field: String in ["width", "depth", "height_bands"]:
			assert_eq(int(actual.get(field, -1)), int(wanted[field]),
				"template %d %s" % [index, field])
	gut.p("ASSET_TEMPLATES: %d unique macro footprints from %d recipes" % [
		expected.size(), WarrenPlotReservations.ASSET_TEMPLATES.size()])


func test_assets_sit_at_the_minimum_modification_site() -> void:
	var plan := _sealed_town(12, &"compact")
	assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
	if plan == null:
		return
	var assets := _plots_of_kind(plan, WarrenMazeSourcePlan.PLOT_ASSET)
	var outcomes: Dictionary = plan.audit.get("plot_outcomes", {})
	var records: Array = outcomes.get("assets", [])
	assert_gt(records.size(), 0, "the scale quota asks for assets")
	assert_gt(assets.size(), 0, "seed 12 compact places at least one asset")
	if assets.is_empty():
		return
	var carved := _carved_town(12, &"compact")
	var sites := _asset_sites(carved)
	assert_gt(sites.size(), 0, "the test enumerates candidate sites of its own")
	var best := sites[0].cost as int
	for site: Dictionary in sites:
		best = mini(best, int(site["cost"]))
	# The FIRST asset is the one placed against an empty town, so its site is
	# comparable with an enumeration that knows nothing about the others.
	var first := assets[0] as Dictionary
	var template := _template_for(StringName(
		(records[0] as Dictionary).get("kind_id", &"")))
	assert_false(template.is_empty(), "a placed asset names a real template")
	var datum := int(first["floor"])
	var cost := 0
	for cell_value: Variant in first["cells"] as Array:
		var column := cell_value as Vector2i
		assert_true(carved.plot_support_ok(column, datum),
			"asset column %s is supportable at its datum" % column)
		cost += absi(plan.massif.top_at(column) - datum)
	assert_eq(cost, best,
		"the asset stands at the minimum terrain-modification cost")
	for plot: Dictionary in assets:
		var members: Array = plot["cells"]
		var sizes: Dictionary = {"x": {}, "z": {}}
		for cell_value: Variant in members:
			var column := cell_value as Vector2i
			(sizes["x"] as Dictionary)[column.x] = true
			(sizes["z"] as Dictionary)[column.y] = true
		assert_eq(members.size(),
			(sizes["x"] as Dictionary).size() \
				* (sizes["z"] as Dictionary).size(),
			"asset %s is a solid rectangle" % plot["id"])
		var door: Vector3i = plot["door_walk"]
		assert_true(plan.passage_kinds.has(door),
			"asset %s fronts a real street cell" % plot["id"])
		assert_eq(door.y, int(plot["floor"]),
			"asset %s takes its datum from the street it fronts" % plot["id"])
		assert_eq(StringName(plot["building_id"]), StringName(plot["id"]),
			"asset %s is its own building" % plot["id"])
	gut.p("seed 12 compact: %d/%d assets placed, min cost %d" % [
		assets.size(), records.size(), best])


func test_decks_are_flat_street_level_regions() -> void:
	var total := 0
	var refused := 0
	for spec: Dictionary in PLANNER_SEEDS:
		var seed_value := int(spec["seed"])
		var scale := StringName(spec["scale"])
		var plan := _sealed_town(seed_value, scale)
		assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
		if plan == null:
			continue
		var carved := _carved_town(seed_value, scale)
		var quota: Vector2i = WarrenPlotReservations.DECK_QUOTA[scale]
		var cap: int = WarrenPlotReservations.DECK_MAX[scale]
		var decks := _plots_of_kind(plan, WarrenMazeSourcePlan.PLOT_DECK)
		total += decks.size()
		assert_lte(decks.size(), quota.y,
			"seed %d never exceeds its deck quota" % seed_value)
		# Every region the source plan refused has to say why, and the shortfall
		# has to be audited -- a silently dropped deck is the bug this test was
		# written for.
		var outcomes: Dictionary = plan.audit.get("plot_outcomes", {})
		var accepted := 0
		for record: Dictionary in outcomes.get("decks", []) as Array:
			if String(record["reason"]) == "":
				accepted += 1
				continue
			refused += 1
			assert_gte(String(record["reason"]).length(), 1,
				"a refused deck records the source plan's reason")
		assert_eq(accepted, decks.size(),
			"seed %d audits exactly the decks that stand" % seed_value)
		assert_eq(int(outcomes.get("decks_short", -1)), quota_short(plan,
			accepted), "seed %d audits its deck shortfall" % seed_value)
		for deck: Dictionary in decks:
			var datum := int(deck["floor"])
			assert_eq(int(deck["top"]), datum,
				"deck %s is flat" % deck["id"])
			var cells: Array = deck["cells"]
			assert_gte(cells.size(), WarrenPlotReservations.DECK_MIN,
				"deck %s clears the deck minimum" % deck["id"])
			assert_lte(cells.size(), cap,
				"deck %s stays inside the scale's area cap" % deck["id"])
			var members: Dictionary = {}
			for cell_value: Variant in cells:
				members[cell_value as Vector2i] = true
			# One connected floor: a deck grown from two opposite neighbours of
			# the same street cell would be two islands.
			assert_eq(_connected_size(members, cells[0] as Vector2i),
				cells.size(), "deck %s is one 4-connected region" % deck["id"])
			for cell_value: Variant in cells:
				var column := cell_value as Vector2i
				assert_lte(absi(plan.massif.top_at(column) - datum), 1,
					"deck %s cell %s is within a band of its datum" % [
						deck["id"], column])
				assert_true(carved.plot_support_ok(column, datum),
					"deck %s cell %s is supportable at the datum" % [
						deck["id"], column])
			var door: Vector3i = deck["door_walk"]
			assert_true(plan.passage_kinds.has(door),
				"deck %s grew off a real street cell" % deck["id"])
			assert_eq(door.y, datum, "deck %s sits at its street's band" \
				% deck["id"])
			var touches := false
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				touches = touches \
					or members.has(Vector2i(door.x, door.z) + direction)
			assert_true(touches, "deck %s adjoins the street it grew from" \
				% deck["id"])
	assert_gt(total, 0, "the corpus grows at least one deck")
	gut.p("decks across the four towns: %d standing, %d refused" % [total,
		refused])


func quota_short(plan: WarrenMazeSourcePlan, accepted: int) -> int:
	## The shortfall the planner should have audited: the scale's own quota roll
	## minus what stands. Re-rolled here from the plan's seed rather than read
	## back out of the audit it is checking.
	var quota := WarrenPlotPlanner.roll(plan,
		WarrenPlotReservations.DECK_QUOTA_SALT, plan.summit_cell, 0,
		WarrenPlotReservations.DECK_QUOTA[plan.scale_profile.scale_id])
	return quota - accepted


func _connected_size(members: Dictionary, start: Vector2i) -> int:
	var out: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	var head := 0
	while head < out.size():
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var next := out[head] + direction
			if members.has(next) and not seen.has(next):
				seen[next] = true
				out.append(next)
		head += 1
	return out.size()


func test_partition_fills_every_street_fronting_column() -> void:
	var demanded := 0
	var supplied := 0
	var buildable := 0
	var buildable_in_plot := 0
	var slots := 0
	var slots_filled := 0
	for spec: Dictionary in PLANNER_SEEDS:
		var seed_value := int(spec["seed"])
		var scale := StringName(spec["scale"])
		var plan := _sealed_town(seed_value, scale)
		assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
		if plan == null:
			continue
		var carved := _carved_town(seed_value, scale)
		var owned: Dictionary = {}
		for plot: Dictionary in plan.plots:
			for cell_value: Variant in plot["cells"] as Array:
				owned[cell_value as Vector2i] = true
		# Demand, re-derived from the carve-stage plan alone: a column a street
		# fronts and the support rule accepts at that street's own band.
		var fronting: Dictionary = {}
		for cell: Vector3i in carved.passage_cells():
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				var column := Vector2i(cell.x, cell.z) + direction
				if not carved.massif.has_column(column):
					continue
				if carved.plot_support_ok(column, cell.y):
					fronting[column] = true
		var missing := 0
		for column: Vector2i in fronting:
			if not owned.has(column):
				missing += 1
		demanded += fronting.size()
		supplied += fronting.size() - missing
		# The finer measure the model actually promises: a house per
		# (column, band), not merely something somewhere on the column.
		var filled := 0
		for slot: Vector3i in demanded_slots(carved):
			slots += 1
			for plot: Dictionary in plan.plots:
				var floor_band := int(plot["floor"])
				var reserved := maxi(int(plot["top"]), floor_band + 1)
				if slot.y >= floor_band and slot.y < reserved \
						and (plot["cells"] as Array).has(
							Vector2i(slot.x, slot.z)):
					filled += 1
					break
		slots_filled += filled
		# Pencil houses were the shape the design rejected; growth absorbs bare
		# neighbouring seeds so a block reads as buildings.
		var houses := _plots_of_kind(plan, WarrenMazeSourcePlan.PLOT_HOUSE)
		var footprint := 0
		for plot: Dictionary in houses:
			footprint += (plot["cells"] as Array).size()
		var mean := float(footprint) / float(maxi(1, houses.size()))
		gut.p("seed %d %s: %d houses, mean footprint %.2f columns" % [
			seed_value, scale, houses.size(), mean])
		var singles := 0
		var mergeable := 0
		for plot: Dictionary in houses:
			if (plot["cells"] as Array).size() != 1:
				continue
			singles += 1
			mergeable += int(_beside_a_peer(plan, plot))
		gut.p("  %d single-column houses, %d of them beside a same-floor peer" \
			% [singles, mergeable])
		# Pinned at measured-minus-guard, not at a round number: a seed whose
		# streets isolate their columns leaves 1x1 towers the grammar builds
		# perfectly well -- the massif's geometry, not a partition bug.
		assert_gte(mean, FOOTPRINT_FLOOR,
			"seed %d %s grows buildings, not pencils" % [seed_value, scale])
		var limit: int = WarrenPlotPlanner.BUILDING_CAP[scale]
		var over := 0
		for plot: Dictionary in houses:
			over += int((plot["cells"] as Array).size() > limit)
		gut.p("  %d houses past BUILDING_CAP %d, %d columns swept in" % [over,
			limit, int((plan.audit.get("plot_outcomes", {}) as Dictionary) \
				.get("orphan_sweep_joined", 0))])
		assert_eq(missing, 0,
			"seed %d %s leaves %d street-fronting column(s) out of every plot" \
				% [seed_value, scale, missing])
		# The broader measure: every column with room for a house in it at all.
		for column: Vector2i in _sorted_columns(carved):
			var longest := 0
			var run := 0
			for band in range(carved.massif.base_at(column),
					carved.massif.top_at(column)):
				run = 0 if carved.excavation.carved.has(
					Vector3i(column.x, band, column.y)) else run + 1
				longest = maxi(longest, run)
			if longest < WarrenMazeSourcePlan.MIN_HOUSE_BANDS:
				continue
			buildable += 1
			buildable_in_plot += int(owned.has(column))
	assert_gt(demanded, 0, "the corpus has street-fronting columns to fill")
	assert_eq(supplied, demanded,
		"every street-fronting supportable column is in a plot")
	var share := float(buildable_in_plot) / float(maxi(1, buildable))
	gut.p("buildable columns in a plot: %d/%d = %.3f (floor %.2f)" % [
		buildable_in_plot, buildable, share, BUILDABLE_COVERAGE_FLOOR])
	assert_gte(share, BUILDABLE_COVERAGE_FLOOR,
		"the share of buildable columns inside a plot holds its pinned floor")
	var slot_share := float(slots_filled) / float(maxi(1, slots))
	gut.p("street-fronting (column, band) slots: %d/%d = %.3f (floor %.2f)" % [
		slots_filled, slots, slot_share, FRONTING_SLOT_FLOOR])
	assert_gte(slot_share, FRONTING_SLOT_FLOOR,
		"the per-(column, band) share holds its pinned floor")


func _beside_a_peer(plan: WarrenMazeSourcePlan, plot: Dictionary) -> bool:
	## Could growth still have swallowed this one-column house -- is another
	## house standing at the same floor right beside it? Separates "the cap ran
	## out" from "there was nothing there to take".
	var column: Vector2i = (plot["cells"] as Array)[0]
	var house := WarrenMazeSourcePlan.PLOT_HOUSE
	for other: Dictionary in plan.plots:
		if StringName(other["id"]) == StringName(plot["id"]) \
				or StringName(other["kind"]) != house \
				or int(other["floor"]) != int(plot["floor"]):
			continue
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			if (other["cells"] as Array).has(column + direction):
				return true
	return false


func demanded_slots(carved: WarrenMazeSourcePlan) -> Array[Vector3i]:
	## Every (column, band) a street fronts and the support rule accepts, read
	## off the plot-free carve-stage plan, so the demand owes the planner
	## nothing.
	var out: Array[Vector3i] = []
	var seen: Dictionary = {}
	for cell: Vector3i in carved.passage_cells():
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var column := Vector2i(cell.x, cell.z) + direction
			var slot := Vector3i(column.x, cell.y, column.y)
			if seen.has(slot) or not carved.massif.has_column(column) \
					or not carved.plot_support_ok(column, cell.y):
				continue
			seen[slot] = true
			out.append(slot)
	return out


func test_houses_rise_to_meet_upper_streets() -> void:
	var tiered := 0
	var houses := 0
	var skipped := 0
	for spec: Dictionary in PLANNER_SEEDS:
		var seed_value := int(spec["seed"])
		var scale := StringName(spec["scale"])
		var plan := _sealed_town(seed_value, scale)
		assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
		if plan == null:
			continue
		var outcomes: Dictionary = plan.audit.get("plot_outcomes", {})
		var records: Array = outcomes.get("buildings", [])
		var by_id: Dictionary = {}
		for plot: Dictionary in plan.plots:
			by_id[StringName(plot["id"])] = plot
		for record: Dictionary in records:
			var plot: Dictionary = by_id.get(StringName(record["id"]), {})
			if String(record["reason"]) != "":
				skipped += 1
				assert_true(plot.is_empty(),
					"a building the planner recorded as skipped never stands")
				continue
			assert_false(plot.is_empty(),
				"every audited building that reports no reason is a real plot")
			if plot.is_empty():
				continue
			houses += 1
			assert_gte(int(plot["top"]) - int(plot["floor"]),
				WarrenMazeSourcePlan.MIN_HOUSE_BANDS,
				"house %s is at least MIN_HOUSE_BANDS tall" % plot["id"])
			assert_lte(int(plot["top"]) - int(plot["floor"]),
				WarrenPlotPlanner.MAX_TIER_BANDS,
				"house %s stays under the six-storey ceiling" % plot["id"])
			if not bool(record["tiered"]):
				continue
			tiered += 1
			# A tiered roof is a street's own band, measured off the passages
			# rather than off the planner's flag.
			var apron: Dictionary = {}
			for cell_value: Variant in plot["cells"] as Array:
				var column := cell_value as Vector2i
				apron[column] = true
				for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
					apron[column + direction] = true
			var meets := false
			for cell: Vector3i in plan.passage_cells():
				meets = meets or cell.y == int(plot["top"]) \
					and apron.has(Vector2i(cell.x, cell.z))
			assert_true(meets,
				"tiered house %s tops out at a street's band" % plot["id"])
			assert_true(bool(plan.plot_facts(plot).tiered),
				"the plan derives the same tier fact for %s" % plot["id"])
	assert_gt(tiered, 0, "the corpus tiers at least one house")
	gut.p("tiered houses across the four towns: %d of %d (%d skipped)" % [
		tiered, houses, skipped])


func test_bridge_plots_sit_on_retained_spans() -> void:
	var bridges := 0
	var spans := 0
	for spec: Dictionary in PLANNER_SEEDS:
		var seed_value := int(spec["seed"])
		var scale := StringName(spec["scale"])
		var plan := _sealed_town(seed_value, scale)
		assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
		if plan == null:
			continue
		spans += plan.excavation.bridge_spans.size()
		var by_columns: Dictionary = {}
		for plot: Dictionary in _plots_of_kind(plan,
				WarrenMazeSourcePlan.PLOT_BRIDGE):
			bridges += 1
			var key := PackedStringArray()
			for cell_value: Variant in plot["cells"] as Array:
				var column := cell_value as Vector2i
				key.append("%d,%d" % [column.x, column.y])
			by_columns["+".join(key)] = plot
		for span_value: Variant in plan.excavation.bridge_spans:
			var span: Array = span_value
			var key := PackedStringArray()
			var floor_band := 0
			for cell_value: Variant in span:
				var cell := cell_value as Vector3i
				key.append("%d,%d" % [cell.x, cell.z])
				assert_true(plan.passage_kinds.has(cell),
					"a bridge span is made of passage cells")
				floor_band = maxi(floor_band,
					plan.passage_headroom_top(cell)
						+ WarrenMazeSourcePlan.TUNNEL_ROOF_BANDS)
			var plot: Dictionary = by_columns.get("+".join(key), {})
			if plot.is_empty():
				# The support rule owns this, not the planner: a span whose
				# own clearance is eaten by another street above it cannot
				# carry a bridge, and that is an audited fact, not a repair.
				assert_true(_bridge_skipped(plan, "+".join(key)),
					"span %s has a bridge or an audited reason" \
						% "+".join(key))
				continue
			assert_eq(int(plot["floor"]), floor_band,
				"bridge %s stands on the span's retained roof slab" \
					% plot["id"])
			assert_eq(int(plot["top"]),
				floor_band + WarrenBuildingParcel.STOREY_BANDS,
				"bridge %s is one storey" % plot["id"])
			assert_true(plan.solid_at(Vector3i(span[0].x, floor_band - 1,
				span[0].z)), "the span's overhead mass really was retained")
			var owner := StringName(plot["building_id"])
			if owner == StringName(plot["id"]):
				continue
			var host: Dictionary = {}
			for other: Dictionary in plan.plots:
				if StringName(other["id"]) == owner:
					host = other
			assert_false(host.is_empty(),
				"bridge %s names a real building" % plot["id"])
			if host.is_empty():
				continue
			assert_eq(int(host["floor"]), int(plot["floor"]),
				"bridge %s joins a building sharing its floor" % plot["id"])
	assert_gt(spans, 0, "the corpus retains bridge spans")
	assert_gt(bridges, 0, "retained spans become bridge plots")
	gut.p("bridges across the four towns: %d of %d retained spans" % [
		bridges, spans])


func _bridge_skipped(plan: WarrenMazeSourcePlan, columns: String) -> bool:
	## True when the planner audited a reason for the bridge that is missing
	## from these columns, so a silently dropped span still fails the test.
	for record: Dictionary in (plan.audit.get("plot_outcomes", {}) \
			as Dictionary).get("bridges", []) as Array:
		if String(record["reason"]) == "":
			continue
		var span: Array = plan.excavation.bridge_spans[int(record["span"])]
		var key := PackedStringArray()
		var seen: Dictionary = {}
		for cell_value: Variant in span:
			var cell := cell_value as Vector3i
			if seen.has(Vector2i(cell.x, cell.z)):
				continue
			seen[Vector2i(cell.x, cell.z)] = true
			key.append("%d,%d" % [cell.x, cell.z])
		if "+".join(key) == columns:
			return true
	return false


func test_planner_is_deterministic() -> void:
	for spec: Dictionary in PLANNER_SEEDS:
		var seed_value := int(spec["seed"])
		var scale := StringName(spec["scale"])
		var first := _sealed_town(seed_value, scale)
		assert_not_null(first, WarrenMazeSitePlanner.last_failure)
		var second := WarrenMazeSitePlanner.plan(seed_value, {},
			WarrenVillageScaleProfile.for_id(scale))
		assert_not_null(second, WarrenMazeSitePlanner.last_failure)
		if first == null or second == null:
			continue
		assert_eq(first.deterministic_signature(),
			second.deterministic_signature(),
			"seed %d %s signs the same town twice" % [seed_value, scale])
		assert_gt(first.plots.size(), 0,
			"seed %d %s builds a town worth signing" % [seed_value, scale])
		assert_true(first.deterministic_signature().contains("plot:house."),
			"seed %d %s partitions houses into the signature" % [seed_value,
				scale])
		assert_eq(str(first.audit.get("plot_outcomes", {})),
			str(second.audit.get("plot_outcomes", {})),
			"seed %d %s audits the same outcomes twice" % [seed_value, scale])


func test_streets_keep_their_floor() -> void:
	# The addendum's claim, pinned as equality rather than as a ceiling: the
	# plot layer never leaves a street standing over air that the bore had not
	# already left. A carve-stage gap is a lower street's headroom eating an
	# upper street's floor, which no plot can repair; anything above that count
	# is a house or an asset that built the ground out from under a street.
	for spec: Dictionary in PLANNER_SEEDS:
		var seed_value := int(spec["seed"])
		var scale := StringName(spec["scale"])
		var plan := _sealed_town(seed_value, scale)
		assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
		if plan == null:
			continue
		var bore := _carved_town(seed_value, scale).street_floor_gaps()
		var sealed_gaps := int(plan.audit.get("street_floor_gaps", -1))
		gut.p("seed %d %s: street_floor_gaps %d, the bore left %d" % [
			seed_value, scale, sealed_gaps, bore])
		assert_eq(sealed_gaps, bore,
			"seed %d %s adds no floating street" % [seed_value, scale])


# --- Adapter and translator (task B3) ---------------------------------------
# The two downstream seams read plots and nothing else: the volume is
# `solid_at` made into an envelope, and every house/asset plot becomes exactly
# one sealed parcel plus its own back rooms. Both are falsified against the
# sealed plan directly, never against the adapters' own bookkeeping.

## The 24-town corpus the translation rate is measured on: seeds 1..12 at both
## scales. `TRANSLATE_FLOOR` is the plan's own acceptance bar (22/24); it is a
## floor to re-pin upward, never downward.
const CORPUS_SEEDS := 12
const TRANSLATE_FLOOR := 22


func _volume_of(seed_value: int, scale: StringName) -> WarrenVolumePlan:
	## One adapted volume per (seed, scale). The adapter is pure over a sealed
	## plan, so this cache is the plan a fresh call would build.
	var key := "%d/%s" % [seed_value, scale]
	if not _volumes.has(key):
		_volumes[key] = WarrenMazeVolumeAdapter.to_volume_plan(
			_sealed_town(seed_value, scale))
	return _volumes[key] as WarrenVolumePlan


func _parcels_of(seed_value: int, scale: StringName) -> WarrenParcelPlan:
	## One translated parcel plan per (seed, scale), with the translator's own
	## failure text kept beside it so a corpus row can report why.
	var key := "%d/%s" % [seed_value, scale]
	if not _parcel_plans.has(key):
		var volume := _volume_of(seed_value, scale)
		var plan: WarrenParcelPlan = null
		var reason := WarrenMazeVolumeAdapter.last_failure
		if volume != null:
			plan = WarrenMazeBlockPartitioner.partition(
				_sealed_town(seed_value, scale), volume)
			reason = WarrenMazeBlockPartitioner.last_failure
		_parcel_plans[key] = plan
		_parcel_failures[key] = "" if plan != null else reason
	return _parcel_plans[key] as WarrenParcelPlan


func _parcel_failure(seed_value: int, scale: StringName) -> String:
	return String(_parcel_failures.get("%d/%s" % [seed_value, scale], ""))


func test_volume_matches_solid_at() -> void:
	# The adapter's whole contract in one sentence: the volume's mass IS the
	# plan's derived solid. Checked cell by cell over the massif, so a column
	# the adapter leaves too tall (leftover envelope) or too short (a plot cut
	# off) is a named mismatch rather than a ratio that drifts.
	for spec: Dictionary in [{"seed": 12, "scale": &"compact"},
			{"seed": 3, "scale": &"standard"}]:
		var seed_value := int(spec["seed"])
		var scale := StringName(spec["scale"])
		var plan := _sealed_town(seed_value, scale)
		assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
		if plan == null:
			continue
		var volume := _volume_of(seed_value, scale)
		assert_not_null(volume, WarrenMazeVolumeAdapter.last_failure)
		if volume == null:
			continue
		var checked := 0
		var mismatches: Array[String] = []
		for column: Vector2i in _sorted_columns(plan):
			# One band past everything the plan says this column can reach,
			# so the sweep also proves the adapter left no mass above it.
			for band in range(plan.massif.base_at(column),
					plan.column_ceiling(column) + 1):
				var cell := Vector3i(column.x, band, column.y)
				checked += 1
				if volume.has_mass(cell) == plan.solid_at(cell):
					continue
				if mismatches.size() < 6:
					mismatches.append("%s mass=%s solid=%s" % [cell,
						volume.has_mass(cell), plan.solid_at(cell)])
		gut.p("seed %d %s: %d cells checked, %d mismatched" % [seed_value,
			scale, checked, mismatches.size()])
		assert_gt(checked, 800, "the sweep must cover a real town")
		assert_eq(mismatches.size(), 0,
			"seed %d %s volume mass is solid_at: %s" % [seed_value, scale,
				"; ".join(mismatches)])


func test_translator_emits_one_parcel_group_per_building() -> void:
	# One plot, one parcel, no orphan cells: the parcel's rectangle sits
	# inside its plot, its door really serves its address, and the cells the
	# rectangle left over are all recorded as that building's back rooms.
	for spec: Dictionary in [{"seed": 12, "scale": &"compact"},
			{"seed": 3, "scale": &"standard"}]:
		var seed_value := int(spec["seed"])
		var scale := StringName(spec["scale"])
		var plan := _sealed_town(seed_value, scale)
		var parcels := _parcels_of(seed_value, scale)
		assert_not_null(parcels, "seed %d %s translation: %s" % [seed_value,
			scale, _parcel_failure(seed_value, scale)])
		if parcels == null or plan == null:
			continue
		var by_id: Dictionary = {}
		for parcel: WarrenBuildingParcel in parcels.parcels:
			assert_false(by_id.has(parcel.stable_id),
				"parcel %s is emitted once" % parcel.stable_id)
			by_id[parcel.stable_id] = parcel
		var back_rooms: Dictionary = {}
		for record: Dictionary in parcels.audit.get("maze_back_rooms",
				[]) as Array:
			assert_false(back_rooms.has(StringName(record["parcel_id"])),
				"one back-room record per parcel")
			assert_false((record["cells"] as Array).is_empty(),
				"an empty back-room record is omitted, not recorded")
			back_rooms[StringName(record["parcel_id"])] = record
		var buildings := parcels.audit.get("maze_buildings", {}) as Dictionary
		var shrunk := parcels.audit.get("maze_shrunk_parcels",
			{}) as Dictionary
		var expected_buildings: Dictionary = {}
		var building_plots := 0
		for plot: Dictionary in plan.plots:
			var kind := StringName(plot["kind"])
			if kind != WarrenMazeSourcePlan.PLOT_HOUSE \
					and kind != WarrenMazeSourcePlan.PLOT_ASSET:
				continue
			building_plots += 1
			expected_buildings[StringName(plot["building_id"])] = true
			var id := StringName("parcel.maze.%s" % String(plot["id"]))
			assert_true(by_id.has(id), "plot %s became parcel %s" % [
				plot["id"], id])
			if not by_id.has(id):
				continue
			var parcel := by_id[id] as WarrenBuildingParcel
			assert_true(WarrenParcelConstruction.door_serves_address(parcel),
				"parcel %s serves its own address" % id)
			assert_eq(parcel.base_band, int(plot["floor"]),
				"parcel %s keeps its plot floor" % id)
			assert_eq(parcel.top_band, int(plot["top"]),
				"parcel %s keeps its plot top" % id)
			assert_eq(parcel.address_walk_cell, plot["door_walk"] as Vector3i,
				"parcel %s keeps its plot door" % id)
			var owned: Dictionary = {}
			for column: Vector2i in parcel.footprint:
				assert_true((plot["cells"] as Array).has(column),
					"parcel %s stays inside plot %s" % [id, plot["id"]])
				owned[column] = true
			for column_value: Variant in (back_rooms.get(id,
					{}) as Dictionary).get("cells", []) as Array:
				var column := column_value as Vector2i
				assert_false(owned.has(column),
					"back room %s does not re-own a parcel column" % id)
				owned[column] = true
			assert_eq(owned.size(), (plot["cells"] as Array).size(),
				"parcel %s plus its back rooms cover plot %s exactly" % [
					id, plot["id"]])
			# The translator returns the largest rectangle THAT SEALS, so the
			# maximality has to be falsified against the test's own
			# enumeration: either the parcel really is the biggest legal
			# rectangle in the plot, or the plot is published as shrunk with
			# the reason the bigger one was refused.
			var largest := _largest_rectangle_area(plot)
			if parcel.footprint.size() != largest:
				assert_true(shrunk.has(String(plot["id"])),
					"plot %s took %d of %d columns and says why" % [
						plot["id"], parcel.footprint.size(), largest])
				assert_ne(String(shrunk.get(String(plot["id"]), "")), "",
					"plot %s names the reason it shrank" % plot["id"])
			assert_lte(parcel.footprint.size(), largest,
				"parcel %s cannot exceed the plot's own largest rectangle"
					% id)
		gut.p(("seed %d %s: %d building plots, %d parcels, %d back rooms, " \
			+ "%d shrunk") % [seed_value, scale, building_plots,
				parcels.parcels.size(), back_rooms.size(), shrunk.size()])
		for key: Variant in shrunk.keys():
			gut.p("  shrunk %s: %s" % [key, shrunk[key]])
		assert_gt(building_plots, 4, "the town has buildings to translate")
		assert_eq(parcels.parcels.size(), building_plots,
			"every house and asset plot becomes exactly one parcel")
		assert_eq(buildings.size(), expected_buildings.size(),
			"maze_buildings keys are the building plots' own group ids")
		for key: Variant in expected_buildings.keys():
			assert_true(buildings.has(key),
				"maze_buildings carries building %s" % key)


func test_decks_and_bridges_translate_to_typed_records() -> void:
	# Decks and bridges are composition's own typed records, never parcels.
	var decks_seen := 0
	var bridges_seen := 0
	for spec: Dictionary in PLANNER_SEEDS:
		var seed_value := int(spec["seed"])
		var scale := StringName(spec["scale"])
		var plan := _sealed_town(seed_value, scale)
		var parcels := _parcels_of(seed_value, scale)
		if parcels == null or plan == null:
			gut.p("seed %d %s did not translate: %s" % [seed_value, scale,
				_parcel_failure(seed_value, scale)])
			continue
		var records: Dictionary = {
			WarrenMazeSourcePlan.PLOT_DECK: {},
			WarrenMazeSourcePlan.PLOT_BRIDGE: {},
		}
		for key: StringName in [WarrenMazeSourcePlan.PLOT_DECK,
				WarrenMazeSourcePlan.PLOT_BRIDGE]:
			var audit_key := "maze_decks" if key \
				== WarrenMazeSourcePlan.PLOT_DECK else "maze_bridges"
			for record: Dictionary in parcels.audit.get(audit_key,
					[]) as Array:
				(records[key] as Dictionary)[StringName(record["id"])] = record
		for plot: Dictionary in plan.plots:
			var kind := StringName(plot["kind"])
			if not records.has(kind):
				continue
			var id := StringName(plot["id"])
			var typed := records[kind] as Dictionary
			assert_true(typed.has(id), "plot %s has a typed record" % id)
			assert_null(_parcel_named(parcels,
				StringName("parcel.maze.%s" % id)),
				"plot %s is a record, never a parcel" % id)
			if not typed.has(id):
				continue
			var record := typed[id] as Dictionary
			assert_eq(record["cells"], plot["cells"],
				"record %s keeps the plot's own cells" % id)
			assert_eq(int(record["floor"]), int(plot["floor"]),
				"record %s keeps the plot's own floor" % id)
			assert_eq(record["door_walk"] as Vector3i,
				plot["door_walk"] as Vector3i,
				"record %s keeps the plot's own door" % id)
			if kind == WarrenMazeSourcePlan.PLOT_BRIDGE:
				assert_eq(int(record["top"]), int(plot["top"]),
					"bridge %s keeps its own top" % id)
				assert_eq(StringName(record["building_id"]),
					StringName(plot["building_id"]),
					"bridge %s keeps its own building group" % id)
				bridges_seen += 1
			else:
				decks_seen += 1
	gut.p("typed records: %d decks, %d bridges" % [decks_seen, bridges_seen])
	assert_gt(decks_seen, 0, "the corpus really contains decks")
	assert_gt(bridges_seen, 0, "the corpus really contains bridges")


func _largest_rectangle_area(plot: Dictionary) -> int:
	## The biggest axis-aligned rectangle of this plot's own cells that
	## contains a column 4-adjacent to its door and obeys the parcel shape
	## rule (deeper than wide, or the one 2-wide by 1-deep rowhouse).
	## Deliberately a second, independent implementation: it is what the
	## translator's own choice is falsified against.
	var cells: Dictionary = {}
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for cell_value: Variant in plot["cells"] as Array:
		var column := cell_value as Vector2i
		cells[column] = true
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	var door := plot["door_walk"] as Vector3i
	var best := 0
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
			Vector2i.UP]:
		var threshold := Vector2i(door.x, door.z) - direction
		if not cells.has(threshold):
			continue
		for x0 in range(minimum.x, threshold.x + 1):
			for x1 in range(threshold.x, maximum.x + 1):
				for z0 in range(minimum.y, threshold.y + 1):
					for z1 in range(threshold.y, maximum.y + 1):
						var span := Vector2i(x1 - x0 + 1, z1 - z0 + 1)
						var depth := span.x if direction.x != 0 else span.y
						var width := span.y if direction.x != 0 else span.x
						if depth < width \
								and not (width == 2 and depth == 1):
							continue
						var whole := true
						for x in range(x0, x1 + 1):
							for z in range(z0, z1 + 1):
								whole = whole and cells.has(Vector2i(x, z))
						if whole:
							best = maxi(best, span.x * span.y)
	return best


func _parcel_named(plan: WarrenParcelPlan,
		id: StringName) -> WarrenBuildingParcel:
	for parcel: WarrenBuildingParcel in plan.parcels:
		if parcel.stable_id == id:
			return parcel
	return null


func test_flat_roof_parcels_relax_parity_where_something_stands_on_the_roof() \
		-> void:
	# A plot with a street, a terrace or another building ON its top band owes
	# the storey grid nothing up there. `flat_roof` buys exactly that: an odd
	# five-band parcel seals when it is flagged and is refused when it is not,
	# the even four-band parcel every legacy caller builds is untouched, and a
	# flagged parcel counts its storeys against a one-band slab.
	var plan := _sealed_town(12, &"compact")
	var volume := _volume_of(12, &"compact")
	var parcels := _parcels_of(12, &"compact")
	assert_not_null(parcels, _parcel_failure(12, &"compact"))
	if parcels == null or volume == null or plan == null:
		return
	var host: WarrenBuildingParcel = null
	var flagged := 0
	for parcel: WarrenBuildingParcel in parcels.parcels:
		if parcel.height_bands() >= 6 and host == null:
			host = parcel
		# The flag is a plot fact, not a repair: it is set exactly where
		# something stands on this plot's roof.
		for plot: Dictionary in plan.plots:
			if StringName("parcel.maze.%s" % String(plot["id"])) \
					!= parcel.stable_id:
				continue
			var facts := plan.plot_facts(plot)
			var standing := bool(facts["tiered"]) or not bool(facts["roofed"])
			flagged += int(parcel.flat_roof)
			assert_eq(parcel.flat_roof, standing,
				"parcel %s is flat-roofed exactly when something stands on " \
				% parcel.stable_id + "its roof")
	assert_gt(flagged, 0, "the town really has something standing on a roof")
	assert_not_null(host, "the town has a six-band parcel to restate")
	if host == null:
		return
	var flat := _restate(host, host.base_band + 5, true)
	var odd := _restate(host, host.base_band + 5, false)
	var even := _restate(host, host.base_band + 4, false)
	var shallow := _restate(host, host.base_band + 3, true)
	assert_true(flat.seal(volume), "a flat-roofed five-band parcel seals")
	assert_false(odd.seal(volume), "an odd five-band parcel is still refused")
	assert_true(even.seal(volume), "the even four-band parcel is untouched")
	assert_true(shallow.seal(volume), "a flat-roofed three-band parcel seals")
	# The top band is the slab, so five bands are two storeys under it; a
	# pitched parcel still reserves the authored two.
	assert_eq(flat.storey_count(), 2, "five flat bands are two storeys")
	assert_eq(flat.roof_base_band(), host.base_band + 4,
		"the flat slab starts above the storeys it carries")
	assert_eq(shallow.storey_count(), 1, "three flat bands are one storey")
	assert_eq(even.storey_count(), 1, "the pitched parcel is unchanged")
	assert_eq(even.roof_base_band(), host.base_band + 2,
		"the pitched roof reservation is unchanged")
	assert_false(WarrenBuildingParcel.new(host.stable_id, host.footprint,
		host.base_band, host.base_band + 2, host.address_walk_cell,
		host.threshold_column, host.frontage_direction, 0,
		true).seal(volume),
		"flat_roof still demands a storey plus a band of roof")


func _restate(host: WarrenBuildingParcel, top_band: int,
		flat_roof: bool) -> WarrenBuildingParcel:
	## The same slot as `host` at another top band, so only the height rule
	## can decide the outcome.
	return WarrenBuildingParcel.new(host.stable_id, host.footprint,
		host.base_band, top_band, host.address_walk_cell,
		host.threshold_column, host.frontage_direction,
		host.address_door_phase, flat_roof)


func test_corpus_translates() -> void:
	# The plan's own acceptance bar, measured rather than asserted seed by
	# seed: at least TRANSLATE_FLOOR of the 24 towns adapt and translate. Each
	# failure reports the adapter's or the translator's verbatim reason.
	var translated := 0
	var failures: Array[String] = []
	for scale: StringName in [&"compact", &"standard"]:
		for seed_value in range(1, CORPUS_SEEDS + 1):
			var plan := _sealed_town(seed_value, scale)
			if plan == null:
				failures.append("seed %d %s seal: %s" % [seed_value, scale,
					WarrenMazeSitePlanner.last_failure])
				continue
			var parcels := _parcels_of(seed_value, scale)
			if parcels == null:
				failures.append("seed %d %s: %s" % [seed_value, scale,
					_parcel_failure(seed_value, scale)])
				continue
			translated += 1
			gut.p(("seed %d %s: %d parcels (%d shrunk), %d back-room " \
				+ "cells, %d decks, %d bridges, ownership %.3f (%d owned " \
				+ "of %d solid, %d rock)") % [seed_value, scale,
					parcels.parcels.size(),
					int(parcels.audit.get("maze_shrunk_parcel_count", 0)),
					int(parcels.audit.get("maze_back_room_cells", 0)),
					(parcels.audit.get("maze_decks", []) as Array).size(),
					(parcels.audit.get("maze_bridges", []) as Array).size(),
					float(parcels.audit.get("maze_ownership_ratio", 0.0)),
					int(parcels.audit.get("maze_owned_cells", 0)),
					int(parcels.audit.get("maze_solid_cells", 0)),
					int(parcels.audit.get("maze_rock_cells", 0))])
	for failure: String in failures:
		gut.p(failure)
	gut.p("corpus: %d/%d towns translate" % [translated, 2 * CORPUS_SEEDS])
	assert_gte(translated, TRANSLATE_FLOOR,
		"%d/%d towns translate" % [translated, 2 * CORPUS_SEEDS])


# --- Pipeline and the Phase B exit metric (task B4) -------------------------
# What survived the deleted constructive suite: the phase pipeline, the corpus
# seal rate, seal's audit merge, and the exterior-rock ratio the plot model was
# built to drive down. Every ledger, reservation, stamp, trim, and foundation
# test went with the code it described.

## Measured exterior-rock ratio on the four planner towns, 2026-08-22:
## seed 12 compact 0.1877, seed 4 compact 0.1214, seed 3 standard 0.1564,
## seed 9 standard 0.0686. The ceiling is the worst of those plus a 0.05
## guard, rounded up to two places. A CEILING, so it is re-pinned DOWNWARD
## only as the town gets less rocky -- a rise past it is a regression to
## report, never to accommodate.
const EXTERIOR_ROCK_CEILING := 0.24

## Measured `maze_ownership_ratio` on the four planner towns, 2026-08-22 --
## plot-owned cells (parcels plus their back rooms) over the plan's own
## derived solid -- each minus a 0.05 guard, rounded down to two places:
## seed 12 compact 0.6667 -> 0.61, seed 4 compact 0.7227 -> 0.67,
## seed 3 standard 0.6762 -> 0.62, seed 9 standard 0.7685 -> 0.71.
## Anti-regression floors, re-pinned UPWARD only; a drop is a regression to
## report, never to accommodate.
##
## History (task B4): the deleted constructive suite pinned this same idea at
## 0.66 (seed 4 compact) and 0.65 (seed 12 compact) in
## test_translator_partition_is_one_to_one_with_claims, measured on
## `maze_owned_solid_ratio` -- the ledger-era 2D-footprint metric that died
## with the edit ledger. That metric and this one count different things
## (this denominator is real derived solid, this numerator includes back-room
## mass), so the old numbers are not comparable and these floors are freshly
## measured rather than carried across. The old pair is recorded here so the
## history survives the deletion.
const OWNERSHIP_FLOOR: Dictionary = {
	"12/compact": 0.61,
	"4/compact": 0.67,
	"3/standard": 0.62,
	"9/standard": 0.71,
}


func test_carve_returns_an_unsealed_plan_for_the_phase_pipeline() -> void:
	## Ported from the deleted constructive suite (task B4): the carver's own
	## deferred-seal contract, which the whole stop_after pipeline rests on --
	## sealing later may not change what was carved.
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(12, {}, profile)
	var plan := WarrenMazeCarver.carve(12, massif, profile, false)
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	assert_false(plan.is_sealed())
	assert_true(plan.seal(), plan.last_rejection)
	var sealed := WarrenMazeCarver.carve(12, massif, profile)
	assert_not_null(sealed, WarrenMazeCarver.last_failure)
	assert_eq(plan.deterministic_signature(),
		sealed.deterministic_signature(),
		"deferred seal must not change what was carved")


func test_stop_after_exposes_each_phase_uncontaminated() -> void:
	## Ported from the deleted constructive suite (task B4), re-targeted onto
	## the plot pipeline's own stages: carve exposes a town with no plots at
	## all, reserve adds assets and decks and nothing the partition grows, and
	## partition adds the houses and bridges but still hands back an OPEN plan.
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var carved := WarrenMazeSitePlanner.plan(12, {}, profile, &"carve")
	assert_not_null(carved, WarrenMazeSitePlanner.last_failure)
	assert_false(carved.is_sealed())
	assert_eq(carved.plots.size(), 0, "the bore alone places no plot")

	var reserved := WarrenMazeSitePlanner.plan(12, {}, profile, &"reserve")
	assert_not_null(reserved, WarrenMazeSitePlanner.last_failure)
	assert_false(reserved.is_sealed())
	assert_gt(reserved.plots.size(), 0, "reserve places assets and decks")
	for plot: Dictionary in reserved.plots:
		assert_true(StringName(plot["kind"]) in [
			WarrenMazeSourcePlan.PLOT_ASSET, WarrenMazeSourcePlan.PLOT_DECK],
			"reserve must not have partitioned anything yet: %s is a %s" \
				% [plot["id"], plot["kind"]])

	var partitioned := WarrenMazeSitePlanner.plan(12, {}, profile,
		&"partition")
	assert_not_null(partitioned, WarrenMazeSitePlanner.last_failure)
	assert_false(partitioned.is_sealed(),
		"stop_after hands back an open plan, whatever the stage")
	assert_gt(_plots_of_kind(partitioned,
		WarrenMazeSourcePlan.PLOT_HOUSE).size(), 0,
		"partition grows houses")
	assert_gt(partitioned.plots.size(), reserved.plots.size(),
		"partition adds to what reserve left standing")


func test_plan_rejects_an_unknown_stop_after_stage() -> void:
	## Ported from the deleted constructive suite (task B4), unchanged.
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var result := WarrenMazeSitePlanner.plan(12, {}, profile, &"bogus")
	assert_null(result)
	assert_ne(WarrenMazeSitePlanner.last_failure, "",
		"an unknown stop_after stage must set last_failure")
	assert_true(WarrenMazeSitePlanner.last_failure.contains("bogus"),
		"the failure message should name the offending stop_after value")


func test_site_planner_seals_the_corpus_one_pass() -> void:
	## Ported from the deleted constructive suite (task B4). The planner's own
	## corpus: seeds 1..12 x {compact, standard}. A handful of seeds are known
	## to miss the carve-stage frontage floor; this asserts the failures stay
	## confined to massif/carve -- a seal failure here would mean the plot
	## layer built a town its own model refuses, which is the planner's bug,
	## not a pre-existing generation gate.
	var success := 0
	var total := 0
	var failures: Array[String] = []
	for scale: StringName in [&"compact", &"standard"]:
		for seed_value in range(1, CORPUS_SEEDS + 1):
			total += 1
			var plan := _sealed_town(seed_value, scale)
			if plan != null:
				success += 1
				assert_true(plan.is_sealed(),
					"seed %d %s: plan() must return a sealed plan" \
						% [seed_value, scale])
				continue
			# The cache keeps the null, not the reason; re-run the failing
			# town (it fails in the first two phases, so it is cheap) to read
			# the planner's own verbatim failure back.
			WarrenMazeSitePlanner.plan(seed_value, {},
				WarrenVillageScaleProfile.for_id(scale))
			var failure := WarrenMazeSitePlanner.last_failure
			failures.append("seed %d %s: %s" % [seed_value, scale, failure])
			assert_true(failure.begins_with("massif:") \
					or failure.begins_with("carve:"),
				"seed %d %s: only massif/carve failures are known-acceptable, got: %s" \
					% [seed_value, scale, failure])
	for failure: String in failures:
		gut.p(failure)
	gut.p("corpus: %d/%d towns seal one-pass" % [success, total])
	assert_gte(success, TRANSLATE_FLOOR,
		"expected >= %d/%d seals, got %d" % [TRANSLATE_FLOOR, total, success])


func test_seal_merges_audit_instead_of_replacing_it() -> void:
	## Ported from the deleted constructive suite (task B4), re-targeted onto
	## the plot layer's own audit. seal() used to do `audit = _build_audit()`,
	## a wholesale replacement that destroyed whatever the earlier phases had
	## already written. A full one-pass run exercises every phase, so a sealed
	## plan must still carry `plot_outcomes` alongside seal's own keys.
	var plan := _sealed_town(4, &"compact")
	assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
	if plan == null:
		return
	assert_true(plan.is_sealed(), plan.last_rejection)
	assert_true(plan.audit.has("plot_outcomes"),
		"seal() must not wipe the plot phases' own outcomes")
	var outcomes := plan.audit.get("plot_outcomes", {}) as Dictionary
	assert_gt((outcomes.get("buildings", []) as Array).size(), 0,
		"the outcomes seal preserved must be a real record, not an empty one")
	for key: String in ["frontage_ratio", "street_floor_gaps",
			"exterior_rock_ratio"]:
		assert_true(plan.audit.has(key),
			"seal contributes its own %s alongside what it preserved" % key)


func test_exterior_rock_ratio_is_pinned() -> void:
	## Phase B's exit metric: of the solid cells on the town's own skin above
	## grade, how many are bare rock rather than building. Reported per town
	## and pinned as a ceiling (see EXTERIOR_ROCK_CEILING for the measured
	## values). Every count is re-derived here off `solid_at` and `plots`
	## directly, so the number the plan audits is falsified rather than
	## trusted.
	for spec: Dictionary in PLANNER_SEEDS:
		var seed_value := int(spec["seed"])
		var scale := StringName(spec["scale"])
		var plan := _sealed_town(seed_value, scale)
		assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
		if plan == null:
			continue
		var measured := plan.exterior_rock_ratio()
		assert_eq(str(plan.audit.get("exterior_rock_ratio", {})),
			str(measured), "seal audits exactly what the accessor derives")
		var exterior := 0
		var rock := 0
		var in_plot := 0
		for column: Vector2i in _sorted_columns(plan):
			for band in range(plan.massif.base_at(column) + 1,
					plan.column_ceiling(column)):
				if not plan.solid_at(Vector3i(column.x, band, column.y)):
					continue
				var exposed := false
				for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
					exposed = exposed or not plan.solid_at(Vector3i(
						column.x + direction.x, band, column.y + direction.y))
				if not exposed:
					continue
				exterior += 1
				var owned := false
				for plot: Dictionary in plan.plots:
					if not (plot["cells"] as Array).has(column):
						continue
					if band >= int(plot["floor"]) and band < int(plot["top"]):
						owned = true
						break
				in_plot += int(owned)
				rock += int(not owned)
		assert_eq(int(measured["exterior_cells"]), exterior,
			"seed %d %s: exterior cell count" % [seed_value, scale])
		assert_eq(int(measured["rock_cells"]), rock,
			"seed %d %s: exterior rock count" % [seed_value, scale])
		assert_eq(int(measured["plot_cells"]), in_plot,
			"seed %d %s: exterior plot count" % [seed_value, scale])
		assert_gt(exterior, 0,
			"seed %d %s has a skin to measure" % [seed_value, scale])
		var ratio := float(measured["ratio"])
		gut.p("seed %d %s: exterior rock %d/%d = %.4f (plot %d, ceiling %.2f)" \
			% [seed_value, scale, rock, exterior, ratio, in_plot,
				EXTERIOR_ROCK_CEILING])
		assert_lte(ratio, EXTERIOR_ROCK_CEILING,
			"seed %d %s: exterior rock ratio %.4f is past its pinned ceiling" \
				% [seed_value, scale, ratio])


func test_ownership_is_pinned_on_the_planner_seeds() -> void:
	## The ownership floor the deleted constructive suite carried, restated on
	## the live metric (see OWNERSHIP_FLOOR for the measured values and for
	## what the old ledger-era floors were). Read off the translated parcel
	## plan's own audit; test_translator_emits_one_parcel_group_per_building
	## and test_volume_matches_solid_at are what falsify the metric itself
	## against the sealed plan, so this test's only job is the floor.
	for spec: Dictionary in PLANNER_SEEDS:
		var seed_value := int(spec["seed"])
		var scale := StringName(spec["scale"])
		var key := "%d/%s" % [seed_value, scale]
		assert_true(OWNERSHIP_FLOOR.has(key),
			"every planner seed carries a pinned ownership floor: %s" % key)
		var parcels := _parcels_of(seed_value, scale)
		assert_not_null(parcels, _parcel_failure(seed_value, scale))
		if parcels == null or not OWNERSHIP_FLOOR.has(key):
			continue
		var ratio := float(parcels.audit.get("maze_ownership_ratio", 0.0))
		var pinned := float(OWNERSHIP_FLOOR[key])
		gut.p(("seed %d %s: ownership %.4f (floor %.2f) -- %d owned of %d " \
			+ "solid, %d rock") % [seed_value, scale, ratio, pinned,
				int(parcels.audit.get("maze_owned_cells", 0)),
				int(parcels.audit.get("maze_solid_cells", 0)),
				int(parcels.audit.get("maze_rock_cells", 0))])
		assert_gte(ratio, pinned,
			"seed %d %s: ownership %.4f fell below its pinned floor %.2f" \
				% [seed_value, scale, ratio, pinned])

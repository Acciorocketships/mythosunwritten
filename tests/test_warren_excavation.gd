extends GutTest

## Excavation gates operate on negative space: the bored route must climb,
## stay mostly covered, and never open a cavern or a through-sightline.
##
## Everything the carver reports about itself (cover flags, transitions,
## portals) is re-derived here from the massif alone, so a carver that
## produced a technically-legal but wrong-looking route -- a causeway over
## the roofs, a teleporting walk, an honest-looking `covered` dictionary
## that nothing supports -- fails rather than grades its own homework.

const StampedGround = preload("res://tests/fixtures/warren_stamped_ground.gd")


func _hill(world_seed: int = 0) -> Dictionary:
	## Exercise excavation against the shared synthetic settlement-relief stamp.
	## Flat ground is valid too; this fixture isolates how the inhabited bell's
	## route follows real terrain bands.
	return StampedGround.hill(WarrenMassifBuilder.RADIUS_CELLS + 4, world_seed)


const PROBE_SEEDS := [1, 2, 6]
const SIDES: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT,
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
## Seeds the canyon gate is checked against. Deliberately NOT PROBE_SEEDS: an
## enclosure floor sampled only on three seeds chosen because they satisfy it
## asserts nothing about the carver, and an earlier revision passed at 0.65 on
## those three while a third of arbitrary seeds sat below it.
##
## A consecutive window, none of it the seeds the rest of this suite samples.
## Teeth verified by execution at the current floor rather than assumed:
## deleting the production gate drops seeds 43, 44, 49 and 50 of this window
## below it, the lowest to 0.538. Trimmed from 40 seeds to 24 once the ground
## street lengthened routes and roughly doubled the cost of a carve; 24 still
## carries enough carved seeds to exercise both the enclosure and grade gates
## and to fail loudly if supply collapses.
const CANYON_SEED_START := 40
const CANYON_SEED_COUNT := 24
## Seeds the full carve -> adapt -> ground-arcade chain is exercised on.
## Distinct from PROBE_SEEDS and from the canyon window, so no seed is doing
## double duty. Sixteen is the smallest size whose clearance rate was stable
## across the first 96 seeds (70-80%, against 57-88% at twelve), and the chain
## costs about 1.7s per seed, so this is ~27s of the suite.
const ARCADE_SEED_START := 16
const ARCADE_SEED_COUNT := 16
## Measured on seeds 16-31: 11 carved, 8 cleared (73%). Floors sit below the
## observed range on every 16-seed window (rate 70-80%, count 6-8) so they
## survive seed-to-seed variation, and far above zero so a regression to
## "no candidate ever reaches an arcade" fails loudly.
const MIN_ARCADE_CLEARED_SEEDS := 5
const MIN_ARCADE_CLEARED_RATIO := 0.55
## Lane cells a town must carry, absolutely and as a share of its route.
##
## A house needs a public address (WarrenBuildingParcel.gd:47), the bore plus
## its arcade branches offers about 45 of them across ~565 columns, and that
## ceiling -- not the partitioner -- is what caps a mass-first town at 23-26
## houses. Lanes exist to lift it, so what has to be pinned is that they
## materially widen the public realm rather than that any exists.
##
## Measured across the corpus, not per town. A lane hangs off a route cell and
## needs HEADROOM_BANDS of void in its own column; even in the deep bell it is
## legal only where neighboring building mass leaves that exact swept volume.
## A per-town floor would therefore be a lottery on route shape.
##
## Pinned as a corpus total instead, which is the quantity the sentence above
## actually cares about -- "lanes materially widen the public realm" is a
## statement about towns in general, not about every town. Measured 6 lanes and
## 29 cells against 103 route cells over PROBE_SEEDS; both floors are halved off
## that, and the proportional one stays the load-bearing half.
##
## The proportional floor remains the load-bearing assertion: optional lanes
## must materially widen the public realm across the reviewed corpus.
const MIN_LANE_CELLS_PER_TOWN := 14
const MIN_LANE_CELLS_PER_FIVE_ROUTE_CELLS := 1


func _carved(world_seed: int) -> WarrenExcavation:
	var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
	if massif == null:
		return null
	return WarrenExcavationCarver.carve(world_seed, massif)


func _hand_built(route: Array, transitions: Array) -> WarrenExcavation:
	## A minimal excavation with valid headroom and a portal, so seal() can
	## only be rejecting the walk or transition shape under test.
	var excavation := WarrenExcavation.new(0)
	for cell_value: Variant in route:
		var cell := cell_value as Vector3i
		excavation.route.append(cell)
		for band: Vector3i in excavation.headroom_slot(cell):
			excavation.carved[band] = true
	for spec_value: Variant in transitions:
		excavation.transitions.append(spec_value as Dictionary)
	excavation.portals.append(route[0] as Vector3i)
	return excavation


func _hand_lane(excavation: WarrenExcavation, anchor: Vector3i,
		cells: Array[Vector3i]) -> void:
	## A hand-built lane with valid headroom and LEVEL transitions tiling it, so
	## seal() can only be rejecting the anchor or the cells under test.
	var transitions: Array[Dictionary] = []
	var previous := anchor
	for cell: Vector3i in cells:
		transitions.append({"from": previous, "to": cell,
			"kind": WarrenVolumeTransition.Kind.LEVEL})
		previous = cell
		for band: Vector3i in excavation.headroom_slot(cell):
			excavation.carved[band] = true
	excavation.lanes.append({"anchor": anchor, "cells": cells,
		"transitions": transitions})


func _reordered(massif: WarrenMassif) -> WarrenMassif:
	## The same solid with its column Dictionary built in the opposite order.
	## Iteration order over a Dictionary is insertion order, so any carver
	## decision that reads `columns.keys()` without imposing its own ordering
	## will diverge here while looking perfectly deterministic to a test that
	## just carves the same massif twice.
	var clone := WarrenMassif.new(massif.world_seed)
	var keys: Array = massif.columns.keys()
	keys.reverse()
	for column_value: Variant in keys:
		var column := column_value as Vector2i
		clone.columns[column] = (massif.columns[column] as Dictionary).duplicate()
	clone.core_top_bands = massif.core_top_bands
	clone.seal()
	return clone


func _full_height_walls(massif: WarrenMassif, excavation: WarrenExcavation,
		cell: Vector3i) -> int:
	## Sides where mass still stands the whole height of the street slot,
	## derived from the massif and the removed volume -- never from anything
	## the carver chose to record about itself.
	var walls := 0
	for direction: Vector3i in SIDES:
		var column := Vector2i(cell.x + direction.x, cell.z + direction.z)
		if not massif.has_column(column) \
				or massif.top_at(column) \
					< cell.y + WarrenExcavation.HEADROOM_BANDS:
			continue
		var open := false
		for band in range(cell.y, cell.y + WarrenExcavation.HEADROOM_BANDS):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				open = true
				break
		walls += int(not open)
	return walls


func test_probe_seeds_carve_climbing_covered_routes() -> void:
	var accepted := 0
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		accepted += 1
		assert_true(excavation.is_sealed())
		assert_between(excavation.route.size(),
			WarrenExcavationCarver.MIN_ROUTE_CELLS,
			WarrenExcavationCarver.MAX_ROUTE_CELLS,
			"route length family (seed %d)" % world_seed)
		assert_gte(excavation.route_span_bands(),
			WarrenExcavationCarver.MIN_SPAN_BANDS,
			"the route must genuinely climb (seed %d)" % world_seed)
		assert_gt(excavation.route_span_bands(),
			WarrenMassif.BUILDABLE_LAYER_BANDS - WarrenExcavation.HEADROOM_BANDS,
			("seed %d climbed %d bands, which the buildable layer's own "
			+ "freedom supplies on level ground -- the route must ride the "
			+ "hill, not just the crust") % [world_seed,
				excavation.route_span_bands()])
		assert_between(excavation.covered_ratio(), 0.55, 0.70,
			"most of the route tunnels under mass (seed %d)" % world_seed)
		assert_between(excavation.portals.size(), 1, 2,
			"portals (seed %d)" % world_seed)
	assert_gt(accepted, 0, "no probe seed carved a route: %s" \
		% WarrenExcavationCarver.last_failure)


func test_every_route_cell_is_bounded_by_mass_or_declared_open() -> void:
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		for cell: Vector3i in excavation.route:
			var flanked := 0
			for direction: Vector3i in [Vector3i.RIGHT, Vector3i.LEFT,
					Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var side := cell + direction
				var column := Vector2i(side.x, side.z)
				var solid_beside := massif.has_column(column) \
					and massif.top_at(column) > cell.y \
					and not excavation.carved.has(side)
				flanked += int(solid_beside)
			assert_gte(flanked, 1,
				("route cell %s (seed %d) floats beside no remaining " \
				+ "mass; excavated streets are canyons, not causeways") \
				% [cell, world_seed])


func test_removed_volume_never_leaves_the_solid() -> void:
	## Excavation is subtraction. Every removed cell must have been mass, and
	## the removed volume must be exactly the route's headroom slots -- a
	## route that skimmed the massif's outer skin would "remove" cells that
	## were already open air and read as a causeway over the roofs.
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		for cell_value: Variant in excavation.carved.keys():
			var cell := cell_value as Vector3i
			var column := Vector2i(cell.x, cell.z)
			assert_true(massif.has_column(column),
				"carved %s (seed %d) is outside the footprint" \
				% [cell, world_seed])
			if not massif.has_column(column):
				continue
			assert_between(cell.y, massif.base_at(column),
				massif.top_at(column) - 1,
				"carved %s (seed %d) is not inside the solid" \
				% [cell, world_seed])
		# Lanes are subtraction on the same terms as the route, so they widen
		# this identity rather than exempting themselves from it: every public
		# cell in the town, route or lane, owns one unshared headroom slot.
		var stairs := 0
		var specs: Array[Dictionary] = []
		specs.append_array(excavation.transitions)
		for lane: Dictionary in excavation.lanes:
			specs.append_array(lane["transitions"] as Array[Dictionary])
		for spec: Dictionary in specs:
			stairs += int(int(spec["kind"])
				== int(WarrenVolumeTransition.Kind.STAIR))
		assert_eq(excavation.carved.size(),
			excavation.public_cells().size() * WarrenExcavation.HEADROOM_BANDS
				+ stairs,
			("removed volume must be one unshared headroom slot per walk " \
			+ "cell, plus exactly one extra band for each stair's " \
			+ "two-tread intermediate cell (seed %d)") % world_seed)


func test_route_is_a_walk_that_never_teleports() -> void:
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		var seen: Dictionary = {}
		for index in excavation.route.size():
			var cell := excavation.route[index]
			assert_false(seen.has(cell),
				"route revisits %s (seed %d)" % [cell, world_seed])
			seen[cell] = true
			if index == 0:
				continue
			var step := cell - excavation.route[index - 1]
			assert_eq(absi(step.x) + absi(step.z), 1,
				"route step %d (seed %d) is not a 4-adjacent move" \
				% [index, world_seed])
			assert_lte(absi(step.y), 1,
				"route step %d (seed %d) jumps more than one band" \
				% [index, world_seed])


func test_cover_flags_are_reproducible_from_the_massif_alone() -> void:
	## covered_ratio() reads a dictionary the carver wrote. Recomputing every
	## flag from the massif and the removed volume is what stops that
	## dictionary from being a claim instead of a measurement.
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		var roofed := 0
		for cell: Vector3i in excavation.route:
			var column := Vector2i(cell.x, cell.z)
			# The roof is the first band above the floor that this cell's own
			# removed volume did NOT take out. Counted rather than assumed to
			# be HEADROOM_BANDS up: a stair's intermediate cell carries both
			# treads, so its void is a band taller and its roof a band higher.
			var height := 0
			while excavation.carved.has(
					Vector3i(cell.x, cell.y + height, cell.z)):
				height += 1
			var expected := massif.top_at(column) > cell.y + height
			roofed += int(expected)
			assert_eq(bool(excavation.covered.get(cell, false)), expected,
				"cover flag for %s (seed %d) is not what the mass says" \
				% [cell, world_seed])
		assert_almost_eq(excavation.covered_ratio(),
			float(roofed) / float(excavation.route.size()), 0.0001,
			"covered_ratio (seed %d) must agree with the remaining mass" \
			% world_seed)


func test_transitions_tile_the_route_and_build_real_transitions() -> void:
	## Constructs the actual WarrenVolumeTransition each spec describes and
	## requires it to seal, then -- the part with teeth -- requires every cell
	## surface_cells() will claim for that transition to be void the
	## excavation actually removed, with standing headroom above it.
	##
	## seal() alone proves very little here: it validates swept_air_cells only
	## for duplicates, so it passes just as happily on an empty array. It is
	## surface_cells() that Task 3 will reserve the stair footprint from, and
	## it works in micro lanes at twice this lattice's resolution, so a floor
	## band that looks right per macro cell can still leave half of every
	## flight standing in solid mass.
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		assert_gt(excavation.transitions.size(), 0,
			"a walk with no transitions describes no movement (seed %d)" \
			% world_seed)
		var cursor := 0
		var kinds: Dictionary = {}
		for index in excavation.transitions.size():
			var spec := excavation.transitions[index]
			var from_cell := spec["from"] as Vector3i
			var to_cell := spec["to"] as Vector3i
			assert_eq(from_cell, excavation.route[cursor],
				("transition %d must start where the previous one ended " \
				+ "(seed %d)") % [index, world_seed])
			var delta := to_cell - from_cell
			var run := absi(delta.x) + absi(delta.z)
			if cursor + run > excavation.route.size() - 1:
				assert_lte(cursor + run, excavation.route.size() - 1,
					"transition %d runs off the end of the walk (seed %d)" \
					% [index, world_seed])
				break
			assert_eq(excavation.route[cursor + run], to_cell,
				"transition %d must land on the walk (seed %d)" \
				% [index, world_seed])
			var swept: Array[Vector3i] = []
			for offset in range(run + 1):
				for band: Vector3i in excavation.headroom_slot(
						excavation.route[cursor + offset]):
					swept.append(band)
			var transition := WarrenVolumeTransition.new(
				StringName("excavation.transition.%02d" % index),
				from_cell, to_cell,
				int(spec["kind"]) as WarrenVolumeTransition.Kind, swept)
			assert_true(transition.seal(),
				("transition %d (%s -> %s, kind %d) cannot be built as a " \
				+ "WarrenVolumeTransition (seed %d)") % [index, from_cell,
				to_cell, int(spec["kind"]), world_seed])
			for micro: Vector3i in transition.surface_cells():
				var macro_column := Vector2i(
					floori(float(micro.x) / 2.0), floori(float(micro.z) / 2.0))
				for band in range(micro.y,
						micro.y + WarrenExcavation.HEADROOM_BANDS):
					assert_true(excavation.carved.has(
						Vector3i(macro_column.x, band, macro_column.y)),
						("transition %d puts walking surface at %s, whose " \
						+ "macro cell %s band %d is solid mass the " \
						+ "excavation never removed (seed %d)") % [index,
						micro, macro_column, band, world_seed])
			kinds[int(spec["kind"])] = true
			cursor += run
		assert_eq(cursor, excavation.route.size() - 1,
			"transitions must tile the whole walk, gapless (seed %d)" \
			% world_seed)
		assert_true(kinds.has(int(WarrenVolumeTransition.Kind.STAIR)),
			"a street that climbs 8 bands must use stairs (seed %d)" \
			% world_seed)


func test_seal_rejects_a_span_no_transition_could_be_built_from() -> void:
	## The tiling above is only as strong as seal(), which is what enforces it
	## in production. Both failures are reproduced by hand so that deleting
	## either check fails a test instead of passing quietly.
	var teleport := _hand_built(
		[Vector3i(0, 0, 0), Vector3i(3, 0, 0)],
		[{"from": Vector3i(0, 0, 0), "to": Vector3i(3, 0, 0),
			"kind": WarrenVolumeTransition.Kind.RAMP}])
	assert_false(teleport.seal(),
		"a walk that jumps three cells in one step is not a walk")
	assert_ne(teleport.last_rejection, "",
		"a rejected seal must explain why, like the sibling massif")

	var one_cell_rise := _hand_built(
		[Vector3i(0, 0, 0), Vector3i(1, 1, 0)],
		[{"from": Vector3i(0, 0, 0), "to": Vector3i(1, 1, 0),
			"kind": WarrenVolumeTransition.Kind.STAIR}])
	assert_false(one_cell_rise.seal(),
		("a one-cell rise seals as no Kind at all, so the excavation must " \
		+ "never emit one -- this is the exact defect the run-2 stair " \
		+ "vocabulary exists to prevent"))

	var untiled := _hand_built(
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0)],
		[{"from": Vector3i(0, 0, 0), "to": Vector3i(1, 0, 0),
			"kind": WarrenVolumeTransition.Kind.LEVEL}])
	assert_false(untiled.seal(),
		"transitions that stop short of the terminus do not describe the walk")

	var legal := _hand_built(
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 1, 0)],
		[{"from": Vector3i(0, 0, 0), "to": Vector3i(2, 1, 0),
			"kind": WarrenVolumeTransition.Kind.STAIR}])
	assert_true(legal.seal(),
		("a one-band rise over a two-cell run IS a stair; the rejections " \
		+ "above must be specific, not a seal that refuses everything"))


func test_route_reads_as_a_canyon_climbing_into_the_town() -> void:
	## Flanked-on-one-side by anything at all is the floor the brief gates. A
	## street that reads as a canyon has full-height walls on BOTH sides for
	## most of its run, and it gains its height going in rather than starting
	## on a summit and walking down.
	##
	## Checked over a wide seed range against the carver's own production
	## gate, recomputed here from the massif and the removed volume. The
	## enclosure floor is a real constraint on every seed the carver accepts,
	## not a property of the three seeds the other tests sample.
	var carved_seeds := 0
	for world_seed in range(CANYON_SEED_START,
			CANYON_SEED_START + CANYON_SEED_COUNT):
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		carved_seeds += 1
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		var walled := 0
		var summit_index := 0
		for index in excavation.route.size():
			var cell := excavation.route[index]
			walled += int(_full_height_walls(massif, excavation, cell) >= 2)
			if cell.y > excavation.route[summit_index].y:
				summit_index = index
		assert_gte(float(walled) / float(excavation.route.size()),
			WarrenExcavationCarver.MIN_WALL_RATIO,
			("most of the route must be walled to full street height on " \
			+ "both sides (seed %d)") % world_seed)
		assert_gte(summit_index, excavation.route.size() / 2,
			("the route must climb INTO the town, not begin at its high " \
			+ "point and descend (seed %d)") % world_seed)
	# Was 30 when the route had no ground street to fit into its budget and
	# 39 of these 40 seeds carried a route. The grade requirement costs real
	# supply (measured: 25 of 40 here), so this floor is lowered to match what
	# the carver actually delivers rather than left at a number that only
	# passed before the amendment. It still fails loudly if supply collapses.
	assert_gt(carved_seeds, 8,
		("the canyon gate must be exercised on a wide seed range, not on a " \
		+ "handful that happen to carve: only %d of %d seeds produced a " \
		+ "route") % [carved_seeds, CANYON_SEED_COUNT])


func test_route_walks_at_grade_before_it_climbs() -> void:
	## The excavated route is what WarrenGroundArcadeSolver roots its two
	## ground market branches from, and _find_path only accepts a root whose
	## band equals envelope.ground_at() -- the massif's base band once the
	## adapter has run. A route that touches grade only at its portal offers
	## one root, so the second branch is impossible by construction and every
	## candidate fails the arcade stage regardless of seed.
	##
	## Recomputed here from the massif, and asserted over a wide seed range
	## rather than the probe seeds, because this is a supply-shaped property:
	## it has to hold for every route the carver accepts, not for three.
	var carved_seeds := 0
	for world_seed in range(CANYON_SEED_START,
			CANYON_SEED_START + CANYON_SEED_COUNT):
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		carved_seeds += 1
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		var grade: Array[Vector3i] = []
		for cell: Vector3i in excavation.route:
			if cell.y == massif.base_at(Vector2i(cell.x, cell.z)):
				grade.append(cell)
		assert_gte(grade.size(), WarrenExcavationCarver.MIN_GRADE_CELLS,
			("the route must walk a ground street before it climbs, or the " \
			+ "town has no ground-level public realm at all (seed %d)") \
			% world_seed)
		var spread := 0
		for i in grade.size():
			for j in range(i + 1, grade.size()):
				spread = maxi(spread, absi(grade[i].x - grade[j].x)
					+ absi(grade[i].z - grade[j].z))
		assert_gte(spread, WarrenExcavationCarver.MIN_GRADE_SPREAD_CELLS,
			("two arcade branch roots must be far enough apart to survive " \
			+ "MIN_BRANCH_SEPARATION_CELLS once the first branch has been " \
			+ "carved (seed %d)") % world_seed)
	assert_gt(carved_seeds, 8,
		"the grade gate must be exercised on a wide seed range: only %d of " \
		% carved_seeds + "%d seeds produced a route" % CANYON_SEED_COUNT)


func test_carved_routes_clear_the_real_ground_arcade_stage() -> void:
	## The grade gates above assert the carver's own arithmetic. They cannot
	## tell whether that arithmetic still buys what it was added for: the gate
	## constants, WarrenGroundArcadeSolver.MIN_BRANCH_SEPARATION_CELLS, and
	## that solver's root filter could all drift apart while every other test
	## in this file keeps passing and clearance quietly returns to zero -- the
	## state this whole amendment exists to fix.
	##
	## So this runs the real three-stage chain, with no stubs: carve ->
	## WarrenExcavationVolumeAdapter.to_volume_plan ->
	## WarrenGroundArcadeSolver.extend.
	##
	## MEASURED PER SEED, NOT PER BORE. One route is never a fair proxy for the
	## production grammar: the deep inhabited bell offers several vertical
	## crossing windows, but their alignment depends on the bore's turns and
	## landing phases. The production path tries
	## WarrenTownSolver.MASS_FIRST_EXCAVATION_ATTEMPTS bores per massif and
	## keeps any that clears, so this measures the same attempt corpus.
	##
	## Floors are set from measurement on THIS window, not from aspiration, and
	## both are needed: the rate alone passes if supply collapses to one massif
	## that happens to clear; the count alone passes if supply grows while
	## clearance rots.
	var carved := 0
	var cleared := 0
	for world_seed in range(ARCADE_SEED_START,
			ARCADE_SEED_START + ARCADE_SEED_COUNT):
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		if massif == null:
			continue
		var any_bore := false
		var any_arcade := false
		for attempt in WarrenTownSolver.MASS_FIRST_EXCAVATION_ATTEMPTS:
			var excavation := WarrenExcavationCarver.carve(world_seed
				+ attempt * WarrenTownSolver.MASS_FIRST_ATTEMPT_STRIDE, massif)
			if excavation == null:
				continue
			any_bore = true
			var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
				excavation)
			if plan == null:
				continue
			if WarrenGroundArcadeSolver.extend(plan) != null:
				any_arcade = true
				break
		carved += int(any_bore)
		cleared += int(any_arcade)
	assert_gte(cleared, MIN_ARCADE_CLEARED_SEEDS,
		("only %d of %d carved routes reached a ground arcade; the route " \
		+ "must walk far enough at grade to root two separated branches") \
		% [cleared, carved])
	assert_gte(float(cleared) / float(maxi(1, carved)),
		MIN_ARCADE_CLEARED_RATIO,
		("ground arcade clearance fell to %d of %d carved routes; the grade " \
		+ "gates and WarrenGroundArcadeSolver's root contract have drifted " \
		+ "apart") % [cleared, carved])


func test_carve_does_not_depend_on_massif_column_order() -> void:
	## Carving the same massif twice cannot fail while any Dictionary keeps
	## its insertion order, so it proves nothing about determinism. Carving
	## the same SOLID presented in the opposite column order does: it is the
	## real hazard here, since the carver enumerates `massif.columns` to find
	## its portals and a Dictionary's key order is an implementation detail
	## no consumer should be pinned to.
	for world_seed: int in PROBE_SEEDS:
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		if massif == null:
			continue
		var first := WarrenExcavationCarver.carve(world_seed, massif)
		var second := WarrenExcavationCarver.carve(world_seed,
			_reordered(massif))
		assert_eq(first == null, second == null,
			"acceptance itself must not depend on column order (seed %d)" \
			% world_seed)
		if first == null or second == null:
			continue
		assert_eq(first.route, second.route,
			"column order must not change the route (seed %d)" % world_seed)
		assert_eq(first.portals, second.portals,
			"column order must not change the portals (seed %d)" % world_seed)
		assert_eq(first.carved.size(), second.carved.size(),
			"column order must not change the removed volume (seed %d)" \
			% world_seed)
		for cell_value: Variant in first.carved.keys():
			assert_true(second.carved.has(cell_value as Vector3i),
				"removed volume differs at %s (seed %d)" \
				% [cell_value, world_seed])
		assert_eq(first.transitions.size(), second.transitions.size(),
			"column order must not change the transitions (seed %d)" \
			% world_seed)


func _public_graph_reaches_every_cell(excavation: WarrenExcavation) -> bool:
	## Flood fill the whole street network from the route's mouth over route
	## steps and lane transitions alike. This is the property
	## WarrenVolumePlan._all_walk_connected() will re-check one stage later, so a
	## lane that fails here is an alley the sealed plan cannot accept either.
	var adjacency: Dictionary = {}
	for cell: Vector3i in excavation.public_cells():
		adjacency[cell] = [] as Array[Vector3i]
	for index in range(1, excavation.route.size()):
		(adjacency[excavation.route[index]] as Array[Vector3i]).append(
			excavation.route[index - 1])
		(adjacency[excavation.route[index - 1]] as Array[Vector3i]).append(
			excavation.route[index])
	for lane: Dictionary in excavation.lanes:
		var walk: Array[Vector3i] = [lane["anchor"] as Vector3i]
		walk.append_array(lane["cells"] as Array[Vector3i])
		for index in range(1, walk.size()):
			if not adjacency.has(walk[index]) or not adjacency.has(walk[index - 1]):
				return false
			(adjacency[walk[index]] as Array[Vector3i]).append(walk[index - 1])
			(adjacency[walk[index - 1]] as Array[Vector3i]).append(walk[index])
	var reached: Dictionary = {}
	var pending: Array[Vector3i] = [excavation.route[0]]
	while not pending.is_empty():
		var current: Vector3i = pending.pop_back()
		if reached.has(current):
			continue
		reached[current] = true
		for neighbour: Vector3i in adjacency[current] as Array[Vector3i]:
			if not reached.has(neighbour):
				pending.append(neighbour)
	return reached.size() == adjacency.size()


func test_the_route_branches_into_a_connected_lane_network() -> void:
	## One route cannot seed a village across 565 columns: every house needs a
	## public address, and the bore plus its arcade branches offer about 45 of
	## them. Lanes are the street web that address the rest of the hill, so this
	## asserts a substantive network rather than the existence of one alley.
	var accepted := 0
	var corpus_lanes := 0
	var corpus_lane_cells := 0
	var corpus_route_cells := 0
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		accepted += 1
		corpus_lanes += excavation.lanes.size()
		corpus_lane_cells += excavation.lane_cells().size()
		corpus_route_cells += excavation.route.size()
		var seen: Dictionary = {}
		for cell: Vector3i in excavation.route:
			seen[cell] = true
		for cell: Vector3i in excavation.lane_cells():
			assert_false(seen.has(cell),
				"lane cell %s (seed %d) is already public realm" \
				% [cell, world_seed])
			seen[cell] = true
		assert_true(_public_graph_reaches_every_cell(excavation),
			"seed %d left an orphan alley in its street network" % world_seed)
	assert_gt(accepted, 0, "no probe seed carved a route")
	assert_gte(corpus_lanes, 3,
		"the corpus branched only %d lanes off %d routes; one spur per town "
		% [corpus_lanes, accepted] + "is not a street network")
	assert_gte(corpus_lane_cells, MIN_LANE_CELLS_PER_TOWN,
		"the corpus carried only %d lane cells" % corpus_lane_cells)
	assert_gte(corpus_lane_cells * 5,
		corpus_route_cells * MIN_LANE_CELLS_PER_FIVE_ROUTE_CELLS,
		("the corpus added only %d lane cells to %d route cells; the lane "
		+ "network must widen the public realm, not decorate it")
		% [corpus_lane_cells, corpus_route_cells])
	assert_gt(accepted, 0, "no probe seed carved a route: %s" \
		% WarrenExcavationCarver.last_failure)


func test_every_lane_cell_is_a_slot_cut_from_solid_that_fronts_a_house() -> void:
	## A lane's own legality, deliberately lighter than the route's: no
	## two-sided full-height wall rule, because a terrace lane open on its
	## downhill side is correct hill-town form and gets a parapet from the
	## surface stages rather than a building.
	##
	## What a lane must do instead is earn the mass it removes. Every lane cell
	## fronts at least one column that could carry the cheapest legal house --
	## WarrenBuildingParcel's one storey plus its roof reservation, on
	## unexcavated bearing -- which is the whole reason lanes exist. Re-derived
	## from the massif here, never read back off the carver.
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		var needed := WarrenBuildingParcel.STOREY_BANDS \
			+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
		for cell: Vector3i in excavation.lane_cells():
			var column := Vector2i(cell.x, cell.z)
			assert_true(massif.has_column(column),
				"lane cell %s (seed %d) stands outside the footprint" \
				% [cell, world_seed])
			if not massif.has_column(column):
				continue
			var height := 0
			while excavation.carved.has(Vector3i(cell.x, cell.y + height, cell.z)):
				height += 1
			assert_gte(height, WarrenExcavation.HEADROOM_BANDS,
				"lane cell %s (seed %d) has no carved headroom" \
				% [cell, world_seed])
			assert_lte(cell.y + height, massif.top_at(column),
				"lane cell %s (seed %d) was cut through the massif's skin" \
				% [cell, world_seed])
			assert_gte(cell.y, massif.base_at(column),
				"lane cell %s (seed %d) is cut below natural ground" \
				% [cell, world_seed])
			var addressable := false
			for side: Vector3i in SIDES:
				var beside := Vector2i(cell.x + side.x, cell.z + side.z)
				if not massif.has_column(beside) \
						or massif.base_at(beside) > cell.y \
						or massif.top_at(beside) < cell.y + needed:
					continue
				var clear := true
				for band in range(massif.base_at(beside), cell.y + needed):
					if excavation.carved.has(Vector3i(beside.x, band, beside.y)):
						clear = false
						break
				addressable = addressable or clear
			assert_true(addressable,
				("lane cell %s (seed %d) fronts no column that can carry a " \
				+ "house; a lane that addresses nothing is spent mass") \
				% [cell, world_seed])


func test_lanes_leave_every_gate_the_route_answers_to_intact() -> void:
	## Lanes are cut AFTER the route has been chosen against its gates, so this
	## re-measures those gates on the finished solid. A lane that took a route
	## cell's wall, its flank or its roof would satisfy every gate at selection
	## time and violate all three by the time anything is built.
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		var walled := 0
		for cell: Vector3i in excavation.route:
			var flanked := 0
			var walls := 0
			for side: Vector3i in SIDES:
				var column := Vector2i(cell.x + side.x, cell.z + side.z)
				if not massif.has_column(column):
					continue
				if massif.top_at(column) > cell.y \
						and not excavation.carved.has(cell + side):
					flanked += 1
				if massif.top_at(column) < cell.y + WarrenExcavation.HEADROOM_BANDS:
					continue
				var open := false
				for band in range(cell.y, cell.y + WarrenExcavation.HEADROOM_BANDS):
					if excavation.carved.has(Vector3i(column.x, band, column.y)):
						open = true
						break
				walls += int(not open)
			assert_gte(flanked, 1,
				"lanes stranded route cell %s (seed %d) beside no mass" \
				% [cell, world_seed])
			walled += int(walls >= 2)
		assert_gte(float(walled) / float(excavation.route.size()),
			WarrenExcavationCarver.MIN_WALL_RATIO,
			"lanes opened the route's canyon walls (seed %d)" % world_seed)
		assert_between(excavation.covered_ratio(), 0.55, 0.70,
			"lanes changed what stands over the route (seed %d)" % world_seed)
		assert_between(excavation.portals.size(), 1, 2,
			"lanes changed the route's portal count (seed %d)" % world_seed)


func test_seal_rejects_a_lane_that_never_reaches_the_public_realm() -> void:
	## The connectivity above is only as strong as seal(), which is what
	## enforces it in production -- and one stage later
	## WarrenVolumePlan._all_walk_connected() rejects the whole town for it.
	var orphan := _hand_built(
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0)],
		[{"from": Vector3i(0, 0, 0), "to": Vector3i(1, 0, 0),
			"kind": WarrenVolumeTransition.Kind.LEVEL}])
	_hand_lane(orphan, Vector3i(9, 0, 9), [Vector3i(10, 0, 9)])
	assert_false(orphan.seal(),
		"a lane anchored on nothing is an alley nobody can walk into")

	var untiled := _hand_built(
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0)],
		[{"from": Vector3i(0, 0, 0), "to": Vector3i(1, 0, 0),
			"kind": WarrenVolumeTransition.Kind.LEVEL}])
	untiled.lanes.append({
		"anchor": Vector3i(1, 0, 0),
		"cells": [Vector3i(1, 0, 1)] as Array[Vector3i],
		"transitions": [] as Array[Dictionary],
	})
	for band: Vector3i in untiled.headroom_slot(Vector3i(1, 0, 1)):
		untiled.carved[band] = true
	assert_false(untiled.seal(),
		"a lane whose transitions do not tile it describes no walk")

	var reused := _hand_built(
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0)],
		[{"from": Vector3i(0, 0, 0), "to": Vector3i(1, 0, 0),
			"kind": WarrenVolumeTransition.Kind.LEVEL}])
	_hand_lane(reused, Vector3i(1, 0, 0), [Vector3i(0, 0, 0)])
	assert_false(reused.seal(),
		"a lane cell that is already route is a second claim on one surface")

	var legal := _hand_built(
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0)],
		[{"from": Vector3i(0, 0, 0), "to": Vector3i(1, 0, 0),
			"kind": WarrenVolumeTransition.Kind.LEVEL}])
	_hand_lane(legal, Vector3i(1, 0, 0), [Vector3i(1, 0, 1), Vector3i(1, 0, 2)])
	assert_true(legal.seal(),
		("a lane hanging off the route by LEVEL steps IS legal; the " \
		+ "rejections above must be specific, not a seal that refuses lanes"))

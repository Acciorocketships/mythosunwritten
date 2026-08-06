extends GutTest

## Excavation gates operate on negative space: the bored route must climb,
## stay mostly covered, and never open a cavern or a through-sightline.
##
## Everything the carver reports about itself (cover flags, transitions,
## portals) is re-derived here from the massif alone, so a carver that
## produced a technically-legal but wrong-looking route -- a causeway over
## the roofs, a teleporting walk, an honest-looking `covered` dictionary
## that nothing supports -- fails rather than grades its own homework.

const PROBE_SEEDS := [1, 2, 6]
const SIDES: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT,
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
## Seeds the canyon gate is checked against. Deliberately NOT PROBE_SEEDS: an
## enclosure floor sampled only on three seeds chosen because they satisfy it
## asserts nothing about the carver, and an earlier revision passed at 0.65 on
## those three while a third of arbitrary seeds sat below it.
##
## This window is chosen to be the HARDEST forty consecutive seeds measured,
## not the most comfortable: 49 and 67 land exactly on the floor, so the gate
## is what puts them there. Over seeds 0-39 every route clears the floor on
## the score weights alone and the assertion could not fail.
const CANYON_SEED_START := 40
const CANYON_SEED_COUNT := 40


func _carved(world_seed: int) -> WarrenExcavation:
	var massif := WarrenMassifBuilder.build(world_seed)
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
		assert_between(excavation.route.size(), 22, 26,
			"route length family (seed %d)" % world_seed)
		assert_gte(excavation.route_span_bands(), 8,
			"the route must genuinely climb (seed %d)" % world_seed)
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
		var massif := WarrenMassifBuilder.build(world_seed)
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
		var massif := WarrenMassifBuilder.build(world_seed)
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
		var stairs := 0
		for spec: Dictionary in excavation.transitions:
			stairs += int(int(spec["kind"])
				== int(WarrenVolumeTransition.Kind.STAIR))
		assert_eq(excavation.carved.size(),
			excavation.route.size() * WarrenExcavation.HEADROOM_BANDS + stairs,
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
		var massif := WarrenMassifBuilder.build(world_seed)
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
		var massif := WarrenMassifBuilder.build(world_seed)
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
	assert_gt(carved_seeds, 30,
		("the canyon gate must be exercised on a wide seed range, not on a " \
		+ "handful that happen to carve: only %d of %d seeds produced a " \
		+ "route") % [carved_seeds, CANYON_SEED_COUNT])


func test_carve_does_not_depend_on_massif_column_order() -> void:
	## Carving the same massif twice cannot fail while any Dictionary keeps
	## its insertion order, so it proves nothing about determinism. Carving
	## the same SOLID presented in the opposite column order does: it is the
	## real hazard here, since the carver enumerates `massif.columns` to find
	## its portals and a Dictionary's key order is an implementation detail
	## no consumer should be pinned to.
	for world_seed: int in PROBE_SEEDS:
		var massif := WarrenMassifBuilder.build(world_seed)
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

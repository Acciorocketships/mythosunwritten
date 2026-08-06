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
## A canyon is bounded by mass reaching the full height of the street, not by
## a one-band kerb at a terrace lip -- and every gate in the brief is
## satisfied by kerbs alone. Wall height is steered for, never gated, inside
## the carver, so this floor is a real measurement rather than a restatement
## of a constant: the probe seeds measure 0.77-0.88 with that steering and
## 0.44-0.63 without it, and the threshold sits between the two.
const MIN_FULL_HEIGHT_WALL_RATIO := 0.65


func _carved(world_seed: int) -> WarrenExcavation:
	var massif := WarrenMassifBuilder.build(world_seed)
	if massif == null:
		return null
	return WarrenExcavationCarver.carve(world_seed, massif)


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
		assert_eq(excavation.carved.size(),
			excavation.route.size() * WarrenExcavation.HEADROOM_BANDS,
			("removed volume must be exactly one unshared headroom slot " \
			+ "per walk cell (seed %d)") % world_seed)


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
			var roof := Vector3i(cell.x,
				cell.y + WarrenExcavation.HEADROOM_BANDS, cell.z)
			var expected := massif.top_at(column) > roof.y \
				and not excavation.carved.has(roof)
			roofed += int(expected)
			assert_eq(bool(excavation.covered.get(cell, false)), expected,
				"cover flag for %s (seed %d) is not what the mass says" \
				% [cell, world_seed])
		assert_almost_eq(excavation.covered_ratio(),
			float(roofed) / float(excavation.route.size()), 0.0001,
			"covered_ratio (seed %d) must agree with the remaining mass" \
			% world_seed)


func test_transitions_mark_exactly_the_floor_band_changes() -> void:
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		var expected: Dictionary = {}
		for index in range(1, excavation.route.size()):
			var from_cell := excavation.route[index - 1]
			var to_cell := excavation.route[index]
			if from_cell.y != to_cell.y:
				expected["%s>%s" % [from_cell, to_cell]] = true
		var emitted: Dictionary = {}
		for spec: Dictionary in excavation.transitions:
			var key := "%s>%s" % [spec["from"], spec["to"]]
			assert_false(emitted.has(key),
				"transition %s emitted twice (seed %d)" % [key, world_seed])
			emitted[key] = true
			assert_eq(int(spec["kind"]), int(WarrenVolumeTransition.Kind.STAIR),
				"a one-band excavated step is a stair (seed %d)" % world_seed)
		assert_eq(emitted.size(), expected.size(),
			"transition count must match the floor-band changes (seed %d)" \
			% world_seed)
		for key: String in expected:
			assert_true(emitted.has(key),
				"floor band changes at %s with no transition (seed %d)" \
				% [key, world_seed])


func test_route_reads_as_a_canyon_climbing_into_the_town() -> void:
	## Flanked-on-one-side by anything at all is the floor the brief gates. A
	## street that reads as a canyon has full-height walls on BOTH sides for
	## most of its run, and it gains its height going in rather than starting
	## on a summit and walking down.
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		var massif := WarrenMassifBuilder.build(world_seed)
		var walled := 0
		var summit_index := 0
		for index in excavation.route.size():
			var cell := excavation.route[index]
			walled += int(_full_height_walls(massif, excavation, cell) >= 2)
			if cell.y > excavation.route[summit_index].y:
				summit_index = index
		assert_gte(float(walled) / float(excavation.route.size()),
			MIN_FULL_HEIGHT_WALL_RATIO,
			("most of the route must be walled to full street height on " \
			+ "both sides (seed %d)") % world_seed)
		assert_gte(summit_index, excavation.route.size() / 2,
			("the route must climb INTO the town, not begin at its high " \
			+ "point and descend (seed %d)") % world_seed)


func test_carve_is_deterministic_for_one_seed() -> void:
	for world_seed: int in PROBE_SEEDS:
		var first := _carved(world_seed)
		var second := _carved(world_seed)
		if first == null:
			assert_null(second, "acceptance itself must be deterministic")
			continue
		assert_eq(first.route, second.route,
			"same seed must bore the same route (seed %d)" % world_seed)
		assert_eq(first.portals, second.portals,
			"same seed must open the same portals (seed %d)" % world_seed)
		assert_eq(first.carved.size(), second.carved.size(),
			"same seed must remove the same volume (seed %d)" % world_seed)
		for cell_value: Variant in first.carved.keys():
			assert_true(second.carved.has(cell_value as Vector3i),
				"removed volume differs at %s (seed %d)" \
				% [cell_value, world_seed])
		assert_eq(first.transitions.size(), second.transitions.size(),
			"same seed must emit the same transitions (seed %d)" % world_seed)

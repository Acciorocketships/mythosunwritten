extends GutTest

## The massif is the primary object of the mass-first pipeline: a tall,
## terraced, deterministic solid. These tests pin its hard gates.


func test_massif_builds_tall_terraced_and_deterministic() -> void:
	var a := WarrenMassifBuilder.build(1)
	var b := WarrenMassifBuilder.build(1)
	assert_not_null(a, WarrenMassifBuilder.last_failure)
	assert_true(a.is_sealed())
	assert_gte(a.core_top_bands, 16,
		"core must reach 16 bands so excavation has vertical room")
	assert_gte(a.terrace_levels().size(), 5,
		"a smooth dome is not a terraced town silhouette")
	assert_lte(a.widest_plateau_cells(), 6,
		"wide flat plateaus read as empty platforms, not terraces")
	var worst_step := 0
	for column: Vector2i in a.columns:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor := column + direction
			if a.has_column(neighbor):
				worst_step = maxi(worst_step,
					absi(a.top_at(column) - a.top_at(neighbor)))
	assert_lte(worst_step, WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS,
		"neighbouring columns must step like terraces, not cliffs")
	assert_eq(a.columns.size(), b.columns.size())
	for column: Vector2i in a.columns:
		assert_eq(a.top_at(column), b.top_at(column),
			"same seed must give identical column heights")


func test_massif_seeds_differ_and_respect_ground_bands() -> void:
	var flat := WarrenMassifBuilder.build(2)
	var raised_bands: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			raised_bands[Vector2i(x, z)] = 2
	var raised := WarrenMassifBuilder.build(2, raised_bands)
	assert_not_null(flat, WarrenMassifBuilder.last_failure)
	assert_not_null(raised, WarrenMassifBuilder.last_failure)
	var differing := 0
	var other := WarrenMassifBuilder.build(3)
	for column: Vector2i in flat.columns:
		if other.has_column(column) \
				and flat.top_at(column) != other.top_at(column):
			differing += 1
	assert_gt(differing, 10, "different seeds must differ meaningfully")
	for column: Vector2i in raised.columns:
		assert_gte(raised.base_at(column), 2,
			"terrain ground bands lift the massif base")


func test_the_address_gate_requires_a_tower_at_the_top_of_the_climb() -> void:
	## Pins WHY "no building over 2-3 storeys" cannot be reached by reshaping
	## the massif, so the next attempt starts from the constraint instead of
	## rediscovering it. Measured on real bores, not argued.
	##
	## A walk cell is ADDRESSED only when a neighbouring column carries
	## WarrenVolumePlan.MIN_ADDRESS_BUILDING_BANDS of CONTINUOUS mass starting
	## at the street's own floor band, and WarrenPublicRealmCarver's topology
	## gate demands that of 0.55 of the itinerary. The street must also climb
	## WarrenExcavationCarver.MIN_SPAN_BANDS. So the flank beside its highest
	## cell stands span + address bands above the lowest -- and
	## WarrenParcelConstruction descends a house to
	## WarrenVolumeEnvelope.ground_at(), turning every one of those bands into
	## a storey a viewer counts.
	##
	## Shortening the massif starves the address gate instead (measured:
	## warren_mass_first_report --stage hillside, SHORT+FLAT column). Raising
	## each column's base to its terrace deletes the mass the gate reads. One
	## field is both the datum street rules measure mass from and the datum a
	## house descends to; a terraced town needs those to differ, and no value
	## of `base` satisfies both.
	var storeys_per_band := WarrenBuildingParcel.STOREY_BANDS
	var forced := (WarrenExcavationCarver.MIN_SPAN_BANDS
		+ WarrenVolumePlan.MIN_ADDRESS_BUILDING_BANDS
		- WarrenBuildingParcel.ROOF_RESERVATION_BANDS) / storeys_per_band
	assert_gte(forced, 4,
		"the published constants already demand a %d storey flank" % forced)
	var measured := 0
	for world_seed in [13, 16]:
		var massif := WarrenMassifBuilder.build(world_seed)
		assert_not_null(massif, WarrenMassifBuilder.last_failure)
		if massif == null:
			continue
		var shortest := _shortest_addressed_flank_storeys(massif)
		if shortest < 0:
			continue
		measured += 1
		assert_gte(shortest, 4,
			("seed %d: the shortest flank addressing the top of the climb " \
			+ "builds %d storeys. If this is ever 3 or fewer the address " \
			+ "datum has been split from the bearing datum -- delete this " \
			+ "test and build the terraced hillside.") % [world_seed, shortest])
	assert_gt(measured, 0, "neither seed produced an addressed bore")


func _shortest_addressed_flank_storeys(massif: WarrenMassif) -> int:
	## Over the bore family WarrenTownSolver.mass_first_frontier tries: the
	## fewest storeys any column addressing a route's HIGHEST walk cell builds,
	## counted the way WarrenParcelConstruction.proposal() counts them (from
	## the bearing datum, so the descent is included). -1 when nothing carved.
	var fewest := 1 << 20
	for attempt in WarrenTownSolver.MASS_FIRST_EXCAVATION_ATTEMPTS:
		var excavation := WarrenExcavationCarver.carve(massif.world_seed
			+ attempt * WarrenTownSolver.MASS_FIRST_ATTEMPT_STRIDE, massif)
		if excavation == null:
			continue
		var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if plan == null:
			continue
		var summit := excavation.route[0]
		for cell: Vector3i in excavation.route:
			if cell.y > summit.y:
				summit = cell
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			var column := Vector2i(summit.x + direction.x,
				summit.z + direction.y)
			var addressed := true
			for band in range(summit.y,
					summit.y + WarrenVolumePlan.MIN_ADDRESS_BUILDING_BANDS):
				if not plan.has_mass(Vector3i(column.x, band, column.y)):
					addressed = false
					break
			if not addressed:
				continue
			fewest = mini(fewest, (massif.top_at(column)
				- massif.base_at(column)
				- WarrenBuildingParcel.ROOF_RESERVATION_BANDS)
				/ WarrenBuildingParcel.STOREY_BANDS)
	return -1 if fewest == 1 << 20 else fewest


func test_seal_requires_single_connected_component_and_no_holes() -> void:
	var built := WarrenMassifBuilder.build(1)
	assert_not_null(built, WarrenMassifBuilder.last_failure)
	if built == null:
		return
	assert_true(built.is_sealed())
	assert_true(built._is_single_component(),
		"a solid massif must not be a scattered archipelago of columns")
	assert_eq(built._find_interior_hole(), null,
		"a solid massif must not have a puncture through its middle")


func test_seal_rejects_a_hand_built_disjoint_massif() -> void:
	var massif := WarrenMassif.new(99)
	for column: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		massif.columns[column] = {"base": 0, "top": 5, "terrace": 5}
	for column: Vector2i in [Vector2i(10, 10), Vector2i(11, 10)]:
		massif.columns[column] = {"base": 0, "top": 5, "terrace": 5}
	assert_false(massif.seal(),
		"two disjoint clusters must not seal as one solid massif")
	assert_ne(massif.last_rejection, "",
		"a rejected seal must explain why, like the sibling envelope class")


func test_seal_rejects_a_solid_block_with_a_multi_cell_interior_void() -> void:
	var massif := WarrenMassif.new(100)
	for z in range(5):
		for x in range(5):
			massif.columns[Vector2i(x, z)] = {"base": 0, "top": 5, "terrace": 5}
	# Two ADJACENT interior cells removed: every single missing cell still
	# has at least one missing neighbour, so a 4-neighbour-presence
	# heuristic never flags either of them, even though the pair together
	# forms one fully enclosed void with no path to the outside.
	massif.columns.erase(Vector2i(2, 2))
	massif.columns.erase(Vector2i(2, 3))
	assert_true(massif._is_single_component(),
		"the ring surrounding the void is still one connected component")
	assert_false(massif.seal(),
		"a fully enclosed multi-cell void must not seal as solid")
	assert_ne(massif.last_rejection, "",
		"a rejected seal must explain why, like the sibling envelope class")

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
	var flat := WarrenMassifBuilder.build(1)
	var raised_bands: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			raised_bands[Vector2i(x, z)] = 2
	var raised := WarrenMassifBuilder.build(1, raised_bands)
	assert_not_null(flat, WarrenMassifBuilder.last_failure)
	assert_not_null(raised, WarrenMassifBuilder.last_failure)
	var differing := 0
	var other := WarrenMassifBuilder.build(4)
	for column: Vector2i in flat.columns:
		if other.has_column(column) \
				and flat.top_at(column) != other.top_at(column):
			differing += 1
	assert_gt(differing, 10, "different seeds must differ meaningfully")
	for column: Vector2i in raised.columns:
		assert_gte(raised.base_at(column), 2,
			"terrain ground bands lift the massif base")


func test_the_address_gate_no_longer_forces_a_tower_at_the_top_of_the_climb() \
		-> void:
	## Pins BOTH halves of the split datum on real bores, not by argument: the
	## address gate still demands a four-storey column of mass beside the top of
	## the climb, and a house standing there is still only three storeys tall.
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
	## each column's base to its terrace deletes the mass the gate reads. So one
	## field could not be both, and `bearing_at` is now the second: the gate
	## keeps reading the whole solid from `base_at`, while a house stops
	## descending at the terrace and the hill below it is rendered as stone.
	var storeys_per_band := WarrenBuildingParcel.STOREY_BANDS
	var forced := (WarrenExcavationCarver.MIN_SPAN_BANDS
		+ WarrenVolumePlan.MIN_ADDRESS_BUILDING_BANDS
		- WarrenBuildingParcel.ROOF_RESERVATION_BANDS) / storeys_per_band
	assert_gte(forced, 4,
		"the published constants already demand a %d storey flank" % forced)
	var measured := 0
	# Seeds re-pinned to survivors of the rim step rule: 13 no longer builds
	# (plateau of 7 cells), which is a seed-supply fact reported in
	# task-13-report.md, not a property of the datum split this test pins.
	for world_seed in [16, 17]:
		var massif := WarrenMassifBuilder.build(world_seed)
		assert_not_null(massif, WarrenMassifBuilder.last_failure)
		if massif == null:
			continue
		var from_ground := _tallest_addressed_flank_storeys(massif, false)
		var from_terrace := _tallest_addressed_flank_storeys(massif, true)
		if from_ground < 0:
			continue
		measured += 1
		assert_gte(from_ground, 4,
			"seed %d: natural ground still makes that flank %d storeys" \
			% [world_seed, from_ground])
		assert_lte(from_terrace, WarrenMassif.MAX_TERRACE_STOREYS,
			"seed %d: the flank addressing the top of the climb builds %d " \
			% [world_seed, from_terrace]
			+ "storeys from its terrace, so the datums are not really split")
	assert_gt(measured, 0, "neither seed produced an addressed bore")


func test_the_buildable_layer_is_derived_from_the_parcel_contract() -> void:
	## WarrenMassif deliberately restates the layer rather than importing the
	## parcel vocabulary, so this is the only thing stopping the two drifting.
	assert_eq(WarrenMassif.BUILDABLE_LAYER_BANDS,
		WarrenMassif.MAX_TERRACE_STOREYS * WarrenBuildingParcel.STOREY_BANDS
		+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS,
		"the buildable layer must be exactly MAX_TERRACE_STOREYS storeys "
		+ "plus one roof reservation")
	var massif := WarrenMassifBuilder.build(1)
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	if massif == null:
		return
	var raised := 0
	for column: Vector2i in massif.columns:
		var bearing := massif.bearing_at(column)
		assert_between(bearing, massif.base_at(column), massif.top_at(column),
			"the terrace at %s is outside its own column" % column)
		assert_lte(massif.top_at(column) - bearing,
			WarrenMassif.BUILDABLE_LAYER_BANDS,
			"the terrace at %s carries more than one buildable layer" % column)
		if massif.top_at(column) - massif.base_at(column) \
				<= WarrenMassif.BUILDABLE_LAYER_BANDS:
			assert_eq(bearing, massif.base_at(column),
				"a column already inside the layer keeps natural ground at %s" \
				% column)
		else:
			raised += 1
	# Measured 126 of 291 on seed 1. The remainder is the taper -- rim columns
	# shorter than one buildable layer, which keep natural ground by the rule
	# above. A third is a floor on "the terrace actually bites", not a target.
	assert_gt(raised * 3, massif.columns.size(),
		"a terrace that lifts almost nothing is not a hillside: %d of %d" \
		% [raised, massif.columns.size()])


func test_the_rim_steps_down_to_the_ground_like_every_other_terrace() -> void:
	## Empty ground beside a boundary column IS height zero, and the neighbour
	## step limit applies to it. Without that the rim was a legal 7-16 band
	## cliff (measured over seeds 0-39) which every remedy so far re-skinned --
	## timber, then stone -- rather than removed. With it the tallest continuous
	## vertical face anywhere in the solid is one riser, so a viewer never sees
	## more than MAX_NEIGHBOR_STEP_BANDS of unbroken wall before a setback,
	## whatever material later dresses it.
	for world_seed: int in [0, 1, 3, 5, 16, 18]:
		var massif := WarrenMassifBuilder.build(world_seed)
		assert_not_null(massif, "seed %d: %s" % [world_seed,
			WarrenMassifBuilder.last_failure])
		if massif == null:
			continue
		var tallest_rim := 0
		var tallest_face := 0
		for column: Vector2i in massif.columns:
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
					Vector2i.UP, Vector2i.DOWN]:
				var neighbor := column + direction
				var exposed := massif.top_at(column) - massif.base_at(column) \
					if not massif.has_column(neighbor) \
					else massif.top_at(column) - massif.top_at(neighbor)
				if not massif.has_column(neighbor):
					tallest_rim = maxi(tallest_rim, exposed)
				tallest_face = maxi(tallest_face, exposed)
		assert_lte(tallest_rim, WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS,
			"seed %d presents a %d-band cliff to the empty ground beside it" \
			% [world_seed, tallest_rim])
		assert_lte(tallest_face, WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS,
			"seed %d has a %d-band continuous face" % [world_seed, tallest_face])


func _tallest_addressed_flank_storeys(massif: WarrenMassif,
		from_terrace: bool) -> int:
	## Over the bore family WarrenTownSolver.mass_first_frontier tries: the most
	## storeys any column addressing a route's HIGHEST walk cell builds, counted
	## the way WarrenParcelConstruction.proposal() counts them -- from the
	## bearing datum when `from_terrace`, from natural ground otherwise. -1 when
	## nothing carved.
	var tallest := -1
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
			var datum := massif.bearing_at(column) if from_terrace \
				else massif.base_at(column)
			tallest = maxi(tallest, (massif.top_at(column) - datum
				- WarrenBuildingParcel.ROOF_RESERVATION_BANDS)
				/ WarrenBuildingParcel.STOREY_BANDS)
	return tallest


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

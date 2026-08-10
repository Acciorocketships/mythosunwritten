extends GutTest

## The massif is the primary object of the mass-first pipeline: a deep,
## completely inhabited construction envelope grounded on terrain. It supplies
## the small-mountain silhouette; parcelization turns that mass into rooms and
## roofs, so no hidden stone substrate is permitted.

const StampedGround = preload("res://tests/fixtures/warren_stamped_ground.gd")


func _hill(world_seed: int = 0) -> Dictionary:
	return StampedGround.hill(WarrenMassifBuilder.RADIUS_CELLS + 1, world_seed)


func test_massif_builds_a_terraced_layer_and_is_deterministic() -> void:
	var a := WarrenMassifBuilder.build(1, _hill())
	var b := WarrenMassifBuilder.build(1, _hill())
	assert_not_null(a, WarrenMassifBuilder.last_failure)
	assert_true(a.is_sealed())
	assert_gte(a.vertical_development_bands(),
		WarrenMassifBuilder.MIN_CORE_BANDS,
		"the inhabited bell must reach its vertical-development floor")
	assert_lte(a.core_top_bands, WarrenMassif.BUILDABLE_LAYER_BANDS,
		"the compiler supports a finite eight-storey-plus-roof envelope")
	assert_gte(a.terrace_levels().size(), 5,
		"a smooth dome is not a terraced town silhouette")
	assert_lte(a.widest_plateau_cells(), WarrenMassifBuilder.MAX_PLATEAU_CELLS,
		"wide flat plateaus read as empty platforms, not terraces")
	var worst_step := 0
	for column: Vector2i in a.columns:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor := column + direction
			if a.has_column(neighbor):
				worst_step = maxi(worst_step,
					absi(a.layer_at(column) - a.layer_at(neighbor)))
	assert_lte(worst_step, WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS,
		"neighbouring columns must step like terraces, not cliffs")
	assert_eq(a.columns.size(), b.columns.size())
	for column: Vector2i in a.columns:
		assert_eq(a.top_at(column), b.top_at(column),
			"same seed must give identical column heights")


func test_massif_seeds_differ_and_respect_ground_bands() -> void:
	var hill := _hill()
	var base := WarrenMassifBuilder.build(1, hill)
	var raised_bands: Dictionary = {}
	for column: Vector2i in hill:
		raised_bands[column] = int(hill[column]) + 2
	var raised := WarrenMassifBuilder.build(1, raised_bands)
	assert_not_null(base, WarrenMassifBuilder.last_failure)
	assert_not_null(raised, WarrenMassifBuilder.last_failure)
	var differing := 0
	var other := WarrenMassifBuilder.build(4, hill)
	for column: Vector2i in base.columns:
		if other.has_column(column) \
				and base.layer_at(column) != other.layer_at(column):
			differing += 1
	assert_gt(differing, 10, "different seeds must differ meaningfully")
	for column: Vector2i in raised.columns:
		assert_eq(raised.base_at(column), int(hill[column]) + 2,
			"terrain ground bands lift the massif base")


func test_a_flat_site_still_builds_an_inhabited_town_mountain() \
		-> void:
	## Terrain decides where the town stands, not whether its architecture has a
	## silhouette. The inhabited envelope must create the mountain even on level
	## ground; natural relief then shifts each column's base without becoming
	## hidden structural mass.
	for world_seed: int in [0, 1, 3, 5, 11, 18]:
		var flat := WarrenMassifBuilder.build(world_seed,
			StampedGround.flat(WarrenMassifBuilder.RADIUS_CELLS + 1))
		assert_not_null(flat, "seed %d: %s" % [world_seed,
			WarrenMassifBuilder.last_failure])
		if flat == null:
			continue
		assert_gte(flat.core_top_bands, WarrenMassifBuilder.MIN_CORE_BANDS)
		assert_eq(flat.bearing_at(Vector2i.ZERO), flat.base_at(Vector2i.ZERO),
			"the mountain is inhabited down to terrain")


func test_the_vertical_development_floor_is_derived_from_the_bore() -> void:
	## The crown must contain eight complete inhabited storeys before its roof;
	## the bore's smaller span is a circulation minimum, not the town's height.
	assert_eq(WarrenMassifBuilder.MIN_CORE_BANDS,
		WarrenMassif.MAX_TERRACE_STOREYS \
			* WarrenBuildingParcel.STOREY_BANDS,
		"the crown floor is the complete inhabited storey budget")
	assert_gte(WarrenMassifBuilder.MIN_CORE_BANDS,
		WarrenExcavationCarver.MIN_SPAN_BANDS + WarrenExcavation.HEADROOM_BANDS,
		"the inhabited crown must still contain the required bore")


func _ground_frame(kind: String) -> Dictionary:
	## The input frames warren_mass_first_report --stage terrain uses, so the
	## suite and the measuring instrument describe the same ground.
	##
	## Every variation is laid ON the stamped hill rather than on band zero,
	## because the vertical-development gate is deliberately NOT ground-neutral
	## (it measures lowest ground to highest roof) while the SHAPE gates are --
	## and it is the shape gates this frame family exists to interrogate.
	var span := WarrenMassifBuilder.RADIUS_CELLS + 4
	var hill := StampedGround.hill(span)
	var bands: Dictionary = {}
	for z in range(-span, span + 1):
		for x in range(-span, span + 1):
			var column := Vector2i(x, z)
			var floor_band := int(hill.get(column, 0))
			match kind:
				"hill":
					bands[column] = floor_band
				"slope":
					bands[column] = floor_band + clampi((x + span) / 4, 0, 8)
				"steep":
					bands[column] = floor_band + x + span
				"terrace":
					bands[column] = floor_band \
						+ (0 if x <= -1 else (2 if x == 0 else 6))
				_:
					bands[column] = floor_band
	return bands


func test_gate_verdicts_are_invariant_under_the_ground_the_massif_stands_on() \
		-> void:
	## THE property this wave exists to pin. The massif authors a LAYER of mass
	## above whatever ground it is handed; the ground itself is the terrain's,
	## and the terrain renders it as slope or as dressed cliff. So a shape gate
	## that scores absolute column tops is charging the builder for the
	## landscape -- which is exactly why a smooth slope read as a 10-14 cell
	## plateau and a terraced frame as a 6-band cliff (terrain audit).
	##
	## Stamped on four inputs that differ by up to 44 bands of relief, including
	## one steeper than any terrain can legally produce: identical verdicts,
	## identical relative structure, cell for cell.
	for world_seed: int in [0, 1, 3, 5, 11, 18]:
		var flat := WarrenMassifBuilder.build(world_seed,
			_ground_frame("hill"))
		var flat_failure := WarrenMassifBuilder.last_failure
		for kind: String in ["slope", "steep", "terrace"]:
			var bands := _ground_frame(kind)
			var relief := WarrenMassifBuilder.build(world_seed, bands)
			assert_eq(relief == null, flat == null,
				("seed %d on %s ground: the verdict moved (%s vs flat %s); a " \
				+ "constant-thickness layer draped over relief must be " \
				+ "gate-neutral") % [world_seed, kind,
					WarrenMassifBuilder.last_failure, flat_failure])
			if flat == null or relief == null:
				continue
			assert_eq(relief.columns.size(), flat.columns.size(),
				"seed %d on %s ground: footprint changed" % [world_seed, kind])
			assert_eq(relief.core_top_bands, flat.core_top_bands,
				"seed %d on %s ground: core bands are relief-relative already, "
				% [world_seed, kind] + "so they must not move")
			assert_eq(relief.terrace_levels(), flat.terrace_levels(),
				"seed %d on %s ground: terrace levels moved" \
				% [world_seed, kind])
			assert_eq(relief.widest_plateau_cells(),
				flat.widest_plateau_cells(),
				"seed %d on %s ground: widest plateau moved" \
				% [world_seed, kind])
			for column: Vector2i in flat.columns:
				assert_true(relief.has_column(column),
					"seed %d on %s ground: column %s vanished" \
					% [world_seed, kind, column])
				assert_eq(relief.layer_at(column), flat.layer_at(column),
					"seed %d on %s ground: the layer at %s changed thickness" \
					% [world_seed, kind, column])
				assert_eq(relief.base_at(column), int(bands[column]),
					"seed %d on %s ground: column %s did not take its own " \
					% [world_seed, kind, column] + "input ground as its base")


func test_a_real_layer_cliff_still_fails_the_neighbour_step_gate() -> void:
	## Sabotage-proof for the neighbour-step gate: relief-relativity must not
	## have turned it off. Hand-built because the builder cannot produce an
	## illegal step by construction -- the point is that the GATE still sees one
	## when the layer, not the ground, is what steps.
	##
	## The fixture is a 5x5 pad of one-band rim with a tall column dead centre,
	## so the centre has all four neighbours and the missing-neighbour branch
	## cannot mask the result, while the rim contributes only one band. Run
	## twice: on flat ground, and with the tall column's ground sunk by exactly
	## its extra layer so every absolute top in the pad is equal. The old
	## absolute measure scored that second pad as perfectly level; the
	## relief-relative one still sees the cliff.
	var step := WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS + 2
	for cancelled: bool in [false, true]:
		var massif := WarrenMassif.new(7)
		for z in range(5):
			for x in range(5):
				var centre := x == 2 and z == 2
				var layer := 1 + step if centre else 1
				# `cancelled` sinks the tall column's ground by exactly its extra
				# layer, so every absolute top in the pad is 1 and the OLD
				# absolute measure scored the whole thing as flat.
				var base := -step if centre and cancelled else 0
				massif.columns[Vector2i(x, z)] = {
					"base": base, "top": base + layer, "terrace": layer,
				}
		var tallest_absolute_step := 0
		for column: Vector2i in massif.columns:
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
					Vector2i.UP, Vector2i.DOWN]:
				if massif.has_column(column + direction):
					tallest_absolute_step = maxi(tallest_absolute_step,
						absi(massif.top_at(column)
							- massif.top_at(column + direction)))
		if cancelled:
			assert_eq(tallest_absolute_step, 0,
				"the fixture must be flat in ABSOLUTE terms, or it proves "
				+ "nothing about relief-relativity")
		var worst := WarrenMassifBuilder._worst_neighbor_step(massif)
		assert_eq(worst, step,
			("a %d-band step in the authored layer is a cliff whether or not " \
			+ "the ground cancels it in absolute terms (cancelled=%s)") \
			% [step, cancelled])
		assert_gt(worst, WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS,
			"the neighbour-step gate must still have teeth (cancelled=%s)" \
			% cancelled)


func test_a_real_layer_plateau_still_fails_the_plateau_gate() -> void:
	## The plateau gate's counterpart sabotage-proof, and its converse: a
	## constant-thickness layer laid on a STAIRCASE of ground is not a plateau
	## even though its absolute tops rise in lockstep, while a genuine
	## constant-LAYER slab is one however the ground beneath it moves.
	var wide := WarrenMassifBuilder.MAX_PLATEAU_CELLS + 3
	var slab := WarrenMassif.new(8)
	for x in range(wide):
		slab.columns[Vector2i(x, 0)] = {"base": x, "top": x + 5, "terrace": 5}
	assert_eq(slab.widest_plateau_cells(), wide,
		"%d columns of identical layer thickness are one plateau however " \
		% wide + "much the ground under them climbs")
	assert_gt(slab.widest_plateau_cells(),
		WarrenMassifBuilder.MAX_PLATEAU_CELLS,
		"the plateau gate must still have teeth")

	var terraced := WarrenMassif.new(9)
	for x in range(wide):
		# Layer thins by one band per column exactly as the ground rises by one:
		# every absolute top is 10, which the old measure scored as one wide
		# plateau and the audit observed on every slope.
		terraced.columns[Vector2i(x, 0)] = {
			"base": x, "top": 10, "terrace": 10 - x,
		}
	assert_eq(terraced.widest_plateau_cells(), 1,
		"columns of differing layer thickness are separate terraces even " \
		+ "when a rising ground makes their absolute tops equal")
	assert_eq(terraced.terrace_levels().size(), wide,
		"each distinct layer thickness is its own terrace level")


func test_the_layer_cap_bounds_the_inhabited_mountain() -> void:
	## Every addressed flank is real building mass from its own terrain base.
	## The finite recipe stack still caps the tallest possible house.
	var measured := 0
	for world_seed in [7, 11]:
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		assert_not_null(massif, WarrenMassifBuilder.last_failure)
		if massif == null:
			continue
		for column: Vector2i in massif.columns:
			measured += 1
			assert_eq(massif.bearing_at(column), massif.base_at(column),
				"seed %d: bearing must be the terrain datum" % world_seed)
			var storeys := maxi(0, (massif.layer_at(column)
				- WarrenBuildingParcel.ROOF_RESERVATION_BANDS)
				/ WarrenBuildingParcel.STOREY_BANDS)
			assert_lte(storeys, WarrenMassif.MAX_TERRACE_STOREYS,
				"seed %d: column %s exceeds the inhabited stack cap" % [
					world_seed, column])
	assert_gt(measured, 0, "the fixtures did not contain any massif columns")


func test_the_buildable_layer_is_derived_from_the_parcel_contract() -> void:
	## WarrenMassif deliberately restates the layer rather than importing the
	## parcel vocabulary, so this is the only thing stopping the two drifting.
	assert_eq(WarrenMassif.BUILDABLE_LAYER_BANDS,
		WarrenMassif.MAX_TERRACE_STOREYS * WarrenBuildingParcel.STOREY_BANDS
		+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS,
		"the buildable layer must be exactly MAX_TERRACE_STOREYS storeys "
		+ "plus one roof reservation")
	assert_eq(WarrenMassifBuilder.MAX_LAYER_BANDS,
		WarrenMassif.BUILDABLE_LAYER_BANDS,
		"the builder may not author a column taller than one buildable layer")
	assert_lte(WarrenMassifBuilder.MIN_LAYER_BANDS,
		WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS,
		"the rim must taper within one ordinary terrace riser")
	assert_eq(WarrenMassif.ADDRESS_BANDS,
		WarrenVolumePlan.MIN_ADDRESS_BUILDING_BANDS,
		"mass-first and the common public-realm contract must agree on "
		+ "what constitutes an inhabited street wall")
	assert_eq(WarrenVolumeEnvelope.DEFAULT_ADDRESS_BANDS,
		WarrenVolumePlan.MIN_ADDRESS_BUILDING_BANDS,
		"route-first envelopes must keep the published frontage bar exactly")
	var massif := WarrenMassifBuilder.build(1, _hill())
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	if massif == null:
		return
	for column: Vector2i in massif.columns:
		assert_lte(massif.layer_at(column), WarrenMassif.BUILDABLE_LAYER_BANDS,
			"the layer at %s is thicker than one buildable layer" % column)
		# No second construction datum: every authored band is inhabitable.
		assert_eq(massif.bearing_at(column), massif.base_at(column),
			"the bearing datum must be natural ground at %s: nothing the "
			% column + "fabric authors stands below the buildable layer")


func test_the_rim_steps_down_to_the_ground_like_every_other_terrace() -> void:
	## Empty ground beside a boundary column IS height zero, and the neighbour
	## step limit applies to it. Without that the rim was a legal 7-16 band
	## cliff (measured over seeds 0-39) which every remedy so far re-skinned --
	## timber, then stone -- rather than removed. With it the tallest continuous
	## vertical face anywhere in the solid is one riser, so a viewer never sees
	## more than MAX_NEIGHBOR_STEP_BANDS of unbroken wall before a setback,
	## whatever material later dresses it.
	for world_seed: int in [0, 1, 3, 5, 11, 18]:
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
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
				# LAYER, not absolute top: the ground step between two columns
				# is the terrain's face to render, and charging it here is what
				# the relief-relative wave removed.
				var exposed := massif.layer_at(column) \
					if not massif.has_column(neighbor) \
					else massif.layer_at(column) - massif.layer_at(neighbor)
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
	var built := WarrenMassifBuilder.build(1, _hill())
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

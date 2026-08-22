extends GutTest


func _sealed_fixture() -> WarrenMazeSourcePlan:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(12, {}, profile)
	return WarrenMazeCarver.carve(12, massif, profile)


func _unsealed_fixture() -> WarrenMazeSourcePlan:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(12, {}, profile)
	return WarrenMazeCarver.carve(12, massif, profile, false)


func test_carve_can_return_an_unsealed_plan_for_the_phase_pipeline() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(12, {}, profile)
	var plan := WarrenMazeCarver.carve(12, massif, profile, false)
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	assert_false(plan.is_sealed())
	assert_true(plan.seal(), plan.last_rejection)
	var sealed := WarrenMazeCarver.carve(12, massif, profile)
	assert_eq(plan.deterministic_signature(),
		sealed.deterministic_signature(),
		"deferred seal must not change what was carved")


func test_edit_ledger_overlays_the_sealed_massif() -> void:
	var plan := _unsealed_fixture()
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	var column: Vector2i = plan.massif.columns.keys()[0]
	var base := plan.massif.base_at(column)
	assert_eq(plan.effective_base(column), base,
		"no edit means the massif value shows through")
	assert_true(plan.record_edit(column, base + 1,
		plan.massif.top_at(column), &"reserve"))
	assert_eq(plan.effective_base(column), base + 1)
	assert_eq(plan.foundation_depth(column), 1,
		"a raised floor is a one-band rock foundation")


func test_edits_may_never_sink_below_terrain_or_touch_streets() -> void:
	var plan := _unsealed_fixture()
	var column: Vector2i = plan.massif.columns.keys()[0]
	assert_false(plan.record_edit(column,
		plan.massif.base_at(column) - 1, plan.massif.top_at(column),
		&"reserve"), "terrain is the immutable floor")
	var street := plan.passage_cells()[0]
	assert_false(plan.record_edit(Vector2i(street.x, street.z),
		street.y + 1, street.y + 4, &"reserve"),
		"carved streets are immutable after the bore")


func test_signature_covers_ledger_claims_and_reservations() -> void:
	var first := _sealed_fixture()
	var second := _sealed_fixture()
	assert_eq(first.deterministic_signature(),
		second.deterministic_signature())
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(12, {}, profile)
	var edited := WarrenMazeCarver.carve(12, massif, profile, false)
	assert_not_null(edited, WarrenMazeCarver.last_failure)
	var column: Vector2i = edited.massif.columns.keys()[0]
	assert_true(edited.record_edit(column, edited.massif.base_at(column) + 1,
		edited.massif.top_at(column), &"reserve"))
	assert_true(edited.seal(), edited.last_rejection)
	assert_ne(first.deterministic_signature(),
		edited.deterministic_signature(),
		"an edit must change the sealed identity")


func test_record_edit_on_a_sealed_plan_is_rejected() -> void:
	var plan := _sealed_fixture()
	assert_true(plan.is_sealed())
	var column: Vector2i = plan.massif.columns.keys()[0]
	assert_false(plan.record_edit(column, plan.massif.base_at(column) + 1,
		plan.massif.top_at(column), &"reserve"),
		"a sealed plan's ledger is frozen")
	assert_true(plan.column_edits.is_empty())


func test_reservation_pass_lands_features_with_reason_codes() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(12, {}, profile)
	var plan := WarrenMazeCarver.carve(12, massif, profile, false)
	assert_true(WarrenMazeReservationPass.reserve(plan, profile),
		WarrenMazeReservationPass.last_failure)
	var outcomes := plan.audit.get("reservation_outcomes", []) as Array
	assert_gt(outcomes.size(), 0)
	for outcome: Dictionary in outcomes:
		assert_true(outcome.has("kind") and outcome.has("result"))
	for reservation: Dictionary in plan.reservations:
		for cell: Vector2i in reservation.cells:
			for passage: Vector3i in plan.passage_cells():
				assert_ne(cell, Vector2i(passage.x, passage.z),
					"reservations never claim street columns")
	# The brief's prose is the authority: every non-optional kind either lands
	# at least its quota minimum, or the shortfall is itself a reason-coded
	# outcome -- a silent, unaccounted skip is what this guards against.
	for entry: Dictionary in WarrenMazeReservationPass.REGISTRY:
		if bool(entry.optional):
			continue
		var kind := entry.kind as StringName
		var quota := (entry.quota as Dictionary).get(
			"compact", Vector2i.ZERO) as Vector2i
		var placed := 0
		for reservation: Dictionary in plan.reservations:
			if StringName(reservation.get("kind", &"")) == kind:
				placed += 1
		var has_shortfall_outcome := false
		for outcome: Dictionary in outcomes:
			if StringName(outcome.get("kind", &"")) == kind \
					and StringName(outcome.get("result", &"")) \
						== &"quota_shortfall":
				has_shortfall_outcome = true
				break
		assert_true(placed >= quota.x or has_shortfall_outcome,
			"%s must land >= its quota minimum (%d) or record a quota_shortfall outcome; placed=%d" \
				% [String(kind), quota.x, placed])


func test_reservation_edits_carry_reserve_phase_and_avoid_passage_columns() -> void:
	## Refined 2026-08-22 (slice 1c task 1, rule 3/4): a passage column is no
	## longer categorically off limits -- claim_overhead's bridge-consuming
	## path deliberately edits a covered span's own passage columns to build
	## a skywalk deck directly on top of the street, legal exactly when the
	## edit's own floor clears every hosted passage's own headroom (the same
	## bound WarrenMazeSourcePlan._passage_headroom_floor shares with
	## record_trim and seal()). Re-derived here independently (max hosted
	## passage y + WarrenExcavation.HEADROOM_BANDS per column) rather than
	## reaching into the plan's own private helper, so this test does not
	## just check the implementation against itself.
	var profile := WarrenVillageScaleProfile.for_id(&"standard")
	var massif := WarrenMassifBuilder.build(1, {}, profile)
	var plan := WarrenMazeCarver.carve(1, massif, profile, false)
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	assert_true(WarrenMazeReservationPass.reserve(plan, profile),
		WarrenMazeReservationPass.last_failure)
	assert_false(plan.column_edits.is_empty(),
		"the reservation pass should have recorded at least one edit")
	var passage_headroom_floor: Dictionary = {}
	for cell: Vector3i in plan.passage_cells():
		var column := Vector2i(cell.x, cell.z)
		var floor_needed := cell.y + WarrenExcavation.HEADROOM_BANDS
		passage_headroom_floor[column] = maxi(
			int(passage_headroom_floor.get(column, floor_needed)), floor_needed)
	for column: Vector2i in plan.column_edits.keys():
		var edit := plan.column_edits[column] as Dictionary
		assert_eq(StringName(edit.get("phase", &"")), &"reserve",
			"every edit the reservation pass records is phase reserve")
		if passage_headroom_floor.has(column):
			assert_gte(int(edit.get("floor_band", 0)),
				int(passage_headroom_floor[column]),
				("edit at column %s touches a passage column without " \
					+ "clearing its own headroom") % column)


func test_overhead_reservations_never_claim_passage_columns() -> void:
	## test_reservation_edits_carry_reserve_phase_and_avoid_passage_columns only
	## walks column_edits, which claim_overhead never writes (it records a
	## reservation with no edits), so it cannot cover a skywalk_span flank
	## that is itself a passage column. Seed 2 compact was probed to actually
	## land an overhead reservation, so this exercises the real code path
	## rather than vacuously passing on an empty reservation list.
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(2, {}, profile)
	var plan := WarrenMazeCarver.carve(2, massif, profile, false)
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	assert_true(WarrenMazeReservationPass.reserve(plan, profile),
		WarrenMazeReservationPass.last_failure)
	var passage_columns: Dictionary = {}
	for cell: Vector3i in plan.passage_cells():
		passage_columns[Vector2i(cell.x, cell.z)] = true
	var overhead_reservations: Array[Dictionary] = []
	for reservation: Dictionary in plan.reservations:
		if not (reservation.walk_cells as Array).is_empty():
			overhead_reservations.append(reservation)
	assert_gt(overhead_reservations.size(), 0,
		"seed 2 compact is expected to land at least one skywalk_span reservation")
	for reservation: Dictionary in overhead_reservations:
		for cell: Vector2i in reservation.cells:
			assert_false(passage_columns.has(cell),
				"an overhead reservation's flanking column must never be a passage column")


func test_reservation_pass_selects_different_optional_subsets_across_seeds() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var optional_kinds: Array[StringName] = []
	for entry: Dictionary in WarrenMazeReservationPass.REGISTRY:
		if bool(entry.optional):
			optional_kinds.append(entry.kind as StringName)
	var subsets: Dictionary = {}
	for city_seed in range(1, 13):
		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
		if plan == null:
			# A handful of seeds fail the P1/P2 carve itself (unrelated to this
			# pass, e.g. seed 7 misses the frontage floor at compact scale);
			# the reservation pass has nothing to run against those.
			continue
		assert_true(WarrenMazeReservationPass.reserve(plan, profile),
			WarrenMazeReservationPass.last_failure)
		var selected: Dictionary = {}
		for outcome: Dictionary in plan.audit.get(
				"reservation_outcomes", []) as Array:
			var kind := StringName(outcome.get("kind", &""))
			if kind in optional_kinds and StringName(outcome.get(
					"result", &"")) != &"optional_not_selected":
				selected[kind] = true
		var keys: Array = selected.keys()
		keys.sort()
		subsets[city_seed] = str(keys)
	var distinct: Dictionary = {}
	for value: Variant in subsets.values():
		distinct[value] = true
	assert_gt(distinct.size(), 1,
		"optional subsets across seeds 1-12 must show real variation: %s" \
			% str(subsets))


func test_stamping_produces_building_shaped_claims_not_pencils() -> void:
	## Geometry-aware exit assertion (controller ruling #2): a building is a
	## LINEAGE, not a single claim -- the L-shape already treats two claims
	## sharing one lineage_hint as one building, and WarrenMazeStampPass's
	## bounded lineage-grouping post-pass extends that to every claim, so a
	## staircase-shaped blob split into several rectangles for the footprint
	## contract still reads as one stepped building here. Checks: no claim
	## degenerates into a pencil tower (per claim), no rectangular claim's
	## footprint reaches deeper from its door_column than its original shape
	## depth plus the back-extension cap (per claim -- the cumulative-depth
	## fix), the town is at least half lineages that clear a single-column
	## footprint (summed per lineage), every seed lands at least one
	## genuinely building-shaped (area >= 4) claim, and the grouping rule
	## itself holds -- every lineage's claims stay within one band of
	## each other. Also asserts the three translatability invariants
	## directly (controller ruling #3, following Task 7's discovery that
	## most claims could not seal as parcels): floor_band == door_walk.y,
	## every footprint stays within the authored size menu, and every
	## claim's door_walk sits on a passage cell adjacent to its own
	## footprint.
	for city_seed: int in [1, 3, 4, 12]:
		var profile := WarrenVillageScaleProfile.for_id(&"compact")
		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
		if plan == null:
			continue
		assert_true(WarrenMazeReservationPass.reserve(plan, profile))
		assert_true(WarrenMazeStampPass.stamp(plan, profile),
			WarrenMazeStampPass.last_failure)
		var original_arm_depths := plan.audit.get(
			"stamp_original_arm_depth", {}) as Dictionary
		var has_area_4_or_more := false
		var lineage_areas: Dictionary = {}
		var lineage_floors: Dictionary = {}
		for claim: Dictionary in plan.parcel_claims:
			var footprint := claim.footprint as Array[Vector2i]
			has_area_4_or_more = has_area_4_or_more or footprint.size() >= 4
			if footprint.size() == 1:
				assert_lte(int(claim.top_band) - int(claim.floor_band),
					2 * WarrenBuildingParcel.STOREY_BANDS,
					"a 1x1 claim may not become a pencil tower")
			var shape_id := String(claim.get("shape_id", ""))
			var door_column := claim.door_column as Vector2i
			var door_walk := claim.door_walk as Vector3i
			var claim_frontage := claim.frontage as Vector2i

			# Invariant 1: the datum is the addressing street's own
			# elevation, never a footprint-terrain majority --
			# WarrenBuildingParcel.seal()'s unconditional first check is
			# address_walk_cell.y != base_band -> false.
			assert_eq(int(claim.floor_band), door_walk.y,
				"seed %d: claim at door_column %s has floor_band %d != door_walk.y %d" \
					% [city_seed, str(door_column), int(claim.floor_band),
						door_walk.y])

			# Invariant 2: every footprint, after back-extension, lateral
			# extension, and 1x1 merges, must stay within the authored size
			# menu -- WarrenParcelConstruction.profile_for has no template
			# for anything else.
			var claim_into_block := -claim_frontage
			var claim_depth := WarrenMazeStampPass._footprint_depth(
				footprint, claim_into_block)
			var claim_width := footprint.size() / claim_depth
			assert_true(WarrenMazeStampPass._is_menu_shape(claim_width,
				claim_depth),
				("seed %d: claim at door_column %s is %dx%d (w x d), " \
					+ "outside the authored size menu") \
						% [city_seed, str(door_column), claim_width,
							claim_depth])

			# Invariant 3: every claim -- including an L's wing -- carries a
			# door_walk on a passage cell adjacent to its OWN footprint, so
			# door_serves_address can hold for some phase.
			assert_true(footprint.has(door_column),
				"seed %d: claim at door_column %s does not contain its own threshold" \
					% [city_seed, str(door_column)])
			assert_eq(door_column + claim_frontage,
				Vector2i(door_walk.x, door_walk.z),
				"seed %d: claim at door_column %s: threshold + frontage != door_walk" \
					% [city_seed, str(door_column)])
			assert_true(plan.passage_kinds.has(door_walk),
				"seed %d: claim at door_column %s: door_walk %s is not a passage cell" \
					% [city_seed, str(door_column), str(door_walk)])

			if not shape_id.begins_with("L.") \
					and original_arm_depths.has(door_column):
				var into_block := -(claim.frontage as Vector2i)
				var max_projection := 0
				for column: Vector2i in footprint:
					var delta := column - door_column
					var projection := delta.x * into_block.x \
						+ delta.y * into_block.y
					max_projection = maxi(max_projection, projection)
				var extent := max_projection + 1
				var allowed := int(original_arm_depths[door_column]) \
					+ WarrenMazeStampPass.MAX_BACK_EXTENSION_DEPTH
				assert_lte(extent, allowed,
					("seed %d: claim at door %s reaches %d deep, past its " \
						+ "original depth (%d) plus the back-extension cap (%d)") \
							% [city_seed, str(door_column), extent,
								int(original_arm_depths[door_column]),
								WarrenMazeStampPass.MAX_BACK_EXTENSION_DEPTH])
			var lineage := StringName(claim.get("lineage_hint", &""))
			assert_ne(lineage, &"",
				"seed %d: every claim must belong to a lineage after grouping" \
					% city_seed)
			lineage_areas[lineage] = int(lineage_areas.get(lineage, 0)) \
				+ footprint.size()
			var floors: Array = lineage_floors.get(lineage, [])
			floors.append(int(claim.floor_band))
			lineage_floors[lineage] = floors
		for lineage: Variant in lineage_floors.keys():
			var floors: Array = lineage_floors[lineage]
			var lowest: int = floors[0]
			var highest: int = floors[0]
			for value: int in floors:
				lowest = mini(lowest, value)
				highest = maxi(highest, value)
			assert_lte(highest - lowest, 1,
				"seed %d: lineage %s spans more than one band" \
					% [city_seed, String(lineage)])
		var sums: Array[int] = []
		sums.assign(lineage_areas.values())
		sums.sort()
		assert_gte(sums[sums.size() / 2], 2,
			"seed %d: median lineage footprint must clear a single column" \
				% city_seed)
		assert_true(has_area_4_or_more,
			"seed %d: at least one claim must be building-shaped (area >= 4)" \
				% city_seed)


func test_stamp_edits_stay_within_one_band_and_own_apron() -> void:
	## A flat ground_bands fixture never varies massif.base_at, so the +/-1
	## band edit path never fires and this test used to assert nothing (see
	## task-4 report). Slope the input instead: base rises one band every 3
	## columns across the massif's own star-shaped footprint. The footprint
	## is seed-dependent (WarrenMassifBuilder only creates a column where the
	## Gaussian field clears MIN_COLUMN_BANDS), so it is learned from a flat
	## build first, then the same columns are rebuilt with a sloped
	## ground_bands (`base := int(ground_bands.get(column, 0))` per column,
	## per WarrenMassifBuilder.build).
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var city_seed := 1
	var flat_massif := WarrenMassifBuilder.build(city_seed, {}, profile)
	assert_not_null(flat_massif, WarrenMassifBuilder.last_failure)
	var min_x := 2147483647
	for column: Vector2i in flat_massif.columns.keys():
		min_x = mini(min_x, column.x)
	var ground_bands: Dictionary = {}
	for column: Vector2i in flat_massif.columns.keys():
		ground_bands[column] = int(floor(float(column.x - min_x) / 3.0))
	var massif := WarrenMassifBuilder.build(city_seed, ground_bands, profile)
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	assert_true(WarrenMazeReservationPass.reserve(plan, profile),
		WarrenMazeReservationPass.last_failure)
	assert_true(WarrenMazeStampPass.stamp(plan, profile),
		WarrenMazeStampPass.last_failure)

	## Refined 2026-08-21 (the tiers unlock): a stamp edit may now also be a
	## BEARING edit, which may move its floor by more than one band as long
	## as the pre-edit massif carried continuous solid mass through it --
	## _column_bears proved that precisely (band-by-band, ledger-aware) at
	## placement time; this mirrors seal()'s own cheaper re-validation
	## (a massif-range check) rather than re-deriving the full walk here.
	var stamp_edit_columns: Array[Vector2i] = []
	for column_value: Variant in plan.column_edits.keys():
		var column := column_value as Vector2i
		var edit := plan.column_edits[column] as Dictionary
		if StringName(edit.phase) != &"stamp":
			continue
		stamp_edit_columns.append(column)
		var floor_band := int(edit.floor_band)
		var drift := absi(floor_band - plan.massif.base_at(column))
		if drift > 1:
			assert_true(bool(edit.get("bearing", false)),
				("stamp edit at %s moves its floor %d bands but is not " 					+ "marked bearing") % [column, drift])
			assert_true(plan.massif.base_at(column) <= floor_band 					and floor_band <= plan.massif.top_at(column),
				("bearing edit at %s must have its floor within the " 					+ "pre-edit massif's own [base, top] range") % column)
	assert_gt(stamp_edit_columns.size(), 0,
		"the sloped fixture must actually exercise the stamp-phase edit path")

	# Every stamp-phase edited column sits inside some claim's footprint, or
	# at most one column outside it -- the footprint + 1-column apron rule.
	for column: Vector2i in stamp_edit_columns:
		var inside_apron := false
		for claim: Dictionary in plan.parcel_claims:
			for member: Vector2i in claim.footprint as Array[Vector2i]:
				var delta := member - column
				if absi(delta.x) + absi(delta.y) <= 1:
					inside_apron = true
					break
			if inside_apron:
				break
		assert_true(inside_apron,
			"stamp edit at %s is not inside any claim's footprint or its apron" \
				% column)

	# Final-review fix wave (finding 1): a batch of offender edits is recorded
	# all-or-nothing via WarrenMazeStampPass._record_offender_batch, so a real
	# stamp run can never leave a partially-committed batch behind. There is
	# no dedicated "partial batch" outcome key -- confirming stamp_outcomes
	# never grows one is a canary against a future regression reintroducing
	# the per-offender early-return the fix replaced.
	var stamp_outcomes := plan.audit.get("stamp_outcomes", {}) as Dictionary
	assert_false(stamp_outcomes.has("partial_batch"),
		"a partial_batch outcome key would mean the atomic-commit invariant broke")


func test_record_offender_batch_is_all_or_nothing_when_an_offender_hosts_a_passage() -> void:
	## Direct unit test on WarrenMazeStampPass._record_offender_batch (finding
	## 1's strongest form): a synthetic batch of two offenders where the FIRST
	## is individually valid and the SECOND hosts a passage on some band. The
	## old code (a bare loop calling plan.record_edit per offender, aborting
	## on the first rejection) would have already committed the first
	## offender's edit before ever reaching the second -- stranding a floor/top
	## edit with no claim recorded to match it. The fixed batch helper
	## validates every offender first and commits nothing if any of them fails.
	var plan := _unsealed_fixture()
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	assert_false(plan.passage_cells().is_empty())

	var passage_columns: Dictionary = {}
	for cell: Vector3i in plan.passage_cells():
		passage_columns[Vector2i(cell.x, cell.z)] = true
	var passage_column := Vector2i(plan.passage_cells()[0].x,
		plan.passage_cells()[0].z)

	var clean_column: Vector2i
	var found_clean := false
	for column: Vector2i in plan.massif.columns.keys():
		if not passage_columns.has(column):
			clean_column = column
			found_clean = true
			break
	assert_true(found_clean,
		"fixture must contain at least one column with no passage on any band")

	var floor_band := plan.massif.base_at(clean_column)
	var top_band := plan.massif.top_at(clean_column)
	var outcomes: Dictionary = {}
	var offenders: Array[Vector2i] = [clean_column, passage_column]
	var committed := WarrenMazeStampPass._record_offender_batch(plan, offenders,
		floor_band, top_band, &"stamp", outcomes, {})

	assert_false(committed,
		"a batch containing a passage-hosting offender must not commit")
	assert_true(plan.column_edits.is_empty(),
		"zero edits may be recorded when any offender in the batch is rejected -- " \
			+ "including the earlier, individually-valid offender")
	assert_eq(int(outcomes.get("edit_rejected", 0)), 1)


func test_foundations_are_derived_from_datum_minus_terrain() -> void:
	## Same sloped-fixture technique as
	## test_stamp_edits_stay_within_one_band_and_own_apron: a flat
	## ground_bands fixture never raises any column's floor above its own
	## terrain sample, so foundation_columns would be vacuously empty. Slope
	## the input, learn the footprint from a flat build first (it is
	## seed-dependent), then rebuild sloped over the same columns.
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var city_seed := 12
	var flat_massif := WarrenMassifBuilder.build(city_seed, {}, profile)
	assert_not_null(flat_massif, WarrenMassifBuilder.last_failure)
	var min_x := 2147483647
	for column: Vector2i in flat_massif.columns.keys():
		min_x = mini(min_x, column.x)
	var ground_bands: Dictionary = {}
	for column: Vector2i in flat_massif.columns.keys():
		ground_bands[column] = int(floor(float(column.x - min_x) / 3.0))
	var massif := WarrenMassifBuilder.build(city_seed, ground_bands, profile)
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	assert_gt(massif.columns.size(), 0,
		"the sloped fixture must actually have columns, or every assertion " \
			+ "below passes vacuously")
	var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	assert_true(WarrenMazeReservationPass.reserve(plan, profile),
		WarrenMazeReservationPass.last_failure)
	assert_true(WarrenMazeStampPass.stamp(plan, profile),
		WarrenMazeStampPass.last_failure)

	# Every claimed column's effective floor sits at or above its own terrain
	# sample -- the immutable-floor rule enforced through the whole pipeline.
	var claimed_columns: Dictionary = {}
	for claim: Dictionary in plan.parcel_claims:
		for column: Vector2i in claim.footprint as Array[Vector2i]:
			claimed_columns[column] = true
			assert_gte(plan.effective_base(column), plan.massif.base_at(column),
				"claimed column %s sits below terrain" % column)
	assert_gt(claimed_columns.size(), 0,
		"the sloped fixture must actually claim columns, or the map is empty " \
			+ "and every assertion below passes vacuously")

	var foundation_columns := plan.audit.get("foundation_columns", {}) \
		as Dictionary
	assert_false(foundation_columns.is_empty(),
		"a slope this steep must raise at least one claimed column's floor " \
			+ "above terrain")

	# A column may now carry more than one claim (Task 1 stacking): only the
	# LOWEST claim's floor_band on a given column ever needs a foundation
	# reaching down to terrain (everything stacked above it is supported by
	# the mass/claim below, not by an independent foundation), so the
	# governing floor per column is the minimum across every claim that
	# touches it -- exactly what WarrenMazeStampPass.derive_foundations keys
	# foundation_columns by.
	var min_floor_by_column: Dictionary = {}
	for claim: Dictionary in plan.parcel_claims:
		var floor_band := int(claim.floor_band)
		for column: Vector2i in claim.footprint as Array[Vector2i]:
			if not min_floor_by_column.has(column) \
					or floor_band < int(min_floor_by_column[column]):
				min_floor_by_column[column] = floor_band

	# Every claimed column whose GOVERNING (lowest) floor_band clears its own
	# foundation datum appears with the right depth; every claimed column at
	# (or below) grade is omitted entirely. Bridge-capable columns
	# (controller ruling, 2026-08-22, slice 1c task 1): a PASSAGE-HOSTING
	# column's datum is that passage's own required headroom floor
	# (WarrenMazeSourcePlan._passage_headroom_floor), never terrain -- the
	# rock between terrain and the headroom is real, untouched massif the
	# street already runs through, not something construction fabricates as
	# foundation. A non-passage column's datum stays terrain, unchanged.
	for column: Vector2i in min_floor_by_column.keys():
		var floor_band := int(min_floor_by_column[column])
		var headroom_floor := plan._passage_headroom_floor(column)
		var datum := headroom_floor if headroom_floor >= 0 \
			else plan.massif.base_at(column)
		if floor_band > datum:
			assert_true(foundation_columns.has(column),
				("claimed column %s at floor %d above its own foundation " \
					+ "datum %d is missing from foundation_columns") \
						% [column, floor_band, datum])
			assert_eq(int(foundation_columns[column]), floor_band - datum,
				"foundation depth at %s is wrong" % column)
		else:
			assert_false(foundation_columns.has(column),
				"claimed column %s at or below its own foundation datum " \
					% column + "must not appear in foundation_columns")

	# Same contract for reservation cells whose datum_band clears their own
	# foundation datum -- except a FLANK-search skywalk_span reservation
	# (walk_cells non-empty, no `plot_top` key), which is excluded outright
	# regardless of datum vs terrain (see the next block); a bridge-consumed
	# one (walk_cells non-empty, has `plot_top`) is a real edited column and
	# is checked exactly like any other reservation.
	for reservation: Dictionary in plan.reservations:
		if not (reservation.get("walk_cells", []) as Array).is_empty() \
				and not reservation.has("plot_top"):
			continue
		var datum_band := int(reservation.datum_band)
		for column: Vector2i in reservation.cells as Array[Vector2i]:
			var headroom_floor := plan._passage_headroom_floor(column)
			var datum := headroom_floor if headroom_floor >= 0 \
				else plan.massif.base_at(column)
			if datum_band > datum:
				assert_true(foundation_columns.has(column),
					("reservation column %s at datum_band %d above its " \
						+ "own foundation datum %d is missing from " \
						+ "foundation_columns") \
							% [column, datum_band, datum])
				assert_eq(int(foundation_columns[column]), datum_band - datum,
					"foundation depth at %s is wrong" % column)
			else:
				assert_false(foundation_columns.has(column),
					"reservation column %s at or below its own foundation " \
						% column + "datum must not appear in foundation_columns")

	# Overhead (skywalk_span) reservations are excluded outright, even when
	# their walk band clears terrain -- their flanks stand on grounded rock
	# (claim_overhead never edits a floor), so a foundation entry there would
	# be nonsense for slice-2's retained-foundation machinery. Seed 2 compact
	# is the fixture test_overhead_reservations_never_claim_passage_columns
	# already relies on to actually land a skywalk_span reservation.
	var overhead_profile := WarrenVillageScaleProfile.for_id(&"compact")
	var overhead_massif := WarrenMassifBuilder.build(2, {}, overhead_profile)
	var overhead_plan := WarrenMazeCarver.carve(2, overhead_massif,
		overhead_profile, false)
	assert_not_null(overhead_plan, WarrenMazeCarver.last_failure)
	assert_true(WarrenMazeReservationPass.reserve(overhead_plan,
		overhead_profile), WarrenMazeReservationPass.last_failure)
	assert_true(WarrenMazeStampPass.stamp(overhead_plan, overhead_profile),
		WarrenMazeStampPass.last_failure)
	var overhead_reservations: Array[Dictionary] = []
	for reservation: Dictionary in overhead_plan.reservations:
		if not (reservation.walk_cells as Array).is_empty():
			overhead_reservations.append(reservation)
	assert_gt(overhead_reservations.size(), 0,
		"seed 2 compact is expected to land at least one skywalk_span " \
			+ "reservation")
	var overhead_foundation_columns := overhead_plan.audit.get(
		"foundation_columns", {}) as Dictionary
	for reservation: Dictionary in overhead_reservations:
		for column: Vector2i in reservation.cells as Array[Vector2i]:
			assert_false(overhead_foundation_columns.has(column),
				("overhead reservation flank column %s must not appear in " \
					+ "foundation_columns") % column)



func test_site_planner_seals_the_corpus_one_pass() -> void:
	## The planner's own corpus: seeds 1-12 x {compact, standard}. A handful of
	## seeds are known to miss the carve-stage frontage floor (see
	## WarrenMazeCarver's own seed-7-compact caveat, task-3-report.md); this
	## only asserts the failures stay confined to massif/carve -- a reserve,
	## stamp, or seal failure here would mean the planner's own wiring (not a
	## pre-existing generation gate) broke the corpus.
	var scale_ids: Array[StringName] = [&"compact", &"standard"]
	var success := 0
	var total := 0
	var failure_table: Array[String] = []
	for scale_id: StringName in scale_ids:
		var profile := WarrenVillageScaleProfile.for_id(scale_id)
		for city_seed in range(1, 13):
			total += 1
			var result := WarrenMazeSitePlanner.plan(city_seed, {}, profile)
			if result != null:
				success += 1
				assert_true(result.is_sealed(),
					"%s seed %d: plan() with default stop_after must return a sealed plan" \
						% [String(scale_id), city_seed])
			else:
				var failure := WarrenMazeSitePlanner.last_failure
				failure_table.append("%s seed %d: %s" \
					% [String(scale_id), city_seed, failure])
				assert_true(failure.begins_with("massif:") \
						or failure.begins_with("carve:"),
					"%s seed %d: only massif/carve failures are known-acceptable, got: %s" \
						% [String(scale_id), city_seed, failure])
				assert_false(failure.begins_with("reserve:"),
					"%s seed %d: the planner's own reserve wiring must not fail: %s" \
						% [String(scale_id), city_seed, failure])
				assert_false(failure.begins_with("stamp:"),
					"%s seed %d: the planner's own stamp wiring must not fail: %s" \
						% [String(scale_id), city_seed, failure])
	assert_gte(success, 22,
		"expected >= 22/24 successes, got %d/%d:\n%s" \
			% [success, total, "\n".join(failure_table)])

	var compact_profile := WarrenVillageScaleProfile.for_id(&"compact")
	var first := WarrenMazeSitePlanner.plan(12, {}, compact_profile)
	assert_not_null(first, WarrenMazeSitePlanner.last_failure)
	var second := WarrenMazeSitePlanner.plan(12, {}, compact_profile)
	assert_not_null(second, WarrenMazeSitePlanner.last_failure)
	assert_eq(first.deterministic_signature(), second.deterministic_signature(),
		"two one-pass runs of the same seed/profile must seal identically")


func test_stop_after_exposes_each_phase_uncontaminated() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var carved := WarrenMazeSitePlanner.plan(12, {}, profile, &"carve")
	assert_false(carved.is_sealed())
	assert_eq(carved.reservations.size(), 0)
	assert_eq(carved.parcel_claims.size(), 0)
	var reserved := WarrenMazeSitePlanner.plan(12, {}, profile, &"reserve")
	assert_gt(reserved.reservations.size(), 0)
	assert_eq(reserved.parcel_claims.size(), 0,
		"reserve must not have stamped anything yet")
	var stamped := WarrenMazeSitePlanner.plan(12, {}, profile, &"stamp")
	assert_gt(stamped.parcel_claims.size(), 0)


func test_translator_partition_is_one_to_one_with_claims() -> void:
	for city_seed in [12, 4]:
		var profile := WarrenVillageScaleProfile.for_id(&"compact")
		var plan := WarrenMazeSitePlanner.plan(city_seed, {}, profile)
		assert_not_null(plan, "seed %d: %s" \
			% [city_seed, WarrenMazeSitePlanner.last_failure])
		if plan == null:
			continue
		var volume := WarrenMazeVolumeAdapter.to_volume_plan(plan)
		assert_not_null(volume, "seed %d: %s" \
			% [city_seed, WarrenMazeVolumeAdapter.last_failure])
		if volume == null:
			continue
		var parcels := WarrenMazeBlockPartitioner.partition(plan, volume)
		assert_not_null(parcels, "seed %d: %s" \
			% [city_seed, WarrenMazeBlockPartitioner.last_failure])
		if parcels == null:
			continue
		assert_eq(parcels.parcels.size(), plan.parcel_claims.size(),
			"seed %d: translation is 1:1 -- a dropped claim is a generator bug" \
				% city_seed)
		# Controller ruling (fix round 2, task-7-report.md): 0.85 was
		# mis-scoped at the SOURCE level -- the old pipeline only ever cleared
		# it at COMPOSITION, where rooms expand into back/upper mass beyond
		# each parcel's own 2D footprint. That floor now belongs to slice 2's
		# composition-stage exit, not this translator's. What this stage can
		# actually promise, and what stays gated here: a real (if modest)
		# floor on the 2D-footprint ratio, a fully-accounted column breakdown
		# so the composition stage inherits real numbers instead of a black
		# box, and a cap on how much of the town is buildable mass this stage
		# left on the table entirely.
		# Controller adjudication (final-review fix wave, 2026-08-21): finding
		# 3 fixed _ownership_audit_translated's numerator, which used to read a
		# parcel's cells through a fine/macro grid alias that coincidentally
		# over- or under-credited cells with no consistent direction. The old
		# uniform 0.35 floor was calibrated against that artifact-inflated
		# metric, not against what this ratio actually measures now, so it was
		# re-pinned per seed against the CORRECTED metric's own measured
		# baselines -- seed 4: 0.4213, seed 12: 0.3360 -- each minus a small
		# guard.
		# Re-pinned upward (slice 1b task 1, 2026-08-21): the storey budget
		# and skyline trim shrink every claimed column's edited volume down to
		# roughly its own storeys instead of the full massif ceiling, which
		# raises the 2D-footprint ratio's DENOMINATOR-shrinking effect more
		# than it costs the numerator -- measured seed 4: 0.4213 -> 0.5583,
		# seed 12: 0.3360 -> 0.4751.
		# Re-pinned upward again (fix round 4, bearing/tiers unlock,
		# 2026-08-21): upper-street houses that now bear directly on the
		# mountain claim MORE of the massif's own volume per column (the
		# bearing rock they stand on becomes owned foundation, not
		# unclaimed mass), measured seed 4: 0.5583 -> 0.6419, seed 12:
		# 0.4751 -> 0.6073. Per the ruling that an ownership floor may only
		# move UP (never be weakened), both floors are re-pinned again to
		# the new measured baseline minus the same small guard. These stay
		# anti-regression floors (catch a future correctness regression in the
		# audit, stamp, or trim pass), not quality targets; the 0.85 quality
		# target stays slice 2's composition-level exit per the ruling above.
		# Re-pinned upward again (slice 1c task 1, controller rulings
		# 2026-08-22 x3): WarrenMazeVolumeAdapter._edited_massif and
		# WarrenBuildingParcel._has_continuous_bearing both had to become
		# passage-aware before a bridge/bearing claim's own column could
		# translate at all, and WarrenMazeSourcePlan.passage_headroom_top
		# (the real, per-cell carved headroom, replacing cell.y + the flat
		# HEADROOM_BANDS constant everywhere a passage's own required
		# clearance is measured) fixed the one remaining dropped claim on a
		# stair-adjacent cell whose real carved slot ran one band taller than
		# the constant assumed (see task-1-report.md's addenda). Both pinned
		# seeds now translate fully end-to-end for the first time in this
		# test's own history: seed 4 measured 0.6419 -> 0.6885 (unchanged by
		# this final fix, already fully green), seed 12 measured for the
		# first time at 0.6750 (previously unmeasurable). Both floors
		# re-pinned upward to the newly measured baselines minus a guard.
		var ratio := float(parcels.audit.get("maze_owned_solid_ratio", 0.0))
		var ratio_floor := 0.66 if city_seed == 4 else 0.65
		assert_gte(ratio, ratio_floor,
			"seed %d: 2D-footprint ownership anti-regression floor (%.2f); measured %s" \
				% [city_seed, ratio_floor, ratio])
		var breakdown := parcels.audit.get("maze_ownership_breakdown", {}) \
			as Dictionary
		assert_true(breakdown.has("claimed") and breakdown.has("reserved") \
			and breakdown.has("buildable_unclaimed") \
			and breakdown.has("unbuildable"),
			"seed %d: ownership breakdown must publish all four counts: %s" \
				% [city_seed, breakdown])
		var total_columns := plan.massif.columns.size()
		var breakdown_total := int(breakdown.get("claimed", 0)) \
			+ int(breakdown.get("reserved", 0)) \
			+ int(breakdown.get("buildable_unclaimed", 0)) \
			+ int(breakdown.get("unbuildable", 0))
		assert_eq(breakdown_total, total_columns,
			"seed %d: breakdown counts must sum to the massif's %d columns, got %d: %s" \
				% [city_seed, total_columns, breakdown_total, breakdown])
		var accounted_for := int(breakdown.get("claimed", 0)) \
			+ int(breakdown.get("reserved", 0)) \
			+ int(breakdown.get("buildable_unclaimed", 0))
		var unclaimed_buildable_ratio := float(breakdown.get(
			"buildable_unclaimed", 0)) / float(maxi(1, accounted_for))
		assert_lte(unclaimed_buildable_ratio, 0.40,
			("seed %d: buildable_unclaimed/(claimed+reserved+buildable_unclaimed) " \
				+ "= %s must stay <= 0.40: %s") \
				% [city_seed, unclaimed_buildable_ratio, breakdown])


func test_plan_rejects_an_unknown_stop_after_stage() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var result := WarrenMazeSitePlanner.plan(12, {}, profile, &"bogus")
	assert_null(result)
	assert_ne(WarrenMazeSitePlanner.last_failure, "",
		"an unknown stop_after stage must set last_failure")
	assert_true(WarrenMazeSitePlanner.last_failure.contains("bogus"),
		"the failure message should name the offending stop_after value")


func test_seal_merges_audit_instead_of_replacing_it() -> void:
	## seal() used to do `audit = _build_audit()`, a wholesale replacement
	## that destroyed audit keys earlier phases had already written
	## (reservation_outcomes, stamp_outcomes, foundation_columns). A full
	## one-pass planner run exercises every phase, so a sealed plan's audit
	## must still carry all of them.
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var plan := WarrenMazeSitePlanner.plan(4, {}, profile)
	assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
	if plan == null:
		return
	assert_true(plan.is_sealed(), plan.last_rejection)
	assert_true(plan.audit.has("reservation_outcomes"),
		"seal() must not wipe reservation_outcomes written by the reserve phase")
	assert_true(plan.audit.has("stamp_outcomes"),
		"seal() must not wipe stamp_outcomes written by the stamp phase")
	assert_true(plan.audit.has("foundation_columns"),
		"seal() must not wipe foundation_columns written by the stamp phase")


func test_seal_preserves_a_nonempty_foundation_columns_audit() -> void:
	## Same sloped-fixture technique as
	## test_stamp_edits_stay_within_one_band_and_own_apron: a flat
	## ground_bands fixture never raises any claimed column's floor above its
	## own terrain sample, so foundation_columns would be vacuously empty and
	## this could not prove survival through seal()'s merge. Slope the input,
	## learn the footprint from a flat build first (it is seed-dependent),
	## then rebuild sloped over the same columns and run the full planner
	## through seal().
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var city_seed := 1
	var flat_massif := WarrenMassifBuilder.build(city_seed, {}, profile)
	assert_not_null(flat_massif, WarrenMassifBuilder.last_failure)
	var min_x := 2147483647
	for column: Vector2i in flat_massif.columns.keys():
		min_x = mini(min_x, column.x)
	var ground_bands: Dictionary = {}
	for column: Vector2i in flat_massif.columns.keys():
		ground_bands[column] = int(floor(float(column.x - min_x) / 3.0))
	var plan := WarrenMazeSitePlanner.plan(city_seed, ground_bands, profile)
	assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
	if plan == null:
		return
	assert_true(plan.is_sealed(), plan.last_rejection)
	var foundation_columns := plan.audit.get("foundation_columns", {}) \
		as Dictionary
	assert_false(foundation_columns.is_empty(),
		"a slope this steep must raise at least one claimed column's floor " \
			+ "above terrain, and seal() must not wipe it from the audit")


func test_seal_rejects_a_stamp_edit_outside_every_claims_apron() -> void:
	## Finding 4 (final-review fix wave): seal() must validate that every
	## stamp-phase edit sits within one column of some claim's own footprint --
	## a doctored plan with a stamp edit far from every claim must fail seal
	## with a named, apron-specific reason. WarrenMazeStampPass's own candidate
	## enumeration is supposed to guarantee this by construction; this test
	## proves seal() actually re-checks it rather than trusting that.
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var plan := WarrenMazeSitePlanner.plan(12, {}, profile, &"stamp")
	assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
	assert_false(plan.is_sealed())
	assert_false(plan.parcel_claims.is_empty(),
		"fixture must have real claims to build an apron against")

	var apron_columns: Dictionary = {}
	for claim: Dictionary in plan.parcel_claims:
		for member: Vector2i in claim.footprint as Array[Vector2i]:
			apron_columns[member] = true
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				apron_columns[member + direction] = true
	var passage_columns: Dictionary = {}
	for cell: Vector3i in plan.passage_cells():
		passage_columns[Vector2i(cell.x, cell.z)] = true

	var offending_column: Vector2i
	var found := false
	for column: Vector2i in plan.massif.columns.keys():
		if apron_columns.has(column) or passage_columns.has(column):
			continue
		offending_column = column
		found = true
		break
	assert_true(found,
		"fixture must contain a column outside every claim's footprint+apron " \
			+ "to doctor an out-of-apron edit onto")

	# Doctored directly on the ledger (bypassing record_edit) so the edit is
	# otherwise fully legal -- at the pre-edit surface (drift 0, well inside
	# the +/-1 budget), not a passage column, not sinking below terrain --
	# isolating the apron rule as the only thing that can reject it.
	plan.column_edits[offending_column] = {
		"floor_band": plan.massif.base_at(offending_column),
		"top_band": plan.massif.top_at(offending_column),
		"phase": &"stamp",
	}
	assert_false(plan.seal(), "an out-of-apron stamp edit must fail seal")
	assert_true(plan.last_rejection.contains("apron"),
		"expected an apron-named rejection, got: %s" % plan.last_rejection)


func test_seal_rejects_pairwise_overlapping_claims() -> void:
	## Finding 4 (final-review fix wave): claims must be pairwise disjoint --
	## a doctored plan with two claims sharing a footprint column must fail
	## seal with a named, disjointness-specific reason.
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var plan := WarrenMazeSitePlanner.plan(12, {}, profile, &"stamp")
	assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
	assert_false(plan.is_sealed())
	assert_gte(plan.parcel_claims.size(), 1,
		"fixture must have at least one real claim to duplicate")

	var duplicate := (plan.parcel_claims[0] as Dictionary).duplicate(true)
	plan.parcel_claims.append(duplicate)
	assert_false(plan.seal(),
		"two claims sharing a footprint column must fail seal")
	assert_true(plan.last_rejection.contains("disjoint"),
		"expected a claims-must-be-disjoint rejection, got: %s" \
			% plan.last_rejection)


func test_claims_respect_the_scale_storey_budget() -> void:
	## Task 1 (2026-08-21): the old massif-ceiling-derived house height let a
	## claim grow as tall as its column's solid extent (up to a 14-band/
	## 7-storey tower); STOREY_BUDGET now caps every claim at 2-3 storeys
	## (compact) worth of bands, floored by MIN_HOUSE_BANDS. Checks both the
	## bound itself and that the bound actually BITES somewhere per seed --
	## comparing the storey-capped top_band against the same column's raw,
	## uncapped solid ceiling (WarrenMazeStampPass._column_ceiling with an
	## empty claimed_intervals, i.e. no stacking cap either) proves the cap is
	## the thing doing the work, not an accident of a shallow massif.
	var budget: Vector2i = WarrenMazeStampPass.STOREY_BUDGET[&"compact"]
	var max_height := budget.y * WarrenBuildingParcel.STOREY_BANDS
	for city_seed: int in [1, 3, 4, 12]:
		var profile := WarrenVillageScaleProfile.for_id(&"compact")
		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
		if plan == null:
			continue
		assert_true(WarrenMazeReservationPass.reserve(plan, profile),
			WarrenMazeReservationPass.last_failure)
		assert_true(WarrenMazeStampPass.stamp(plan, profile),
			WarrenMazeStampPass.last_failure)
		assert_false(plan.parcel_claims.is_empty(),
			"seed %d: fixture must produce real claims, or every assertion " \
				% city_seed + "below passes vacuously")
		var cap_bit := false
		for claim: Dictionary in plan.parcel_claims:
			var height := int(claim.top_band) - int(claim.floor_band)
			assert_lte(height, max_height,
				("seed %d: claim at door_column %s is %d bands tall, past " \
					+ "the compact storey budget's %d-band cap") \
					% [city_seed, str(claim.door_column), height, max_height])
			assert_gte(height, WarrenMazeSourcePlan.MIN_HOUSE_BANDS,
				("seed %d: claim at door_column %s is %d bands tall, below " \
					+ "MIN_HOUSE_BANDS") \
					% [city_seed, str(claim.door_column), height])
			var raw_ceiling := WarrenMazeStampPass._column_ceiling(plan,
				claim.door_column as Vector2i, int(claim.floor_band), {})
			cap_bit = cap_bit or raw_ceiling > int(claim.top_band)
		assert_true(cap_bit,
			("seed %d: at least one claim must be shorter than its raw, " \
				+ "uncapped column ceiling -- otherwise the storey budget " \
				+ "never actually bit") % city_seed)


func test_upper_streets_stack_claims_above_lower_houses() -> void:
	## Task 1: claimed occupancy is now band-interval-based, so a column may
	## carry more than one claim as long as their [floor_band, top_band)
	## ranges stay disjoint -- an upper street's house built above a lower
	## one's roof. Across the same seed x scale corpus as the sibling
	## building-shape test, at least one column somewhere must show this
	## (tiers actually exist), and NO column may ever show two overlapping
	## claims (the core occupancy invariant every placement/extension/merge
	## site is now built on).
	##
	## Refined 2026-08-21 (the tiers unlock, bearing): a column bears at a
	## candidate floor -- exempt from the +/-1 terrain-offender budget -- when
	## it is genuinely unclaimed and SOLID (see
	## WarrenMazeStampPass._column_bears) -- an upper-street house may now
	## bear directly on the mountain rather than needing a lower claim's roof
	## to stack on. `upper_claims` (floor_band >= 4 bands above the column's
	## own massif base -- i.e. addressing a street two-plus storeys up) and a
	## direct anti-floating check (every such claim's own footprint columns
	## must have SOLID mass through their own plinth, via state_at_raw -- the
	## pre-ledger truth, since a bearing column's OWN floor-raising edit makes
	## the ledger-aware state_at report AIR below it by design once the edit
	## exists, which would make a naive post-hoc check misreport every real
	## bearing column as "floating") are measured in the SAME loop as the
	## stacking check above.
	##
	## Plinth refinement (2026-08-21, second pass): _column_bears no longer
	## requires continuity all the way down to the column's own base -- only
	## the PLINTH_BANDS (2) immediately below the floor need to be solid, so
	## a room may sit directly over a covered passage's own roof (a real
	## slab separates them; "lower tunnels beneath are allowed" by design).
	##
	## CONCERN (see task-1-report.md, fix rounds 4-5): the coordinator's
	## brief asked for >= 25% of claims to be upper-street across this
	## corpus, and expected the plinth refinement specifically to raise the
	## ratio "well above" the 12.7% measured with the earlier
	## continuity-to-base rule. Re-measured after implementing plinth
	## bearing exactly as specified: aggregate across seeds 1/3/4/12 is
	## STILL 8/63 = 12.7% -- byte-for-byte the same claims (same door
	## columns, same floors) as before the plinth change, confirmed directly
	## (not just accepted): a 12-seed compact sweep gives 18/162 = 11.1%,
	## consistent with the 4-seed figure, so this isn't a fluke of the pinned
	## seeds. Investigated why: HEADROOM_BANDS (3) + PLINTH_BANDS (2) means a
	## floor needs to clear FIVE bands above any nearby passage's own
	## elevation before its plinth stops overlapping that passage's carved
	## headroom -- verified directly on a real column (seed 1, door-adjacent
	## column (2,0): a passage at y=0 with carved headroom through y=2 means
	## floor=4's plinth [2,4) still overlaps it and correctly fails to bear,
	## while floor=5's plinth [3,5) clears it and correctly bears). Compact
	## massifs simply don't have much vertical relief between a climbing
	## street and the nearest tunnel below it, so most of this scale's
	## high-elevation candidates sit right at the floor=4-5 boundary where
	## plinth and continuity-to-base agree. The mechanism is verified correct
	## (the plinth test itself works exactly as specified); the shortfall is
	## a genuine, measured property of the compact-scale corpus, not a bug in
	## this implementation.
	##
	## RESOLVED (slice 1c task 1, 2026-08-22, rule 4 -- the bridge-capable
	## ledger): the actual blocker was never the plinth math -- it was that
	## record_edit/can_record_edit rejected ANY edit on a passage-hosting
	## column outright, no matter how far above the passage the floor sat, so
	## a candidate whose bearing check already passed (floor well past the
	## 5-band plinth threshold above) still got its offender edit bounced at
	## the ledger, and the whole candidate failed to place. Rule 4 replaces
	## that blanket ban with the same headroom bound record_trim already
	## used (floor_band >= hosted passage y + HEADROOM_BANDS), and
	## _column_bears additionally grants an automatic pass for a floor
	## landing exactly on a tunnel's own trimmed roof slab (headroom +
	## TUNNEL_ROOF_BANDS), where the plinth window would otherwise dip one
	## band into the passage's own carved headroom by design. Re-measured on
	## the same seeds 1/3/4/12 compact aggregate: 24/68 = 35.3%, up from
	## 8/63 = 12.7% -- confirms the blocker really was the ledger gate, not
	## the plinth mechanism. Threshold re-pinned upward to the new measured
	## aggregate minus a guard, per the ruling that a floor may only move up.
	var found_stack := false
	var total_claims := 0
	var upper_claims := 0
	for city_seed: int in [1, 3, 4, 12]:
		var profile := WarrenVillageScaleProfile.for_id(&"compact")
		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
		if plan == null:
			continue
		assert_true(WarrenMazeReservationPass.reserve(plan, profile),
			WarrenMazeReservationPass.last_failure)
		assert_true(WarrenMazeStampPass.stamp(plan, profile),
			WarrenMazeStampPass.last_failure)
		var intervals_by_column: Dictionary = {}
		for claim: Dictionary in plan.parcel_claims:
			var floor_band := int(claim.floor_band)
			var top_band := int(claim.top_band)
			var footprint := claim.footprint as Array[Vector2i]
			total_claims += 1
			var door_column := claim.door_column as Vector2i
			if floor_band - plan.massif.base_at(door_column) >= 4:
				upper_claims += 1
				for column: Vector2i in footprint:
					var column_base := plan.massif.base_at(column)
					# Tunnel-roof exemption (rule 4, slice 1c task 1,
					# 2026-08-22): WarrenMazeStampPass._column_bears also
					# grants an automatic pass when the floor lands EXACTLY
					# on a hosted passage's own future-trimmed roof slab
					# (passage y + HEADROOM_BANDS + TUNNEL_ROOF_BANDS) -- by
					# design, that floor's own plinth window dips one band
					# into the passage's own carved headroom (still AIR, not
					# SOLID), which the naive continuity check below would
					# always (and incorrectly) flag as floating. Skip the
					# continuity assertion for exactly that column/floor
					# combination; every other bearing column still gets the
					# full anti-floating check.
					# Controller ruling (2026-08-22): the real, per-cell headroom
					# (plan.passage_headroom_top), not cell.y + the flat
					# HEADROOM_BANDS constant -- a stair/ramp intermediate cell's
					# own carved slot runs one band taller.
					var headroom_floor := -1
					for cell: Vector3i in plan.passage_cells():
						if cell.x == column.x and cell.z == column.y:
							headroom_floor = maxi(headroom_floor,
								plan.passage_headroom_top(cell))
					if headroom_floor >= 0 and floor_band == headroom_floor \
							+ WarrenMazeStampPass.TUNNEL_ROOF_BANDS:
						continue
					# Plinth check (2026-08-21 refinement), not full
					# continuity to base: WarrenMazeStampPass._column_bears
					# only guarantees the PLINTH_BANDS immediately below the
					# floor are solid -- a lower tunnel beneath is allowed
					# by design -- so that is the invariant this direct
					# anti-floating check actually verifies, against the
					# RAW pre-ledger truth (state_at_raw), not a ledger
					# artifact.
					var plinth_floor := maxi(column_base,
						floor_band - WarrenMazeStampPass.PLINTH_BANDS)
					if plinth_floor >= floor_band:
						continue
					for y in range(plinth_floor, floor_band):
						assert_eq(plan.state_at_raw(
								Vector3i(column.x, y, column.y)),
							WarrenMazeSourcePlan.CellState.SOLID,
							("seed %d: upper-street claim at door %s has " \
								+ "a gap in its plinth at column %s, " \
								+ "band %d -- it would float") \
								% [city_seed, door_column, column, y])
			for column: Vector2i in footprint:
				var existing: Array = intervals_by_column.get(column, [])
				for interval: Vector2i in existing:
					var overlaps := floor_band < interval.y \
						and top_band > interval.x
					assert_false(overlaps,
						("seed %d: two claims on column %s overlap: " \
							+ "[%d,%d) and [%d,%d)") \
							% [city_seed, str(column), interval.x, interval.y,
								floor_band, top_band])
				existing.append(Vector2i(floor_band, top_band))
				intervals_by_column[column] = existing
				found_stack = found_stack or existing.size() > 1
	assert_true(found_stack,
		"at least one column across seeds 1,3,4,12 compact must carry two " \
			+ "disjoint-band claims -- tiers must actually exist")
	var upper_ratio := float(upper_claims) / float(maxi(1, total_claims))
	assert_gte(upper_ratio, 0.30,
		("upper-street claim ratio %.3f (%d/%d) across seeds 1,3,4,12 " \
			+ "compact must clear the measured anti-regression floor -- " \
			+ "re-pinned upward (slice 1c task 1, rule 4): measured 24/68 " \
			+ "= 0.353, see the test's own RESOLVED comment above") \
			% [upper_ratio, upper_claims, total_claims])


func test_skyline_trim_removes_unclaimed_mass_above_roofs() -> void:
	## Task 1's P4.5: mass no claim reaches gets discarded -- to a claimed
	## column's own tallest roof, to an unclaimed column's tallest claimed
	## neighbour ("shoulder"), or to bare terrain when isolated.
	## Fix round 1 (2026-08-21 review): seed 12 added alongside seed 4 -- it
	## is the seed that actually exercises a flush-stacked claim sharing a
	## column with a pre-existing stamp-phase offender edit below it (see
	## WarrenMazeStampPass._refresh_stacked_edit_tops), the exact scenario
	## the reviewer's Important finding was about. The explicit `>=` check
	## below is the general form of the invariant (never below the tallest
	## claim actually built there); the `==` check that follows it is the
	## full skyline-trim promise for a genuinely claimed, non-passage,
	## non-reservation column, which subsumes the `>=` but is kept separate
	## so a regression that only breaks equality (not the inequality) still
	## fails loudly with the right assertion.
	## Refinement (2026-08-21, tunnel roofs): passage-hosting columns are no
	## longer exempt outright -- a covered tunnel used to keep the FULL
	## massif ceiling standing over it (~47% of the network, per the
	## rendered debug view). They now trim to max(any claim's own top on the
	## column, highest passage y + HEADROOM_BANDS + TUNNEL_ROOF_BANDS,
	## shoulder), never below the passage's own required headroom --
	## `trim_outcomes.has("tunnel_roof")` proves the mechanism actually fired
	## rather than every passage column already happening to satisfy the
	## bound.
	for city_seed: int in [4, 12]:
		var profile := WarrenVillageScaleProfile.for_id(&"compact")
		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
		assert_not_null(plan, WarrenMazeCarver.last_failure)
		assert_true(WarrenMazeReservationPass.reserve(plan, profile),
			WarrenMazeReservationPass.last_failure)
		assert_true(WarrenMazeStampPass.stamp(plan, profile),
			WarrenMazeStampPass.last_failure)

		var trim_outcomes := plan.audit.get("trim_outcomes", {}) as Dictionary
		assert_false(trim_outcomes.is_empty(),
			"seed %d compact must actually trim something" % city_seed)
		assert_true(trim_outcomes.has("tunnel_roof"),
			("seed %d compact must actually trim at least one passage-" \
				+ "hosting column's own roof") % city_seed)

		# Controller ruling (2026-08-22): the real, per-cell headroom top
		# (plan.passage_headroom_top), not cell.y + the flat HEADROOM_BANDS
		# constant -- a stair/ramp intermediate cell's own carved slot runs
		# one band taller, and production's own _skyline_trim now measures it
		# the same way.
		var passage_headroom_floor: Dictionary = {}
		for cell: Vector3i in plan.passage_cells():
			var passage_column := Vector2i(cell.x, cell.z)
			var top := plan.passage_headroom_top(cell)
			passage_headroom_floor[passage_column] = maxi(
				int(passage_headroom_floor.get(passage_column, top)), top)
		var reservation_columns: Dictionary = {}
		for reservation: Dictionary in plan.reservations:
			for column: Vector2i in reservation.get("cells", []) as Array:
				reservation_columns[column] = true
		var claim_tops: Dictionary = {}
		for claim: Dictionary in plan.parcel_claims:
			var top := int(claim.top_band)
			for column: Vector2i in claim.footprint as Array[Vector2i]:
				claim_tops[column] = maxi(int(claim_tops.get(column, top)),
					top)

		# General invariant, every claimed column: effective_top can never
		# fall below the tallest claim actually built there -- the exact
		# thing a stale, never-refreshed offender edit under a flush-stacked
		# claim used to violate (seal()'s own general check now mirrors this).
		for column: Vector2i in claim_tops.keys():
			assert_gte(plan.effective_top(column), int(claim_tops[column]),
				("seed %d: claimed column %s effective_top %d must be >= " \
					+ "its tallest claim's own top %d") \
					% [city_seed, column, plan.effective_top(column),
						int(claim_tops[column])])

		for column: Vector2i in plan.massif.columns.keys():
			if reservation_columns.has(column):
				continue
			if passage_headroom_floor.has(column):
				var keep := int(claim_tops.get(column, -2147483648))
				keep = maxi(keep, int(passage_headroom_floor[column]) \
					+ WarrenMazeStampPass.TUNNEL_ROOF_BANDS)
				var shoulder := -2147483648
				for direction: Vector2i in WarrenMazeStampPass.CARDINALS:
					var neighbor := column + direction
					if claim_tops.has(neighbor):
						shoulder = maxi(shoulder, int(claim_tops[neighbor]))
				var bound := maxi(keep, shoulder)
				assert_lte(plan.effective_top(column), bound,
					("seed %d: passage column %s effective_top %d must be " \
						+ "<= max(keep, shoulder) (%d)") \
						% [city_seed, column, plan.effective_top(column),
							bound])
				var headroom_floor := int(passage_headroom_floor[column])
				assert_gte(plan.effective_top(column), headroom_floor,
					("seed %d: passage column %s effective_top %d must " \
						+ "keep >= HEADROOM_BANDS of air above its own " \
						+ "passage cell (needs >= %d)") \
						% [city_seed, column, plan.effective_top(column),
							headroom_floor])
				continue
			if claim_tops.has(column):
				assert_eq(plan.effective_top(column), int(claim_tops[column]),
					("seed %d: claimed column %s must trim exactly to its " \
						+ "tallest claim's own top") % [city_seed, column])
			else:
				var bound := plan.effective_base(column)
				for direction: Vector2i in WarrenMazeStampPass.CARDINALS:
					var neighbor := column + direction
					if claim_tops.has(neighbor):
						bound = maxi(bound, int(claim_tops[neighbor]))
				assert_lte(plan.effective_top(column), bound,
					("seed %d: unclaimed column %s must trim to at most " \
						+ "its tallest claimed neighbour, or its own " \
						+ "terrain if isolated") % [city_seed, column])


func test_seal_rejects_a_trim_that_cuts_into_a_house() -> void:
	## Mirrors test_seal_rejects_a_stamp_edit_outside_every_claims_apron's
	## doctoring style: a trim recorded directly on the ledger (bypassing
	## record_trim) that cuts a real claim's own footprint down to nothing
	## must fail seal, named "trim".
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var plan := WarrenMazeSitePlanner.plan(12, {}, profile, &"stamp")
	assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
	assert_false(plan.is_sealed())
	assert_gte(plan.parcel_claims.size(), 1,
		"fixture must have at least one real claim to doctor a bad trim onto")

	var claim := plan.parcel_claims[0] as Dictionary
	var column: Vector2i = (claim.footprint as Array[Vector2i])[0]
	plan.column_edits[column] = {"floor_band": int(claim.floor_band),
		"top_band": int(claim.floor_band), "phase": &"trim", "trimmed": true}
	assert_false(plan.seal(),
		"a trim that cuts below a claim's own top must fail seal")
	assert_true(plan.last_rejection.contains("trim"),
		"expected a trim-named rejection, got: %s" % plan.last_rejection)


func test_state_at_reads_through_the_edit_ledger() -> void:
	## Follow-up fix (2026-08-21 review): state_at used to test raw
	## massif.base_at/top_at, ignoring the edit ledger entirely -- a trimmed
	## column's discarded mass (and a raised floor's opened-up gap) kept
	## reporting SOLID forever, so every state_at consumer downstream of a
	## sealed plan (the debug view chief among them) kept seeing ghost mass
	## skyline trim had already discarded. state_at now reads
	## effective_base/effective_top; state_at_raw is the escape hatch for the
	## one caller (WarrenMazeStampPass._column_ceiling, mid-stamping, before
	## any trim exists) that genuinely needs the pre-ledger truth.
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var city_seed := 4

	# Pre-trim comparison run, same technique as
	# test_skyline_trim_removes_unclaimed_mass_above_roofs.
	WarrenMazeStampPass.skyline_trim_enabled = false
	var pre_massif := WarrenMassifBuilder.build(city_seed, {}, profile)
	var pre_plan := WarrenMazeCarver.carve(city_seed, pre_massif, profile,
		false)
	assert_not_null(pre_plan, WarrenMazeCarver.last_failure)
	assert_true(WarrenMazeReservationPass.reserve(pre_plan, profile),
		WarrenMazeReservationPass.last_failure)
	assert_true(WarrenMazeStampPass.stamp(pre_plan, profile),
		WarrenMazeStampPass.last_failure)
	WarrenMazeStampPass.skyline_trim_enabled = true

	var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
	var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	assert_true(WarrenMazeReservationPass.reserve(plan, profile),
		WarrenMazeReservationPass.last_failure)
	assert_true(WarrenMazeStampPass.stamp(plan, profile),
		WarrenMazeStampPass.last_failure)

	var trimmed_column: Vector2i
	var trimmed_top := -1
	var found_trim := false
	for column: Vector2i in plan.column_edits.keys():
		var edit := plan.column_edits[column] as Dictionary
		if bool(edit.get("trimmed", false)):
			trimmed_column = column
			trimmed_top = int(edit.get("top_band", 0))
			found_trim = true
			break
	assert_true(found_trim, "seed 4 compact must record at least one trim")

	# A band at/above the trimmed top must now report AIR -- the whole point
	# of this fix (ghost mass a consumer used to still see is genuinely gone).
	var above := Vector3i(trimmed_column.x, trimmed_top, trimmed_column.y)
	assert_eq(plan.state_at(above), WarrenMazeSourcePlan.CellState.AIR,
		"a band at the trimmed column's own top must report AIR post-trim")

	# The SAME cell, pre-trim, must still have reported SOLID -- proving the
	# change is ledger-driven (the trim genuinely happened), not a
	# regression of the untrimmed massif's own solidity.
	assert_lt(trimmed_top, pre_plan.massif.top_at(trimmed_column),
		("fixture must actually carry raw mass above the trimmed top, or " \
			+ "this comparison is vacuous"))
	assert_eq(pre_plan.state_at(above), WarrenMazeSourcePlan.CellState.SOLID,
		"the same cell, pre-trim, must have reported SOLID")

	# A band inside a real claim's own footprint must still report SOLID.
	assert_false(plan.parcel_claims.is_empty(),
		"fixture must have real claims, or the SOLID check below is vacuous")
	var claim := plan.parcel_claims[0] as Dictionary
	var claim_column: Vector2i = (claim.footprint as Array[Vector2i])[0]
	var inside := Vector3i(claim_column.x, int(claim.floor_band),
		claim_column.y)
	assert_eq(plan.state_at(inside), WarrenMazeSourcePlan.CellState.SOLID,
		"a band inside a claim's own footprint/floor must still report SOLID")


func test_seal_rejects_a_trim_that_cuts_into_headroom() -> void:
	## Refinement (2026-08-21, tunnel roofs): passage-hosting columns are no
	## longer exempt from trim outright, so a trim recorded directly on the
	## ledger (bypassing record_trim) that cuts below a passage cell's own
	## required HEADROOM_BANDS of air must fail seal, named "headroom" --
	## mirrors test_seal_rejects_a_trim_that_cuts_into_a_house's doctoring
	## style for the claim case.
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var plan := WarrenMazeSitePlanner.plan(12, {}, profile, &"stamp")
	assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
	assert_false(plan.is_sealed())
	assert_false(plan.passage_cells().is_empty(),
		"fixture must have real passage cells to doctor a bad trim onto")

	var passage_cell := plan.passage_cells()[0]
	var column := Vector2i(passage_cell.x, passage_cell.z)
	plan.column_edits[column] = {"floor_band": plan.massif.base_at(column),
		"top_band": passage_cell.y, "phase": &"trim", "trimmed": true}
	assert_false(plan.seal(),
		"a trim that cuts into a passage's own headroom must fail seal")
	assert_true(plan.last_rejection.contains("headroom"),
		"expected a headroom-named rejection, got: %s" % plan.last_rejection)


func test_reservation_plots_carry_ledger_heights() -> void:
	## Refinement (2026-08-21, reservation plot heights): every non-skywalk
	## reservation kind now gets a real ledger top -- open flat plots for
	## the 0-storey kinds (courtyard, garden_terrace), a real building
	## envelope for large_house/landmark_plot -- via
	## WarrenMazeReservationPass.PLOT_STOREYS, instead of the old
	## maxi(effective_top, datum) which just preserved whatever the raw
	## massif ceiling already was (the same massif-ceiling-derived-height
	## bug Task 1 fixed for houses). skywalk_span is deliberately excluded
	## (claim_overhead never touches a floor at all -- its flanks stand on
	## grounded natural rock, untouched by this dictionary or by this test).
	var found_non_skywalk := false
	for city_seed: int in [4, 12]:
		var profile := WarrenVillageScaleProfile.for_id(&"compact")
		var plan := WarrenMazeSitePlanner.plan(city_seed, {}, profile)
		assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
		if plan == null:
			continue
		for reservation: Dictionary in plan.reservations:
			var kind := StringName(reservation.get("kind", &""))
			if kind == &"skywalk_span":
				continue
			found_non_skywalk = true
			var datum := int(reservation.get("datum_band", 0))
			var storeys := int(
				WarrenMazeReservationPass.PLOT_STOREYS.get(kind, 0))
			var expected_top := datum \
				+ storeys * WarrenBuildingParcel.STOREY_BANDS
			assert_eq(int(reservation.get("plot_top", -1)), expected_top,
				("seed %d: reservation kind %s plot_top must equal datum " \
					+ "(%d) + PLOT_STOREYS*STOREY_BANDS (%d)") \
					% [city_seed, kind, datum, expected_top])
			for column: Vector2i in reservation.get("cells", []) as Array:
				assert_eq(plan.effective_top(column), expected_top,
					("seed %d: reservation kind %s column %s " \
						+ "effective_top must equal datum + " \
						+ "PLOT_STOREYS*STOREY_BANDS (%d)") \
						% [city_seed, kind, column, expected_top])
	assert_true(found_non_skywalk,
		"seeds 4/12 compact must place at least one non-skywalk " \
			+ "reservation, or this test passes vacuously")


func test_houses_under_upper_streets_rise_to_meet_them() -> void:
	## Rule 1 (tier-driven height, slice 1c task 1, 2026-08-22): a house
	## beneath an upper street should rise to MEET it --
	## WarrenMazeStampPass._find_tier_top caps a claim's roof at the lowest
	## qualifying passage y in its own footprint or 1-column apron, instead
	## of a seeded roll that has no idea a street runs overhead. Measures,
	## across the pinned compact corpus: for every passage cell at least 4
	## bands above the portal (a genuinely "upper" street, not the ground
	## floor), what share of its flank columns' solid mass at
	## [p.y - 2, p.y) -- the two bands directly under the street -- belongs
	## to a CLAIM versus unclaimed rock. "Flank column" here is any
	## non-passage cardinal neighbour of the passage cell: a true
	## travel-direction-perpendicular flank needs a walk reconstruction this
	## measurement does not need for its own purpose (proving houses
	## actually rise to meet the street above them, not just leave rock
	## standing there).
	var claim_mass := 0
	var rock_mass := 0
	var total_tiered := 0
	for city_seed: int in [1, 3, 4, 12]:
		var profile := WarrenVillageScaleProfile.for_id(&"compact")
		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
		if plan == null:
			continue
		assert_true(WarrenMazeReservationPass.reserve(plan, profile),
			WarrenMazeReservationPass.last_failure)
		assert_true(WarrenMazeStampPass.stamp(plan, profile),
			WarrenMazeStampPass.last_failure)
		var portal_y := plan.excavation.route[0].y
		var passage_columns: Dictionary = {}
		for cell: Vector3i in plan.passage_cells():
			passage_columns[Vector2i(cell.x, cell.z)] = true
		var claim_intervals: Dictionary = {}
		for claim: Dictionary in plan.parcel_claims:
			var floor_band := int(claim.floor_band)
			var top_band := int(claim.top_band)
			for column: Vector2i in claim.footprint as Array[Vector2i]:
				var existing: Array = claim_intervals.get(column, [])
				existing.append(Vector2i(floor_band, top_band))
				claim_intervals[column] = existing

		# Tiered-claim exactness: every claim's top equals a real passage y
		# adjacent to its own footprint or 1-column apron -- re-derives the
		# same search space _find_tier_top uses, independently, rather than
		# trusting the `tiered` flag alone.
		for claim: Dictionary in plan.parcel_claims:
			if not bool(claim.get("tiered", false)):
				continue
			total_tiered += 1
			var apron: Dictionary = {}
			for column: Vector2i in claim.footprint as Array[Vector2i]:
				apron[column] = true
				for direction: Vector2i in WarrenMazeStampPass.CARDINALS:
					apron[column + direction] = true
			var matched := false
			for cell: Vector3i in plan.passage_cells():
				if cell.y == int(claim.top_band) \
						and apron.has(Vector2i(cell.x, cell.z)):
					matched = true
					break
			assert_true(matched,
				("seed %d: tiered claim at door %s has top %d that " \
					+ "matches no passage cell adjacent to its own " \
					+ "footprint/apron") \
					% [city_seed, str(claim.door_column), int(claim.top_band)])

		for cell: Vector3i in plan.passage_cells():
			if cell.y < portal_y + 4:
				continue
			var column := Vector2i(cell.x, cell.z)
			for direction: Vector2i in WarrenMazeStampPass.CARDINALS:
				var flank := column + direction
				if passage_columns.has(flank) \
						or not plan.massif.has_column(flank):
					continue
				for band in range(cell.y - 2, cell.y):
					if plan.state_at_raw(Vector3i(flank.x, band, flank.y)) \
							!= WarrenMazeSourcePlan.CellState.SOLID:
						continue
					var owned := false
					for interval: Vector2i in claim_intervals.get(flank, []) \
							as Array:
						if band >= interval.x and band < interval.y:
							owned = true
							break
					if owned:
						claim_mass += 1
					else:
						rock_mass += 1

	var total_mass := claim_mass + rock_mass
	assert_gt(total_mass, 0,
		"the pinned corpus must produce at least one upper-street flank " \
			+ "band to measure, or this test passes vacuously")
	var claim_share := float(claim_mass) / float(maxi(1, total_mass))
	print(("houses_under_upper_streets_rise_to_meet_them: claim=%d rock=%d " \
		+ "share=%.4f tiered_claims=%d") \
		% [claim_mass, rock_mass, claim_share, total_tiered])
	# Measured 2026-08-22 on seeds 1/3/4/12 compact: claim_share == 0.5116
	# (44/86 flank bands). Pinned at measured minus a guard -- an
	# anti-regression floor, not a quality target; see this test's own
	# header for the methodology.
	assert_gte(claim_share, 0.45,
		("upper-flank claim share %.4f (%d/%d) fell below the measured " \
			+ "anti-regression floor") % [claim_share, claim_mass, total_mass])


func test_courtyards_are_flat_plots_at_street_level() -> void:
	## Rule 2 (street-level courtyards/gardens, slice 1c task 1, 2026-08-22):
	## courtyard and garden_terrace now use WarrenMazeReservationPass.
	## _apply_level_to_walk instead of a terrain-majority datum -- every
	## landed reservation is a perfectly flat open plot at the elevation of
	## the passage cell it opens off, not a dip or a mound.
	var found_any := false
	for city_seed: int in [3, 9]:
		var profile := WarrenVillageScaleProfile.for_id(&"standard")
		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
		assert_not_null(plan, WarrenMazeCarver.last_failure)
		assert_true(WarrenMazeReservationPass.reserve(plan, profile),
			WarrenMazeReservationPass.last_failure)
		var passage_by_column: Dictionary = {}
		for cell: Vector3i in plan.passage_cells():
			var column := Vector2i(cell.x, cell.z)
			var ys: Array = passage_by_column.get(column, [])
			ys.append(cell.y)
			passage_by_column[column] = ys
		for reservation: Dictionary in plan.reservations:
			var kind := StringName(reservation.get("kind", &""))
			if kind != &"courtyard" and kind != &"garden_terrace":
				continue
			found_any = true
			assert_eq(StringName(reservation.get("plot_kind", &"")), &"flat",
				("seed %d: %s reservation must carry plot_kind == &\"flat\"") \
					% [city_seed, kind])
			var datum := int(reservation.get("datum_band", -1))
			var cells := reservation.get("cells", []) as Array[Vector2i]
			assert_false(cells.is_empty(),
				"seed %d: %s reservation has no cells" % [city_seed, kind])
			for column: Vector2i in cells:
				assert_eq(plan.effective_base(column), datum,
					("seed %d: %s reservation column %s effective_base " \
						+ "must equal datum_band %d") \
						% [city_seed, kind, column, datum])
				assert_eq(plan.effective_top(column), datum,
					("seed %d: %s reservation column %s effective_top " \
						+ "must equal datum_band %d") \
						% [city_seed, kind, column, datum])
			# datum_band must equal the y of some real passage cell adjacent
			# to the patch (cardinally, to any of its own columns).
			var matched := false
			for column: Vector2i in cells:
				for direction: Vector2i in WarrenMazeStampPass.CARDINALS:
					var neighbor := column + direction
					if not passage_by_column.has(neighbor):
						continue
					if datum in (passage_by_column[neighbor] as Array):
						matched = true
						break
				if matched:
					break
			assert_true(matched,
				("seed %d: %s reservation datum_band %d matches no " \
					+ "passage cell adjacent to the patch") \
					% [city_seed, kind, datum])
	assert_true(found_any,
		"seeds 3/9 standard must place at least one courtyard/garden_terrace " \
			+ "reservation, or this test passes vacuously")


func test_bridge_claims_clear_street_headroom() -> void:
	## Rule 4 (bridge-capable ledger, slice 1c task 1, 2026-08-22): a claim
	## whose footprint includes a column that also hosts a passage cell (a
	## bearing claim standing on a lower tunnel's own trimmed roof, or any
	## other legally bridge-edited column) is only ever legal when its own
	## floor clears every hosted passage's own required headroom --
	## record_edit/can_record_edit's shared _passage_headroom_floor gate,
	## which seal() also re-validates. Checks the real corpus, then proves
	## seal() actually re-derives the rule rather than trusting it was
	## upheld at stamp time, by doctoring a violation directly onto the
	## ledger.
	var checked_columns := 0
	for city_seed: int in [1, 3, 4, 12]:
		var profile := WarrenVillageScaleProfile.for_id(&"compact")
		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
		if plan == null:
			continue
		assert_true(WarrenMazeReservationPass.reserve(plan, profile),
			WarrenMazeReservationPass.last_failure)
		assert_true(WarrenMazeStampPass.stamp(plan, profile),
			WarrenMazeStampPass.last_failure)
		# Controller ruling (2026-08-22): the real, per-cell headroom top
		# (plan.passage_headroom_top), not cell.y + the flat HEADROOM_BANDS
		# constant -- a stair/ramp intermediate cell's own carved slot runs
		# one band taller.
		var passage_headroom_floor: Dictionary = {}
		for cell: Vector3i in plan.passage_cells():
			var column := Vector2i(cell.x, cell.z)
			var top := plan.passage_headroom_top(cell)
			passage_headroom_floor[column] = maxi(
				int(passage_headroom_floor.get(column, top)), top)
		for claim: Dictionary in plan.parcel_claims:
			var floor_band := int(claim.floor_band)
			for column: Vector2i in claim.footprint as Array[Vector2i]:
				if not passage_headroom_floor.has(column):
					continue
				# Only a column whose floor the ledger actually RAISED above
				# its own natural terrain is bound by the headroom rule at
				# all -- a footprint column that merely happens to share
				# (x, z) with an unrelated passage many bands above its own
				# UNEDITED roof (the ordinary case: most claims stop their
				# ceiling walk well below any such passage, via
				# _column_ceiling's own state_at_raw walk, with no ledger
				# edit involved at all) never touched that passage's
				# headroom in the first place, so the rule does not apply to
				# it. record_edit/can_record_edit's own gate is what
				# actually guarantees this invariant at the moment such a
				# column IS raised; this re-derives it as a regression check
				# rather than trusting it silently held.
				if plan.effective_base(column) <= plan.massif.base_at(column):
					continue
				checked_columns += 1
				var required := int(passage_headroom_floor[column])
				assert_gte(floor_band, required,
					("seed %d: claim at door %s has footprint column %s " \
						+ "hosting a passage with real headroom top %d, but its " \
						+ "own floor %d does not clear it") \
						% [city_seed, str(claim.door_column), column,
							required, floor_band])
	assert_gt(checked_columns, 0,
		"the pinned corpus must produce at least one claim whose footprint " \
			+ "column was actually raised above terrain on a passage-" \
			+ "hosting column, or the corpus check above passes vacuously")

	# seal() rejects a doctored claim whose footprint column hosts a passage
	# but whose floor does not clear its headroom -- mirrors this suite's
	# other doctored-rejection tests (e.g.
	# test_seal_rejects_a_trim_that_cuts_into_headroom).
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var plan := WarrenMazeSitePlanner.plan(12, {}, profile, &"stamp")
	assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
	assert_false(plan.is_sealed())
	assert_false(plan.parcel_claims.is_empty(),
		"fixture must have real claims to doctor a bad headroom edit onto")
	assert_false(plan.passage_cells().is_empty(),
		"fixture must have real passage cells to doctor a bad headroom edit onto")

	var passage_cell := plan.passage_cells()[0]
	var offending_column := Vector2i(passage_cell.x, passage_cell.z)
	# Doctored directly on the ledger (bypassing record_edit, which would
	# correctly refuse this) as a STAMP-phase edit whose floor sits AT the
	# passage's own band -- inside its required headroom, not clearing it --
	# isolating the headroom rule as the only thing that can reject it. The
	# headroom check runs before the apron/disjointness checks in seal()'s
	# own per-edit loop, so this column need not belong to any real claim's
	# footprint or apron for the rejection to be headroom-named.
	plan.column_edits[offending_column] = {
		"floor_band": passage_cell.y, "top_band": passage_cell.y + 4,
		"phase": &"stamp"}
	assert_false(plan.seal(),
		"a stamp edit that touches a passage column without clearing its " \
			+ "own headroom must fail seal")
	assert_true(plan.last_rejection.contains("headroom"),
		"expected a headroom-named rejection, got: %s" % plan.last_rejection)


func test_passage_headroom_is_a_per_cell_fact_not_a_constant() -> void:
	## Controller ruling (2026-08-22): WarrenMazeSourcePlan.passage_headroom_top
	## (cell.y + excavation.slot_bands(cell)) replaces cell.y +
	## WarrenExcavation.HEADROOM_BANDS everywhere a passage's own required
	## clearance is measured -- a stair/ramp intermediate stride cell's own
	## carved slot runs one band taller than a plain LEVEL cell's, and the
	## flat constant silently undercounted it (see task-1-report.md's third
	## addendum: this is exactly what let a claim seal as "bearing" on what
	## the real volume still shows as open carved air).
	var checked := 0
	var found_taller_slot := false
	for city_seed in range(1, 13):
		var profile := WarrenVillageScaleProfile.for_id(&"compact")
		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
		if plan == null:
			continue
		assert_true(WarrenMazeReservationPass.reserve(plan, profile),
			WarrenMazeReservationPass.last_failure)
		assert_true(WarrenMazeStampPass.stamp(plan, profile),
			WarrenMazeStampPass.last_failure)
		for claim: Dictionary in plan.parcel_claims:
			var floor_band := int(claim.floor_band)
			for column: Vector2i in claim.footprint as Array[Vector2i]:
				# Only a column whose floor the ledger actually RAISED above its
				# own natural terrain is bound by the headroom rule at all -- a
				# footprint column that merely happens to share (x, z) with an
				# unrelated passage many bands above its own UNEDITED roof never
				# touched that passage's headroom in the first place (see
				# test_bridge_claims_clear_street_headroom's own comment for the
				# identical reasoning).
				if plan.effective_base(column) <= plan.massif.base_at(column):
					continue
				for cell: Vector3i in plan.passage_cells():
					if cell.x != column.x or cell.z != column.y:
						continue
					checked += 1
					var real_top := plan.passage_headroom_top(cell)
					if plan.excavation.slot_bands(cell) \
							> WarrenExcavation.HEADROOM_BANDS:
						found_taller_slot = true
					assert_gte(floor_band, real_top,
						("seed %d: claim at door %s has footprint column " \
							+ "%s hosting passage cell %s (real headroom " \
							+ "top %d, slot_bands %d) but its own floor %d " \
							+ "does not clear it") \
							% [city_seed, str(claim.door_column), column,
								cell, real_top,
								plan.excavation.slot_bands(cell), floor_band])
	assert_gt(checked, 0,
		"the pinned corpus must produce at least one claim whose " \
			+ "footprint touches a passage-hosting column, or this check " \
			+ "is vacuous")
	assert_true(found_taller_slot,
		"the pinned corpus must include at least one passage cell whose " \
			+ "real carved slot exceeds HEADROOM_BANDS (a stair/ramp " \
			+ "intermediate cell), or this test never exercises the " \
			+ "actual fix")

	# seal() rejects a doctored claim one band below a stair cell's REAL
	# headroom -- the exact gap the old, constant-based rule used to miss:
	# floor = real_headroom_top - 1 was illegal all along (still inside the
	# cell's own carved slot) but the flat HEADROOM_BANDS constant would
	# have called it legal.
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var plan := WarrenMazeSitePlanner.plan(12, {}, profile, &"stamp")
	assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
	assert_false(plan.is_sealed())
	var stair_cell := Vector3i(0, 0, -4)
	assert_true(plan.passage_kinds.has(stair_cell),
		("fixture must still carry the known stair-adjacent passage cell " \
			+ "at %s -- reproduction may need re-pinning if the carve " \
			+ "corpus changed") % stair_cell)
	var real_slot := plan.excavation.slot_bands(stair_cell)
	assert_gt(real_slot, WarrenExcavation.HEADROOM_BANDS,
		("fixture cell %s must have a real carved slot taller than " \
			+ "HEADROOM_BANDS, or this doctoring proves nothing") % stair_cell)
	var real_top := plan.passage_headroom_top(stair_cell)
	var offending_column := Vector2i(stair_cell.x, stair_cell.z)
	plan.column_edits[offending_column] = {
		"floor_band": real_top - 1,
		"top_band": real_top - 1 + WarrenMazeSourcePlan.MIN_HOUSE_BANDS,
		"phase": &"stamp"}
	assert_false(plan.seal(),
		"a stamp edit one band below a stair cell's REAL headroom must " \
			+ "fail seal")
	assert_true(plan.last_rejection.contains("headroom"),
		"expected a headroom-named rejection, got: %s" % plan.last_rejection)

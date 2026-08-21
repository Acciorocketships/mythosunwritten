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
	var profile := WarrenVillageScaleProfile.for_id(&"standard")
	var massif := WarrenMassifBuilder.build(1, {}, profile)
	var plan := WarrenMazeCarver.carve(1, massif, profile, false)
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	assert_true(WarrenMazeReservationPass.reserve(plan, profile),
		WarrenMazeReservationPass.last_failure)
	assert_false(plan.column_edits.is_empty(),
		"the reservation pass should have recorded at least one edit")
	var passage_columns: Dictionary = {}
	for cell: Vector3i in plan.passage_cells():
		passage_columns[Vector2i(cell.x, cell.z)] = true
	for column: Vector2i in plan.column_edits.keys():
		var edit := plan.column_edits[column] as Dictionary
		assert_eq(StringName(edit.get("phase", &"")), &"reserve",
			"every edit the reservation pass records is phase reserve")
		assert_false(passage_columns.has(column),
			"an edit must never touch a passage column")


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
	## each other.
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

	var stamp_edit_columns: Array[Vector2i] = []
	for column_value: Variant in plan.column_edits.keys():
		var column := column_value as Vector2i
		var edit := plan.column_edits[column] as Dictionary
		if StringName(edit.phase) != &"stamp":
			continue
		stamp_edit_columns.append(column)
		assert_lte(absi(int(edit.floor_band) - plan.massif.base_at(column)), 1,
			"stamp edits move at most one band")
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

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
	for city_seed: int in [1, 3, 4, 12]:
		var profile := WarrenVillageScaleProfile.for_id(&"compact")
		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
		if plan == null:
			continue
		assert_true(WarrenMazeReservationPass.reserve(plan, profile))
		assert_true(WarrenMazeStampPass.stamp(plan, profile),
			WarrenMazeStampPass.last_failure)
		var sizes: Array[int] = []
		for claim: Dictionary in plan.parcel_claims:
			var footprint := claim.footprint as Array[Vector2i]
			sizes.append(footprint.size())
			if footprint.size() == 1:
				assert_lte(int(claim.top_band) - int(claim.floor_band),
					2 * WarrenBuildingParcel.STOREY_BANDS,
					"a 1x1 claim may not become a pencil tower")
		sizes.sort()
		assert_gte(sizes[sizes.size() / 2], 4,
			"seed %d: median footprint must be building-shaped" % city_seed)


func test_stamp_edits_stay_within_one_band_and_own_apron() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(12, {}, profile)
	var plan := WarrenMazeCarver.carve(12, massif, profile, false)
	WarrenMazeReservationPass.reserve(plan, profile)
	WarrenMazeStampPass.stamp(plan, profile)
	for column_value: Variant in plan.column_edits.keys():
		var column := column_value as Vector2i
		var edit := plan.column_edits[column] as Dictionary
		if StringName(edit.phase) != &"stamp":
			continue
		assert_lte(absi(int(edit.floor_band) - plan.massif.base_at(column)), 1,
			"stamp edits move at most one band")

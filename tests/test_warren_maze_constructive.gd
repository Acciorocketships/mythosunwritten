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

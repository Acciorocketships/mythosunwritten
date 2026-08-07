extends GutTest

## The adapter is the seam between the new mass-first stages and the whole
## existing parcel/fabric machine: its output must satisfy the same sealed
## WarrenVolumePlan contract the route-first carver produces.


func test_adapter_produces_sealed_volume_plan() -> void:
	var massif := WarrenMassifBuilder.build(1)
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	var excavation := WarrenExcavationCarver.carve(1, massif)
	assert_not_null(excavation, WarrenExcavationCarver.last_failure)
	var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
		excavation)
	assert_not_null(plan,
		"adapter failed: %s" % WarrenExcavationVolumeAdapter.last_failure)
	if plan == null:
		return
	assert_true(plan.is_sealed(), plan.last_rejection)
	assert_eq(plan.primary_itinerary.size(), excavation.route.size())
	assert_gt(plan.transitions.size(), 0)
	var envelope := plan.envelope
	for cell: Vector3i in excavation.route:
		assert_true(envelope.contains_column(Vector2i(cell.x, cell.z)),
			"every route column exists in the synthesised envelope")


func test_adapter_preserves_exact_walk_and_entry_geometry() -> void:
	## A plan that seals while quietly describing different geometry than the
	## excavated void would be the worst possible outcome for Tasks 4-6: every
	## later stage would build against a fiction. Size equality alone (the
	## test above) cannot catch a reordering or a substitution, so this checks
	## the actual cell sequence and entry point are identical, not just
	## equally sized.
	var massif := WarrenMassifBuilder.build(1)
	var excavation := WarrenExcavationCarver.carve(1, massif)
	var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
		excavation)
	assert_not_null(plan, WarrenExcavationVolumeAdapter.last_failure)
	if plan == null:
		return
	assert_eq(plan.primary_itinerary, excavation.route,
		"the plan's itinerary must be the excavated walk, cell for cell, " \
		+ "in order -- not merely the same size")
	assert_eq(plan.entry_cell, excavation.portals[0],
		"the plan must enter where the excavation actually opens to daylight")
	for cell: Vector3i in excavation.route:
		assert_true(plan.has_walk(cell))


func test_adapter_envelope_matches_massif_column_heights_exactly() -> void:
	## The brief's own contract test only proves the synthesised envelope
	## KNOWS about every route column. It says nothing about whether the
	## envelope's ground/height at those columns -- and every other massif
	## column frontage/addressing logic will read -- actually match the
	## terraced mass Task 1 built, rather than some other plausible-looking
	## Gaussian shape.
	var massif := WarrenMassifBuilder.build(1)
	var excavation := WarrenExcavationCarver.carve(1, massif)
	var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
		excavation)
	assert_not_null(plan, WarrenExcavationVolumeAdapter.last_failure)
	if plan == null:
		return
	var envelope := plan.envelope
	var checked := 0
	for column_value: Variant in massif.columns.keys():
		var column := column_value as Vector2i
		checked += 1
		assert_eq(envelope.ground_at(column), massif.base_at(column),
			"column %s ground band must match the massif" % column)
		assert_eq(envelope.height_at(column),
			massif.top_at(column) - massif.base_at(column),
			"column %s height must match the massif's terrace" % column)
		assert_eq(envelope.top_at(column), massif.top_at(column),
			"column %s top must match the massif exactly" % column)
	assert_eq(checked, massif.columns.size())


func test_adapter_transitions_preserve_excavation_spine_edges() -> void:
	## Confirms the adapter builds transitions FROM what the excavation
	## already decided rather than re-deriving new endpoints: every macro
	## move the carver recorded must survive into the sealed plan unaltered
	## (same from, to, and kind), regardless of whatever connective spurs the
	## adapter also had to add for STAIR/RAMP intermediate cells.
	var massif := WarrenMassifBuilder.build(1)
	var excavation := WarrenExcavationCarver.carve(1, massif)
	var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
		excavation)
	assert_not_null(plan, WarrenExcavationVolumeAdapter.last_failure)
	if plan == null:
		return
	var plan_edges: Dictionary = {}
	for transition: WarrenVolumeTransition in plan.transitions:
		var key := "%s>%s:%d" % [transition.from_cell, transition.to_cell,
			transition.kind]
		plan_edges[key] = true
	assert_gt(excavation.transitions.size(), 0)
	for spec: Dictionary in excavation.transitions:
		var key := "%s>%s:%d" % [spec["from"], spec["to"], int(spec["kind"])]
		assert_true(plan_edges.has(key),
			"excavation spine edge %s is missing from the sealed plan" % key)


func test_adapter_mass_cells_equal_massif_minus_excavated_void() -> void:
	## The load-bearing fidelity claim: the plan's buildable solid is exactly
	## the massif with the excavation's void subtracted, checked exhaustively
	## over every cell of the massif rather than sampled. A plan that swept
	## too little air would leave phantom solid mass inside the street it
	## just carved; one that swept too much would erase real building volume
	## the excavation never touched.
	var massif := WarrenMassifBuilder.build(1)
	var excavation := WarrenExcavationCarver.carve(1, massif)
	var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
		excavation)
	assert_not_null(plan, WarrenExcavationVolumeAdapter.last_failure)
	if plan == null:
		return
	var checked := 0
	var excavated_checked := 0
	for column_value: Variant in massif.columns.keys():
		var column := column_value as Vector2i
		for y in range(massif.base_at(column), massif.top_at(column)):
			var cell := Vector3i(column.x, y, column.y)
			checked += 1
			if excavation.carved.has(cell):
				excavated_checked += 1
				assert_false(plan.has_mass(cell),
					"excavated cell %s must not remain solid in the plan" % cell)
			else:
				assert_true(plan.has_mass(cell),
					("un-excavated massif cell %s must remain solid in the " \
					+ "plan") % cell)
	assert_gt(checked, 0)
	assert_eq(excavated_checked, excavation.carved.size(),
		"every carved cell must lie inside the massif solid that was checked")


func test_adapter_corpus_preserves_geometry_across_seeds() -> void:
	## The four tests above could all be an accident of seed 1. Re-checks the
	## cheap subset of those fidelity claims (walk identity, entry, envelope
	## heights) across a small seed corpus so passing is a property of the
	## adapter, not a property of one hand-picked massif.
	var accepted := 0
	for world_seed in range(6):
		var massif := WarrenMassifBuilder.build(world_seed)
		if massif == null:
			continue
		var excavation := WarrenExcavationCarver.carve(world_seed, massif)
		if excavation == null:
			continue
		var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		assert_not_null(plan, "seed %d: adapter failed: %s" \
			% [world_seed, WarrenExcavationVolumeAdapter.last_failure])
		if plan == null:
			continue
		accepted += 1
		assert_true(plan.is_sealed(), "seed %d: %s" \
			% [world_seed, plan.last_rejection])
		assert_eq(plan.primary_itinerary, excavation.route,
			"seed %d: walk must match the excavated route exactly" % world_seed)
		assert_eq(plan.entry_cell, excavation.portals[0],
			"seed %d: entry must match the excavation's chosen portal" \
			% world_seed)
		for column_value: Variant in massif.columns.keys():
			var column := column_value as Vector2i
			assert_eq(plan.envelope.top_at(column), massif.top_at(column),
				"seed %d column %s height must match the massif" \
				% [world_seed, column])
	assert_gt(accepted, 0,
		"no seed in the corpus produced a sealed plan")


func test_adapter_is_deterministic() -> void:
	## No randf/Time/engine RNG anywhere in the adapter: rebuilding from the
	## same massif and excavation objects (themselves already proven
	## deterministic by their own suites) must yield a bit-identical plan.
	var massif := WarrenMassifBuilder.build(1)
	var excavation := WarrenExcavationCarver.carve(1, massif)
	var first := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
		excavation)
	var second := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
		excavation)
	assert_not_null(first, WarrenExcavationVolumeAdapter.last_failure)
	assert_not_null(second, WarrenExcavationVolumeAdapter.last_failure)
	if first == null or second == null:
		return
	assert_eq(first.deterministic_signature(),
		second.deterministic_signature())
	assert_eq(first.envelope.deterministic_signature(),
		second.envelope.deterministic_signature())

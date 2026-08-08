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
	# Corrected from the brief's literal `== excavation.route.size()`: walk
	# cells are transition endpoints only (one per bored move), matching
	# WarrenPublicRealmCarver's own route-first convention. Making every
	# carved cell -- including a STAIR/RAMP's intermediate stride cell -- a
	# walk cell was the root cause of a real integration defect: that
	# intermediate's ground is already claimed whole by
	# WarrenVolumeTransition.surface_cells(), and WarrenVolumePublicRealmAdapter
	# gives every walk cell an unconditional surface square of its own, so the
	# two claims collided on every candidate's first climbing move (see
	# test_adapter_plan_survives_the_public_realm_adapter below). See the
	# task-3-report.md amendment for the full history.
	assert_eq(plan.primary_itinerary.size(), excavation.transitions.size() + 1,
		"walk cells are one per move endpoint (plus the portal), not one " \
		+ "per carved cell")
	assert_gt(plan.transitions.size(), 0)
	var envelope := plan.envelope
	for cell: Vector3i in excavation.route:
		assert_true(envelope.contains_column(Vector2i(cell.x, cell.z)),
			"every route column exists in the synthesised envelope")


func _endpoint_walk_cells(excavation: WarrenExcavation) -> Array[Vector3i]:
	## The walk-cell sequence the adapter is now contracted to produce: the
	## portal, then every transition's `to_cell`, in order -- the excavation's
	## own move endpoints, never an intermediate stride cell.
	var out: Array[Vector3i] = [excavation.route[0]]
	for spec: Dictionary in excavation.transitions:
		out.append(spec["to"] as Vector3i)
	return out


func test_adapter_preserves_exact_walk_and_entry_geometry() -> void:
	## A plan that seals while quietly describing different geometry than the
	## excavated void would be the worst possible outcome for Tasks 4-6: every
	## later stage would build against a fiction. Size equality alone (the
	## test above) cannot catch a reordering or a substitution, so this checks
	## the actual cell sequence and entry point are identical, not just
	## equally sized -- against the move-endpoint sequence, not the raw
	## cell-by-cell walk (see the correction above).
	var massif := WarrenMassifBuilder.build(1)
	var excavation := WarrenExcavationCarver.carve(1, massif)
	var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
		excavation)
	assert_not_null(plan, WarrenExcavationVolumeAdapter.last_failure)
	if plan == null:
		return
	assert_eq(plan.primary_itinerary, _endpoint_walk_cells(excavation),
		"the plan's itinerary must be the excavated move endpoints, cell " \
		+ "for cell, in order -- not merely the same size")
	assert_eq(plan.entry_cell, excavation.portals[0],
		"the plan must enter where the excavation actually opens to daylight")
	var endpoints: Dictionary = {}
	for cell: Vector3i in _endpoint_walk_cells(excavation):
		endpoints[cell] = true
	for cell: Vector3i in excavation.route:
		assert_eq(plan.has_walk(cell), endpoints.has(cell),
			("walk-cell membership at %s must match move-endpoint status " \
			+ "exactly -- an intermediate stride cell must NOT be a walk " \
			+ "cell, since its ground already belongs to the transition") \
			% cell)


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
		# The SECOND datum. Ground stays natural ground so the frontage,
		# arcade and cover rules keep reading the whole solid; the terrace
		# only bounds how far a house descends.
		assert_eq(envelope.bearing_at(column), massif.bearing_at(column),
			"column %s terrace must match the massif" % column)
	assert_eq(checked, massif.columns.size())
	var raised := 0
	for column_value: Variant in massif.columns.keys():
		var column := column_value as Vector2i
		raised += int(envelope.bearing_at(column) > envelope.ground_at(column))
	assert_gt(raised, 0,
		"a synthesised envelope whose terrace never rises above ground has "
		+ "not carried the massif's second datum at all")


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
		assert_eq(plan.primary_itinerary, _endpoint_walk_cells(excavation),
			"seed %d: walk must match the excavated move endpoints exactly" \
			% world_seed)
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


func test_adapter_plan_survives_the_public_realm_adapter() -> void:
	## Pins the regression this amendment exists to fix. Before it,
	## WarrenExcavationVolumeAdapter made every carved cell a walk cell
	## (including a STAIR/RAMP's intermediate stride cell) and wired the
	## orphan in with a connective LEVEL spur. WarrenVolumePublicRealmAdapter
	## independently gives every walk cell its own 2x2 surface square AND
	## gives every vertical transition the macro column(s) strictly between
	## its endpoints via WarrenVolumeTransition.surface_cells() -- which for a
	## STAIR/RAMP is exactly that same intermediate column. The two claims
	## collided at the first climbing move of every route, deterministically,
	## on every one of Task 6's 31 measured candidates ("surface cell ... is
	## shared by volume.walk.NN and volume.transition.NN"). This runs the
	## actual downstream adapter and re-derives the no-shared-surface
	## invariant independently (mirroring SectionalPublicRealmPlan.add_node's
	## own bookkeeping) rather than trusting a non-null return alone.
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
		if plan == null:
			continue
		# MIN_SPAN_BANDS requires an 8-band climb, so every accepted
		# excavation contains at least one vertical move -- this is a real
		# exercise of the conflict on every seed reached, not a contrived one.
		var has_vertical := false
		for transition: WarrenVolumeTransition in plan.transitions:
			has_vertical = has_vertical or transition.is_vertical()
		assert_true(has_vertical,
			("seed %d: an excavated route must climb, or this test exercises " \
			+ "nothing") % world_seed)
		var realm := WarrenVolumePublicRealmAdapter.from_volume(plan)
		assert_not_null(realm, "seed %d: %s" \
			% [world_seed, WarrenVolumePublicRealmAdapter.last_failure])
		if realm == null:
			continue
		accepted += 1
		assert_true(realm.is_sealed(), realm.last_rejection)
		var surface_owner: Dictionary = {}
		for node: PublicRealmNode in realm.nodes:
			for cell: Vector3i in node.surface_cells:
				assert_false(surface_owner.has(cell),
					("seed %d: surface cell %s is claimed by both %s and " \
					+ "%s") % [world_seed, cell, surface_owner.get(cell),
					node.stable_id])
				surface_owner[cell] = node.stable_id
	assert_gt(accepted, 0,
		"no seed in the corpus produced a plan the realm adapter accepted")


func test_lanes_reach_the_plan_as_connected_auxiliary_public_realm() -> void:
	## Lanes must arrive downstream as ORDINARY public realm, because the whole
	## point of them is that the existing address, frontage, door, arcade and
	## partition machinery needs no special case for a street web.
	##
	## Three claims, each of which a plausible wiring mistake would break: every
	## lane cell is addressable (WarrenBuildingParcel.gd:47 rejects any address
	## the plan holds no frontage for, so a lane nobody can be addressed from is
	## a lane that buys nothing); the lane's own endpoints are walk NODES but
	## NOT primary itinerary (every gate that reads primary_itinerary is a
	## statement about the bored climb); and the sealed plan's walk graph is
	## connected, which is what seal() re-checks and what an orphan alley breaks.
	var massif := WarrenMassifBuilder.build(1)
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	var excavation := WarrenExcavationCarver.carve(1, massif)
	assert_not_null(excavation, WarrenExcavationCarver.last_failure)
	if excavation == null:
		return
	assert_gt(excavation.lanes.size(), 0, "seed 1 grew no lanes to adapt")
	var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
		excavation)
	assert_not_null(plan,
		"adapter failed: %s" % WarrenExcavationVolumeAdapter.last_failure)
	if plan == null:
		return
	assert_true(plan.is_sealed(), plan.last_rejection)
	for cell: Vector3i in excavation.lane_cells():
		assert_true(plan.has_frontage(cell),
			"lane cell %s is not addressable in the sealed plan" % cell)
	var primary: Dictionary = {}
	for cell: Vector3i in plan.primary_itinerary:
		primary[cell] = true
	var nodes := 0
	for lane: Dictionary in excavation.lanes:
		for spec: Dictionary in lane["transitions"] as Array[Dictionary]:
			var endpoint := spec["to"] as Vector3i
			nodes += 1
			assert_true(plan.has_walk(endpoint),
				"lane endpoint %s is not a walk node" % endpoint)
			assert_false(primary.has(endpoint),
				("lane endpoint %s joined the primary itinerary; the route's " \
				+ "own gates measure that list") % endpoint)
	assert_gt(nodes, 0, "no lane contributed a walk node")
	assert_eq(plan.walk_cells.size(),
		_endpoint_walk_cells(excavation).size() + nodes,
		"the plan's walk cells are exactly the route's endpoints plus the lanes'")
	# seal() already ran _all_walk_connected(); re-derived here so a future
	# adapter that stopped emitting lane transitions could not pass by simply
	# never wiring the lanes in.
	assert_eq(plan.audit.landing_turn_violation_count, 0,
		"a lane branching off the route left an undeclared vertical turn")
	assert_gt(int(plan.audit.auxiliary_walk_cell_count), 0,
		"the plan records no auxiliary public realm at all")

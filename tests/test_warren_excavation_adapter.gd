extends GutTest

## The adapter is the seam between the new mass-first stages and the whole
## existing parcel/fabric machine: its output must satisfy the same sealed
## WarrenVolumePlan contract the route-first carver produces.

const StampedGround = preload("res://tests/fixtures/warren_stamped_ground.gd")


func _hill(world_seed: int = 0) -> Dictionary:
	## Exercise the adapter against the shared synthetic settlement-relief stamp;
	## flat ground is valid, but relief-relative coordinates are the seam under
	## test here.
	return StampedGround.hill(WarrenMassifBuilder.RADIUS_CELLS + 4, world_seed)


func _excavation(world_seed: int, massif: WarrenMassif,
		require_lanes: bool = false) -> WarrenExcavation:
	## Match the production contract: a massif owns a deterministic bounded bore
	## family, not one privileged seed that must remain legal after its depth or
	## grammar changes. Return the first sealed survivor so repeated calls stay
	## bit-identical.
	for attempt in WarrenTownSolver.MASS_FIRST_EXCAVATION_ATTEMPTS:
		var carve_seed := world_seed \
			+ attempt * WarrenTownSolver.MASS_FIRST_ATTEMPT_STRIDE
		var result := WarrenExcavationCarver.carve(carve_seed, massif)
		if result != null and (not require_lanes or not result.lanes.is_empty()):
			return result
	return null


func test_adapter_produces_sealed_volume_plan() -> void:
	var massif := WarrenMassifBuilder.build(1, _hill())
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	var excavation := _excavation(1, massif)
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
	var massif := WarrenMassifBuilder.build(1, _hill())
	var excavation := _excavation(1, massif)
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


func _terraced_ground() -> Dictionary:
	## test_village_plan.gd's `_terraced_region` step field, restated in the
	## massif's own column lattice: three ground plateaus separated by risers.
	##
	## Measured in both riser height and bench width. The old field stepped 0/2/6
	## over two adjacent columns: a six-band cliff two columns wide that was not
	## representative of the settlement relief stamp and forced route behavior
	## around a synthetic wall.
	##
	## Both numbers now come from what the stamp actually produces:
	## SettlementReliefPlan's risers are one 4 m terrain storey, which is three
	## warren bands, and its benches are RING_WIDTH_CELLS of 24 m terrain cell,
	## which is eight or more 3 m columns. A bore climbs a riser by spending its
	## layer freedom along the bench below it, so a bench narrower than the
	## climb is impassable however low the riser.
	var span := WarrenMassifBuilder.RADIUS_CELLS + 4
	var bands: Dictionary = {}
	for z in range(-span, span + 1):
		for x in range(-span, span + 1):
			bands[Vector2i(x, z)] = 0 if x <= -5 else (3 if x <= 4 else 6)
	return bands


func test_adapter_envelope_matches_massif_column_heights_exactly() -> void:
	## The brief's own contract test only proves the synthesised envelope
	## KNOWS about every route column. It says nothing about whether the
	## envelope's ground/height at those columns -- and every other massif
	## column frontage/addressing logic will read -- actually match the
	## terraced mass Task 1 built, rather than some other plausible-looking
	## Gaussian shape.
	##
	## Run on two different relief frames and state the true relationship rather
	## than the one that happened to hold at base zero.
	## envelope_from_massif DROPS any column the neighbour-step clamp squeezed to
	## zero height, and `ground_at`/`height_at` answer 0 for a column the
	## envelope does not hold -- so on flat ground the old blanket "every massif
	## column matches" passed for dropped columns by coincidence (0 == 0 == 0).
	## On relief a dropped column's massif top is its own ground band, which is
	## not zero, and the coincidence is gone. The honest claim is that the
	## envelope holds exactly the positive-layer columns and copies those
	## faithfully.
	var adapted_frames := 0
	for ground: Dictionary in [_hill(), _terraced_ground()]:
		var massif := WarrenMassifBuilder.build(1, ground)
		assert_not_null(massif, WarrenMassifBuilder.last_failure)
		if massif == null:
			continue
		var excavation := _excavation(1, massif)
		if excavation == null:
			continue
		var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		assert_not_null(plan, WarrenExcavationVolumeAdapter.last_failure)
		if plan == null:
			continue
		adapted_frames += 1
		var envelope := plan.envelope
		var carried := 0
		var dropped := 0
		for column_value: Variant in massif.columns.keys():
			var column := column_value as Vector2i
			if massif.layer_at(column) < 1:
				dropped += 1
				assert_false(envelope.contains_column(column),
					("column %s carries no mass, so the envelope must drop it " \
					+ "rather than hold a zero-height column") % column)
				continue
			carried += 1
			assert_true(envelope.contains_column(column),
				"column %s carries mass and must reach the envelope" % column)
			assert_eq(envelope.ground_at(column), massif.base_at(column),
				"column %s ground band must match the massif" % column)
			assert_eq(envelope.height_at(column), massif.layer_at(column),
				"column %s height must match the massif's terrace" % column)
			assert_eq(envelope.top_at(column), massif.top_at(column),
				"column %s top must match the massif exactly" % column)
			# The SECOND datum. Ground stays natural ground so the frontage,
			# arcade and cover rules keep reading the whole solid; the terrace
			# only bounds how far a house descends.
			assert_eq(envelope.bearing_at(column), massif.bearing_at(column),
				"column %s terrace must match the massif" % column)
		assert_eq(carried + dropped, massif.columns.size())
		assert_eq(envelope.height_bands.size(), carried,
			"the envelope must hold exactly the massif's load-bearing columns")
		var raised := 0
		var grounded := 0
		for column_value: Variant in massif.columns.keys():
			var column := column_value as Vector2i
			if not envelope.contains_column(column):
				continue
			raised += int(envelope.bearing_at(column)
				> envelope.ground_at(column))
			grounded += int(envelope.ground_at(column)
				== massif.base_at(column))
		# The second datum is intentionally equal to natural ground: the deep
		# mountain is inhabited construction, never a hidden substrate that may
		# lift a house away from terrain.
		assert_eq(raised, 0,
			"nothing the fabric authors stands below the buildable layer, so "
			+ "no envelope column may declare a terrace above its own ground")
		assert_eq(grounded, envelope.height_bands.size(),
			"every envelope column stands on its own input ground band")
	assert_gt(adapted_frames, 0,
		"no relief frame produced an excavation for the adapter fidelity check")


func test_adapter_transitions_preserve_excavation_spine_edges() -> void:
	## Confirms the adapter builds transitions FROM what the excavation
	## already decided rather than re-deriving new endpoints: every macro
	## move the carver recorded must survive into the sealed plan unaltered
	## (same from, to, and kind), regardless of whatever connective spurs the
	## adapter also had to add for STAIR/RAMP intermediate cells.
	var massif := WarrenMassifBuilder.build(1, _hill())
	var excavation := _excavation(1, massif)
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
	var massif := WarrenMassifBuilder.build(1, _hill())
	var excavation := _excavation(1, massif)
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
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		if massif == null:
			continue
		var excavation := _excavation(world_seed, massif)
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
			# Zero-layer columns are dropped by envelope_from_massif, and the
			# envelope answers 0 for a column it does not hold. Comparing tops
			# there only ever held because flat ground made both sides 0.
			if not plan.envelope.contains_column(column):
				assert_lt(massif.layer_at(column), 1,
					("seed %d: column %s carries mass but never reached the " \
					+ "envelope") % [world_seed, column])
				continue
			assert_eq(plan.envelope.top_at(column), massif.top_at(column),
				"seed %d column %s height must match the massif" \
				% [world_seed, column])
	assert_gt(accepted, 0,
		"no seed in the corpus produced a sealed plan")


func test_the_whole_mass_first_chain_runs_on_terraced_ground() -> void:
	## WAVE 1 ACCEPTANCE. Mass-first has only ever been exercised at base 0, and
	## the terrain audit found it dying at the FIRST stage on any relief. This
	## walks the whole chain -- massif, carve, adapt, partition -- on the
	## terraced step field the village suite already uses for real terrain, and
	## demands the same guarantees the flat corpus gets: a sealed volume plan
	## whose columns stand on their own input ground, and a partition that
	## leaves no street wall to nobody.
	var ground := _terraced_ground()
	var reached := 0
	var relief_seen := 0
	var houses := 0
	for world_seed: int in [1, 3, 4, 5, 6, 9, 11]:
		var massif := WarrenMassifBuilder.build(world_seed, ground)
		if massif == null:
			continue
		# The gates are relief-relative, so the massif must build on relief
		# wherever it builds on flat ground -- pinned as an invariance in
		# test_warren_massif.gd; here it is only the precondition.
		var bases: Dictionary = {}
		for column: Vector2i in massif.columns:
			assert_eq(massif.base_at(column), int(ground[column]),
				"seed %d: column %s ignored its input ground" \
				% [world_seed, column])
			bases[massif.base_at(column)] = true
		assert_gt(bases.size(), 1,
			"seed %d: a footprint on one ground band proves nothing about relief"
			% world_seed)
		relief_seen += 1
		var excavation := _excavation(world_seed, massif)
		if excavation == null:
			continue
		# The at-grade street is the local input ground, not band 0.
		var grade_bands: Dictionary = {}
		for cell: Vector3i in excavation.route:
			var column := Vector2i(cell.x, cell.z)
			if cell.y == massif.base_at(column):
				grade_bands[cell.y] = true
		assert_gt(grade_bands.size(), 0,
			"seed %d: the bore never touched its own ground" % world_seed)
		var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if plan == null:
			continue
		assert_true(plan.is_sealed(), "seed %d: %s" \
			% [world_seed, plan.last_rejection])
		var parcels := WarrenSolidPartitioner.partition(massif, excavation)
		if parcels.is_empty():
			continue
		reached += 1
		houses += parcels.size()
		var unowned := WarrenSolidPartitioner.unowned_route_faces(parcels,
			excavation, massif)
		assert_eq(unowned.size(), 0,
			"seed %d: %d street walls belong to nobody on terraced ground: %s" \
			% [world_seed, unowned.size(), str(unowned.slice(0, 6))])
		for parcel: WarrenBuildingParcel in parcels:
			var footing := -2147483648
			for column: Vector2i in parcel.footprint:
				footing = maxi(footing, massif.base_at(column))
			assert_gte(parcel.base_band, footing,
				("seed %d: house %s is rooted below its own input ground, so " \
				+ "the chain is still assuming base 0") \
				% [world_seed, parcel.stable_id])
	assert_gt(relief_seen, 0,
		"no seed built a massif on the terraced frame at all")
	assert_gt(reached, 0,
		"no seed reached a partition on terraced ground -- the whole point "
		+ "of relief-relative gates is that the chain now runs on relief")
	# A floor on "the chain really ran", not a target. The deep inhabited bell
	# should supply many terrain-rooted houses across the corpus, while seed
	# supply may still move without this test becoming a pin on an exact count.
	assert_gt(houses, 84,
		"only %d houses across %d terraced towns -- the chain is limping, "
		% [houses, reached] + "not running")


func test_adapter_is_deterministic() -> void:
	## No randf/Time/engine RNG anywhere in the adapter: rebuilding from the
	## same massif and excavation objects (themselves already proven
	## deterministic by their own suites) must yield a bit-identical plan.
	var massif := WarrenMassifBuilder.build(1, _hill())
	var excavation := _excavation(1, massif)
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
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		if massif == null:
			continue
		var excavation := _excavation(world_seed, massif)
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
	var massif := WarrenMassifBuilder.build(1, _hill())
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	var excavation := _excavation(1, massif, true)
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


func _breadth_probe(walk: Array[Vector3i]) -> WarrenVolumePlan:
	## A plan carrying exactly `walk` as one connected LEVEL chain, built far
	## enough from any real geometry that only the breadth audit is under test.
	## Deliberately not sealed: exact_route_breadth_audit reads walk cells and
	## transitions, which is all this needs, and sealing would drag in the
	## envelope, entry and landing contracts that have nothing to do with breadth.
	var envelope := WarrenVolumeEnvelope.new()
	var plan := WarrenVolumePlan.new(&"breadth.probe", 0, envelope)
	for cell: Vector3i in walk:
		plan.add_walk_cell(cell)
	return plan


func test_public_breadth_is_bounded_locally_not_by_total_size() -> void:
	## The property this audit protects is a SLAB -- public floor broader than
	## one macro cell. The total inside-corner count is not that property: it is
	## a corner count, so it grows with how convoluted and how large the street
	## network is, which is the quality the warren exists to produce.
	##
	## Pinned as an invariance so the allowance can never regress to an absolute
	## number again. Two constructions, and they must be decided differently.
	var winding: Array[Vector3i] = []
	# A one-wide staircase-shaped lane: 40 macro cells, 39 turns, no two cells
	# ever forming a 2x2 block. Every inside corner it owns is isolated.
	var cursor := Vector3i.ZERO
	for step in 40:
		winding.append(cursor)
		cursor += Vector3i.RIGHT if step % 2 == 0 else Vector3i.BACK
	var winding_plan := _breadth_probe(winding)
	var winding_audit := winding_plan.exact_route_breadth_audit()
	assert_lte(int(winding_audit.max_interior_component_size),
		WarrenVolumePlan.MAX_EXACT_ROUTE_INTERIOR_COMPONENT_SIZE,
		"a one-wide winding lane owns only isolated inside corners")
	assert_true(winding_plan.exact_route_breadth_allows(),
		("a %d-cell winding network with %d inside corners is not a slab and " \
		+ "must be admitted") % [winding.size(),
			int(winding_audit.interior_cell_count)])

	# A genuine plaza: a 4x4 macro block. Same cell count order of magnitude,
	# but the public floor is now four macro cells wide.
	var plaza: Array[Vector3i] = []
	for x in 4:
		for z in 4:
			plaza.append(Vector3i(x, 0, z))
	var plaza_plan := _breadth_probe(plaza)
	var plaza_audit := plaza_plan.exact_route_breadth_audit()
	assert_gt(int(plaza_audit.max_interior_component_size),
		WarrenVolumePlan.MAX_EXACT_ROUTE_INTERIOR_COMPONENT_SIZE,
		"a 4x4 macro block is one broad slab of public floor")
	assert_false(plaza_plan.exact_route_breadth_allows(),
		"a plaza must still be refused, whatever the total allowance is")
	# And it is refused on the LOCAL rule, not on the total -- so growing the
	# network can never make a plaza legal.
	assert_lte(int(plaza_audit.interior_cell_count),
		WarrenVolumePlan.interior_breadth_allowance(plaza.size()),
		("the plaza's total is within allowance; only the component cap " \
		+ "catches it, which is why the component cap is the real rule"))

	# The allowance is a density, and it never falls below what it was.
	assert_eq(WarrenVolumePlan.interior_breadth_allowance(10),
		WarrenVolumePlan.MAX_EXACT_ROUTE_INTERIOR_CELLS,
		"a small public realm keeps the historical absolute allowance")
	assert_gt(WarrenVolumePlan.interior_breadth_allowance(80),
		WarrenVolumePlan.interior_breadth_allowance(40),
		"a larger public realm is allowed proportionally more corners")
	for walk_cells in [1, 20, 40, 42, 80, 200]:
		assert_gte(WarrenVolumePlan.interior_breadth_allowance(walk_cells),
			WarrenVolumePlan.MAX_EXACT_ROUTE_INTERIOR_CELLS,
			"the allowance may never drop below the historical floor")

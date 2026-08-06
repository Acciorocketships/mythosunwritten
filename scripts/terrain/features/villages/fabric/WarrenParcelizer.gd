class_name WarrenParcelizer
extends RefCounted

## Deterministic bounded selection of roofable building envelopes around the
## carved public realm.  Selection changes construction mass only; it cannot add,
## remove, or reconnect any public route cell.
const MAX_PARCELS := 28
const MIN_PARCELS := 10
# The horizontal dry packing is also the construction backbone admitted by the
# real solve.  Stopping it at the validity minimum produced exactly ten houses
# even when four more measured-compatible walls existed, leaving most of a
# 22-cell route to be closed by platforms.  Continue to a modest density target;
# plans which cannot reach it still retain the ten-building validity floor and
# lose naturally on packing capacity.
const TARGET_PACKED_PARCELS := 14
const MAX_ONE_STOREY_TOWERS := 3
## Compact 3 m towers are useful corner closers, but their complete authored
## roof vocabulary is deliberately small.  Capping their total count prevents
## exact enclosure pressure from turning an otherwise varied warren into a row
## of the same little gable.  Wider/deeper parcels must carry the remaining
## street wall, so the cap changes construction geometry rather than recolouring
## duplicate stamps after packing.
const MAX_TOWER_PARCELS := 3
# The 3 x 6 townhouse is the best narrow alley filler, so an unconstrained
# greedy pass replaces every rejected tower with the same slim silhouette.
# Cap it independently; density is protected by parcel-footprint area, allowing
# square and long houses to carry the street wall instead of another repeated
# narrow roof.
const MAX_SLIM_PARCELS := 3
const MAX_ONE_STOREY_WIDE_BUILDINGS := 1
# A chimney cannot rescue a one-storey footprint whose horizontal silhouette
# still dominates its inhabited height. These formerly served as a packing
# escape hatch, but the exact frontier is broad enough to choose a different
# topology instead. Production therefore admits no visually short building.
const MAX_VISUALLY_SHORT_BUILDINGS := 0
const VISUALLY_SHORT_FALLBACK_COST := 2200.0
# Local socket score is only a pre-order; measured follow-up capacity chooses
# among a bounded diverse prefix. Twenty-four retains several straight/corner
# lengths and facade phases without paying the quadratic reservation audit for
# every interchangeable bridge pair.
const CONNECTION_PAIR_FRONTIER := 24
const SHAPES: Array[Vector2i] = [
	# The main modular gable is 6.49 m across its eaves. A 6 x 9 m parcel is the
	# smallest repeat-aligned footprint whose ridge is unambiguously longer than
	# that transverse span. The former 3 x 6 logical slot was visually sideways.
	Vector2i(2, 3),
	Vector2i(2, 2),
	# A 3 x 6 m frontage is retained only with the staggered pair of complete
	# compact gables compiled by SettlementFabricProgram.  Both ridges run along
	# the six-metre axis; this is no longer the old sideways 6.49 m modular roof.
	Vector2i(1, 2),
	Vector2i(1, 1),
]
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]
static var last_failure := ""
static var last_diagnostic: Dictionary = {}


static func solve(source: WarrenVolumePlan,
		pair_compatibility: Callable = Callable(),
		connection_pair: Callable = Callable(),
		reservation_compatibility: Callable = Callable(),
		connection_broad_phase: Callable = Callable()) -> WarrenParcelPlan:
	return _solve(source, false, pair_compatibility, connection_pair,
		reservation_compatibility, connection_broad_phase)


static func diagnostic_solve(source: WarrenVolumePlan) -> WarrenParcelPlan:
	return _solve(source, true, Callable(), Callable(), Callable(), Callable())


static func _solve(source: WarrenVolumePlan,
		allow_short_diagnostic: bool,
		pair_compatibility: Callable,
		connection_pair: Callable,
		reservation_compatibility: Callable,
		connection_broad_phase: Callable) -> WarrenParcelPlan:
	last_failure = ""
	last_diagnostic = {}
	var solve_started := Time.get_ticks_msec()
	if source == null or not source.is_sealed():
		last_failure = "missing sealed volume"
		return null
	var vertical_candidates := _candidates(source)
	var candidates := _horizontal_candidates(vertical_candidates)
	var candidates_finished := Time.get_ticks_msec()
	last_diagnostic = {
		"candidate_count": candidates.size(),
		"vertical_variant_count": vertical_candidates.size(),
		"one_storey_candidate_count": _candidate_short_count(candidates),
	}
	if candidates.is_empty():
		last_failure = "no complete narrow/deep roofable candidates"
		return null
	# Exact recipe envelopes are immutable for the duration of one bounded solve.
	# The lookahead visits the same candidate pairs many times; cache that pure
	# predicate once instead of rebuilding component AABBs for every greedy state.
	if pair_compatibility.is_valid():
		var original_pair_compatibility := pair_compatibility
		var pair_compatibility_cache: Dictionary = {}
		pair_compatibility = func(left: WarrenBuildingParcel,
				right: WarrenBuildingParcel) -> bool:
			var key := _parcel_pair_key(left, right)
			if not pair_compatibility_cache.has(key):
				pair_compatibility_cache[key] = bool(
					original_pair_compatibility.call(left, right))
			return bool(pair_compatibility_cache[key])
	var selected: Array[WarrenBuildingParcel] = []
	var occupied: Dictionary = {}
	var used_thresholds: Dictionary = {}
	var shape_counts: Dictionary = {}
	var base_counts: Dictionary = {}
	var addressed_walk_counts: Dictionary = {}
	var selected_overpass_count := 0
	var selected_half_level_pair_count := 0
	var selected_one_storey_tower_count := 0
	var selected_tower_count := 0
	var selected_slim_count := 0
	var selected_one_storey_wide_count := 0
	var selected_visually_short_count := 0
	var selection_conflict_cache: Dictionary = {}
	# Preserve one exact future occupied-link relationship before generic packing
	# consumes either facade. This is a construction motif selected from ordinary
	# candidates, never a post-hoc bridge or special location stamp.
	var connection_motif := _best_connection_pair(source, candidates, selected,
		pair_compatibility, connection_pair, reservation_compatibility,
		connection_broad_phase)
	var connection_finished := Time.get_ticks_msec()
	if connection_pair.is_valid() and connection_motif.is_empty():
		last_failure = "no measured occupied-link pair among %d roofable candidates" \
			% candidates.size()
		return null
	var connection_seed: Array[Dictionary] = []
	connection_seed.assign(connection_motif.get("candidates", []) as Array)
	var connection_reservation := connection_motif.get("reservation", {}) \
		as Dictionary
	if reservation_compatibility.is_valid() \
			and not connection_reservation.is_empty():
		var original_reservation_compatibility := reservation_compatibility
		var reservation_compatibility_cache: Dictionary = {}
		reservation_compatibility = func(parcel: WarrenBuildingParcel,
				reservation: Dictionary) -> bool:
			var key := "%s|%s" % [parcel.stable_id,
				_reservation_key(reservation)]
			if not reservation_compatibility_cache.has(key):
				reservation_compatibility_cache[key] = bool(
					original_reservation_compatibility.call(parcel, reservation))
			return bool(reservation_compatibility_cache[key])
	# A maze street needs at least one literal canyon interval: two complete,
	# measured-compatible buildings addressing the same exterior walk cell from
	# opposite sides.  Seed that relation before generic packing so the solver
	# cannot spend every compatible envelope on a different exposed interval and
	# then claim density from parcel count alone.  This is a topological motif of
	# ordinary parcels, analogous to the occupied-link motif above; it does not
	# add a facade or repair geometry after selection.
	var opposing_frontage_seed: Array[Dictionary] = []
	opposing_frontage_seed.assign(connection_motif.get(
		"opposing_candidates", []) as Array)
	if opposing_frontage_seed.is_empty():
		opposing_frontage_seed = _best_opposing_frontage_pair(candidates,
			pair_compatibility, selected, connection_reservation,
			reservation_compatibility)
	if opposing_frontage_seed.is_empty():
		last_failure = "no measured opposing-facade pair survived the occupied-link reservation"
		return null
	# The four mandatory relationship endpoints are selected as one bounded
	# construction backbone.  The motif search also returns a conflict-graph
	# continuation proving that its aesthetic choices cannot strand the minimum
	# inhabited count; admitting that continuation here makes completeness a
	# construction property rather than a repair pass after greedy packing.
	var construction_seed := connection_seed.duplicate()
	construction_seed.append_array(opposing_frontage_seed)
	construction_seed.append_array(connection_motif.get(
		"packing_followup_candidates", []) as Array)
	for seed_candidate: Dictionary in construction_seed:
		var seed_parcel := seed_candidate.parcel as WarrenBuildingParcel
		if selected.has(seed_parcel):
			continue
		selected.append(seed_parcel)
		used_thresholds[_threshold_key(seed_parcel)] = true
		var seed_family := _shape_key(seed_parcel)
		shape_counts[seed_family] = int(shape_counts.get(seed_family, 0)) + 1
		base_counts[seed_parcel.base_band] = int(base_counts.get(
			seed_parcel.base_band, 0)) + 1
		addressed_walk_counts[seed_parcel.address_walk_cell] = int(
			addressed_walk_counts.get(seed_parcel.address_walk_cell, 0)) + 1
		selected_overpass_count += int(seed_parcel.has_occupied_overpass)
		selected_one_storey_tower_count += int(_is_one_storey_tower(seed_parcel))
		selected_tower_count += int(seed_parcel.width_cells == 1 \
			and seed_parcel.depth_cells == 1)
		selected_slim_count += int(seed_parcel.width_cells == 1 \
			and seed_parcel.depth_cells == 2)
		selected_one_storey_wide_count += int(_is_one_storey_wide(seed_parcel))
		selected_visually_short_count += int(_is_visually_short(seed_parcel))
		if _forms_half_level_pair(seed_parcel,
				selected.slice(0, selected.size() - 1)):
			selected_half_level_pair_count += 1
		for cell: Vector3i in seed_parcel.occupied_cells():
			occupied[cell] = true
	# Half-level adjacency remains mandatory, but it is chosen around the sealed
	# occupied-link corridor so a lower-priority stagger cannot consume the only
	# viable bridge opportunity. Both motifs still consist of ordinary parcels.
	var half_level_seed := _best_half_level_pair(candidates, pair_compatibility,
		selected, connection_reservation, reservation_compatibility)
	var half_level_finished := Time.get_ticks_msec()
	for seed_candidate: Dictionary in half_level_seed:
		var seed_parcel := seed_candidate.parcel as WarrenBuildingParcel
		if selected.has(seed_parcel):
			continue
		selected.append(seed_parcel)
		used_thresholds[_threshold_key(seed_parcel)] = true
		var seed_family := _shape_key(seed_parcel)
		shape_counts[seed_family] = int(shape_counts.get(seed_family, 0)) + 1
		base_counts[seed_parcel.base_band] = int(base_counts.get(
			seed_parcel.base_band, 0)) + 1
		addressed_walk_counts[seed_parcel.address_walk_cell] = int(
			addressed_walk_counts.get(seed_parcel.address_walk_cell, 0)) + 1
		selected_overpass_count += int(seed_parcel.has_occupied_overpass)
		selected_one_storey_tower_count += int(_is_one_storey_tower(seed_parcel))
		selected_tower_count += int(seed_parcel.width_cells == 1 \
			and seed_parcel.depth_cells == 1)
		selected_slim_count += int(seed_parcel.width_cells == 1 \
			and seed_parcel.depth_cells == 2)
		selected_one_storey_wide_count += int(_is_one_storey_wide(seed_parcel))
		selected_visually_short_count += int(_is_visually_short(seed_parcel))
		if _forms_half_level_pair(seed_parcel,
				selected.slice(0, selected.size() - 1)):
			selected_half_level_pair_count += 1
		for cell: Vector3i in seed_parcel.occupied_cells():
			occupied[cell] = true
	while selected.size() < MAX_PARCELS:
		var best_candidate: Dictionary = {}
		var best_score := INF
		# Viability depends only on the current selected state, not on which
		# candidate is being scored. Compute it once per greedy step. The former
		# nested lookahead re-ran every candidate's selected-stack and reservation
		# proof for every possible choice, making the exact asset frontier cubic in
		# practice even though all predicates are immutable.
		var viable_candidates: Array[Dictionary] = []
		for candidate: Dictionary in candidates:
			var parcel := candidate.parcel as WarrenBuildingParcel
			var threshold_key := _threshold_key(parcel)
			if used_thresholds.has(threshold_key) \
					or (parcel.width_cells == 1 and parcel.depth_cells == 1 \
						and selected_tower_count >= MAX_TOWER_PARCELS) \
					or (parcel.width_cells == 1 and parcel.depth_cells == 2 \
						and selected_slim_count >= MAX_SLIM_PARCELS) \
					or (_is_one_storey_tower(parcel) \
						and selected_one_storey_tower_count \
							>= MAX_ONE_STOREY_TOWERS) \
					or (_is_one_storey_wide(parcel) \
						and selected_one_storey_wide_count \
							>= MAX_ONE_STOREY_WIDE_BUILDINGS) \
					or (_is_visually_short(parcel) \
						and selected_visually_short_count \
							>= MAX_VISUALLY_SHORT_BUILDINGS) \
					or (_is_tall_construction(parcel) \
						and _roof_step_neighbor_count(parcel, selected) == 0) \
					or _overlaps_occupied(parcel, occupied) \
					or not _compatible_with_selected(parcel, selected,
						pair_compatibility) \
					or not _preserves_reservation(parcel, connection_reservation,
						reservation_compatibility):
				continue
			viable_candidates.append(candidate)
		for candidate: Dictionary in viable_candidates:
			var parcel := candidate.parcel as WarrenBuildingParcel
			var is_auxiliary := bool(candidate.get("is_auxiliary", false))
			var is_ground_arcade := bool(candidate.get("is_ground_arcade", false))
			var is_elevated_gallery := bool(candidate.get(
				"is_elevated_gallery", false))
			var is_gallery_terminal := bool(candidate.get(
				"is_gallery_terminal", false))
			var is_ground_primary := bool(candidate.get("is_ground_primary", false))
			var family := _shape_key(parcel)
			var address_count := int(addressed_walk_counts.get(
				parcel.address_walk_cell, 0))
			var family_count := int(shape_counts.get(family, 0))
			# Repeated compact houses are useful for closing the final turn, but they
			# may not become the dominant visual language.  The old 150-point cost
			# was negligible beside frontage rewards in the thousands, which is why
			# entire streets compiled as identical towers.  Shape diversity is now a
			# first-class packing objective on the same scale as enclosure.
			var repeat_cost := 1800.0 if parcel.width_cells == 1 \
				and parcel.depth_cells == 1 else 800.0 \
				if parcel.width_cells == 1 else 300.0
			var dynamic_score := float(candidate.score) \
				+ float(family_count) * repeat_cost \
				+ float(int(base_counts.get(parcel.base_band, 0))) * 300.0 \
				+ float(maxi(0, address_count - 1)) * 210.0
			if not shape_counts.has(family):
				dynamic_score -= 900.0
			var repeated_row_neighbors := _repeated_row_neighbor_count(parcel,
				selected)
			if repeated_row_neighbors > 0:
				# Same footprint, base, height, ridge, and frontage is exactly the
				# barracks-like row the city grammar must avoid.
				dynamic_score += float(repeated_row_neighbors) * 5500.0
			var adjacent_same_base := _same_base_neighbor_count(parcel, selected)
			if adjacent_same_base > 0:
				dynamic_score += float(adjacent_same_base) * 800.0
			var adjacent_half_level := _half_level_neighbor_count(parcel, selected)
			if adjacent_half_level > 0:
				dynamic_score -= float(adjacent_half_level) * 1500.0
			if address_count == 0:
				# Closing a previously exposed route interval is the first-order
				# volumetric-city objective. It must outweigh the compatibility
				# lookahead's modest preference for an interchangeable empty pocket.
				dynamic_score -= 1600.0 if pair_compatibility.is_valid() \
					else 440.0
			elif address_count == 1:
				# A second distinct facade turns an exposed strip into an alley.
				# It is nearly as valuable as first-side coverage: maximizing only
				# the latter produced a nominally bounded route that still read as
				# one open street from oblique views. Third and fourth addresses
				# remain costly to avoid an impassably pinched node.
				dynamic_score -= 8000.0 if pair_compatibility.is_valid() \
					else 620.0
			if is_ground_arcade:
				# The ground arcade is part of the town's inhabited lower wall, not a
				# decorative route appended after packing.  Spending a compatible
				# envelope here must beat leaving enough raw capacity for a building in
				# an unrelated open pocket; otherwise the later arcade proof sees an
				# empty street even though the parcel count is nominally high.  Exact
				# mesh clearance and future-link reservations remain hard gates above.
				dynamic_score -= 12000.0 if address_count == 0 else 4500.0 \
					if address_count == 1 else 0.0
			elif is_elevated_gallery:
				# Upper branches exist specifically to become facade canyons. If their
				# walls lose a packing tie to an unrelated perimeter plot, the branch
				# would regress into the detached broad deck it was designed to replace.
				dynamic_score -= 11000.0 if address_count == 0 else 6500.0 \
					if address_count == 1 else 0.0
				if is_gallery_terminal:
					# A one-edge upper branch is valid only as a doorstep. Without an
					# addressed facade it becomes the disconnected ornamental shelf the
					# volumetric route was designed to eliminate.
					dynamic_score -= 24000.0 if address_count == 0 else 9000.0 \
						if address_count == 1 else 0.0
			elif is_ground_primary:
				# The first storey of the climbing itinerary must read as a street
				# cut between inhabited walls, not as grass beneath an elevated town.
				# This is intentionally distinct from generic primary frontage: upper
				# galleries already gain enclosure from the staggered mass around them,
				# while an exposed ground interval creates a sightline through the whole
				# settlement.  Exact measured-clearance remains the admission authority.
				dynamic_score -= 16500.0 if address_count == 0 else 8200.0 \
					if address_count == 1 else 0.0
			elif is_auxiliary:
				dynamic_score -= 1800.0 if address_count == 0 else 700.0 \
					if address_count == 1 else 0.0
			if parcel.has_occupied_overpass:
				# A maze is most legible when occupied mass repeatedly crosses its own
				# route: streets should tunnel under rooms, not merely pass beside
				# them. Reward bridge-house parcels with a long diminishing tail;
				# exact mass, bearing, headroom, and roof clearance remain hard
				# gates, so this cannot create a decorative canopy.
				dynamic_score -= 6000.0 if selected_overpass_count == 0 \
					else 4000.0 if selected_overpass_count == 1 else 2600.0 \
					if selected_overpass_count == 2 else 1600.0 \
					if selected_overpass_count == 3 else 900.0 \
					if selected_overpass_count == 4 else 600.0 \
					if selected_overpass_count == 5 else 0.0
			if selected_half_level_pair_count == 0 \
					and _forms_half_level_pair(parcel, selected):
				dynamic_score -= 620.0
			var roof_step_neighbors := _roof_step_neighbor_count(parcel, selected)
			if roof_step_neighbors > 0:
				# Roof height is part of composition, not a palette choice. Adjacent
				# envelopes separated by one half/full level turn a sheer tower into
				# the intended Gaussian staircase and expose useful roofs/outcroppings
				# from the upper path. Multiple compatible steps are especially useful
				# because they join local descents into a chain instead of isolated pairs.
				dynamic_score -= 3800.0 \
					+ float(roof_step_neighbors - 1) * 1200.0
			if _is_lower_roof_step(parcel, selected):
				# This used to be guarded by _is_visually_short(), even though
				# production deliberately forbids visually short buildings. As a
				# result the strongest downhill-composition reward was unreachable and
				# tall stacks were routinely left as isolated shafts. Prefer an
				# ordinary complete house one roof band below an existing neighbour.
				dynamic_score -= 5200.0
				if _is_grounded_low_terminal(parcel):
					# A terrain-addressed two-storey house completes the Gaussian descent
					# without reintroducing the squat one-storey escape vocabulary.
					dynamic_score -= 2800.0
			var atomic_roof_neighbors := _atomic_perpendicular_neighbor_count(
				parcel, selected)
			if atomic_roof_neighbors > 0:
				# A face contact is not automatically a convincing old-town roofscape.
				# Prefer the bounded subset whose equal-height orthogonal ridges can be
				# compiled by the same finite host/branch table used at assembly. Cap
				# the reward so a few cross-gabled compounds do not flatten the entire
				# skyline onto one datum.
				dynamic_score -= float(mini(atomic_roof_neighbors, 2)) * 4200.0
			# Prefer a complete packing over a locally attractive envelope. Count
			# how many currently viable tall candidates this choice would eliminate
			# through footprint, facade, or measured-clearance conflicts. The route
			# vocabulary is small and bounded, so this deterministic forward check is
			# cheaper and clearer than repairing a stranded greedy result afterward.
			var blocking_count := _selection_blocking_count(parcel,
				viable_candidates, pair_compatibility,
				selection_conflict_cache) if pair_compatibility.is_valid() else 0
			# A second frontage is valuable only if it does not strand the rest of
			# the occupied envelope. Measured roofs make one unlucky wide choice
			# eliminate several otherwise valid narrow/deep neighbors, so capacity
			# remains the dominant tie-break even while closing an alley.
			var enclosure_critical := is_ground_arcade or is_elevated_gallery \
				or is_ground_primary
			var blocking_weight := (1400.0 if enclosure_critical else 1800.0) \
				if pair_compatibility.is_valid() else 1600.0
			dynamic_score += float(blocking_count) * blocking_weight
			if best_candidate.is_empty() or dynamic_score < best_score:
				best_candidate = candidate
				best_score = dynamic_score
		if best_candidate.is_empty():
			break
		var parcel := best_candidate.parcel as WarrenBuildingParcel
		var threshold_key := _threshold_key(parcel)
		selected.append(parcel)
		used_thresholds[threshold_key] = true
		var family := _shape_key(parcel)
		shape_counts[family] = int(shape_counts.get(family, 0)) + 1
		base_counts[parcel.base_band] = int(base_counts.get(parcel.base_band, 0)) + 1
		addressed_walk_counts[parcel.address_walk_cell] = int(
			addressed_walk_counts.get(parcel.address_walk_cell, 0)) + 1
		selected_overpass_count += int(parcel.has_occupied_overpass)
		selected_one_storey_tower_count += int(_is_one_storey_tower(parcel))
		selected_tower_count += int(parcel.width_cells == 1 \
			and parcel.depth_cells == 1)
		selected_slim_count += int(parcel.width_cells == 1 \
			and parcel.depth_cells == 2)
		selected_one_storey_wide_count += int(_is_one_storey_wide(parcel))
		selected_visually_short_count += int(_is_visually_short(parcel))
		if _forms_half_level_pair(parcel, selected.slice(0, selected.size() - 1)):
			selected_half_level_pair_count += 1
		for cell: Vector3i in parcel.occupied_cells():
			occupied[cell] = true
	if selected.size() < MIN_PARCELS and not allow_short_diagnostic:
		last_diagnostic["selected_count"] = selected.size()
		last_diagnostic["selected_signature"] = _selection_signature(selected)
		last_diagnostic["connection_seed_count"] = connection_seed.size()
		last_diagnostic["half_level_seed_count"] = half_level_seed.size()
		last_failure = "packing stopped at %d/%d complete buildings" % [
			selected.size(), MIN_PARCELS]
		return null
	# Horizontal occupancy is now complete. Reassign only the complete storey
	# variants of those immutable footprint/address slots so roof rhythm cannot
	# lose a packing tie to the shorter version of the same house. The vertical
	# solver uses the same measured compatibility and occupied-link reservation
	# contracts as this transaction; failure rejects the plan rather than falling
	# back to a flat skyline.
	if not allow_short_diagnostic:
		var vertical := WarrenParcelHeightSolver.solve(selected,
			vertical_candidates,
			pair_compatibility, connection_reservation,
			reservation_compatibility)
		if vertical.is_empty():
			last_failure = WarrenParcelHeightSolver.last_failure
			last_diagnostic["height"] = \
				WarrenParcelHeightSolver.last_diagnostic.duplicate(true)
			return null
		selected = vertical
		if not _rebind_reservation_owners(connection_reservation, selected):
			last_failure = "occupied-link owner slot disappeared after height solve"
			return null
		last_diagnostic["height"] = \
			WarrenParcelHeightSolver.last_diagnostic.duplicate(true)
	var plan := WarrenParcelPlan.new(
		StringName("%s.parcels" % source.stable_id), source)
	var reservations: Array[Dictionary] = []
	if not connection_reservation.is_empty():
		reservations.append(connection_reservation)
	# A single planned bridge can become a decorative punctuation mark. Once the
	# final skyline is frozen, reserve one additional independent socket pair if
	# it exists. This search cannot move a parcel or change its height; it accepts
	# only another exact authored corridor whose cells and measured bounds are
	# disjoint from the first and whose non-owner buildings all preserve it.
	var additional_reservation := _best_additional_connection_reservation(
		source, selected, reservations, connection_pair,
		reservation_compatibility, connection_broad_phase)
	if not additional_reservation.is_empty():
		reservations.append(additional_reservation)
	if not plan.seal(selected, reservations):
		last_failure = "parcel plan rejected after packing"
		return null
	last_diagnostic["selected_count"] = selected.size()
	last_diagnostic["gallery_terminal_count"] = int(plan.audit.get(
		"elevated_gallery_terminal_count", 0))
	last_diagnostic["addressed_gallery_terminal_count"] = int(plan.audit.get(
		"addressed_elevated_gallery_terminal_count", 0))
	last_diagnostic["selected_signature"] = _selection_signature(selected)
	last_diagnostic["selected_shape_counts"] = shape_counts.duplicate()
	last_diagnostic["plan_audit"] = plan.audit.duplicate(true)
	last_diagnostic["timing"] = {
		"candidate_ms": candidates_finished - solve_started,
		"connection_ms": connection_finished - candidates_finished,
		"half_level_ms": half_level_finished - connection_finished,
		"greedy_and_seal_ms": Time.get_ticks_msec() - half_level_finished,
		"total_ms": Time.get_ticks_msec() - solve_started,
	}
	return plan


static func _candidates(source: WarrenVolumePlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var candidate_index := 0
	# The lower arcade is carved before parcels, so its sides are ordinary
	# construction opportunities rather than a post-hoc decoration problem.
	# Primary and auxiliary addresses share the same roof/clearance contracts;
	# only the score distinguishes their role in the composed town.
	for route_index in source.walk_cells.size():
		var walk := source.walk_cells[route_index]
		var is_auxiliary := not source.primary_itinerary.has(walk)
		var is_ground_arcade := source.ground_arcade_cells.has(walk)
		var is_elevated_gallery := source.elevated_gallery_cells.has(walk)
		var is_gallery_terminal := is_elevated_gallery \
			and _walk_transition_degree(source, walk) == 1
		var is_ground_primary := source.primary_itinerary.has(walk) \
			and walk.y == source.envelope.ground_at(Vector2i(walk.x, walk.z))
		for direction_index in DIRECTIONS.size():
			var walk_to_building := DIRECTIONS[direction_index]
			var frontage := -walk_to_building
			for shape_index in SHAPES.size():
				var shape := SHAPES[shape_index]
				var width := shape.x
				var depth := shape.y
				var lateral_variants := 2 if width == 2 else 1
				for lateral_variant in lateral_variants:
					var footprint := _footprint(walk, walk_to_building,
						width, depth, lateral_variant)
					var threshold := Vector2i(walk.x + walk_to_building.x,
						walk.z + walk_to_building.y)
					# Building bases may sit on any 1.5 m half-level, but inhabited
					# envelopes are complete 3 m storeys followed by one conservative
					# 3 m roof reservation. Roof mass is part of the parcel transaction,
					# never a visual afterthought allowed to intersect its neighbors.
					# The Gaussian core needs a true tall vocabulary; limiting every
					# address to one or two storeys flattened otherwise different route
					# heights onto the same roof datum. Three- and four-storey envelopes
					# remain ordinary complete room stacks; the compiler already supports
					# up to eight.  The warped Gaussian admits the fourth storey only in
					# its genuinely tall interior columns, and the selection grammar still
					# requires every tall result to descend through neighboring complete
					# roofs.  This exposes the envelope's intended centre-weighted skyline
					# instead of compensating for a high route with another two-storey roof
					# at the same absolute datum.
					for storey_value: Variant in [1, 2, 3, 4]:
						var storeys := int(storey_value)
						var envelope_bands: int = storeys \
							* WarrenBuildingParcel.STOREY_BANDS \
							+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
						var parcel := WarrenBuildingParcel.new(
							StringName("parcel.candidate.%04d" % candidate_index),
							footprint, walk.y, walk.y + envelope_bands, walk,
							threshold, frontage)
						candidate_index += 1
						if not parcel.seal(source):
							continue
						if not WarrenParcelConstruction.door_serves_address(parcel):
							continue
						# A nominal one-storey envelope may still descend along its bearing
						# column into a tall terrain-rooted stack. Judge the final proposal,
						# not the abstract parcel. A truly one-storey wide result is always
						# squat; one narrow result remains eligible as a bounded fallback and
						# receives the dedicated chimney roofline.
						if _is_visually_short(parcel) and parcel.width_cells > 1:
							continue
						out.append({
							"parcel": parcel,
							"score": _candidate_score(source, parcel,
								route_index, direction_index, shape_index,
								lateral_variant) - (320.0 if is_auxiliary else 0.0),
							"is_auxiliary": is_auxiliary,
							"is_ground_arcade": is_ground_arcade,
							"is_elevated_gallery": is_elevated_gallery,
							"is_gallery_terminal": is_gallery_terminal,
							"is_ground_primary": is_ground_primary,
						})
	return out


static func _horizontal_candidates(all_variants: Array[Dictionary]) \
		-> Array[Dictionary]:
	## Collapse height variants before footprint packing. Each horizontal slot is
	## represented by its complete two-storey envelope (or the nearest available
	## complete fallback); WarrenParcelHeightSolver later assigns the skyline over
	## the frozen footprint graph. This removes duplicate pair work and prevents
	## a roof-height choice from changing street density.
	var best_by_slot: Dictionary = {}
	for candidate: Dictionary in all_variants:
		var parcel := candidate.parcel as WarrenBuildingParcel
		var footprint_parts := PackedStringArray()
		for column: Vector2i in parcel.footprint:
			footprint_parts.append("%d:%d" % [column.x, column.y])
		footprint_parts.sort()
		var key := "%s/%s" % [_threshold_key(parcel),
			",".join(footprint_parts)]
		var incumbent := best_by_slot.get(key, {}) as Dictionary
		var distance := absi(parcel.storey_count() - 2)
		var incumbent_distance := 2147483647 if incumbent.is_empty() else \
			absi((incumbent.parcel as WarrenBuildingParcel).storey_count() - 2)
		if incumbent.is_empty() or distance < incumbent_distance \
				or (distance == incumbent_distance \
					and String(parcel.stable_id) < String(
						(incumbent.parcel as WarrenBuildingParcel).stable_id)):
			best_by_slot[key] = candidate
	var out: Array[Dictionary] = []
	out.assign(best_by_slot.values())
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String((a.parcel as WarrenBuildingParcel).stable_id) \
			< String((b.parcel as WarrenBuildingParcel).stable_id))
	return out


static func _footprint(walk: Vector3i, walk_to_building: Vector2i,
		width: int, depth: int, lateral_variant: int) -> Array[Vector2i]:
	var perpendicular := Vector2i(-walk_to_building.y, walk_to_building.x)
	var threshold := Vector2i(walk.x, walk.z) + walk_to_building
	var lateral_start := -lateral_variant if width == 2 else 0
	var out: Array[Vector2i] = []
	for depth_offset in depth:
		for width_offset in width:
			out.append(threshold + walk_to_building * depth_offset \
				+ perpendicular * (lateral_start + width_offset))
	return out


static func _candidate_score(source: WarrenVolumePlan,
		parcel: WarrenBuildingParcel, route_index: int, direction_index: int,
		shape_index: int, lateral_variant: int) -> float:
	var radius := Vector2(float(parcel.threshold_column.x),
		float(parcel.threshold_column.y)).length()
	var score := radius * 7.0
	match parcel.storey_count():
		1:
			# A one-storey compact footprint is a last-resort corner closer. Prefer
			# a true townhouse silhouette whenever the bounded packing still fits.
			score += 70.0
		2:
			score -= 52.0
		_:
			score += 10.0
	if parcel.width_cells == 2 and parcel.depth_cells == 3:
		score -= 42.0
	elif parcel.depth_cells >= 3:
		score -= 20.0
	elif parcel.width_cells == 1 and parcel.depth_cells == 1:
		# Compact pitched towers close tight turns, but narrow/deep townhouses
		# remain the preferred ordinary frontage.
		score += 24.0
	elif parcel.width_cells == 2 and parcel.depth_cells == 2:
		score += 18.0
	if parcel.has_occupied_overpass:
		score -= 480.0
	if _is_visually_short(parcel):
		# Retain one deterministic escape hatch for seeds whose measured roof and
		# skywalk envelopes cannot otherwise reach the inhabited-count contract,
		# but never spend it as an ordinary aesthetic preference.
		score += VISUALLY_SHORT_FALLBACK_COST
	if parcel.support_mode == &"mixed_span":
		score -= 45.0
	if parcel.base_band > source.envelope.ground_at(parcel.threshold_column):
		score -= 80.0
	var tie := posmod(_hash(source.world_seed, route_index,
		direction_index * 17 + shape_index * 5 + lateral_variant,
		parcel.threshold_column.x, parcel.threshold_column.y), 1009)
	return score + float(tie) * 0.025


static func _overlaps_occupied(parcel: WarrenBuildingParcel,
		occupied: Dictionary) -> bool:
	for cell: Vector3i in parcel.occupied_cells():
		if occupied.has(cell):
			return true
	return false


static func _forms_half_level_pair(parcel: WarrenBuildingParcel,
		existing: Array[WarrenBuildingParcel]) -> bool:
	for other: WarrenBuildingParcel in existing:
		if absi(parcel.base_band - other.base_band) == 1 \
				and _footprints_neighbor(parcel, other):
			return true
	return false


static func _half_level_neighbor_count(parcel: WarrenBuildingParcel,
		existing: Array[WarrenBuildingParcel]) -> int:
	var result := 0
	for other: WarrenBuildingParcel in existing:
		result += int(absi(parcel.base_band - other.base_band) == 1 \
			and _footprints_neighbor(parcel, other))
	return result


static func _same_base_neighbor_count(parcel: WarrenBuildingParcel,
		existing: Array[WarrenBuildingParcel]) -> int:
	var result := 0
	for other: WarrenBuildingParcel in existing:
		result += int(parcel.base_band == other.base_band \
			and _footprints_neighbor(parcel, other))
	return result


static func _repeated_row_neighbor_count(parcel: WarrenBuildingParcel,
		existing: Array[WarrenBuildingParcel]) -> int:
	var result := 0
	for other: WarrenBuildingParcel in existing:
		result += int(parcel.base_band == other.base_band \
			and parcel.top_band == other.top_band \
			and parcel.width_cells == other.width_cells \
			and parcel.depth_cells == other.depth_cells \
			and parcel.frontage_direction == other.frontage_direction \
			and _footprints_neighbor(parcel, other))
	return result


static func _roof_step_neighbor_count(parcel: WarrenBuildingParcel,
		existing: Array[WarrenBuildingParcel]) -> int:
	var result := 0
	for other: WarrenBuildingParcel in existing:
		var delta := absi(parcel.top_band - other.top_band)
		result += int(delta >= 1 and delta <= 2 \
			and _footprints_neighbor(parcel, other))
	return result


static func _atomic_perpendicular_neighbor_count(
		parcel: WarrenBuildingParcel,
		existing: Array[WarrenBuildingParcel]) -> int:
	var result := 0
	for other: WarrenBuildingParcel in existing:
		result += int(_pair_has_atomic_perpendicular_roof(parcel, other))
	return result


static func _pair_has_atomic_perpendicular_roof(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel) -> bool:
	## Ask the finite roof grammar itself whether this pair is constructible.
	## Re-deriving its legal offsets here would create a second, eventually
	## divergent set of roof special cases in the parcel solver.
	if left == null or right == null or left.top_band != right.top_band \
			or not _footprints_neighbor(left, right):
		return false
	var proposals: Array[Dictionary] = [
		WarrenParcelConstruction.proposal(left),
		WarrenParcelConstruction.proposal(right),
	]
	if proposals[0].is_empty() or proposals[1].is_empty():
		return false
	var topology := FabricRoofTopologyPlan.build(proposals)
	if topology == null or int(topology.audit.get(
			"perpendicular_valley_count", 0)) != 1:
		return false
	return not FabricRoofJunctionModuleTable.build(proposals,
		topology).is_empty()


static func _is_lower_roof_step(parcel: WarrenBuildingParcel,
		existing: Array[WarrenBuildingParcel]) -> bool:
	for other: WarrenBuildingParcel in existing:
		var descent := other.top_band - parcel.top_band
		if descent >= 1 and descent <= 2 \
				and _footprints_neighbor(parcel, other):
			return true
	return false


static func _is_grounded_low_terminal(parcel: WarrenBuildingParcel) -> bool:
	if parcel == null or parcel.source == null:
		return false
	var construction := WarrenParcelConstruction.proposal(parcel)
	return not construction.is_empty() \
		and int(construction.storeys) <= 2 \
		and parcel.base_band == parcel.source.envelope.ground_at(
			parcel.threshold_column)


static func _is_one_storey_tower(parcel: WarrenBuildingParcel) -> bool:
	return parcel.width_cells == 1 and parcel.depth_cells == 1 \
		and parcel.storey_count() == 1


static func _is_one_storey_wide(parcel: WarrenBuildingParcel) -> bool:
	return parcel.width_cells > 1 and parcel.storey_count() == 1


static func _is_visually_short(parcel: WarrenBuildingParcel) -> bool:
	return int(WarrenParcelConstruction.proposal(parcel).storeys) < 2


static func _is_tall_construction(parcel: WarrenBuildingParcel) -> bool:
	## A tall stack may enter the greedy packing only after a complete lower roof
	## neighbor exists. This makes the Gaussian descent constructive: the solver
	## cannot spend a high facade slot on an isolated uniform shaft and merely
	## hope that a compatible lower building is selected later.
	return int(WarrenParcelConstruction.proposal(parcel).storeys) >= 3


static func _best_half_level_pair(candidates: Array[Dictionary],
		pair_compatibility: Callable,
		selected: Array[WarrenBuildingParcel] = [],
		reservation: Dictionary = {},
		reservation_compatibility: Callable = Callable()) \
		-> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var best_score := INF
	for left_index in candidates.size():
		var left_candidate := candidates[left_index]
		if bool(left_candidate.get("is_auxiliary", false)):
			continue
		var left := left_candidate.parcel as WarrenBuildingParcel
		if not _compatible_with_selected(left, selected, pair_compatibility) \
				or not _preserves_reservation(left, reservation,
					reservation_compatibility):
			continue
		for right_index in range(left_index + 1, candidates.size()):
			var right_candidate := candidates[right_index]
			if bool(right_candidate.get("is_auxiliary", false)):
				continue
			var right := right_candidate.parcel as WarrenBuildingParcel
			if absi(left.base_band - right.base_band) != 1 \
					or not _footprints_neighbor(left, right) \
					or _threshold_key(left) == _threshold_key(right) \
					or _parcels_overlap(left, right) \
					or not _pair_is_compatible(left, right,
						pair_compatibility) \
					or not _compatible_with_selected(right, selected,
						pair_compatibility) \
					or not _preserves_reservation(right, reservation,
						reservation_compatibility) \
					or not _pair_respects_height_caps(left, right, selected):
				continue
			var score := float(left_candidate.score) \
				+ float(right_candidate.score)
			# The literal canyon interval belongs to the same inhabited cluster as
			# the occupied bridge endpoints.  Choosing the best opposed facades in
			# isolation placed those two motifs on opposite sides of the envelope;
			# later platform infill then connected the empty middle visually.  Make
			# adjacency part of the motif itself, while the exact pair and roof
			# predicates above remain the geometry authority.
			var cluster_contacts := _footprint_neighbor_count(left, selected) \
				+ _footprint_neighbor_count(right, selected)
			score -= float(cluster_contacts) * 5200.0
			if out.is_empty() or score < best_score:
				out = [left_candidate, right_candidate] as Array[Dictionary]
				best_score = score
	return out


static func _best_opposing_frontage_pair(candidates: Array[Dictionary],
		pair_compatibility: Callable,
		selected: Array[WarrenBuildingParcel], reservation: Dictionary,
		reservation_compatibility: Callable,
		forbidden_walks: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var best_score := INF
	for left_index in candidates.size():
		var left_candidate := candidates[left_index]
		var left := left_candidate.parcel as WarrenBuildingParcel
		if selected.has(left) or _is_visually_short(left) \
				or forbidden_walks.has(left.address_walk_cell) \
				or not _compatible_with_selected(left, selected,
					pair_compatibility) \
				or not _preserves_reservation(left, reservation,
					reservation_compatibility):
			continue
		for right_index in range(left_index + 1, candidates.size()):
			var right_candidate := candidates[right_index]
			var right := right_candidate.parcel as WarrenBuildingParcel
			if selected.has(right) or _is_visually_short(right) \
					or left.address_walk_cell != right.address_walk_cell \
					or left.frontage_direction != -right.frontage_direction \
					or _threshold_key(left) == _threshold_key(right) \
					or _parcels_overlap(left, right) \
					or not _pair_is_compatible(left, right,
						pair_compatibility) \
					or not _compatible_with_selected(right, selected,
						pair_compatibility) \
					or not _preserves_reservation(right, reservation,
						reservation_compatibility) \
					or not _pair_respects_height_caps(left, right, selected):
				continue
			var score := float(left_candidate.score) \
				+ float(right_candidate.score)
			# Prefer the lower climbing itinerary, then its market arcades: enclosing
			# either location blocks the longest eye-level sight lines through the
			# core. Upper galleries already gain enclosure from surrounding mass.
			if bool(left_candidate.get("is_ground_primary", false)):
				score -= 1800.0
			elif bool(left_candidate.get("is_ground_arcade", false)):
				score -= 1200.0
			if out.is_empty() or score < best_score:
				out = [left_candidate, right_candidate] as Array[Dictionary]
				best_score = score
	return out


static func _best_connection_pair(source: WarrenVolumePlan,
		candidates: Array[Dictionary],
		selected: Array[WarrenBuildingParcel], pair_compatibility: Callable,
		connection_pair: Callable,
		reservation_compatibility: Callable,
		connection_broad_phase: Callable) -> Dictionary:
	if not connection_pair.is_valid():
		return {}
	var started := Time.get_ticks_msec()
	var considered_pair_count := 0
	var reservation_pair_count := 0
	var motifs: Array[Dictionary] = []
	for left_index in candidates.size():
		var left_candidate := candidates[left_index]
		if bool(left_candidate.get("is_auxiliary", false)):
			continue
		var left := left_candidate.parcel as WarrenBuildingParcel
		if not _compatible_with_selected(left, selected, pair_compatibility):
			continue
		for right_index in range(left_index + 1, candidates.size()):
			considered_pair_count += 1
			var right_candidate := candidates[right_index]
			if bool(right_candidate.get("is_auxiliary", false)):
				continue
			var right := right_candidate.parcel as WarrenBuildingParcel
			if _threshold_key(left) == _threshold_key(right) \
					or _parcels_overlap(left, right) \
					or not _pair_respects_height_caps(left, right, selected) \
					or not _pair_is_compatible(left, right,
						pair_compatibility):
				continue
			if connection_broad_phase.is_valid() \
					and not bool(connection_broad_phase.call(left, right)):
				continue
			var reservation := connection_pair.call(left, right) as Dictionary
			reservation_pair_count += int(not reservation.is_empty())
			if reservation.is_empty() \
					or not _compatible_with_selected(right, selected,
						pair_compatibility) \
					or not _selected_preserve_reservation(selected, reservation,
						reservation_compatibility):
				continue
			reservation = reservation.duplicate(true)
			reservation["owner_parcel_ids"] = [left.stable_id, right.stable_id]
			motifs.append({
				"candidates": [left_candidate, right_candidate],
				"reservation": reservation,
				"lower_route_cover_count":
					_reservation_lower_route_cover_count(source, reservation),
				"local_score": float(left_candidate.score)
					+ float(right_candidate.score),
			})
	var enumeration_finished := Time.get_ticks_msec()
	if motifs.is_empty():
		last_diagnostic["connection"] = {
			"considered_pairs": considered_pair_count,
			"reservation_pairs": reservation_pair_count,
			"motifs": 0,
			"enumeration_ms": enumeration_finished - started,
			"capacity_ms": 0,
		}
		return {}
	motifs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.local_score), float(b.local_score)):
			return float(a.local_score) < float(b.local_score)
		var a_values := a.candidates as Array
		var b_values := b.candidates as Array
		return _threshold_key((a_values[0] as Dictionary).parcel \
			as WarrenBuildingParcel) < _threshold_key(
			(b_values[0] as Dictionary).parcel as WarrenBuildingParcel))
	for motif_index in motifs.size():
		motifs[motif_index]["local_rank"] = motif_index
	if motifs.size() > CONNECTION_PAIR_FRONTIER:
		motifs.resize(CONNECTION_PAIR_FRONTIER)
	var best: Dictionary = {}
	var no_opposing_motif_count := 0
	var under_capacity_motif_count := 0
	var best_packing_capacity := -1
	var best_unstepped_tall := 2147483647
	var best_ground_primary_two_sided := -1
	var best_ground_primary_bounded := -1
	var best_contact_component := -1
	var best_neighboring_pairs := -1
	var best_composition_penalty := 2147483647
	var best_capacity := -1
	var best_cover_count := -1
	var best_local_score := INF
	var best_rank: Array[float] = []
	var cover_histogram: Dictionary = {}
	var cover_capacity_maximum: Dictionary = {}
	var maximum_contact_component := 0
	var minimum_contact_component_count := 2147483647
	var frontier_compositions: Array[Dictionary] = []
	for motif: Dictionary in motifs:
		var cover_count := int(motif.lower_route_cover_count)
		cover_histogram[cover_count] = int(cover_histogram.get(cover_count, 0)) + 1
		var pair := motif.candidates as Array
		var left := (pair[0] as Dictionary).parcel as WarrenBuildingParcel
		var right := (pair[1] as Dictionary).parcel as WarrenBuildingParcel
		var reservation := motif.reservation as Dictionary
		var pair_selected: Array[WarrenBuildingParcel] = [left, right]
		var opposing_candidates := _best_opposing_frontage_pair(candidates,
			pair_compatibility, pair_selected, reservation,
			reservation_compatibility)
		if opposing_candidates.is_empty():
			no_opposing_motif_count += 1
			continue
		var motif_selected := pair_selected.duplicate()
		for opposing_value: Dictionary in opposing_candidates:
			motif_selected.append(opposing_value.parcel as WarrenBuildingParcel)
		var capacity := _followup_capacity_for_selected(candidates,
			motif_selected, pair_compatibility, reservation,
			reservation_compatibility)
		var packing := _followup_packing(candidates,
			motif_selected, pair_compatibility, reservation,
			reservation_compatibility)
		var packing_capacity := int(packing.count)
		var composition_penalty := int(packing.composition_penalty)
		var unstepped_tall := int((packing.composition as Dictionary).get(
			"unstepped_tall_count", 2147483647))
		var ground_primary_two_sided := int((packing.composition as Dictionary).get(
			"ground_primary_two_sided_count", 0))
		var ground_primary_bounded := int((packing.composition as Dictionary).get(
			"ground_primary_bounded_count", 0))
		var contact_component := int((packing.composition as Dictionary).get(
			"largest_contact_component_count", 0))
		var neighboring_pairs := int((packing.composition as Dictionary).get(
			"neighboring_pair_count", 0))
		maximum_contact_component = maxi(maximum_contact_component, int(
			(packing.composition as Dictionary).get(
				"largest_contact_component_count", 0)))
		minimum_contact_component_count = mini(minimum_contact_component_count,
			int((packing.composition as Dictionary).get(
				"contact_component_count", 2147483647)))
		motif["opposing_candidates"] = opposing_candidates
		motif["packing_capacity"] = packing_capacity
		motif["packing_composition"] = packing.composition
		motif["composition_penalty"] = composition_penalty
		motif["packing_followup_candidates"] = packing.candidates
		frontier_compositions.append({
			"local_rank": int(motif.local_rank),
			"lower_route_cover_count": cover_count,
			"packing_capacity": packing_capacity,
			"composition_penalty": composition_penalty,
			"composition": (packing.composition as Dictionary).duplicate(true),
		})
		cover_capacity_maximum[cover_count] = maxi(int(
			cover_capacity_maximum.get(cover_count, 0)), capacity)
		var local_score := float(motif.local_score)
		if packing_capacity < MIN_PARCELS:
			under_capacity_motif_count += 1
			continue
		# The dry skyline count is only a proxy: the exact vertical solver may repair
		# it after all height variants are visible. Preserve the physical contact
		# graph first because no later stage can reconnect detached footprints, then
		# prefer its more feasible skyline and better negative-space street walls.
		var rank: Array[float] = [-float(contact_component),
			float(unstepped_tall), -float(ground_primary_two_sided),
			-float(ground_primary_bounded), -float(cover_count),
			-float(neighboring_pairs), float(composition_penalty),
			-float(packing_capacity), -float(capacity), local_score]
		if best.is_empty() or _numeric_rank_less(rank, best_rank):
			best = motif
			best_rank = rank
			best_packing_capacity = packing_capacity
			best_unstepped_tall = unstepped_tall
			best_ground_primary_two_sided = ground_primary_two_sided
			best_ground_primary_bounded = ground_primary_bounded
			best_contact_component = contact_component
			best_neighboring_pairs = neighboring_pairs
			best_composition_penalty = composition_penalty
			best_capacity = capacity
			best_cover_count = cover_count
			best_local_score = local_score
	if best.is_empty():
		# Motifs existed but every one died in the followup gates; without this
		# record the failure reads as "no pair" when pairs were plentiful.
		last_diagnostic["connection"] = {
			"considered_pairs": considered_pair_count,
			"reservation_pairs": reservation_pair_count,
			"motifs": motifs.size(),
			"no_opposing_motif_count": no_opposing_motif_count,
			"under_capacity_motif_count": under_capacity_motif_count,
			"enumeration_ms": enumeration_finished - started,
			"capacity_ms": Time.get_ticks_msec() - enumeration_finished,
		}
		return {}
	last_diagnostic["connection"] = {
		"considered_pairs": considered_pair_count,
		"reservation_pairs": reservation_pair_count,
		"motifs": motifs.size(),
		"chosen_local_rank": int(best.get("local_rank", -1)),
		"chosen_candidate_ids": PackedStringArray([
			String(((best.candidates as Array)[0] as Dictionary).parcel.stable_id),
			String(((best.candidates as Array)[1] as Dictionary).parcel.stable_id),
		]),
		"chosen_lower_route_cover_count": int(
			best.get("lower_route_cover_count", 0)),
		"chosen_packing_capacity": int(best.get("packing_capacity", -1)),
		"chosen_packing_composition": best.get("packing_composition", {}),
		"chosen_ground_primary_two_sided_count":
			best_ground_primary_two_sided,
		"chosen_ground_primary_bounded_count": best_ground_primary_bounded,
		"frontier_maximum_contact_component": maximum_contact_component,
		"frontier_minimum_contact_component_count":
			minimum_contact_component_count,
		"frontier_compositions": frontier_compositions,
		"lower_route_cover_histogram": cover_histogram,
		"lower_route_cover_capacity_maximum": cover_capacity_maximum,
		"enumeration_ms": enumeration_finished - started,
		"capacity_ms": Time.get_ticks_msec() - enumeration_finished,
	}
	return {
		"candidates": best.candidates,
		"reservation": best.reservation,
		"opposing_candidates": best.opposing_candidates,
		"packing_followup_candidates": best.packing_followup_candidates,
	}


static func _numeric_rank_less(left: Array[float], right: Array[float]) -> bool:
	if right.is_empty():
		return true
	for index in mini(left.size(), right.size()):
		if not is_equal_approx(left[index], right[index]):
			return left[index] < right[index]
	return left.size() < right.size()


static func _best_additional_connection_reservation(source: WarrenVolumePlan,
		selected: Array[WarrenBuildingParcel], reservations: Array[Dictionary],
		connection_pair: Callable, reservation_compatibility: Callable,
		connection_broad_phase: Callable) -> Dictionary:
	if not connection_pair.is_valid() or selected.size() < 4:
		return {}
	var used_owners: Dictionary = {}
	for reservation: Dictionary in reservations:
		for owner_value: Variant in reservation.get("owner_parcel_ids", []):
			used_owners[StringName(owner_value)] = true
	var best: Dictionary = {}
	var best_cover := -1
	var best_size := 2147483647
	for left_index in selected.size():
		var left := selected[left_index]
		if used_owners.has(left.stable_id):
			continue
		for right_index in range(left_index + 1, selected.size()):
			var right := selected[right_index]
			if used_owners.has(right.stable_id) \
					or (connection_broad_phase.is_valid() and not bool(
						connection_broad_phase.call(left, right))):
				continue
			var reservation := connection_pair.call(left, right) as Dictionary
			if reservation.is_empty() \
					or not _reservation_is_independent(reservation, reservations):
				continue
			var preserved := true
			for parcel: WarrenBuildingParcel in selected:
				if parcel == left or parcel == right:
					continue
				if reservation_compatibility.is_valid() and not bool(
						reservation_compatibility.call(parcel, reservation)):
					preserved = false
					break
			if not preserved:
				continue
			var cover := _reservation_lower_route_cover_count(source, reservation)
			var size := (reservation.get("reserved_cells", {}) as Dictionary).size()
			if best.is_empty() or cover > best_cover \
					or (cover == best_cover and size < best_size):
				best = reservation.duplicate(true)
				best["owner_parcel_ids"] = [left.stable_id, right.stable_id]
				best_cover = cover
				best_size = size
	return best


static func _rebind_reservation_owners(reservation: Dictionary,
		selected: Array[WarrenBuildingParcel]) -> bool:
	if reservation.is_empty():
		return true
	var owner_ids := PackedStringArray()
	for value: Variant in reservation.get("owner_endpoints", []):
		var endpoint := value as Dictionary
		var wanted := String(endpoint.get("slot_signature", ""))
		var matched: WarrenBuildingParcel = null
		for parcel: WarrenBuildingParcel in selected:
			if parcel.slot_signature() == wanted:
				matched = parcel
				break
		if matched == null:
			return false
		owner_ids.append(String(matched.stable_id))
	reservation["owner_parcel_ids"] = owner_ids
	return owner_ids.size() == 2


static func _reservation_is_independent(candidate: Dictionary,
		existing: Array[Dictionary]) -> bool:
	var candidate_cells := candidate.get("reserved_cells", {}) as Dictionary
	var candidate_bounds: Array[AABB] = []
	candidate_bounds.assign(candidate.get("visual_bounds", []) as Array)
	for reservation: Dictionary in existing:
		var cells := reservation.get("reserved_cells", {}) as Dictionary
		for cell_value: Variant in candidate_cells.keys():
			if cells.has(cell_value):
				return false
		for candidate_box: AABB in candidate_bounds:
			for box_value: Variant in reservation.get("visual_bounds", []):
				if SettlementFabricPlan._aabb_overlaps_volume(candidate_box,
						box_value as AABB):
					return false
	return true


static func _reservation_key(reservation: Dictionary) -> String:
	var components := PackedStringArray()
	for component: Dictionary in reservation.get("components", []) as Array:
		components.append("%s@%s/r%d" % [StringName(component.get(
			"recipe_id", "")), component.get("origin", Vector3i()),
			int(component.get("yaw_quarters", -1))])
	components.sort()
	return ",".join(components)


static func _reservation_lower_route_cover_count(source: WarrenVolumePlan,
		reservation: Dictionary) -> int:
	var covered: Dictionary = {}
	var cells := reservation.get("reserved_cells", {}) as Dictionary
	for route_cell: Vector3i in source.primary_itinerary:
		if route_cell.y != source.envelope.ground_at(
				Vector2i(route_cell.x, route_cell.z)):
			continue
		for cell_value: Variant in cells.keys():
			var cell := cell_value as Vector3i
			if cell.x == route_cell.x and cell.z == route_cell.z \
					and cell.y >= route_cell.y + 2:
				covered[route_cell] = true
				break
	return covered.size()


static func _followup_capacity_for_selected(candidates: Array[Dictionary],
		selected: Array[WarrenBuildingParcel], pair_compatibility: Callable,
		reservation: Dictionary,
		reservation_compatibility: Callable) -> int:
	var result := 0
	for candidate: Dictionary in candidates:
		var parcel := candidate.parcel as WarrenBuildingParcel
		if selected.has(parcel) or _is_visually_short(parcel) \
				or not _compatible_with_selected(parcel, selected,
					pair_compatibility) \
				or not _preserves_reservation(parcel, reservation,
					reservation_compatibility):
			continue
		var conflicts := false
		for existing: WarrenBuildingParcel in selected:
			if _threshold_key(parcel) == _threshold_key(existing) \
					or _parcels_overlap(parcel, existing):
				conflicts = true
				break
		if conflicts:
			continue
		result += 9 if bool(candidate.get("is_ground_primary", false)) \
			else 5 if bool(candidate.get("is_ground_arcade", false)) \
			else 3 if bool(candidate.get("is_elevated_gallery", false)) \
			else 1
	return result


static func _followup_packing(candidates: Array[Dictionary],
		seed: Array[WarrenBuildingParcel], pair_compatibility: Callable,
		reservation: Dictionary,
		reservation_compatibility: Callable) -> Dictionary:
	## Bounded conflict-graph packing used only to rank mandatory motif choices.
	## Raw compatible-candidate counts badly overvalue dozens of mutually
	## exclusive roof envelopes at one doorway.  This dry run admits complete
	## parcels under the same caps and measured pair contracts as the real
	## transaction, choosing the least-destructive remaining envelope each turn.
	## It never creates a plan and therefore cannot diverge from the authoritative
	## packing or repair it afterward.
	var selected := seed.duplicate()
	var additions: Array[Dictionary] = []
	var occupied: Dictionary = {}
	var thresholds: Dictionary = {}
	var tower_count := 0
	var slim_count := 0
	var one_storey_tower_count := 0
	var one_storey_wide_count := 0
	var visually_short_count := 0
	var family_counts: Dictionary = {}
	var base_counts: Dictionary = {}
	var roof_counts: Dictionary = {}
	var address_counts: Dictionary = {}
	for parcel: WarrenBuildingParcel in selected:
		thresholds[_threshold_key(parcel)] = true
		tower_count += int(parcel.width_cells == 1 and parcel.depth_cells == 1)
		slim_count += int(parcel.width_cells == 1 and parcel.depth_cells == 2)
		one_storey_tower_count += int(_is_one_storey_tower(parcel))
		one_storey_wide_count += int(_is_one_storey_wide(parcel))
		visually_short_count += int(_is_visually_short(parcel))
		var family := _shape_key(parcel)
		family_counts[family] = int(family_counts.get(family, 0)) + 1
		base_counts[parcel.base_band] = int(base_counts.get(parcel.base_band, 0)) + 1
		roof_counts[parcel.top_band] = int(roof_counts.get(parcel.top_band, 0)) + 1
		address_counts[parcel.address_walk_cell] = int(address_counts.get(
			parcel.address_walk_cell, 0)) + 1
		for cell: Vector3i in parcel.occupied_cells():
			occupied[cell] = true
	while selected.size() < MAX_PARCELS:
		var viable: Array[Dictionary] = []
		for candidate: Dictionary in candidates:
			var parcel := candidate.parcel as WarrenBuildingParcel
			if selected.has(parcel) or thresholds.has(_threshold_key(parcel)) \
					or (parcel.width_cells == 1 and parcel.depth_cells == 1 \
						and tower_count >= MAX_TOWER_PARCELS) \
					or (parcel.width_cells == 1 and parcel.depth_cells == 2 \
						and slim_count >= MAX_SLIM_PARCELS) \
					or (_is_one_storey_tower(parcel) \
						and one_storey_tower_count >= MAX_ONE_STOREY_TOWERS) \
					or (_is_one_storey_wide(parcel) \
						and one_storey_wide_count >= MAX_ONE_STOREY_WIDE_BUILDINGS) \
					or (_is_visually_short(parcel) \
						and visually_short_count >= MAX_VISUALLY_SHORT_BUILDINGS) \
					or (_is_tall_construction(parcel) \
						and _roof_step_neighbor_count(parcel, selected) == 0) \
					or _overlaps_occupied(parcel, occupied) \
					or not _compatible_with_selected(parcel, selected,
						pair_compatibility) \
					or not _preserves_reservation(parcel, reservation,
						reservation_compatibility):
				continue
			viable.append(candidate)
		if viable.is_empty():
			break
		var best_candidate: Dictionary = {}
		var best_score := INF
		var conflict_cache: Dictionary = {}
		for candidate: Dictionary in viable:
			var parcel := candidate.parcel as WarrenBuildingParcel
			var blocking := _selection_blocking_count(parcel, viable,
				pair_compatibility, conflict_cache)
			var trial := selected.duplicate()
			trial.append(parcel)
			var family := _shape_key(parcel)
			var projected_family_count := int(family_counts.get(family, 0)) + 1
			var projected_base_count := int(base_counts.get(parcel.base_band, 0)) + 1
			var projected_roof_count := int(roof_counts.get(parcel.top_band, 0)) + 1
			var existing_address_count := int(address_counts.get(
				parcel.address_walk_cell, 0))
			var footprint_neighbors := _footprint_neighbor_count(parcel, selected)
			var atomic_roof_neighbors := _atomic_perpendicular_neighbor_count(
				parcel, selected)
			# Capacity remains the first-order dry-packing objective, but candidates
			# with equal destructive power must build a roof-step chain rather than a
			# barracks row.  These are geometric terms only; facade and roof colours are
			# deliberately absent.
			var score := float(blocking) * 10000.0 + float(candidate.score) \
				+ float(_unstepped_tall_composition_count(trial)) * 6500.0 \
				+ float(_repeated_row_pair_count(trial)) * 5200.0 \
				+ float(_same_base_neighbor_count(parcel, selected)) * 700.0 \
				+ float(maxi(0, projected_family_count - 3)) * 1400.0 \
				+ float(maxi(0, projected_base_count \
					- ceili(float(trial.size()) * 0.45))) * 5200.0 \
				+ float(maxi(0, projected_roof_count \
					- ceili(float(trial.size()) * 0.50))) * 3200.0
			if not family_counts.has(family):
				score -= 900.0
			if not base_counts.has(parcel.base_band):
				score -= 1300.0
			if not roof_counts.has(parcel.top_band):
				score -= 900.0
			# The route is negative space only when its edge cells acquire opposed
			# building walls. Once one real facade addresses a walk square, completing
			# its other side outranks another isolated perimeter address.
			if existing_address_count == 1:
				score -= 7200.0
			# Contiguous building mass is what turns paths into negative-space
			# canyons and gives the roof junction grammar real work to do. Detached
			# compatible plots are capacity, not composition.  This reward is larger
			# than one ordinary conflict because a ten-building proof with seven
			# isolated components was exactly the broad-plaza failure found by the
			# adversarial cameras; a motif which cannot retain ten buildings after
			# choosing the cluster simply loses on packing capacity below.
			score -= float(footprint_neighbors) * 11500.0
			score -= float(mini(atomic_roof_neighbors, 2)) * 3800.0
			score -= float(_roof_step_neighbor_count(parcel, selected)) * 1800.0
			score -= float(_half_level_neighbor_count(parcel, selected)) * 900.0
			if best_candidate.is_empty() or score < best_score:
				best_candidate = candidate
				best_score = score
		var chosen := best_candidate.parcel as WarrenBuildingParcel
		selected.append(chosen)
		additions.append(best_candidate)
		thresholds[_threshold_key(chosen)] = true
		tower_count += int(chosen.width_cells == 1 and chosen.depth_cells == 1)
		slim_count += int(chosen.width_cells == 1 and chosen.depth_cells == 2)
		one_storey_tower_count += int(_is_one_storey_tower(chosen))
		one_storey_wide_count += int(_is_one_storey_wide(chosen))
		visually_short_count += int(_is_visually_short(chosen))
		var chosen_family := _shape_key(chosen)
		family_counts[chosen_family] = int(family_counts.get(
			chosen_family, 0)) + 1
		base_counts[chosen.base_band] = int(base_counts.get(
			chosen.base_band, 0)) + 1
		roof_counts[chosen.top_band] = int(roof_counts.get(
			chosen.top_band, 0)) + 1
		address_counts[chosen.address_walk_cell] = int(address_counts.get(
			chosen.address_walk_cell, 0)) + 1
		for cell: Vector3i in chosen.occupied_cells():
			occupied[cell] = true
		if selected.size() >= TARGET_PACKED_PARCELS:
			break
	var composition := _packing_composition(selected)
	return {"count": selected.size(), "candidates": additions,
		"composition": composition,
		"composition_penalty": _packing_composition_penalty(composition)}


static func _packing_composition(
		parcels: Array[WarrenBuildingParcel]) -> Dictionary:
	var family_counts: Dictionary = {}
	var base_counts: Dictionary = {}
	var roof_counts: Dictionary = {}
	var stepped_pairs := 0
	var half_level_pairs := 0
	var neighboring_pairs := 0
	var atomic_perpendicular_pairs := 0
	var occupied_overpass_count := 0
	var address_directions: Dictionary = {}
	var occupied_cells: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		var family := _shape_key(parcel)
		family_counts[family] = int(family_counts.get(family, 0)) + 1
		base_counts[parcel.base_band] = int(base_counts.get(parcel.base_band, 0)) + 1
		roof_counts[parcel.top_band] = int(roof_counts.get(parcel.top_band, 0)) + 1
		occupied_overpass_count += int(parcel.has_occupied_overpass)
		if not address_directions.has(parcel.address_walk_cell):
			address_directions[parcel.address_walk_cell] = {} as Dictionary
		(address_directions[parcel.address_walk_cell] as Dictionary)[
			parcel.frontage_direction] = true
		for cell: Vector3i in parcel.occupied_cells():
			occupied_cells[cell] = true
	for left_index in parcels.size():
		for right_index in range(left_index + 1, parcels.size()):
			var left := parcels[left_index]
			var right := parcels[right_index]
			if not _footprints_neighbor(left, right):
				continue
			neighboring_pairs += 1
			atomic_perpendicular_pairs += int(
				_pair_has_atomic_perpendicular_roof(left, right))
			var base_delta := absi(left.base_band - right.base_band)
			var roof_delta := absi(left.top_band - right.top_band)
			half_level_pairs += int(base_delta == 1)
			stepped_pairs += int(roof_delta >= 1 and roof_delta <= 2)
	var opposed_address_count := 0
	for direction_value: Variant in address_directions.values():
		var directions := direction_value as Dictionary
		for direction_value_key: Variant in directions.keys():
			var direction := direction_value_key as Vector2i
			if directions.has(-direction):
				opposed_address_count += 1
				break
	var contact_components := _packing_contact_components(parcels)
	var route_enclosure := _packing_route_enclosure(parcels[0].source,
		occupied_cells) if not parcels.is_empty() else {}
	var largest_contact_component_count := 0
	for component: Array in contact_components:
		largest_contact_component_count = maxi(
			largest_contact_component_count, component.size())
	var compact_count := int(family_counts.get("1:1", 0)) \
		+ int(family_counts.get("1:2", 0))
	return {
		"unstepped_tall_count": _unstepped_tall_composition_count(parcels),
		"repeated_row_pair_count": _repeated_row_pair_count(parcels),
		"family_count": family_counts.size(),
		"largest_family_count": _largest_dictionary_count(family_counts),
		"compact_parcel_count": compact_count,
		"base_band_count": base_counts.size(),
		"largest_base_count": _largest_dictionary_count(base_counts),
		"roof_band_count": roof_counts.size(),
		"largest_roof_count": _largest_dictionary_count(roof_counts),
		"half_level_pair_count": half_level_pairs,
		"stepped_roof_pair_count": stepped_pairs,
		"neighboring_pair_count": neighboring_pairs,
		"atomic_perpendicular_roof_pair_count": atomic_perpendicular_pairs,
		"contact_component_count": contact_components.size(),
		"largest_contact_component_count": largest_contact_component_count,
		"opposed_address_count": opposed_address_count,
		"occupied_overpass_count": occupied_overpass_count,
		"ground_primary_bounded_count": int(route_enclosure.get(
			"ground_primary_bounded_count", 0)),
		"ground_primary_two_sided_count": int(route_enclosure.get(
			"ground_primary_two_sided_count", 0)),
		"ground_arcade_bounded_count": int(route_enclosure.get(
			"ground_arcade_bounded_count", 0)),
	}


static func _packing_route_enclosure(source: WarrenVolumePlan,
		occupied_cells: Dictionary) -> Dictionary:
	if source == null:
		return {}
	var primary: Dictionary = {}
	for cell: Vector3i in source.primary_itinerary:
		primary[cell] = true
	var arcade: Dictionary = {}
	for cell: Vector3i in source.ground_arcade_cells:
		arcade[cell] = true
	var ground_primary_bounded := 0
	var ground_primary_two_sided := 0
	var ground_arcade_bounded := 0
	for walk: Vector3i in source.walk_cells:
		var sides := 0
		for direction: Vector2i in DIRECTIONS:
			sides += int(occupied_cells.has(Vector3i(walk.x + direction.x,
				walk.y, walk.z + direction.y)))
		if primary.has(walk) and walk.y == source.envelope.ground_at(
				Vector2i(walk.x, walk.z)):
			ground_primary_bounded += int(sides >= 1)
			ground_primary_two_sided += int(sides >= 2)
		elif arcade.has(walk):
			ground_arcade_bounded += int(sides >= 1)
	return {
		"ground_primary_bounded_count": ground_primary_bounded,
		"ground_primary_two_sided_count": ground_primary_two_sided,
		"ground_arcade_bounded_count": ground_arcade_bounded,
	}


static func _packing_composition_penalty(composition: Dictionary) -> int:
	## Lexicographic quality encoded with non-overlapping integer ranges.  One
	## unresolved tall shaft is categorically worse than a horizontal alternative.
	## Contact comes next because this stage owns footprints: the height solver can
	## (and does) turn a provisional same-height neighbor into a stepped roof, but
	## it cannot reconnect a detached footprint graph.  Treating the provisional
	## two-storey graph as the final skyline made one apparent row cost more than
	## adding a sixth house to the central mass, violating the stage boundary.
	## Repetition still matters, but only after the topology which can eliminate it
	## vertically has been preserved.
	return int(composition.unstepped_tall_count) * 1000000 \
		+ maxi(0, 7 - int(composition.largest_contact_component_count)) \
			* 160000 \
		+ maxi(0, int(composition.contact_component_count) - 3) * 20000 \
		+ maxi(0, 4 - int(composition.occupied_overpass_count)) * 30000 \
		+ maxi(0, 2 - int(composition.ground_primary_two_sided_count)) * 80000 \
		+ maxi(0, 4 - int(composition.ground_primary_bounded_count)) * 30000 \
		+ int(composition.repeated_row_pair_count) * 100000 \
		+ maxi(0, 4 - int(composition.family_count)) * 10000 \
		+ maxi(0, 4 - int(composition.neighboring_pair_count)) * 12000 \
		+ maxi(0, 1 - int(composition.atomic_perpendicular_roof_pair_count)) \
			* 9000 \
		+ maxi(0, int(composition.largest_family_count) - 3) * 2000 \
		+ maxi(0, int(composition.largest_base_count) - 4) * 20000 \
		+ maxi(0, 3 - int(composition.base_band_count)) * 6000 \
		+ maxi(0, int(composition.largest_roof_count) - 5) * 5000 \
		+ maxi(0, 3 - int(composition.roof_band_count)) * 2000 \
		+ maxi(0, 2 - int(composition.opposed_address_count)) * 100 \
		+ maxi(0, 2 - int(composition.stepped_roof_pair_count)) * 20 \
		+ maxi(0, 1 - int(composition.half_level_pair_count))


static func _packing_contact_components(
		parcels: Array[WarrenBuildingParcel]) -> Array[Array]:
	var neighbors: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		neighbors[parcel.stable_id] = [] as Array[StringName]
	for left_index in parcels.size():
		var left := parcels[left_index]
		for right_index in range(left_index + 1, parcels.size()):
			var right := parcels[right_index]
			if not _footprints_neighbor(left, right):
				continue
			(neighbors[left.stable_id] as Array[StringName]).append(
				right.stable_id)
			(neighbors[right.stable_id] as Array[StringName]).append(
				left.stable_id)
	var components: Array[Array] = []
	var visited: Dictionary = {}
	var ids: Array[StringName] = []
	ids.assign(neighbors.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for start: StringName in ids:
		if visited.has(start):
			continue
		var component: Array[StringName] = []
		var frontier: Array[StringName] = [start]
		while not frontier.is_empty():
			var current: StringName = frontier.pop_back()
			if visited.has(current):
				continue
			visited[current] = true
			component.append(current)
			for neighbor: StringName in neighbors[current]:
				if not visited.has(neighbor):
					frontier.append(neighbor)
		components.append(component)
	return components


static func _largest_dictionary_count(counts: Dictionary) -> int:
	var result := 0
	for value: Variant in counts.values():
		result = maxi(result, int(value))
	return result


static func _repeated_row_pair_count(
		parcels: Array[WarrenBuildingParcel]) -> int:
	var result := 0
	for left_index in parcels.size():
		var left := parcels[left_index]
		for right_index in range(left_index + 1, parcels.size()):
			var right := parcels[right_index]
			result += int(left.base_band == right.base_band \
				and left.top_band == right.top_band \
				and left.width_cells == right.width_cells \
				and left.depth_cells == right.depth_cells \
				and left.frontage_direction == right.frontage_direction \
				and _footprints_neighbor(left, right))
	return result


static func _footprint_neighbor_count(parcel: WarrenBuildingParcel,
		existing: Array[WarrenBuildingParcel]) -> int:
	var result := 0
	for other: WarrenBuildingParcel in existing:
		result += int(_footprints_neighbor(parcel, other))
	return result


static func _unstepped_tall_composition_count(
		parcels: Array[WarrenBuildingParcel]) -> int:
	var downhill: Dictionary = {}
	var terminals: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		downhill[parcel.stable_id] = [] as Array[StringName]
		var storeys := int(WarrenParcelConstruction.proposal(parcel).get(
			"storeys", 0))
		if storeys <= 2 and parcel.source != null \
				and parcel.base_band == parcel.source.envelope.ground_at(
					parcel.threshold_column):
			terminals[parcel.stable_id] = true
	for left_index in parcels.size():
		var left := parcels[left_index]
		for right_index in range(left_index + 1, parcels.size()):
			var right := parcels[right_index]
			if not _footprints_neighbor(left, right):
				continue
			var delta := left.top_band - right.top_band
			if absi(delta) < 1 or absi(delta) > 2:
				continue
			var higher := left if delta > 0 else right
			var lower := right if delta > 0 else left
			(downhill[higher.stable_id] as Array[StringName]).append(
				lower.stable_id)
	var unresolved := 0
	for parcel: WarrenBuildingParcel in parcels:
		if int(WarrenParcelConstruction.proposal(parcel).get("storeys", 0)) >= 3:
			unresolved += int(not _reaches_composition_terminal(parcel.stable_id,
				downhill, terminals))
	return unresolved


static func _reaches_composition_terminal(start: StringName,
		downhill: Dictionary, terminals: Dictionary) -> bool:
	var pending: Array[StringName] = [start]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current: StringName = pending.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		if terminals.has(current):
			return true
		for next_value: StringName in downhill.get(current, []):
			pending.append(next_value)
	return false


static func _walk_transition_degree(source: WarrenVolumePlan,
		walk: Vector3i) -> int:
	var result := 0
	for transition: WarrenVolumeTransition in source.transitions:
		result += int(transition.from_cell == walk or transition.to_cell == walk)
	return result


static func _selection_blocking_count(candidate: WarrenBuildingParcel,
		viable_candidates: Array[Dictionary], pair_compatibility: Callable,
		conflict_cache: Dictionary) -> int:
	var result := 0
	for other_value: Dictionary in viable_candidates:
		var other := other_value.parcel as WarrenBuildingParcel
		if other == candidate:
			continue
		var pair_key := _parcel_pair_key(other, candidate)
		if not conflict_cache.has(pair_key):
			conflict_cache[pair_key] = _threshold_key(other) \
				== _threshold_key(candidate) \
				or _parcels_overlap(other, candidate) \
				or not _pair_is_compatible(other, candidate,
					pair_compatibility)
		if bool(conflict_cache[pair_key]):
			result += 1
	return result


static func _pair_respects_height_caps(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel,
		selected: Array[WarrenBuildingParcel]) -> bool:
	var total_tower_count := int(left.width_cells == 1 and left.depth_cells == 1) \
		+ int(right.width_cells == 1 and right.depth_cells == 1)
	var slim_count := int(left.width_cells == 1 and left.depth_cells == 2) \
		+ int(right.width_cells == 1 and right.depth_cells == 2)
	var tower_count := int(_is_one_storey_tower(left)) \
		+ int(_is_one_storey_tower(right))
	var wide_count := int(_is_one_storey_wide(left)) \
		+ int(_is_one_storey_wide(right))
	var visually_short_count := int(_is_visually_short(left)) \
		+ int(_is_visually_short(right))
	for parcel: WarrenBuildingParcel in selected:
		total_tower_count += int(parcel.width_cells == 1 \
			and parcel.depth_cells == 1)
		slim_count += int(parcel.width_cells == 1 and parcel.depth_cells == 2)
		tower_count += int(_is_one_storey_tower(parcel))
		wide_count += int(_is_one_storey_wide(parcel))
		visually_short_count += int(_is_visually_short(parcel))
	return total_tower_count <= MAX_TOWER_PARCELS \
		and slim_count <= MAX_SLIM_PARCELS \
		and tower_count <= MAX_ONE_STOREY_TOWERS \
		and wide_count <= MAX_ONE_STOREY_WIDE_BUILDINGS \
		and visually_short_count <= MAX_VISUALLY_SHORT_BUILDINGS


static func _selected_preserve_reservation(
		selected: Array[WarrenBuildingParcel], reservation: Dictionary,
		reservation_compatibility: Callable) -> bool:
	for parcel: WarrenBuildingParcel in selected:
		if not _preserves_reservation(parcel, reservation,
				reservation_compatibility):
			return false
	return true


static func _preserves_reservation(parcel: WarrenBuildingParcel,
		reservation: Dictionary,
		reservation_compatibility: Callable) -> bool:
	return true if reservation.is_empty() \
		or not reservation_compatibility.is_valid() else bool(
			reservation_compatibility.call(parcel, reservation))


static func _compatible_with_selected(parcel: WarrenBuildingParcel,
		selected: Array[WarrenBuildingParcel],
		pair_compatibility: Callable) -> bool:
	if not pair_compatibility.is_valid():
		return true
	for other: WarrenBuildingParcel in selected:
		if not _pair_is_compatible(parcel, other, pair_compatibility):
			return false
	return true


static func _pair_is_compatible(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel, pair_compatibility: Callable) -> bool:
	return true if not pair_compatibility.is_valid() else bool(
		pair_compatibility.call(left, right))


static func _parcels_overlap(a: WarrenBuildingParcel,
		b: WarrenBuildingParcel) -> bool:
	var occupied: Dictionary = {}
	for cell: Vector3i in a.occupied_cells():
		occupied[cell] = true
	return _overlaps_occupied(b, occupied)


static func _footprints_neighbor(a: WarrenBuildingParcel,
		b: WarrenBuildingParcel) -> bool:
	var b_columns: Dictionary = {}
	for column: Vector2i in b.footprint:
		b_columns[column] = true
	for column: Vector2i in a.footprint:
		for direction: Vector2i in DIRECTIONS:
			if b_columns.has(column + direction):
				return true
	return false


static func _threshold_key(parcel: WarrenBuildingParcel) -> String:
	return "%d:%d:%d/%d:%d" % [parcel.address_walk_cell.x,
		parcel.address_walk_cell.y, parcel.address_walk_cell.z,
		parcel.frontage_direction.x, parcel.frontage_direction.y]


static func _shape_key(parcel: WarrenBuildingParcel) -> String:
	return "%d:%d" % [parcel.width_cells, parcel.depth_cells]


static func _parcel_pair_key(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel) -> String:
	var left_id := String(left.stable_id)
	var right_id := String(right.stable_id)
	return "%s|%s" % [left_id, right_id] if left_id < right_id \
		else "%s|%s" % [right_id, left_id]


static func _candidate_short_count(candidates: Array[Dictionary]) -> int:
	var result := 0
	for candidate: Dictionary in candidates:
		result += int(_is_visually_short(
			candidate.parcel as WarrenBuildingParcel))
	return result


static func _selection_signature(
		parcels: Array[WarrenBuildingParcel]) -> String:
	var parts := PackedStringArray()
	for parcel: WarrenBuildingParcel in parcels:
		parts.append(parcel.deterministic_signature())
	parts.sort()
	return "|".join(parts)


static func _hash(seed_value: int, route_index: int, salt: int,
		x: int, z: int) -> int:
	var value := seed_value * 1103515245 + route_index * 214013 \
		+ salt * 12345
	value = value ^ (x * 73856093) ^ (z * 19349663)
	value = value ^ (value >> 13)
	return posmod(value, 2147483629)

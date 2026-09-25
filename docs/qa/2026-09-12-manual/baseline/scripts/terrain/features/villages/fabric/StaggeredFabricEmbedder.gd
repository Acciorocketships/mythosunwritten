class_name StaggeredFabricEmbedder
extends RefCounted

## Deterministic bounded beam search for the first coupled solid/void step.
## It places conservative complete-building envelopes directly from unsatisfied
## public-boundary obligations. Each envelope includes a furnished room stack
## and its roof, so the search cannot accept a facade that later becomes an
## unroofed shell. A proposal is useful only when its occupied volume closes the
## requested route side without entering claimed exterior air or existing mass.
const ROOM_MINIMUM := Vector3i(-2, 0, -2)
const MARKET_MINIMUM := Vector3i(-2, 0, -1)
const MARKET_SIZE := Vector3i(4, 3, 2)
const TOWER_MINIMUM := Vector3i(-1, 0, -1)
const TOWER_FOOTPRINT_SIZE := Vector3i(2, 1, 2)
## The smallest authored pitched roof spans 6 m. A square 3 m semantic plot
## therefore rendered as a 6.7-by-3.5 m sideways house. Make the infill a real
## narrow/deep 3-by-6 m plot so search occupancy, walls, roof, and collision all
## share the proportions visible to the player.
const MICRO_MINIMUM := Vector3i(-1, 0, -2)
const MICRO_FOOTPRINT_SIZE := Vector3i(2, 1, 4)
const SLIM_MINIMUM := Vector3i(-1, 0, -2)
const SLIM_FOOTPRINT_SIZE := Vector3i(2, 1, 4)
const DEFAULT_BEAM_WIDTH := 24
const DEFAULT_BUILDING_BUDGET := 28
const MAX_BRANCHING_PER_STATE := 48


static func solve(stable_id: StringName, solid_void: FabricSolidVoidPlan,
		exterior_air: Dictionary, structural_solids: Dictionary,
		inhabited_volume: Dictionary, beam_width: int = DEFAULT_BEAM_WIDTH,
		building_budget: int = DEFAULT_BUILDING_BUDGET,
		program: SettlementFabricProgram = null,
		reserved_visual_bounds: Array[AABB] = [],
		allow_markets: bool = true) \
		-> StaggeredFabricEmbeddingPlan:
	var frontier := solve_frontier(stable_id, solid_void, exterior_air,
		structural_solids, inhabited_volume, beam_width, building_budget,
		program, reserved_visual_bounds, allow_markets, 1)
	return null if frontier.is_empty() \
		else frontier[0] as StaggeredFabricEmbeddingPlan


static func solve_frontier(stable_id: StringName,
		solid_void: FabricSolidVoidPlan, exterior_air: Dictionary,
		structural_solids: Dictionary, inhabited_volume: Dictionary,
		beam_width: int = DEFAULT_BEAM_WIDTH,
		building_budget: int = DEFAULT_BUILDING_BUDGET,
		program: SettlementFabricProgram = null,
		reserved_visual_bounds: Array[AABB] = [], allow_markets: bool = true,
		result_limit: int = 8,
		search_strategy: StringName = &"global_set",
		world_seed: int = 0,
		market_zone_cells: Dictionary = {},
		priority_address_cells: Dictionary = {},
		required_market_count: int = 0,
		required_skywalk_pair_count: int = 0) \
		-> Array[StaggeredFabricEmbeddingPlan]:
	var results: Array[StaggeredFabricEmbeddingPlan] = []
	if stable_id.is_empty() or solid_void == null or not solid_void.is_sealed() \
			or exterior_air.is_empty() or beam_width <= 0 or building_budget <= 0 \
			or result_limit <= 0 \
			or (search_strategy != &"global_set" \
				and search_strategy != &"frontage_order"):
		return results
	var reserved: Dictionary = {}
	for source: Dictionary in [structural_solids, inhabited_volume]:
		for cell_value: Variant in source:
			reserved[cell_value as Vector3i] = true
	var initial_state := {
		"proposals": [] as Array[Dictionary],
		"occupied": {} as Dictionary,
		"reserved_visual_bounds": reserved_visual_bounds.duplicate(),
		"visual_spans": [] as Array[Dictionary],
		"covered": {} as Dictionary,
		"score": 0.0,
		"selected_library": {} as Dictionary,
		"skywalk_endpoints": [] as Array[Dictionary],
		"skywalk_pair_count": 0,
		"priority_address_count": 0,
		"market_count": 0,
		"skywalk_blocked": exterior_air.duplicate(),
	}
	for blocked_cell_value: Variant in reserved:
		(initial_state.skywalk_blocked as Dictionary)[
			blocked_cell_value as Vector3i] = true
	var library: Array[Dictionary] = []
	if search_strategy == &"global_set":
		library = _candidate_library(solid_void, exterior_air, reserved,
			initial_state, program, allow_markets, world_seed, market_zone_cells,
			priority_address_cells)
		if OS.get_environment("WARREN_EMBED_DEBUG") == "1":
			var kind_counts: Dictionary = {}
			for candidate: Dictionary in library:
				var kind := StringName(candidate.kind)
				kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
			print("[warren-embed] library=%d kinds=%s market-zone=%d" % [
				library.size(), kind_counts, market_zone_cells.size()])
			for candidate: Dictionary in library:
				if StringName(candidate.kind) == &"market":
					print("[warren-embed] market origin=%s yaw=%d family=%d" % [
						candidate.origin, int(candidate.yaw_quarters),
						int(candidate.market_family)])
		if library.is_empty():
			return results
	var beam: Array[Dictionary] = [initial_state]
	for _iteration in building_budget:
		var expanded: Array[Dictionary] = []
		for state: Dictionary in beam:
			var additions := _next_library_additions(state, library,
				required_skywalk_pair_count) \
				if search_strategy == &"global_set" \
				else _next_additions(state, solid_void, exterior_air, reserved,
					program, allow_markets)
			if additions.is_empty():
				expanded.append(state)
				continue
			for addition: Dictionary in additions:
				var origin := addition.origin as Vector3i
				var cells := addition.occupied_cells as Array[Vector3i]
				var visual_bounds := addition.visual_bounds as Array[AABB]
				var newly_covered := addition.covered_indices as Dictionary \
					if addition.has("covered_indices") \
					else _covered_obligations(cells,
						solid_void.unbounded_obligations)
				expanded.append(_extend_state(state, origin, cells, visual_bounds,
					newly_covered, solid_void.unbounded_obligations.size(),
					int(addition.storeys), int(addition.yaw_quarters),
					int(addition.route_y), StringName(addition.kind),
					int(addition.get("library_index", -1)),
					int(addition.get("market_family", -1)),
					bool(addition.get("priority_address", false))))
		if expanded.is_empty():
			break
		expanded.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _state_better_with_requirements(a, b,
				required_market_count, required_skywalk_pair_count))
		beam.clear()
		var seen_states: Dictionary = {}
		for state: Dictionary in expanded:
			var state_key := _state_signature(state)
			if seen_states.has(state_key):
				continue
			seen_states[state_key] = true
			beam.append(state)
			if beam.size() >= beam_width:
				break
		if _next_uncovered_index(beam[0].covered as Dictionary,
				solid_void.unbounded_obligations.size()) < 0:
			break
	if beam.is_empty():
		return results
	beam.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _state_better_with_requirements(a, b,
			required_market_count, required_skywalk_pair_count))
	if OS.get_environment("WARREN_EMBED_DEBUG") == "1":
		_debug_rejections(beam[0] as Dictionary, solid_void, exterior_air,
			reserved, program,
			allow_markets)
	var initial_bounded := solid_void.boundary_obligations.size() \
		- solid_void.unbounded_obligations.size()
	for index in mini(result_limit, beam.size()):
		var state := beam[index] as Dictionary
		var candidate_id := stable_id if index == 0 \
			else StringName("%s/candidate.%02d" % [stable_id, index])
		var result := StaggeredFabricEmbeddingPlan.new(candidate_id)
		if result.seal(state.proposals as Array[Dictionary],
				state.covered as Dictionary, solid_void.unbounded_obligations.size(),
				initial_bounded, solid_void.boundary_obligations.size()):
			result.potential_skywalk_pair_count = int(state.skywalk_pair_count)
			results.append(result)
	return results


static func _candidate_library(solid_void: FabricSolidVoidPlan,
		exterior_air: Dictionary, reserved: Dictionary, initial_state: Dictionary,
		program: SettlementFabricProgram, allow_markets: bool,
		world_seed: int, market_zone_cells: Dictionary,
		priority_address_cells: Dictionary) -> Array[Dictionary]:
	## Candidate geometry is independent of search order. Compile and statically
	## qualify it once, then let the bounded search solve a set-packing problem.
	## The former first-open-obligation traversal could commit a legal house that
	## made a much larger later frontage impossible, even though the reverse
	## composition was valid. That was an algorithmic ordering artefact, not a
	## property of the town grammar.
	# Neighboring boundary obligations propose many of the exact same plots.  A
	# candidate's room stack, roof envelopes, and complete boundary coverage are
	# properties of that plot—not of the obligation that happened to discover it.
	# Deduplicate the cheap identities before doing any geometric work.  The old
	# order expanded and intersected the same four-storey house dozens of times
	# and made this pure search two orders of magnitude slower than the complete
	# structural transaction which follows it.
	var raw_by_signature: Dictionary = {}
	for index in solid_void.unbounded_obligations.size():
		var obligation := solid_void.unbounded_obligations[index] as Dictionary
		# Standalone inhabited masses are square. Shallow rectangular geometry is
		# reserved for roofed outcroppings attached to an existing room.
		var kinds: Array[StringName] = [&"building", &"tower"]
		# Elevated folds need a narrow/deep inhabited stack. A 6 m square room
		# cannot fit beside many stair turns, while a flat 3 m tower has neither the
		# requested house proportions nor a pitched roof.
		if int(obligation.surface_cell.y) >= 2:
			kinds.append(&"slim")
		# A one-storey micro house has no lower mass that can carry it. It is a
		# useful ground/half-rise infill, but on an upper route it degenerates into
		# exactly the isolated house-on-a-rock-column composition this grammar is
		# meant to make impossible.
		if int(obligation.surface_cell.y) <= 1:
			kinds.append(&"micro")
		if allow_markets and int(obligation.surface_cell.y) == 0 \
				and (market_zone_cells.is_empty() \
					or market_zone_cells.has(obligation.surface_cell as Vector3i)):
			kinds.append(&"market")
		for kind: StringName in kinds:
			for candidate: Dictionary in _candidate_origins(obligation, kind):
				var variants: Array[Dictionary] = [candidate]
				if kind == &"market":
					variants.clear()
					for family: int in SettlementFabricProgram.MARKET_STALLS.size():
						var variant := candidate.duplicate()
						variant["market_family"] = family
						variants.append(variant)
				for variant: Dictionary in variants:
					var origin := variant.origin as Vector3i
					var signature := "%s/%d/%d/%d/%d/%d/v%d" % [kind,
						origin.x, origin.y, origin.z, int(variant.storeys),
						int(variant.yaw_quarters),
						int(variant.get("market_family", -1))]
					if raw_by_signature.has(signature):
						var existing := raw_by_signature[signature] as Dictionary
						var source_indices := existing.source_indices as Dictionary
						source_indices[index] = true
						continue
					variant["signature"] = signature
					variant["source_indices"] = {index: true}
					raw_by_signature[signature] = variant
	var out: Array[Dictionary] = []
	var signatures := PackedStringArray()
	for signature_value: Variant in raw_by_signature:
		signatures.append(String(signature_value))
	signatures.sort()
	var no_dynamic_occupancy: Dictionary = {}
	for signature: String in signatures:
		var candidate := raw_by_signature[signature] as Dictionary
		var origin := candidate.origin as Vector3i
		var kind := StringName(candidate.kind)
		var storeys := int(candidate.storeys)
		var route_y := int(candidate.route_y)
		var yaw := int(candidate.yaw_quarters)
		var cells := _occupied_cells(origin, storeys, yaw, kind)
		if _intersects(cells, exterior_air, reserved, no_dynamic_occupancy):
			continue
		var visual_bounds := _proposal_visual_bounds(candidate, program)
		if not visual_bounds.is_empty() and _visual_intersects(visual_bounds,
				initial_state.reserved_visual_bounds as Array[AABB]):
			continue
		if _requires_address(kind):
			var address_landing := _address_landing(origin, route_y, yaw, kind)
			if not _has_addressed_storey(origin, storeys, route_y) \
					or not solid_void.has_surface_cell(address_landing):
				continue
			candidate["priority_address"] = priority_address_cells.has(
				address_landing)
		var boundary_cells := _proposal_boundary_cells(candidate, program)
		var covered := _covered_obligations(boundary_cells,
			solid_void.unbounded_obligations)
		var covers_discovering_obligation := false
		for source_index_value: Variant in candidate.source_indices as Dictionary:
			if covered.has(int(source_index_value)):
				covers_discovering_obligation = true
				break
		if not covers_discovering_obligation:
			continue
		candidate.erase("source_indices")
		# A seed only changes the order among already qualified construction
		# candidates. Geometry and every hard gate remain seed-independent.
		candidate["seed_rank"] = 0 if world_seed == 0 else _seeded_hash(
			String(candidate.signature), world_seed)
		candidate["occupied_cells"] = cells
		candidate["boundary_cells"] = boundary_cells
		candidate["visual_bounds"] = visual_bounds
		candidate["visual_footprint_area"] = _visual_footprint_area(visual_bounds)
		candidate["covered_indices"] = covered
		out.append(candidate)
	out.sort_custom(_library_candidate_less)
	for index in out.size():
		out[index]["library_index"] = index
	return out


static func _next_library_additions(state: Dictionary,
		library: Array[Dictionary], required_skywalk_pair_count: int = 0) \
		-> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var state_occupied := state.occupied as Dictionary
	var covered := state.covered as Dictionary
	var spans := state.visual_spans as Array[Dictionary]
	var selected := state.selected_library as Dictionary
	var market_count := 0
	for proposal: Dictionary in state.proposals as Array[Dictionary]:
		market_count += int(StringName(proposal.kind) == &"market")
	for index in library.size():
		if selected.has(index):
			continue
		var candidate := library[index]
		# Slim infill exists to close the pockets left by the primary massing. It
		# must not crowd the beam before two ordinary stacks establish the required
		# inhabited skywalk opportunity; exact overhead geometry remains the final
		# authority once that topology-preserving prefix exists.
		if StringName(candidate.kind) == &"slim" \
				and int(state.get("skywalk_pair_count", 0)) \
				< maxi(0, required_skywalk_pair_count):
			continue
		if market_count >= 4 and StringName(candidate.kind) == &"market":
			continue
		var new_count := 0
		for covered_index_value: Variant in candidate.covered_indices:
			if not covered.has(int(covered_index_value)):
				new_count += 1
		if new_count == 0 or _intersects_dynamic(
				candidate.occupied_cells as Array[Vector3i], state_occupied) \
				or _intersects_unrelated_visual_span(candidate,
					candidate.visual_bounds as Array[AABB], spans):
			continue
		var ranked := candidate.duplicate()
		ranked["new_coverage_count"] = new_count
		out.append(ranked)
	# The branch cap is a performance bound, not a license to erase a required
	# vocabulary. High-coverage room stacks otherwise fill all 48 slots before a
	# shallower market frontage is ever considered, making the two-stall contract
	# depend on incidental dictionary density. Until the alley owns two stalls,
	# rank qualified market branches first; exact overlap, enclosure, and final
	# transaction checks still decide whether they survive.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if market_count < 2:
			var a_market := StringName(a.kind) == &"market"
			var b_market := StringName(b.kind) == &"market"
			if a_market != b_market:
				return a_market
		return _dynamic_candidate_less(a, b))
	if out.size() > MAX_BRANCHING_PER_STATE:
		out.resize(MAX_BRANCHING_PER_STATE)
	return out


static func _library_candidate_less(a: Dictionary, b: Dictionary) -> bool:
	var a_coverage := (a.covered_indices as Dictionary).size()
	var b_coverage := (b.covered_indices as Dictionary).size()
	if a_coverage != b_coverage:
		return a_coverage > b_coverage
	var a_volume := (a.occupied_cells as Array).size()
	var b_volume := (b.occupied_cells as Array).size()
	if a_volume != b_volume:
		return a_volume < b_volume
	if not is_equal_approx(float(a.visual_footprint_area),
			float(b.visual_footprint_area)):
		return float(a.visual_footprint_area) < float(b.visual_footprint_area)
	if int(a.seed_rank) != int(b.seed_rank):
		return int(a.seed_rank) < int(b.seed_rank)
	return String(a.signature) < String(b.signature)


static func _dynamic_candidate_less(a: Dictionary, b: Dictionary) -> bool:
	if int(a.new_coverage_count) != int(b.new_coverage_count):
		return int(a.new_coverage_count) > int(b.new_coverage_count)
	return int(a.library_index) < int(b.library_index)


static func _intersects_dynamic(cells: Array[Vector3i],
		state_occupied: Dictionary) -> bool:
	for cell: Vector3i in cells:
		if state_occupied.has(cell):
			return true
	return false


static func _debug_rejections(state: Dictionary,
		solid_void: FabricSolidVoidPlan, exterior_air: Dictionary,
		reserved: Dictionary, program: SettlementFabricProgram,
		allow_markets: bool) -> void:
	var totals := {"candidate": 0, "route_air": 0, "seed_mass": 0,
		"proposal_mass": 0, "volume": 0, "visual": 0,
		"address": 0, "coverage": 0, "qualified": 0}
	var open_obligations := 0
	for index in solid_void.unbounded_obligations.size():
		if (state.covered as Dictionary).has(index):
			continue
		open_obligations += 1
		var obligation := solid_void.unbounded_obligations[index] as Dictionary
		var kinds: Array[StringName] = [&"building", &"tower"]
		if int(obligation.surface_cell.y) >= 2:
			kinds.append(&"slim")
		if int(obligation.surface_cell.y) <= 1:
			kinds.append(&"micro")
		if allow_markets and int(obligation.surface_cell.y) == 0:
			kinds.append(&"market")
		for kind: StringName in kinds:
			for candidate: Dictionary in _candidate_origins(obligation, kind):
				totals.candidate = int(totals.candidate) + 1
				var cells := _occupied_cells(candidate.origin as Vector3i,
					int(candidate.storeys), int(candidate.yaw_quarters), kind)
				if _intersects(cells, exterior_air, reserved,
						state.occupied as Dictionary):
					totals.volume = int(totals.volume) + 1
					var hit_air := false
					var hit_seed := false
					var hit_proposal := false
					for cell: Vector3i in cells:
						hit_air = hit_air or exterior_air.has(cell)
						hit_seed = hit_seed or reserved.has(cell)
						hit_proposal = hit_proposal or (state.occupied as Dictionary).has(cell)
					totals.route_air = int(totals.route_air) + int(hit_air)
					totals.seed_mass = int(totals.seed_mass) + int(hit_seed)
					totals.proposal_mass = int(totals.proposal_mass) + int(hit_proposal)
					continue
				var visual_bounds := _proposal_visual_bounds(candidate, program)
				if not visual_bounds.is_empty() and (_visual_intersects(visual_bounds,
						state.reserved_visual_bounds as Array[AABB]) \
						or _intersects_unrelated_visual_span(candidate, visual_bounds,
							state.visual_spans as Array[Dictionary])):
					totals.visual = int(totals.visual) + 1
					continue
				if _requires_address(kind) and (not _has_addressed_storey(
						candidate.origin as Vector3i, int(candidate.storeys),
						int(candidate.route_y)) or not solid_void.has_surface_cell(
						_address_landing(candidate.origin as Vector3i,
							int(candidate.route_y), int(candidate.yaw_quarters), kind))):
					totals.address = int(totals.address) + 1
					continue
				var boundary_cells := _proposal_boundary_cells(candidate, program)
				if not _covered_obligations(boundary_cells,
						solid_void.unbounded_obligations).has(index):
					totals.coverage = int(totals.coverage) + 1
					continue
				totals.qualified = int(totals.qualified) + 1
	print("[warren-embed-debug] proposals=%d covered=%d open=%d rejection=%s" % [
		(state.proposals as Array).size(), (state.covered as Dictionary).size(),
		open_obligations, totals])


static func _next_additions(state: Dictionary,
		solid_void: FabricSolidVoidPlan, exterior_air: Dictionary,
		reserved: Dictionary, program: SettlementFabricProgram,
		allow_markets: bool) -> Array[Dictionary]:
	## An impossible early obligation must not stop the whole bounded search.
	## Find the first still-open boundary that has at least one complete-building
	## candidate, preserving deterministic obligation order.
	for index in solid_void.unbounded_obligations.size():
		if (state.covered as Dictionary).has(index):
			continue
		var obligation := solid_void.unbounded_obligations[index] as Dictionary
		var additions := _qualified_additions(obligation, &"building", index,
			solid_void, exterior_air, reserved, state, program)
		additions.append_array(_qualified_additions(obligation, &"tower", index,
			solid_void, exterior_air, reserved, state, program))
		if int(obligation.surface_cell.y) >= 2:
			additions.append_array(_qualified_additions(obligation, &"slim", index,
				solid_void, exterior_air, reserved, state, program))
		if int(obligation.surface_cell.y) <= 1:
			additions.append_array(_qualified_additions(obligation, &"micro", index,
				solid_void, exterior_air, reserved, state, program))
		if allow_markets and int(obligation.surface_cell.y) == 0:
			additions.append_array(_qualified_additions(obligation, &"market", index,
				solid_void, exterior_air, reserved, state, program))
		if not additions.is_empty():
			return additions
	return []


static func _qualified_additions(obligation: Dictionary, kind: StringName,
		obligation_index: int, solid_void: FabricSolidVoidPlan,
		exterior_air: Dictionary, reserved: Dictionary,
		state: Dictionary, program: SettlementFabricProgram) -> Array[Dictionary]:
	var additions: Array[Dictionary] = []
	for candidate: Dictionary in _candidate_origins(obligation, kind):
		var origin := candidate.origin as Vector3i
		var storeys := int(candidate.storeys)
		var route_y := int(candidate.route_y)
		var cells := _occupied_cells(origin, storeys,
			int(candidate.yaw_quarters), kind)
		if _intersects(cells, exterior_air, reserved,
				state.occupied as Dictionary):
			continue
		var visual_bounds := _proposal_visual_bounds(candidate, program)
		if not visual_bounds.is_empty():
			if _visual_intersects(visual_bounds,
					state.reserved_visual_bounds as Array[AABB]) \
					or _intersects_unrelated_visual_span(candidate, visual_bounds,
						state.visual_spans as Array[Dictionary]):
				continue
		var boundary_cells := _proposal_boundary_cells(candidate, program)
		var covered := _covered_obligations(boundary_cells,
			solid_void.unbounded_obligations)
		if not covered.has(obligation_index):
			continue
		if _requires_address(kind) and (not _has_addressed_storey(origin,
				storeys, route_y) or not solid_void.has_surface_cell(
				_address_landing(origin, route_y,
					int(candidate.yaw_quarters), kind))):
			continue
		candidate["occupied_cells"] = cells
		candidate["boundary_cells"] = boundary_cells
		candidate["visual_bounds"] = visual_bounds
		additions.append(candidate)
	return additions


static func _requires_address(kind: StringName) -> bool:
	return kind == &"building" or kind == &"tower" \
		or kind == &"slim" or kind == &"micro"


static func _has_addressed_storey(origin: Vector3i, storeys: int,
		route_y: int) -> bool:
	var delta := route_y - origin.y
	return delta >= 0 and delta % 2 == 0 and delta / 2 < storeys


static func _address_landing(origin: Vector3i, route_y: int,
		yaw_quarters: int, kind: StringName) -> Vector3i:
	# Addressed modular rooms place their threshold at (-1, 0, 1) and face
	# local +Z. The required landing is therefore (-1, 0, 2), transformed at
	# the actual addressed storey's route elevation.
	var local_landing := Vector3i(0, 0, 1) if kind == &"tower" \
		else Vector3i(0, 0, 2) if kind == &"micro" or kind == &"slim" \
		else Vector3i(-1, 0, 2)
	return FabricRecipe.transform_cell(local_landing,
		Vector3i(origin.x, route_y, origin.z), yaw_quarters)


static func _candidate_origins(obligation: Dictionary,
		kind: StringName) -> Array[Dictionary]:
	var surface := obligation.surface_cell as Vector3i
	var side := obligation.side as Vector3i
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	var yaw := _yaw_toward_route(side)
	var minimum := MARKET_MINIMUM if kind == &"market" \
		else TOWER_MINIMUM if kind == &"tower" \
		else SLIM_MINIMUM if kind == &"slim" \
		else MICRO_MINIMUM if kind == &"micro" else ROOM_MINIMUM
	var size := MARKET_SIZE if kind == &"market" \
		else TOWER_FOOTPRINT_SIZE if kind == &"tower" \
		else SLIM_FOOTPRINT_SIZE if kind == &"slim" \
		else MICRO_FOOTPRINT_SIZE if kind == &"micro" else Vector3i(4, 1, 4)
	var footprint := _rotated_footprint_bounds(yaw, minimum, size)
	# Sliding the four-cell facade along the route lets one building close
	# several neighboring obligations. Building bases are not sampled merely
	# around the current route datum: an upper alley should commonly be the
	# third-floor address of a house rooted several bands below it. Constraining
	# every inhabited candidate to an exact floor/threshold datum makes tall
	# ground-rooted masses bind multiple route levels, while odd route bands
	# naturally select half-raised bases. This avoids manufacturing a field of
	# unrelated short houses on high stone plinths.
	for tangent_offset in [-1, 0, -2, 1]:
		var xz_origin := Vector3i(surface.x, 0, surface.z)
		if side.x < 0:
			xz_origin.x = surface.x - 1 - int(footprint.max_x)
			xz_origin.z = surface.z - int(footprint.center_z) + tangent_offset
		elif side.x > 0:
			xz_origin.x = surface.x + 1 - int(footprint.min_x)
			xz_origin.z = surface.z - int(footprint.center_z) + tangent_offset
		elif side.z < 0:
			xz_origin.z = surface.z - 1 - int(footprint.max_z)
			xz_origin.x = surface.x - int(footprint.center_x) + tangent_offset
		else:
			xz_origin.z = surface.z + 1 - int(footprint.min_z)
			xz_origin.x = surface.x - int(footprint.center_x) + tangent_offset
		var base_ys: Array[int] = []
		var storey_options: Array[int] = []
		if kind == &"market":
			base_ys.append(surface.y)
			storey_options.append(0)
		elif kind == &"micro":
			base_ys.append(surface.y)
			storey_options.append(1)
		elif kind == &"building" or kind == &"tower" or kind == &"slim":
			# One storey spans two lattice cells. The deepest legal four-storey
			# candidate can therefore address a route six cells above its base.
			# Keep the parity of the route datum so one of its real floor planes,
			# rather than an arbitrary wall band, always owns the address.
			# Root the mass at the lowest parity-compatible datum (ground or one
			# retained half-rise). Every addressed upper alley is therefore another
			# floor of a building which already occupies the town below. Sampling all
			# higher legal bases created unsupported rock needles and made verticality
			# synonymous with stilts. True high terrain perches are a separate
			# production opportunity and require a surveyed TerrainSurfaceField.
			var lowest_addressable_base := posmod(surface.y, 2)
			if surface.y - lowest_addressable_base <= 6:
				base_ys.append(lowest_addressable_base)
		for base_y in base_ys:
			var minimum_storeys := 0 if kind == &"market" else 1
			if kind == &"building" or kind == &"tower" or kind == &"slim":
				minimum_storeys = (surface.y - base_y) / 2 + 1
				storey_options.clear()
				for storeys in range(minimum_storeys, 5):
					storey_options.append(storeys)
			for storeys in storey_options:
				var origin := Vector3i(xz_origin.x, base_y, xz_origin.z)
				var key := "%s/%d" % [_cell_key(origin), storeys]
				if seen.has(key):
					continue
				seen[key] = true
				out.append({
					"kind": kind,
					"origin": origin,
					"storeys": storeys,
					"yaw_quarters": yaw,
					"route_y": surface.y,
				})
	return out


static func _occupied_cells(origin: Vector3i, storeys: int,
		yaw_quarters: int, kind: StringName) -> Array[Vector3i]:
	return StaggeredFabricCompiler.proposal_occupied_cells({
		"origin": origin,
		"storeys": storeys,
		"yaw_quarters": yaw_quarters,
		"kind": kind,
	})


static func _intersects(cells: Array[Vector3i], exterior_air: Dictionary,
		reserved: Dictionary, state_occupied: Dictionary) -> bool:
	for cell: Vector3i in cells:
		if exterior_air.has(cell) or reserved.has(cell) \
				or state_occupied.has(cell):
			return true
	return false


static func _proposal_visual_bounds(proposal: Dictionary,
		program: SettlementFabricProgram) -> Array[AABB]:
	var out: Array[AABB] = []
	if program == null:
		return out
	for component: Dictionary in StaggeredFabricCompiler.proposal_components(
			proposal):
		var recipe_value := program.recipe(StringName(component.recipe_id))
		if recipe_value == null or recipe_value.placements.is_empty():
			continue
		var origin := component.origin as Vector3i
		var yaw := int(component.yaw_quarters)
		var transform := Transform3D(Basis(Vector3.UP,
			float(posmod(yaw, 4)) * PI * 0.5), Vector3(origin) * FabricRecipe.CELL_SIZE)
		out.append(transform * recipe_value.local_clearance_bounds)
	return out


static func _proposal_boundary_cells(proposal: Dictionary,
		program: SettlementFabricProgram) -> Array[Vector3i]:
	## Frontage is an eye-level semantic fact, not a side effect of the broad
	## collision envelope used by set packing. Expand the exact same recipes the
	## final compiler will emit and transform their authored occluder cells. This
	## prevents a hollow footprint, roof volume, or private headroom cell from
	## being scored as a street wall that does not exist in the rendered town.
	var out: Array[Vector3i] = []
	if program == null:
		return out
	var seen: Dictionary = {}
	for component: Dictionary in StaggeredFabricCompiler.proposal_components(
			proposal):
		var recipe_value := program.recipe(StringName(component.recipe_id))
		if recipe_value == null:
			continue
		var origin := component.origin as Vector3i
		var yaw := int(component.yaw_quarters)
		for local_cell: Vector3i in recipe_value.occluder_cells:
			var cell := FabricRecipe.transform_cell(local_cell, origin, yaw)
			if not seen.has(cell):
				seen[cell] = true
				out.append(cell)
	return out


static func _visual_intersects(candidate_bounds: Array[AABB],
		existing_bounds: Array[AABB]) -> bool:
	for candidate: AABB in candidate_bounds:
		for existing: AABB in existing_bounds:
			var overlap_x := minf(candidate.end.x, existing.end.x) \
				- maxf(candidate.position.x, existing.position.x)
			var overlap_y := minf(candidate.end.y, existing.end.y) \
				- maxf(candidate.position.y, existing.position.y)
			var overlap_z := minf(candidate.end.z, existing.end.z) \
				- maxf(candidate.position.z, existing.position.z)
			if overlap_x > 0.10 and overlap_y > 0.10 and overlap_z > 0.10:
				return true
	return false


static func _visual_footprint_area(bounds: Array[AABB]) -> float:
	## The exact envelope already exists for qualification; use its union broad
	## phase to prefer compact authored variants when two plots close the same
	## frontage. This prevents a 7 m tent from winning over a 5 m stocked stall
	## merely because its recipe id sorts first.
	if bounds.is_empty():
		return 0.0
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for value: AABB in bounds:
		minimum = minimum.min(Vector2(value.position.x, value.position.z))
		maximum = maximum.max(Vector2(value.end.x, value.end.z))
	var size := maximum - minimum
	return maxf(0.0, size.x) * maxf(0.0, size.y)


static func _covered_obligations(cells: Array[Vector3i],
		obligations: Array[Dictionary]) -> Dictionary:
	var occupied: Dictionary = {}
	for cell: Vector3i in cells:
		occupied[cell] = true
	var out: Dictionary = {}
	for index in obligations.size():
		var obligation := obligations[index] as Dictionary
		var neighbor := (obligation.surface_cell as Vector3i) \
			+ (obligation.side as Vector3i)
		if occupied.has(neighbor) or occupied.has(neighbor + Vector3i.UP):
			out[index] = true
	return out


static func _extend_state(state: Dictionary, origin: Vector3i,
		cells: Array[Vector3i], candidate_visual_bounds: Array[AABB],
		newly_covered: Dictionary,
		obligation_count: int, storeys: int, yaw_quarters: int,
		route_y: int, kind: StringName,
		library_index: int, market_family: int = -1,
		priority_address: bool = false) -> Dictionary:
	var proposals: Array[Dictionary] = []
	for proposal: Dictionary in state.proposals as Array[Dictionary]:
		proposals.append(proposal)
	var proposal_suffix := ".v%02d" % market_family if kind == &"market" else ""
	var accepted_proposal := {
		"stable_id": StringName("%s.%d.%d.%d.s%d.r%d%s" % [kind, origin.x,
			origin.y, origin.z, storeys, yaw_quarters, proposal_suffix]),
		"kind": kind,
		"origin": origin,
		"storeys": storeys,
		"yaw_quarters": yaw_quarters,
		"route_y": route_y,
		"support_mode": &"grounded_stack" if origin.y == 0 \
			else &"retained_half_perch",
		"occupied_cells": cells,
	}
	if kind == &"market":
		accepted_proposal["market_family"] = market_family
	proposals.append(accepted_proposal)
	var existing_endpoints: Array[Dictionary] = []
	existing_endpoints.assign(state.skywalk_endpoints as Array)
	var new_endpoints := _proposal_skywalk_endpoints(accepted_proposal)
	existing_endpoints.append_array(new_endpoints)
	var occupied := (state.occupied as Dictionary).duplicate()
	var skywalk_blocked := (state.skywalk_blocked as Dictionary).duplicate()
	for cell: Vector3i in cells:
		occupied[cell] = true
		skywalk_blocked[cell] = true
	# Count only opposing facade pairs whose entire deck/headroom corridor remains
	# clear of public air, the prefab/market seed, and every already-selected mass.
	# Exact recipes remain authoritative, but the beam no longer preserves pairs
	# already proved impossible by its own lattice facts.
	var skywalk_pair_count := _greedy_skywalk_pair_count(existing_endpoints,
		skywalk_blocked)
	var visual_spans: Array[Dictionary] = []
	for span: Dictionary in state.visual_spans as Array[Dictionary]:
		visual_spans.append(span)
	visual_spans.append({
		"proposal": proposals.back(),
		"bounds": candidate_visual_bounds,
	})
	var covered := (state.covered as Dictionary).duplicate()
	for index_value: Variant in newly_covered:
		covered[int(index_value)] = true
	var selected_library := (state.selected_library as Dictionary).duplicate()
	if library_index >= 0:
		selected_library[library_index] = true
	var bands: Dictionary = {}
	var storey_counts: Dictionary = {}
	var market_count := 0
	var market_families: Dictionary = {}
	var priority_address_count := int(state.get("priority_address_count", 0)) \
		+ int(priority_address)
	var full_building_count := 0
	var tower_count := 0
	var micro_count := 0
	var half_level_pairs := 0
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for proposal: Dictionary in proposals:
		var proposal_origin := proposal.origin as Vector3i
		bands[proposal_origin.y] = true
		if StringName(proposal.kind) == &"market":
			market_count += 1
			market_families[int(proposal.get("market_family",
				StaggeredFabricCompiler.market_family(proposal_origin)))] = true
		else:
			storey_counts[int(proposal.storeys)] = true
			if StringName(proposal.kind) == &"building":
				full_building_count += 1
			elif StringName(proposal.kind) == &"tower":
				tower_count += 1
			elif StringName(proposal.kind) == &"slim":
				full_building_count += 1
			else:
				micro_count += 1
		for cell: Vector3i in proposal.occupied_cells as Array[Vector3i]:
			minimum.x = mini(minimum.x, cell.x)
			minimum.y = mini(minimum.y, cell.z)
			maximum.x = maxi(maximum.x, cell.x)
			maximum.y = maxi(maximum.y, cell.z)
	for first_band_value: Variant in bands:
		if bands.has(int(first_band_value) + 1):
			half_level_pairs += 1
	var area := maxi(1, maximum.x - minimum.x + 1) \
		* maxi(1, maximum.y - minimum.y + 1)
	var remaining := obligation_count - covered.size()
	# Two occupied market frontages are part of the warren's ground-level
	# construction grammar. Weight the first pair strongly enough that the beam
	# does not discard them in favour of one more interchangeable wall stack,
	# then retain the softer diversity reward for additional stalls.
	var market_score := float(mini(market_count, 2)) * 64.0 \
		+ float(maxi(0, mini(market_count, 4) - 2)) * 12.0 \
		+ float(mini(market_families.size(), 2)) * 40.0 \
		+ float(maxi(0, mini(market_families.size(), 4) - 2)) * 8.0
	# The exact overhead transaction remains authoritative, but the massing beam
	# should not discard every facade pair that could possibly carry a skywalk.
	# Reward the first opposing co-level pair strongly, then taper quickly so a
	# town is never contorted merely to maximize speculative bridges.
	var skywalk_score := 34.0 if skywalk_pair_count > 0 else 0.0
	# A second independent pair establishes a network rather than a single visual
	# accent. Later pairs taper because exact occupancy and route coverage still
	# decide whether any candidate is constructible.
	skywalk_score += 18.0 if skywalk_pair_count > 1 else 0.0
	skywalk_score += float(maxi(0, mini(skywalk_pair_count, 5) - 2)) * 6.0
	var score := float(covered.size()) * 100.0 \
		- float(proposals.size()) * 7.0 - float(area) * 0.08 \
		+ float(bands.size()) * 4.0 + float(half_level_pairs) * 7.0 \
		+ float(storey_counts.size()) * 2.0 \
		+ float(mini(full_building_count, 6)) * 5.0 \
		+ market_score + skywalk_score \
		+ float(mini(priority_address_count, 1)) * 180.0 \
		+ float(mini(tower_count, 6)) * 3.0 \
		+ (4.0 if tower_count > 0 and full_building_count > 0 else 0.0) \
		+ float(mini(micro_count, 4)) * 2.0 \
		- float(remaining) * 2.0
	return {
		"proposals": proposals,
		"occupied": occupied,
		"reserved_visual_bounds": state.reserved_visual_bounds,
		"visual_spans": visual_spans,
		"covered": covered,
		"score": score,
		"selected_library": selected_library,
		"skywalk_endpoints": existing_endpoints,
		"skywalk_pair_count": skywalk_pair_count,
		"priority_address_count": priority_address_count,
		"market_count": market_count,
		"skywalk_blocked": skywalk_blocked,
	}


static func _proposal_skywalk_endpoints(proposal: Dictionary) \
		-> Array[Dictionary]:
	## Cheap resource-free counterpart of WarrenOverheadSolver's exact endpoint
	## discovery. It preserves facade pairs in the beam without duplicating any
	## collision, support, route-coverage, or final-admission rule.
	var out: Array[Dictionary] = []
	var kind := StringName(proposal.kind)
	if kind == &"market":
		return out
	var origin := proposal.origin as Vector3i
	var yaw := int(proposal.yaw_quarters)
	var storeys := int(proposal.storeys)
	var x_radius := 2 if kind == &"building" else 1
	var z_radius := 2 if kind == &"building" or kind == &"slim" else 1
	var local_endpoints: Array[Dictionary] = [
		{"cell": Vector3i(x_radius - 1, 0, 0), "facing": Vector3i.RIGHT},
		{"cell": Vector3i(-x_radius, 0, 0), "facing": Vector3i.LEFT},
		{"cell": Vector3i(0, 0, -z_radius), "facing": Vector3i.FORWARD},
		{"cell": Vector3i(0, 0, z_radius - 1), "facing": Vector3i.BACK},
	]
	for level in storeys:
		var level_origin := origin + Vector3i(0, level * 2, 0)
		for endpoint: Dictionary in local_endpoints:
			out.append({
				"owner": StringName(proposal.stable_id),
				"cell": FabricRecipe.transform_cell(endpoint.cell as Vector3i,
					level_origin, yaw),
				"facing": FabricRecipe.transform_direction(
					endpoint.facing as Vector3i, yaw),
			})
	return out


static func _greedy_skywalk_pair_count(endpoints: Array[Dictionary],
		blocked: Dictionary) -> int:
	## Deterministic matching heuristic for the massing beam. Exact skywalk
	## geometry remains the overhead solver's authority; this function only stops
	## the beam from overvaluing several speculative spans that all consume the
	## same bearing building.
	var edges: Dictionary = {}
	for left_index in endpoints.size():
		var left := endpoints[left_index]
		for right_index in range(left_index + 1, endpoints.size()):
			var right := endpoints[right_index]
			var left_owner := StringName(left.owner)
			var right_owner := StringName(right.owner)
			if left_owner == right_owner:
				continue
			var left_cell := left.cell as Vector3i
			var right_cell := right.cell as Vector3i
			var forward := left.facing as Vector3i
			if left_cell.y != right_cell.y \
					or forward != -(right.facing as Vector3i):
				continue
			var delta := right_cell - left_cell
			var distance := delta.x * forward.x + delta.z * forward.z
			if distance < 3 or distance > 7 or distance % 2 == 0 \
					or delta != forward * distance:
				continue
			var corridor_clear := true
			for offset in range(1, distance):
				var corridor_cell := left_cell + forward * offset
				if blocked.has(corridor_cell) \
						or blocked.has(corridor_cell + Vector3i.UP):
					corridor_clear = false
					break
			if not corridor_clear:
				continue
			var first := left_owner if String(left_owner) < String(right_owner) \
				else right_owner
			var second := right_owner if first == left_owner else left_owner
			edges["%s/%s" % [first, second]] = [first, second]
	var edge_keys: Array = edges.keys()
	edge_keys.sort()
	var used: Dictionary = {}
	var count := 0
	for key: String in edge_keys:
		var owners := edges[key] as Array
		var first := StringName(owners[0])
		var second := StringName(owners[1])
		if used.has(first) or used.has(second):
			continue
		used[first] = true
		used[second] = true
		count += 1
	return count


static func _intersects_unrelated_visual_span(candidate: Dictionary,
		candidate_bounds: Array[AABB], spans: Array[Dictionary]) -> bool:
	for span: Dictionary in spans:
		var existing_bounds := span.bounds as Array[AABB]
		if not _visual_intersects(candidate_bounds, existing_bounds):
			continue
		if not StaggeredFabricCompiler.classified_roof_seam_compatible(candidate,
				span.proposal as Dictionary):
			return true
	return false


static func _next_uncovered_index(covered: Dictionary, count: int) -> int:
	for index in count:
		if not covered.has(index):
			return index
	return -1


static func _state_better(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a.score), float(b.score)):
		return float(a.score) > float(b.score)
	var a_signature := _state_signature(a)
	var b_signature := _state_signature(b)
	return a_signature < b_signature


static func _state_better_with_requirements(a: Dictionary, b: Dictionary,
		required_market_count: int,
		required_skywalk_pair_count: int) -> bool:
	# A hard vocabulary requirement must shape the bounded frontier explicitly.
	# Encoding it as a very large aesthetic weight is brittle: the numeric value
	# would have to dominate every future frontage term. Compare progress toward
	# the quota lexicographically, then use the ordinary construction score.
	var required := maxi(0, required_market_count)
	var a_progress := mini(int(a.get("market_count", 0)), required)
	var b_progress := mini(int(b.get("market_count", 0)), required)
	if a_progress != b_progress:
		return a_progress > b_progress
	var required_pairs := maxi(0, required_skywalk_pair_count)
	var a_pair_progress := mini(int(a.get("skywalk_pair_count", 0)),
		required_pairs)
	var b_pair_progress := mini(int(b.get("skywalk_pair_count", 0)),
		required_pairs)
	if a_pair_progress != b_pair_progress:
		return a_pair_progress > b_pair_progress
	return _state_better(a, b)


static func _state_signature(state: Dictionary) -> String:
	var parts := PackedStringArray()
	for proposal: Dictionary in state.proposals as Array[Dictionary]:
		parts.append(String(proposal.stable_id))
	parts.sort()
	return "|".join(parts)


static func _yaw_toward_route(side: Vector3i) -> int:
	# The modular room's reviewed door facade faces local +Z. `side` points
	# from the route toward the proposed building, so the door faces -side.
	if side.x < 0:
		return 1
	if side.x > 0:
		return 3
	if side.z < 0:
		return 0
	return 2


static func _rotated_footprint_bounds(yaw_quarters: int,
		minimum_cell: Vector3i, size: Vector3i) -> Dictionary:
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for local_cell: Vector3i in FabricRecipe.box_cells(minimum_cell, size):
		var rotated := FabricRecipe.transform_cell(local_cell, Vector3i.ZERO,
			yaw_quarters)
		minimum.x = mini(minimum.x, rotated.x)
		minimum.y = mini(minimum.y, rotated.z)
		maximum.x = maxi(maximum.x, rotated.x)
		maximum.y = maxi(maximum.y, rotated.z)
	return {
		"min_x": minimum.x,
		"max_x": maximum.x,
		"min_z": minimum.y,
		"max_z": maximum.y,
		"center_x": floori(float(minimum.x + maximum.x) * 0.5),
		"center_z": floori(float(minimum.y + maximum.y) * 0.5),
	}


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]


static func _seeded_hash(value: String, seed: int) -> int:
	var hash_value := seed ^ 0x459d3f2b
	for byte in value.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte)) * 16777619) & 0x7fffffff
	return hash_value

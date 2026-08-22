class_name WarrenMazeCarver
extends RefCounted

## Deterministic, single-transaction front end for the solid-first maze town.
## One DFS carves the entrance-to-summit spine; coverage-driven alley walks
## then extend that same connected public graph. There is no attempt index,
## survivor ranking, or complete-plan alternative.
const MIN_HOUSE_BANDS := WarrenMazeSourcePlan.MIN_HOUSE_BANDS
const FRONTAGE_FLOOR := 0.90
const FRONTAGE_BUFFER_TARGET := 0.92
const MAX_SPINE_STRAIGHT_RUN := WarrenMazeSourcePlan.MAX_SPINE_STRAIGHT_RUN
const MAX_ALLEY_STRAIGHT_RUN := WarrenMazeSourcePlan.MAX_ALLEY_STRAIGHT_RUN
const MIN_ALLEY_CELLS := 3
const MAX_ALLEY_CELLS := 8
const SPINE_VISIT_BUDGET := 40000
const MAX_DERIVED_ALLEY_CELLS := 320
## Controller ruling (2026-08-22, task-2 follow-up): a passage cell now
## opens to sky by default -- the block-thickness heuristic that used to
## gate this was starving bridge-span eligibility, since "would-be-open"
## cells were concentrated at the massif's thin, peripheral edge where a
## genuine two-block-connecting span is structurally rare. See
## task-2-report.md for the before/after per-seed counts.
const BRIDGE_SPAN_PERIOD := 4
const MIN_LOOP_JOINS := 1
const MAX_LOOP_JOINS := 2
const MAX_LOOP_CONNECTOR_CELLS := 8
const MAX_LOOP_SEARCH_VISITS_PER_ANCHOR := 500

static var last_failure := ""
static var last_diagnostic: Dictionary = {}


static func carve(world_seed: int, massif: WarrenMassif,
		scale_profile: WarrenVillageScaleProfile = null,
		seal_plan: bool = true) -> WarrenMazeSourcePlan:
	last_failure = ""
	last_diagnostic = {}
	var profile := scale_profile if scale_profile != null \
		else WarrenVillageScaleProfile.select(world_seed)
	if massif == null or not massif.is_sealed():
		last_failure = "massif missing or unsealed"
		return null
	if profile == null or not profile.validate():
		last_failure = "scale profile missing or invalid"
		return null
	var market_cells := clampi(profile.radius_cells - 2, 4, 7)
	var portals := _portal_cells(massif, market_cells, world_seed)
	if portals.is_empty():
		last_failure = "no boundary entrance can support the market approach"
		return null
	# Portal selection is part of construction, not a candidate corpus: the
	# deterministic best mouth becomes the one road-aligned entrance in v1.
	var portal := portals[0]
	var excavation := WarrenExcavation.new(world_seed)
	var occupied: Dictionary = {portal: true}
	excavation.route.append(portal)
	for band in range(portal.y,
			portal.y + WarrenPassageLatticeRules.HEADROOM_BANDS):
		excavation.carved[Vector3i(portal.x, band, portal.z)] = true
	var context := {
		"world_seed": world_seed,
		"massif": massif,
		"profile": profile,
		"excavation": excavation,
		"occupied": occupied,
		"portal": portal,
		"market_cells": market_cells,
		"inner_radius": maxf(2.5, float(profile.radius_cells) * 0.42),
		"visits": 0,
	}
	if not _search_spine(context, portal, -1, 0):
		last_failure = "single spine DFS exhausted %d visits" \
			% int(context.visits)
		last_diagnostic = {"stage": &"spine", "visits": context.visits,
			"portal": portal, "route_cells": excavation.route.size()}
		return null
	var thickness := _block_thickness_field(massif,
		excavation.route.back(), profile.radius_cells)
	# Reserve the universal square before alley growth can spend either of its
	# two flanking cells. Alley coverage then grows around this immutable public
	# feature and restores any frontage margin the wider floor consumes.
	var market_square := _stamp_market_square(world_seed, massif, excavation,
		excavation.route.slice(0, market_cells))
	if market_square.is_empty():
		last_failure = "universal market square could not fit beside its approach"
		last_diagnostic = {"stage": &"market_stamp",
			"frontage": _frontage_audit(massif, excavation),
			"market_approach": excavation.route.slice(0, market_cells)}
		return null
	var before_frontage := _frontage_audit(massif, excavation)
	_carve_alleys(world_seed, massif, excavation, thickness,
		market_cells, profile)
	var loop_target := MAX_LOOP_JOINS if profile.scale_id in [
		WarrenVillageScaleProfile.LARGE,
		WarrenVillageScaleProfile.GRAND] else MIN_LOOP_JOINS
	_carve_loop_joins(world_seed, massif, excavation, thickness,
		market_square, loop_target)
	var after_frontage := _frontage_audit(massif, excavation)
	if float(after_frontage.ratio) < FRONTAGE_FLOOR:
		last_failure = "alley budget reached %.3f frontage, below %.3f" % [
			float(after_frontage.ratio), FRONTAGE_FLOOR]
		last_diagnostic = {"stage": &"alleys", "before": before_frontage,
			"after": after_frontage, "lane_count": excavation.lanes.size(),
			"lane_cells": excavation.lane_cells().size()}
		return null
	var forced_open: Array[Vector3i] = []
	forced_open.assign(excavation.route.slice(0, market_cells))
	for cell: Vector3i in market_square:
		if cell not in forced_open:
			forced_open.append(cell)
	_open_passages_to_air(world_seed, massif, excavation, forced_open,
		profile)
	_finalize_excavation(massif, excavation)
	if not excavation.seal():
		last_failure = "maze excavation rejected: %s" % excavation.last_rejection
		return null
	var plan := WarrenMazeSourcePlan.new(world_seed, profile, massif, excavation)
	for cell: Vector3i in excavation.route:
		plan.mark_passage(cell, WarrenMazeSourcePlan.PASSAGE_SPINE)
	for cell: Vector3i in excavation.lane_cells():
		plan.mark_passage(cell, WarrenMazeSourcePlan.PASSAGE_MARKET \
			if cell in market_square else WarrenMazeSourcePlan.PASSAGE_ALLEY)
	plan.market_zone.assign(excavation.route.slice(0, market_cells))
	plan.market_square_cells.assign(market_square)
	plan.feature_stamps.append({"kind": &"market_square",
		"cells": market_square.duplicate(), "adaptation": &"fit"})
	plan.summit_cell = excavation.route.back()
	plan.block_thickness = thickness
	if seal_plan:
		if not plan.seal():
			last_failure = "maze source plan rejected: %s" % plan.last_rejection
			last_diagnostic = {"stage": &"source_seal", "audit": plan.audit,
				"lane_count": excavation.lanes.size()}
			return null
		last_diagnostic = plan.audit.duplicate(true)
		last_diagnostic["spine_visits"] = context.visits
		last_diagnostic["lane_count"] = excavation.lanes.size()
		last_diagnostic["loop_join_count"] = excavation.loop_edges.size()
	return plan


static func _stamp_market_square(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation,
		market_approach: Array) -> Array[Vector3i]:
	## Widen one two-cell run of the ground approach by one cell to a side. The
	## resulting 2x2 is explicit source topology and remains one connected lane;
	## generic passage growth is still forbidden from making broad floors.
	var candidates: Array[Dictionary] = []
	for index in range(market_approach.size() - 1):
		var first := market_approach[index] as Vector3i
		var second := market_approach[index + 1] as Vector3i
		var delta := second - first
		if delta.y != 0 or absi(delta.x) + absi(delta.z) != 1:
			continue
		var travel := Vector2i(delta.x, delta.z)
		for side_sign in [-1, 1]:
			var side := Vector2i(-travel.y * side_sign, travel.x * side_sign)
			var side_first := first + Vector3i(side.x, 0, side.y)
			var side_second := second + Vector3i(side.x, 0, side.y)
			if not WarrenPassageLatticeRules.is_at_grade(massif, side_first) \
					or not WarrenPassageLatticeRules.is_at_grade(massif, side_second) \
					or not WarrenPassageLatticeRules.slot_is_borable(massif,
						excavation, side_first,
						WarrenPassageLatticeRules.HEADROOM_BANDS) \
					or not WarrenPassageLatticeRules.slot_is_borable(massif,
						excavation, side_second,
						WarrenPassageLatticeRules.HEADROOM_BANDS):
				continue
			var score := float(index) * 120.0
			var tie := WarrenPassageLatticeRules.hash_key(world_seed,
				0x4D41524B, side_second, side_sign)
			var lane_cells := [side_first, side_second] as Array[Vector3i]
			candidates.append({"lane_cells": lane_cells,
				"square": [first, second, side_first, side_second] \
					as Array[Vector3i],
				"transitions": [
					{"from": first, "to": side_first,
						"kind": WarrenVolumeTransition.Kind.LEVEL},
					{"from": side_first, "to": side_second,
						"kind": WarrenVolumeTransition.Kind.LEVEL},
				] as Array[Dictionary],
				"score": score, "tie": tie})
	# A turning approach already owns three corners of a square. Carving only the
	# missing diagonal preserves more surrounding building mass and guarantees a
	# market on tight zig-zag entrances where neither straight side remains free.
	for index in range(market_approach.size() - 2):
		var first := market_approach[index] as Vector3i
		var corner := market_approach[index + 1] as Vector3i
		var third := market_approach[index + 2] as Vector3i
		var incoming := corner - first
		var outgoing := third - corner
		if first.y != corner.y or corner.y != third.y \
				or absi(incoming.x) + absi(incoming.z) != 1 \
				or absi(outgoing.x) + absi(outgoing.z) != 1 \
				or incoming.x * outgoing.x + incoming.z * outgoing.z != 0:
			continue
		var missing := first + outgoing
		if not WarrenPassageLatticeRules.is_at_grade(massif, missing) \
				or not WarrenPassageLatticeRules.slot_is_borable(massif,
				excavation, missing,
				WarrenPassageLatticeRules.HEADROOM_BANDS):
			continue
		candidates.append({"lane_cells": [missing] as Array[Vector3i],
			"square": [first, corner, third, missing] as Array[Vector3i],
			"transitions": [{"from": first, "to": missing,
				"kind": WarrenVolumeTransition.Kind.LEVEL}] as Array[Dictionary],
			"score": float(index) * 120.0 + 40.0,
			"tie": WarrenPassageLatticeRules.hash_key(world_seed,
				0x4D415254, missing)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.score), float(b.score)):
			return float(a.score) < float(b.score)
		return int(a.tie) < int(b.tie))
	for candidate: Dictionary in candidates:
		var lane_cells := candidate.lane_cells as Array[Vector3i]
		var carved: Array[Vector3i] = []
		for cell: Vector3i in lane_cells:
			for band in range(cell.y, cell.y \
					+ WarrenPassageLatticeRules.HEADROOM_BANDS):
				var air := Vector3i(cell.x, band, cell.z)
				excavation.carved[air] = true
				carved.append(air)
		var transitions := candidate.transitions as Array[Dictionary]
		var anchor := transitions[0].from as Vector3i
		excavation.lanes.append({"anchor": anchor, "cells": lane_cells,
			"transitions": transitions, "feature_kind": &"market_square"})
		var square := candidate.square as Array[Vector3i]
		# Close the square's fourth side explicitly.  The typed market is already
		# the one deliberate broad public floor, so this seam creates the
		# universal reconnecting loop without boring another plaza or asking a
		# downstream adapter to infer adjacency from touching surfaces.
		var endpoint: Vector3i = lane_cells.back()
		var predecessor: Vector3i = anchor if lane_cells.size() == 1 \
			else lane_cells[lane_cells.size() - 2]
		var loop_target := Vector3i(2147483647, 2147483647, 2147483647)
		for square_cell: Vector3i in square:
			if square_cell == endpoint or square_cell == predecessor:
				continue
			var delta: Vector3i = square_cell - endpoint
			if delta.y == 0 and absi(delta.x) + absi(delta.z) == 1:
				loop_target = square_cell
				break
		if loop_target.x == 2147483647:
			excavation.lanes.pop_back()
			for air: Vector3i in carved:
				excavation.carved.erase(air)
			continue
		excavation.loop_edges.append({"from": endpoint, "to": loop_target,
			"kind": WarrenVolumeTransition.Kind.LEVEL})
		var fronted_square_cells := 0
		for cell: Vector3i in square:
			fronted_square_cells += int(_addressable_sides(massif,
				excavation, cell) >= 1)
		# Two held corners plus the two-cell street mouth produce a recognisable
		# square bounded on its long sides. The graph-wide frontage seal below still
		# prevents this local exception from opening the rest of the town.
		if fronted_square_cells >= 2:
			square.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
				return _cell_less(a, b))
			return square
		excavation.loop_edges.pop_back()
		excavation.lanes.pop_back()
		for air: Vector3i in carved:
			excavation.carved.erase(air)
	return [] as Array[Vector3i]


static func _search_spine(context: Dictionary, current: Vector3i,
		previous_direction_index: int, straight_run: int) -> bool:
	context.visits = int(context.visits) + 1
	if int(context.visits) > SPINE_VISIT_BUDGET:
		return false
	var excavation := context.excavation as WarrenExcavation
	var profile := context.profile as WarrenVillageScaleProfile
	var portal := context.portal as Vector3i
	var radius := Vector2(float(current.x), float(current.z)).length()
	if excavation.route.size() >= profile.route_cell_range.x \
			and excavation.route.size() >= int(context.market_cells) \
			and current.y - portal.y >= profile.route_span_range.x \
			and radius <= float(context.inner_radius):
		return true
	if excavation.route.size() >= profile.route_cell_range.y:
		return false
	var candidates := _spine_candidates(context, current,
		previous_direction_index, straight_run)
	for candidate: Dictionary in candidates:
		var cells := candidate.cells as Array[Vector3i]
		var run := int(candidate.run)
		var before_size := excavation.route.size()
		excavation.transitions.append({"from": current,
			"to": cells.back(), "kind": int(candidate.kind)})
		var carved := WarrenPassageLatticeRules.carve_stride(excavation,
			context.occupied as Dictionary, cells, int(candidate.rise), run)
		var next_straight := straight_run + run \
			if int(candidate.direction_index) == previous_direction_index else run
		if _search_spine(context, cells.back(),
				int(candidate.direction_index), next_straight):
			return true
		excavation.transitions.pop_back()
		WarrenPassageLatticeRules.rollback(excavation,
			context.occupied as Dictionary, cells, carved)
		excavation.route.resize(before_size)
	return false


static func _spine_candidates(context: Dictionary, current: Vector3i,
		previous_direction_index: int, straight_run: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var massif := context.massif as WarrenMassif
	var excavation := context.excavation as WarrenExcavation
	var profile := context.profile as WarrenVillageScaleProfile
	var occupied := context.occupied as Dictionary
	# Keep one ordinary street node immediately beyond the protected market
	# zone. Alleys may not branch inside the market, so without this landing the
	# spine can climb on the very next move and leave the ground network with no
	# legal root at all.
	var market_incomplete := excavation.route.size() \
		< int(context.market_cells) + 1
	var portal := context.portal as Vector3i
	for direction_index in WarrenPassageLatticeRules.DIRECTIONS.size():
		var direction := WarrenPassageLatticeRules.DIRECTIONS[direction_index]
		if previous_direction_index >= 0 \
				and direction_index == (previous_direction_index + 2) % 4:
			continue
		for action_index in WarrenPassageLatticeRules.CLIMB_ACTIONS.size():
			var action := WarrenPassageLatticeRules.CLIMB_ACTIONS[action_index]
			var run := int(action.run)
			if excavation.route.size() + run > profile.route_cell_range.y:
				continue
			var next_straight := straight_run + run \
				if direction_index == previous_direction_index else run
			if next_straight > MAX_SPINE_STRAIGHT_RUN:
				continue
			var stride := WarrenPassageLatticeRules.stride_cells(massif,
				excavation, occupied, current, direction,
				int(action.rise), run)
			if stride.is_empty() or market_incomplete \
					and not _stride_is_at_grade(massif, stride):
				continue
			var address_sides := 0
			var two_sided := 0
			for cell: Vector3i in stride:
				var sides := _addressable_sides(massif, excavation, cell)
				if sides < 1:
					address_sides = -1000
					break
				address_sides += sides
				two_sided += int(sides >= 2)
			if address_sides < 0:
				continue
			var endpoint: Vector3i = stride.back()
			var radius := Vector2(float(endpoint.x), float(endpoint.z)).length()
			var span := endpoint.y - portal.y
			var span_deficit := maxi(0, profile.route_span_range.x - span)
			var score := radius * 240.0 + float(span_deficit) * 520.0 \
				- float(address_sides) * 105.0 - float(two_sided) * 160.0 \
				+ float(run) * 35.0
			if not market_incomplete and int(action.rise) > 0:
				score -= 310.0
			if direction_index == previous_direction_index:
				score += float(next_straight) * 55.0
			else:
				score -= 45.0
			var tie := WarrenPassageLatticeRules.hash_key(
				int(context.world_seed), 0x51A7, endpoint,
				int(context.visits) * 17 + action_index)
			out.append({"cells": stride, "run": run,
				"rise": int(action.rise), "kind": int(action.kind),
				"direction_index": direction_index, "score": score,
				"tie": tie})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.score), float(b.score)):
			return float(a.score) < float(b.score)
		return int(a.tie) < int(b.tie))
	return out


static func _carve_alleys(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, thickness: Dictionary,
		market_cell_count: int, profile: WarrenVillageScaleProfile) -> void:
	var public_set: Dictionary = {}
	for cell: Vector3i in excavation.route:
		public_set[cell] = true
	var market_set: Dictionary = {}
	for cell: Vector3i in excavation.route.slice(0, market_cell_count):
		market_set[cell] = true
	for lane: Dictionary in excavation.lanes:
		for cell: Vector3i in lane.cells as Array[Vector3i]:
			public_set[cell] = true
			if StringName(lane.get("feature_kind", &"")) == &"market_square":
				market_set[cell] = true
	var capable := _house_capable_column_count(massif, excavation)
	# Existing lane budgets were tuned for the retired one-canyon skin. The maze
	# derives the minimum public-cell supply needed to plausibly front the whole
	# mass, while retaining the profile value as a hard lower bound.
	# A winding passage fronts fewer than two new columns per cell because turns,
	# stairs, and already-addressed junction shoulders overlap. The measured
	# source corpus needs roughly one passage cell per capable column to reach
	# the profile's addressed-column target; the independent source seal still
	# requires 0.90 of passage cells to retain an inhabitable facade.
	var target_public_cells := int(ceil(float(capable) * 1.10))
	var cell_budget := clampi(maxi(profile.lane_cell_budget,
		target_public_cells - excavation.route.size()),
		profile.lane_cell_budget, MAX_DERIVED_ALLEY_CELLS)
	var lane_budget := maxi(profile.lane_budget,
		int(ceil(float(cell_budget) / 4.0)))
	var tried: Dictionary = {}
	var used_cells := excavation.lane_cells().size()
	while excavation.lanes.size() < lane_budget and used_cells < cell_budget:
		var audit := _frontage_audit(massif, excavation)
		if excavation.lane_cells().size() >= profile.lane_cell_budget \
				and float(audit.column_ratio) \
					>= _column_frontage_target(profile) \
				and float(audit.ratio) >= FRONTAGE_BUFFER_TARGET:
			break
		var anchor := _next_alley_anchor(world_seed, excavation,
			market_set, tried)
		if anchor == Vector3i(2147483647, 2147483647, 2147483647):
			break
		tried[anchor] = true
		var ratio_before := float(audit.column_ratio)
		var lane := _grow_alley(world_seed, massif, excavation, public_set,
			thickness, anchor, cell_budget - used_cells)
		if lane.is_empty():
			continue
		excavation.lanes.append(lane)
		var after_lane := _frontage_audit(massif, excavation)
		var ratio_after := float(after_lane.column_ratio)
		if ratio_after <= ratio_before \
				or float(after_lane.ratio) < FRONTAGE_FLOOR:
			excavation.lanes.pop_back()
			WarrenPassageLatticeRules.rollback(excavation, public_set,
				lane.cells as Array[Vector3i],
				lane.get("_carved", []) as Array[Vector3i])
			continue
		lane.erase("_carved")
		used_cells += (lane.cells as Array[Vector3i]).size()


static func _next_alley_anchor(world_seed: int,
		excavation: WarrenExcavation, market_set: Dictionary,
		tried: Dictionary) -> Vector3i:
	var anchors := _walk_nodes(excavation)
	anchors.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		var ah := WarrenPassageLatticeRules.hash_key(world_seed, 0xA11E, a)
		var bh := WarrenPassageLatticeRules.hash_key(world_seed, 0xA11E, b)
		if ah != bh:
			return ah < bh
		return _cell_less(a, b))
	for anchor: Vector3i in anchors:
		if not market_set.has(anchor) and not tried.has(anchor):
			return anchor
	return Vector3i(2147483647, 2147483647, 2147483647)


static func _carve_loop_joins(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, thickness: Dictionary,
		market_square: Array[Vector3i], target_count: int) -> void:
	## Close the branch tree with an explicit short connector.  Each connector
	## is still a narrow alley: only its first and last cells touch old public
	## realm, every intermediate is newly bored, at least one solid flank remains
	## inhabitable, and the universal market is excluded.  Searching both
	## cardinal orders between nearby graph nodes admits straight or one-bend
	## tunnels without introducing an unconstrained second route solver.
	var market_set: Dictionary = {}
	for cell: Vector3i in market_square:
		market_set[cell] = true
	var loop_cells: Dictionary = {}
	while excavation.loop_edges.size() < target_count:
		var public_set: Dictionary = {}
		for cell: Vector3i in excavation.public_cells():
			public_set[cell] = true
		var walk_set: Dictionary = {}
		var walk_nodes := _walk_nodes(excavation)
		for cell: Vector3i in walk_nodes:
			walk_set[cell] = true
		walk_nodes.assign(walk_set.keys())
		walk_nodes.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return _cell_less(a, b))
		var candidates: Array[Dictionary] = []
		for first_index in walk_nodes.size():
			var anchor := walk_nodes[first_index]
			if market_set.has(anchor):
				continue
			for second_index in range(first_index + 1, walk_nodes.size()):
				var target := walk_nodes[second_index]
				var distance := absi(target.x - anchor.x) \
					+ absi(target.z - anchor.z)
				if target.y != anchor.y or market_set.has(target) \
						or distance < 2 \
						or distance > MAX_LOOP_CONNECTOR_CELLS + 1:
					continue
				for path_value: Variant in _manhattan_connector_paths(
						anchor, target):
					var cells := path_value as Array[Vector3i]
					if not _loop_connector_is_legal(massif, excavation,
							public_set, walk_set, thickness, market_set,
							loop_cells, anchor, target, cells):
						continue
					var frontage := 0
					var centre_distance := 0.0
					for cell: Vector3i in cells:
						frontage += _addressable_sides(massif, excavation,
							cell)
						centre_distance += Vector2(float(cell.x),
							float(cell.z)).length_squared()
					candidates.append({"cells": cells, "anchor": anchor,
						"target": target, "frontage": frontage,
						"score": -float(frontage) * 1000.0
							+ float(cells.size()) * 80.0
							+ centre_distance * 0.25,
						"tie": WarrenPassageLatticeRules.hash_key(world_seed,
							0x100F, cells.back(), first_index * 131
								+ second_index * 7
								+ excavation.loop_edges.size())})
		if candidates.is_empty():
			candidates = _winding_loop_connector_candidates(world_seed,
				massif, excavation, public_set, walk_set, thickness,
				market_set, loop_cells, walk_nodes)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if not is_equal_approx(float(a.score), float(b.score)):
				return float(a.score) < float(b.score)
			if int(a.tie) != int(b.tie):
				return int(a.tie) < int(b.tie)
			return _cell_less(a.cell as Vector3i, b.cell as Vector3i))
		if candidates.is_empty():
			break
		var committed := false
		for candidate: Dictionary in candidates:
			var cells := candidate.cells as Array[Vector3i]
			var carved: Array[Vector3i] = []
			var transitions: Array[Dictionary] = []
			var previous := candidate.anchor as Vector3i
			for cell: Vector3i in cells:
				for band in range(cell.y, cell.y \
						+ WarrenPassageLatticeRules.HEADROOM_BANDS):
					var air := Vector3i(cell.x, band, cell.z)
					excavation.carved[air] = true
					carved.append(air)
				transitions.append({"from": previous, "to": cell,
					"kind": WarrenVolumeTransition.Kind.LEVEL})
				previous = cell
			var lane := {"anchor": candidate.anchor,
				"cells": cells, "transitions": transitions,
				"feature_kind": &"loop_join"}
			var edge := {"from": cells.back(), "to": candidate.target,
				"kind": WarrenVolumeTransition.Kind.LEVEL}
			excavation.lanes.append(lane)
			excavation.loop_edges.append(edge)
			var audit := _frontage_audit(massif, excavation)
			if float(audit.ratio) >= FRONTAGE_FLOOR:
				for cell: Vector3i in cells:
					loop_cells[cell] = true
				committed = true
				break
			excavation.loop_edges.pop_back()
			excavation.lanes.pop_back()
			for air: Vector3i in carved:
				excavation.carved.erase(air)
		if not committed:
			break


static func _manhattan_connector_paths(anchor: Vector3i,
		target: Vector3i) -> Array:
	var out: Array = []
	var x_first: Array[Vector3i] = []
	var cursor := anchor
	while cursor.x != target.x:
		cursor += Vector3i(signi(target.x - cursor.x), 0, 0)
		if cursor != target:
			x_first.append(cursor)
	while cursor.z != target.z:
		cursor += Vector3i(0, 0, signi(target.z - cursor.z))
		if cursor != target:
			x_first.append(cursor)
	if not x_first.is_empty():
		out.append(x_first)
	var z_first: Array[Vector3i] = []
	cursor = anchor
	while cursor.z != target.z:
		cursor += Vector3i(0, 0, signi(target.z - cursor.z))
		if cursor != target:
			z_first.append(cursor)
	while cursor.x != target.x:
		cursor += Vector3i(signi(target.x - cursor.x), 0, 0)
		if cursor != target:
			z_first.append(cursor)
	if not z_first.is_empty() and z_first != x_first:
		out.append(z_first)
	return out


static func _winding_loop_connector_candidates(world_seed: int,
		massif: WarrenMassif, excavation: WarrenExcavation,
		public_set: Dictionary, walk_set: Dictionary, thickness: Dictionary,
		market_set: Dictionary, loop_cells: Dictionary,
		walk_nodes: Array[Vector3i]) -> Array[Dictionary]:
	## If no straight/one-bend seam fits, run one bounded breadth-first search
	## from each graph node.  This is still one deterministic construction: the
	## search emits only short, same-datum, cardinal corridors and ranks the
	## resulting seams once.  It exists because winding branches often leave no
	## legal Manhattan rectangle even though a narrow dogleg can reconnect them.
	var out: Array[Dictionary] = []
	var emitted: Dictionary = {}
	for anchor_index in walk_nodes.size():
		var anchor := walk_nodes[anchor_index]
		if market_set.has(anchor):
			continue
		var queue: Array[Dictionary] = [{"cell": anchor,
			"path": [] as Array[Vector3i]}]
		var visited: Dictionary = {anchor: true}
		var cursor := 0
		var visits := 0
		var anchor_candidates := 0
		while cursor < queue.size() \
				and visits < MAX_LOOP_SEARCH_VISITS_PER_ANCHOR \
				and anchor_candidates < 4:
			var state := queue[cursor]
			cursor += 1
			visits += 1
			var current := state.cell as Vector3i
			var path := state.path as Array[Vector3i]
			if path.size() >= MAX_LOOP_CONNECTOR_CELLS:
				continue
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				var next := current + Vector3i(direction.x, 0, direction.y)
				if visited.has(next) or public_set.has(next) \
						or market_set.has(next) or loop_cells.has(next) \
						or int(thickness.get(Vector2i(next.x, next.z), 0)) < 1 \
						or _addressable_sides(massif, excavation, next) < 1 \
						or not WarrenPassageLatticeRules.slot_is_borable(
							massif, excavation, next,
							WarrenPassageLatticeRules.HEADROOM_BANDS):
					continue
				var old_neighbours: Array[Vector3i] = []
				var invalid_old_neighbour := false
				for side: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
					var neighbour := next + Vector3i(side.x, 0, side.y)
					if not public_set.has(neighbour):
						continue
					if not walk_set.has(neighbour):
						invalid_old_neighbour = true
						break
					old_neighbours.append(neighbour)
				if invalid_old_neighbour:
					continue
				var target := Vector3i(2147483647, 2147483647,
					2147483647)
				var has_target := false
				for neighbour: Vector3i in old_neighbours:
					if neighbour == anchor and path.is_empty():
						continue
					if neighbour == anchor or market_set.has(neighbour) \
							or has_target:
						invalid_old_neighbour = true
						break
					target = neighbour
					has_target = true
				if invalid_old_neighbour:
					continue
				if path.is_empty() and anchor not in old_neighbours:
					continue
				if not path.is_empty() and not old_neighbours.is_empty() \
						and not has_target:
					continue
				var next_path: Array[Vector3i] = []
				next_path.assign(path)
				next_path.append(next)
				if has_target:
					if not _loop_connector_is_legal(massif, excavation,
							public_set, walk_set, thickness, market_set,
							loop_cells, anchor, target, next_path):
						continue
					var key := "%s>%s:%s" % [anchor, target, next_path]
					if emitted.has(key):
						continue
					emitted[key] = true
					var frontage := 0
					var centre_distance := 0.0
					for cell: Vector3i in next_path:
						frontage += _addressable_sides(massif, excavation,
							cell)
						centre_distance += Vector2(float(cell.x),
							float(cell.z)).length_squared()
					out.append({"cells": next_path, "anchor": anchor,
						"target": target, "frontage": frontage,
						"score": -float(frontage) * 1000.0
							+ float(next_path.size()) * 95.0
							+ centre_distance * 0.25,
						"tie": WarrenPassageLatticeRules.hash_key(
							world_seed, 0x100D, next_path.back(),
							anchor_index * 31 + next_path.size() * 7
								+ excavation.loop_edges.size())})
					anchor_candidates += 1
					continue
				var simulated_walk := walk_set.duplicate()
				for cell: Vector3i in next_path:
					simulated_walk[cell] = true
				if _forms_untyped_public_square(simulated_walk, next):
					continue
				visited[next] = true
				queue.append({"cell": next, "path": next_path})
	return out


static func _loop_connector_is_legal(massif: WarrenMassif,
		excavation: WarrenExcavation, public_set: Dictionary,
		walk_set: Dictionary, thickness: Dictionary, market_set: Dictionary,
		loop_cells: Dictionary, anchor: Vector3i, target: Vector3i,
		cells: Array[Vector3i]) -> bool:
	if cells.is_empty() or cells.size() > MAX_LOOP_CONNECTOR_CELLS:
		return false
	var simulated_walk := walk_set.duplicate()
	for index in cells.size():
		var cell := cells[index]
		if public_set.has(cell) or market_set.has(cell) \
				or loop_cells.has(cell) \
				or int(thickness.get(Vector2i(cell.x, cell.z), 0)) < 1 \
				or _addressable_sides(massif, excavation, cell) < 1 \
				or not WarrenPassageLatticeRules.slot_is_borable(massif,
					excavation, cell,
					WarrenPassageLatticeRules.HEADROOM_BANDS):
			return false
		var allowed_old_neighbours: Dictionary = {}
		if index == 0:
			allowed_old_neighbours[anchor] = true
		if index == cells.size() - 1:
			allowed_old_neighbours[target] = true
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var neighbour := cell + Vector3i(direction.x, 0, direction.y)
			if public_set.has(neighbour) \
					and not allowed_old_neighbours.has(neighbour):
				return false
		simulated_walk[cell] = true
		if _forms_untyped_public_square(simulated_walk, cell):
			return false
	return true


static func _forms_untyped_public_square(walk_set: Dictionary,
		join: Vector3i) -> bool:
	## A macro walk node expands to a 2x2 player-width surface in the common
	## volume plan.  Completing any four-node square here would therefore make
	## an accidental broad floor.  The market is already present and the join is
	## forbidden from entering it, so every square involving this new cell is
	## necessarily untyped.
	for offset_x in [-1, 0]:
		for offset_z in [-1, 0]:
			var origin := join + Vector3i(offset_x, 0, offset_z)
			var complete := true
			for dx in 2:
				for dz in 2:
					var cell := origin + Vector3i(dx, 0, dz)
					if cell != join and not walk_set.has(cell):
						complete = false
			if complete:
				return true
	return false


static func _grow_alley(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, public_set: Dictionary,
		thickness: Dictionary, anchor: Vector3i, budget: int) -> Dictionary:
	var target := mini(budget, MIN_ALLEY_CELLS + posmod(
		WarrenPassageLatticeRules.hash_key(world_seed, 0xB4A, anchor),
		MAX_ALLEY_CELLS - MIN_ALLEY_CELLS + 1))
	if target < MIN_ALLEY_CELLS:
		return {}
	var lane_cells: Array[Vector3i] = []
	var transitions: Array[Dictionary] = []
	var all_carved: Array[Vector3i] = []
	var local_set: Dictionary = {anchor: true}
	var current := anchor
	var previous_direction_index := -1
	var straight := 0
	while lane_cells.size() < target:
		var candidates := _alley_candidates(world_seed, massif, excavation,
			public_set, local_set, thickness, anchor, current,
			previous_direction_index, straight, target - lane_cells.size(),
			lane_cells.size())
		if candidates.is_empty():
			break
		var selected := candidates[0]
		var stride := selected.cells as Array[Vector3i]
		transitions.append({"from": current, "to": stride.back(),
			"kind": int(selected.kind)})
		var carved := WarrenPassageLatticeRules.carve_lane_stride(excavation,
			public_set, lane_cells, stride, int(selected.rise), int(selected.run))
		all_carved.append_array(carved)
		for cell: Vector3i in stride:
			local_set[cell] = true
		straight = straight + int(selected.run) \
			if int(selected.direction_index) == previous_direction_index \
			else int(selected.run)
		previous_direction_index = int(selected.direction_index)
		current = stride.back()
	if lane_cells.size() < MIN_ALLEY_CELLS:
		WarrenPassageLatticeRules.rollback(excavation, public_set,
			lane_cells, all_carved)
		return {}
	return {"anchor": anchor, "cells": lane_cells,
		"transitions": transitions, "_carved": all_carved}


static func _alley_candidates(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, public_set: Dictionary,
		local_set: Dictionary, thickness: Dictionary, anchor: Vector3i,
		current: Vector3i, previous_direction_index: int, straight_run: int,
		budget: int, move_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var already_fronted := _fronted_columns(massif, excavation)
	for direction_index in WarrenPassageLatticeRules.DIRECTIONS.size():
		var direction := WarrenPassageLatticeRules.DIRECTIONS[direction_index]
		if previous_direction_index >= 0 \
				and direction_index == (previous_direction_index + 2) % 4:
			continue
		for action_index in WarrenPassageLatticeRules.CONTOUR_ACTIONS.size():
			var action := WarrenPassageLatticeRules.CONTOUR_ACTIONS[action_index]
			var run := int(action.run)
			if run > budget:
				continue
			var next_straight := straight_run + run \
				if direction_index == previous_direction_index else run
			if next_straight > MAX_ALLEY_STRAIGHT_RUN:
				continue
			var stride := WarrenPassageLatticeRules.stride_cells(massif,
				excavation, public_set, current, direction,
				int(action.rise), run)
			if stride.is_empty() or not _alley_stride_is_legal(massif,
					excavation, public_set, local_set, thickness, anchor,
					current, stride):
				continue
			var new_frontage: Dictionary = {}
			var sides := 0
			for cell: Vector3i in stride:
				for side: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
					var column := Vector2i(cell.x + side.x,
						cell.z + side.y)
					if _column_carries_house_at(massif, excavation,
							column, cell.y):
						sides += 1
						if not already_fronted.has(column):
							new_frontage[column] = true
			var endpoint: Vector3i = stride.back()
			var travel := absi(endpoint.x - anchor.x) \
				+ absi(endpoint.z - anchor.z)
			var score := -float(new_frontage.size()) * 1200.0 \
				- float(sides) * 180.0 + float(absi(int(action.rise))) * 5200.0 \
				- float(travel) * 55.0 + float(next_straight) * 45.0
			var tie := WarrenPassageLatticeRules.hash_key(world_seed,
				0xA77E, endpoint, move_index * 13 + action_index)
			out.append({"cells": stride, "run": run,
				"rise": int(action.rise), "kind": int(action.kind),
				"direction_index": direction_index, "score": score,
				"tie": tie})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.score), float(b.score)):
			return float(a.score) < float(b.score)
		return int(a.tie) < int(b.tie))
	return out


static func _alley_stride_is_legal(massif: WarrenMassif,
		excavation: WarrenExcavation, public_set: Dictionary,
		local_set: Dictionary, thickness: Dictionary, anchor: Vector3i,
		previous: Vector3i, stride: Array[Vector3i]) -> bool:
	var predecessor := previous
	for cell: Vector3i in stride:
		if _addressable_sides(massif, excavation, cell) < 1:
			return false
		# Same-datum adjacency to an older street would turn the two cells into
		# one broad surface. The branch's own predecessor is the only exception.
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var neighbor := cell + Vector3i(direction.x, 0, direction.y)
			if public_set.has(neighbor) and neighbor != predecessor \
					and not local_set.has(neighbor):
				return false
		var target_thickness := int(thickness.get(
			Vector2i(cell.x, cell.z), 2))
		for other_value: Variant in public_set.keys():
			var other := other_value as Vector3i
			if other.y != cell.y or local_set.has(other) \
					or absi(other.x - anchor.x) + absi(other.z - anchor.z) \
						<= target_thickness:
				continue
			var distance := absi(other.x - cell.x) + absi(other.z - cell.z)
			if distance >= 2 and distance <= target_thickness:
				return false
		predecessor = cell
	return true


static func _open_passages_to_air(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, market_zone: Array,
		profile: WarrenVillageScaleProfile) -> void:
	## Controller ruling (2026-08-22): a passage cell opens to sky by
	## default now. The three exceptions that stay covered are the market
	## (`market_zone`, forced covered rather than forced open), a
	## `_column_is_public_facade` over/under crossing (opening it would erase
	## a wall an earlier crossing already proved), and a seeded bridge span
	## cell (its retained overhead mass is the skywalk deck itself).
	var market_set: Dictionary = {}
	for value: Variant in market_zone:
		market_set[value as Vector3i] = true
	var bridged := _select_bridge_spans(world_seed, massif, excavation,
		market_set, profile)
	# A bridge cell's own column can also host a lower, unrelated passage
	# cell (the pre-existing over/under crossing pattern this maze already
	# carves) that would otherwise open straight past the bridge's retained
	# roof now that opening is the default. Cap every other cell's climb at
	# the lowest bridge floor sharing its column, so the bridge's mass -- and
	# the `covered` promise its acceptance check made -- survives intact.
	var bridge_ceiling: Dictionary = {}
	for cell_value: Variant in bridged.keys():
		var cell := cell_value as Vector3i
		var column := Vector2i(cell.x, cell.z)
		if not bridge_ceiling.has(column) or cell.y < int(bridge_ceiling[column]):
			bridge_ceiling[column] = cell.y
	for cell: Vector3i in excavation.public_cells():
		if bridged.has(cell):
			continue
		var column := Vector2i(cell.x, cell.z)
		if market_set.has(cell) \
				or _column_is_public_facade(massif, excavation, column, cell):
			continue
		var ceiling := massif.top_at(column)
		if bridge_ceiling.has(column):
			ceiling = mini(ceiling, int(bridge_ceiling[column]))
		for band in range(cell.y, ceiling):
			excavation.carved[Vector3i(cell.x, band, cell.z)] = true


static func _bridge_eligible(massif: WarrenMassif, excavation: WarrenExcavation,
		market_set: Dictionary, cell: Vector3i) -> bool:
	## Every cell opens to sky except a market cell or a facade crossing (see
	## `_open_passages_to_air`), so a bridge-span run candidate needs only
	## rule those two out -- there is no more thickness gate to also check.
	return not market_set.has(cell) and not _column_is_public_facade(massif,
		excavation, Vector2i(cell.x, cell.z), cell)


static func _select_bridge_spans(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, market_set: Dictionary,
		profile: WarrenVillageScaleProfile) -> Dictionary:
	## Walks the spine then each lane in array order (never dictionary order)
	## looking for maximal runs of non-market, non-portal, non-facade-crossing,
	## level-stride cells -- every such cell would otherwise open straight to
	## the sky. Each such run is handed to `_select_spans_in_run`, which does a
	## deterministic window search (see its own comment) rather than sampling
	## one candidate per period; an accepted span's flanks prove it genuinely
	## connects two blocks. Selection stops at the profile's skywalk quota.
	var accepted: Dictionary = {}
	var quota := profile.skywalk_range.y
	if quota <= 0 or excavation.route.is_empty():
		return accepted
	var portal := excavation.route[0]
	var walks: Array[Array] = [excavation.route]
	var walk_transitions: Array[Array] = [excavation.transitions]
	for lane: Dictionary in excavation.lanes:
		var walk: Array[Vector3i] = [lane.anchor as Vector3i]
		walk.append_array(lane.cells as Array[Vector3i])
		walks.append(walk)
		walk_transitions.append(lane.transitions as Array[Dictionary])
	for walk_index in walks.size():
		if excavation.bridge_spans.size() >= quota:
			break
		var walk := walks[walk_index] as Array[Vector3i]
		var level_cells := _level_stride_cells(walk,
			walk_transitions[walk_index] as Array[Dictionary])
		var run: Array[Vector3i] = []
		var directions: Dictionary = {}
		for index in range(1, walk.size()):
			var cell := walk[index]
			var eligible := level_cells.has(cell) and cell != portal \
				and _bridge_eligible(massif, excavation, market_set, cell)
			if eligible:
				run.append(cell)
				directions[cell] = Vector2i(cell.x - walk[index - 1].x,
					cell.z - walk[index - 1].z)
				continue
			if not run.is_empty():
				_select_spans_in_run(world_seed, massif, excavation, run,
					directions, quota, accepted)
				run = []
				directions = {}
				if excavation.bridge_spans.size() >= quota:
					break
		if not run.is_empty():
			_select_spans_in_run(world_seed, massif, excavation, run,
				directions, quota, accepted)
	return accepted


static func _level_stride_cells(walk: Array[Vector3i],
		transitions: Array[Dictionary]) -> Dictionary:
	## The subset of `walk`'s cells whose incoming transition is a rise-0
	## LEVEL stride. LEVEL is the only Kind whose run is always 1
	## (WarrenExcavation.kind_allows), so each LEVEL spec's `to` cell is
	## exactly one new walk cell -- there is never an intermediate cell to
	## also mark, unlike a multi-cell STAIR or RAMP span.
	var out: Dictionary = {}
	var cursor := 0
	for spec: Dictionary in transitions:
		var from_cell := spec.from as Vector3i
		var to_cell := spec.to as Vector3i
		var run := absi(to_cell.x - from_cell.x) + absi(to_cell.z - from_cell.z)
		cursor += run
		if cursor >= walk.size():
			break
		if int(spec.kind) == WarrenVolumeTransition.Kind.LEVEL:
			out[walk[cursor]] = true
	return out


static func _select_spans_in_run(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, run: Array[Vector3i],
		directions: Dictionary, quota: int, accepted: Dictionary) -> void:
	## Controller ruling (2026-08-22, second follow-up): a fixed-phase sample
	## of one cell per period missed legal cells that existed elsewhere in the
	## same window purely by chance. Deterministic window search fixes that:
	## the seeded hash only picks which run-index the first window starts
	## counting from (a phase in [0, PERIOD)); every window of PERIOD cells
	## after that is then scanned in full, in walk order, for the first cell
	## that can host a span, so a legal cell already counted in that window is
	## never skipped by bad luck. At most one span per window.
	if run.is_empty():
		return
	var phase := WarrenPassageLatticeRules.hash_key(world_seed, 0xB21D6E,
		run[0], 0) % BRIDGE_SPAN_PERIOD
	var window_start := phase
	while window_start < run.size():
		if excavation.bridge_spans.size() >= quota:
			return
		var window_end := mini(window_start + BRIDGE_SPAN_PERIOD, run.size())
		for index in range(window_start, window_end):
			var candidate := run[index]
			if accepted.has(candidate):
				continue
			var length_hash := WarrenPassageLatticeRules.hash_key(world_seed,
				0xB21D6E, candidate, 1)
			var length := mini(1 + (length_hash % 2), run.size() - index)
			var span: Array[Vector3i] = run.slice(index, index + length)
			if _bridge_span_is_legal(massif, excavation, span, directions):
				excavation.bridge_spans.append(span)
				for cell: Vector3i in span:
					accepted[cell] = true
				break
			if length > 1:
				var fallback: Array[Vector3i] = run.slice(index, index + 1)
				if _bridge_span_is_legal(massif, excavation, fallback, directions):
					excavation.bridge_spans.append(fallback)
					accepted[candidate] = true
					break
		window_start += BRIDGE_SPAN_PERIOD


static func _bridge_span_is_legal(massif: WarrenMassif,
		excavation: WarrenExcavation, span: Array[Vector3i],
		directions: Dictionary) -> bool:
	for cell: Vector3i in span:
		var direction := directions.get(cell, Vector2i.ZERO) as Vector2i
		if direction == Vector2i.ZERO:
			return false
		var perpendicular := Vector2i(-direction.y, direction.x)
		var column := Vector2i(cell.x, cell.z)
		var roof_band := cell.y + WarrenPassageLatticeRules.HEADROOM_BANDS
		for flank: Vector2i in [column + perpendicular, column - perpendicular]:
			if not _column_is_solid_at(massif, excavation, flank, cell.y) \
					or not _column_is_solid_at(massif, excavation, flank,
						roof_band):
				return false
		if massif.top_at(column) - cell.y \
				< WarrenPassageLatticeRules.HEADROOM_BANDS + 2:
			return false
	return true


static func _column_is_solid_at(massif: WarrenMassif,
		excavation: WarrenExcavation, column: Vector2i, band: int) -> bool:
	if not massif.has_column(column):
		return false
	if band < massif.base_at(column) or band >= massif.top_at(column):
		return false
	return not excavation.carved.has(Vector3i(column.x, band, column.y))


static func _column_is_public_facade(massif: WarrenMassif,
		excavation: WarrenExcavation, column: Vector2i,
		owner: Vector3i) -> bool:
	for other: Vector3i in excavation.public_cells():
		if other == owner:
			continue
		var distance := absi(other.x - column.x) + absi(other.z - column.y)
		if distance == 1 and _column_carries_house_at(massif, excavation,
				column, other.y):
			return true
	return false


static func _finalize_excavation(massif: WarrenMassif,
		excavation: WarrenExcavation) -> void:
	excavation.portals = [excavation.route[0]] as Array[Vector3i]
	excavation.covered.clear()
	for cell: Vector3i in excavation.public_cells():
		var column := Vector2i(cell.x, cell.z)
		var roof := Vector3i(cell.x,
			cell.y + excavation.slot_bands(cell), cell.z)
		excavation.covered[cell] = massif.top_at(column) > roof.y \
			and not excavation.carved.has(roof)


static func _portal_cells(massif: WarrenMassif, market_cells: int,
		world_seed: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for column_value: Variant in massif.columns.keys():
		var column := column_value as Vector2i
		var base := massif.base_at(column)
		if massif.top_at(column) < base \
				+ WarrenPassageLatticeRules.HEADROOM_BANDS:
			continue
		var exposed := false
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			if not massif.has_column(column + direction):
				exposed = true
				break
		if not exposed:
			continue
		var portal := Vector3i(column.x, base, column.y)
		if _grade_component_size(massif, portal, market_cells) < market_cells:
			continue
		out.append(portal)
	out.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var ar := Vector2(float(a.x), float(a.z)).length()
		var br := Vector2(float(b.x), float(b.z)).length()
		if not is_equal_approx(ar, br):
			return ar < br
		var ah := WarrenPassageLatticeRules.hash_key(world_seed, 0xE17, a)
		var bh := WarrenPassageLatticeRules.hash_key(world_seed, 0xE17, b)
		if ah != bh:
			return ah < bh
		return _cell_less(a, b))
	return out


static func _grade_component_size(massif: WarrenMassif, portal: Vector3i,
		limit: int) -> int:
	var visited: Dictionary = {Vector2i(portal.x, portal.z): true}
	var frontier: Array[Vector2i] = [Vector2i(portal.x, portal.z)]
	while not frontier.is_empty() and visited.size() < limit:
		var column: Vector2i = frontier.pop_back()
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var neighbor := column + direction
			if visited.has(neighbor) or not massif.has_column(neighbor) \
					or massif.base_at(neighbor) != portal.y \
					or massif.top_at(neighbor) < portal.y \
						+ WarrenPassageLatticeRules.HEADROOM_BANDS:
				continue
			visited[neighbor] = true
			frontier.append(neighbor)
	return visited.size()


static func _stride_is_at_grade(massif: WarrenMassif,
		stride: Array[Vector3i]) -> bool:
	for cell: Vector3i in stride:
		if not WarrenPassageLatticeRules.is_at_grade(massif, cell):
			return false
	return true


static func _addressable_sides(massif: WarrenMassif,
		excavation: WarrenExcavation, cell: Vector3i) -> int:
	var out := 0
	for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
		out += int(_column_carries_house_at(massif, excavation,
			Vector2i(cell.x + direction.x, cell.z + direction.y), cell.y))
	return out


static func _column_carries_house_at(massif: WarrenMassif,
		excavation: WarrenExcavation, column: Vector2i,
		street_band: int) -> bool:
	if not massif.has_column(column) or street_band < massif.base_at(column) \
			or street_band + MIN_HOUSE_BANDS > massif.top_at(column):
		return false
	for band in range(street_band, street_band + MIN_HOUSE_BANDS):
		if excavation.carved.has(Vector3i(column.x, band, column.y)):
			return false
	return true


static func _frontage_audit(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Dictionary:
	var capable := _house_capable_column_count(massif, excavation)
	var fronted_columns := _fronted_columns(massif, excavation).size()
	var fronted_passages := 0
	var public := excavation.public_cells()
	for cell: Vector3i in public:
		fronted_passages += int(_addressable_sides(massif,
			excavation, cell) >= 1)
	return {"capable": capable, "fronted": fronted_columns,
		"ratio": float(fronted_passages) / float(maxi(1, public.size())),
		"column_ratio": float(fronted_columns) / float(maxi(1, capable))}


static func _column_frontage_target(
		profile: WarrenVillageScaleProfile) -> float:
	match profile.scale_id:
		WarrenVillageScaleProfile.COMPACT:
			return 0.50
		WarrenVillageScaleProfile.STANDARD:
			return 0.52
		WarrenVillageScaleProfile.LARGE:
			return 0.58
		_:
			return 0.68


static func _house_capable_column_count(massif: WarrenMassif,
		excavation: WarrenExcavation) -> int:
	var out := 0
	for column: Vector2i in massif.columns:
		var run := 0
		var longest := 0
		for band in range(massif.base_at(column), massif.top_at(column)):
			run = run + 1 if not excavation.carved.has(
				Vector3i(column.x, band, column.y)) else 0
			longest = maxi(longest, run)
		out += int(longest >= MIN_HOUSE_BANDS)
	return out


static func _fronted_columns(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in excavation.public_cells():
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var column := Vector2i(cell.x + direction.x,
				cell.z + direction.y)
			if _column_carries_house_at(massif, excavation, column, cell.y):
				out[column] = true
	return out


static func _walk_nodes(excavation: WarrenExcavation) -> Array[Vector3i]:
	var out: Array[Vector3i] = [excavation.route[0]]
	for transition: Dictionary in excavation.transitions:
		out.append(transition.to as Vector3i)
	for lane: Dictionary in excavation.lanes:
		for transition: Dictionary in lane.transitions as Array[Dictionary]:
			out.append(transition.to as Vector3i)
	return out


static func _block_thickness_field(massif: WarrenMassif,
		summit: Vector3i, radius_cells: int) -> Dictionary:
	var out: Dictionary = {}
	var denominator := maxf(1.0, float(radius_cells))
	for column: Vector2i in massif.columns:
		var distance := Vector2(float(column.x - summit.x),
			float(column.y - summit.z)).length()
		var inward := clampf(1.0 - distance / denominator, 0.0, 1.0)
		var weight := smoothstep(0.0, 1.0, inward)
		out[column] = roundi(lerpf(1.5, 3.5, weight))
	return out


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x

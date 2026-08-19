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
const OPEN_AIR_THICKNESS_CEILING := 2

static var last_failure := ""
static var last_diagnostic: Dictionary = {}


static func carve(world_seed: int, massif: WarrenMassif,
		scale_profile: WarrenVillageScaleProfile = null) -> WarrenMazeSourcePlan:
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
	_open_passages_to_air(massif, excavation, thickness,
		forced_open)
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
	if not plan.seal():
		last_failure = "maze source plan rejected: %s" % plan.last_rejection
		last_diagnostic = {"stage": &"source_seal", "audit": plan.audit,
			"lane_count": excavation.lanes.size()}
		return null
	last_diagnostic = plan.audit.duplicate(true)
	last_diagnostic["spine_visits"] = context.visits
	last_diagnostic["lane_count"] = excavation.lanes.size()
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


static func _open_passages_to_air(massif: WarrenMassif,
		excavation: WarrenExcavation, thickness: Dictionary,
		market_zone: Array) -> void:
	var market_set: Dictionary = {}
	for value: Variant in market_zone:
		market_set[value as Vector3i] = true
	for cell: Vector3i in excavation.public_cells():
		var column := Vector2i(cell.x, cell.z)
		var open := market_set.has(cell) \
			or int(thickness.get(column, 2)) <= OPEN_AIR_THICKNESS_CEILING
		# An over/under crossing deliberately uses the solid above one passage
		# as an inhabited facade beside another. Opening that whole column would
		# erase the wall the network already proved and turn a mountain crossing
		# into an unowned shaft.
		if open and _column_is_public_facade(massif, excavation, column, cell):
			open = false
		if not open:
			continue
		for band in range(cell.y, massif.top_at(column)):
			excavation.carved[Vector3i(cell.x, band, cell.z)] = true


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

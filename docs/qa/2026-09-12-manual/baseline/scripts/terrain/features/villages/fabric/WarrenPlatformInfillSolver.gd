class_name WarrenPlatformInfillSolver
extends RefCounted

## Derives small public forecourts from the already accepted volumetric route.
## This pass never invents a second circulation graph: every admitted patch is
## fused to one elevated route square, has clear exterior headroom, and faces
## retained inhabited mass. Selected empty core columns keep one guarded
## 1.5 m daylight well, so closing the central vertical sightline does not turn
## the town into an undifferentiated suspended floor.
## The prelude creates more honest lower street frontage, while upper route
## turns still need enough connected court budget to close every multi-column
## shaft. Optional narrow galleries may cross a lower public route when they
## remain connected to an upper route and terminate at inhabited frontage; this
## produces a real second circulation layer instead of a decorative empty deck.
## Sixteen 3 m patches are the complete town-wide ceiling, and no more than six
## may be optional. Required shaft closure spends this budget first; optional
## galleries may use only the remainder. Facade pockets bounded by buildings on at least two sides are
## likewise legitimate upper courts even when they do not happen to project
## onto the lower itinerary. They remain short route-fused strips with exact
## support and headroom; admitting them avoids leaving accidental vertical
## courtyards as bare shafts merely because the lower route turns beside them.
## This prevents a difficult seed from turning several individually valid short
## runs into one broad suspended upper floor.
const MAX_PATCH_COUNT := 16
const MAX_OPTIONAL_PATCH_COUNT := 6
# Retain several deliberately guarded glimpses into lower levels, but never let
# subtraction turn the repaired central deck network back into a field of
# top-to-ground holes. The bounded-neighbour proof and incremental subtraction
# keep these one fine cell wide and prevent adjacent holes.
const MAX_LIGHTWELL_COUNT := 6
# Lightwells on different height bands still read as one broad vertical shaft
# when their XZ projections overlap or nearly touch. Keep at least two complete
# 1.5 m deck cells between projected openings, independent of elevation.
const MIN_LIGHTWELL_PROJECTED_SEPARATION_CELLS := 3
# A gallery may cross at most six facade-near squares from one route square;
# six is the complete route-plus-gallery strip, not six independent platforms.
# The strip remains one cell wide, so it occludes a lower street without filling
# the surrounding court.
const MAX_PATCHES_PER_ROUTE_CELL := 6
const MAX_ROUTE_REACH := 6
# Ground streets are authored on the 3 m macro lattice. Three connected open
# squares expand to the twelve-cell fine-grid court accepted by the exact visual
# audit; anything larger must be divided before aesthetic court fill can spend
# the remaining budget.
const MAX_UNCOVERED_GROUND_ROUTE_COMPONENT_SIZE := 3
const CARDINALS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT,
	Vector2i.UP, Vector2i.DOWN]
static var last_diagnostic: Dictionary = {}


static func solve(source: WarrenVolumePlan, parcels: WarrenParcelPlan,
		pruning: WarrenPrunedMassPlan,
		optional_patch_limit: int = MAX_OPTIONAL_PATCH_COUNT) -> Dictionary:
	last_diagnostic = {}
	var optional_limit := clampi(optional_patch_limit, 0,
		MAX_OPTIONAL_PATCH_COUNT)
	var empty := {
		"extensions": {},
		"daylight_voids": [] as Array[Vector3i],
		"patch_count": 0,
		"lightwell_count": 0,
		"uncovered_core_column_count": 0,
		"max_uncovered_core_component_size": 0,
		"uncovered_ground_route_cell_count": 0,
		"max_uncovered_ground_route_component_size": 0,
		"required_patch_count": 0,
		"optional_patch_count": 0,
		"over_route_patch_count": 0,
	}
	if source == null or not source.is_sealed() or parcels == null \
			or not parcels.is_sealed() or parcels.source != source \
			or pruning == null or not pruning.is_sealed() \
			or pruning.source != source or pruning.parcels != parcels:
		return empty
	var reserved_fine_cells := _reserved_surface_cells(source, parcels)
	var candidates: Array[Dictionary] = []
	for route_index in source.primary_itinerary.size():
		var route_cell := source.primary_itinerary[route_index]
		if route_cell.y <= source.envelope.ground_at(
				Vector2i(route_cell.x, route_cell.z)):
			continue
		# Flood through legal exterior air rather than sampling four straight
		# spokes.  A shaft can sit around a corner from the route; the retained
		# parent chain becomes the right-angle platform corridor that reaches it.
		var frontier: Array[Dictionary] = [{"cell": route_cell, "distance": 0}]
		var visited: Dictionary = {route_cell: true}
		while not frontier.is_empty():
			var current := frontier.pop_front() as Dictionary
			var parent := current.cell as Vector3i
			var distance := int(current.distance) + 1
			if distance > MAX_ROUTE_REACH:
				continue
			for direction in CARDINALS:
				var candidate := parent + Vector3i(direction.x, 0, direction.y)
				if visited.has(candidate):
					continue
				visited[candidate] = true
				if not _has_clear_pruned_headroom(candidate, source, parcels,
						pruning, reserved_fine_cells):
					continue
				var building_sides := _building_side_count(candidate,
						pruning.building_cells)
				var nearby_buildings := _nearby_building_count(candidate,
					pruning.building_cells)
				var route_sides := _route_side_count(candidate, source)
				var is_open_core_column := pruning.daylight_void_columns.has(
					Vector2i(candidate.x, candidate.z))
				var is_over_lower_route := _has_lower_public_route(candidate, source)
				var is_facade_court := building_sides >= 2
				var score := building_sides * 120 + nearby_buildings * 24 \
					+ route_sides * 35 \
					+ source.envelope.height_at(Vector2i(candidate.x,
						candidate.z)) * 4 + int(is_open_core_column) * 150 \
					+ int(is_over_lower_route) * 220 \
					+ int(is_facade_court) * 180 \
					- (distance - 1) * 55 \
					+ _stable_tie(source.world_seed, candidate)
				candidates.append({
					"route_index": route_index,
					"route_cell": route_cell,
					"cell": candidate,
					"parent": parent,
					"direction": direction,
					"distance": distance,
					"open_core": is_open_core_column,
					"over_lower_route": is_over_lower_route,
					"facade_court": is_facade_court,
					"building_sides": building_sides,
					"nearby_buildings": nearby_buildings,
					"score": score,
				})
				frontier.append({"cell": candidate, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.distance) != int(b.distance):
			return int(a.distance) < int(b.distance)
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return _cell_key(a.cell as Vector3i) < _cell_key(b.cell as Vector3i))
	var claimed_macro: Dictionary = {}
	var claimed_route_counts: Dictionary = {}
	var extensions: Dictionary = {}
	var selected_patches: Array[Dictionary] = []
	# Shaft closure is a hard topology obligation, not an aesthetic score.  Admit
	# the smallest connected candidate bundles that monotonically reduce the
	# largest open core component before spending any budget on optional courts.
	_close_open_core_shafts(candidates, pruning, claimed_macro,
		claimed_route_counts, extensions, selected_patches)
	var required_patch_count := claimed_macro.size()
	# A lower route one square beyond the upper facade is still a useful place
	# for a gallery, but reaching it must commit the intervening facade-bounded
	# square atomically. Admitting only distance-one candidates made the result
	# depend on a lucky exact column overlap and left otherwise dense towns open
	# from roof to street. These short bundles remain route-fused and
	# building-bounded; they cannot become an empty suspended plaza.
	var split_result := _admit_route_splitting_bundles(source, pruning,
		candidates, claimed_macro, claimed_route_counts, extensions,
		selected_patches, optional_limit)
	var optional_patch_count := int(split_result.patch_count)
	var over_route_patch_count := int(split_result.over_route_patch_count)
	var over_route_bundle_result := _admit_short_facade_bundles(source, candidates,
		claimed_macro, claimed_route_counts, extensions, selected_patches,
		optional_limit - optional_patch_count)
	optional_patch_count += int(over_route_bundle_result.patch_count)
	over_route_patch_count += int(
		over_route_bundle_result.over_route_patch_count)
	for value: Dictionary in candidates:
		if claimed_macro.size() >= MAX_PATCH_COUNT \
				or optional_patch_count >= optional_limit:
			break
		var candidate := value.cell as Vector3i
		var route_index := int(value.route_index)
		if int(value.distance) != 1 or int(value.building_sides) < 1 \
				or (not bool(value.open_core) \
					and not bool(value.over_lower_route) \
					and not bool(value.facade_court)) \
				or _column_is_claimed(Vector2i(candidate.x, candidate.z), claimed_macro) \
				or int(claimed_route_counts.get(route_index, 0)) \
					>= MAX_PATCHES_PER_ROUTE_CELL \
				or _selected_neighbor_count(candidate, claimed_macro) >= 3 \
				or _bundle_creates_broad_platform(source,
					[value] as Array[Dictionary], claimed_macro):
			continue
		_commit_candidate(value, claimed_macro, claimed_route_counts,
			extensions, selected_patches)
		optional_patch_count += 1
		over_route_patch_count += int(bool(value.over_lower_route))
	# A daylight well is a subtraction from an already connected court, never a
	# special-case incomplete patch.  Delaying the subtraction until every patch
	# is known lets us prove that each of its four sides is another public surface
	# or an inhabited wall.  Later holes see earlier holes as empty, so two wells
	# cannot invalidate one another after selection.
	var daylight_voids := _carve_bounded_lightwells(source, pruning,
		extensions, selected_patches)
	var uncovered_core_columns := _uncovered_core_columns(pruning,
		claimed_macro)
	var max_uncovered_component := _max_uncovered_core_component(pruning,
		claimed_macro)
	var uncovered_ground_route := _ground_route_opening_audit(source, pruning,
		claimed_macro)
	last_diagnostic = {
		"candidate_count": candidates.size(),
		"open_core_candidate_count": _open_core_candidate_count(candidates),
		"over_route_candidates_by_distance": _over_route_candidates_by_distance(
			candidates),
		"near_over_route_candidates": _near_over_route_candidate_keys(candidates),
		"selected_columns": _column_keys(claimed_macro),
		"uncovered_columns": _uncovered_column_keys(pruning, claimed_macro),
		"elevated_route_columns": _elevated_route_keys(source),
		"uncovered_ground_route": uncovered_ground_route,
	}
	return {
		"extensions": extensions,
		"daylight_voids": daylight_voids,
		"patch_count": claimed_macro.size(),
		"lightwell_count": daylight_voids.size(),
		"uncovered_core_column_count": uncovered_core_columns,
		"max_uncovered_core_component_size": max_uncovered_component,
		"uncovered_ground_route_cell_count": int(
			uncovered_ground_route.remaining),
		"max_uncovered_ground_route_component_size": int(
			uncovered_ground_route.maximum),
		"required_patch_count": required_patch_count,
		"optional_patch_count": optional_patch_count,
		"over_route_patch_count": over_route_patch_count,
}


static func _admit_route_splitting_bundles(source: WarrenVolumePlan,
		pruning: WarrenPrunedMassPlan, candidates: Array[Dictionary],
		claimed_macro: Dictionary, claimed_route_counts: Dictionary,
		extensions: Dictionary, selected_patches: Array[Dictionary],
		optional_limit: int) -> Dictionary:
	## Treat the visible opening as topology. Until every uncovered ground-street
	## component is a short court, choose the legal connected gallery which most
	## reduces the largest component. Scores break ties only after topology, so a
	## pretty facade pocket can never consume the one patch needed to divide a
	## roof-to-ground street.
	var patch_count := 0
	var over_route_patch_count := 0
	while claimed_macro.size() < MAX_PATCH_COUNT \
			and patch_count < optional_limit:
		var current := _ground_route_opening_audit(source, pruning, claimed_macro)
		if int(current.maximum) \
				<= MAX_UNCOVERED_GROUND_ROUTE_COMPONENT_SIZE:
			break
		var best_bundle: Array[Dictionary] = []
		var best_maximum := int(current.maximum)
		var best_remaining := int(current.remaining)
		var best_score := -INF
		var best_key := ""
		for value: Dictionary in candidates:
			if not bool(value.over_lower_route):
				continue
			var bundle := _optional_bundle(value, candidates, claimed_macro)
			if bundle.is_empty() \
					or claimed_macro.size() + bundle.size() > MAX_PATCH_COUNT \
					or patch_count + bundle.size() > optional_limit \
					or not _optional_bundle_is_admissible(source, value, bundle,
						claimed_macro, claimed_route_counts):
				continue
			var prospective := claimed_macro.duplicate()
			var bundle_score := 0.0
			var key_parts := PackedStringArray()
			for member: Dictionary in bundle:
				var member_cell := member.cell as Vector3i
				prospective[member_cell] = true
				bundle_score += float(member.score)
				key_parts.append(_cell_key(member_cell))
			var result := _ground_route_opening_audit(source, pruning, prospective)
			if int(result.maximum) > best_maximum \
					or (int(result.maximum) == best_maximum \
						and int(result.remaining) >= best_remaining):
				continue
			var key := ",".join(key_parts)
			var is_better := int(result.maximum) < best_maximum \
				or (int(result.maximum) == best_maximum \
					and int(result.remaining) < best_remaining) \
				or (int(result.maximum) == best_maximum \
					and int(result.remaining) == best_remaining \
					and (best_bundle.is_empty() \
						or bundle.size() < best_bundle.size())) \
				or (int(result.maximum) == best_maximum \
					and int(result.remaining) == best_remaining \
					and bundle.size() == best_bundle.size() \
					and (bundle_score > best_score \
						or (is_equal_approx(bundle_score, best_score) \
							and key < best_key)))
			if is_better:
				best_bundle = bundle
				best_maximum = int(result.maximum)
				best_remaining = int(result.remaining)
				best_score = bundle_score
				best_key = key
		if best_bundle.is_empty():
			break
		for member: Dictionary in best_bundle:
			assert(_commit_candidate(member, claimed_macro,
				claimed_route_counts, extensions, selected_patches))
			patch_count += 1
			over_route_patch_count += int(bool(member.over_lower_route))
	return {
		"patch_count": patch_count,
		"over_route_patch_count": over_route_patch_count,
	}


static func _admit_short_facade_bundles(source: WarrenVolumePlan,
		candidates: Array[Dictionary],
		claimed_macro: Dictionary, claimed_route_counts: Dictionary,
		extensions: Dictionary,
		selected_patches: Array[Dictionary], optional_limit: int) -> Dictionary:
	var patch_count := 0
	var over_route_patch_count := 0
	# The topology pass above has already divided every reachable long opening.
	# Spend only the remaining budget here on compact facade courts, preserving a
	# stable preference for useful lower-route overlap.
	var ranked: Array[Dictionary] = []
	ranked.assign(candidates)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.over_lower_route) != bool(b.over_lower_route):
			return bool(a.over_lower_route)
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		if int(a.distance) != int(b.distance):
			return int(a.distance) < int(b.distance)
		return _cell_key(a.cell as Vector3i) < _cell_key(b.cell as Vector3i))
	for value: Dictionary in ranked:
		if claimed_macro.size() >= MAX_PATCH_COUNT \
				or patch_count >= optional_limit:
			break
		if (not bool(value.over_lower_route) \
				and not bool(value.facade_court)) or int(value.distance) < 2 \
				or int(value.distance) > MAX_ROUTE_REACH \
				or int(value.building_sides) < 1:
			continue
		var bundle := _optional_bundle(value, candidates, claimed_macro)
		if bundle.size() < 2 or bundle.size() > MAX_ROUTE_REACH \
				or claimed_macro.size() + bundle.size() > MAX_PATCH_COUNT \
				or patch_count + bundle.size() > optional_limit \
				or not _optional_bundle_is_admissible(source, value, bundle,
					claimed_macro, claimed_route_counts):
			continue
		for member: Dictionary in bundle:
			assert(_commit_candidate(member, claimed_macro,
				claimed_route_counts, extensions, selected_patches))
			patch_count += 1
			over_route_patch_count += int(bool(member.over_lower_route))
	return {
		"patch_count": patch_count,
		"over_route_patch_count": over_route_patch_count,
	}


static func _optional_bundle(value: Dictionary,
		candidates: Array[Dictionary], claimed_macro: Dictionary) \
		-> Array[Dictionary]:
	return [value] as Array[Dictionary] if int(value.distance) == 1 \
		else _connected_bundle(value, candidates, claimed_macro)


static func _optional_bundle_is_admissible(source: WarrenVolumePlan,
		value: Dictionary,
		bundle: Array[Dictionary], claimed_macro: Dictionary,
		claimed_route_counts: Dictionary) -> bool:
	# A gallery is a path, not a replacement ground plane. Test the complete
	# atomic bundle against both earlier infill and the sealed route: it may turn,
	# branch, or end in a square facade landing, but may never complete a 2 x 2
	# macro deck. That local invariant prevents many individually plausible
	# patches from merging into the empty suspended plazas caught by visual QA.
	if _bundle_creates_broad_platform(source, bundle, claimed_macro):
		return false
	var route_additions: Dictionary = {}
	var prospective := claimed_macro.duplicate()
	for member_index in bundle.size():
		var member := bundle[member_index]
		var cell := member.cell as Vector3i
		var route_index := int(member.route_index)
		var is_destination := member_index == bundle.size() - 1
		# A real facade destination touches a building. Its connected approach may
		# cross one narrow open square, but must remain inside the measured building
		# neighborhood and may never create a broad platform node.
		var destination_side_minimum := 1 \
			if bool(value.over_lower_route) else 2
		if (is_destination \
				and int(member.building_sides) < destination_side_minimum) \
				or (not is_destination and int(member.nearby_buildings) < 1) \
				or _column_is_claimed(Vector2i(cell.x, cell.z), prospective) \
				or _selected_neighbor_count(cell, prospective) >= 3:
			return false
		prospective[cell] = true
		route_additions[route_index] = int(route_additions.get(
			route_index, 0)) + 1
	for route_index_value: Variant in route_additions.keys():
		var route_index := int(route_index_value)
		if int(claimed_route_counts.get(route_index, 0)) \
				+ int(route_additions[route_index]) \
				> MAX_PATCHES_PER_ROUTE_CELL:
			return false
	return true


static func _bundle_creates_broad_platform(source: WarrenVolumePlan,
		bundle: Array[Dictionary], claimed_macro: Dictionary) -> bool:
	var prospective := claimed_macro.duplicate()
	for member: Dictionary in bundle:
		prospective[member.cell as Vector3i] = true
	for member: Dictionary in bundle:
		var cell := member.cell as Vector3i
		for offset_x in [-1, 0]:
			for offset_z in [-1, 0]:
				var corner := Vector3i(cell.x + offset_x, cell.y,
					cell.z + offset_z)
				var fills_square := true
				for x in 2:
					for z in 2:
						var square := corner + Vector3i(x, 0, z)
						if not prospective.has(square) \
								and not source.has_walk(square):
							fills_square = false
							break
					if not fills_square:
						break
				if fills_square:
					return true
	return false


static func _ground_route_opening_audit(source: WarrenVolumePlan,
		pruning: WarrenPrunedMassPlan, claimed_macro: Dictionary) -> Dictionary:
	var remaining: Dictionary = {}
	for walk: Vector3i in source.walk_cells:
		var column := Vector2i(walk.x, walk.z)
		if walk.y != source.envelope.ground_at(column) \
				or source.landing_cells.has(walk) \
				or _ground_route_has_overhead(walk, pruning, claimed_macro):
			continue
		remaining[walk] = true
	var remaining_count := remaining.size()
	var maximum := 0
	while not remaining.is_empty():
		var start := remaining.keys().front() as Vector3i
		remaining.erase(start)
		var frontier: Array[Vector3i] = [start]
		var size := 0
		while not frontier.is_empty():
			var current: Vector3i = frontier.pop_back()
			size += 1
			for direction: Vector2i in CARDINALS:
				var neighbor := current + Vector3i(direction.x, 0, direction.y)
				if remaining.erase(neighbor):
					frontier.append(neighbor)
		maximum = maxi(maximum, size)
	return {"maximum": maximum, "remaining": remaining_count}


static func _ground_route_has_overhead(walk: Vector3i,
		pruning: WarrenPrunedMassPlan, claimed_macro: Dictionary) -> bool:
	for rise in range(WarrenVolumePlan.HEADROOM_BANDS, 7):
		if pruning.building_cells.has(walk + Vector3i.UP * rise):
			return true
	for cell_value: Variant in claimed_macro.keys():
		var cell := cell_value as Vector3i
		var rise := cell.y - walk.y
		if cell.x == walk.x and cell.z == walk.z \
				and rise >= WarrenVolumePlan.HEADROOM_BANDS and rise <= 6:
			return true
	return false


static func _open_core_candidate_count(candidates: Array[Dictionary]) -> int:
	var result := 0
	for candidate: Dictionary in candidates:
		result += int(bool(candidate.open_core))
	return result


static func _over_route_candidates_by_distance(
		candidates: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for candidate: Dictionary in candidates:
		if not bool(candidate.over_lower_route) \
				or int(candidate.building_sides) < 1:
			continue
		var distance := int(candidate.distance)
		result[distance] = int(result.get(distance, 0)) + 1
	return result


static func _near_over_route_candidate_keys(
		candidates: Array[Dictionary]) -> PackedStringArray:
	var result := PackedStringArray()
	for candidate: Dictionary in candidates:
		if not bool(candidate.over_lower_route) \
				or int(candidate.distance) > MAX_ROUTE_REACH:
			continue
		result.append("%s<- %s d=%d sides=%d route=%d" % [
			_cell_key(candidate.cell as Vector3i),
			_cell_key(candidate.parent as Vector3i), int(candidate.distance),
			int(candidate.building_sides), int(candidate.route_index)])
	result.sort()
	return result


static func _column_keys(cells: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for cell_value: Variant in cells.keys():
		var cell := cell_value as Vector3i
		out.append("%d:%d@%d" % [cell.x, cell.z, cell.y])
	out.sort()
	return out


static func _uncovered_column_keys(pruning: WarrenPrunedMassPlan,
		claimed_macro: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for column_value: Variant in pruning.daylight_void_columns.keys():
		var column := column_value as Vector2i
		if not _column_is_claimed(column, claimed_macro):
			out.append("%d:%d" % [column.x, column.y])
	out.sort()
	return out


static func _elevated_route_keys(source: WarrenVolumePlan) -> PackedStringArray:
	var out := PackedStringArray()
	for cell: Vector3i in source.primary_itinerary:
		if cell.y > source.envelope.ground_at(Vector2i(cell.x, cell.z)):
			out.append("%d:%d@%d" % [cell.x, cell.z, cell.y])
	out.sort()
	return out


static func _close_open_core_shafts(candidates: Array[Dictionary],
		pruning: WarrenPrunedMassPlan, claimed_macro: Dictionary,
		claimed_route_counts: Dictionary, extensions: Dictionary,
		selected_patches: Array[Dictionary]) -> void:
	while claimed_macro.size() < MAX_PATCH_COUNT:
		var current_remaining := _uncovered_core_columns(pruning, claimed_macro)
		if current_remaining == 0:
			return
		var current_max := _max_uncovered_core_component(pruning, claimed_macro)
		var best_bundle: Array[Dictionary] = []
		var best_max := current_max
		var best_remaining := current_remaining
		var best_score := -INF
		var best_key := ""
		for value: Dictionary in candidates:
			if not bool(value.open_core):
				continue
			var bundle := _connected_bundle(value, candidates, claimed_macro)
			if bundle.is_empty() \
					or claimed_macro.size() + bundle.size() > MAX_PATCH_COUNT:
				continue
			var prospective := claimed_macro.duplicate()
			var bundle_score := 0.0
			var bundle_key_parts := PackedStringArray()
			for member: Dictionary in bundle:
				var member_cell := member.cell as Vector3i
				prospective[member_cell] = true
				bundle_score += float(member.score)
				bundle_key_parts.append(_cell_key(member_cell))
			var result_max := _max_uncovered_core_component(pruning, prospective)
			var result_remaining := _uncovered_core_columns(pruning, prospective)
			var bundle_key := ",".join(bundle_key_parts)
			var is_better := result_max < best_max \
				or (result_max == best_max and result_remaining < best_remaining) \
				or (result_max == best_max and result_remaining == best_remaining \
					and bundle.size() < best_bundle.size()) \
				or (result_max == best_max and result_remaining == best_remaining \
					and bundle.size() == best_bundle.size() \
					and (bundle_score > best_score \
						or (is_equal_approx(bundle_score, best_score) \
							and bundle_key < best_key)))
			if is_better:
				best_bundle = bundle
				best_max = result_max
				best_remaining = result_remaining
				best_score = bundle_score
				best_key = bundle_key
		if best_bundle.is_empty() \
				or (best_max == current_max and best_remaining >= current_remaining):
			return
		for member: Dictionary in best_bundle:
			_commit_candidate(member, claimed_macro, claimed_route_counts,
				extensions, selected_patches)


static func _connected_bundle(value: Dictionary,
		candidates: Array[Dictionary], claimed_macro: Dictionary) -> Array[Dictionary]:
	var cell := value.cell as Vector3i
	if _column_is_claimed(Vector2i(cell.x, cell.z), claimed_macro):
		return []
	var reversed: Array[Dictionary] = [value]
	var cursor := value
	while int(cursor.distance) > 1:
		var parent := cursor.parent as Vector3i
		if claimed_macro.has(parent):
			break
		if _column_is_claimed(Vector2i(parent.x, parent.z), claimed_macro):
			return []
		var parent_candidate: Dictionary = {}
		for candidate: Dictionary in candidates:
			if int(candidate.route_index) == int(value.route_index) \
					and (candidate.cell as Vector3i) == parent:
				parent_candidate = candidate
				break
		if parent_candidate.is_empty():
			return []
		reversed.append(parent_candidate)
		cursor = parent_candidate
	var out: Array[Dictionary] = []
	for index in range(reversed.size() - 1, -1, -1):
		out.append(reversed[index])
	return out


static func _commit_candidate(value: Dictionary, claimed_macro: Dictionary,
		claimed_route_counts: Dictionary, extensions: Dictionary,
		selected_patches: Array[Dictionary]) -> bool:
	var candidate := value.cell as Vector3i
	if _column_is_claimed(Vector2i(candidate.x, candidate.z), claimed_macro):
		return false
	if int(value.distance) > 1 \
			and not claimed_macro.has(value.parent as Vector3i):
		return false
	var route_cell := value.route_cell as Vector3i
	if not extensions.has(route_cell):
		extensions[route_cell] = [] as Array[Vector3i]
	(extensions[route_cell] as Array[Vector3i]).append_array(
		_expand_macro_cell(candidate))
	selected_patches.append({
		"route_cell": route_cell,
		"cell": candidate,
		"open_core": bool(value.open_core),
		"over_lower_route": bool(value.get("over_lower_route", false)),
		"score": int(value.score),
	})
	claimed_macro[candidate] = true
	var route_index := int(value.route_index)
	claimed_route_counts[route_index] = int(claimed_route_counts.get(
		route_index, 0)) + 1
	return true


static func _uncovered_core_columns(pruning: WarrenPrunedMassPlan,
		claimed_macro: Dictionary) -> int:
	var result := 0
	for column_value: Variant in pruning.daylight_void_columns.keys():
		result += int(not _column_is_claimed(column_value as Vector2i,
			claimed_macro))
	return result


static func _max_uncovered_core_component(pruning: WarrenPrunedMassPlan,
		claimed_macro: Dictionary) -> int:
	var remaining: Dictionary = {}
	for column_value: Variant in pruning.daylight_void_columns.keys():
		var column := column_value as Vector2i
		if not _column_is_claimed(column, claimed_macro):
			remaining[column] = true
	var largest := 0
	while not remaining.is_empty():
		var frontier: Array[Vector2i] = [remaining.keys().front() as Vector2i]
		remaining.erase(frontier.front())
		var size := 0
		while not frontier.is_empty():
			var column: Vector2i = frontier.pop_back()
			size += 1
			for direction: Vector2i in CARDINALS:
				var neighbor: Vector2i = column + direction
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					frontier.append(neighbor)
		largest = maxi(largest, size)
	return largest


static func _column_is_claimed(column: Vector2i,
		claimed_macro: Dictionary) -> bool:
	for cell_value: Variant in claimed_macro.keys():
		var cell := cell_value as Vector3i
		if Vector2i(cell.x, cell.z) == column:
			return true
	return false


static func _has_clear_pruned_headroom(cell: Vector3i,
		source: WarrenVolumePlan, parcels: WarrenParcelPlan,
		pruning: WarrenPrunedMassPlan, reserved_fine_cells: Dictionary) -> bool:
	var column := Vector2i(cell.x, cell.z)
	# An upper gallery normally stays inside the inhabited core. The one legal
	# fringe exception is a cell directly sheltering an already-sealed lower
	# public route: this lets a connected platform follow the market arcade far
	# enough to break its roof-to-ground shaft without authorizing an arbitrary
	# empty suspended terrace beyond the town.
	if (not parcels.urban_core_columns.has(column) \
			and not _has_lower_public_route(cell, source)) \
			or source.has_walk(cell) \
			or cell.y < source.envelope.ground_at(column):
		return false
	for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
		var air_cell := cell + Vector3i.UP * y_offset
		# The Gaussian envelope is provisional mass, not a rendered solid. Its
		# exhaustive pruning classification is authoritative: retained building and
		# bearing cells block headroom, while PRUNED_EXTERIOR_AIR and OUTSIDE_CORE
		# are both empty. The outer classification is reachable here only through
		# the direct-lower-route fringe gate above, so this cannot authorize a free
		# suspended platform beyond the town.
		var classification := pruning.classification_at(air_cell)
		if classification in [
				WarrenPrunedMassPlan.Classification.BUILDING,
				WarrenPrunedMassPlan.Classification.BEARING_OPPORTUNITY]:
			return false
		for fine_cell in _expand_macro_cell(air_cell):
			if reserved_fine_cells.has(fine_cell):
				return false
	return true


static func _building_side_count(cell: Vector3i,
		building_cells: Dictionary) -> int:
	var result := 0
	for direction in CARDINALS:
		var neighbor := cell + Vector3i(direction.x, 0, direction.y)
		var bounded := false
		for y_offset in [-1, 0, 1, 2]:
			bounded = bounded or building_cells.has(
				neighbor + Vector3i.UP * y_offset)
		result += int(bounded)
	return result


static func _nearby_building_count(cell: Vector3i,
		building_cells: Dictionary) -> int:
	var result := 0
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var distance := absi(dx) + absi(dz)
			if distance == 0 or distance > 2:
				continue
			var found := false
			for y_offset in [-1, 0, 1, 2]:
				found = found or building_cells.has(cell
					+ Vector3i(dx, y_offset, dz))
			result += int(found)
	return result


static func _route_side_count(cell: Vector3i,
		source: WarrenVolumePlan) -> int:
	var result := 0
	for direction in CARDINALS:
		result += int(source.has_walk(
			cell + Vector3i(direction.x, 0, direction.y)))
	return result


static func _has_lower_public_route(cell: Vector3i,
		source: WarrenVolumePlan) -> bool:
	for walk: Vector3i in source.walk_cells:
		if walk.x == cell.x and walk.z == cell.z \
				and cell.y - walk.y >= WarrenVolumePlan.HEADROOM_BANDS:
			return true
	return false


static func _selected_neighbor_count(cell: Vector3i,
		selected: Dictionary) -> int:
	var result := 0
	for direction in CARDINALS:
		result += int(selected.has(
			cell + Vector3i(direction.x, 0, direction.y)))
	return result


static func _reserved_surface_cells(source: WarrenVolumePlan,
		parcels: WarrenParcelPlan) -> Dictionary:
	var out: Dictionary = {}
	for reservation: Dictionary in parcels.connection_reservations:
		for value: Variant in (reservation.reserved_cells as Dictionary).keys():
			out[value as Vector3i] = true
	# Platform discovery runs before the public-realm adapter, but its candidate
	# surfaces must still avoid the exact stairs/ramps that adapter will compile.
	# Reserve both the transition floor and its player-height air from the one
	# canonical footprint owned by WarrenVolumeTransition.
	for transition: WarrenVolumeTransition in source.transitions:
		for surface: Vector3i in transition.surface_cells():
			for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
				out[surface + Vector3i.UP * y_offset] = true
	return out


static func _expand_macro_cell(cell: Vector3i) -> Array[Vector3i]:
	var origin := Vector3i(cell.x * 2, cell.y, cell.z * 2)
	return [origin, origin + Vector3i.RIGHT, origin + Vector3i.BACK,
		origin + Vector3i(1, 0, 1)] as Array[Vector3i]


static func _carve_bounded_lightwells(source: WarrenVolumePlan,
		pruning: WarrenPrunedMassPlan, extensions: Dictionary,
		selected_patches: Array[Dictionary]) -> Array[Vector3i]:
	var public_surfaces: Dictionary = {}
	for macro_cell: Vector3i in source.primary_itinerary:
		if macro_cell.y == source.envelope.ground_at(
				Vector2i(macro_cell.x, macro_cell.z)):
			continue
		for fine_cell: Vector3i in _expand_macro_cell(macro_cell):
			public_surfaces[fine_cell] = true
	for values_value: Variant in extensions.values():
		for fine_cell: Vector3i in values_value as Array[Vector3i]:
			public_surfaces[fine_cell] = true
	var structural_solids := _expanded_building_cells(pruning.building_cells)
	selected_patches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.open_core) != bool(b.open_core):
			return bool(a.open_core)
		if int(a.cell.y) != int(b.cell.y):
			return int(a.cell.y) > int(b.cell.y)
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return _cell_key(a.cell as Vector3i) < _cell_key(b.cell as Vector3i))
	var out: Array[Vector3i] = []
	for patch: Dictionary in selected_patches:
		if out.size() >= MAX_LIGHTWELL_COUNT:
			break
		var macro_cell := patch.cell as Vector3i
		if macro_cell.y < 2:
			continue
		var candidates := _expand_macro_cell(macro_cell)
		candidates.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			var a_tie := _stable_tie(source.world_seed, a)
			var b_tie := _stable_tie(source.world_seed, b)
			return a_tie < b_tie if a_tie != b_tie else _cell_key(a) < _cell_key(b))
		for hole: Vector3i in candidates:
			if _near_projected_lightwell(hole, out):
				continue
			if not _is_bounded_lightwell(hole, public_surfaces,
					structural_solids):
				continue
			public_surfaces.erase(hole)
			var route_cell := patch.route_cell as Vector3i
			(extensions[route_cell] as Array[Vector3i]).erase(hole)
			# Four visually bounded sides are not sufficient: three of those
			# sides may be building walls while the fourth is the only one-cell
			# neck back to the route.  Removing that neck creates an attractive
			# looking but unreachable island, which the exact exterior-air proof
			# must reject.  Admit a daylight opening only when every surviving
			# extension cell remains horizontally connected to the route square
			# that owns the patch.
			if not _extensions_remain_route_connected(extensions):
				(extensions[route_cell] as Array[Vector3i]).append(hole)
				public_surfaces[hole] = true
				continue
			out.append(hole)
			break
	out.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return _cell_key(a) < _cell_key(b))
	return out


static func _near_projected_lightwell(candidate: Vector3i,
		existing: Array[Vector3i]) -> bool:
	for lightwell: Vector3i in existing:
		var distance := absi(candidate.x - lightwell.x) \
			+ absi(candidate.z - lightwell.z)
		if distance < MIN_LIGHTWELL_PROJECTED_SEPARATION_CELLS:
			return true
	return false


static func _extensions_remain_route_connected(extensions: Dictionary) -> bool:
	for route_value: Variant in extensions.keys():
		var route_cell := route_value as Vector3i
		var extension_cells := extensions[route_cell] as Array[Vector3i]
		if extension_cells.is_empty():
			continue
		var node_surfaces: Dictionary = {}
		var pending: Array[Vector3i] = []
		for route_surface: Vector3i in _expand_macro_cell(route_cell):
			node_surfaces[route_surface] = true
			pending.append(route_surface)
		for extension_cell: Vector3i in extension_cells:
			node_surfaces[extension_cell] = true
		var reached: Dictionary = {}
		for route_surface: Vector3i in pending:
			reached[route_surface] = true
		while not pending.is_empty():
			var current: Vector3i = pending.pop_back()
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor := current + direction
				if node_surfaces.has(neighbor) and not reached.has(neighbor):
					reached[neighbor] = true
					pending.append(neighbor)
		for extension_cell: Vector3i in extension_cells:
			if not reached.has(extension_cell):
				return false
	return true


static func _is_bounded_lightwell(cell: Vector3i,
		public_surfaces: Dictionary, structural_solids: Dictionary) -> bool:
	for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
			Vector3i.FORWARD, Vector3i.BACK]:
		var neighbor: Vector3i = cell + direction
		if not public_surfaces.has(neighbor) \
				and not structural_solids.has(neighbor) \
				and not structural_solids.has(neighbor + Vector3i.UP):
			return false
	return true


static func _expanded_building_cells(macro_cells: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for value: Variant in macro_cells.keys():
		for cell: Vector3i in _expand_macro_cell(value as Vector3i):
			out[cell] = true
	return out


static func _stable_tie(world_seed: int, cell: Vector3i) -> int:
	return posmod(world_seed * 31 + cell.x * 101 + cell.y * 47
		+ cell.z * 193, 29)


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]

class_name WarrenGroundArcadeSolver
extends RefCounted

## Carves two connected terrain-level market branches into a sealed volumetric
## route *before* parcels are selected. Buildings therefore compete around the
## real public void instead of an alley being pushed through whatever residual
## lawn happened to remain after massing. The completed parcel plan is then
## checked against exact room/bearing facts; elevated footprints do not count
## as eye-level frontage merely because their projection is nearby.
##
## The primary branch crosses enough of the central mass to divide broad
## unaddressable cavities. A shorter branch starts from a spatially separated
## point on the same public itinerary, preventing the opposite lower approach
## from surviving as an empty undercroft corridor. Both remain parts of one
## connected route graph, and both exist before building/market selection.
const MIN_CELLS := 7
const TARGET_CELLS := 8
const SECONDARY_MIN_CELLS := 4
const SECONDARY_TARGET_CELLS := 5
const MIN_BRANCH_SEPARATION_CELLS := 4
const ROOT_FRONTIER := 12
const MAX_SEARCH_VISITS_PER_ROOT := 512
# Four addressed arcade intervals are enough to create two building-bounded
# turns; the later stocked-market transaction closes the remaining edges. A
# ratio made the same valid four-facade composition fail merely because the
# deterministic branch found nine cells instead of seven.
const MIN_GROUNDED_FRONTAGE_CELLS := 4
const MIN_ENCLOSED_CELLS := 4
const MIN_TURN_COUNT := 2
# At least two cells of the lower market alleys must run beneath the already
# sealed climbing itinerary.  Those crossings make one public level the roof of
# another and split the vertical sightline before any optional building detail
# is selected.  A branch which merely wanders beside the main route is an open
# street on a lawn, regardless of how many props later line it.
## Route-first's value, and the default every envelope this solver sees carries
## unless a synthesised one lowers it -- see
## WarrenVolumeEnvelope.DEFAULT_UPPER_ROUTE_CROSSOVERS and
## WarrenMassif.UPPER_ROUTE_CROSSOVERS.
const MIN_UPPER_ROUTE_CROSSOVERS := 2


static func _required_crossovers(source: WarrenVolumePlan) -> int:
	return source.envelope.upper_route_crossovers if source != null \
		and source.envelope != null else MIN_UPPER_ROUTE_CROSSOVERS
# Carving an auxiliary branch parallel to a terrain-level primary street spends
# the exact mass which its facades need.  The root must leave that street once;
# subsequent cells are ranked away from it so the two alleys bound different
# faces of the same compact building mass instead of merging into an open plaza.
const PRIMARY_GROUND_PROXIMITY_PENALTY := 760.0
const CARDINALS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]
static var last_failure := ""


static func extend(source: WarrenVolumePlan) -> WarrenVolumePlan:
	last_failure = ""
	if source == null or not source.is_sealed():
		last_failure = "missing sealed public route"
		return null
	var branch := _find_path(source, TARGET_CELLS, MIN_CELLS, false)
	var path: Array[Vector3i] = []
	path.assign(branch.get("path", []) as Array)
	var root := branch.get("root", Vector3i(2147483647, 0, 0)) as Vector3i
	if path.size() + 1 < MIN_CELLS:
		last_failure = "no complete winding ground arcade"
		return null
	var first := _clone_volume(source, root, path, 0)
	if first == null:
		last_failure = "ground arcade failed volume transaction"
		return null
	# One branch can leave the opposite side of a tall Gaussian core as raw
	# undercroft lawn. Carve a shorter, spatially separated second branch before
	# parcelization so both lower approaches compete for grounded facades. This
	# remains one connected public graph; it is not a detached market prop or a
	# post-hoc blocker inserted after buildings exist.
	# Four- and five-cell branches are separate sectional grammar families. The
	# seed chooses between them before parcelization; exact construction still
	# owns every shared validity gate. Keeping both families avoids making either
	# a universal shape that starves the parcel frontier on the opposite core
	# profile.
	var secondary_target := SECONDARY_MIN_CELLS + posmod(source.world_seed,
		SECONDARY_TARGET_CELLS - SECONDARY_MIN_CELLS + 1)
	var secondary := _find_path(first, secondary_target,
		SECONDARY_MIN_CELLS, true)
	var secondary_path: Array[Vector3i] = []
	secondary_path.assign(secondary.get("path", []) as Array)
	var secondary_root := secondary.get("root",
		Vector3i(2147483647, 0, 0)) as Vector3i
	if secondary_path.size() + 1 < SECONDARY_MIN_CELLS:
		last_failure = "no separated secondary ground arcade"
		return null
	var result := _clone_volume(first, secondary_root, secondary_path, 1)
	if result == null:
		last_failure = "secondary ground arcade failed volume transaction"
		return null
	if int(result.audit.get("ground_arcade_upper_crossover_count", 0)) \
			< _required_crossovers(source):
		last_failure = "ground arcades do not pass beneath the climbing itinerary"
		return null
	return result


static func parcels_enclose_arcade(parcels: WarrenParcelPlan) -> bool:
	var audit := arcade_enclosure_audit(parcels)
	return bool(audit.get("passes", false))


static func arcade_enclosure_audit(parcels: WarrenParcelPlan) -> Dictionary:
	if parcels == null or not parcels.is_sealed():
		return {"passes": false, "cell_count": 0, "qualified_ratio": 0.0,
			"grounded_ratio": 0.0}
	var auxiliary: Array[Vector3i] = []
	auxiliary.assign(parcels.source.ground_arcade_cells)
	if auxiliary.size() + 2 < MIN_CELLS + SECONDARY_MIN_CELLS:
		return {"passes": false, "cell_count": auxiliary.size(),
			"qualified_ratio": 0.0, "grounded_ratio": 0.0}
	var grounded := 0
	var qualified := 0
	for cell: Vector3i in auxiliary:
		var has_grounded_frontage := _grounded_frontage_count(cell, parcels) > 0
		var has_cover := _overhead_building_count(cell, parcels) > 0
		grounded += int(has_grounded_frontage)
		qualified += int(has_grounded_frontage or has_cover)
	# Stocked market prefabs are admitted by the later exact transaction and can
	# close the remaining route edges. Require enough real building-owned
	# intervals to bound both turns now, without pretending the pre-market parcel
	# stage is the final facade audit.
	var qualified_ratio := float(qualified) / float(auxiliary.size())
	var grounded_ratio := float(grounded) / float(auxiliary.size())
	return {"passes": qualified >= MIN_ENCLOSED_CELLS \
			and grounded >= MIN_GROUNDED_FRONTAGE_CELLS,
		"cell_count": auxiliary.size(), "qualified_count": qualified,
		"grounded_count": grounded, "qualified_ratio": qualified_ratio,
		"grounded_ratio": grounded_ratio}


static func _find_path(source: WarrenVolumePlan, target_cells: int,
		minimum_cells: int, prefer_separated_root: bool) -> Dictionary:
	var best: Dictionary = {}
	var roots: Array[Dictionary] = []
	var existing_auxiliary: Array[Vector3i] = []
	for cell: Vector3i in source.walk_cells:
		if not source.primary_itinerary.has(cell):
			existing_auxiliary.append(cell)
	for root: Vector3i in source.primary_itinerary:
		var column := Vector2i(root.x, root.z)
		if root.y != source.envelope.ground_at(column):
			continue
		var separation := _distance_to_cells(root, existing_auxiliary)
		if prefer_separated_root \
				and separation < MIN_BRANCH_SEPARATION_CELLS:
			continue
		roots.append({"cell": root, "score": _root_score(root, source) \
			- (float(separation) * 480.0 if prefer_separated_root else 0.0)})
	roots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.score), float(b.score)):
			return float(a.score) < float(b.score)
		return _cell_key(a.cell as Vector3i) < _cell_key(b.cell as Vector3i))
	if roots.size() > ROOT_FRONTIER:
		roots.resize(ROOT_FRONTIER)
	for target_count in range(target_cells, minimum_cells - 1, -1):
		var best_score := INF
		for root_value: Dictionary in roots:
			var root := root_value.cell as Vector3i
			var path: Array[Vector3i] = []
			var visited: Dictionary = {root: true}
			var budget := {"visits": 0}
			_search(source, root, Vector2i.ZERO, 0, target_count - 1, visited,
				[] as Array[Vector3i], path, budget)
			if path.size() + 1 < target_count:
				continue
			var score := _path_score(root, path, source)
			if best.is_empty() or score < best_score:
				best = {"root": root, "path": path}
				best_score = score
		if not best.is_empty():
			break
	return best


static func _root_score(root: Vector3i, source: WarrenVolumePlan) -> float:
	var column := Vector2i(root.x, root.z)
	return Vector2(float(root.x), float(root.z)).length() * 120.0 \
		- float(source.envelope.height_at(column)) * 24.0


static func _distance_to_cells(root: Vector3i,
		cells: Array[Vector3i]) -> int:
	if cells.is_empty():
		return 0
	var result := 2147483647
	for cell: Vector3i in cells:
		result = mini(result, absi(cell.x - root.x) + absi(cell.z - root.z))
	return result


static func _search(source: WarrenVolumePlan, current: Vector3i,
		previous_direction: Vector2i, turn_count: int, remaining: int,
		visited: Dictionary,
		path: Array[Vector3i], result: Array[Vector3i], budget: Dictionary) -> bool:
	if int(budget.visits) >= MAX_SEARCH_VISITS_PER_ROOT:
		return false
	budget.visits = int(budget.visits) + 1
	if remaining == 0:
		if turn_count < MIN_TURN_COUNT:
			return false
		result.assign(path)
		return true
	var candidates: Array[Dictionary] = []
	for direction_index in CARDINALS.size():
		var direction := CARDINALS[direction_index]
		var cell := current + Vector3i(direction.x, 0, direction.y)
		var column := Vector2i(cell.x, cell.z)
		if visited.has(cell) or not source.envelope.contains_column(column) \
				or cell.y != source.envelope.ground_at(column) \
				or not _walk_air_is_free(cell, source) \
				or _would_complete_public_square(cell, source, visited) \
				or not _route_breadth_allows(source, path, cell):
			continue
		var score := Vector2(float(cell.x), float(cell.z)).length() * 34.0 \
			- float(source.envelope.height_at(column)) * 18.0
		var wall_opportunity := _opposing_wall_opportunity(cell, direction,
			source)
		# A street is the negative space between future buildings.  Carve through
		# mass which can retain two complete inhabited walls; a visually winding
		# route with no roofable side columns is only a path across a lawn and cannot
		# be repaired by the parcel or prop stages later.
		score -= float(wall_opportunity) * 520.0
		if wall_opportunity == 2:
			score -= 900.0
		if _has_upper_public_walk(cell, source):
			score -= 1500.0
		score += float(_ground_primary_neighbor_count(cell, source)) \
			* PRIMARY_GROUND_PROXIMITY_PENALTY
		if previous_direction != Vector2i.ZERO:
			if direction == previous_direction:
				score += 140.0
			elif direction == -previous_direction:
				score += 700.0
			else:
				score -= 120.0
		score += float(posmod(source.world_seed * 31 + cell.x * 101
			+ cell.z * 193 + direction_index * 17 + path.size() * 43, 997)) \
			* 0.025
		candidates.append({"cell": cell, "direction": direction,
			"score": score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.score), float(b.score)):
			return float(a.score) < float(b.score)
		return _cell_key(a.cell as Vector3i) < _cell_key(b.cell as Vector3i))
	for candidate: Dictionary in candidates:
		var cell := candidate.cell as Vector3i
		var direction := candidate.direction as Vector2i
		var next_turn_count := turn_count + int(previous_direction \
			!= Vector2i.ZERO and direction != previous_direction)
		visited[cell] = true
		path.append(cell)
		if _search(source, cell, direction, next_turn_count, remaining - 1,
				visited, path, result, budget):
			return true
		path.pop_back()
		visited.erase(cell)
	return false


static func _path_score(root: Vector3i, path: Array[Vector3i],
		source: WarrenVolumePlan) -> float:
	var result := 0.0
	var previous := root
	var previous_direction := Vector2i.ZERO
	for cell: Vector3i in path:
		var column := Vector2i(cell.x, cell.z)
		result += Vector2(float(cell.x), float(cell.z)).length() * 40.0
		result -= float(source.envelope.height_at(column)) * 24.0
		var direction := Vector2i(cell.x - previous.x, cell.z - previous.z)
		var wall_opportunity := _opposing_wall_opportunity(cell, direction,
			source)
		result -= float(wall_opportunity) * 620.0
		if wall_opportunity == 2:
			result -= 1100.0
		if _has_upper_public_walk(cell, source):
			result -= 1800.0
		result += float(_ground_primary_neighbor_count(cell, source)) \
			* PRIMARY_GROUND_PROXIMITY_PENALTY
		if previous_direction != Vector2i.ZERO and direction != previous_direction:
			result -= 180.0
		previous_direction = direction
		previous = cell
	return result


static func _has_upper_public_walk(cell: Vector3i,
		source: WarrenVolumePlan) -> bool:
	for walk: Vector3i in source.walk_cells:
		if walk.x == cell.x and walk.z == cell.z \
				and walk.y - cell.y >= WarrenVolumePlan.HEADROOM_BANDS:
			return true
	return false


static func _ground_primary_neighbor_count(cell: Vector3i,
		source: WarrenVolumePlan) -> int:
	var result := 0
	for direction: Vector2i in CARDINALS:
		var neighbor := cell + Vector3i(direction.x, 0, direction.y)
		if source.primary_itinerary.has(neighbor) \
				and neighbor.y == source.envelope.ground_at(
					Vector2i(neighbor.x, neighbor.z)):
			result += 1
	return result


static func _opposing_wall_opportunity(cell: Vector3i,
		direction: Vector2i, source: WarrenVolumePlan) -> int:
	if direction == Vector2i.ZERO:
		return 0
	var side := Vector2i(-direction.y, direction.x)
	var result := 0
	for sign_value: int in [-1, 1]:
		var column: Vector2i = Vector2i(cell.x, cell.z) + side * sign_value
		result += int(_column_supports_complete_wall(column, cell.y, source))
	return result


static func _column_supports_complete_wall(column: Vector2i, base_band: int,
		source: WarrenVolumePlan) -> bool:
	## This is intentionally a resource-free necessary condition, not a guessed
	## prefab bound.  Exact parcel footprints and measured roof envelopes remain
	## authoritative later; the route simply avoids carving beside columns which
	## cannot possibly hold the minimum two-storey-plus-roof vocabulary.
	if not source.envelope.contains_column(column) \
			or source.envelope.ground_at(column) > base_band \
			or source.envelope.top_at(column) - base_band \
				< source.address_bands():
		return false
	for y in range(base_band, base_band + source.address_bands()):
		if not source.has_mass(Vector3i(column.x, y, column.y)):
			return false
	return true

static func _walk_air_is_free(cell: Vector3i,
		source: WarrenVolumePlan) -> bool:
	for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
		if not source.has_mass(cell + Vector3i.UP * y_offset):
			return false
	return true


static func _would_complete_public_square(cell: Vector3i,
		source: WarrenVolumePlan, branch_cells: Dictionary) -> bool:
	## Test each 2x2 square which could contain the candidate. This early pruning
	## mirrors WarrenVolumePlan's final invariant and lets the bounded DFS find a
	## genuinely alley-shaped alternative instead of rejecting a finished branch.
	for x_offset in [-1, 0]:
		for z_offset in [-1, 0]:
			var origin := cell + Vector3i(x_offset, 0, z_offset)
			var complete := true
			for corner in [origin, origin + Vector3i.RIGHT,
					origin + Vector3i.BACK, origin + Vector3i(1, 0, 1)]:
				if corner != cell and not source.has_walk(corner) \
						and not branch_cells.has(corner):
					complete = false
					break
			if complete:
				return true
	return false


static func _route_breadth_allows(source: WarrenVolumePlan,
		path: Array[Vector3i], candidate: Vector3i) -> bool:
	## Asks WarrenVolumePlan the same question its seal() will ask, rather than
	## restating the thresholds -- the branch this carves has to survive that
	## seal, and a second copy of the rule is a second thing to keep in step.
	var additions: Array[Vector3i] = []
	additions.assign(path)
	additions.append(candidate)
	return source.exact_route_breadth_allows(additions)


static func _grounded_frontage_count(cell: Vector3i,
		parcels: WarrenParcelPlan) -> int:
	var result := 0
	for parcel: WarrenBuildingParcel in parcels.parcels:
		for column: Vector2i in parcel.footprint:
			if absi(column.x - cell.x) + absi(column.y - cell.z) != 1:
				continue
			if parcel.base_band <= cell.y \
					or (parcel.bearing_columns.has(column) \
						and parcels.source.envelope.ground_at(column) <= cell.y):
				result += 1
				break
	return result


static func _overhead_building_count(cell: Vector3i,
		parcels: WarrenParcelPlan) -> int:
	var column := Vector2i(cell.x, cell.z)
	var result := 0
	for parcel: WarrenBuildingParcel in parcels.parcels:
		if parcel.footprint.has(column) \
				and parcel.base_band - cell.y >= WarrenVolumePlan.HEADROOM_BANDS:
			result += 1
	return result


static func _clone_volume(source: WarrenVolumePlan, arcade_root: Vector3i,
		arcade_cells: Array[Vector3i], branch_index: int) -> WarrenVolumePlan:
	var result := WarrenVolumePlan.new(
		StringName("%s.arcade%d" % [source.stable_id, branch_index]), source.world_seed,
		source.envelope)
	for cell: Vector3i in source.walk_cells:
		var added := result.add_walk_cell(cell, true) \
			if source.primary_itinerary.has(cell) \
			else result.add_ground_arcade_cell(cell) \
			if source.ground_arcade_cells.has(cell) \
			else result.add_elevated_gallery_cell(cell) \
			if source.elevated_gallery_cells.has(cell) \
			else result.add_walk_cell(cell, false)
		if not added:
			return null
	for cell: Vector3i in arcade_cells:
		if not result.add_ground_arcade_cell(cell):
			return null
	for source_transition: WarrenVolumeTransition in source.transitions:
		var transition := WarrenVolumeTransition.new(source_transition.stable_id,
			source_transition.from_cell, source_transition.to_cell,
			source_transition.kind, source_transition.swept_air_cells)
		if not result.add_transition(transition):
			return null
	var previous := arcade_root
	for index in arcade_cells.size():
		var cell := arcade_cells[index]
		var swept: Array[Vector3i] = []
		for endpoint: Vector3i in [previous, cell]:
			for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
				var air_cell := endpoint + Vector3i.UP * y_offset
				if not swept.has(air_cell):
					swept.append(air_cell)
		var transition := WarrenVolumeTransition.new(
			StringName("arcade.%02d.transition.%02d" % [branch_index, index]),
			previous, cell,
			WarrenVolumeTransition.Kind.LEVEL, swept)
		if not result.add_transition(transition):
			return null
		previous = cell
	for landing: Vector3i in source.landing_cells:
		if not result.add_landing(landing):
			return null
	if not result.add_landing(arcade_root):
		return null
	for daylight: Vector3i in source.daylight_void_cells:
		if not result.add_daylight_void(daylight):
			return null
	if not result.seal(source.entry_cell):
		last_failure = "ground arcade volume rejected: %s" % result.last_rejection
		return null
	return result


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]

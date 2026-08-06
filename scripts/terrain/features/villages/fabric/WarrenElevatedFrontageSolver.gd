class_name WarrenElevatedFrontageSolver
extends RefCounted

## Adds short typed upper-gallery loops before parcel selection. The main
## itinerary still owns all climbing topology; these level facade canyons leave
## one route square and rejoin another. They can never become ornamental
## one-edge shelves, and because their void exists before massing, buildings
## must form their walls rather than decorating a platform after the fact.
const BRANCH_COUNT := 2
const MIN_BRANCH_CELLS := 1
const MAX_BRANCH_CELLS := 4
const MAX_SEARCH_VISITS_PER_ROOT := 384
const MIN_ROOT_RISE_BANDS := 2
const MIN_BRANCH_SEPARATION_CELLS := 4
# Upper cul-de-sacs must be able to terminate at a building whose vertical
# silhouette exceeds its footprint. One inhabited storey plus a roof was the
# old generic address minimum; for these deliberately introduced gallery cells
# require two complete storeys and the roof reservation before carving the void.
const MIN_GALLERY_BUILDING_BANDS := \
	WarrenBuildingParcel.STOREY_BANDS * 2 \
	+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
const CARDINALS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]
static var last_failure := ""


static func extend(source: WarrenVolumePlan) -> WarrenVolumePlan:
	var candidates := variants(source)
	return null if candidates.is_empty() else candidates[0]


static func variants(source: WarrenVolumePlan) -> Array[WarrenVolumePlan]:
	## Elevated bypasses are bounded grammar alternatives. A route which admits a
	## topological gallery may not admit enough measured building/roof envelopes
	## around that new void; retain every complete prefix so the construction
	## transaction chooses between real towns rather than repairing one afterward.
	last_failure = ""
	var out: Array[WarrenVolumePlan] = []
	if source == null or not source.is_sealed():
		last_failure = "missing sealed route and ground arcades"
		return out
	out.append(source)
	var result := source
	for branch_index in BRANCH_COUNT:
		var branch := _best_branch(result, branch_index)
		var path: Array[Vector3i] = []
		path.assign(branch.get("path", []) as Array)
		var root := branch.get("root",
			Vector3i(2147483647, 0, 0)) as Vector3i
		var rejoin := branch.get("rejoin",
			Vector3i(2147483647, 0, 0)) as Vector3i
		if path.size() < MIN_BRANCH_CELLS:
			break
		var extended := _clone_with_branch(result, root, path, rejoin,
			branch_index)
		if extended == null:
			if last_failure.is_empty():
				last_failure = "elevated gallery failed volume transaction"
			break
		result = extended
		out.append(result)
	# Prefer richer valid topology when a caller requests only one variant. The
	# composed town solver still ranks all returned alternatives with measured
	# construction facts.
	out.reverse()
	return out


static func _best_branch(source: WarrenVolumePlan,
		branch_index: int) -> Dictionary:
	var existing: Array[Vector3i] = []
	existing.assign(source.elevated_gallery_cells)
	var best: Dictionary = {}
	var best_score := -INF
	for root_index in source.primary_itinerary.size():
		var root := source.primary_itinerary[root_index]
		var column := Vector2i(root.x, root.z)
		if root.y - source.envelope.ground_at(column) < MIN_ROOT_RISE_BANDS:
			continue
		var separation := _distance_to_cells(root, existing)
		if not existing.is_empty() \
				and separation < MIN_BRANCH_SEPARATION_CELLS:
			continue
		var incident := _incident_directions(root, source)
		var branches: Array[Dictionary] = []
		var budget := {"visits": 0}
		_search_branches(source, root, root, Vector2i.ZERO, incident,
			[] as Array[Vector3i], {root: true}, branches, budget)
		for branch: Dictionary in branches:
			var path: Array[Vector3i] = []
			path.assign(branch.path as Array)
			var rejoin := branch.rejoin as Vector3i
			var address_sides := 0
			var double_sided := 0
			var overhead := 0
			var turns := 0
			var previous := root
			var previous_direction := Vector2i.ZERO
			for cell: Vector3i in path:
				var sides := _address_side_count(cell, path, source)
				address_sides += sides
				double_sided += int(sides >= 2)
				overhead += int(_has_lower_walk(cell, source))
				var direction := Vector2i(cell.x - previous.x,
					cell.z - previous.z)
				turns += int(previous_direction != Vector2i.ZERO \
					and direction != previous_direction)
				previous_direction = direction
				previous = cell
			var rejoin_direction := Vector2i(rejoin.x - previous.x,
				rejoin.z - previous.z)
			turns += int(previous_direction != Vector2i.ZERO \
				and rejoin_direction != previous_direction)
			# The gallery is not permission to grow an empty balcony. At least
			# one cell must be a true second layer above existing circulation and
			# the bypass must retain enough complete mass for buildings to wall it.
			if address_sides < maxi(2, path.size()) \
					or double_sided < 1 or overhead < 1:
				continue
			var radius := Vector2(float(path.back().x),
				float(path.back().z)).length()
			var tie := posmod(_hash(source.world_seed, branch_index,
				root_index, path.size() * 17 + rejoin.x * 3 + rejoin.z), 1009)
			var score := float(address_sides) * 950.0 \
				+ float(double_sided) * 700.0 \
				+ float(overhead) * 1450.0 \
				+ float(turns) * 320.0 + float(root.y) * 24.0 \
				+ float(separation) * 18.0 - float(path.size()) * 210.0 \
				- radius * 22.0 - float(tie) * 0.015
			# A gallery is a nearby-building connector. Once all hard enclosure and
			# crossover facts pass, minimize the carved void before comparing style;
			# otherwise each additional address side pays for another empty route
			# square and the solver recreates an elevated street.
			if best.is_empty() or path.size() < (best.path as Array).size() \
					or (path.size() == (best.path as Array).size() \
						and score > best_score):
				best = {"root": root, "path": path, "rejoin": rejoin,
					"score": score}
				best_score = score
	return best


static func _search_branches(source: WarrenVolumePlan, root: Vector3i,
		current: Vector3i, previous_direction: Vector2i,
		incident: Array[Vector2i], path: Array[Vector3i], visited: Dictionary,
		out: Array[Dictionary], budget: Dictionary) -> void:
	if int(budget.visits) >= MAX_SEARCH_VISITS_PER_ROOT:
		return
	budget.visits = int(budget.visits) + 1
	if path.size() >= MIN_BRANCH_CELLS:
		var rejoin := _rejoin_cell(current, root, path, source)
		if rejoin.x != 2147483647 \
				and not _completes_public_square(path, rejoin, source):
			out.append({"path": path.duplicate(), "rejoin": rejoin})
			# A cell which already touches the sealed route is the terminal. Letting
			# the search continue would create an unclassified side connection.
			return
	if path.size() >= MAX_BRANCH_CELLS:
		return
	for direction: Vector2i in CARDINALS:
		if path.is_empty() \
				and (incident.has(direction) or incident.has(-direction)):
			continue
		if previous_direction != Vector2i.ZERO \
				and direction == -previous_direction:
			continue
		var cell := current + Vector3i(direction.x, 0, direction.y)
		if visited.has(cell) or source.has_walk(cell) \
				or not _cell_is_legal(cell, source):
			continue
		var prospective := path.duplicate()
		prospective.append(cell)
		if _completes_public_square(prospective,
				Vector3i(2147483647, 0, 0), source):
			continue
		# Before the minimum length, touching another existing route cell would
		# create a mesh seam which is absent from the explicit graph.
		if prospective.size() < MIN_BRANCH_CELLS \
				and _rejoin_cell(cell, root, prospective, source).x != 2147483647:
			continue
		visited[cell] = true
		_search_branches(source, root, cell, direction, incident, prospective,
			visited, out, budget)
		visited.erase(cell)


static func _cell_is_legal(cell: Vector3i,
		source: WarrenVolumePlan) -> bool:
	for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
		if not source.has_mass(cell + Vector3i.UP * y_offset):
			return false
	return true


static func _completes_public_square(path: Array[Vector3i],
		rejoin: Vector3i, source: WarrenVolumePlan) -> bool:
	var additions: Dictionary = {}
	for cell: Vector3i in path:
		additions[cell] = true
	if rejoin.x != 2147483647:
		additions[rejoin] = true
	for cell: Vector3i in path:
		for x_offset in [-1, 0]:
			for z_offset in [-1, 0]:
				var origin := cell + Vector3i(x_offset, 0, z_offset)
				var complete := true
				for corner in [origin, origin + Vector3i.RIGHT,
						origin + Vector3i.BACK,
						origin + Vector3i(1, 0, 1)]:
					if not source.has_walk(corner) and not additions.has(corner):
						complete = false
						break
				if complete:
					return true
	return false


static func _rejoin_cell(terminal: Vector3i, root: Vector3i,
		path: Array[Vector3i], source: WarrenVolumePlan) -> Vector3i:
	## A gallery episode is a bypass in the public graph, not a platform which
	## stops in open air. Prefer a primary-route rejoin, then any already-sealed
	## walk at the same datum. The first branch cell and its root are excluded.
	var candidates: Array[Vector3i] = []
	for direction: Vector2i in CARDINALS:
		var cell := terminal + Vector3i(direction.x, 0, direction.y)
		if cell == root or path.has(cell) or not source.has_walk(cell):
			continue
		candidates.append(cell)
	candidates.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var a_primary := source.primary_itinerary.has(a)
		var b_primary := source.primary_itinerary.has(b)
		if a_primary != b_primary:
			return a_primary
		return _cell_key(a) < _cell_key(b))
	return Vector3i(2147483647, 0, 0) if candidates.is_empty() \
		else candidates[0]


static func _address_side_count(cell: Vector3i, branch: Array[Vector3i],
		source: WarrenVolumePlan) -> int:
	var result := 0
	for direction: Vector2i in CARDINALS:
		var neighbor := cell + Vector3i(direction.x, 0, direction.y)
		if source.has_walk(neighbor) or branch.has(neighbor):
			continue
		var complete := true
		for y in range(cell.y, cell.y + MIN_GALLERY_BUILDING_BANDS):
			if not source.has_mass(Vector3i(neighbor.x, y, neighbor.z)):
				complete = false
				break
		result += int(complete)
	return result


static func _incident_directions(root: Vector3i,
		source: WarrenVolumePlan) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for transition: WarrenVolumeTransition in source.transitions:
		if transition.from_cell != root and transition.to_cell != root:
			continue
		var other := transition.other(root)
		var direction := Vector2i(signi(other.x - root.x),
			signi(other.z - root.z))
		if direction != Vector2i.ZERO and not out.has(direction):
			out.append(direction)
	return out


static func _has_lower_walk(cell: Vector3i,
		source: WarrenVolumePlan) -> bool:
	for walk: Vector3i in source.walk_cells:
		if walk.x == cell.x and walk.z == cell.z \
				and cell.y - walk.y >= WarrenVolumePlan.HEADROOM_BANDS:
			return true
	return false


static func _distance_to_cells(cell: Vector3i,
		others: Array[Vector3i]) -> int:
	var result := 2147483647
	for other: Vector3i in others:
		result = mini(result, absi(cell.x - other.x) \
			+ absi(cell.z - other.z))
	return result if not others.is_empty() else MIN_BRANCH_SEPARATION_CELLS


static func _clone_with_branch(source: WarrenVolumePlan, root: Vector3i,
		path: Array[Vector3i], rejoin: Vector3i,
		branch_index: int) -> WarrenVolumePlan:
	var result := WarrenVolumePlan.new(
		StringName("%s.gallery%d" % [source.stable_id, branch_index]),
		source.world_seed, source.envelope)
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
	for cell: Vector3i in path:
		if not result.add_elevated_gallery_cell(cell):
			return null
	for source_transition: WarrenVolumeTransition in source.transitions:
		var transition := WarrenVolumeTransition.new(source_transition.stable_id,
			source_transition.from_cell, source_transition.to_cell,
			source_transition.kind, source_transition.swept_air_cells)
		if not result.add_transition(transition):
			return null
	var previous := root
	for index in path.size():
		var cell := path[index]
		var swept: Array[Vector3i] = []
		for endpoint: Vector3i in [previous, cell]:
			for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
				var air := endpoint + Vector3i.UP * y_offset
				if not swept.has(air):
					swept.append(air)
		var transition := WarrenVolumeTransition.new(
			StringName("gallery.%02d.transition.%02d" % [branch_index, index]),
			previous, cell, WarrenVolumeTransition.Kind.LEVEL, swept)
		if not result.add_transition(transition):
			return null
		previous = cell
	var rejoin_swept: Array[Vector3i] = []
	for endpoint: Vector3i in [previous, rejoin]:
		for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
			var air := endpoint + Vector3i.UP * y_offset
			if not rejoin_swept.has(air):
				rejoin_swept.append(air)
	var rejoin_transition := WarrenVolumeTransition.new(
		StringName("gallery.%02d.transition.rejoin" % branch_index),
		previous, rejoin, WarrenVolumeTransition.Kind.LEVEL, rejoin_swept)
	if not result.add_transition(rejoin_transition):
		return null
	for landing: Vector3i in source.landing_cells:
		if not result.add_landing(landing):
			return null
	if not result.add_landing(root):
		return null
	# A bypass may rejoin at the far end of a stair/ramp. The 3 m route square is
	# already the authored two-lane landing; record that semantic fact so the
	# orthogonal gallery turn cannot be mistaken for stairs joined edge-to-edge.
	if not result.add_landing(rejoin):
		return null
	for daylight: Vector3i in source.daylight_void_cells:
		if not result.add_daylight_void(daylight):
			return null
	if not result.seal(source.entry_cell):
		last_failure = "elevated gallery rejected: %s" % result.last_rejection
		return null
	return result


static func _hash(seed_value: int, branch_index: int,
		root_index: int, salt: int) -> int:
	var value := seed_value * 1103515245 + branch_index * 214013 \
		+ root_index * 73856093 + salt * 19349663
	value = value ^ (value >> 13)
	return posmod(value, 2147483629)


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]

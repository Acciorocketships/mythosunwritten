class_name WarrenVolumePublicRealmAdapter
extends RefCounted

## Lossless topology adapter from the 3 m macro volume lattice to the existing
## 1.5 m two-lane exterior-realm contract. It preserves the primary 3D journey
## plus any already-sealed auxiliary ground arcade; it never infers topology.
## Ramps own their intermediate span; compact stairs remain one atomic edge
## between adjacent low/high landing squares.
static var last_failure := ""
const CARDINAL_MACRO_DIRECTIONS: Array[Vector3i] = [
	Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK,
]


static func from_volume(source: WarrenVolumePlan,
		parcels: WarrenParcelPlan = null,
		pruning: WarrenPrunedMassPlan = null,
		optional_infill_limit: int = \
			WarrenPlatformInfillSolver.MAX_OPTIONAL_PATCH_COUNT,
		supplemental_air: Array[Vector3i] = [],
		supplemental_surfaces: Array[Vector3i] = []) \
		-> SectionalPublicRealmPlan:
	last_failure = ""
	if source == null or not source.is_sealed():
		last_failure = "missing sealed source"
		return null
	var realm := SectionalPublicRealmPlan.new(
		StringName("%s.realm" % source.stable_id),
		PublicRealmNode.AirRealm.EXTERIOR)
	var node_ids: Array[StringName] = []
	var walk_node_ids: Dictionary = {}
	var elevated_supplemental_by_walk := \
		_attached_elevated_supplemental_by_walk(source,
			supplemental_surfaces)
	var infill := WarrenPlatformInfillSolver.solve(source, parcels, pruning,
		optional_infill_limit) \
		if parcels != null and pruning != null else {
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
	var extensions := infill.extensions as Dictionary
	for index in source.walk_cells.size():
		var macro_cell := source.walk_cells[index]
		var has_attached_roof_court := elevated_supplemental_by_walk.has(
			macro_cell)
		# Preserve the one authored third-storey court through the otherwise
		# generic public-realm adapter. Its exact surface cells remain ordinary
		# structural claims; the name lets the visual adapter give only this 6 m
		# square a legible paving pattern without re-inferring topology. Compact
		# and standard roof courts are already-sealed supplemental cells attached
		# to one walk node; give that complete node the same typed name. Previously
		# it stayed `volume.walk.*`, so a real 20-cell civic court rendered as an
		# anonymous empty deck with none of the reviewed paving or edge planters.
		var node_id := StringName("volume.courtyard.%02d" % index) \
			if source.courtyard_cells.has(macro_cell) else StringName(
				"volume.courtyard.rooftop.%02d" % index) \
				if has_attached_roof_court else \
			StringName("volume.walk.%02d" % index)
		var surfaces := _square_surface_cells(macro_cell)
		if extensions.has(macro_cell):
			surfaces.append_array(extensions[macro_cell] as Array[Vector3i])
		if has_attached_roof_court:
			surfaces.append_array(elevated_supplemental_by_walk[macro_cell] \
				as Array[Vector3i])
		var node_value := PublicRealmNode.new(node_id,
			PublicRealmNode.EpisodeKind.COURT if has_attached_roof_court \
				else _episode_kind(source, macro_cell),
			PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT \
				if has_attached_roof_court else _surface_kind(source, macro_cell),
			PublicRealmNode.AirRealm.EXTERIOR,
			_cover_policy(source, macro_cell), surfaces, _air_for_surfaces(surfaces),
			macro_cell.y, macro_cell.y, false, macro_cell == source.entry_cell)
		if not node_value.seal() or not realm.add_node(node_value):
			last_failure = "walk node %s rejected: %s" % [node_id,
				realm.last_rejection]
			return null
		walk_node_ids[macro_cell] = node_id
	var edge_index := 0
	var vertical_node_ids: Dictionary = {}
	for transition_index in source.transitions.size():
		var transition := source.transitions[transition_index]
		var from_id := walk_node_ids.get(transition.from_cell, &"") as StringName
		var to_id := walk_node_ids.get(transition.to_cell, &"") as StringName
		if from_id.is_empty() or to_id.is_empty():
			last_failure = "transition %d has no endpoint node" % transition_index
			return null
		if transition.is_vertical():
			var transition_id := StringName("volume.transition.%02d" % transition_index)
			var transition_surfaces := _transition_surface_cells(transition)
			if transition_surfaces.is_empty():
				last_failure = "vertical transition %d has no intermediate surface" % \
					transition_index
				return null
			var transition_node := PublicRealmNode.new(transition_id,
				PublicRealmNode.EpisodeKind.STAIR_CANYON,
				PublicRealmSurfacePlan.SurfaceKind.STAIR,
				PublicRealmNode.AirRealm.EXTERIOR,
				PublicRealmNode.CoverPolicy.COVERED,
				transition_surfaces, _air_for_surfaces(transition_surfaces),
				_transition_end_y(transition_surfaces, transition, true),
				_transition_end_y(transition_surfaces, transition, false), false, false)
			if not transition_node.seal() or not realm.add_node(transition_node):
				last_failure = "transition node %s rejected: %s surfaces=%s" % [
					transition_id, realm.last_rejection, transition_surfaces]
				return null
			vertical_node_ids[transition.stable_id] = transition_id
			var edge_kind := PublicRealmEdge.TransitionKind.RAMP \
				if transition.kind == WarrenVolumeTransition.Kind.RAMP \
				else PublicRealmEdge.TransitionKind.HALF_STAIR
			var is_primary := _transition_is_primary(source, transition)
			if not _add_edge(realm, edge_index, from_id, transition_id,
					edge_kind, is_primary):
				last_failure = "transition entry edge %s -> %s has no two-lane seam" % [
					from_id, transition_id]
				return null
			edge_index += 1
			if not _add_edge(realm, edge_index, transition_id, to_id,
					edge_kind, is_primary):
				last_failure = "transition exit edge %s -> %s has no two-lane seam" % [
					transition_id, to_id]
				return null
			edge_index += 1
		else:
			var is_primary := _transition_is_primary(source, transition)
			if not _add_edge(realm, edge_index, from_id, to_id,
					PublicRealmEdge.TransitionKind.LEVEL, is_primary):
				last_failure = "direct edge %s -> %s has no two-lane seam" % [
					from_id, to_id]
				return null
			edge_index += 1
	var supplemental_components := _supplemental_surface_components(
		supplemental_surfaces, realm)
	for component_index in supplemental_components.size():
		var surfaces := supplemental_components[component_index] \
			as Array[Vector3i]
		var node_id := StringName("volume.supplemental.%02d" % component_index)
		var supplemental_kind := _supplemental_surface_kind(source, surfaces)
		var node_value := PublicRealmNode.new(node_id,
			PublicRealmNode.EpisodeKind.COURT \
				if supplemental_kind \
					== PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT \
				else PublicRealmNode.EpisodeKind.UNDERCROFT,
			supplemental_kind,
			PublicRealmNode.AirRealm.EXTERIOR,
			PublicRealmNode.CoverPolicy.OPEN \
				if supplemental_kind \
					== PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT \
				else PublicRealmNode.CoverPolicy.COVERED, surfaces,
			_air_for_surfaces(surfaces), surfaces[0].y, surfaces[0].y,
			false, false)
		if not node_value.seal() or not realm.add_node(node_value):
			last_failure = "supplemental covered route node %s rejected: %s" % [
				node_id, realm.last_rejection]
			return null
		var partner := supplemental_partner(realm, node_id, surfaces)
		if partner.is_empty() or not _add_edge(realm, edge_index, partner,
				node_id, PublicRealmEdge.TransitionKind.LEVEL, false):
			last_failure = "supplemental covered route %s has no two-lane seam" % \
				node_id
			return null
		edge_index += 1
	for primary_index in range(source.primary_itinerary.size() - 1):
		var from_cell := source.primary_itinerary[primary_index]
		var to_cell := source.primary_itinerary[primary_index + 1]
		var transition := _transition_between(source, from_cell, to_cell)
		if transition == null:
			last_failure = "primary itinerary has no transition at %d" % \
				primary_index
			return null
		node_ids.append(walk_node_ids[from_cell] as StringName)
		if transition.is_vertical():
			node_ids.append(vertical_node_ids.get(
				transition.stable_id, &"") as StringName)
	if not source.primary_itinerary.is_empty():
		node_ids.append(walk_node_ids[source.primary_itinerary.back()] as StringName)
	if node_ids.size() < 2:
		last_failure = "primary itinerary is empty"
		return null
	realm.set_primary_itinerary(node_ids)
	for node_value: PublicRealmNode in realm.nodes:
		for cell: Vector3i in node_value.surface_cells:
			realm.require_classification(cell)
	for cell: Vector3i in infill.daylight_voids as Array[Vector3i]:
		realm.add_daylight_void(cell)
	for cell: Vector3i in supplemental_air:
		if not realm.add_supplemental_air(cell):
			last_failure = "supplemental exterior air could not be projected"
			return null
	if not realm.seal():
		last_failure = "realm seal failed: %s" % realm.last_rejection
		return null
	realm.audit["infill_platform_patch_count"] = int(infill.patch_count)
	realm.audit["required_infill_platform_patch_count"] = int(
		infill.required_patch_count)
	realm.audit["optional_infill_platform_patch_count"] = int(
		infill.optional_patch_count)
	realm.audit["over_route_platform_patch_count"] = int(
		infill.over_route_patch_count)
	realm.audit["infill_lightwell_count"] = int(infill.lightwell_count)
	realm.audit["uncovered_core_column_count"] = int(
		infill.uncovered_core_column_count)
	realm.audit["max_uncovered_core_component_size"] = int(
		infill.max_uncovered_core_component_size)
	realm.audit["uncovered_ground_route_cell_count"] = int(
		infill.uncovered_ground_route_cell_count)
	realm.audit["max_uncovered_ground_route_component_size"] = int(
		infill.max_uncovered_ground_route_component_size)
	realm.audit["composed_walk_enclosure_ratio"] = \
		_composed_walk_enclosure_ratio(source, pruning, extensions) \
		if pruning != null else 0.0
	return realm


static func supplemental_partner(realm: SectionalPublicRealmPlan,
		node_id: StringName,
		surfaces: Array[Vector3i]) -> StringName:
	## Which already-placed node a supplemental component hangs its LEVEL edge
	## off. Ranked by LEVEL lanes first (TASK E2).
	##
	## Raw contact count alone aims this connector straight at a
	## STAIR_CANYON — the one node kind whose surface cells are guaranteed to
	## sit at more than one y, so it wins the count precisely BECAUSE it is
	## sloped — and the edge the caller builds is declared LEVEL. A flat
	## lanes is the better connection on its own merits, and `_add_edge` still
	## names the edge a half stair when no partner offers any.
	##
	## This reorders nothing on a town that already sealed. The old winner's
	## every seam was level (an edge with a stepped seam is why a town did NOT
	## seal), so its level count equals the raw count that won it, and it
	## suffices that no loser's level count can exceed its own raw count.
	##
	## That last step is NOT general — greedy maximal matching on a subset of
	## the candidates can be LARGER than on the whole set, because a bad early
	## pairing that blocked two later ones may itself have been removed. It
	## holds here on a lemma about this caller's inputs:
	##
	##   SINGLE-BAND LEMMA. A supplemental component occupies exactly one band.
	##   `_supplemental_surface_components` grows it over
	##   CARDINAL_MACRO_DIRECTIONS, which are horizontal-only, so no two cells
	##   of one component differ in y. Every candidate seam from a given
	##   `from_cell` therefore steps by the same amount — |from_cell.y - y_c|
	##   for the component's single band y_c — so restricting to level lanes
	##   removes WHOLE from-groups and never part of one.
	##
	## Given the lemma the level run is the raw run with k matched from-groups
	## deleted. Deleting them frees exactly k to-cells, and in a greedy pass
	## each freed to-cell can promote at most one previously blocked
	## from-group, so the level matching gains at most k while losing exactly
	## k: level <= raw. `test_a_supplemental_court_prefers_a_level_partner`
	## covers the ranking itself.
	var candidates: Array[Dictionary] = []
	for existing: PublicRealmNode in realm.nodes:
		var existing_id := String(existing.stable_id)
		if existing.stable_id == node_id \
				or existing_id.begins_with("volume.supplemental."):
			continue
		var seams := _adjacent_lane_seams(existing.surface_cells, surfaces)
		if seams.size() >= 2:
			candidates.append({"node_id": existing.stable_id,
				"seam_count": seams.size(),
				"level_seam_count": _adjacent_lane_seams(
					existing.surface_cells, surfaces, true).size()})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.level_seam_count) != int(b.level_seam_count):
			return int(a.level_seam_count) > int(b.level_seam_count)
		if int(a.seam_count) != int(b.seam_count):
			return int(a.seam_count) > int(b.seam_count)
		return String(a.node_id) < String(b.node_id))
	return &"" if candidates.is_empty() \
		else StringName(candidates[0].node_id)


static func _supplemental_surface_components(cells: Array[Vector3i],
		realm: SectionalPublicRealmPlan) -> Array[Array]:
	var existing: Dictionary = {}
	for node_value: PublicRealmNode in realm.nodes:
		for cell: Vector3i in node_value.surface_cells:
			existing[cell] = true
	var remaining: Dictionary = {}
	for cell: Vector3i in cells:
		if not existing.has(cell):
			remaining[cell] = true
	var components: Array[Array] = []
	while not remaining.is_empty():
		var seeds: Array[Vector3i] = []
		seeds.assign(remaining.keys())
		seeds.sort_custom(_fine_cell_less)
		var seed := seeds[0]
		remaining.erase(seed)
		var frontier: Array[Vector3i] = [seed]
		var component: Array[Vector3i] = []
		while not frontier.is_empty():
			var cell: Vector3i = frontier.pop_back()
			component.append(cell)
			for direction: Vector3i in CARDINAL_MACRO_DIRECTIONS:
				var neighbor := cell + direction
				if remaining.erase(neighbor):
					frontier.append(neighbor)
		component.sort_custom(_fine_cell_less)
		components.append(component)
	components.sort_custom(func(a: Array, b: Array) -> bool:
		return _fine_cell_less(a[0] as Vector3i, b[0] as Vector3i))
	return components


static func _attached_elevated_supplemental_by_walk(source: WarrenVolumePlan,
		supplemental_surfaces: Array[Vector3i]) -> Dictionary:
	## A route-connected roof court is part of the walk node it opens from, not a
	## second graph episode pasted beside it. Folding the already-authoritative
	## supplemental cells into that node permits a narrow doorway into the broad
	## space while every inter-node route/stair seam keeps its existing two lanes.
	var canonical: Dictionary = {}
	for walk: Vector3i in source.walk_cells:
		for cell: Vector3i in _square_surface_cells(walk):
			canonical[cell] = true
	for transition: WarrenVolumeTransition in source.transitions:
		for cell: Vector3i in transition.surface_cells():
			canonical[cell] = true
	var remaining: Dictionary = {}
	for cell: Vector3i in supplemental_surfaces:
		if not canonical.has(cell):
			remaining[cell] = true
	var result: Dictionary = {}
	while not remaining.is_empty():
		var start := remaining.keys()[0] as Vector3i
		var frontier: Array[Vector3i] = [start]
		var component: Array[Vector3i] = []
		remaining.erase(start)
		while not frontier.is_empty():
			var current: Vector3i = frontier.pop_back()
			component.append(current)
			for direction: Vector3i in CARDINAL_MACRO_DIRECTIONS:
				var neighbor := current + direction
				if remaining.erase(neighbor):
					frontier.append(neighbor)
		if _supplemental_surface_kind(source, component) \
				!= PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT:
			continue
		var best_walk := Vector3i(2147483647, 2147483647, 2147483647)
		var best_contact_count := 0
		for walk: Vector3i in source.walk_cells:
			var contact_count := 0
			var walk_surfaces := _square_surface_cells(walk)
			for court_cell: Vector3i in component:
				for walk_cell: Vector3i in walk_surfaces:
					var delta := court_cell - walk_cell
					contact_count += int(delta.y == 0 \
						and absi(delta.x) + absi(delta.z) == 1)
			if contact_count > best_contact_count:
				best_contact_count = contact_count
				best_walk = walk
		if best_contact_count <= 0:
			continue
		if not result.has(best_walk):
			result[best_walk] = [] as Array[Vector3i]
		(result[best_walk] as Array[Vector3i]).append_array(component)
	for value: Variant in result.values():
		(value as Array[Vector3i]).sort_custom(_fine_cell_less)
	return result


static func _supplemental_surface_kind(source: WarrenVolumePlan,
		surfaces: Array[Vector3i]) -> PublicRealmSurfacePlan.SurfaceKind:
	## Supplemental market aisles remain terrain streets. A route extension
	## above its immutable terrain datum is structural circulation, so the common
	## surface assembler gives it the same supported plank/collision treatment as
	## authored upper terraces and courts.
	for cell: Vector3i in surfaces:
		var macro_column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if cell.y > source.envelope.ground_at(macro_column):
			return PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT
	return PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET


static func _fine_cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x


static func _composed_walk_enclosure_ratio(source: WarrenVolumePlan,
		pruning: WarrenPrunedMassPlan, extensions: Dictionary) -> float:
	## Parcel adjacency is deliberately not the only useful enclosure fact. An
	## exterior route cell can also sit under inhabited mass or open into a small
	## guarded court that is itself bounded by retained buildings. Count those
	## composed facts here, after all three inputs have been accepted together.
	if source.primary_itinerary.is_empty():
		return 0.0
	var enclosed := 0
	for walk: Vector3i in source.primary_itinerary:
		var bounded := extensions.has(walk)
		for direction in CARDINAL_MACRO_DIRECTIONS:
			var neighbor := walk + direction
			for y_offset in [-1, 0, 1, 2]:
				bounded = bounded or pruning.building_cells.has(
					neighbor + Vector3i.UP * y_offset)
		for y in range(walk.y + WarrenVolumePlan.HEADROOM_BANDS,
				source.envelope.top_at(Vector2i(walk.x, walk.z))):
			bounded = bounded or pruning.building_cells.has(
				Vector3i(walk.x, y, walk.z))
		enclosed += int(bounded)
	return float(enclosed) / float(source.primary_itinerary.size())


static func _transition_is_primary(source: WarrenVolumePlan,
		transition: WarrenVolumeTransition) -> bool:
	for index in range(source.primary_itinerary.size() - 1):
		var first := source.primary_itinerary[index]
		var second := source.primary_itinerary[index + 1]
		if (transition.from_cell == first and transition.to_cell == second) \
				or (transition.from_cell == second and transition.to_cell == first):
			return true
	return false


static func _transition_between(source: WarrenVolumePlan, from_cell: Vector3i,
		to_cell: Vector3i) -> WarrenVolumeTransition:
	for transition: WarrenVolumeTransition in source.transitions:
		if (transition.from_cell == from_cell and transition.to_cell == to_cell) \
				or (transition.from_cell == to_cell \
					and transition.to_cell == from_cell):
			return transition
	return null


static func _add_edge(realm: SectionalPublicRealmPlan, edge_index: int,
		from_id: StringName, to_id: StringName,
		kind: PublicRealmEdge.TransitionKind,
		is_primary: bool) -> bool:
	## TASK E2. An edge's transition kind is a FACT about the lanes that prove
	## it, not a wish the caller may state independently of them.
	##
	## `_adjacent_lane_seams` accepts any contact within one band because that
	## is right for a stair or a ramp — the 1.5 m riser between the two lanes
	## is the point of those edges. `PublicRealmEdge.seal` then holds a LEVEL
	## edge to a stricter rule (no seam may step at all), and nothing used to
	## reconcile the two: a LEVEL edge built over a node with surface cells at
	## more than one y — a STAIR_CANYON, a walk node carrying an infill
	## extension or a roof court — could be handed a stepped lane and was
	## refused by the seal a stage later, as `realm seal failed: invalid or
	## duplicate edge`. That was the largest maze blocker family (5/compact,
	## 10/standard, step/3/standard and the solve_selected quarters).
	##
	## So: prove a LEVEL edge with LEVEL lanes, and if none are on offer, name
	## the edge for what its lanes actually are. Restricting the LEVEL search
	## is a NO-OP wherever a town already sealed — a stepped candidate that
	## reached the selected set made the seal fail, and one that did not reach
	## it marks nothing in the greedy pass, so removing it cannot change the
	## outcome — which is why this returns towns without moving any that
	## already stand.
	var from_node := realm.node(from_id)
	var to_node := realm.node(to_id)
	if from_node == null or to_node == null:
		return false
	var edge_kind := kind
	var seams := _adjacent_lane_seams(from_node.surface_cells,
		to_node.surface_cells, kind == PublicRealmEdge.TransitionKind.LEVEL)
	if seams.size() < 2 and kind == PublicRealmEdge.TransitionKind.LEVEL:
		# One 1.5 m riser is half a 3 m storey, and the vocabulary already has
		# the word for it. Refusing here instead would trade one gate for
		# another; claiming LEVEL is the defect this whole rule exists to stop.
		seams = _adjacent_lane_seams(from_node.surface_cells,
			to_node.surface_cells, false)
		edge_kind = PublicRealmEdge.TransitionKind.HALF_STAIR
	if seams.size() < 2:
		return false
	var edge_value := PublicRealmEdge.new(
		StringName("volume.edge.%02d" % edge_index), from_id, to_id,
		edge_kind, is_primary)
	for seam: Dictionary in seams:
		edge_value.add_seam(seam.from_cell as Vector3i,
			seam.to_cell as Vector3i)
	return realm.add_edge(edge_value)


static func _square_surface_cells(macro_cell: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var origin := Vector3i(macro_cell.x * 2, macro_cell.y,
		macro_cell.z * 2)
	for x_offset in 2:
		for z_offset in 2:
			out.append(origin + Vector3i(x_offset, 0, z_offset))
	return out


static func _transition_surface_cells(
		transition: WarrenVolumeTransition) -> Array[Vector3i]:
	return transition.surface_cells()


static func _air_for_surfaces(
		surfaces: Array[Vector3i]) -> Array[Vector3i]:
	var unique: Dictionary = {}
	var out: Array[Vector3i] = []
	for surface: Vector3i in surfaces:
		for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
			var cell := surface + Vector3i.UP * y_offset
			if not unique.has(cell):
				unique[cell] = true
				out.append(cell)
	return out


static func _transition_end_y(surfaces: Array[Vector3i],
		transition: WarrenVolumeTransition, at_entry: bool) -> int:
	var direction := transition.direction
	var best_projection := 2147483647 if at_entry else -2147483648
	var result := transition.from_cell.y if at_entry else transition.to_cell.y
	for cell: Vector3i in surfaces:
		var projection := cell.x * direction.x + cell.z * direction.y
		if (at_entry and projection < best_projection) \
				or (not at_entry and projection > best_projection):
			best_projection = projection
			result = cell.y
	return result


static func _adjacent_lane_seams(from_cells: Array[Vector3i],
		to_cells: Array[Vector3i],
		require_level: bool = false) -> Array[Dictionary]:
	## `require_level` restricts the search to lanes that do not step, which is
	## what `PublicRealmEdge.TransitionKind.LEVEL` means and what its own seal
	## enforces (TASK E2). The default stays permissive because a stair or ramp
	## edge is proved by exactly the lanes it excludes.
	var candidates: Array[Dictionary] = []
	for from_cell: Vector3i in from_cells:
		for to_cell: Vector3i in to_cells:
			var rise := absi(from_cell.y - to_cell.y)
			if absi(from_cell.x - to_cell.x) + absi(from_cell.z - to_cell.z) == 1 \
					and rise <= 1 and (rise == 0 or not require_level):
				candidates.append({"from_cell": from_cell, "to_cell": to_cell})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _cell_key(a.from_cell as Vector3i) \
			< _cell_key(b.from_cell as Vector3i))
	# Court infill can legitimately meet the side of a stair landing. The graph
	# edge needs a non-overlapping player-width seam, not every geometric contact.
	# Keep the deterministic maximal subset so a side contact cannot duplicate an
	# already-authored endpoint lane and invalidate an otherwise sound transition.
	var out: Array[Dictionary] = []
	var used_from: Dictionary = {}
	var used_to: Dictionary = {}
	for seam: Dictionary in candidates:
		var from_cell := seam.from_cell as Vector3i
		var to_cell := seam.to_cell as Vector3i
		var from_key := _cell_key(from_cell)
		var to_key := _cell_key(to_cell)
		if used_from.has(from_key) or used_to.has(to_key):
			continue
		used_from[from_key] = true
		used_to[to_key] = true
		out.append(seam)
	return out


static func _episode_kind(source: WarrenVolumePlan,
		cell: Vector3i) -> PublicRealmNode.EpisodeKind:
	if source.landing_cells.has(cell):
		return PublicRealmNode.EpisodeKind.COURT
	if cell.y == source.envelope.ground_at(Vector2i(cell.x, cell.z)):
		return PublicRealmNode.EpisodeKind.STREET
	return PublicRealmNode.EpisodeKind.TERRACE


static func _surface_kind(source: WarrenVolumePlan,
		cell: Vector3i) -> PublicRealmSurfacePlan.SurfaceKind:
	return PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET \
		if cell.y == source.envelope.ground_at(Vector2i(cell.x, cell.z)) \
		else PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT


static func _cover_policy(source: WarrenVolumePlan,
		cell: Vector3i) -> PublicRealmNode.CoverPolicy:
	for y in range(cell.y + WarrenVolumePlan.HEADROOM_BANDS,
			source.envelope.top_at(Vector2i(cell.x, cell.z))):
		if source.has_mass(Vector3i(cell.x, y, cell.z)):
			return PublicRealmNode.CoverPolicy.COVERED
	return PublicRealmNode.CoverPolicy.OPEN


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]

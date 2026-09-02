class_name VillageOutskirtsSolver
extends RefCounted

## Places sparse ground houses only after the dense urban transaction is
## sealed. Each admitted house includes a proved short connection to the
## existing public graph; failed candidates leave no partial payload.
const SURVEY_LIMIT := 256
## Volumetric towns are materialized on the scaled 3 m fine lattice.  Their
## outskirts are world-space construction, so using the old authored 1.5 m
## module here put the distributor on a half-cell phase beside the town.
const OUTSKIRTS_GRID_STEP := VillageWorldScale.WORLD_FINE_CELL_M
const PATH_HALF_WIDTH := OUTSKIRTS_GRID_STEP * 0.5
const PATH_CLEARANCE := PATH_HALF_WIDTH + 0.5
const BRANCH_CORRIDOR_HALF_WIDTH := VillageProgram.MODULE * 4.0
const PARCEL_PATH_MARGIN := 0.25
const DOOR_BRANCH_ALIGNMENT_MIN := 0.85
const PERIMETER_ROOTS_PER_SIDE := 4
const PERIMETER_GRID_MARGIN := 3
const PERIMETER_ROOT_SEPARATION := OUTSKIRTS_GRID_STEP * 2.0
## An exit authors a small edge neighbourhood, not a town-wide belt road.
## Eight fine cells give the two flanking runs enough continuous frontage for
## a 12-15 m authored house beside an irregular city silhouette while still
## bounding every shared route to the 24 m terrain-cell neighborhood of its
## actual entrance. This remains a local edge street, never a belt road.
const ENTRY_NEIGHBOURHOOD_STEPS := 8
## The public lane occupies the one-cell gap.  A prefab's irregular authored
## eaves may leave at most half a cell beyond that lane before it stops reading
## as part of the same street wall.
const MAX_PERIMETER_GAP := OUTSKIRTS_GRID_STEP * 0.5 + PARCEL_PATH_MARGIN


static func solve(terrain: VillageTerrainView, settlement_id: StringName,
		arrival: Vector2, primary_axis: Vector2, tier: StringName,
		theme: StringName, program: VillageProgram,
		urban: VillageUrbanFabricPlan,
		existing_volumes: Array[VillageOccupancyVolume],
		canonical_ground: FeatureGroundField = null
		) -> VillageOutskirtsPlan:
	assert(terrain != null and not settlement_id.is_empty())
	assert(arrival.is_finite() and primary_axis.is_normalized())
	if program == null or program.outskirts_program == null \
			or urban == null or not urban.accepted:
		return _rejected(&"urban_fabric")
	var plan := VillageOutskirtsPlan.new()
	var occupancy := VillageOccupancy.new()
	if not occupancy.add_all(existing_volumes):
		return _rejected(&"existing_occupancy")
	var blockers: Array[VillageMassingPlacement] = []
	if urban.massing != null:
		blockers.assign(urban.massing.placements)
	var volumetric := urban.generation_kind \
		== VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN
	var prefab_scale := VillageWorldScale.PRODUCTION_UNIFORM_SCALE \
		if volumetric else 1.0
	var annulus := _outskirts_annulus(urban, arrival, volumetric)
	var inner_radius := annulus.x
	var outer_radius := annulus.y
	var contacts := _ground_contacts(terrain, arrival, primary_axis, urban)
	var survey_cache: Dictionary = {}
	plan.route_exit_count = contacts.size() if volumetric else 0
	var branches := _outskirts_branches(terrain, arrival, primary_axis,
		contacts, inner_radius, urban, volumetric)
	var target := program.outskirts_program.target_houses(tier,
		plan.route_exit_count)
	var used_branches: Dictionary = {}
	var used_branch_roots: Dictionary = {}
	var branch_groups: Dictionary = {}
	for branch: Dictionary in branches:
		branch_groups[_branch_group_key(branch)] = true
	var entry_ids: Dictionary = {}
	var volume_ids: Dictionary = {}
	var surface_ids: Dictionary = {}
	var clearance_ids: Dictionary = {}
	for slot_index in target:
		var candidate_specs := program.outskirts_program.spec_candidates_for_slot(
			settlement_id, slot_index, tier)
		var selected_spec := candidate_specs[0]
		var accepted := false
		var rejection := &"terrain_perches"
		var accepted_contact := StringName()
		var accepted_alignment := 0.0
		var accepted_connector_length := 0.0
		var accepted_neighbourhood_route_length := 0.0
		var accepted_perimeter_gap := -1.0
		var accepted_direction := Vector2.ZERO
		var accepted_branch_point := Vector2.ZERO
		var accepted_source := StringName()
		var rejection_counts: Dictionary = {}
		var rejection_examples: Dictionary = {}
		var best_rejected_alignment := -1.0
		var best_rejected_geometry: Dictionary = {}
		var branch_audit: Array[Dictionary] = []
		var attempted_asset_ids: Array[StringName] = []
		# The choice is a bounded construction search over authored contracts. It
		# prefers the city-scale silhouettes, but every fallback is independently
		# surveyed and proved; no smaller house inherits a perch computed for a
		# different footprint.
		for spec: VillageAssetSpec in candidate_specs:
			attempted_asset_ids.append(spec.asset_id)
			var footprint := spec.ground_contact_local_rect.size * 0.5 \
				* prefab_scale
			var surveys := _ordered_surveys(terrain, arrival, primary_axis,
				footprint, branches, slot_index, volumetric, survey_cache,
				inner_radius, outer_radius)
			branch_audit.clear()
			for survey: Dictionary in surveys:
				branch_audit.append({
					"contact": String(survey.contact_key),
					"contact_point": survey.contact_point,
					"contact_radius": float(survey.contact_radius),
					"discovered_perch_count": int(survey.discovered_perch_count),
					"corridor_perch_count": (survey.perches as Array).size(),
				})
			var candidate_surveys := surveys.duplicate()
			if volumetric and used_branches.size() < mini(target,
					branch_groups.size()):
				# Distribution is a preference only after every different side has
				# been proved. If terrain or exact occupancy makes the remaining sides
				# impossible, retry unoccupied roots on already-served runs rather than
				# silently dropping a surrounding house.
				for survey: Dictionary in surveys:
					var fallback := survey.duplicate()
					fallback["allow_served_side"] = true
					candidate_surveys.append(fallback)
			for survey: Dictionary in candidate_surveys:
				var survey_key := StringName(survey.contact_key)
				var branch_descriptor := survey.get("branch", {}) as Dictionary
				var branch_group := _branch_group_key(branch_descriptor,
					survey_key)
				if used_branch_roots.has(survey_key):
					continue
				# Until every available side has a house, a later slot may not
				# collapse back onto an already-served side. Alternate roots on one
				# side are terrain fallbacks, not permission to cluster the district.
				if volumetric and not bool(survey.get("allow_served_side", false)) \
						and used_branches.has(branch_group) \
						and used_branches.size() < mini(target,
							branch_groups.size()):
					continue
				for perch: VillageTerrainPerch in survey.perches:
					var radius := perch.anchor.distance_to(arrival)
					var uses_arrival_annulus := not bool(
						branch_descriptor.get("grid_edge", false))
					if (uses_arrival_annulus and (radius < inner_radius - 0.001 \
							or radius > outer_radius + 0.001)) \
							or perch.relief > spec.max_ground_relief + 0.001:
						continue
					var slot := VillageMassingSlot.new(StringName(
						"outskirts.house.%02d" % slot_index), spec.asset_id)
					for facade_index in 2:
						var placement := VillageMassingPlacement.from_perch(slot,
							spec, perch, facade_index, prefab_scale)
						var branch_for_door := survey.get("branch", {}) \
							as Dictionary
						var perimeter_door := bool(branch_for_door.get(
							"perimeter_lot", false))
						var entrance_result: Dictionary = _configure_perimeter_door(
							terrain, placement, spec, program.elevated_program,
							survey) if perimeter_door else {
								"accepted": placement.configure_entrance(spec, terrain,
									program.elevated_program),
							}
						var entrance_ready := bool(entrance_result.accepted)
						if not entrance_ready \
								or not placement.ground_accessible:
							rejection = &"entrance"
							rejection_counts[rejection] = int(
								rejection_counts.get(rejection, 0)) + 1
							var entrance_geometry := entrance_result.get(
								"diagnostic_geometry", {}) as Dictionary
							if not entrance_geometry.is_empty() \
									and not rejection_examples.has(rejection):
								rejection_examples[rejection] = entrance_geometry
							continue
						# The outskirts transaction below publishes the reviewed support
						# rectangle as lower-storey solid and the broader visual/eave box
						# only above public headroom. Seal that same profile before routing
						# so lane feasibility and committed occupancy are the same fact.
						placement.ground_route_support_profile = true
						var candidate := _candidate(terrain, settlement_id, arrival,
							primary_axis, theme, program, urban, spec, placement,
							survey, blockers, occupancy, outer_radius,
							canonical_ground)
						if not bool(candidate.accepted):
							rejection = candidate.reason
							rejection_counts[rejection] = int(
								rejection_counts.get(rejection, 0)) + 1
							var rejected_alignment := float(candidate.get(
								"door_branch_alignment", -1.0))
							var rejected_geometry := candidate.get(
								"diagnostic_geometry", {}) as Dictionary
							if not rejected_geometry.is_empty() \
									and not rejection_examples.has(rejection):
								rejection_examples[rejection] = rejected_geometry
							if rejected_alignment > best_rejected_alignment \
									or (best_rejected_geometry.is_empty() \
										and not rejected_geometry.is_empty()):
								best_rejected_alignment = rejected_alignment
								best_rejected_geometry = rejected_geometry
							continue
						_append_unique_entries(plan.entries, candidate.entries,
							entry_ids)
						var novel_volumes := _append_unique_volumes(plan.volumes,
							candidate.volumes, volume_ids)
						_append_unique_shapes(plan.surfaces, candidate.surfaces,
							surface_ids)
						_append_unique_shapes(plan.clearances,
							candidate.clearances, clearance_ids)
						plan.route_stair_count += int(candidate.stair_count)
						plan.supported_house_count += 1
						plan.side_served_house_count += 1
						plan.foundation_piece_count += int(
							candidate.foundation_piece_count)
						plan.placements.append(placement)
						assert(occupancy.add_all(novel_volumes))
						blockers.append(placement)
						selected_spec = spec
						accepted_contact = survey_key
						used_branches[branch_group] = true
						used_branch_roots[accepted_contact] = true
						accepted_alignment = float(candidate.door_branch_alignment)
						accepted_connector_length = float(
							candidate.parcel_connector_length)
						accepted_perimeter_gap = float(candidate.perimeter_gap)
						var accepted_branch := survey.get("branch", {}) as Dictionary
						accepted_neighbourhood_route_length = float(
							accepted_branch.get("route_length", 0.0))
						var accepted_node := accepted_branch.get("node") \
							as VillageCirculationNode
						var source_node := accepted_branch.get("source_node") \
							as VillageCirculationNode
						if accepted_node != null:
							accepted_direction = accepted_node.outward
							accepted_branch_point = accepted_node.point
						if source_node != null:
							accepted_source = source_node.stable_key
						accepted = true
						break
					if accepted:
						break
				if accepted:
					break
			if accepted:
				break
		plan.audit.append({"slot": slot_index,
			"asset_id": selected_spec.asset_id,
			"attempted_asset_ids": attempted_asset_ids,
			"accepted": accepted, "reason": &"accepted" if accepted \
				else rejection, "route_exit_count": contacts.size(),
			"branch_contact": accepted_contact, "branches": branch_audit,
			"branch_source": accepted_source,
			"branch_direction": [accepted_direction.x,
				accepted_direction.y],
			"branch_point": [accepted_branch_point.x,
				accepted_branch_point.y],
			"neighbourhood_route_length":
				accepted_neighbourhood_route_length,
			"outskirts_grid_step": OUTSKIRTS_GRID_STEP,
			"door_branch_alignment": accepted_alignment,
			"best_rejected_door_branch_alignment": best_rejected_alignment,
			"best_rejected_geometry": best_rejected_geometry,
			"rejection_counts": rejection_counts,
			"rejection_examples": rejection_examples,
			"parcel_connector_length": accepted_connector_length,
			"perimeter_gap": accepted_perimeter_gap,
			"inner_radius": inner_radius, "outer_radius": outer_radius})
	plan.branch_count = used_branches.size()
	plan.accepted = true
	plan.reason = &"accepted"
	if not plan.validate(program.outskirts_program, tier):
		var validation_occupancy := VillageOccupancy.new()
		var validation_conflict := validation_occupancy.first_conflict(
			plan.volumes)
		var validation_message := "outskirts plan contract failed"
		if not validation_conflict.is_empty():
			var validation_candidate := validation_conflict.candidate \
				as VillageOccupancyVolume
			var validation_existing := validation_conflict.existing \
				as VillageOccupancyVolume
			validation_message = "%s (%s/%s against %s/%s)" % [
				validation_message, validation_candidate.stable_id,
				validation_candidate.owner_id, validation_existing.stable_id,
				validation_existing.owner_id]
		assert(false, validation_message)
	return plan


static func _outskirts_branches(terrain: VillageTerrainView,
		arrival: Vector2, primary_axis: Vector2,
		contacts: Array[VillageCirculationNode], inner_radius: float,
		urban: VillageUrbanFabricPlan, volumetric: bool) -> Array[Dictionary]:
	## Convert sealed public exits into a small street graph before parcels are
	## considered. Every sealed exit joins a tight, grid-aligned distributor
	## around the exact urban silhouette. Houses are lots outside that shared
	## street, never props on the world road.
	var out: Array[Dictionary] = []
	if contacts.is_empty():
		return out
	if volumetric:
		# Every sealed ground exit joins the same exact exterior contour. Build
		# the contour view from each exit, then let each lot root keep the shortest
		# source-to-root route. This produces one shared wrapping street graph even
		# when a town has several doors to natural terrain; it cannot degenerate
		# into unrelated radial spokes or duplicate the same frontage per exit.
		var by_root: Dictionary = {}
		var root_order: Array[String] = []
		for source: VillageCirculationNode in contacts:
			for branch: Dictionary in _grid_edge_branches(terrain, arrival,
					primary_axis, source, urban):
				var node := branch.node as VillageCirculationNode
				var local := _grid_local(node.point, arrival, primary_axis) \
					/ OUTSKIRTS_GRID_STEP
				var root_key := "%d:%d" % [roundi(local.x), roundi(local.y)]
				var route_length := _network_length(
					branch.network_nodes as Array[VillageCirculationNode])
				branch["route_length"] = route_length
				if not by_root.has(root_key):
					by_root[root_key] = branch
					root_order.append(root_key)
					continue
				var existing := by_root[root_key] as Dictionary
				var existing_length := float(existing.route_length)
				var existing_source := existing.source_node \
					as VillageCirculationNode
				if route_length < existing_length - 0.001 \
						or (is_equal_approx(route_length, existing_length) \
							and String(source.stable_key) \
							< String(existing_source.stable_key)):
					by_root[root_key] = branch
		for root_key: String in root_order:
			out.append(by_root[root_key] as Dictionary)
		return out
	for contact_index in contacts.size():
		var source := contacts[contact_index]
		var outward := source.outward
		if not outward.is_normalized():
			outward = source.point - arrival
			outward = outward.normalized() if not outward.is_zero_approx() \
				else -primary_axis
		var root := source.point
		var axes: Array[Vector2] = [outward]
		var labels := PackedStringArray(["forward"])
		for axis_index in axes.size():
			var axis := axes[axis_index]
			var key := StringName("%s.branch.%s" % [source.stable_key,
				labels[axis_index]])
			var node := VillageCirculationNode.new(key,
				VillageCirculationNode.Kind.TERRAIN_CONTACT, root,
				terrain.surface_y(root), source.owner_key, axis)
			out.append({
				"node": node,
				"source_node": source,
				"main_path_a": source.point,
				"main_path_b": root,
				# A real volumetric edge portal already belongs to the sealed
				# public graph. Its parcel search is the short exterior band ahead
				# of that portal, never the legacy centre-based annulus.
				"grid_edge": volumetric,
				# Several sealed exits are already branch streets. Their houses
				# occupy side lots along those streets; only the derived wrapping
				# contour uses the outward-facing perimeter-lot contract.
				"perimeter_lot": false,
			})
	return out


static func _network_length(nodes: Array[VillageCirculationNode]) -> float:
	var total := 0.0
	for index in range(1, nodes.size()):
		total += nodes[index - 1].point.distance_to(nodes[index].point)
	return total


static func _grid_edge_branches(terrain: VillageTerrainView,
		arrival: Vector2, primary_axis: Vector2,
		source: VillageCirculationNode, urban: VillageUrbanFabricPlan
		) -> Array[Dictionary]:
	## The city and its edge district share one orthogonal world-fine lattice. Rasterize
	## the exact sealed structural/public union, take the one-cell exterior contour,
	## and retain only the bounded component around the real public exit. The lane
	## follows nearby recesses and stepped wings without becoming a belt road.
	## There is no radial ring and no free rotation: every prefab remains on the
	## same axes as the town.
	assert(urban != null)
	var side_axis := Vector2(-primary_axis.y, primary_axis.x)
	var outward := source.outward
	if not outward.is_normalized():
		outward = source.point - arrival
		outward = outward.normalized() if not outward.is_zero_approx() \
			else -primary_axis
	var directions: Array[Vector2] = [primary_axis, side_axis,
		-primary_axis, -side_axis]
	var local_directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN,
		Vector2i.LEFT, Vector2i.UP]
	var entry_side := 0
	var best_dot := -INF
	for direction_index in directions.size():
		var alignment := directions[direction_index].dot(outward)
		if alignment > best_dot:
			best_dot = alignment
			entry_side = direction_index
	var grid := _urban_perimeter_grid(urban, arrival, primary_axis)
	var perimeter := grid.perimeter as Dictionary
	var blocked := grid.blocked as Dictionary
	var shapes: Array[FeatureGroundShape] = []
	shapes.assign(grid.shapes as Array)
	if perimeter.is_empty():
		return []
	var source_local := _grid_local(source.point, arrival, primary_axis)
	var outward_local := Vector2(outward.dot(primary_axis),
		outward.dot(side_axis))
	var entry_cell := _nearest_perimeter_cell(perimeter, source_local,
		outward_local)
	var graph := _perimeter_component(entry_cell, perimeter, shapes,
		arrival, primary_axis)
	var component := graph.component as Dictionary
	var parents := graph.parents as Dictionary
	var distances := graph.distances as Dictionary
	if component.is_empty():
		return []
	# The canonical entrance is a junction, not a parcel frontage. Populate its
	# two short flanking runs first. The entry-facing run is a terrain fallback;
	# the opposite side of the city belongs to another real exit, if one exists.
	var side_order := [posmod(entry_side + 1, 4),
		posmod(entry_side - 1, 4), entry_side]
	var ranked_by_side: Dictionary = {}
	var centre := grid.centre as Vector2
	for side_index: int in side_order:
		var candidates: Array[Vector2i] = []
		var local_outward := local_directions[side_index]
		for cell_variant: Variant in component.keys():
			var cell := cell_variant as Vector2i
			var graph_distance := int(distances.get(cell, 1 << 30))
			if graph_distance <= 0 \
					or graph_distance > ENTRY_NEIGHBOURHOOD_STEPS:
				continue
			if blocked.has(cell - local_outward):
				candidates.append(cell)
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var a_local := Vector2(a) * OUTSKIRTS_GRID_STEP
			var b_local := Vector2(b) * OUTSKIRTS_GRID_STEP
			# Broad prefabs need a continuous street wall, not a corner cell that
			# happens to have one occupied neighbour. Prefer the middle of the
			# longest same-facing contour run before considering route distance.
			# Exact occupancy still validates the eventual measured house envelope.
			var a_frontage := _frontage_capacity_cells(a, local_outward,
				perimeter, blocked)
			var b_frontage := _frontage_capacity_cells(b, local_outward,
				perimeter, blocked)
			if a_frontage != b_frontage:
				return a_frontage > b_frontage
			var a_distance := int(distances.get(a, 1 << 30))
			var b_distance := int(distances.get(b, 1 << 30))
			if a_distance != b_distance:
				return a_distance < b_distance
			var direction := Vector2(local_outward)
			var tangent := Vector2(-direction.y, direction.x)
			var a_projection := (a_local - centre).dot(direction)
			var b_projection := (b_local - centre).dot(direction)
			if not is_equal_approx(a_projection, b_projection):
				return a_projection > b_projection
			var a_tangent := absf((a_local - centre).dot(tangent))
			var b_tangent := absf((b_local - centre).dot(tangent))
			if not is_equal_approx(a_tangent, b_tangent):
				return a_tangent < b_tangent
			return a.x < b.x if a.x != b.x else a.y < b.y)
		var separated: Array[Vector2i] = []
		for candidate: Vector2i in candidates:
			var far_enough := true
			for selected: Vector2i in separated:
				if Vector2(candidate - selected).length() \
						* OUTSKIRTS_GRID_STEP \
						< PERIMETER_ROOT_SEPARATION - 0.001:
					far_enough = false
					break
			if far_enough:
				separated.append(candidate)
				if separated.size() >= PERIMETER_ROOTS_PER_SIDE:
					break
			ranked_by_side[side_index] = separated
	var out: Array[Dictionary] = []
	var used_roots: Dictionary = {}
	for rank in PERIMETER_ROOTS_PER_SIDE:
		for target_side: int in side_order:
			var candidates := ranked_by_side[target_side] as Array[Vector2i]
			if rank >= candidates.size():
				continue
			var root_cell := candidates[rank]
			if used_roots.has(root_cell):
				continue
			used_roots[root_cell] = true
			var path := _perimeter_path(root_cell, entry_cell, parents)
			if path.is_empty():
				continue
			var nodes: Array[VillageCirculationNode] = [source]
			for cell: Vector2i in path:
				var point := _grid_world(Vector2(cell) * OUTSKIRTS_GRID_STEP,
					arrival, primary_axis)
				if nodes[-1].point.distance_to(point) <= 0.01:
					continue
				nodes.append(VillageCirculationNode.new(StringName(
					"%s.perimeter.%d.%d" % [source.stable_key,
						cell.x, cell.y]),
					VillageCirculationNode.Kind.TERRAIN_CONTACT, point,
					terrain.surface_y(point), source.owner_key, Vector2.ZERO))
			var branch_node := nodes[-1]
			branch_node.outward = directions[target_side]
			out.append({
				"node": branch_node,
				"source_node": source,
				"main_path_a": source.point,
				"main_path_b": source.point,
				"network_nodes": nodes,
					"side_key": StringName("%s.neighbourhood.side.%d" % [
						source.stable_key, target_side]),
				"grid_edge": true,
				"perimeter_lot": true,
			})
	return out


static func _frontage_capacity_cells(cell: Vector2i,
		local_outward: Vector2i, perimeter: Dictionary,
		blocked: Dictionary) -> int:
	## Count the contiguous same-facing contour through this root. Four cells on
	## either side covers the largest reviewed 15 m prefab without turning the
	## local entrance neighborhood into a settlement-wide search.
	var tangent := Vector2i(-local_outward.y, local_outward.x)
	var capacity := 1
	for sign_value in [-1, 1]:
		for distance in range(1, 5):
			var neighbour: Vector2i = cell + tangent * distance \
				* int(sign_value)
			if not perimeter.has(neighbour) \
					or not blocked.has(neighbour - local_outward):
				break
			capacity += 1
	return capacity


static func _urban_perimeter_grid(urban: VillageUrbanFabricPlan,
		arrival: Vector2, primary_axis: Vector2) -> Dictionary:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var shapes: Array[FeatureGroundShape] = []
	# The contour wraps exact occupied/public prisms. Broad district and ecology
	# clearances intentionally do not participate: those planning envelopes would
	# recreate the vacant moat this graph is designed to eliminate.
	for volume: VillageOccupancyVolume in urban.volumes:
		if volume.role not in [VillageOccupancy.Role.SOLID,
				VillageOccupancy.Role.WALK_SURFACE,
				VillageOccupancy.Role.WALK_GUARD]:
			continue
		shapes.append(FeatureGroundShape.oriented_rect(volume.centre,
			volume.half_extents, volume.angle))
		var world_bounds := volume.bounds_xz()
		for point: Vector2 in [world_bounds.position,
				Vector2(world_bounds.end.x, world_bounds.position.y),
				Vector2(world_bounds.position.x, world_bounds.end.y),
				world_bounds.end]:
			var local := _grid_local(point, arrival, primary_axis)
			minimum.x = minf(minimum.x, local.x)
			minimum.y = minf(minimum.y, local.y)
			maximum.x = maxf(maximum.x, local.x)
			maximum.y = maxf(maximum.y, local.y)
	var step := OUTSKIRTS_GRID_STEP
	if shapes.is_empty():
		# Only isolated test/custom fixtures can claim an accepted urban plan with
		# no structural volumes. Model their declared core as one module so the
		# same contour algorithm remains the sole topology producer.
		minimum = -Vector2.ONE * step * 0.5
		maximum = -minimum
		shapes.append(FeatureGroundShape.oriented_rect(arrival,
			Vector2.ONE * step * 0.5, primary_axis.angle()))
	var lo := Vector2i(floori(minimum.x / step) - PERIMETER_GRID_MARGIN,
		floori(minimum.y / step) - PERIMETER_GRID_MARGIN)
	var hi := Vector2i(ceili(maximum.x / step) + PERIMETER_GRID_MARGIN,
		ceili(maximum.y / step) + PERIMETER_GRID_MARGIN)
	var blocked: Dictionary = {}
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var cell := Vector2i(x, z)
			var point := _grid_world(Vector2(cell) * step,
				arrival, primary_axis)
			for shape: FeatureGroundShape in shapes:
				if shape.signed_distance(point) \
						<= PATH_HALF_WIDTH + PARCEL_PATH_MARGIN:
					blocked[cell] = true
					break
	var perimeter: Dictionary = {}
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var cell := Vector2i(x, z)
			if blocked.has(cell):
				continue
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if (dx != 0 or dz != 0) \
							and blocked.has(cell + Vector2i(dx, dz)):
						perimeter[cell] = true
						break
				if perimeter.has(cell):
					break
	return {"blocked": blocked, "perimeter": perimeter,
		"shapes": shapes, "centre": (minimum + maximum) * 0.5}


static func _nearest_perimeter_cell(perimeter: Dictionary,
		source_local: Vector2, outward_local: Vector2) -> Vector2i:
	var best := Vector2i.ZERO
	var best_score := INF
	var side := Vector2(-outward_local.y, outward_local.x)
	for cell_variant: Variant in perimeter.keys():
		var cell := cell_variant as Vector2i
		var point := Vector2(cell) * OUTSKIRTS_GRID_STEP
		var delta := point - source_local
		var along := delta.dot(outward_local)
		var score := delta.length() + absf(delta.dot(side)) * 2.0 \
			+ maxf(-along, 0.0) * 4.0
		if score < best_score - 0.001 \
				or (is_equal_approx(score, best_score) \
					and (cell.x < best.x or (cell.x == best.x and cell.y < best.y))):
			best = cell
			best_score = score
	return best


static func _perimeter_component(entry: Vector2i, perimeter: Dictionary,
		shapes: Array[FeatureGroundShape], arrival: Vector2,
		primary_axis: Vector2) -> Dictionary:
	var component: Dictionary = {entry: true}
	var parents: Dictionary = {entry: entry}
	var distances: Dictionary = {entry: 0}
	var queue: Array[Vector2i] = [entry]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN,
				Vector2i.LEFT, Vector2i.UP]:
			var next := cell + direction
			if not perimeter.has(next) or component.has(next) \
					or not _perimeter_edge_clear(cell, next, shapes, arrival,
						primary_axis):
				continue
			component[next] = true
			parents[next] = cell
			distances[next] = int(distances[cell]) + 1
			queue.append(next)
	return {"component": component, "parents": parents,
		"distances": distances}


static func _perimeter_edge_clear(a: Vector2i, b: Vector2i,
		shapes: Array[FeatureGroundShape], arrival: Vector2,
		primary_axis: Vector2) -> bool:
	var world_a := _grid_world(Vector2(a) * OUTSKIRTS_GRID_STEP,
		arrival, primary_axis)
	var world_b := _grid_world(Vector2(b) * OUTSKIRTS_GRID_STEP,
		arrival, primary_axis)
	var corridor := FeatureGroundShape.capsule(world_a, world_b,
		PATH_HALF_WIDTH)
	for shape: FeatureGroundShape in shapes:
		if corridor.intersects(shape, PARCEL_PATH_MARGIN):
			return false
	return true


static func _perimeter_path(root: Vector2i, entry: Vector2i,
		parents: Dictionary) -> Array[Vector2i]:
	if not parents.has(root):
		return []
	var reverse: Array[Vector2i] = [root]
	var current := root
	while current != entry:
		current = parents[current] as Vector2i
		reverse.append(current)
	reverse.reverse()
	return reverse


static func _branch_group_key(branch: Dictionary,
		fallback: StringName = &"") -> StringName:
	var side_key := StringName(branch.get("side_key", &""))
	if not side_key.is_empty():
		return side_key
	var node := branch.get("node") as VillageCirculationNode
	return node.stable_key if node != null else fallback


static func _grid_local(point: Vector2, arrival: Vector2,
		primary_axis: Vector2) -> Vector2:
	var delta := point - arrival
	var side := Vector2(-primary_axis.y, primary_axis.x)
	return Vector2(delta.dot(primary_axis), delta.dot(side))


static func _grid_world(local: Vector2, arrival: Vector2,
		primary_axis: Vector2) -> Vector2:
	var side := Vector2(-primary_axis.y, primary_axis.x)
	return arrival + primary_axis * local.x + side * local.y


static func _ordered_surveys(terrain: VillageTerrainView, arrival: Vector2,
		primary_axis: Vector2, footprint: Vector2,
		branches: Array[Dictionary], slot_index: int,
		volumetric: bool, cache: Dictionary, inner_radius: float,
		outer_radius: float) -> Array[Dictionary]:
	## A volumetric outskirts parcel is born from a sealed public exit. Surveying
	## the whole annulus first and attempting a lane afterwards let the terrain
	## ranking consume its bounded result set with attractive but unreachable
	## perches. Here each branch owns its outward corridor before a house exists;
	## every candidate is consequently on the correct side of the same exit the
	## route solver must reach. Legacy towns retain their existing global survey.
	if not volumetric or branches.is_empty():
		var global_key := "global:%0.3f:%0.3f" % [footprint.x, footprint.y]
		if not cache.has(global_key):
			cache[global_key] = VillageTerrainSurvey.discover(
				terrain, arrival, footprint, primary_axis,
				outer_radius, SURVEY_LIMIT, inner_radius)
		var legacy_contacts: Array[VillageCirculationNode] = []
		for branch: Dictionary in branches:
			var legacy_node := branch.get("node") as VillageCirculationNode
			if legacy_node != null:
				legacy_contacts.append(legacy_node)
		return [{"contact_key": &"legacy_graph", "contacts": legacy_contacts,
			"contact_point": [arrival.x, arrival.y], "contact_radius": 0.0,
			"discovered_perch_count": (cache[global_key] as Array).size(),
			"perches": cache[global_key], "branch": {}}]
	var out: Array[Dictionary] = []
	for offset in branches.size():
		var branch_descriptor := branches[(slot_index + offset) % branches.size()]
		var contact := branch_descriptor.node as VillageCirculationNode
		var outward := contact.outward
		if not outward.is_normalized():
			outward = contact.point - arrival
			outward = outward.normalized() if not outward.is_zero_approx() \
				else -primary_axis
		var key := "branch:%s:%0.3f:%0.3f" % [String(contact.stable_key),
			footprint.x, footprint.y]
		var grid_edge := bool(branch_descriptor.get("grid_edge", false))
		var perimeter_lot := bool(branch_descriptor.get("perimeter_lot", false))
		# An edge lot is one building depth plus the public clearance and one
		# shared module beyond its real portal. Its own footprint therefore sets
		# the maximum setback; town scale and a legacy radial annulus cannot push
		# a small house away from its neighbours.
		var maximum_forward := PATH_CLEARANCE \
			+ maxf(footprint.x, footprint.y) * 2.0 \
			+ VillageProgram.MODULE * 2.0 if grid_edge else outer_radius
		var minimum_arrival_radius := 0.0 if grid_edge else inner_radius
		var maximum_arrival_radius := contact.point.distance_to(arrival) \
			+ maximum_forward + BRANCH_CORRIDOR_HALF_WIDTH \
			+ footprint.length() if grid_edge else outer_radius
		if not cache.has(key):
			# Terrain survey candidates use the canonical 3 m world lattice. Offset
			# its origin by half a cell toward the town so complete 4.5 m prefab
			# footprints can put their facade immediately across the 3 m lane instead
			# of being rounded outward to the next whole 3 m sample.
			var survey_origin := contact.point if perimeter_lot else (contact.point \
				- outward * OUTSKIRTS_GRID_STEP * 0.5 \
				if grid_edge else contact.point)
			var discovered := VillageTerrainSurvey.discover_corridor(terrain,
				survey_origin, arrival, footprint, outward,
				maximum_forward,
				BRANCH_CORRIDOR_HALF_WIDTH + minf(footprint.x, footprint.y),
				minimum_arrival_radius, maximum_arrival_radius, SURVEY_LIMIT,
				PATH_HALF_WIDTH + PARCEL_PATH_MARGIN \
					if perimeter_lot else -1.0)
			cache[key] = discovered
		var discovered := cache[key] as Array[VillageTerrainPerch]
		var branch_cycle := slot_index / maxi(1, branches.size())
		var preferred_side := -1 if posmod(branch_cycle \
			+ String(contact.stable_key).hash(), 2) == 0 else 1
		var perches := _corridor_perches(discovered, arrival,
			contact.point, outward, footprint, inner_radius,
			outer_radius, preferred_side, not grid_edge,
			perimeter_lot)
		var contact_nodes: Array[VillageCirculationNode] = [contact]
		out.append({"contact_key": contact.stable_key,
			"contact_point": [contact.point.x, contact.point.y],
			"contact_radius": contact.point.distance_to(arrival),
			"discovered_perch_count": discovered.size(),
			"contacts": contact_nodes, "perches": perches,
			"branch": branch_descriptor})
	return out


static func _corridor_perches(discovered: Array[VillageTerrainPerch],
		arrival: Vector2, contact: Vector2, outward: Vector2,
		footprint: Vector2, inner_radius: float,
		outer_radius: float, preferred_side: int = 1,
		enforce_arrival_annulus: bool = true,
		perimeter_lot: bool = false
		) -> Array[VillageTerrainPerch]:
	var out: Array[VillageTerrainPerch] = []
	var side := Vector2(-outward.y, outward.x)
	var minimum_lateral := 0.0 if perimeter_lot else PATH_CLEARANCE \
		+ minf(footprint.x, footprint.y)
	# Complete prefabs often have an intentionally off-centre authored door.
	# One shared module of tangent freedom lets that real door align to the lane
	# while keeping the building on the town lattice; a centre-only survey forced
	# such houses either to face away or overlap the contour.
	var maximum_lateral := maxf(OUTSKIRTS_GRID_STEP,
		maxf(footprint.x, footprint.y)) if perimeter_lot \
		else BRANCH_CORRIDOR_HALF_WIDTH + minf(footprint.x, footprint.y)
	for perch: VillageTerrainPerch in discovered:
		var radius := perch.anchor.distance_to(arrival)
		var delta := perch.anchor - contact
		var along := delta.dot(outward)
		var lateral := absf(delta.dot(side))
		# The prefab may be rectangular. Its legal street setback is its actual
		# oriented support radius normal to this contour, not the longest side of
		# its axis-aligned source rectangle. Using the longest side pushed a 7.5 x
		# 4.5 m compound house a full grid cell away when its 4.5 m facade depth was
		# the dimension facing the lane. Each surveyed orientation already seals a
		# yaw, so this projection makes the one-cell street gap exact by construction.
		var forward_radius := _oriented_half_extent(footprint, perch.yaw,
			outward)
		# The contour node is the centre of the one-cell public lane. For a
		# perimeter lot, placing the support edge exactly at that lane's outer edge
		# is both the correct street-wall relationship and the only phase shared by
		# even-cell prefab footprints. Adding the generic half-metre route clearance
		# here pushed those houses to the next 3 m line, after which the exact
		# perimeter-gap proof correctly rejected them as remote.
		# Perimeter surveys have already generated each orientation from its
		# exact support radius and the lane edge. Do not infer that phase a second
		# time here: the yaw conventions of the generic corridor filter describe
		# ranking axes, whereas the frontage generator owns the measured support
		# plane. Non-perimeter side lots still need the ordinary minimum offset.
		var minimum_forward := 0.0 if perimeter_lot else (PATH_CLEARANCE \
			+ minf(footprint.x, footprint.y))
		if (enforce_arrival_annulus and (radius < inner_radius - 0.001 \
				or radius > outer_radius + 0.001)) \
				or along < minimum_forward - 0.001 \
				or lateral < minimum_lateral - 0.001 \
				or lateral > maximum_lateral + 0.001:
			continue
		out.append(perch)
	# Houses occupy side parcels, never the road centreline. Prefer the requested
	# side and the first legal facade setback from the branch; repeated slots
	# alternate sides before extending farther along the street.
	out.sort_custom(func(a: VillageTerrainPerch,
			b: VillageTerrainPerch) -> bool:
		var da := a.anchor - contact
		var db := b.anchor - contact
		var a_signed := da.dot(side)
		var b_signed := db.dot(side)
		var a_wrong_side := 0 if perimeter_lot else int(
			signf(a_signed) != float(preferred_side))
		var b_wrong_side := 0 if perimeter_lot else int(
			signf(b_signed) != float(preferred_side))
		if a_wrong_side != b_wrong_side:
			return a_wrong_side < b_wrong_side
		var a_lateral := absf(da.dot(side))
		var b_lateral := absf(db.dot(side))
		var a_setback_error := absf(a_lateral - minimum_lateral)
		var b_setback_error := absf(b_lateral - minimum_lateral)
		if not is_equal_approx(a_setback_error, b_setback_error):
			return a_setback_error < b_setback_error
		var a_along := da.dot(outward)
		var b_along := db.dot(outward)
		if not is_equal_approx(a_along, b_along):
			return a_along < b_along
		return String(a.candidate_key) < String(b.candidate_key))
	return out


static func _oriented_half_extent(half_extents: Vector2, yaw: float,
		axis: Vector2) -> float:
	## Project the same XZ basis used by `VillageMassingPlacement.from_perch`
	## onto a world-space axis. This is the support-function radius of the
	## reviewed rectangular contact, so it remains correct for either admitted
	## quarter-turn and for future non-square prefabs.
	assert(axis.is_normalized())
	var basis := Basis(Vector3.UP, yaw)
	var local_x_3 := basis * Vector3.RIGHT
	var local_z_3 := basis * Vector3.BACK
	var local_x := Vector2(local_x_3.x, local_x_3.z)
	var local_z := Vector2(local_z_3.x, local_z_3.z)
	return absf(axis.dot(local_x)) * half_extents.x \
		+ absf(axis.dot(local_z)) * half_extents.y


static func _configure_perimeter_door(terrain: VillageTerrainView,
		placement: VillageMassingPlacement, spec: VillageAssetSpec,
		vocabulary: VillageElevatedProgram, survey: Dictionary) -> Dictionary:
	## A perimeter house addresses the contour lane itself. Bind its doorway to
	## the orthogonal projection on that lane before occupancy and routing are
	## compiled; scaling an arbitrary authored "one module from the door" probe
	## would otherwise jump across the whole street and make the router approach
	## the facade from behind.
	var branch := survey.get("branch", {}) as Dictionary
	if not bool(branch.get("perimeter_lot", false)):
		return {"accepted": false, "reason": &"not_perimeter_lot"}
	var transform := placement.building_transform(spec)
	placement.entrance = spec.world_entrance(transform)
	placement.entrance_outward = spec.world_entrance_outward(transform)
	if not placement.entrance_outward.is_normalized():
		return {"accepted": false, "reason": &"entrance_outward"}
	placement.access_half_width = maxf(
		VillageProgram.MODULE * placement.uniform_scale * 0.5,
		maxf(vocabulary.stair_aabb.size.x * placement.uniform_scale * 0.5,
			TraversalEnvelope.MIN_APERTURE_WIDTH * 0.5))
	var node := branch.get("node") as VillageCirculationNode
	if node == null or not node.outward.is_normalized():
		return {"accepted": false, "reason": &"branch_outward"}
	var tangent := Vector2(-node.outward.y, node.outward.x)
	var handoff := node.point + tangent \
		* (placement.entrance - node.point).dot(tangent)
	var toward_lane := handoff - placement.entrance
	if toward_lane.is_zero_approx() \
			or placement.entrance_outward.dot(toward_lane.normalized()) \
			< DOOR_BRANCH_ALIGNMENT_MIN:
		return {"accepted": false, "reason": &"direction",
			"diagnostic_geometry": {
				"asset_id": String(spec.asset_id),
				"entrance": [placement.entrance.x, placement.entrance.y],
				"entrance_outward": [placement.entrance_outward.x,
					placement.entrance_outward.y],
				"handoff": [handoff.x, handoff.y],
				"branch_root": [node.point.x, node.point.y],
				"branch_outward": [node.outward.x, node.outward.y],
				"support_centre": [placement.support_centre.x,
					placement.support_centre.y],
				"support_half_extents": [placement.support_half_extents.x,
					placement.support_half_extents.y],
				"yaw": placement.yaw,
				"alignment": placement.entrance_outward.dot(
					toward_lane.normalized()) if not toward_lane.is_zero_approx()
					else -1.0,
			}}
	var ground_y := terrain.surface_y(handoff)
	if terrain.may_be_wet(handoff) \
			or not TraversalEnvelope.step_is_legal(placement.floor_y - ground_y):
		return {"accepted": false, "reason": &"terrain",
			"diagnostic_geometry": {
				"asset_id": String(spec.asset_id),
				"handoff": [handoff.x, handoff.y],
				"floor_y": placement.floor_y,
				"ground_y": ground_y,
				"wet": terrain.may_be_wet(handoff),
			}}
	placement.entrance_ground_contact = handoff
	placement.entrance_ground_y = ground_y
	placement.street_contact = handoff
	placement.street_contact_y = ground_y
	placement.entrance_stair_count = 0
	placement.entrance_stair_base_y = ground_y
	placement.entrance_residual_step = placement.floor_y - ground_y
	placement.access_min_y = minf(placement.floor_y, ground_y)
	placement.access_max_y = maxf(placement.floor_y, ground_y) \
		+ TraversalEnvelope.MIN_HEADROOM
	placement.ground_accessible = true
	return {"accepted": true, "reason": &"accepted"}


static func parcel_conflicts_canonical_clearance(
		placement: VillageMassingPlacement,
		canonical_ground: FeatureGroundField) -> bool:
	## The canonical field is the single reservation authority shared with
	## terrain, grass, and dressing. Test the prefab's complete measured visual
	## rectangle here, before its private branch is routed; checking only the
	## door or foundation would still allow broad walls and eaves onto the road.
	return placement != null and canonical_ground != null \
		and canonical_ground.overlaps_clearance(placement.solid_shape(),
			PARCEL_PATH_MARGIN)


static func _candidate(terrain: VillageTerrainView,
		settlement_id: StringName, arrival: Vector2, primary_axis: Vector2,
		theme: StringName, program: VillageProgram,
		urban: VillageUrbanFabricPlan, spec: VillageAssetSpec,
		placement: VillageMassingPlacement,
		survey: Dictionary,
		blockers: Array[VillageMassingPlacement], occupancy: VillageOccupancy,
		max_connector_length: float,
		canonical_ground: FeatureGroundField = null
		) -> Dictionary:
	var stable_id := StringName("%s.%s" % [settlement_id,
		placement.stable_key])
	# A prefab's reviewed ground contact is its occupied lower-storey footprint.
	# The measured visual rectangle also contains roof eaves, so treating that
	# entire rectangle as a solid column to the ground falsely blocks a lane that
	# runs beside the facade. Preserve the complete upper visual envelope as a
	# second solid beginning above traversal headroom; this admits a conventional
	# eave over the pavement without weakening building/building protection.
	var solid := VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
		placement.support_centre, placement.support_half_extents,
		placement.support_angle, placement.solid_min_y,
		placement.solid_max_y, StringName("%s.solid" % stable_id), stable_id)
	var structural_volumes: Array[VillageOccupancyVolume] = [solid]
	var upper_solid_min := maxf(placement.solid_min_y,
		placement.floor_y + TraversalEnvelope.MIN_HEADROOM)
	if upper_solid_min < placement.solid_max_y - 0.001:
		structural_volumes.append(VillageOccupancyVolume.new(
			VillageOccupancy.Role.SOLID, placement.solid_centre,
			placement.solid_half_extents,
			placement.solid_angle, upper_solid_min,
			placement.solid_max_y, StringName("%s.upper_solid" % stable_id),
			stable_id))
	var access := VillageOccupancyVolume.new(VillageOccupancy.Role.HEADROOM,
		(placement.entrance + placement.entrance_ground_contact) * 0.5,
		Vector2(maxf(placement.entrance.distance_to(
			placement.entrance_ground_contact), VillageProgram.MODULE) * 0.5,
			placement.access_half_width), placement.entrance_outward.angle(),
		placement.access_min_y, placement.access_max_y,
		StringName("%s.access" % stable_id), stable_id)
	var initial_volumes := structural_volumes.duplicate()
	initial_volumes.append(access)
	for volume: VillageOccupancyVolume in initial_volumes:
		var conflicts := occupancy.conflicts(volume)
		if not conflicts.is_empty():
			var existing := conflicts[0] as VillageOccupancyVolume
			return {"accepted": false, "reason": &"occupancy",
				"diagnostic_geometry": {
					"candidate_volume": String(volume.stable_id),
					"candidate_centre": [volume.centre.x, volume.centre.y],
					"candidate_half_extents": [volume.half_extents.x,
						volume.half_extents.y],
					"existing_volume": String(existing.stable_id),
					"existing_owner": String(existing.owner_id),
					"existing_centre": [existing.centre.x, existing.centre.y],
					"existing_half_extents": [existing.half_extents.x,
						existing.half_extents.y],
				}}
	for urban_surface: FeatureGroundShape in urban.surfaces:
		if placement.support_shape().intersects(urban_surface,
				PARCEL_PATH_MARGIN):
			return {"accepted": false, "reason": &"urban_path_overlap"}
	# The road field is already the canonical reservation authority used by
	# terrain, grass and props. Outskirts parcels must consult that same field
	# before routing; otherwise their locally generated branch graph can be valid
	# while the prefab itself lands on the pre-existing world road. Check the
	# complete measured visual/eave rectangle, not only the foundation contact.
	if parcel_conflicts_canonical_clearance(placement, canonical_ground):
		return {"accepted": false, "reason": &"canonical_road_overlap"}
	var from := VillageCirculationNode.new(
		StringName("%s.terrain" % placement.stable_key),
		VillageCirculationNode.Kind.TERRAIN_CONTACT,
		placement.street_contact, placement.street_contact_y,
		placement.stable_key, placement.entrance_outward)
	var contacts: Array[VillageCirculationNode] = []
	contacts.assign(survey.get("contacts", []) as Array)
	var branch_descriptor := survey.get("branch", {}) as Dictionary
	var ordered_contacts := _resolved_branch_contacts(terrain, from, contacts)
	ordered_contacts.sort_custom(func(a: VillageCirculationNode,
			b: VillageCirculationNode) -> bool:
		var a_distance := a.point.distance_squared_to(from.point)
		var b_distance := b.point.distance_squared_to(from.point)
		if a_distance != b_distance:
			return a_distance < b_distance
		return String(a.stable_key) < String(b.stable_key))
	var routes: Array[VillageCirculationLink] = []
	# Index of the optional doorway-normal spur within `routes`. A wide prefab
	# may put its real door directly on the contour lane; in that case the typed
	# entrance apron already closes the threshold and no zero-length route edge
	# may be manufactured.
	var parcel_route_index := -1
	var all_blockers := blockers.duplicate()
	all_blockers.append(placement)
	var route_blocking_volumes := _market_blocking_volumes(urban)
	var branch_alignment := 1.0
	var parcel_connector_length := 0.0
	var perimeter_gap := -1.0
	if not branch_descriptor.is_empty():
		var branch_node := branch_descriptor.get("node") \
			as VillageCirculationNode
		var source_node := branch_descriptor.get("source_node") \
			as VillageCirculationNode
		var network_nodes: Array[VillageCirculationNode] = []
		network_nodes.assign(branch_descriptor.get("network_nodes", []) as Array)
		var perimeter_lot := bool(branch_descriptor.get("perimeter_lot", false))
		if network_nodes.is_empty() and branch_node != null:
			network_nodes.append(branch_node)
		if branch_node == null or source_node == null \
				or not branch_node.outward.is_normalized() \
				or network_nodes.is_empty() \
				or network_nodes[-1].point.distance_to(branch_node.point) > 0.01:
			return {"accepted": false, "reason": &"branch_contract"}
		perimeter_gap = maxf(0.0,
			placement.support_shape().signed_distance(branch_node.point)
			- PATH_HALF_WIDTH)
		if perimeter_lot and perimeter_gap > MAX_PERIMETER_GAP + 0.001:
			return {"accepted": false, "reason": &"perimeter_setback",
				"perimeter_gap": perimeter_gap,
				"diagnostic_geometry": {
					"branch_root": [branch_node.point.x, branch_node.point.y],
					"branch_outward": [branch_node.outward.x,
						branch_node.outward.y],
					"support_centre": [placement.support_centre.x,
						placement.support_centre.y],
					"support_half_extents": [placement.support_half_extents.x,
						placement.support_half_extents.y],
					"support_angle": placement.support_angle,
					"perimeter_gap": perimeter_gap,
				}}
		var along := maxf(0.0, (from.point - branch_node.point).dot(
			branch_node.outward))
		# A perimeter house fronts the wrapping lane itself. Its short doorstep
		# route begins at the contour root, allowing the router to absorb an
		# authored prefab's off-centre door with one exterior right-angle turn.
		# Extending the lane centreline toward the house first can sweep under a
		# wide facade even though the actual doorway is correctly beside the lane.
		var handoff_point := branch_node.point + branch_node.outward * along
		if perimeter_lot:
			# The root is a lattice junction; the actual doorway may be authored off
			# centre. Meet it at its orthogonal projection onto this one-cell-wide
			# street instead of aiming diagonally from the cell centre. The bounded
			# half-cell tangent segment remains part of the same lane and lets the
			# complete prefab face the street squarely.
			var tangent := Vector2(-branch_node.outward.y,
				branch_node.outward.x)
			# The junction root is one sample on a continuous contour lane, not
			# necessarily the centre of an authored facade. Project to the actual
			# doorway tangent so broad compound prefabs retain a square approach.
			# Connector length and the bounded neighborhood graph still cap this
			# segment; clamping it to half a cell made every off-centre large-house
			# door approach diagonally and falsely rejected it.
			var tangent_offset := (placement.entrance \
				- branch_node.point).dot(tangent)
			handoff_point = branch_node.point + tangent * tangent_offset
		var toward_branch := handoff_point - placement.entrance
		branch_alignment = placement.entrance_outward.dot(
			toward_branch.normalized()) if not toward_branch.is_zero_approx() \
			else -1.0
		if branch_alignment < DOOR_BRANCH_ALIGNMENT_MIN:
			return {"accepted": false, "reason": &"door_away_from_branch",
				"door_branch_alignment": branch_alignment,
				"diagnostic_geometry": {
					"entrance": [placement.entrance.x, placement.entrance.y],
					"street_contact": [from.point.x, from.point.y],
					"handoff": [handoff_point.x, handoff_point.y],
					"branch_root": [branch_node.point.x, branch_node.point.y],
					"entrance_outward": [placement.entrance_outward.x,
						placement.entrance_outward.y],
					"yaw": placement.yaw,
				}}
		var branch_corridor := FeatureGroundShape.capsule(branch_node.point,
			handoff_point, PATH_HALF_WIDTH)
		if not perimeter_lot and placement.support_shape().intersects(
				branch_corridor, PARCEL_PATH_MARGIN):
			return {"accepted": false, "reason": &"house_on_branch"}
		var main_a := branch_descriptor.get("main_path_a",
			source_node.point) as Vector2
		var main_b := branch_descriptor.get("main_path_b",
			branch_node.point) as Vector2
		if main_a.distance_to(main_b) > 0.01 \
			and placement.support_shape().intersects(
					FeatureGroundShape.capsule(main_a, main_b, PATH_HALF_WIDTH),
					PARCEL_PATH_MARGIN):
			return {"accepted": false, "reason": &"house_on_main_path"}
		# The final contour edge terminates at this parcel's declared frontage.
		# Its rounded lane cap is allowed to meet the facade/door seam; every
		# earlier distributor edge remains unrelated construction and must clear
		# the complete house envelope.
		var checked_network_end := network_nodes.size() - 1 \
			if perimeter_lot else network_nodes.size()
		for network_index in range(1, checked_network_end):
			var network_a := network_nodes[network_index - 1].point
			var network_b := network_nodes[network_index].point
			if placement.support_shape().intersects(
					FeatureGroundShape.capsule(network_a, network_b,
						PATH_HALF_WIDTH), PARCEL_PATH_MARGIN):
				return {"accepted": false,
					"reason": &"house_on_perimeter_distributor"}
		var handoff := VillageCirculationNode.new(StringName(
			"%s.handoff" % placement.stable_key),
			VillageCirculationNode.Kind.TERRAIN_CONTACT, handoff_point,
			terrain.surface_y(handoff_point), placement.stable_key,
			branch_node.outward)
		# The ordered nodes describe the shared source-to-contour infrastructure.
		# Stable edge identities let several parcels reuse that graph without
		# duplicating its surface, clearance, headroom, or stair payload.
		var route_nodes: Array[VillageCirculationNode] = []
		route_nodes.append_array(network_nodes)
		if route_nodes[-1].point.distance_to(handoff.point) > 0.01:
			route_nodes.append(handoff)
		if route_nodes[-1].point.distance_to(from.point) > 0.01:
			parcel_route_index = route_nodes.size() - 1
			route_nodes.append(from)
		# The contour is shared settlement infrastructure. The bounded
		# per-parcel connector is only the outward frontage plus the door spur;
		# otherwise a larger or more articulated core would make a valid lot fail
		# solely because its shared perimeter route is longer.
		var connector_length := branch_node.point.distance_to(handoff.point) \
			+ handoff.point.distance_to(from.point)
		parcel_connector_length = connector_length
		if connector_length > max_connector_length + 0.001:
			return {"accepted": false, "reason": &"connector_length"}
		for node_index in range(1, route_nodes.size()):
			var link: VillageCirculationLink
			if node_index < network_nodes.size():
				link = VillageGroundRouter.fixed_link(terrain,
					route_nodes[node_index - 1], route_nodes[node_index],
					all_blockers, program.elevated_program,
					route_blocking_volumes)
			else:
				link = VillageGroundRouter.best_link(terrain, arrival,
					primary_axis, route_nodes[node_index - 1],
					route_nodes[node_index], all_blockers,
					program.elevated_program, route_blocking_volumes)
			if link == null:
				return {"accepted": false, "reason": &"connector"}
			routes.append(link)
	else:
		for contact: VillageCirculationNode in ordered_contacts:
			if from.point.distance_to(contact.point) \
					> max_connector_length + 0.001:
				continue
			var route := VillageGroundRouter.best_link(terrain, arrival,
				primary_axis, from, contact, all_blockers,
				program.elevated_program, route_blocking_volumes)
			if route != null:
				routes.append(route)
				break
		if routes.is_empty():
			return {"accepted": false, "reason": &"connector"}
	var route_plan := VillageCirculationPlan.new()
	route_plan.accepted = true
	route_plan.reason = &"accepted"
	route_plan.links.append_array(routes)
	var stairs := VillageRouteStairFabricSolver.solve(settlement_id,
		route_plan, program.elevated_program, urban.public_walk_network_id)
	if not stairs.accepted:
		return {"accepted": false,
			"reason": StringName("stairs_%s" % String(stairs.reason))}
	var building_transform := placement.building_transform(spec)
	var entries: Array[Dictionary] = [{"asset_id":
		spec.asset_for_theme(theme), "stable_id": stable_id,
		"transform": building_transform}]
	for attachment: VillageAttachedAssetSpec in spec.attachments:
		entries.append({"asset_id": attachment.asset_for_theme(theme),
			"stable_id": StringName("%s.component.%s" % [stable_id,
				attachment.stable_key]),
			"transform": attachment.world_transform(building_transform)})
	entries.append_array(stairs.entries)
	var volumes: Array[VillageOccupancyVolume] = []
	volumes.append_array(structural_volumes)
	volumes.append(access)
	volumes.append_array(stairs.volumes)
	var surfaces: Array[FeatureGroundShape] = []
	var clearances: Array[FeatureGroundShape] = []
	var ground_owner := StringName("%s.ground_circulation" % settlement_id)
	var walk_network := urban.public_walk_network_id
	if walk_network.is_empty():
		walk_network = StringName("%s.urban.walk_network" % settlement_id)
	for route_index in routes.size():
		var route := routes[route_index]
		# The shared street keeps the full scaled fine-cell width. Its last few
		# metres taper to the prefab's measured doorway aperture; widening that
		# private threshold back to a whole 3 m cell would reserve headroom through
		# the two wall piers beside the door.
		var is_parcel_route := not branch_descriptor.is_empty() \
			and route_index == parcel_route_index
		var route_half_width := placement.access_half_width \
			if is_parcel_route else PATH_HALF_WIDTH
		# The final threshold spur is a declared part of this house's frontage,
		# not anonymous settlement headroom cutting through the house envelope.
		# Giving that one connector the house owner makes its contact with the
		# typed doorway seam legal while every shared street remains independently
		# owned and collision-checked.
		var route_owner := stable_id if is_parcel_route else ground_owner
		for index in range(1, route.samples.size()):
			var a := route.samples[index - 1]
			var b := route.samples[index]
			var a2 := Vector2(a.x, a.z)
			var b2 := Vector2(b.x, b.z)
			if a2.distance_to(b2) <= 0.01:
				continue
			var route_id := StringName("%s.%s.outskirts.%03d" % [
				settlement_id, route.stable_key, index])
			surfaces.append(FeatureGroundShape.capsule(a2, b2,
				route_half_width, FeatureGroundField.WORN_PATH,
				VillagePlan.SURFACE_PRIORITY, route_id))
			clearances.append(FeatureGroundShape.capsule(a2, b2,
				route_half_width + 0.5, FeatureGroundField.NATURAL, 0,
				StringName("%s.clearance" % route_id)))
			volumes.append(VillageOccupancyVolume.new(
				VillageOccupancy.Role.HEADROOM, (a2 + b2) * 0.5,
				Vector2(a2.distance_to(b2) * 0.5, route_half_width),
				(b2 - a2).angle(), minf(a.y, b.y),
				maxf(a.y, b.y) + TraversalEnvelope.MIN_HEADROOM,
				StringName("%s.headroom" % route_id), route_owner,
				walk_network))
	var lot := spec.world_lot(building_transform)
	clearances.append(FeatureGroundShape.oriented_rect(
		lot.centre, lot.half_extents, lot.angle,
		FeatureGroundField.NATURAL, 0,
		StringName("%s.clearance" % stable_id)))
	# Ground houses carry the same measured perimeter-foundation transaction as
	# legacy massing. The support is solved after the route so neither its stone
	# modules nor its occupancy can block the lane or doorway that makes this
	# house part of the city.
	var support_reservations: Array[VillageOccupancyVolume] = []
	support_reservations.append_array(occupancy.volumes())
	support_reservations.append_array(volumes)
	var support := VillageBuildingSupportSolver.solve(terrain, stable_id,
		placement, spec, program, support_reservations)
	if not support.accepted:
		return {"accepted": false,
			"reason": StringName("support_%s" % String(support.reason))}
	entries.append_array(support.pieces)
	volumes.append_array(support.volumes)
	var cross_conflict := VillageOccupancy.first_cross_conflict(volumes,
		occupancy.volumes())
	if not cross_conflict.is_empty():
		var conflict_candidate := cross_conflict.candidate \
			as VillageOccupancyVolume
		var conflict_existing := cross_conflict.existing \
			as VillageOccupancyVolume
		return {"accepted": false, "reason": &"route_occupancy",
			"door_branch_alignment": branch_alignment,
			"diagnostic_geometry": {
				"candidate": String(conflict_candidate.stable_id),
				"candidate_owner": String(conflict_candidate.owner_id),
				"candidate_role": conflict_candidate.role,
				"candidate_walk_network": String(
					conflict_candidate.walk_network_id),
				"existing": String(conflict_existing.stable_id),
				"existing_owner": String(conflict_existing.owner_id),
				"existing_role": conflict_existing.role,
				"existing_walk_network": String(
					conflict_existing.walk_network_id),
				"branch_root": [branch_descriptor.node.point.x,
					branch_descriptor.node.point.y],
				"source": [branch_descriptor.source_node.point.x,
					branch_descriptor.source_node.point.y],
			}}
	var local := VillageOccupancy.new()
	var internal_conflict := local.first_conflict(volumes)
	if not internal_conflict.is_empty():
		var internal_candidate := internal_conflict.candidate \
			as VillageOccupancyVolume
		var internal_existing := internal_conflict.existing \
			as VillageOccupancyVolume
		return {"accepted": false, "reason": &"internal_occupancy",
			"door_branch_alignment": branch_alignment,
			"diagnostic_geometry": {
				"candidate": String(internal_candidate.stable_id),
				"candidate_owner": String(internal_candidate.owner_id),
				"candidate_role": internal_candidate.role,
				"existing": String(internal_existing.stable_id),
				"existing_owner": String(internal_existing.owner_id),
				"existing_role": internal_existing.role,
			}}
	assert(local.add_all(volumes))
	return {"accepted": true, "reason": &"accepted", "entries": entries,
		"volumes": volumes, "surfaces": surfaces,
		"clearances": clearances, "stair_count": stairs.stair_count,
		"foundation_piece_count": support.pieces.size(),
		"door_branch_alignment": branch_alignment,
		"parcel_connector_length": parcel_connector_length,
		"perimeter_gap": perimeter_gap}


static func _append_unique_entries(target: Array[Dictionary], incoming: Array,
		seen: Dictionary) -> void:
	for entry: Dictionary in incoming:
		var stable_id := StringName(entry.get("stable_id", &""))
		assert(not stable_id.is_empty())
		if seen.has(stable_id):
			continue
		seen[stable_id] = true
		target.append(entry)


static func _append_unique_volumes(
		target: Array[VillageOccupancyVolume], incoming: Array,
		seen: Dictionary) -> Array[VillageOccupancyVolume]:
	var novel: Array[VillageOccupancyVolume] = []
	for volume: VillageOccupancyVolume in incoming:
		assert(not volume.stable_id.is_empty())
		if seen.has(volume.stable_id):
			continue
		seen[volume.stable_id] = true
		target.append(volume)
		novel.append(volume)
	return novel


static func _append_unique_shapes(target: Array[FeatureGroundShape],
		incoming: Array, seen: Dictionary) -> void:
	for shape: FeatureGroundShape in incoming:
		assert(not shape.stable_id.is_empty())
		if seen.has(shape.stable_id):
			continue
		seen[shape.stable_id] = true
		target.append(shape)


static func _outskirts_annulus(urban: VillageUrbanFabricPlan,
		arrival: Vector2, volumetric: bool) -> Vector2:
	## Legacy authored layouts retain their reviewed annulus. Volumetric towns
	## use their exact contour for placement; this reach remains only the bounded
	## search/connector ceiling, so world scale cannot invalidate a legal lot.
	if not volumetric:
		return Vector2(VillageOutskirtsProgram.INNER_RADIUS,
			VillageOutskirtsProgram.OUTER_RADIUS)
	var core_reach := 0.0
	for shape: FeatureGroundShape in urban.clearances:
		var bounds := shape.bounds()
		for point: Vector2 in [bounds.position,
				Vector2(bounds.end.x, bounds.position.y),
				Vector2(bounds.position.x, bounds.end.y), bounds.end]:
			core_reach = maxf(core_reach, point.distance_to(arrival))
	# Urban clearance is already the exact union of lots, public surfaces, and
	# their safety envelopes. One path-width band beyond it is sufficient;
	# individual prefab solids still pass exact occupancy and shape intersection
	# tests. A whole terrain macro-cell here produced a vacant moat rather than a
	# porous town edge.
	var inner_radius := maxf(VillageOutskirtsProgram.INNER_RADIUS,
		core_reach + VillageProgram.MODULE * 2.0)
	return Vector2(inner_radius,
		inner_radius + VillageOutskirtsProgram.OUTSKIRTS_BAND_WIDTH)


static func _resolved_branch_contacts(terrain: VillageTerrainView,
		from: VillageCirculationNode,
		contacts: Array[VillageCirculationNode]
		) -> Array[VillageCirculationNode]:
	## The canonical warren entry represents the continuing exterior world road,
	## not a point every edge house should retrace to. Resolve a parcel's handoff
	## to its orthogonal projection on that authored outward ray. The generated
	## connector is then the requested smaller branch from the main road; its
	## endpoint, length, and stable identity all follow from the selected parcel.
	var out: Array[VillageCirculationNode] = []
	for contact: VillageCirculationNode in contacts:
		if contact.stable_key != &"warren.canonical_entry" \
				or not contact.outward.is_normalized():
			out.append(contact)
			continue
		var along := maxf(0.0,
			(from.point - contact.point).dot(contact.outward))
		var point := contact.point + contact.outward * along
		var lattice := Vector2i(roundi(point.x / VillageProgram.MODULE),
			roundi(point.y / VillageProgram.MODULE))
		out.append(VillageCirculationNode.new(StringName(
			"warren.road_handoff.%d.%d" % [lattice.x, lattice.y]),
			VillageCirculationNode.Kind.TERRAIN_CONTACT, point,
			terrain.surface_y(point), contact.owner_key, contact.outward))
	return out


static func _ground_contacts(terrain: VillageTerrainView, arrival: Vector2,
		primary_axis: Vector2, urban: VillageUrbanFabricPlan
		) -> Array[VillageCirculationNode]:
	var out: Array[VillageCirculationNode] = []
	if urban.circulation != null:
		for node: VillageCirculationNode in urban.circulation.nodes:
			if node.kind == VillageCirculationNode.Kind.ARRIVAL \
					or node.kind == VillageCirculationNode.Kind.TERRAIN_CONTACT:
				out.append(node)
		return out
	# Volumetric warren: derive route exits from the exact sealed public union.
	# A terrain-street endpoint qualifies only where its world floor is within an
	# ordinary player step of natural terrain. The same local-to-world transform
	# that materialized the town supplies its point, so an outskirts lane cannot
	# start at a guessed radius, inside a wall, or halfway up the massif.
	if urban.fabric_plan != null and urban.fabric_plan.surface_plan != null:
		var surface := urban.fabric_plan.surface_plan
		var street_cells := surface.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET)
		var candidates: Array[Dictionary] = []
		for cell: Vector3i in street_cells:
			var degree := 0
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				for rise in range(-1, 2):
					if surface.has_cell(cell + direction + Vector3i.UP * rise):
						degree += 1
						break
			if degree > 1:
				continue
			var world3 := urban.world_transform \
				* (Vector3(cell) * FabricRecipe.CELL_SIZE)
			var point := Vector2(world3.x, world3.z)
			var ground_y := terrain.surface_y(point)
			if absf(world3.y - ground_y) \
					> TraversalEnvelope.MAX_PLANNED_STEP + 0.001:
				continue
			candidates.append({"cell": cell, "point": point,
				"height": ground_y, "distance": point.distance_squared_to(arrival)})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.distance) > float(b.distance) \
				if not is_equal_approx(float(a.distance), float(b.distance)) \
				else String(a.cell) < String(b.cell))
		for candidate: Dictionary in candidates:
			var point := candidate.point as Vector2
			var separated := true
			for contact: VillageCirculationNode in out:
				separated = separated and contact.point.distance_to(point) \
					>= FabricRecipe.CELL_SIZE * 2.0
			if not separated:
				continue
			var outward := point - arrival
			outward = outward.normalized() if not outward.is_zero_approx() \
				else -primary_axis
			out.append(VillageCirculationNode.new(StringName(
				"warren.exit.%d.%d.%d" % [(candidate.cell as Vector3i).x,
					(candidate.cell as Vector3i).y, (candidate.cell as Vector3i).z]),
				VillageCirculationNode.Kind.TERRAIN_CONTACT, point,
				float(candidate.height), &"warren.public_exit", outward))
		if not out.is_empty():
			return out
	# A generated warren has one canonical boundary entry and a first itinerary
	# segment that points into its mass. Transform both with the same sealed world
	# frame used by render, collision, and ground paint; the opposite direction is
	# therefore the authored exterior continuation. This remains available when
	# the finished terrain-street union has no degree-one endpoint (for example a
	# loop at the threshold), and replaces the old guessed point halfway through
	# the outskirts annulus.
	if urban.volumetric_spatial != null \
			and urban.volumetric_spatial.source_volume != null:
		var source := urban.volumetric_spatial.source_volume
		var entry := source.entry_cell
		var entry_local := Vector3(
			float(entry.x) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M \
				+ FabricRecipe.CELL_SIZE * 0.5,
			float(entry.y) * WarrenVolumePlan.VERTICAL_BAND_SIZE_M,
			float(entry.z) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M \
				+ FabricRecipe.CELL_SIZE * 0.5)
		var world_entry := urban.world_transform * entry_local
		var entry_point := Vector2(world_entry.x, world_entry.z)
		var route_delta := source.primary_itinerary[1] - entry
		var local_inward := Vector3(float(route_delta.x), 0.0,
			float(route_delta.z)).normalized()
		var world_inward3 := urban.world_transform.basis * local_inward
		var outward := -Vector2(world_inward3.x, world_inward3.z).normalized()
		var ground_y := terrain.surface_y(entry_point)
		if outward.is_normalized() and absf(world_entry.y - ground_y) \
				<= TraversalEnvelope.MAX_PLANNED_STEP + 0.001:
			out.append(VillageCirculationNode.new(&"warren.canonical_entry",
				VillageCirculationNode.Kind.TERRAIN_CONTACT, entry_point,
				ground_y, &"warren.public_entry", outward))
			return out
	# Compact isolated fixtures have no source volume. Retain a contract-derived
	# approach only for those tests/custom programs; production warrens take one
	# of the two exact topology branches above.
	var point := arrival - primary_axis \
		* (VillageOutskirtsProgram.INNER_RADIUS * 0.5)
	out.append(VillageCirculationNode.new(&"warren.approach",
		VillageCirculationNode.Kind.TERRAIN_CONTACT, point,
		terrain.surface_y(point), &"warren.approach", -primary_axis))
	return out


static func _market_blocking_volumes(urban: VillageUrbanFabricPlan
		) -> Array[VillageOccupancyVolume]:
	if urban.market != null:
		return urban.market.blocking_volumes()
	var empty: Array[VillageOccupancyVolume] = []
	return empty


static func _rejected(reason: StringName) -> VillageOutskirtsPlan:
	var plan := VillageOutskirtsPlan.new()
	plan.reason = reason
	return plan

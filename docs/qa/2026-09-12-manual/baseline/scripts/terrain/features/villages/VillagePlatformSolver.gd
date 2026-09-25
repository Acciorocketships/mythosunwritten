class_name VillagePlatformSolver
extends RefCounted

## Connects nearby upper doors on the same finished floor, then unions the
## selected minimum edge set into inhabited platform regions. It never grows a
## platform from an empty anchor and never changes a building floor.
const MAX_JOIN_RADIUS := VillageMassingProgram.MAX_PLATFORM_JOIN_RADIUS
const PLATFORM_HALF_WIDTH := VillageProgram.MODULE * 0.5
const SEARCH_MARGIN_CELLS := 6
const MAX_ROUTE_CELLS := 33


static func solve(origin: Vector2, primary_axis: Vector2,
		placements: Array[VillageMassingPlacement],
		reserved_volumes: Array[VillageOccupancyVolume] = []) -> Dictionary:
	assert(origin.is_finite() and primary_axis.is_normalized())
	var groups: Dictionary = {}
	for placement: VillageMassingPlacement in placements:
		if placement.ground_accessible:
			continue
		var key := roundi(placement.floor_y * 1000.0)
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(placement)
	var regions: Array[VillagePlatformRegion] = []
	var links: Array[VillageCirculationLink] = []
	var candidate_count := 0
	var floor_keys: Array = groups.keys()
	floor_keys.sort()
	for floor_key: int in floor_keys:
		var group: Array[VillageMassingPlacement] = []
		group.assign(groups[floor_key])
		group.sort_custom(func(a: VillageMassingPlacement,
				b: VillageMassingPlacement) -> bool:
			return String(a.stable_key) < String(b.stable_key))
		if group.size() < 2:
			continue
		var candidates := _edge_candidates(origin, primary_axis, group,
			placements, reserved_volumes)
		candidate_count += candidates.size()
		var selected := _minimum_edges(group, candidates)
		_append_regions(regions, links, group, selected, primary_axis,
			floor_key)
	return {"regions": regions, "links": links,
		"candidate_count": candidate_count}


static func _edge_candidates(origin: Vector2, primary_axis: Vector2,
		group: Array[VillageMassingPlacement],
		all_placements: Array[VillageMassingPlacement],
		reserved_volumes: Array[VillageOccupancyVolume]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in group.size():
		for prior in index:
			var a := group[prior]
			var b := group[index]
			if a.entrance.distance_to(b.entrance) > MAX_JOIN_RADIUS:
				continue
			var best: Dictionary = {}
			for cells: Array[Vector2] in _cell_paths(origin, primary_axis,
					a, b):
				var samples := _samples(a, b, cells)
				if VillageRouteGeometry.path_hits_solids(samples,
						all_placements, a.stable_key, b.stable_key,
						PLATFORM_HALF_WIDTH) \
						or VillageRouteGeometry.path_hits_volumes(samples,
							reserved_volumes, PLATFORM_HALF_WIDTH):
					continue
				var signature := _cell_signature(cells)
				if best.is_empty() or cells.size() < (best.cells as Array).size() \
						or (cells.size() == (best.cells as Array).size() \
							and signature < String(best.signature)):
					best = {"cells": cells, "samples": samples,
						"signature": signature}
			if best.is_empty():
				var searched := _searched_cell_path(origin, primary_axis, a, b,
					all_placements, reserved_volumes)
				if not searched.is_empty():
					var searched_samples := _samples(a, b, searched)
					if not VillageRouteGeometry.path_hits_solids(
							searched_samples, all_placements, a.stable_key,
							b.stable_key, PLATFORM_HALF_WIDTH) \
							and not VillageRouteGeometry.path_hits_volumes(
								searched_samples, reserved_volumes,
								PLATFORM_HALF_WIDTH):
						best = {"cells": searched,
							"samples": searched_samples,
							"signature": _cell_signature(searched)}
			if best.is_empty():
				continue
			var link := VillageCirculationLink.new(
				VillageRouteGeometry.edge_key(&"platform",
					StringName("%s.door" % a.stable_key),
					StringName("%s.door" % b.stable_key)),
				VillageCirculationLink.Kind.SHARED_PLATFORM,
				StringName("%s.door" % a.stable_key),
				StringName("%s.door" % b.stable_key))
			link.control_points = best.samples
			link.samples = best.samples
			link.length = VillageRouteGeometry.polyline_length(link.samples)
			if not link.is_valid():
				continue
			out.append({"a": a, "b": b, "link": link,
				"cells": best.cells, "signature": best.signature})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (a.cells as Array).size() != (b.cells as Array).size():
			return (a.cells as Array).size() < (b.cells as Array).size()
		return String(a.link.stable_key) < String(b.link.stable_key))
	return out


static func _minimum_edges(group: Array[VillageMassingPlacement],
		candidates: Array[Dictionary]) -> Array[Dictionary]:
	var parent: Dictionary = {}
	for placement: VillageMassingPlacement in group:
		parent[placement.stable_key] = placement.stable_key
	var out: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		var a: StringName = candidate.a.stable_key
		var b: StringName = candidate.b.stable_key
		if _find(parent, a) == _find(parent, b):
			continue
		_union(parent, a, b)
		out.append(candidate)
	return out


static func _append_regions(regions: Array[VillagePlatformRegion],
		links: Array[VillageCirculationLink],
		group: Array[VillageMassingPlacement], selected: Array[Dictionary],
		primary_axis: Vector2, floor_key: int) -> void:
	if selected.is_empty():
		return
	var parent: Dictionary = {}
	for placement: VillageMassingPlacement in group:
		parent[placement.stable_key] = placement.stable_key
	for edge: Dictionary in selected:
		_union(parent, edge.a.stable_key, edge.b.stable_key)
	var by_root: Dictionary = {}
	for edge: Dictionary in selected:
		var root := _find(parent, edge.a.stable_key)
		if not by_root.has(root):
			by_root[root] = []
		(by_root[root] as Array).append(edge)
	var roots: Array = by_root.keys()
	roots.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for root: StringName in roots:
		var edges: Array = by_root[root]
		var frontage_set: Dictionary = {}
		var cell_set: Dictionary = {}
		for edge: Dictionary in edges:
			frontage_set[edge.a.stable_key] = true
			frontage_set[edge.b.stable_key] = true
			links.append(edge.link)
			for centre: Vector2 in edge.cells:
				cell_set[_point_key(centre)] = centre
		var region := VillagePlatformRegion.new()
		region.stable_key = StringName("platform.band_%d.%s" % [
			floor_key, root])
		region.frontage_keys.assign(frontage_set.keys())
		region.frontage_keys.sort_custom(func(a: StringName,
				b: StringName) -> bool: return String(a) < String(b))
		region.surface_y = float(floor_key) / 1000.0
		region.yaw = primary_axis.angle()
		var cell_keys: Array = cell_set.keys()
		cell_keys.sort()
		for key: String in cell_keys:
			region.cell_centres.append(cell_set[key])
		if region.is_valid():
			regions.append(region)


static func _cell_paths(origin: Vector2, primary_axis: Vector2,
		a: VillageMassingPlacement,
		b: VillageMassingPlacement) -> Array[Array]:
	var start := _frontage_cell(a, origin, primary_axis)
	var finish := _frontage_cell(b, origin, primary_axis)
	var cell_paths: Array[Array] = []
	for x_first: bool in [true, false]:
		var cells: Array[Vector2i] = [start]
		var cursor := start
		var axes: Array[int] = []
		axes.assign([0, 1] if x_first else [1, 0])
		for axis: int in axes:
			while cursor[axis] != finish[axis]:
				cursor[axis] += 1 if finish[axis] > cursor[axis] else -1
				cells.append(cursor)
		var world_cells: Array[Vector2] = []
		for cell: Vector2i in cells:
			world_cells.append(_grid_world(cell, origin, primary_axis))
		if cell_paths.is_empty() \
				or _cell_signature(world_cells) \
					!= _cell_signature(cell_paths[0]):
			cell_paths.append(world_cells)
	return cell_paths


static func _searched_cell_path(origin: Vector2, primary_axis: Vector2,
		a: VillageMassingPlacement, b: VillageMassingPlacement,
		placements: Array[VillageMassingPlacement],
		reserved_volumes: Array[VillageOccupancyVolume]) -> Array[Vector2]:
	var start := _frontage_cell(a, origin, primary_axis)
	var finish := _frontage_cell(b, origin, primary_axis)
	var minimum := Vector2i(mini(start.x, finish.x),
		mini(start.y, finish.y)) - Vector2i.ONE * SEARCH_MARGIN_CELLS
	var maximum := Vector2i(maxi(start.x, finish.x),
		maxi(start.y, finish.y)) + Vector2i.ONE * SEARCH_MARGIN_CELLS
	var pending: Array[Vector2i] = [start]
	var head := 0
	var parent: Dictionary = {_grid_key(start): start}
	var depth: Dictionary = {_grid_key(start): 1}
	while head < pending.size():
		var current := pending[head]
		head += 1
		if current == finish:
			return _reconstruct_cells(parent, current, origin, primary_axis)
		var current_depth := int(depth[_grid_key(current)])
		if current_depth >= MAX_ROUTE_CELLS:
			continue
		for step: Vector2i in _ordered_steps(current, finish):
			var neighbour := current + step
			if neighbour.x < minimum.x or neighbour.y < minimum.y \
					or neighbour.x > maximum.x or neighbour.y > maximum.y:
				continue
			var key := _grid_key(neighbour)
			if parent.has(key) or not _cell_edge_is_clear(current, neighbour,
					origin, primary_axis, a, b, placements, reserved_volumes):
				continue
			parent[key] = current
			depth[key] = current_depth + 1
			pending.append(neighbour)
	return []


static func _ordered_steps(current: Vector2i,
		finish: Vector2i) -> Array[Vector2i]:
	var steps: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN,
		Vector2i.LEFT, Vector2i.UP]
	steps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var distance_a := (finish - (current + a)).length_squared()
		var distance_b := (finish - (current + b)).length_squared()
		if distance_a != distance_b:
			return distance_a < distance_b
		return _grid_key(a) < _grid_key(b))
	return steps


static func _cell_edge_is_clear(from: Vector2i, to: Vector2i,
		origin: Vector2, primary_axis: Vector2,
		a: VillageMassingPlacement, b: VillageMassingPlacement,
		placements: Array[VillageMassingPlacement],
		reserved_volumes: Array[VillageOccupancyVolume]) -> bool:
	var samples: Array[Vector3] = [
		VillageRouteGeometry.point3(_grid_world(from, origin, primary_axis),
			a.floor_y),
		VillageRouteGeometry.point3(_grid_world(to, origin, primary_axis),
			a.floor_y),
	]
	return not VillageRouteGeometry.path_hits_solids(samples, placements,
		a.stable_key, b.stable_key, PLATFORM_HALF_WIDTH) \
		and not VillageRouteGeometry.path_hits_volumes(samples,
			reserved_volumes, PLATFORM_HALF_WIDTH)


static func _reconstruct_cells(parent: Dictionary, finish: Vector2i,
		origin: Vector2, primary_axis: Vector2) -> Array[Vector2]:
	var reversed: Array[Vector2i] = [finish]
	var cursor := finish
	while parent[_grid_key(cursor)] != cursor:
		cursor = parent[_grid_key(cursor)]
		reversed.append(cursor)
	reversed.reverse()
	var out: Array[Vector2] = []
	for cell: Vector2i in reversed:
		out.append(_grid_world(cell, origin, primary_axis))
	return out


static func _samples(a: VillageMassingPlacement,
		b: VillageMassingPlacement, cells: Array[Vector2]) -> Array[Vector3]:
	var out: Array[Vector3] = [VillageRouteGeometry.point3(a.entrance,
		a.floor_y)]
	_append_distinct(out, VillageRouteGeometry.point3(_departure(a),
		a.floor_y))
	for centre: Vector2 in cells:
		_append_distinct(out, VillageRouteGeometry.point3(centre, a.floor_y))
	_append_distinct(out, VillageRouteGeometry.point3(_departure(b),
		b.floor_y))
	_append_distinct(out, VillageRouteGeometry.point3(b.entrance, b.floor_y))
	return out


static func _append_distinct(points: Array[Vector3], point: Vector3) -> void:
	if points.is_empty() or points[-1].distance_squared_to(point) > 0.000001:
		points.append(point)


static func _departure(placement: VillageMassingPlacement) -> Vector2:
	if not placement.ground_accessible:
		return placement.street_contact
	return placement.entrance + placement.entrance_outward \
		* VillageDoorGeometry.clear_departure(placement,
			PLATFORM_HALF_WIDTH)


static func _frontage_cell(placement: VillageMassingPlacement,
		origin: Vector2, primary_axis: Vector2) -> Vector2i:
	var departure := _departure(placement)
	var cell := _grid_cell(departure, origin, primary_axis)
	var side := Vector2(-primary_axis.y, primary_axis.x)
	var grid_step := Vector2i.ZERO
	if absf(placement.entrance_outward.dot(primary_axis)) \
			>= absf(placement.entrance_outward.dot(side)):
		grid_step.x = 1 if placement.entrance_outward.dot(primary_axis) > 0.0 \
			else -1
	else:
		grid_step.y = 1 if placement.entrance_outward.dot(side) > 0.0 else -1
	# Never let nearest-cell rounding pull the first complete platform tile back
	# toward the facade. The exact departure remains part of the route, while
	# this cell begins the regular module union wholly beyond it.
	while (_grid_world(cell, origin, primary_axis) - placement.entrance).dot(
			placement.entrance_outward) \
			< (departure - placement.entrance).dot(
				placement.entrance_outward) - 0.001:
		cell += grid_step
	return cell


static func _grid_cell(point: Vector2, origin: Vector2,
		axis: Vector2) -> Vector2i:
	var offset := point - origin
	var side := Vector2(-axis.y, axis.x)
	return Vector2i(roundi(offset.dot(axis) / VillageProgram.MODULE),
		roundi(offset.dot(side) / VillageProgram.MODULE))


static func _grid_world(cell: Vector2i, origin: Vector2,
		axis: Vector2) -> Vector2:
	return origin + axis * float(cell.x) * VillageProgram.MODULE \
		+ Vector2(-axis.y, axis.x) * float(cell.y) * VillageProgram.MODULE


static func _cell_signature(cells: Array) -> String:
	var parts: PackedStringArray = []
	for centre: Vector2 in cells:
		parts.append(_point_key(centre))
	return ",".join(parts)


static func _point_key(point: Vector2) -> String:
	return "%d:%d" % [roundi(point.x * 1000.0),
		roundi(point.y * 1000.0)]


static func _grid_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]


static func _find(parent: Dictionary, key: StringName) -> StringName:
	var root := key
	while parent[root] != root:
		root = parent[root]
	var cursor := key
	while parent[cursor] != cursor:
		var next: StringName = parent[cursor]
		parent[cursor] = root
		cursor = next
	return root


static func _union(parent: Dictionary, a: StringName, b: StringName) -> void:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a == root_b:
		return
	if String(root_a) < String(root_b):
		parent[root_b] = root_a
	else:
		parent[root_a] = root_b

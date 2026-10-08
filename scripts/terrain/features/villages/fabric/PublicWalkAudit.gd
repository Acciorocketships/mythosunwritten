class_name PublicWalkAudit
extends RefCounted

## Pure census of the finished public walk graph: which walk surfaces lead
## somewhere. A public episode is USEFUL when it is a destination (the town
## gate, an exterior portal, a served doorway landing, the market, a terminal
## lookout, or a plaza/court of at least `OVERLOOK_MIN_CELLS` fine cells) or
## when it lies on a path between useful episodes (a loop counts). Leaves
## without a destination are peeled repeatedly; whatever is peeled is a
## pathway to nowhere.
const OVERLOOK_MIN_CELLS := 16


static func audit(fabric: SettlementFabricPlan,
		spatial: WarrenSpatialPlan = null) -> Dictionary:
	var realm := fabric.public_realm if fabric != null else null
	if realm == null:
		return {"summary": {"nodes": 0, "dead_end_nodes": 0,
			"dead_end_cells": 0}, "dead_ends": []}
	var destinations := destination_cells(fabric, spatial)
	var neighbours: Dictionary = {}
	for node: PublicRealmNode in realm.nodes:
		neighbours[node.stable_id] = {}
	for edge: PublicRealmEdge in realm.edges:
		(neighbours[edge.from_node_id] as Dictionary)[edge.to_node_id] = true
		(neighbours[edge.to_node_id] as Dictionary)[edge.from_node_id] = true
	var useful: Dictionary = {}
	var nodes: Dictionary = {}
	for node: PublicRealmNode in realm.nodes:
		nodes[node.stable_id] = node
		if node.is_landing or node.surface_cells.size() >= OVERLOOK_MIN_CELLS:
			useful[node.stable_id] = true
			continue
		for cell: Vector3i in node.surface_cells:
			if destinations.has(cell):
				useful[node.stable_id] = true
				break
	var removed: Dictionary = {}
	var queue: Array[StringName] = []
	for id: StringName in neighbours:
		if not useful.has(id) and (neighbours[id] as Dictionary).size() <= 1:
			queue.append(id)
	while not queue.is_empty():
		var id: StringName = queue.pop_back()
		if removed.has(id):
			continue
		removed[id] = true
		for other: StringName in neighbours[id]:
			if removed.has(other) or useful.has(other):
				continue
			var live := 0
			for next: StringName in neighbours[other]:
				if not removed.has(next):
					live += 1
			if live <= 1:
				queue.append(other)
	var dead_ends: Array[Dictionary] = []
	var cells := 0
	var ids: Array = removed.keys()
	ids.sort()
	for id: StringName in ids:
		var node := nodes[id] as PublicRealmNode
		cells += node.surface_cells.size()
		dead_ends.append({"id": id, "kind": node.episode_kind,
			"cells": node.surface_cells.size(),
			"first": node.surface_cells[0] if not node.surface_cells.is_empty() \
				else Vector3i.ZERO})
	return {"summary": {"nodes": realm.nodes.size(),
		"dead_end_nodes": removed.size(), "dead_end_cells": cells},
		"dead_ends": dead_ends}


static func destination_cells(fabric: SettlementFabricPlan,
		spatial: WarrenSpatialPlan = null) -> Dictionary:
	## Fine public cells that are themselves a reason to walk somewhere.
	var out: Dictionary = {}
	if fabric.surface_plan != null:
		for entrance: Dictionary in fabric.surface_plan.entrance_records:
			if bool(entrance.get("served", false)):
				out[entrance.get("landing_cell", Vector3i()) as Vector3i] = true
	if spatial == null:
		return out
	# The covered market's own public floor (its aisle under the canopy).
	for feature: WarrenFeatureReservation in spatial.features:
		for cell: Vector3i in feature.public_cells:
			out[cell] = true
	var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context.get(
		&"maze_source_plan") if spatial.source_volume != null else null
	if source != null:
		var macros: Array[Vector3i] = []
		macros.append_array(source.market_square_cells)
		for stamp: Dictionary in source.feature_stamps:
			for cell: Vector3i in stamp.get("cells", []):
				macros.append(cell)
		if source.excavation != null:
			macros.append_array(source.excavation.portals)
		# A courtyard clearing is a place to go (it is furnished and fronted),
		# however small: a 4-cell green's ring is under OVERLOOK_MIN_CELLS but its
		# one access lane is not a pathway to nowhere.
		for plot: Dictionary in source.plots:
			if WarrenPlotReservations.is_clearing_plot(plot):
				for column: Vector2i in plot.cells:
					macros.append(Vector3i(column.x, int(plot.floor), column.y))
		for macro: Vector3i in macros:
			for dx in 2:
				for dz in 2:
					out[Vector3i(macro.x * 2 + dx, macro.y, macro.z * 2 + dz)] = true
	return out

extends RefCounted


static func finish_house_massing(plan: WarrenMazeSourcePlan) -> void:
	## A narrow skyline belongs to a connected building group. Keep complete
	## upper party walls and occupied spans; let detached one-column plots be
	## cottages. Public ceilings and upper loads remain authoritative.
	if plan == null or plan.is_sealed():
		return
	var changes: Array[Dictionary] = []
	var ordered := plan.plots.duplicate()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return String(a.id) < String(b.id))
	for plot: Dictionary in ordered:
		if plot.kind != WarrenMazeSourcePlan.PLOT_HOUSE \
				or (plot.cells as Array).size() != 1:
			continue
		var column: Vector2i = plot.cells[0]
		var minimum := int(plot.floor) + WarrenMazeSourcePlan.MIN_HOUSE_BANDS
		var original_top := int(plot.top)
		if original_top <= minimum or _narrow_house_bears_upper_use(plan,
				plot, column, minimum):
			continue
		while int(plot.top) > minimum:
			var room_top := int(plot.top) - WarrenBuildingParcel.ROOF_RESERVATION_BANDS
			if _narrow_house_has_upper_neighbor(plan,plot,column,room_top):
				break
			plot.top = int(plot.top) - WarrenBuildingParcel.STOREY_BANDS
		if int(plot.top) != original_top:
			changes.append({"id":plot.id,"before":original_top,"after":plot.top})
	plan.audit["narrow_house_massing"] = changes


static func _narrow_house_has_upper_neighbor(plan: WarrenMazeSourcePlan,
		plot: Dictionary, column: Vector2i, room_top: int) -> bool:
	for other: Dictionary in plan.plots:
		if other.id == plot.id or other.kind not in [
				WarrenMazeSourcePlan.PLOT_HOUSE,WarrenMazeSourcePlan.PLOT_BRIDGE]:
			continue
		var other_room_top := int(other.top)
		if other.kind == WarrenMazeSourcePlan.PLOT_HOUSE:
			other_room_top -= WarrenBuildingParcel.ROOF_RESERVATION_BANDS
		if int(other.floor) > room_top - WarrenBuildingParcel.STOREY_BANDS \
				or other_room_top < room_top:
			continue
		for adjacent: Vector2i in other.cells:
			if absi(adjacent.x-column.x)+absi(adjacent.y-column.y) == 1:
				return true
	return false


static func _narrow_house_bears_upper_use(plan: WarrenMazeSourcePlan,
		plot: Dictionary, column: Vector2i, minimum: int) -> bool:
	for walk: Vector3i in plan.excavation.public_cells():
		if Vector2i(walk.x,walk.z) == column and walk.y >= minimum \
				and walk.y <= int(plot.top):
			return true
	for other: Dictionary in plan.plots:
		if other.id != plot.id and (other.cells as Array).has(column) \
				and int(other.floor) >= minimum:
			return true
	# Source bridge endpoint houses carry the separately reserved upper room.
	for proof: Dictionary in plan.excavation.bridge_span_audit.get("seeded",[]):
		for group: Array in proof.get("endpoint_foundation_groups",[]):
			if group.has(column) and int(proof.floor) >= minimum:
				return true
	return false


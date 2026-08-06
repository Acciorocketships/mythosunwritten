class_name VillageSkirtDeckSolver
extends RefCounted

## Derives a compact skirt from the exact unsupported part of a retained
## building. A one-cell apron is added only along exposed unsupported edges;
## no terrain/core-supported cell and no uninhabited platform can enter it.
const EPS := 0.001
const CARDINALS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]


static func solve(terrain: VillageTerrainView, stable_id: StringName,
		placement: VillageMassingPlacement, spec: VillageAssetSpec,
		support: VillageBuildingSupportPlan) -> VillageSkirtDeckPlan:
	assert(terrain != null and not stable_id.is_empty())
	assert(placement != null and spec != null and support != null)
	var plan := VillageSkirtDeckPlan.new()
	plan.stable_id = stable_id
	if not support.accepted or support.stable_id != stable_id:
		return _rejected(plan, &"support")
	if placement.perch.is_naturally_supported():
		plan.accepted = true
		plan.reason = &"accepted"
		assert(plan.validate(true))
		return plan
	if support.mode != VillageBuildingSupportPlan.Mode.ROCK_CORE \
			or support.core.is_empty():
		return _rejected(plan, &"rock_core")
	var contact := spec.world_ground_contact(
		placement.building_transform(spec))
	var grid := VillageModuleGrid.cells(contact, VillageProgram.MODULE)
	if grid.is_empty():
		return _rejected(plan, &"module_grid")
	var by_coordinate: Dictionary = {}
	var unsupported: Dictionary = {}
	for cell: VillageModuleCell in grid:
		by_coordinate[cell.coordinate] = cell
		if _inside_core(cell, support.core):
			continue
		var bounds := _ground_bounds(terrain, cell)
		if placement.floor_y - bounds.x \
				> TraversalEnvelope.MAX_PLANNED_STEP + EPS:
			unsupported[cell.coordinate] = cell
	var selected: Dictionary = {}
	for coordinate: Vector2i in unsupported:
		selected[_cell_key((unsupported[coordinate] as VillageModuleCell).centre)] = {
			"cell": unsupported[coordinate], "under_building": true}
	# The apron grows only outward from an unsupported building edge. It cannot
	# become an empty free-standing platform because every cell has an inhabited
	# contact cell as its direct parent.
	var axis_x := Vector2.RIGHT.rotated(float(contact.angle))
	var axis_z := Vector2.DOWN.rotated(float(contact.angle))
	for coordinate: Vector2i in unsupported:
		var parent := unsupported[coordinate] as VillageModuleCell
		for direction: Vector2i in CARDINALS:
			if by_coordinate.has(coordinate + direction):
				continue
			var centre := parent.centre + axis_x * float(direction.x) \
				* VillageProgram.MODULE + axis_z * float(direction.y) \
				* VillageProgram.MODULE
			var apron := VillageModuleCell.new(coordinate + direction,
				centre, Vector2.ONE * VillageProgram.MODULE * 0.5,
				float(contact.angle))
			var bounds := _ground_bounds(terrain, apron)
			# An exterior tile is a skirt only when its complete footprint is
			# below the traversable threshold. Marginal cells remain natural
			# ground, preventing timber from carpeting a supported facade.
			if placement.floor_y - bounds.y \
					<= TraversalEnvelope.MAX_PLANNED_STEP + EPS:
				continue
			selected[_cell_key(centre)] = {
				"cell": apron, "under_building": false}
	var keys: Array = selected.keys()
	keys.sort()
	for index in keys.size():
		var item: Dictionary = selected[keys[index]]
		var cell := item.cell as VillageModuleCell
		for point: Vector2 in [cell.centre] + cell.corners():
			if terrain.is_wet(point):
				return _rejected(plan, &"water")
		plan.cells.append(VillageTimberCell.new(
			StringName("%s.skirt.%03d" % [stable_id, index]), stable_id,
			VillageTimberCell.Kind.SKIRT, cell.centre, placement.floor_y,
			cell.yaw, bool(item.under_building)))
	plan.accepted = true
	plan.reason = &"accepted"
	assert(plan.validate(false))
	return plan


static func _inside_core(cell: VillageModuleCell, core: Dictionary) -> bool:
	var core_shape := FeatureGroundShape.oriented_rect(core.centre,
		core.half_extents, float(core.angle))
	for point: Vector2 in cell.corners():
		if core_shape.signed_distance(point) > EPS:
			return false
	return true


static func _ground_bounds(terrain: VillageTerrainView,
		cell: VillageModuleCell) -> Vector2:
	var shape := cell.shape()
	return TerrainSurfaceField.height_bounds(
		terrain.region_covering(shape.bounds()), shape.bounds())


static func _cell_key(point: Vector2) -> String:
	return "%d:%d" % [roundi(point.x * 1000.0),
		roundi(point.y * 1000.0)]


static func _rejected(plan: VillageSkirtDeckPlan,
		reason: StringName) -> VillageSkirtDeckPlan:
	plan.reason = reason
	plan.cells.clear()
	assert(plan.validate(false))
	return plan

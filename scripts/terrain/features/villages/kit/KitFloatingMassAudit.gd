class_name KitFloatingMassAudit
extends RefCounted

## Counts the town masses the owner reads as "floating boxes" (September 29
## town review, photos 1, 2, 6 and 10) and incomplete skywalks (photo 2's "L").
## Pure: reads a sealed spatial plan, its fabric and the kit masses built from
## them (`KitVillageBuildings.build(...).masses`).
##
## - `unborne_crown_cells`: structural stone resting on public air (a tunnel
##   ceiling, a rock shoulder left over a street) whose column carries no
##   construction on top. Stone has no lintel vocabulary; such a crown is a
##   slab hanging over the lane (`WarrenVolumetricSolver.unborne_crown_cells`).
## - `floating_storey_cells`: roofless kit storeys (retained terrain, tunnel
##   ceilings) hanging over public air whose top carries no kit house storey
##   and no walked floor -- the stone-walled, plank-bottomed box with no roof.
## - `incomplete_skywalks`: a skywalk mass that is neither a complete enclosed
##   corridor (a storey under a roof) nor an open railed timber deck.

const ROOFLESS_PREFIXES: Array[String] = ["kit.retained", "kit.tunnel"]


static func audit(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan,
		masses: Array) -> Dictionary:
	var grid := spatial.grid
	var building_cells := WarrenVolumetricSolver.building_private_cells(
		spatial.buildings)
	var stone: Dictionary = fabric.retained_terrace_cells.duplicate()
	for cell: Vector3i in grid.cells_with_use(
			WarrenSpatialGrid.Use.STRUCTURAL_VOLUME):
		if grid.owner_name_at(cell) == WarrenVolumetricSolver.MAZE_STONE_FEATURE_ID:
			stone[cell] = true
	var unborne := WarrenVolumetricSolver.unborne_crown_cells(grid, stone,
		building_cells)
	var house_cells: Dictionary = {}
	var roofless_cells: Dictionary = {}
	for mass: BuildingMass in masses:
		if String(mass.stable_id).contains("skywalk"):
			continue
		var into := roofless_cells if _roofless(mass) else house_cells
		for storey: Dictionary in mass.storeys:
			var floor := int(storey.floor_band)
			for band in range(floor, floor + int(storey.get("bands", 2))):
				for cell: Vector2i in storey.cells:
					into[Vector3i(cell.x, band, cell.y)] = true
	var floating: Array[Vector3i] = []
	var incomplete: Array[StringName] = []
	for mass: BuildingMass in masses:
		if String(mass.stable_id).contains("skywalk"):
			var enclosed := not mass.storeys.is_empty() \
				and _roofed(mass.storeys[0], masses)
			var open_deck := mass.storeys.is_empty() and mass.roofs.is_empty() \
				and mass.decks.size() == 1 and bool(mass.decks[0].get("rails", false))
			if not enclosed and not open_deck:
				incomplete.append(mass.stable_id)
			continue
		if not _roofless(mass):
			continue
		for storey: Dictionary in mass.storeys:
			var floor := int(storey.floor_band)
			var top := floor + int(storey.get("bands", 2))
			for cell: Vector2i in storey.cells:
				var below := Vector3i(cell.x, floor - 1, cell.y)
				if not grid.contains(below) or grid.use_at(below) \
						!= WarrenSpatialGrid.Use.PUBLIC_AIR:
					continue
				# Climb through the roofless courses stacked on this one.
				var above := Vector3i(cell.x, top, cell.y)
				while roofless_cells.has(above):
					above += Vector3i.UP
				if house_cells.has(above) or KitVillageBuildings._walked(grid, above):
					continue
				floating.append(Vector3i(cell.x, floor, cell.y))
	var unborne_list: Array[Vector3i] = []
	unborne_list.assign(unborne.keys())
	unborne_list.sort_custom(WarrenVolumetricSolver._cell_less)
	floating.sort_custom(WarrenVolumetricSolver._cell_less)
	return {"unborne_crown_cells": unborne_list, "floating_storey_cells": floating,
		"incomplete_skywalks": incomplete,
		"count": unborne_list.size() + floating.size() + incomplete.size()}


## Every cell of `storey` lies under a roof wing eaved at its top: its own, or
## the host roof `KitRoofJunctions` continued over it.
static func _roofed(storey: Dictionary, masses: Array) -> bool:
	var eave := int(storey.floor_band) + int(storey.get("bands", 2))
	for cell: Vector2i in storey.cells:
		var covered := false
		for mass: BuildingMass in masses:
			for roof: Dictionary in mass.roofs:
				covered = covered or int(roof.eave_band) == eave \
					and (roof.rect as Rect2i).has_point(cell)
		if not covered:
			return false
	return true


static func _roofless(mass: BuildingMass) -> bool:
	for prefix: String in ROOFLESS_PREFIXES:
		if String(mass.stable_id).begins_with(prefix):
			return true
	return false

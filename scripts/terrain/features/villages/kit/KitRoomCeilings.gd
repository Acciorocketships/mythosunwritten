extends RefCounted


## A structural reservation is not necessarily a rendered horizontal surface.
## Close inhabited crowns below retaining skins with native deck boards, while
## allowing actual room floors and existing decks to own shared interfaces.
static func close(masses: Array[BuildingMass]) -> int:
	var floors: Dictionary = {}
	for mass: BuildingMass in masses:
		for storey: Dictionary in mass.storeys:
			if storey.get("retaining", false) or storey.get("fortified", false):
				continue
			for cell: Vector2i in storey.cells:
				floors[Vector3i(cell.x, int(storey.floor_band), cell.y)] = true
		for deck: Dictionary in mass.decks:
			for cell: Vector2i in deck.cells:
				floors[Vector3i(cell.x, int(deck.band), cell.y)] = true
	var count := 0
	for mass: BuildingMass in masses:
		for storey: Dictionary in mass.storeys:
			if storey.get("retaining", false) or storey.get("fortified", false):
				continue
			var band := int(storey.floor_band) + int(storey.get("bands", 2))
			var cells: Dictionary = {}
			for cell: Vector2i in storey.get("covered_crown", {}):
				var key := Vector3i(cell.x, band, cell.y)
				if floors.has(key):
					continue
				cells[cell] = true
				floors[key] = true
				count += 1
			if not cells.is_empty():
				mass.decks.append(
					{"cells": cells, "band": band, "rails": false, "room_ceiling": true}
				)
	return count

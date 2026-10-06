extends RefCounted
## Accepted skywalks open the guard on both landing decks. The span already
## owns its side rails; leaving a balcony's end rail here fences off the route.


static func open_landings(masses: Array[BuildingMass], spans: Array[Dictionary]) -> void:
	var openings := {}
	for span: Dictionary in spans:
		var step: Vector3i = span.step
		var direction := BuildingMass.DIRS.find(Vector2i(step.x, step.z))
		if direction < 0:
			continue
		for near: Vector3i in SettlementFabricAssembler._skywalk_candidate_lanes(span):
			var far := near + step * (int(span.gap) + 1)
			for endpoint: Array in [[near, direction], [far, (direction + 2) % 4]]:
				var cell: Vector3i = endpoint[0]
				if not openings.has(cell.y):
					openings[cell.y] = {}
				openings[cell.y][BuildingMass.edge_key(Vector2i(cell.x, cell.z), endpoint[1])] = true
	for mass: BuildingMass in masses:
		for deck: Dictionary in mass.decks:
			if not openings.has(int(deck.band)):
				continue
			var edges: Dictionary = deck.get("open_edges", {})
			for edge: Vector3i in openings[int(deck.band)]:
				var cell := Vector2i(edge.x, edge.y)
				if deck.cells.has(cell) and not deck.cells.has(cell + BuildingMass.DIRS[edge.z]):
					edges[edge] = true
			deck["open_edges"] = edges

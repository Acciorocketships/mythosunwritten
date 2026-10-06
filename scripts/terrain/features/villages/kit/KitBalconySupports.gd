extends RefCounted
## A balcony on a shifted upper room may stand above another balcony rather
## than a wall. Carry its bracket from that lower deck with a complete timber
## triangle; a room reservation alone is not a physical bearing.
static func seat(masses: Array[BuildingMass], houses: Dictionary,
		grid: WarrenSpatialGrid) -> int:
	var rooms := {}
	for house: Dictionary in houses.values():
		for band: int in house.storeys:
			for cell: Vector2i in house.storeys[band]:
				for dy in 2: rooms[Vector3i(cell.x,band+dy,cell.y)] = true
	var count := 0
	for mass: BuildingMass in masses:
		if not String(mass.stable_id).contains(".balcony."): continue
		var posts: Array[Dictionary] = []
		for part: Dictionary in mass.decor:
			if part.kind != &"raker" or not part.has("from"): continue
			var foot: Vector3 = part.from
			var head: Vector3 = part.to
			if head.y-foot.y < .1 or _touches_room(rooms,foot): continue
			var bearing := -INF
			for lower: BuildingMass in masses:
				if lower == mass or not String(lower.stable_id).contains(".balcony."): continue
				for deck: Dictionary in lower.decks:
					var band := float(deck.band)
					if band >= foot.y or head.y-band > 2.01: continue
					if _touches_cells(deck.cells,Vector2(foot.x,foot.z)): bearing = maxf(bearing,band)
			if not is_finite(bearing): continue
			var clear := true
			for band in range(floori(bearing),ceili(head.y)):
				if grid.use_at(Vector3i(floori(foot.x),band,floori(foot.z))) == WarrenSpatialGrid.Use.PUBLIC_AIR:
					clear = false
			if not clear: continue
			foot.y = bearing
			part.from = foot
			part["deck_bearing"] = true
			posts.append({"kind": &"raker", "dir":0, "centre":Vector2(foot.x,foot.z),
				"from":foot,"to":Vector3(foot.x,head.y,foot.z),"deck_bearing":true})
			count += 1
		mass.decor.append_array(posts)
	return count

static func _touches_room(rooms: Dictionary, point: Vector3) -> bool:
	for dx in [-.001,.001]:
		for dz in [-.001,.001]:
			if rooms.has(Vector3i(floori(point.x+dx),floori(point.y),floori(point.z+dz))): return true
	return false

static func _touches_cells(cells: Dictionary, point: Vector2) -> bool:
	for dx in [-.001,.001]:
		for dz in [-.001,.001]:
			if cells.has(Vector2i(floori(point.x+dx),floori(point.y+dz))): return true
	return false

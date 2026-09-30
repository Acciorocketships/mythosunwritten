extends RefCounted
## Roofline variety of a kit-built town (September 29 town review, photo 11:
## "a bunch of the same roof at the same level, facing in the same direction").
## Input: the dictionary returned by `KitVillageBuildings.build`. Measured on
## the house masses (planner lineages; features and retained terraces are not
## houses), in module cells and planner bands.
##   houses          house masses carrying at least one pitched roof wing
##   gable_front     houses whose principal ridge runs toward the street they
##                   open onto (gable to the street); the rest are eave-fronted
##   axis_minority   share of principal ridges on the less common axis
##   pairs           touching house pairs (a shared wall edge at one band)
##   twins           ... whose principal wings are side-by-side copies: same
##                   ridge axis, eave band and depth, offset across the ridge
##                   (the sawtooth row of identical gables)
##   twin_run        largest group of houses chained by twin pairs
##   same_ridge      touching pairs whose ridges stand within half a storey
##   ridge_levels    distinct principal ridge heights (half-storey steps)
##   compound        houses whose roof has two or more wings (L/T/cross gable)
static func measure(built: Dictionary, kit: BuildingKit) -> Dictionary:
	var houses: Array = built.get("houses", [])
	var out := {"houses": 0, "gable_front": 0, "fronted": 0, "axis_minority": 0.0,
		"pairs": 0, "twins": 0, "twin_run": 0, "same_ridge": 0, "ridge_levels": 0,
		"compound": 0, "examples": []}
	var principal: Array[Dictionary] = []
	var roofed: Array[BuildingMass] = []
	for mass: BuildingMass in houses:
		var best: Dictionary = {}
		var area := 0
		for roof: Dictionary in mass.roofs:
			var r: Rect2i = roof.rect
			if r.get_area() > area:
				area = r.get_area()
				best = roof
		if best.is_empty():
			continue
		roofed.append(mass)
		principal.append(best)
		if mass.roofs.size() >= 2:
			out.compound += 1
		var front := _front_dir(mass)
		if front >= 0:
			out.fronted += 1
			if int(best.axis) == front % 2:
				out.gable_front += 1
	out.houses = roofed.size()
	var along_x := 0
	var levels: Dictionary = {}
	for roof: Dictionary in principal:
		if int(roof.axis) == 0: along_x += 1
		levels[roundi(ridge_height(roof, kit) / (kit.storey_height * 0.5))] = true
	out.ridge_levels = levels.size()
	if not principal.is_empty():
		out.axis_minority = float(mini(along_x, principal.size() - along_x)) / principal.size()
	# Touching pairs.
	var owner: Dictionary = {}
	for i in roofed.size():
		for storey: Dictionary in roofed[i].storeys:
			for band in range(int(storey.floor_band), int(storey.floor_band) + int(storey.get("bands", 2))):
				for cell: Vector2i in storey.cells:
					owner[Vector3i(cell.x, band, cell.y)] = i
	var pairs: Dictionary = {}
	for key: Vector3i in owner:
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other := Vector3i(key.x + step.x, key.y, key.z + step.y)
			if owner.has(other) and owner[other] != owner[key]:
				var a := mini(owner[key], owner[other])
				var b := maxi(owner[key], owner[other])
				pairs[Vector2i(a, b)] = true
	out.pairs = pairs.size()
	var twin_links: Dictionary = {}
	for pair: Vector2i in pairs:
		var a: Dictionary = principal[pair.x]
		var b: Dictionary = principal[pair.y]
		if absf(ridge_height(a, kit) - ridge_height(b, kit)) < kit.storey_height * 0.5 - 0.01:
			out.same_ridge += 1
		if _twins(a, b):
			out.twins += 1
			(out.examples as Array).append("twins %s %s" % [roofed[pair.x].stable_id, roofed[pair.y].stable_id])
			for k in [pair.x, pair.y]:
				if not twin_links.has(k): twin_links[k] = []
			(twin_links[pair.x] as Array).append(pair.y)
			(twin_links[pair.y] as Array).append(pair.x)
	var seen: Dictionary = {}
	for start: int in twin_links:
		if seen.has(start): continue
		var size := 0
		var pending: Array = [start]
		while not pending.is_empty():
			var k: int = pending.pop_back()
			if seen.has(k): continue
			seen[k] = true
			size += 1
			pending.append_array(twin_links[k])
		out.twin_run = maxi(int(out.twin_run), size)
	return out


static func ridge_height(roof: Dictionary, kit: BuildingKit) -> float:
	var r: Rect2i = roof.rect
	var depth := r.size[1 - int(roof.axis)]
	return float(int(roof.eave_band)) * kit.band_height() + float(kit.roof_profile(depth).height)


## Side-by-side copies: same axis, eave and depth, touching or overlapping
## along the ridge but offset across it.
static func _twins(a: Dictionary, b: Dictionary) -> bool:
	if int(a.axis) != int(b.axis) or int(a.eave_band) != int(b.eave_band):
		return false
	var axis := int(a.axis)
	var side := 1 - axis
	var ar: Rect2i = a.rect
	var br: Rect2i = b.rect
	if ar.size[side] != br.size[side]:
		return false
	var overlap := mini(ar.end[axis], br.end[axis]) - maxi(ar.position[axis], br.position[axis])
	return overlap > 0 and ar.position[side] != br.position[side]


## Direction (BuildingMass.DIRS index) of the house's street door: its
## lowest non-balcony door, else -1.
static func _front_dir(mass: BuildingMass) -> int:
	var best := -1
	var band := 1 << 20
	for storey: Dictionary in mass.storeys:
		for key: Vector3i in storey.openings:
			if StringName(storey.openings[key]) != BuildingMass.OPENING_DOOR: continue
			if int(storey.floor_band) < band:
				band = int(storey.floor_band)
				best = key.z
	return best

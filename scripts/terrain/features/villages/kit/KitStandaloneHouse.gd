class_name KitStandaloneHouse
extends RefCounted

## A freestanding kit house in a measured lot (hamlets and outskirts).
##
## The lot planner keeps its measured prefab contract (support footprint,
## entrance, clearance); the house drawn there is designed by
## `BuildingDesigner` on the kit's module grid inside that support footprint,
## with its door on the planned entrance side. Returns world-frame entries
## `{asset_id, stable_id, transform}` like the prefab path it replaces.


static func entries(kit: BuildingKit, spec: VillageAssetSpec,
		built: Transform3D, floor_y: float, owner: StringName,
		seed: int) -> Array[Dictionary]:
	# The house may fill the lot's measured solid extent (the prefab's eaves
	# included); kit eaves overhang a further half module.
	var contact := spec.world_solid(built)
	var world_module := kit.module_width * VillageWorldScale.KIT_WORLD_SCALE
	var half := contact.half_extents as Vector2
	var nx := maxi(2, int(floor(half.x * 2.0 / world_module + 0.25)))
	var nz := maxi(2, int(floor(half.y * 2.0 / world_module + 0.25)))
	var yaw := -float(contact.angle)
	var basis := Basis(Vector3.UP, yaw)
	var outward2 := spec.world_entrance_outward(built)
	var local_out := basis.inverse() * Vector3(outward2.x, 0.0, outward2.y)
	var dir := _nearest_dir(Vector2(local_out.x, local_out.z))
	var mass := design(kit, nx, nz, dir, seed)
	mass.stable_id = owner
	var centre := contact.centre as Vector2
	var w := kit.module_width
	var native_to_world := Transform3D(basis.scaled(Vector3.ONE * VillageWorldScale.KIT_WORLD_SCALE),
		Vector3(centre.x, floor_y, centre.y)) \
		* Transform3D(Basis.IDENTITY, Vector3(-float(nx) * w * 0.5, 0.0,
			-float(nz) * w * 0.5))
	var out: Array[Dictionary] = []
	for placement: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
		out.append({"asset_id": placement.asset_id,
			"stable_id": placement.stable_id,
			"transform": native_to_world * (placement.transform as Transform3D),
			"color": placement.get("color", Color.WHITE),
			"collision_enabled": bool(placement.get("collision", true))})
	return out


## A house on an nx x nz module rectangle with its front door facing `dir`.
static func design(kit: BuildingKit, nx: int, nz: int, dir: int,
		seed: int) -> BuildingMass:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mass := BuildingMass.new()
	mass.seed = seed
	# Design inside the already reserved lot. A broad rear hall and a front
	# wing make an L or T; the next floor can move its wing, leaving a usable
	# terrace and a post-supported wing above the lower recess.
	var storey_count := 2 if rng.randf() < 0.85 or mini(nx, nz) < 3 else 3
	var shape := posmod(seed, 8)
	for s in storey_count:
		var cells := _floorplate(nx, nz, dir, shape, s)
		mass.add_storey(s * 2, cells, BuildingMass.MATERIAL_TIMBER)
	var door_cell: Vector2i
	match dir:
		0: door_cell = Vector2i(nx - 1, nz / 2)
		1: door_cell = Vector2i(nx / 2, nz - 1)
		2: door_cell = Vector2i(0, nz / 2)
		_: door_cell = Vector2i(nx / 2, 0)
	var ground: Dictionary = mass.storeys[0]
	ground.openings[BuildingMass.edge_key(door_cell, dir)] = BuildingMass.OPENING_DOOR
	BuildingDesigner.new(kit).articulate(mass, {"terrain_storey": 0, "terraced": true,
		"roof_axis": dir % 2 if mini(nx, nz) >= 3 else -1})
	_support_projections(mass)
	_dress_terraces(mass)
	return mass


static func _floorplate(nx: int, nz: int, dir: int, shape: int, floor: int) -> Dictionary:
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, nx, nz))
	var width := nz if dir % 2 == 0 else nx
	var depth := nx if dir % 2 == 0 else nz
	if width < 3 or depth < 3:
		return cells
	# Keep the middle frontage cell (the planned entrance) on every floor.
	# Two-module wings preserve room width and a complete gable profile.
	var wing_width := maxi(2, width / 2 + 1)
	var left := 0
	if shape == 1 or shape == 4:
		left = width - wing_width
	elif shape == 2 or shape >= 5:
		left = (width - wing_width) / 2
	if floor > 0 and (shape == 3 or shape == 4):
		left = width - wing_width if shape == 3 else 0
	if (shape == 0 or shape == 5) and floor == 0:
		return cells
	if shape == 6 and floor > 0:
		return cells
	var cut_depth := maxi(2, depth - 2)
	# Long verandas and deep projecting wings, including the small 4x3 lots.
	# Retain a connected rear hall; a third floor steps back independently.
	if shape == 1 or shape == 2 or shape == 5 or floor == 2:
		cut_depth = depth - 1
	if floor == 0 and (shape == 1 or shape == 2):
		cut_depth = maxi(1, cut_depth - 1)
	if shape == 7 and floor > 0:
		cut_depth = 1
	for cell: Vector2i in cells.keys():
		var u := cell.y if dir % 2 == 0 else cell.x
		var v := cell.x if dir % 2 == 0 else cell.y
		if dir < 2:
			v = depth - 1 - v
		if v < cut_depth and (u < left or u >= left + wing_width):
			cells.erase(cell)
	return cells


static func _support_projections(mass: BuildingMass) -> void:
	for i in range(1, mass.storeys.size()):
		var upper: Dictionary = mass.storeys[i]
		var lower: Dictionary = mass.storeys[i - 1].cells
		for cell: Vector2i in upper.cells:
			if lower.has(cell): continue
			for dir in 4:
				if not lower.has(cell + BuildingMass.DIRS[dir]): continue
				mass.decor.append({"kind": &"bracket", "dir": (dir + 2) % 4,
					"centre": Vector2(cell) + Vector2(0.5, 0.5)
						+ Vector2(BuildingMass.DIRS[dir]) * 0.5,
					"y_band": int(upper.floor_band)})

		# Each convex corner of an unsupported room has a continuous bearing
		# down to the nearest lower floor, or the reserved flat lot ground.
		var vertices := {}
		for cell: Vector2i in upper.cells:
			for corner: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
				var vertex := cell + corner
				vertices[vertex] = int(vertices.get(vertex, 0)) + 1
		for vertex: Vector2i in vertices:
			if int(vertices[vertex]) != 1: continue
			var neighbours := [vertex, vertex - Vector2i.RIGHT,
				vertex - Vector2i.DOWN, vertex - Vector2i.ONE]
			var supported := false
			for cell: Vector2i in neighbours:
				if lower.has(cell): supported = true
			if supported: continue
			var from_band := 0
			for j in range(i - 2, -1, -1):
				var bearing: Dictionary = mass.storeys[j]
				for cell: Vector2i in neighbours:
					if bearing.cells.has(cell):
						from_band = maxi(from_band, int(bearing.floor_band) + 2)
			mass.decor.append({"kind": &"post", "dir": 0,
				"centre": Vector2(vertex), "from_band": from_band,
				"to_band": int(upper.floor_band)})


static func _dress_terraces(mass: BuildingMass) -> void:
	# Pots sit at the outside rail, leaving the centre and house doors clear.
	for deck: Dictionary in mass.decks:
		var count := 0
		for cell: Vector2i in deck.cells:
			for dir in 4:
				var next := cell + BuildingMass.DIRS[dir]
				if deck.cells.has(next) or deck.open_edges.has(BuildingMass.edge_key(cell, dir)):
					continue
				if posmod(cell.x * 7 + cell.y * 11 + mass.seed, 3) != 0: continue
				mass.decor.append({"kind": &"planter", "dir": dir,
					"centre": Vector2(cell) + Vector2(0.5, 0.5) + Vector2(BuildingMass.DIRS[dir]) * 0.32,
					"y_band": int(deck.band)})
				count += 1
				break
			if count >= 2: break


static func _nearest_dir(v: Vector2) -> int:
	var best := 0
	var best_dot := -INF
	for i in 4:
		var d := Vector2(BuildingMass.DIRS[i]).dot(v)
		if d > best_dot:
			best_dot = d
			best = i
	return best

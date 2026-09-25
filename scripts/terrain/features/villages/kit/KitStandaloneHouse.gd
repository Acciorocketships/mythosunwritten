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
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, nx, nz))
	var storey_count := 2 if rng.randf() < 0.85 or mini(nx, nz) < 3 else 3
	for s in storey_count:
		mass.add_storey(s * 2, cells, BuildingMass.MATERIAL_TIMBER)
	var door_cell: Vector2i
	match dir:
		0: door_cell = Vector2i(nx - 1, nz / 2)
		1: door_cell = Vector2i(nx / 2, nz - 1)
		2: door_cell = Vector2i(0, nz / 2)
		_: door_cell = Vector2i(nx / 2, 0)
	var ground: Dictionary = mass.storeys[0]
	ground.openings[BuildingMass.edge_key(door_cell, dir)] = BuildingMass.OPENING_DOOR
	BuildingDesigner.new(kit).articulate(mass, {"terrain_storey": 0})
	return mass


static func _nearest_dir(v: Vector2) -> int:
	var best := 0
	var best_dot := -INF
	for i in 4:
		var d := Vector2(BuildingMass.DIRS[i]).dot(v)
		if d > best_dot:
			best_dot = d
			best = i
	return best

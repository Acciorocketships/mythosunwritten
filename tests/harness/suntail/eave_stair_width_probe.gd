extends SceneTree
## Read-only construction trial for the compact photo-town's roof/stair corner.
## Rebuilds public air from narrowed tread vertices; never mutates production.
## Guard and landing geometry are NOT validated here. This is not an admitted
## stair variant or a replacement for the production roof audit.
const U = preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
const FIT = preload("res://scripts/terrain/features/villages/kit/KitRoofEaveFits.gd")


func _init():
	call_deferred("run")


func run():
	var kit = SuntailBuildingKit.create()
	var source = WarrenMazeSitePlanner.plan(
		85830433957479026, {}, WarrenVillageScaleProfile.for_id(&"compact"), &"", false
	)
	var spatial = load("res://tests/fixtures/frozen_maze_source.gd").spatial(
		source, SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	)
	var built = KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
	var own = built.roof_kits[0]
	var clearance = load("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
	var map = KitVillageBuildings.native_to_lattice(kit).affine_inverse()
	var flight: Dictionary = {}
	for mesh in clearance.floor_meshes(spatial, spatial.compiled_fabric_cache()):
		if String(mesh.get("stable_id", "")) == "volume.transition.07.mesh":
			flight = mesh
	assert(not flight.is_empty())
	var headroom = TraversalEnvelope.MIN_HEADROOM / VillageWorldScale.VERTICAL_SCALE
	var old_air = clearance.from_mesh(flight, map, headroom)
	var results = []
	for inset in [0.0, 0.05, 0.1, 0.2, 0.3, 0.5]:
		var walls: Array[Dictionary] = []
		var altered = 0
		for original in built.walls:
			if not original.get("open", false):
				continue
			if original in old_air:
				altered += 1
				continue
			walls.append(original)
		var transition: WarrenVolumeTransition = spatial.source_volume.transitions[7]
		var lateral := Vector3(-transition.direction.y, 0, transition.direction.x)
		var edge := Vector2.ZERO
		# Convert native kit metres to the fabric's physical frame.
		if lateral.z > 0:
			edge.y = inset * 0.75
		else:
			edge.x = inset * 0.75
		var narrowed := WarrenTransitionSurfaceBuilder.build(
			&"width-trial", transition, transition.surface_cells(), [], false, edge
		)
		assert(not narrowed.is_empty())
		walls.append_array(clearance.from_mesh(narrowed, map, headroom))
		var roof = built.roofs[0].duplicate(true)
		roof.verge_min = 0.0
		roof.union_index = 0
		var rs: Array[Dictionary] = [roof]
		var ctx = U.prepare(rs, walls, own)
		ctx.volumes[0] = {"bounds": AABB(), "planes": []}
		ctx.clips[0] = []
		var mass = BuildingMass.new()
		mass.roofs.append(roof)
		var lost = []
		for p in BuildingKitAssembler.new(own).assemble(mass):
			if not ctx.data.has(p.asset_id):
				continue
			var surfaces = ctx.data[p.asset_id]
			var meshes = []
			for surf in surfaces:
				meshes.append(U.trim_surface(surf, p.transform, walls))
			if FIT.removes_surface({"surfaces": surfaces, "meshes": meshes}, p.transform):
				lost.append([p.role, p.transform.origin])
		assert(altered == old_air.size(), "Every original tread prism must be replaced")
		assert(altered > 0, "The target flight must have actual tread clearance")
		results.append(
			{
				"native_inset": inset,
				"world_inset": inset * (VillageWorldScale.HORIZONTAL_SCALE * 0.75),
				"blocked": lost.size()
			}
		)
		print("INSET ", inset, " altered ", altered, " blocked ", lost)
	assert(results[0].blocked == 2, "Reproduce the two public-air roof contacts")
	assert(results[3].blocked > 0, "A 0.2-native inset still intersects the roof")
	assert(results[4].blocked == 0, "A 0.3-native inset should preserve every roof part")
	print("ROOF_STAIR_WIDTH_TRIAL_PASS ", results)
	quit()

extends SceneTree
## Diagnostic for the compact photo-town eave/stair regression.
## Keeps the actual planner and native assets; trial alternatives are read-only.
const U = preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")


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
	for p in built.placements:
		if String(p.stable_id) != "kit.spatial.parcel.maze.house.000/k0062":
			continue
		print("PART ", p)
		print("ROOF ", built.roofs[p.roof_index])
		var own = built.roof_kits.get(p.roof_index, kit)
		print("KIT ", own.kit_id if "kit_id" in own else own)
		var ctx = U.prepare(built.roofs, built.walls, kit, built.roof_kits)
		for w in built.walls:
			if not w.get("open", false):
				continue
			var raw = ctx.data[p.asset_id]
			var changed = false
			for s in raw:
				var m = U.trim_surface(s, p.transform, [w] as Array[Dictionary])
				changed = changed or m.changed
			if changed:
				print("CUT ", w)
	var idx = 0
	var roof = built.roofs[idx]
	var own = built.roof_kits.get(idx, kit)
	var walls: Array[Dictionary] = []
	for w in built.walls:
		if w.get("open", false):
			walls.append(w)
	var ctx = U.prepare(built.roofs, walls, kit, built.roof_kits)
	for i in built.roofs.size():
		ctx.volumes[i] = {"bounds": AABB(), "planes": []}
		ctx.clips[i] = []
	for ends in [0, 1, 2, 3]:
		var trial = roof.duplicate(true)
		if ends & 1:
			trial.verge_min = 0.0
		if ends & 2:
			trial.verge_max = 0.0
		var mass = BuildingMass.new()
		mass.roofs.append(trial)
		for part in BuildingKitAssembler.new(own).assemble(mass):
			if not String(part.role).contains(".eave"):
				continue
			var result = U.realize(part, ctx)
			if result.is_empty():
				continue
			var raw = 0.0
			var kept = 0.0
			for surf in ctx.data[part.asset_id]:
				var v = part.transform * surf.vertices
				for k in range(0, surf.indices.size(), 3):
					raw += (
						(
							(v[surf.indices[k + 1]] - v[surf.indices[k]])
							. cross(v[surf.indices[k + 2]] - v[surf.indices[k]])
							. length()
						)
						* .5
					)
			for surf in result.meshes:
				var v = surf.vertices
				for k in range(0, surf.indices.size(), 3):
					kept += (
						(
							(v[surf.indices[k + 1]] - v[surf.indices[k]])
							. cross(v[surf.indices[k + 2]] - v[surf.indices[k]])
							. length()
						)
						* .5
					)
			print(
				"TRIAL ",
				ends,
				" ",
				part.role,
				" ",
				part.transform.origin,
				" lost ",
				raw - kept,
				" raw ",
				raw
			)
	var alternative = SuntailBuildingKit.create()
	var trial = roof.duplicate(true)
	trial.erase("tight_eave")
	trial.erase("tight_eave_sides")
	trial.union_index = 0
	var rs: Array[Dictionary] = [trial]
	print(
		"ALT_FIT ",
		load("res://scripts/terrain/features/villages/kit/KitRoofEaveFits.gd").fit(
			rs, alternative, {}, walls
		)
	)
	var actx = U.prepare(rs, walls, alternative)
	var amass = BuildingMass.new()
	amass.roofs.append(trial)
	for part in BuildingKitAssembler.new(alternative).assemble(amass):
		if not String(part.role).contains(".eave"):
			continue
		var actual = U.realize(part, actx)
		if actual.is_empty():
			continue
		var raw = 0.0
		var kept = 0.0
		for surf in actx.data[part.asset_id]:
			var v = part.transform * surf.vertices
			for k in range(0, surf.indices.size(), 3):
				raw += (
					(
						(v[surf.indices[k + 1]] - v[surf.indices[k]])
						. cross(v[surf.indices[k + 2]] - v[surf.indices[k]])
						. length()
					)
					* .5
				)
		for surf in actual.meshes:
			var v = surf.vertices
			for k in range(0, surf.indices.size(), 3):
				kept += (
					(
						(v[surf.indices[k + 1]] - v[surf.indices[k]])
						. cross(v[surf.indices[k + 2]] - v[surf.indices[k]])
						. length()
					)
					* .5
				)
		print("ALT_BLOCKED ", part.role, " ", part.transform.origin, " lost ", raw - kept)

	var clearance = load("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
	for mesh in clearance.floor_meshes(spatial, spatial.compiled_fabric_cache()):
		for air in clearance.from_mesh(
			mesh, KitVillageBuildings.native_to_lattice(kit).affine_inverse(), 1.2
		):
			if air.bounds.position.distance_to(Vector3(-4, 3.1875, 4)) < .01:
				print("AIR_SOURCE ", mesh.get("stable_id", "none"), " ", mesh.keys())
	print("AUDIT ", load("res://tests/fixtures/kit_roof_audit.gd").audit(built, kit))
	quit()

extends SceneTree
## Exact native owner of each nearest inhabited ceiling above a published walk.
func _init() -> void:call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := {}
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for city: String in args[args.find("--cities")+1].split(","):
		var key := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(key[0]),{},program,WarrenVillageScaleProfile.for_id(StringName(key[1])))
		assert(spatial!=null,WarrenVolumetricSolver.last_failure)
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial,fabric,SuntailBuildingKit.create())
		var rooms: Array = built.houses.duplicate()
		for mass: BuildingMass in built.masses:
			if String(mass.stable_id).begins_with("kit.skywalk.") and not mass.storeys.is_empty():rooms.append(mass)
		var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
		var walks := {}
		for walk: Vector3i in source.passage_kinds:
			var quarters := []
			for dx in 2:
				for dz in 2:
					var nearest := {"band":-1,"owner":&""}
					var column := Vector2i(walk.x*2+dx,walk.z*2+dz)
					for mass: BuildingMass in rooms:
						for floor: Dictionary in mass.storeys:
							var band := int(floor.floor_band)
							if band<=walk.y or not floor.cells.has(column):continue
							if nearest.band<0 or band<nearest.band:nearest={"band":band,"owner":mass.stable_id}
					quarters.append(nearest)
			walks[str(walk)]=quarters
		var network := SettlementFabricAssembler.maze_exterior_network(fabric,{},true)
		output[city]={"walks":walks,"spans":network.spans,"private_candidates":network.private_candidates}
	FileAccess.open(args[args.find("--output")+1],FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	quit()

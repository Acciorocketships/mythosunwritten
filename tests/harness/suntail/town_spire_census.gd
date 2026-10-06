extends SceneTree
## Count realized cap instances, including native grammar parts that are absent
## from KitVillageBuildings.towers. Keep whole prefab placements separately:
## they cannot be counted as individual spires from their opaque asset id.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := "8:grand,83:grand"
	if args.has("--cities"): cities = args[args.find("--cities") + 1]
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var records := {}
	for city: String in cities.split(","):
		var fields := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(fields[0]), {}, program,
			WarrenVillageScaleProfile.for_id(StringName(fields[1])))
		assert(spatial != null, WarrenVolumetricSolver.last_failure)
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
		var payload := KitVillageBuildings.legacy_payload_without(fabric, built.replaced_units)
		payload.append_from(built.payload)
		var caps := []
		for id: StringName in payload.asset_ids():
			var name := String(id)
			if not (name.begins_with("pure_village.tower.roof") \
				or name.begins_with("pure_village.roof_turret.roof") \
				or name.begins_with("pure_village.native.roof_tower_")): continue
			var batch: Dictionary = payload.batches[id]
			for index in batch.transforms.size():
				caps.append({"asset":id,"owner":batch.ids[index],
					"pose":var_to_str(batch.transforms[index]),
					"native":name.begins_with("pure_village.native.")})
		var opaque_prefabs := []
		for unit: FabricUnit in fabric.units:
			if String(unit.recipe_id).begins_with("anchor.prefab."):
				opaque_prefabs.append({"id":unit.stable_id,"recipe":unit.recipe_id})
		var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
		records[city] = {"caps":caps,"opaque_prefabs":opaque_prefabs,
			"attached_towers":built.towers.size(),"tower_audit":built.roof_audit.get("towers",{}),
			"asset_outcomes":WarrenPlotPlanner.outcomes(source).get("assets",[])}
		print("SPIRE_CENSUS ", city, " attached=",built.towers.size(), " realized_caps=",caps.size(),
			" opaque_prefabs=",opaque_prefabs.size())
	if args.has("--output"):
		FileAccess.open(args[args.find("--output")+1],FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	quit()

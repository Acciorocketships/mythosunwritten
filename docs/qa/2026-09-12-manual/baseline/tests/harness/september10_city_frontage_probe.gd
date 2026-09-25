extends SceneTree

func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := VillageProgram.compile({}, catalog)
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-24, 25):
		for x in range(-24, 25):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 0
	var terrain := VillageTerrainView.from_region(HeightfieldRegion.new(storeys, levels))
	var seeds: Array = [1, 2, 3, 4]
	if not OS.get_cmdline_user_args().is_empty():
		seeds.assign(OS.get_cmdline_user_args())
	for seed_value: Variant in seeds:
		var seed := int(seed_value)
		var id := StringName("form.%d" % seed)
		var spatial := WarrenVolumetricSolver.solve(seed, {}, program.settlement_fabric_program,
			WarrenVillageScaleProfile.for_id(&"standard"))
		if spatial == null:
			print("CITY_FRONTAGE_FAILED ", seed, " ", WarrenVolumetricSolver.last_failure)
			continue
		var fabric := spatial.compiled_fabric_cache()
		var placement := VillageWarrenFabricSolver._placement(terrain, spatial, Vector2.ZERO, Vector2.DOWN)
		placement["local_bounds"] = VillageWarrenFabricSolver._local_bounds(fabric)
		var urban := VillageWarrenFabricSolver._materialize(terrain, id, spatial, fabric, placement, program, seed)
		var outskirts := VillageOutskirtsConstruction.generate(terrain, id, Vector2.ZERO,
			Vector2.DOWN, &"village", &"blue", program, urban, null)
		var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
		print("CITY_FRONTAGE ", seed, " form=", source.massif.form_id,
			" houses=", outskirts.placements.size(), " shared=", outskirts.shared_street_house_count,
			" branches=", outskirts.branch_count, " valid=", outskirts.validate(program.outskirts_program, &"village"),
			" internal_conflict=", VillageOccupancy.new().first_conflict(outskirts.volumes), " audit=", outskirts.audit[0])
	quit()

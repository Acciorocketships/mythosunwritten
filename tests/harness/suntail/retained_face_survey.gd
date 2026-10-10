extends SceneTree
## Report the actual retained facades that remain after town composition.
## Run headless; coordinates are native kit coordinates, not world metres.
func _initialize() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	for seed_value in [41,67]:
		var spatial := WarrenVolumetricSolver.generate(seed_value,{},program,
			WarrenVillageScaleProfile.for_id(&"large"))
		var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
		var rows: Array[Dictionary] = []
		for mass: BuildingMass in built.masses:
			for storey: Dictionary in mass.storeys:
				if not bool(storey.get("retaining",false)): continue
				var slots := BuildingKitAssembler.wall_slots(storey.cells,false)
				rows.append({"mass":String(mass.stable_id),"floor":storey.floor_band,
					"bands":storey.get("bands",2),"material":String(storey.material),
					"default_opening":String(storey.default_opening),"outline_slots":slots.size(),
					"cells":storey.cells.size()})
		print("RETAINED_FACES ",JSON.stringify({"seed":seed_value,"layers":rows}))
	quit()

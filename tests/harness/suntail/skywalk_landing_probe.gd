extends SceneTree
## Report the actual compiler crown and replacement kit roof at the 43/grand landing.
func _init() -> void:call_deferred("_run")
func _run() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(43,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
	var fabric := spatial.compiled_fabric_cache()
	var crowns := SettlementFabricAssembler.maze_construction_crown_cells(fabric)
	var built := KitVillageBuildings.build(spatial,fabric,SuntailBuildingKit.create())
	for span:Dictionary in SettlementFabricAssembler.maze_skywalk_spans(fabric):
		print("SPAN ",span)
		for cell:Vector3i in [span.cell,span.cell+span.step*(span.gap+1)]:
			print("END ",cell," transition=",fabric.surface_plan.has_transition_geometry(cell)," crown=",crowns.get(cell))
			for unit:FabricUnit in fabric.units:
				if unit.stable_id==crowns.get(cell):print("UNIT ",unit.stable_id," recipe=",unit.recipe_id," origin=",unit.lattice_origin," replaced=",built.replaced_units.has(unit.stable_id))
			for mass:BuildingMass in built.masses:
				for roof:Dictionary in mass.roofs:
					if roof.rect.has_point(Vector2i(cell.x,cell.z)):print("ROOF ",mass.stable_id," ",roof)
			for patch:Dictionary in fabric.surface_plan.patches:
				if (patch.cells as Array).has(cell): print("PATCH ",patch)
	quit()

extends SceneTree
func _init() -> void:
	var cell := Vector2i(45,-240)
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2: cell=Vector2i(int(args[0]),int(args[1]))
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464,cell)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.solve(seed_value,{},program,WarrenVillageScaleProfile.select(seed_value))
	if spatial == null:
		print("JOIN source failed ",WarrenVolumetricSolver.last_failure)
		quit(1)
		return
	var plan := spatial.compiled_fabric_cache()
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	print("PORTAL source=",source.excavation.portals," contacts=",VillageWarrenFabricSolver.terrain_contact_specs(spatial,plan))
	for portal in source.excavation.portals:
		var nearby: Array[Vector3i] = []
		for kind in PublicRealmSurfacePlan.SurfaceKind.size():
			for surface_cell: Vector3i in plan.surface_plan.cells_for_kind(kind):
				if absi(surface_cell.x-portal.x*2)<4 and absi(surface_cell.z-portal.z*2)<4:
					nearby.append(surface_cell)
		print("PORTAL at=",portal," nearby=",nearby)
	quit()

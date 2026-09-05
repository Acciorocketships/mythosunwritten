extends SceneTree

func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(4242, Vector2i.ZERO)
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert(spatial != null)
	var fabric := spatial.compiled_fabric_cache()
	var maze := spatial.source_volume.mass_context[&"maze_source_plan"] as WarrenMazeSourcePlan
	var public: Dictionary = {}
	for cell: Vector3i in maze.excavation.public_cells():
		public[cell] = true
	var street: Dictionary = {}
	for cell: Vector3i in fabric.surface_plan.cells_for_kind(PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET):
		street[cell] = true
	print("GATE seed=",seed_value," specs=",VillageWarrenFabricSolver.terrain_contact_specs(spatial,fabric))
	for portal: Vector3i in maze.excavation.portals:
		var outward := VillageWarrenFabricSolver._explicit_portal_outward(maze,portal,public)
		var nearby: Array = []
		for cell: Vector3i in street:
			if abs(cell.x-portal.x*2)<=3 and abs(cell.z-portal.z*2)<=3:
				nearby.append(cell)
		print("GATE portal=",portal," outward=",outward," street=",nearby)
	quit()

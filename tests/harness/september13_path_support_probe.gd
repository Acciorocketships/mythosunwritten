extends SceneTree
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var name := args[0]
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.solve(9,{},program,WarrenVillageScaleProfile.for_id(&"standard"))
	var fabric := spatial.compiled_fabric_cache()
	var stone := SettlementFabricAssembler.maze_stone_cells(fabric.retained_terrace_cells)
	var plinth := fabric.retained_terrace_cells.duplicate()
	for cell: Vector3i in stone: plinth.erase(cell)
	var support := WarrenSpatialFabricCompiler._supported_retained_maze_cells(spatial,fabric,plinth,stone,fabric.transformed_cells(&"solid"))
	var payload := SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
	var output := "/Users/ryko/story/docs/qa/2026-09-13-manual/04-path/"
	FileAccess.open(output+name+"-payload.bin",FileAccess.WRITE).store_var({"batches":payload.batches,"collision_boxes":payload.collision_boxes,"surface_meshes":payload.surface_meshes,"transform":Transform3D.IDENTITY})
	FileAccess.open(output+name+"-support.txt",FileAccess.WRITE).store_string(var_to_str(support))
	print("UNSUPPORTED ", support.unsupported)
	quit()

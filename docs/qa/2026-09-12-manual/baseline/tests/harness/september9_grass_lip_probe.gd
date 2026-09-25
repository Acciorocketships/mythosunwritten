extends SceneTree
const Assembler = preload("res://scripts/terrain/features/villages/fabric/SettlementFabricAssembler.gd")
func _init()->void:
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial:=frozen.spatial(frozen.read("res://tests/fixtures/september9-east-source.txt"),program)
	var plan:=spatial.compiled_fabric_cache()
	var t:=Assembler.maze_ground_skin_transaction(plan)
	var controls:=Assembler.maze_terrain_control_surface_cells(plan)
	var region:=Assembler.maze_terrain_surface_region(t.capped_ground,controls)
	var layout:=Assembler.maze_green_rim_layout(t.shell,t.walked,t.paved,t.footprints,t.capped_ground,true,region)
	var rows:Array=[]
	for cell:Vector3i in t.capped_ground:
		if cell.y!=0:continue
		var faces:Array=[]
		for d:Vector3i in Assembler.FACE_DIRECTIONS:
			var beside:=cell+d
			faces.append({"direction":str(d),"neighbor_cap":t.capped_ground.has(beside),"neighbor_control":controls.has(beside+Vector3i.UP),"exposed":TerrainSurfaceField.is_exposed_edge(region,cell.x,cell.z,Vector2i(d.x,d.z)),"neighbor_height":region.surface_height(beside.x,beside.z)})
		rows.append({"cell":str(cell),"flat":TerrainSurfaceField.is_flat_cell(region,cell.x,cell.z),"faces":faces})
	var report:={"cells":rows,"layout":str(layout),"controls":str(controls),"plan_seed":plan.world_seed}
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit()

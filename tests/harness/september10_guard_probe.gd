extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric := frozen.spatial(frozen.read("res://tests/fixtures/september10-stone-source.txt"), program).compiled_fabric_cache()
	for z in range(2,6):
		var cell := Vector3i(-2,5,z)
		var segment := PublicRealmSurfacePlan._guard_segment(cell,Vector3i.LEFT,&"exposed_edge")
		print("SITE ",cell," retained ",fabric.retained_terrace_cells.has(cell+Vector3i.LEFT)," below ",fabric.retained_terrace_cells.has(cell+Vector3i.LEFT+Vector3i.DOWN))
		for unit: FabricUnit in fabric.units:
			var recipe := fabric.recipe(unit.recipe_id)
			for local: Vector3i in recipe.solid_cells:
				var p := FabricRecipe.transform_cell(local,unit.lattice_origin,unit.yaw_quarters)
				if p==cell+Vector3i.LEFT or p==cell+Vector3i.LEFT+Vector3i.UP: print("SOLID ",unit.stable_id," ",recipe.recipe_id," ",recipe.role_tags)
		for h in [0.2,1.15]:
			var a: Vector3=segment.a+Vector3.UP*h
			var b: Vector3=segment.b+Vector3.UP*h
			for box:AABB in fabric.surface_plan._guard_wall_boxes:
				var hit := WarrenTransitionSurfaceBuilder._line_box_interval(a,b,box.grow(.04))
				if hit.y>hit.x:print("WALL ",h," ",box," hit ",hit)
		print("PUBLIC ",fabric.surface_plan._has_public_transition(cell,Vector3i.LEFT)," BACKED ",fabric.surface_plan._guard_is_backed_by_wall(segment))
	quit()

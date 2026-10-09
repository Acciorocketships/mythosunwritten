extends GutTest
## The real shared-profile reach that dried between stations 6 and 7 of
## source (-1,1). Exercise the production fill, not the detached repair.
func test_reported_descent_stays_wet_and_below_its_natural_banks()->void:
	var previous:=TerrainTileField.cliff_end
	TerrainTileField.cliff_end=TerrainTileField.CliffEnd.SHARED_PROFILE
	preload("res://scripts/native/NativeGridKernels.gd").setup()
	preload("res://scripts/native/NativeTileKernel.gd").setup()
	preload("res://scripts/native/NativeWaterFill.gd").setup()
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var catalog:=EnvironmentCatalog.load_default()
	var index:=load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var program:=DressingCompiler.compile(index,catalog)
	var fields:=WorldFieldBlockCache.new(plan,water,program.query_margin,program.shore_distance_limit,64)
	var context:=fields.water(Vector2i(-1,5))
	var minimum:=INF
	for i in 57:
		var x:float=-44.0+i*.25
		var p:=Vector2(x,1143.4038+(x+40.91079)*.5744)
		var g:=TerrainTileField.surface_y(context._region,p.x,p.y)
		minimum=minf(minimum,WaterField.level_at(context._ctx,p)-g)
	assert_gt(minimum,.1,"the whole reported gap has water, including between hydraulic samples")
	var natural_plan:=HeightfieldPlan.new(plan.world_seed,plan.height_amplitude,plan.max_storeys,plan.aggregation,plan.max_step)
	natural_plan.set_raw_height_override(plan.uncarved_height)
	var natural:=natural_plan.compute_rect_region(Rect2i(-8,91,10,10))
	var spills:=0
	for z in 85:
		for x in 85:
			var p:=Vector2(-54,1128)+Vector2(x,z)*.5
			var level:=WaterField.level_at(context._ctx,p)
			var ground:=TerrainTileField.surface_y(context._region,p.x,p.y)
			if level<=ground+WaterField.EPS:continue
			if level>TerrainTileField.surface_y(natural,p.x,p.y)+WaterField.EPS:spills+=1
	assert_eq(spills,0,"the repaired reach stays in its excavation across the entire 42 m patch")
	TerrainTileField.cliff_end=previous

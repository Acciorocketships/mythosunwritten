# tests/harness/water_block_cost.gd
# Times one chunk's planning (heightfield region, then water context) as the
# streamer's worker computes it, with the same native kernels and disk cache.
#   PROFILE_WATER_COST=1 Godot --headless --path . -s res://tests/harness/water_block_cost.gd -- \
#     [--seed=N] [--chunk=x,z] [--no-disk] [--serial]
# Prints a digest of the region's storeys/levels and the water fill so a
# change can be checked for identical output.
extends SceneTree

func _init() -> void:
	var seed := 2697992464
	TerrainTileField.cliff_end=TerrainTileField.CliffEnd.SHARED_PROFILE
	var chunk := Vector2i(-1, 5)
	var disk := true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--chunk="):
			var xz := arg.trim_prefix("--chunk=").split(",")
			chunk = Vector2i(int(xz[0]), int(xz[1]))
		elif arg == "--no-disk": disk = false
		elif arg == "--serial": HeightfieldPlan.prefetch_enabled = false
	if disk:
		preload("res://scripts/terrain/field/PlanningDiskCache.gd").configure(seed)
	preload("res://scripts/native/NativeGridKernels.gd").setup()
	preload("res://scripts/native/NativeTileKernel.gd").setup()
	preload("res://scripts/native/NativeWaterFill.gd").setup()
	var water := TerrainWorldTuning.make_water(seed)
	var plan := TerrainWorldTuning.make_heightfield(seed, water)
	var catalog := EnvironmentCatalog.load_default()
	var index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var program := DressingCompiler.compile(index, catalog)
	var fields := WorldFieldBlockCache.new(plan, water, program.query_margin,
		program.shore_distance_limit, 64)
	var t := Time.get_ticks_usec()
	var region := fields.region(chunk)
	var region_ms := (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	var context := fields.water(chunk)
	var water_ms := (Time.get_ticks_usec() - t) / 1000.0
	var rows:Array=[];var dry:=0;var minimum:=INF
	for i in 57:
		var x:float=-44.0+i*.25
		var p:=Vector2(x,1143.4038+(x+40.91079)*.5744)
		var g:=TerrainTileField.surface_y(context._region,p.x,p.y)
		var level:=WaterField.level_at(context._ctx,p)
		minimum=minf(minimum,level-g)
		if level<=g+WaterField.EPS:dry+=1
		rows.append({"p":p,"ground":g,"level":level,"depth":level-g})
	FileAccess.open("/tmp/oct9-production-depth-check.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("PRODUCTION_DEPTH_CHECK ",JSON.stringify({"dry":dry,"minimum":minimum,"region_ms":region_ms,"water_ms":water_ms}))
	quit()

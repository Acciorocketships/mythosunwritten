extends SceneTree
func _init()->void:
	preload("res://scripts/native/NativeGridKernels.gd").setup()
	preload("res://scripts/native/NativeTileKernel.gd").setup()
	preload("res://scripts/native/NativeWaterFill.gd").setup()
	WaterField.profile_fine_input=func(data:Dictionary)->void:
		var rows:=int(data.coarse.size()/data.side)
		if not Rect2(data.base,Vector2(data.side-1,rows-1)*WaterField.FILL_STEP).has_point(Vector2(467,1139)):return
		FileAccess.open("/tmp/oct8-surface-input.var.gz",FileAccess.WRITE).store_buffer(var_to_bytes(data).compress(FileAccess.COMPRESSION_GZIP))
		print("SURFACE_INPUT ",data.base," ",Vector2i(data.side,rows))
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var region:=plan.compute_rect_region(Rect2i(24,72,32,40))
	var ctx:=WaterField.ctx(water,Vector2i(2,5),region)
	print("SURFACE_INPUT_DONE ",ctx.fill.size())
	WaterField._basin_lock.lock()
	var sources:=WaterField._basin_cache.values()
	WaterField._basin_lock.unlock()
	for source:Dictionary in sources:
		if Rect2(source.base,Vector2(source.size-1,source.rows-1)*WaterField.FILL_STEP).has_point(Vector2(467,1139)):
			FileAccess.open("/tmp/oct8-surface-trial.var.gz",FileAccess.WRITE).store_buffer(var_to_bytes(source).compress(FileAccess.COMPRESSION_GZIP))
	var fixture:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/october8/water-inputs.var.gz").decompress_dynamic(100000000,FileAccess.COMPRESSION_GZIP))
	fixture.storeys=region._storeys;fixture.levels=region._levels;fixture.carved=region._carved;fixture.native=region.native_control_heights
	fixture.water_region={"storeys":region._storeys,"levels":region._levels,"carved":region._carved,"native":region.native_control_heights}
	fixture.rivers=[]
	for trace:RiverTrace in ctx.rivers:
		fixture.rivers.append({"points":trace.points,"beds":trace.beds,"widths":trace.widths,"profile":WaterField.profile(trace,region)})
	fixture.water=ctx.fill
	fixture.fill_base=ctx.fill_base
	fixture.fill_size=ctx.get("fill_size",WaterField.FILL_M+1)
	FileAccess.open("/tmp/oct8-trial-water-inputs.var.gz",FileAccess.WRITE).store_buffer(var_to_bytes(fixture).compress(FileAccess.COMPRESSION_GZIP))
	WaterField.profile_fine_input=Callable()
	if "--repeat" in OS.get_cmdline_user_args():
		WaterField._basin_lock.lock()
		WaterField._basin_cache.clear()
		WaterField._basin_lock.unlock()
		var again:=WaterField.ctx(water,Vector2i(2,5),region)
		var same:bool=ctx.fill==again.fill
		print("SOURCE_REPEAT_IDENTICAL ",same," cached_bank_tiles=",plan._water_bank_bounds.size())
		if not same:
			quit(1)
			return
	quit()

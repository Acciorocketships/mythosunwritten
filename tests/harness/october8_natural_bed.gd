extends SceneTree
const E=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
func _init()->void:
	preload("res://scripts/native/NativeGridKernels.gd").setup()
	preload("res://scripts/native/NativeTileKernel.gd").setup()
	var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/october8/water-inputs.var.gz").decompress_dynamic(100000000,FileAccess.COMPRESSION_GZIP))
	var plan:=TerrainWorldTuning.make_heightfield(2697992464)
	var region:=plan.compute_rect_region(Rect2i(32,85,16,20))
	var ground:=func(p:Vector2)->float:return TerrainTileField.surface_y(region,p.x,p.y)
	var grid:=func(origin:Vector2,w:int,h:int)->PackedFloat64Array:
		var xs:=PackedFloat64Array();var zs:=PackedFloat64Array()
		for i in w:xs.append((origin+Vector2(i,0)*E.H).x)
		for k in h:zs.append((origin+Vector2(0,k)*E.H).y)
		return TerrainTileField.sample_grid(region,xs,zs)
	var points:=func(xs:PackedFloat64Array,zs:PackedFloat64Array)->PackedFloat64Array:return TerrainTileField.sample_grid(region,xs,zs)
	var env=E._build(Rect2(440,1090,70,74),ground,Callable(),2697992464,Callable(),grid,points,true,0)
	var out:Array=[]
	for river:Dictionary in d.rivers:
		for i in river.points.size():
			var at:Vector2=river.points[i]
			if not Rect2(440,1090,70,74).has_point(at):continue
			var item:Dictionary={"x":at.x,"z":at.y,"trace_bed":river.beds[i],"natural_kernel":ground.call(at),"natural_sheet":env.at(at),"raw_natural":HeightfieldPlan.height01(Vector3(at.x,0,at.y),2697992464)*TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE}
			print("NATURAL_BED ",JSON.stringify(item));out.append(item)
	FileAccess.open("/tmp/oct8-natural-bed.json",FileAccess.WRITE).store_string(JSON.stringify(out,"  "))
	quit()

extends SceneTree
func _init()->void:
	preload("res://scripts/native/NativeGridKernels.gd").setup()
	preload("res://scripts/native/NativeTileKernel.gd").setup()
	var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("/tmp/oct8-surface-input.var.gz").decompress_dynamic(200000000,FileAccess.COMPRESSION_GZIP))
	var plan:=TerrainWorldTuning.make_heightfield(2697992464)
	var natural:=plan.compute_rect_region(Rect2i(-5,80,60,30))
	var xs:=PackedFloat64Array();var zs:=PackedFloat64Array()
	for x in range(-3,552,6):xs.append(x)
	for z in range(999,1236,6):zs.append(z)
	var heights:=TerrainTileField.sample_grid(natural,xs,zs)
	var out:Array=[];var wet:=0;var outside:=0;var no_cut:=0
	for z in zs.size():
		for x in xs.size():
			var at:=Vector2(xs[x],zs[z])
			var cell:=Vector2i(((at-d.base)/6.0).round())
			var idx:int=cell.y*d.side+cell.x
			var level:float=d.coarse[idx]
			if not is_finite(level):continue
			wet+=1
			var original:float=heights[z*xs.size()+x]
			var bed:float=d.ground[idx]
			if level>original:outside+=1
			if original-bed<.1:no_cut+=1
			out.append({"x":at.x,"z":at.y,"water":level,"ground":bed,"natural":original,"cut":original-bed,"above_natural":level-original})
	print("CONTAINMENT wet=",wet," above_original=",outside," no_cut=",no_cut)
	FileAccess.open("/tmp/oct8-containment.json",FileAccess.WRITE).store_string(JSON.stringify(out,"  "))
	quit()

extends SceneTree
func _init()->void:
	var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/october8/water-inputs.var.gz").decompress_dynamic(100000000,FileAccess.COMPRESSION_GZIP))
	var source:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("/tmp/oct8-surface-trial.var.gz").decompress_dynamic(200000000,FileAccess.COMPRESSION_GZIP))
	var offset:=Vector2i(((d.fill_base-source.base)/WaterField.FILL_STEP).round())
	for key:String in ["levels","sub_levels","sub_ground"]:
		var sub:=key!="levels"
		var side:=roundi(sqrt(d.water[key].size()))
		var source_side:int=(source.size-1)*2+1 if sub else source.size
		var off:=offset*2 if sub else offset
		var values:PackedFloat32Array=d.water[key].duplicate()
		for z in side:
			for x in side:values[z*side+x]=source[key][(z+off.y)*source_side+x+off.x]
		d.water[key]=values
	FileAccess.open("/tmp/oct8-trial-water-inputs.var.gz",FileAccess.WRITE).store_buffer(var_to_bytes(d).compress(FileAccess.COMPRESSION_GZIP))
	quit()

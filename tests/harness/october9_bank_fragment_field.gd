extends RefCounted
func run(review:Node)->void:
	var rows:=[]
	for zi in 85:
		var depths:=[]
		var z:=1134.0+zi*.25
		for xi in 97:
			var x:float=-42.0+xi*.25
			var chunk:=FieldTerrainStreamer.chunk_of(Vector3(x,0,z))
			var water:WaterFieldContext=review._inputs[chunk].water
			var ground:=TerrainTileField.surface_y(water._region,x,z)
			var level:=water.level_at(Vector2(x,z))
			depths.append(level-ground if is_finite(level) else null)
		rows.append(depths)
	FileAccess.open(review._output_dir+"/bank-fragment-field.json",FileAccess.WRITE).store_string(JSON.stringify({"origin":[-42,1134],"step":.25,"depths":rows}))
	print("BANK_FRAGMENT_FIELD done")

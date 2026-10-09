extends RefCounted
func run(review:Node)->void:
	var water:WaterFieldContext=review._streamer._fields.water(Vector2i(3,8))
	var rows:=[]
	for trace:RiverTrace in water._ctx.rivers:
		if trace.source_cell!=Vector2i(0,2):continue
		for i in range(28,41):
			var p:=trace.points[i]
			var axis:Vector2=(trace.points[i+1]-trace.points[i-1]).normalized()
			var normal:=Vector2(-axis.y,axis.x)
			var transect:=[]
			for d in range(-40,41,2):
				var q:=p+normal*d
				var ctx:WaterFieldContext=review._streamer._fields.water(FieldTerrainStreamer.chunk_of(Vector3(q.x,0,q.y)))
				var ground:=TerrainTileField.surface_y(ctx._region,q.x,q.y)
				var level:=ctx.level_at(q)
				transect.append({"d":d,"ground":ground,"water":level if is_finite(level) else null})
			rows.append({"station":i,"p":str(p),"transect":transect})
	FileAccess.open(review._output_dir+"/channel-transects.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
	print("CHANNEL_TRANSECTS_DONE")

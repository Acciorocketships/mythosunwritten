extends RefCounted
func run(review: Node) -> void:
	var trace: RiverTrace = review._streamer._plan._water_plan.river_for(Vector2i(0,2))
	var rows := []
	for i in trace.points.size()-1:
		var p := trace.points[i]
		var direction := (trace.points[i+1]-p).normalized()
		var n := Vector2(-direction.y,direction.x)
		var low := INF
		var samples := []
		for distance in [trace.widths[i]+14.0,trace.widths[i]+26.0]:
			for side in [-1,1]:
				var q: Vector2 = p+n*float(distance)*float(side)
				var ctx: WaterFieldContext = review._streamer._fields.water(FieldTerrainStreamer.chunk_of(Vector3(q.x,0,q.y)))
				var ground := TerrainTileField.surface_y(ctx._region,q.x,q.y)
				low = minf(low,ground)
				samples.append({"p":str(q),"ground":ground})
		rows.append({"station":i,"bed":trace.beds[i],"lowest_bank":low,"samples":samples})
	FileAccess.open(review._output_dir+"/bank-clearance.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("BANK_CLEARANCE_DONE")

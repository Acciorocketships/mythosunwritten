extends RefCounted
func run(review: Node) -> void:
	var rows := []
	var sources := {}
	for z in range(1490,1600,4):
		for x in range(640,755,4):
			var p := Vector2(x,z)
			var chunk := FieldTerrainStreamer.chunk_of(Vector3(x,0,z))
			var water: WaterFieldContext = review._streamer._fields.water(chunk)
			var level := water.level_at(p)
			if not is_finite(level): continue
			var ground := TerrainTileField.surface_y(water._region,x,z)
			var nearest := INF
			var width := 0.0
			var bed := 0.0
			for trace: RiverTrace in water._ctx.rivers:
				for i in trace.points.size()-1:
					var a := trace.points[i]
					var b := trace.points[i+1]
					var t := clampf((p-a).dot(b-a)/maxf(.0001,a.distance_squared_to(b)),0,1)
					var d := p.distance_to(a.lerp(b,t))
					if d < nearest:
						nearest = d
						width = lerpf(trace.widths[i],trace.widths[i+1],t)
						bed = lerpf(trace.beds[i],trace.beds[i+1],t)
				if not sources.has(trace.source_cell):
					sources[trace.source_cell] = {"points":Array(trace.points),"widths":Array(trace.widths),"beds":Array(trace.beds)}
			var ponds := []
			for pond: PondStamp in water._ctx.ponds:
				if pond.footprint_t(p)<1.2: ponds.append({"center":pond.center,"t":pond.footprint_t(p),"surface":pond.surface_y()})
			rows.append({"p":p,"water":level,"ground":ground,"distance":nearest,"width":width,"bed":bed,"ponds":ponds})
	FileAccess.open(review._output_dir+"/water-probe.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"sources":sources}))
	print("EVENING_WATER_PROBE_DONE ",rows.size())

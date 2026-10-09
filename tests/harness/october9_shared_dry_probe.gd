extends RefCounted
func run(review: Node) -> void:
	var rows: Array = []
	for x in range(-44, -29):
		var p := Vector2(x, 1143.4038 + (x + 40.91079) * 0.5744)
		var chunk := FieldTerrainStreamer.chunk_of(Vector3(p.x, 0, p.y))
		var water: WaterFieldContext = review._inputs[chunk].water
		var c: Dictionary = water._ctx
		var traces: Array = []
		for trace: RiverTrace in c.rivers:
			if trace.source_cell != Vector2i(-1, 1): continue
			var prof := WaterField.profile(trace, water._region)
			for i in mini(12, trace.points.size()):
				traces.append({"point":str(trace.points[i]), "bed":trace.beds[i], "width":trace.widths[i], "level":prof.levels[i]})
		var local: Vector2 = (p - c.fill_base) / WaterField.FILL_STEP
		var lo := Vector2i(local.floor())
		var n: int = c.get("fill_size", WaterField.FILL_M + 1)
		var nodes: Array = []
		for z in 2:
			for xx in 2:
				var at := lo + Vector2i(xx,z)
				var q: Vector2 = c.fill_base + Vector2(at)*WaterField.FILL_STEP
				nodes.append({"point":str(q),"level":str(c.fill.levels[at.y*n+at.x]),"ground":TerrainTileField.surface_y(water._region,q.x,q.y)})
		rows.append({"p":str(p), "ground":TerrainTileField.surface_y(water._region,p.x,p.y),"level":str(water.level_at(p)),"coarse":str(WaterField._fill_bilinear_coarse(c,p)),"untapered":str(WaterField._fill_untapered_level(c,p)),"membership":str(WaterField._channel_membership_level(c,p)),"nodes":nodes,"trace":traces if x == -40 else []})
	FileAccess.open(review._output_dir+"/shared-dry-detail.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("SHARED_DRY_PROBE done")

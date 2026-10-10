extends RefCounted
func run(review: Node) -> void:
	var water = review._streamer._plan._water_plan
	var trace: RiverTrace = water.river_for(Vector2i(0,2))
	var rows := []
	for i in range(trace.points.size()-1):
		var a := trace.points[i]
		var b := trace.points[i+1]
		for k in 25:
			var p := a.lerp(b,float(k)/24.0)
			var ctx: WaterFieldContext = review._streamer._fields.water(FieldTerrainStreamer.chunk_of(Vector3(p.x,0,p.y)))
			var ground := TerrainTileField.surface_y(ctx._region,p.x,p.y)
			var level := ctx.level_at(p)
			rows.append({"station":i,"p":str(p),"ground":ground,"water":level if is_finite(level) else null,"depth":level-ground if is_finite(level) else null})
	FileAccess.open(review._output_dir+"/confluence-depths.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
	var old: Array = review._views.duplicate()
	review._views.clear()
	review._views.append({"id":"confluence_overview","position":Vector3(605,110,1690),"target":Vector3(610,24,1625),"fov":60.0,"player":Vector3(616,20,1627)})
	review._views.append({"id":"confluence_approach","position":Vector3(588,58,1660),"target":Vector3(616,20,1627),"fov":60.0,"player":Vector3(616,20,1627)})
	review._views.append({"id":"water_hill","position":Vector3(420.3,37.9,1513),"target":Vector3(453.6,20.2,1579.2),"fov":65.0,"player":Vector3(420.3,31.9,1513)})
	await review._capture_all(3)
	review._views.assign(old)
	print("CONFLUENCE_REVIEW_DONE samples=",rows.size())

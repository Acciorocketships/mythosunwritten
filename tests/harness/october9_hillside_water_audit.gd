extends RefCounted
func run(review: Node) -> void:
	var out := []
	var seen := {}
	for chunk: Vector2i in review._streamer._built:
		var ctx: WaterFieldContext = review._streamer._fields.water(chunk)
		for trace: RiverTrace in ctx._ctx.get("rivers",[]):
			if seen.has(trace.source_cell): continue
			seen[trace.source_cell] = true
			var stations := []
			for i in trace.points.size():
				if trace.points[i].distance_to(Vector2(490,1590))<220:
					stations.append({"i":i,"point":str(trace.points[i]),"bed":trace.beds[i],"width":trace.widths[i]})
			out.append({"source":str(trace.source_cell),"joined":trace.joined,"priority":trace.priority,"stations":stations})
	FileAccess.open(review._output_dir+"/hill-rivers.json",FileAccess.WRITE).store_string(JSON.stringify(out,"  "))
	var old: Array = review._views.duplicate()
	review._views.clear()
	review._views.append({"id":"hill_overview","position":Vector3(500,160,1510),"target":Vector3(500,35,1600),"fov":65.0,"player":Vector3(490,40,1590)})
	await review._capture_all(1)
	review._views.assign(old)
	print("HILL_AUDIT_DONE")

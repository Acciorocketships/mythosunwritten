extends RefCounted
func run(review:Node)->void:
	var out:Array=[]
	for chunk:Vector2i in review._inputs:
		var water:WaterFieldContext=review._inputs[chunk].water
		var item:Dictionary={"chunk":str(chunk),"ponds":[],"rivers":[]}
		for pond:PondStamp in water._ctx.ponds:
			item.ponds.append({"center":str(pond.center),"level":pond.level,"radius":pond.bound_radius()})
		for trace:RiverTrace in water._ctx.rivers:
			var points:Array=[]
			var strengths:PackedFloat64Array=water._ctx.water.bank_strengths(trace)
			for i in trace.points.size():
				if Rect2(-50,990,620,270).has_point(trace.points[i]):
					points.append({"p":str(trace.points[i]),"bed":trace.beds[i],"half_width":trace.widths[i],"bank_strength":strengths[i]})
			if not points.is_empty():item.rivers.append(points)
		out.append(item)
	FileAccess.open(review._output_dir+"/bodies.json",FileAccess.WRITE).store_string(JSON.stringify(out,"  "))
	print("[oct8_water_bodies] exported ",out.size()," chunks")

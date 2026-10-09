extends RefCounted
func run(review:Node)->void:
	var traces:Dictionary={}
	for input:Dictionary in review._inputs.values():
		for trace:RiverTrace in input.water._ctx.rivers:traces[trace.get_instance_id()]=trace
	var samples:=0;var dry:=0;var buried:=0;var internal_dry:=0;var failures:Array=[]
	var world:World3D=review._camera.get_world_3d()
	for trace:RiverTrace in traces.values():
		var seen_wet:=false
		var pending_dry:=0
		for i in range(1,trace.points.size()):
			var a:=trace.points[i-1];var b:=trace.points[i]
			var steps:=ceili(a.distance_to(b))
			for j in steps:
				var point:=a.lerp(b,float(j)/steps)
				var chunk:=FieldTerrainStreamer.chunk_of(Vector3(point.x,0,point.y))
				if not review._inputs.has(chunk):continue
				var water:WaterFieldContext=review._inputs[chunk].water
				var level:=water.level_at(point)
				var query:=PhysicsRayQueryParameters3D.create(Vector3(point.x,400,point.y),Vector3(point.x,-100,point.y))
				var hit:=world.direct_space_state.intersect_ray(query)
				if not hit.is_empty() and str(hit.collider.get_path()).contains("/CliffSlopeRocks/"):
					query.exclude=[hit.rid]
					hit=world.direct_space_state.intersect_ray(query)
				if hit.is_empty():continue
				samples+=1
				if not is_finite(level):
					dry+=1
					if seen_wet:pending_dry+=1
				else:
					seen_wet=true;internal_dry+=pending_dry;pending_dry=0
					if level<=hit.position.y:buried+=1
					else:continue
				failures.append({"x":point.x,"z":point.y,"source":str(trace.source_cell),"station":i,"water":level if is_finite(level) else null,"ground":hit.position.y,"chunk":str(chunk),"collider":str(hit.collider.get_path())})
	FileAccess.open(review._output_dir+"/visible-river-failures.json",FileAccess.WRITE).store_string(JSON.stringify(failures,"  "))
	print("VISIBLE_RIVERS samples=",samples," dry=",dry," internal_dry=",internal_dry," buried=",buried)

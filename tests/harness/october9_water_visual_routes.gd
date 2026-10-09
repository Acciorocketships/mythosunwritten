extends RefCounted

func run(review:Node)->void:
	var samples := []
	var seen := {}
	var bounds := Rect2()
	var first := true
	for chunk:Vector2i in review._inputs:
		var box := Rect2(Vector2(chunk)*192.0,Vector2.ONE*192.0)
		bounds = box if first else bounds.merge(box)
		first = false
	var interior := bounds.grow(-65.0)
	for input:Dictionary in review._inputs.values():
		for trace:RiverTrace in input.water._ctx.rivers:
			if seen.has(trace.source_cell): continue
			seen[trace.source_cell] = true
			for i in range(1,trace.points.size()-1):
				var p := trace.points[i]
				if not interior.has_point(p): continue
				var chunk := FieldTerrainStreamer.chunk_of(Vector3(p.x,0,p.y))
				if not review._inputs.has(chunk): continue
				var water:WaterFieldContext = review._inputs[chunk].water
				var level := water.level_at(p)
				if not is_finite(level): continue
				var ground := TerrainTileField.surface_y(water._region,p.x,p.y)
				var tangent := (trace.points[i+1]-trace.points[i-1]).normalized()
				var before := water.level_at(p-tangent*4.0)
				var after := water.level_at(p+tangent*4.0)
				var drop := absf(before-after) if is_finite(before) and is_finite(after) else 0.0
				samples.append({"at":Vector3(p.x,level,p.y),"tangent":tangent,"depth":level-ground,"drop":drop})
	if samples.is_empty():
		push_error("No interior wet samples for route review")
		return
	var old_views:Array[Dictionary] = review._views.duplicate()
	review._views.clear()
	var evidence := []
	for mode:String in ["drop","shallow"]:
		samples.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.drop>b.drop if mode=="drop" else a.depth<b.depth)
		var sample:Dictionary = samples[0]
		var at:Vector3 = sample.at
		var tangent:Vector2 = sample.tangent
		var camera := at+Vector3(-tangent.y,0,tangent.x)*42.0+Vector3.UP*32.0
		var query := PhysicsRayQueryParameters3D.create(Vector3(camera.x,1000,camera.z),Vector3(camera.x,-500,camera.z),1)
		var hit:Dictionary = review.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): camera.y=maxf(camera.y,hit.position.y+6.0)
		review._views.append({"id":"river_"+mode,"position":camera,"target":at,"fov":60.0,"player":at})
		evidence.append({"kind":mode,"at":str(at),"camera":str(camera),"depth":sample.depth,"drop_8m":sample.drop})
	await review._capture_all(41)
	FileAccess.open(review._output_dir+"/river-visual-routes.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))
	review._views=old_views
	print("RIVER_VISUAL_ROUTES ",JSON.stringify(evidence))

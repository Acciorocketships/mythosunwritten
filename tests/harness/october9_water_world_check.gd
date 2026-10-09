extends RefCounted
func run(review:Node)->void:
	for chunk:Vector2i in review._streamer._built:
		var features:FeatureContext=review._streamer._features.context_for(chunk,Callable())
		review._inputs[chunk]={"region":features.graded_region(review._streamer._fields.region(chunk)),"water":review._streamer._fields.water(chunk),"features":features}
	await preload("res://tests/harness/october8_visible_rivers.gd").new().run(review)
	var seen:Dictionary={};var added:=0
	var bounds := Rect2()
	var first := true
	for chunk: Vector2i in review._inputs:
		var box := Rect2(Vector2(chunk) * 192.0, Vector2.ONE * 192.0)
		bounds = box if first else bounds.merge(box)
		first = false
	var interior := bounds.grow(-80.0)
	for input:Dictionary in review._inputs.values():
		for trace:RiverTrace in input.water._ctx.rivers:
			if seen.has(trace.source_cell):continue
			seen[trace.source_cell]=true
			var best := INF
			var at := Vector3.ZERO
			for p:Vector2 in trace.points:
				if not interior.has_point(p):continue
				var chunk:=FieldTerrainStreamer.chunk_of(Vector3(p.x,0,p.y))
				if not review._inputs.has(chunk):continue
				var water:WaterFieldContext=review._inputs[chunk].water
				var ground:=TerrainTileField.surface_y(water._region,p.x,p.y)
				var level:=WaterField.level_at(water._ctx,p)
				if not is_finite(level):continue
				var distance := p.distance_squared_to(Vector2(review._at.x,review._at.z))
				if distance < best:
					best = distance
					at = Vector3(p.x,maxf(ground,level),p.y)
			if best == INF:continue
			review._views.append({"id":"water_%d"%added,"position":at+Vector3(45,45,45),"target":at,"fov":50.0})
			print("NEW_WATER_VIEW source=",trace.source_cell," at=",at)
			added+=1
			if added>=3:break
		if added>=3:break
	await review._capture_all(1)
	for i in added:review._views.pop_back()
	print("NEW_WATER_CHECK done")

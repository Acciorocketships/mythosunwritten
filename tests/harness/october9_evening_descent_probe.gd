extends SceneTree
func _init()->void: _run.call_deferred()
func _run()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(plan,water,24.0,0.0,64)
	var context:=fields.water(Vector2i(-1,5))
	for i in 15:
		var x:float=-44+i
		var p:=Vector2(x,1143.4038+(x+40.91079)*.5744)
		var nearest:=INF
		var near:=Vector2.ZERO
		for trace:RiverTrace in context._ctx.rivers:
			for j in trace.points.size()-1:
				var q:=Geometry2D.get_closest_point_to_segment(p,trace.points[j],trace.points[j+1])
				if q.distance_to(p)<nearest:nearest=q.distance_to(p);near=q
		print("DEPTH ",p," dist=",nearest," ground=",TerrainTileField.surface_y(context._region,p.x,p.y)," level=",WaterField.level_at(context._ctx,p)," center=",near," center_ground=",TerrainTileField.surface_y(context._region,near.x,near.y)," center_water=",WaterField.level_at(context._ctx,near))
	quit()

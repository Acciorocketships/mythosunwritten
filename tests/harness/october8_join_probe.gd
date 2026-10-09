extends RefCounted
func run(review:Node)->void:
	var water:WaterFieldContext=review._inputs[Vector2i(0,5)].water
	var plan:WaterPlan=water._ctx.water
	var point:=Vector2(143.016,1058.538)
	var original:=plan.noise_h(point)
	for pond:PondStamp in water._ctx.ponds:
		if pond.footprint_t(point)>=1:continue
		print("JOIN_POND p=",point," center=",pond.center," natural=",original," cut=",pond.carve_at(point,original)," water=",pond.surface_y()," t=",pond.footprint_t(point))
	for trace:RiverTrace in water._ctx.rivers:
		if trace.source_cell!=Vector2i(-1,0):continue
		var raw:=plan.river_for(trace.source_cell,0)
		print("JOIN_TRACE source=",trace.source_cell," joined=",trace.joined," endpoint=",trace.points[-1]," last_bed=",trace.beds[-1]," stations=",trace.points.size()," raw=",raw.points.size())
		for i in range(trace.points.size()-1,mini(trace.points.size()+12,raw.points.size())):
			var at:Vector2=raw.points[i]
			var ground:=plan.noise_h(at)
			for pond:PondStamp in water._ctx.ponds:
				if pond.footprint_t(at)<1:print("JOIN_CONTINUATION ",at," bed=",raw.beds[i]," pond_ground=",ground-pond.carve_at(at,ground)," pond_water=",pond.surface_y())

extends SceneTree
func _init()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	for chunk:Vector2i in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i(0,0)]:
		var bodies:=water.bodies_near(chunk*8+Vector2i(4,4),8)
		var bounds:=Rect2();var started:=false
		for river:RiverTrace in bodies.rivers:
			print("DOMAIN_RIVER ",chunk," ",river.source_cell," ",river.bounds())
			bounds=bounds.merge(river.bounds()) if started else river.bounds();started=true
		for pond:PondStamp in bodies.ponds:
			var b:=Rect2(pond.center-Vector2.ONE*pond.bound_radius(),Vector2.ONE*pond.bound_radius()*2)
			print("DOMAIN_POND ",chunk," ",pond.center," ",b)
			bounds=bounds.merge(b) if started else b;started=true
		bounds=bounds.grow(maxf(WaterField.TILE*3,WaterPlan.W_MAX+WaterPlan.BANK_FEATHER))
		print("DOMAIN ",chunk," ",bounds," contains_origin=",bounds.has_point(Vector2.ZERO))
	quit()

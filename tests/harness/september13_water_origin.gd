extends SceneTree
func _init()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),water,26,0,64)
	for chunk:Vector2i in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i(0,0)]:
		var ctx:=fields.water(chunk)
		var raw:=ctx.raw_context()
		print("ORIGIN_CONTEXT ",chunk," ponds=",raw.ponds.size()," rivers=",raw.rivers.size())
		var source:=WaterField._source_fill(raw,ctx._region)
		print("ORIGIN_SOURCE ",chunk," base=",source.get("base")," size=",source.get("size")," rows=",source.get("rows")," boundary_wet=",source.get("boundary_wet"))
		for p:Vector2 in [Vector2(-.01,-.01),Vector2(.01,-.01),Vector2(.01,.01),Vector2(-.01,.01),Vector2(6.5,-7.4)]:
			print("ORIGIN_SAMPLE ",chunk," ",p," wet=",ctx.is_wet(p)," level=",WaterField.level_at(raw,p)," bed=",TerrainSurfaceField.surface_y(ctx._region,p.x,p.y))
	quit()

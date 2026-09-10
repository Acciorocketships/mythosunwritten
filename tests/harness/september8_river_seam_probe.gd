extends SceneTree

func _initialize() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var fields := WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),water,0,0,128)
	for chunk in [Vector2i(-3,-2),Vector2i(-3,-1)]:
		var field := fields.water(chunk)
		print("CHUNK ",chunk," level=",field.level_at(Vector2(-573,-192)),
			" coarse=",WaterField._fill_bilinear_coarse(field._ctx,Vector2(-573,-192)))
		for tr: RiverTrace in field._ctx.rivers:
			var nearest := INF
			var bed := 0.0
			var point := Vector2.ZERO
			for i in tr.points.size():
				var d := tr.points[i].distance_to(Vector2(-573,-192))
				if d < nearest:
					nearest=d;bed=tr.beds[i];point=tr.points[i]
			print("  SOURCE ",tr.source_cell," near=",nearest," bed=",bed," point=",point)
		for pond: PondStamp in field._ctx.ponds:
			print("  POND ",pond.center," level=",pond.surface_y()," r=",pond.bound_radius())
	quit()

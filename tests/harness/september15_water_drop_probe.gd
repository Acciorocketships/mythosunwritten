extends SceneTree

func _init()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(plan,water,26,0,64)
	var point:=Vector2(-221.2,-1478.9)
	var field:=fields.water_at(point)
	var region:=fields.region_at(point)
	var out:=FileAccess.open("res://docs/qa/2026-09-15-manual/05-water-drops/field-before.csv",FileAccess.WRITE)
	out.store_line("x,z,ground,water,wet")
	for iz in 181:
		for ix in 181:
			var p:=Vector2(-275+ix*.5,-1520+iz*.5)
			var ground:=TerrainTileField.surface_y(region,p.x,p.y)
			var level:=field.level_at(p)
			out.store_csv_line([str(p.x),str(p.y),str(ground),str(level),str(field.is_wet(p))])
	out.close()
	var ctx:=field.raw_context()
	var records:=[]
	for river:RiverTrace in ctx.rivers:
		if not river.bounds().grow(24).has_point(point):continue
		var profile:=WaterField.profile(river,region)
		records.append({"source":str(river.source_cell),"points":str(river.points),"beds":str(river.beds),"levels":str(profile.levels)})
	FileAccess.open("res://docs/qa/2026-09-15-manual/05-water-drops/profiles-before.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	print("DROP_FIELD_PROBE_DONE ",records.size())
	quit()

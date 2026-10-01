extends SceneTree
# Source/terrain diagnosis only. No invented hydraulic acceptance.
func _init() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464,water)
	var points := [Vector2(-1126.6,-742.7),Vector2(-1190.7,-604.5),Vector2(-1307.5,-341.2)]
	var reports := []
	for point: Vector2 in points:
		var ctx := water.bodies_in_rect(Rect2(point-Vector2.ONE*96,Vector2.ONE*192))
		var rivers := []
		for river: RiverTrace in ctx.rivers:
			var distance := INF
			var nearest := -1
			for i in river.points.size():
				if river.points[i].distance_to(point) < distance:
					distance = river.points[i].distance_to(point)
					nearest = i
			if distance > 200: continue
			var region := plan.compute_rect_region(Rect2i(Vector2i((river.bounds().position/24).floor())-Vector2i.ONE*4,Vector2i((river.bounds().size/24).ceil())+Vector2i.ONE*9))
			var profile := WaterField.profile(river,region)
			var samples := []
			for i in range(maxi(0,nearest-3),mini(river.points.size(),nearest+4)):
				var p: Vector2 = river.points[i]
				samples.append({"i":i,"xz":[p.x,p.y],"ground":TerrainTileField.surface_y(region,p.x,p.y),"bed":river.beds[i],"level":profile.levels[i]})
			rivers.append({"source":str(river.source_cell),"first":str(river.points[0]),"last":str(river.points[-1]),"nearest_distance":distance,"nearest_index":nearest,"count":river.points.size(),"samples":samples})
		reports.append({"point":str(point),"rivers":rivers,"pond_count":ctx.ponds.size()})
		print("WATER_INVENTORY ",JSON.stringify(reports[-1]))
	FileAccess.open("res://docs/qa/2026-09-16-manual/water-inventory.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	quit()

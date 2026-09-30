extends SceneTree
func _init() -> void:
	var seed_value := 2697992464
	var water := TerrainWorldTuning.make_water(seed_value)
	var heights := TerrainWorldTuning.make_heightfield(seed_value)
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights,water,program.query_margin,program.shore_distance_limit,program.FIELD_CACHE_CAP)
	var paths := PathPlan.new(seed_value,water,fields,program,program.query_margin,SettlementPlan.new(seed_value,water))
	var rows := []
	for cell: Vector2i in [Vector2i(-20,-13),Vector2i(-9,-41),Vector2i(10,-16),Vector2i(21,-49)]:
		for direction: Vector2i in paths._DIRS:
			var a := Vector2(cell)*HeightfieldPlan.CELL
			var b := Vector2(cell+direction)*HeightfieldPlan.CELL
			var row := {"cell":str(cell),"direction":str(direction),"height_a":paths._ground(a),"height_b":paths._ground(b),"walkable":PathProgram.is_route_edge_walkable(fields.region_at((a+b)*.5),cell,direction),"uncarved_control":true}
			var region := fields.region_at((a+b)*.5)
			# The route edge crosses two 12 m point edges (route cell c = point 2c);
			# sample each one's dual-cell border from both owning points.
			var gaps := []
			for edge: Array in PathProgram.route_point_edges(cell,direction):
				var p: Vector2i = edge[0]
				var q: Vector2i = p+direction
				for lateral: float in [-2.0,0.0,2.0]:
					var boundary := (Vector2(p)+Vector2(direction)*.5)*HeightfieldPlan.POINT+Vector2(-direction.y,direction.x)*lateral
					var first := TerrainTileField.surface_y_on_side(region,boundary.x,boundary.y,p)
					var last := TerrainTileField.surface_y_on_side(region,boundary.x,boundary.y,q)
					gaps.append({"point":str(p),"offset":lateral,"a":first,"b":last,"gap":absf(first-last)})
			row["seam_samples"] = gaps
			rows.append(row)
			print(JSON.stringify(row))
			FileAccess.open("res://docs/qa/2026-09-13-manual/36-world-paths/exits-uncarved.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()

extends SceneTree
func _init() -> void:
	var seed_value := 2697992464
	var water := TerrainWorldTuning.make_water(seed_value)
	var heights := TerrainWorldTuning.make_heightfield(seed_value,water)
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights,water,program.query_margin,program.shore_distance_limit,program.FIELD_CACHE_CAP)
	var paths := PathPlan.new(seed_value,water,fields,program,program.query_margin,SettlementPlan.new(seed_value,water))
	var rows := []
	for cell: Vector2i in [Vector2i(-20,-13),Vector2i(-9,-41),Vector2i(10,-16),Vector2i(21,-49)]:
		for direction: Vector2i in paths._DIRS:
			var a := Vector2(cell)*HeightfieldPlan.CELL
			var b := Vector2(cell+direction)*HeightfieldPlan.CELL
			var row := {"cell":str(cell),"direction":str(direction),"height_a":paths._ground(a),"height_b":paths._ground(b),"walkable":PathProgram.is_route_edge_walkable(fields.region_at((a+b)*.5),cell,direction),"planning_intervals":str(paths._planning_intervals_cells(cell,cell+direction)),"planning_distance":paths._planning_distance(cell)}
			var region := fields.region_at((a+b)*.5)
			var gaps := []
			for lateral: float in [-2.0,0.0,2.0]:
				var boundary := (a+b)*.5+Vector2(-direction.y,direction.x)*lateral
				var first := TerrainSurfaceField.surface_y_in_cell(region,boundary.x,boundary.y,cell.x,cell.y)
				var last := TerrainSurfaceField.surface_y_in_cell(region,boundary.x,boundary.y,cell.x+direction.x,cell.y+direction.y)
				gaps.append({"offset":lateral,"a":first,"b":last,"gap":absf(first-last)})
			row["seam_samples"] = gaps
			rows.append(row)
			print(JSON.stringify(row))
			FileAccess.open("res://docs/qa/2026-09-13-manual/36-world-paths/exits.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()

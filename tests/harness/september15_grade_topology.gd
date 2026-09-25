extends SceneTree
const Frozen = preload("res://tests/fixtures/frozen_terrain_grade.gd")
func _init() -> void:
	for site: Array in [["P07",Vector2i(-22,-82)],["P08",Vector2i(-25,-83)],["P09",Vector2i(-21,-11)]]:
		var region := Frozen.region("res://docs/qa/2026-09-15-manual/01-grass/%s-field.txt"%site[0])
		print("SITE ",site[0])
		var candidate := preload("res://tests/fixtures/september15/grid_grade_candidate.gd").region(region)
		var errors := []
		for grade: TerrainGradePatch in region.terrain_grades:
			var heights: Dictionary = {}
			for fine: Vector2i in grade._claims:
				heights[grade._claims[fine]]=true
				var point := grade._origin+Vector2(fine)*grade._targets.pitch
				var before := TerrainSurfaceField.surface_y(region,point.x,point.y)
				var after := TerrainSurfaceField.surface_y(candidate,point.x,point.y)
				if absf(after-before) > .15:
					errors.append([point,before,after,grade._continuous_cells.has(fine)])
			print("CLAIM_HEIGHTS ",heights.keys())
		print("CLAIM_ERRORS ",errors.size()," example ",errors.slice(0,12))
		for z in range(site[1].y-1,site[1].y+2):
			for x in range(site[1].x-1,site[1].x+2):
				var center := Vector2(x,z)*24
				var claimed := 0
				var maximum := 0.0
				var minimum := INF
				for grade: TerrainGradePatch in region.terrain_grades:
					for key: Vector2i in grade._claims:
						var point := grade._origin+Vector2(key)*grade._targets.pitch
						if Rect2(center-Vector2.ONE*12,Vector2.ONE*24).has_point(point):
							claimed+=1
				for dz: float in [-10.5,0,10.5]:
					for dx: float in [-10.5,0,10.5]:
						var h := TerrainSurfaceField.surface_y(region,center.x+dx,center.y+dz)
						minimum=minf(minimum,h);maximum=maxf(maximum,h)
				print(Vector2i(x,z)," natural=",region.surface_height(x,z)," claims=",claimed," graded=",Vector2(minimum,maximum))
	quit()

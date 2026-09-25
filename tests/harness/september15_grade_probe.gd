extends SceneTree

func _init() -> void:
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var water := TerrainWorldTuning.make_water(2697992464)
	var fields := WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464, water),
		water, program.query_margin, program.shore_distance_limit, program.field_cache_cap)
	var world := WorldFeaturePlan.new(2697992464, water, fields, program, SettlementPlan.new(2697992464, water))
	for spot: Array in [["P09",Vector2(-492.4,-277.9)],["P07",Vector2(-518,-1954.1)],["P08",Vector2(-589.4,-2002.1)]]:
		var area := Rect2(spot[1] - Vector2.ONE * 60.0, Vector2.ONE * 120.0)
		var grades: Array = []
		for record: VillageRecord in world._records_affecting(area):
			if record.urban_fabric != null and record.urban_fabric.terrain_grade != null:
				var grade := record.urban_fabric.terrain_grade
				if grade.bounds.intersects(area, true): grades.append(_freeze_grade(grade))
		var region := fields.region_covering(area.grow(48.0))
		var data := {"storeys":region._storeys,"levels":region._levels,"carved":region._carved,"grades":grades,"area":area}
		FileAccess.open("res://docs/qa/2026-09-15-manual/01-grass/" + spot[0] + "-field.txt",FileAccess.WRITE).store_string(var_to_str(data))
		print("FROZEN_GRADE ",spot[0]," grades=",grades.size()," cells=",region._storeys.size())
	quit()

func _freeze_grade(grade: TerrainGradePatch) -> Dictionary:
	return {"id":grade.stable_id,"claims":grade._claims,"origin":grade._origin,"pitch":grade._targets.pitch,
		"continuous_cells":grade._continuous_cells,"datum":grade._continuous_datum,
		"source":{} if grade._continuous_source == null else _freeze_grade(grade._continuous_source)}

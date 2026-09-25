extends SceneTree
const OUT := "res://docs/qa/2026-09-19-manual/131-water-query-cost"

func _init() -> void: run.call_deferred()

func run() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var fields := WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),water,26,0,8)
	var region := fields.region(Vector2i(-3,1))
	var context := fields.water(Vector2i(-3,1))
	var raw := context.raw_context()
	var points := PackedVector2Array()
	# Broad mixed wet/dry owner plus fine bank crossings, including the two
	# sloping-water and dry-neighbor regressions from the bank review.
	for z in range(192,384,2):
		for x in range(-576,-384,2): points.append(Vector2(x+.137,z+.291))
	for centre: Vector2 in [Vector2(-541.5,205.5),Vector2(-586.5,205.5),Vector2(-539,323),Vector2(-468,299)]:
		for z in range(-24,25):
			for x in range(-24,25): points.append(centre+Vector2(x,z)*.125)
	var wet := 0
	var dry := 0
	var mismatches := 0
	var expected := PackedFloat64Array()
	for point: Vector2 in points:
		var original := old_level(raw,region,point)
		var current := context.level_at(point)
		if is_nan(original):
			dry += 1
			if not is_nan(current): mismatches += 1
		else:
			wet += 1
			if original != current: mismatches += 1
		expected.append(original)
	var timings: Array = []
	for repeat in 8:
		for current: bool in ([false,true] if repeat%2==0 else [true,false]):
			var started := Time.get_ticks_usec()
			var values := PackedFloat64Array()
			for point: Vector2 in points:
				values.append(context.level_at(point) if current else old_level(raw,region,point))
			var elapsed := Time.get_ticks_usec()-started
			assert(values.to_byte_array()==expected.to_byte_array(),"Benchmark must preserve every result, including dry NaNs")
			timings.append({"candidate":current,"repeat":repeat,"microseconds":elapsed})
	var report := {"points":points.size(),"wet":wet,"dry":dry,"mismatches":mismatches,"timings":timings}
	FileAccess.open(OUT.path_join("comparison.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WATER_QUERY_COMPARE points=",points.size()," wet=",wet," dry=",dry," mismatches=",mismatches)
	quit(0 if mismatches==0 and wet>0 and dry>0 else 1)

func old_level(raw: Dictionary, region: HeightfieldRegion, point: Vector2) -> float:
	if not WaterField.wet(raw,region,point): return NAN
	return WaterField.level_at(raw,point)

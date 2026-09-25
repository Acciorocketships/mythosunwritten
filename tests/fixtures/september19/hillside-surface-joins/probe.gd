extends SceneTree
const OUT := "res://docs/qa/2026-09-19-manual/114-hillside-surface-joins/"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var water := preload("res://tests/fixtures/september19/hillside-native-reaches/long_reach_plan.gd").new(2697992464,128,32)
	var geology := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464,geology)
	var fields := WorldFieldBlockCache.new(plan,water,26,0,64)
	var field := fields.water(Vector2i(-6,-4))
	assert(water.rejected_routes.is_empty())
	var c := field.raw_context()
	var segments: Array[Dictionary] = []
	for trace: RiverTrace in c.rivers:
		var profile := WaterField.profile(trace,c.region)
		var marked: Dictionary = {}
		for descent: Dictionary in profile.descents:
			for i in range(descent.lo,descent.hi): marked[i]=true
			for i in descent.pos.size()-1:
				segments.append({"source":str(trace.source_cell),"dense":true,"station":descent.lo,"a":descent.pos[i],"b":descent.pos[i+1],"wa":descent.w[i],"wb":descent.w[i+1],"la":descent.lvl[i],"lb":descent.lvl[i+1]})
		for i in trace.points.size()-1:
			if marked.has(i): continue
			segments.append({"source":str(trace.source_cell),"dense":false,"station":i,"a":trace.points[i],"b":trace.points[i+1],"wa":trace.widths[i],"wb":trace.widths[i+1],"la":profile.levels[i],"lb":profile.levels[i+1]})
	var rows: Array[Dictionary] = []
	var samples: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-19-manual/113-hillside-stable-terrain/supply-P10.json"))[1].samples
	for i in range(166,200):
		var sample: Dictionary = samples[i]
		var p := Vector2(sample.x,sample.z)
		var claims: Array[Dictionary] = []
		for segment: Dictionary in segments:
			var ab: Vector2 = segment.b-segment.a
			var t := clampf((p-segment.a).dot(ab)/maxf(ab.length_squared(),.000001),0,1)
			var margin := p.distance_to(segment.a+ab*t)-lerpf(segment.wa,segment.wb,t)
			if margin>0: continue
			claims.append({"source":segment.source,"station":segment.station,"margin":margin,"level":lerpf(segment.la,segment.lb,t),"dense":segment.dense})
		claims.sort_custom(func(a,b):return a.margin<b.margin)
		rows.append({"index":i,"point":[p.x,p.y],"mesh":sample.water,"field":field.level_at(p),"claimants":claims.slice(0,8)})
	FileAccess.open(OUT+"segments.bin",FileAccess.WRITE).store_var(segments)
	FileAccess.open(OUT+"samples.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	var source := WaterField._source_fill(c,c.region)
	var lattice: Array[Dictionary] = []
	for z in range(-654,-593,6):
		for x in range(-1146,-1067,6):
			var p := Vector2(x,z)
			var ij: Vector2i = Vector2i(((p-c.fill_base)/WaterField.FILL_STEP).round())
			var index := ij.y*(WaterField.FILL_M+1)+ij.x
			var sij: Vector2i = Vector2i(((p-source.base)/WaterField.FILL_STEP).round())
			var source_index: int = sij.y*source.size+sij.x
			lattice.append({"point":[x,z],"level":field.level_at(p),"coarse":c.fill.levels[index],"river":source.rivers[source_index]})
	FileAccess.open(OUT+"diagnosis.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":rows,"lattice":lattice},"  ").replace("-inf","null").replace("inf","null").replace("nan","null"))
	FileAccess.open(OUT+"segments.bin",FileAccess.WRITE).store_var(segments)
	print("HILLSIDE_SURFACE_DIAGNOSED ",rows.size()," samples ",segments.size()," segments")
	water._study=null
	quit()

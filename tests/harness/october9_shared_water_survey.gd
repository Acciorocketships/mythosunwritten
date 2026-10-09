extends SceneTree
## Production fills across photographed and unrelated sites. The excavation
## statistic is diagnostic: water above uncarved ground can be a valid lake.
func _init() -> void:
	WaterField.SOURCE_SUPPORT = not "--no-source-support" in OS.get_cmdline_user_args()
	var report_path := "/tmp/oct9-supported-water-survey.json" if WaterField.SOURCE_SUPPORT else "/tmp/oct9-shared-water-survey.json"
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.SHARED_PROFILE
	preload("res://scripts/native/NativeGridKernels.gd").setup()
	preload("res://scripts/native/NativeTileKernel.gd").setup()
	preload("res://scripts/native/NativeWaterFill.gd").setup()
	var catalog := EnvironmentCatalog.load_default()
	var program := DressingCompiler.compile(load("res://terrain/dressing/index.tres"), catalog)
	var results: Array = []
	var all_failures: Array = []
	for seed_value: int in [2697992464, 99]:
		var water := TerrainWorldTuning.make_water(seed_value)
		var plan := TerrainWorldTuning.make_heightfield(seed_value, water)
		var fields := WorldFieldBlockCache.new(plan, water, program.query_margin, program.shore_distance_limit, 16)
		var natural_plan := HeightfieldPlan.new(plan.world_seed, plan.height_amplitude, plan.max_storeys, plan.aggregation, plan.max_step)
		natural_plan.set_raw_height_override(plan.uncarved_height)
		for chunk: Vector2i in [Vector2i(1,5), Vector2i(2,5), Vector2i(-1,5), Vector2i(0,-2)]:
			var began := Time.get_ticks_msec()
			print("WATER_SURVEY_BEGIN seed=", seed_value, " chunk=", chunk)
			var ctx := fields.water(chunk)
			var core := Rect2(Vector2(chunk) * 192.0, Vector2.ONE * 192.0)
			var samples := 0; var dry := 0; var shallow := 0; var minimum := INF
			for trace: RiverTrace in ctx._ctx.rivers:
				for i in range(1, trace.points.size()):
					var a := trace.points[i-1]; var b := trace.points[i]
					var steps := ceili(a.distance_to(b))
					for j in steps:
						var p := a.lerp(b, float(j) / steps)
						if not core.has_point(p): continue
						var ground := TerrainTileField.surface_y(ctx._region, p.x, p.y)
						var level := ctx.level_at(p)
						samples += 1
						if not is_finite(level): dry += 1
						elif level - ground <= WaterField.EPS: shallow += 1
						else:
							minimum = minf(minimum, level - ground)
							continue
						all_failures.append({"seed":seed_value,"chunk":str(chunk),"source":str(trace.source_cell),"station":i,"x":p.x,"z":p.y,"ground":ground,"water":level if is_finite(level) else null})
			var natural := natural_plan.compute_rect_region(Rect2i(chunk * 16 - Vector2i(2,2), Vector2i(21,21)))
			var wet := 0; var above_original := 0
			for z in 64:
				for x in 64:
					var p := core.position + (Vector2(x,z) + Vector2.ONE * .5) * 3.0
					var level := ctx.level_at(p)
					if not is_finite(level): continue
					wet += 1
					if level > TerrainTileField.surface_y(natural,p.x,p.y) + WaterField.EPS: above_original += 1
			var row := {"seed":seed_value,"chunk":str(chunk),"samples":samples,"dry":dry,"shallow":shallow,"min_depth":minimum if is_finite(minimum) else null,"wet_grid":wet,"above_original_grid":above_original,"ms":Time.get_ticks_msec()-began}
			results.append(row)
			print("WATER_SURVEY ", JSON.stringify(row))
			FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"results":results,"failures":all_failures},"  "))
	quit(0 if all_failures.is_empty() else 1)

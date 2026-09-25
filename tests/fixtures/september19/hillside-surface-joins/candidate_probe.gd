extends SceneTree
const FIELD = preload("res://tests/fixtures/september19/hillside-surface-joins/candidate_field.gd")
const OUT := "res://docs/qa/2026-09-19-manual/114-hillside-surface-joins/"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var water := preload("res://tests/fixtures/september19/hillside-native-reaches/long_reach_plan.gd").new(2697992464,128,32)
	var geology := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464,geology)
	var fields := WorldFieldBlockCache.new(plan,water,26,0,64)
	var region := fields.region(Vector2i(-6,-4))
	FIELD.profile_source_cost=true
	var c: Dictionary = FIELD.ctx(water,Vector2i(-6,-4),region)
	assert(water.rejected_routes.is_empty())
	var rows: Array[Dictionary] = []
	var samples: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-19-manual/113-hillside-stable-terrain/supply-P10.json"))[1].samples
	for i in range(166,200):
		var sample: Dictionary = samples[i]
		var p := Vector2(sample.x,sample.z)
		rows.append({"index":i,"point":[p.x,p.y],"field":FIELD.level_at(c,p),"ground":TerrainSurfaceField.surface_y(region,p.x,p.y)})
	FileAccess.open(OUT+"candidate-samples.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("CANDIDATE_PROFILE_SAMPLES ",rows.size())
	water._study=null
	quit()

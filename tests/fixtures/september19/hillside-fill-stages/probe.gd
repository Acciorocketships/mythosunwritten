extends SceneTree
const FIELD = preload("res://tests/fixtures/september19/hillside-fill-stages/observed_field.gd")
const OUT := "res://docs/qa/2026-09-19-manual/115-hillside-fill-stages/"
var samples: Array
func _initialize() -> void: _run.call_deferred()
func record(stage: String, data: Dictionary) -> void:
	FileAccess.open(OUT+stage+".bin",FileAccess.WRITE).store_var(data)
	var rows: Array[Dictionary] = []
	var c := {"fill_base":data.base,"fill_size":data.size,"fill":{"levels":data.levels},"dry_ground":PackedFloat64Array(Array(data.ground))}
	for i in range(166,200):
		var sample: Dictionary = samples[i]
		var p := Vector2(sample.x,sample.z)
		var level: float = FIELD._fill_bilinear_coarse(c,p,false)
		rows.append({"index":i,"point":[p.x,p.y],"level":level if is_finite(level) else null})
	FileAccess.open(OUT+stage+".json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("RECORDED_STAGE ",stage)
func _run() -> void:
	samples=JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-19-manual/113-hillside-stable-terrain/supply-P10.json"))[1].samples
	var water := preload("res://tests/fixtures/september19/hillside-native-reaches/long_reach_plan.gd").new(2697992464,128,32)
	var geology := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464,geology)
	var fields := WorldFieldBlockCache.new(plan,water,26,0,64)
	var region := fields.region(Vector2i(-6,-4))
	FIELD.profile_source_cost=true
	FIELD.stage_observer=record
	var c: Dictionary = FIELD.ctx(water,Vector2i(-6,-4),region)
	assert(water.rejected_routes.is_empty())
	var profiles: Array[Dictionary] = []
	var source: Dictionary = FIELD._source_fill(c,region)
	var contributors := water.bodies_in_rect(Rect2(source.base,Vector2(source.size-1,source.rows-1)*FIELD.FILL_STEP))
	for trace: RiverTrace in contributors.rivers:
		profiles.append({"source":trace.source_cell,"points":trace.points,"widths":trace.widths,"beds":trace.beds,"profile":FIELD.profile(trace,region)})
	FileAccess.open(OUT+"profiles.bin",FileAccess.WRITE).store_var(profiles)
	print("FILL_STAGES_COMPLETE ",profiles.size()," sources")
	FIELD.stage_observer=Callable()
	water._study=null
	quit()

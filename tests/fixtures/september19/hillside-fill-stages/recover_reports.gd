extends SceneTree
const FIELD = preload("res://tests/fixtures/september19/hillside-fill-stages/observed_field.gd")
const OUT := "res://docs/qa/2026-09-19-manual/115-hillside-fill-stages/"
var samples: Array
func _initialize() -> void: _run.call_deferred()
func record(stage: String, data: Dictionary) -> void:
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
	for stage in ["seed","relax","contain","smooth","grade","crest"]:
		var data: Dictionary = FileAccess.open(OUT+stage+".bin",FileAccess.READ).get_var()
		record(stage,data)
	quit()

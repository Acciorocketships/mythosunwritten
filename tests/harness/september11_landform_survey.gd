extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[args.find("--phase")+1]
	var seed_value := 2697992464
	var rows: Dictionary = {}
	for biome: StringName in Helper.BIOME_NAMES:
		rows[biome] = {"count":0,"min":INF,"max":0.0,"sum":0.0,"core":{},"core_weight":0.0}
	for z in range(-120,121):
		for x in range(-120,121):
			var p := Vector3(x*48,0,z*48)
			var weights := Helper.biome_weights5(p,seed_value)
			var biome := Helper.biome_at(p,seed_value)
			var h := HeightfieldPlan.height01(p,seed_value)*TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE
			var row: Dictionary = rows[biome]
			row.count += 1
			row.sum += h
			row.min = minf(row.min,h)
			row.max = maxf(row.max,h)
			if weights[biome] > row.core_weight:
				row.core_weight = weights[biome]
				row.core = {"x":p.x,"z":p.z,"height":h}
	for biome: StringName in rows: rows[biome].mean = rows[biome].sum/maxi(rows[biome].count,1)
	var out := "res://docs/qa/2026-09-11-manual/12-landforms/"+phase+"-survey.json"
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print(JSON.stringify(rows,"  "))
	quit()

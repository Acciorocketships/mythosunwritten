extends SceneTree

const REFERENCE := preload("res://tests/fixtures/september9_dictionary_region.gd")
func _init()->void: call_deferred("_run")
func _run()->void:
	var plan := TerrainWorldTuning.make_heightfield(2697992464)
	plan.set_raw_height_override(func(x:int,z:int)->float:
		return 4.0*float(posmod(x*17+z*31,9))+float(posmod(x-z,4)))
	var rows:Array=[]
	for pass_index in 4:
		for variant in ["production","dictionary"] if pass_index%2==0 else ["dictionary","production"]:
			var start := Time.get_ticks_usec()
			var result := plan.compute_region(12,-56,100) if variant=="production" else REFERENCE.compute_region(plan,12,-56,100)
			var row := {"pass":pass_index,"variant":variant,"ms":(Time.get_ticks_usec()-start)/1000.0,
				"hash":var_to_bytes([result._storeys,result._levels,result._carved]).hex_encode().sha256_text()}
			rows.append(row)
			print("REGION_COST ",JSON.stringify(row))
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()

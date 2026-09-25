extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var oracle := GDScript.new()
	oracle.source_code = FileAccess.get_file_as_string("res://docs/qa/2026-09-15-manual/02-streaming/LandformField-pre-owner-cache.gd.txt").replace("class_name LandformField\n","")
	assert(oracle.reload() == OK)
	var points: Array[Vector3] = []
	for i in 20000:
		points.append(Vector3(float(i%200)*6-1000,0,float(i/200)*6-1200))
	var results := []
	var expected := PackedFloat64Array()
	for round_index in 4:
		for candidate in [false,true] if round_index%2==0 else [true,false]:
			var output := PackedFloat64Array()
			var start := Time.get_ticks_usec()
			for point in points:
				output.append(LandformField.height01(point,2697992464) if candidate else oracle.height01(point,2697992464))
			var row := {"candidate":candidate,"ms":(Time.get_ticks_usec()-start)/1000.0,
				"hash":var_to_bytes(output).hex_encode().sha256_text()}
			if expected.is_empty(): expected=output
			assert(output==expected)
			results.append(row)
			print("LANDFORM_COST ",JSON.stringify(row))
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	quit()

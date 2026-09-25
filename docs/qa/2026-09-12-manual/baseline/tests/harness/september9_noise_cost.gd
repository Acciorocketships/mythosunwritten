extends SceneTree

func _init()->void:call_deferred("_run")
func _run()->void:
	var rows:Array=[]
	for pass_index in 3:
		var values:=PackedFloat64Array()
		var started:=Time.get_ticks_usec()
		for i in 30000:
			var p:=Vector3(float(i%300)*12.0-1800,0,float(i/300)*12.0-2300)
			values.append(HeightfieldPlan.height01(p,2697992464,true))
			values.append(HeightfieldPlan.height01(p+Vector3(6,0,0),2697992464,false))
		rows.append({"pass":pass_index,"ms":(Time.get_ticks_usec()-started)/1000.0,
			"hash":values.to_byte_array().hex_encode().sha256_text()})
		print("NOISE_COST ",JSON.stringify(rows[-1]))
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()

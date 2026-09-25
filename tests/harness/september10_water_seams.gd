extends SceneTree
func _init()->void:_run.call_deferred()
func _run()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(plan,water,0,0,64)
	var out:=[]
	for pair in [[Vector2i(3,-10),Vector2i(3,-9)],[Vector2i(3,-10),Vector2i(4,-10)]]:
		var left:=fields.water(pair[0]);var right:=fields.water(pair[1])
		var worst:=0.0;var count:=0
		var samples:=[]
		for k in range(0,385):
			var p:=Vector2(576+k*.5,-1728) if pair[0].x==pair[1].x else Vector2(768,-1920+k*.5)
			var a:=WaterField.level_at(left.raw_context(),p);var b:=WaterField.level_at(right.raw_context(),p)
			if a!=b:count+=1
			if is_finite(a) and is_finite(b):worst=maxf(worst,absf(a-b))
			if (p.x>650 and p.x<710) or (is_finite(a) and is_finite(b) and absf(a-b)>.001):samples.append({"point":str(p),"a":str(a),"b":str(b)})
		out.append({"chunks":str(pair),"worst":worst,"different":count,"samples":samples})
		print("WATER_SEAM ",pair," worst=",worst," different=",count)
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(out,"  "))
	quit()

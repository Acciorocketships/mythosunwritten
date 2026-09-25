extends SceneTree
func _init()->void:_run.call_deferred()
func _run()->void:
	var fields:=preload("res://tests/fixtures/September10WaterFields.gd").get_fields()
	var ctx:=fields.water(Vector2i(3,-10)).raw_context()
	var crossings:=[];var worst:={"rise":0.0};var count:=0
	for axis in 2:
		for row in 61:
			var previous:Dictionary={}
			for column in 601:
				var p:=Vector2(684,-1740)+ (Vector2(column*.01,row*.1) if axis==0 else Vector2(row*.1,column*.01))
				var ground:=TerrainSurfaceField.surface_y(ctx.region,p.x,p.y)
				var level:=WaterField.level_at(ctx,p)
				var wet:=is_finite(level) and level>ground+WaterField.EPS
				if not previous.is_empty() and absf(previous.ground-ground)<.001:
					if wet!=previous.wet:
						var depth:float=level-ground if wet else previous.level-previous.ground
						crossings.append({"p":str(p),"depth":depth,"axis":axis})
					if wet and previous.wet:
						var rise:float=absf(level-previous.level)
						if rise>worst.rise:worst={"p":str(p),"rise":rise,"axis":axis,"ground":ground}
				previous={"level":level,"ground":ground,"wet":wet};count+=1
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify({"samples":count,"crossings":crossings,"worst_flat_step":worst},"  "))
	print("SHORE_SCAN ",count," ",worst)
	quit()

extends SceneTree
func _init()->void:
	_run.call_deferred()
func _run()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(plan,water,0,0,64)
	var result:=[]
	for chunk:Vector2i in [Vector2i(3,-10),Vector2i(3,-9),Vector2i(4,-10)]:
		var field:=fields.water(chunk)
		var ctx:=field.raw_context()
		var curves:=WaterContour.curves(ctx,Rect2(Vector2(chunk)*192,Vector2.ONE*192))
		for curve:Dictionary in curves:
			var contacts:=WaterSkin._wall_contacts({"region":ctx.region},curve)
			var reaches:=WaterSkin._wet_shelf_reaches({"ctx":ctx,"region":ctx.region},curve)
			for i in curve.pts.size():
				var p:Vector2=curve.pts[i]
				if p.y < -1890 or p.y > -1680 or p.x<600 or p.x>960:continue
				var n:Vector2=curve.normals[i]
				var level:float=curve.levels[i]
				var outer:=p+n*WaterSkin.RIM_ROW5_REACH
				var ground:=TerrainTileField.surface_y(ctx.region,p.x,p.y)
				var outer_ground:=TerrainTileField.surface_y(ctx.region,outer.x,outer.y)
				result.append({"point":[p.x,p.y],"normal":[n.x,n.y],"level":level,"ground":ground,"outer_ground":outer_ground,"wall":int(contacts.flags[i]),"outer_level":str(WaterField.level_at(ctx,outer)),"wet_reach":reaches[i],"shelf_field":str(WaterField.level_at(ctx,p+n*reaches[i])),"open_gap":level-WaterSkin.RIM_ROW5_DROP-outer_ground})
		print("WATER_RIM_PROBE ",chunk)
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	quit()

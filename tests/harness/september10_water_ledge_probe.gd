extends SceneTree
func _init()->void:_run.call_deferred()
func _run()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(plan,water,0,0,64)
	var ctx:=fields.water(Vector2i(3,-10)).raw_context()
	var fill:=WaterField._source_fill(ctx,ctx.region)
	var sub_n:int=(int(fill.size)-1)*2+1
	var rows:=[]
	for z in range(-1746,-1724,3):
		for x in range(678,700,3):
			var p:=Vector2(x,z);var sub:=Vector2i(((p-fill.base)/3).round());var idx:int=sub.y*sub_n+sub.x
			rows.append({"p":str(p),"ground":TerrainTileField.surface_y(ctx.region,p.x,p.y),"level":str(WaterField.level_at(ctx,p)),"coarse":str(WaterField._fill_bilinear_coarse(ctx,p)),"sub":str(fill.sub_levels[idx]),"sub_ground":str(fill.sub_ground[idx])})
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(rows,"  "));quit()

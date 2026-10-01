extends SceneTree
func _init()->void:_run.call_deferred()
func _run()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),water,26,0,64)
	var points:=[Vector2(1106.373,35.625),Vector2(1103.373,35.625),Vector2(1107.873,35.625)]
	for p:Vector2 in points:
		var ctx:=fields.water_at(p).raw_context()
		var origin:Vector2=ctx.fill_base+((p-ctx.fill_base)/6.0).floor()*6.0
		var rows:=[]
		var sub_n:=WaterField.FILL_SUB_M+1
		for z in 3:
			for x in 3:
				var q:=origin+Vector2(x,z)*3.0
				var ij:Vector2i=Vector2i(((q-ctx.fill_base)/3.0).round())
				var sub:float=ctx.fill.sub_levels[ij.y*sub_n+ij.x]
				rows.append({"point":str(q),"ground":TerrainTileField.surface_y(ctx.region,q.x,q.y),"head":str(WaterField._fill_untapered_level(ctx,q)),"coarse":str(WaterField._fill_bilinear_coarse(ctx,q)),"unbounded":str(WaterField._fill_bilinear_coarse(ctx,q,false)),"sub":str(sub),"final":str(WaterField.level_at(ctx,q))})
		print("FIELD ",JSON.stringify({"point":str(p),"coarse":WaterField._fill_bilinear_coarse(ctx,p),"unbounded":WaterField._fill_bilinear_coarse(ctx,p,false),"head":WaterField._fill_untapered_level(ctx,p),"final":WaterField.level_at(ctx,p),"grid":rows}))
	quit()

extends SceneTree
func _init()->void:_run.call_deferred()
func _run()->void:
	var water:=preload("res://tests/fixtures/ReportedWaterPlan.gd").new(2697992464)
	var plan:=water.make_heightfield();var region:=plan.compute_region(4,-44,8)
	var ctx:=WaterField.ctx(water,Vector2i(0,-6),region)
	var rows:=[]
	for trace:RiverTrace in ctx.rivers:
		if trace.source_cell!=Vector2i(0,-2):continue
		var profile:=WaterField.profile(trace,region)
		var descent:Dictionary=profile.descents[0]
		for i in descent.pos.size():
			var p:Vector2=descent.pos[i];rows.append({"p":str(p),"target":descent.lvl[i],"level":WaterField.level_at(ctx,p),"ground":TerrainSurfaceField.surface_y(region,p.x,p.y)})
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(rows,"  "));quit()

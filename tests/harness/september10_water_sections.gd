extends SceneTree
func _init()->void:
	_run.call_deferred()
func _run()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(plan,water,0,0,64)
	var sections:=[]
	for spec in [[Vector2(831,-1809),Vector2(0,1)],[Vector2(879,-1809),Vector2(0,1)],[Vector2(678,-1722),Vector2(1,0)],[Vector2(825,-1770),Vector2(0,1)]]:
		var point:Vector2=spec[0]
		var ctx:=fields.water(Vector2i((point/192.0).floor())).raw_context()
		var source:=WaterField._source_fill(ctx,ctx.region)
		var result:Dictionary={"point":str(point),"samples":[],"rivers":[]}
		for k in range(-16,17):
			var p:Vector2=point+spec[1]*k*.5
			var q:=Vector2i(((p-source.base)/6.0).round())
			var idx:int=q.y*int(source.size)+q.x
			result.samples.append({"p":str(p),"ground":TerrainTileField.surface_y(ctx.region,p.x,p.y),"level":str(WaterField.level_at(ctx,p)),"coarse":str(WaterField._fill_bilinear_coarse(ctx,p)),"untapered":str(WaterField._fill_untapered_level(ctx,p)),"channel":str(WaterField._channel_membership_level(ctx,p)),"nearest_lattice":str(source.base+Vector2(q)*6),"anchor":str(source.rivers[idx]),"source_level":str(source.levels[idx])})
		for trace:RiverTrace in ctx.rivers:
			var profile:=WaterField.profile(trace,ctx.region)
			var near:=[]
			for i in range(trace.points.size()-1):
				var a:=trace.points[i];var b:=trace.points[i+1]
				var t:=clampf((point-a).dot(b-a)/a.distance_squared_to(b),0,1)
				var d:=point.distance_to(a.lerp(b,t))
				if d<100:near.append({"i":i,"a":str(a),"b":str(b),"distance":d,"bed":trace.beds[i],"width":trace.widths[i],"head":profile.levels[i],"head_next":profile.levels[i+1],"sampled":WaterField._sample_level(trace,i,point,ctx.region)})
			result.rivers.append({"source":str(trace.source_cell),"segments":near})
		sections.append(result)
		print("WATER_SECTION ",point)
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(sections,"  "))
	quit()

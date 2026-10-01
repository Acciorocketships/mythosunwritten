extends SceneTree

## Production field census around the three reproduced photographs. Rows carry
## final terrain, natural terrain and water separately; no renderer inference.
func _init()->void:
	_run.call_deferred()

func _run()->void:
	var output:=OS.get_cmdline_user_args()[0]
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var natural:=TerrainWorldTuning.make_heightfield(2697992464,null)
	var program:=FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields:=WorldFieldBlockCache.new(plan,water,program.query_margin,program.shore_distance_limit,program.field_cache_cap)
	var features:=WorldFeaturePlan.new(2697992464,water,fields,program,SettlementPlan.new(2697992464,water))
	var regions:Dictionary={}
	var natural_regions:Dictionary={}
	var rows:Array=[]
	var started:=Time.get_ticks_msec()
	for spot:Array in [["05",Vector2(82,-1510)],["07",Vector2(132.3,-1737)],["08",Vector2(169.9,-1792.5)]]:
		var base:Vector2=(spot[1]/3.0).floor()*3.0-Vector2.ONE*60.0
		var samples:Array=[]
		for z in 41:
			for x in 41:
				var p:=base+Vector2(x,z)*3.0
				var chunk:=Vector2i((p/192.0).floor())
				if not regions.has(chunk):
					regions[chunk]=features.context_for(chunk).graded_region(fields.region(chunk))
					natural_regions[chunk]=natural.compute_region(chunk.x*8+4,chunk.y*8+4,8)
				var ctx:=fields.water(chunk)
				var level:=ctx.level_at(p)
				var raw:=WaterField.level_at(ctx._ctx,p)
				samples.append([TerrainTileField.surface_y(regions[chunk],p.x,p.y),
					TerrainTileField.surface_y(natural_regions[chunk],p.x,p.y),
					level if is_finite(level) else null,raw if is_finite(raw) else null])
		var bodies:=water.bodies_in_rect(Rect2(base,Vector2.ONE*120.0))
		var sources:Array=[]
		for trace:RiverTrace in bodies.rivers:
			var points:Array=[]
			for i in trace.points.size():
				if Rect2(base,Vector2.ONE*120.0).grow(72).has_point(trace.points[i]):
					points.append([trace.points[i].x,trace.points[i].y,trace.beds[i],trace.widths[i]])
			sources.append({"source":str(trace.source_cell),"points":points})
		rows.append({"photo":spot[0],"base":[base.x,base.y],"step":3,"size":41,
			"columns":["final_ground","natural_ground","wet_level","raw_level"],"samples":samples,"sources":sources})
		FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"sites":rows,"elapsed_ms":Time.get_ticks_msec()-started},"  "))
		print("WATER_PHOTO_PROBE ",spot[0]," ms=",Time.get_ticks_msec()-started)
	quit()

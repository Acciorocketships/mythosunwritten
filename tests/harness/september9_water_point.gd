extends SceneTree

func _init()->void:
	_run.call_deferred()

func _run()->void:
	var point:=Vector2(48,-1569)
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	if OS.get_cmdline_user_args().has("--historical") or OS.get_cmdline_user_args().has("--junction"):
		point=Vector2(-402.0981,-489.6676)
		water=preload("res://tests/fixtures/ReportedWaterPlan.gd").new(2697992464)
		plan=water.make_heightfield()
	if OS.get_cmdline_user_args().has("--junction"): point=Vector2(42,-1080)
	var fields:=WorldFieldBlockCache.new(plan,water,0,0,64)
	var chunk:=Vector2i((point/192.0).floor())
	var ctx:=fields.water(chunk)._ctx
	var result:Dictionary={"point":str(point),"level":str(WaterField.level_at(ctx,point)),"neighbours":[],"traces":[]}
	result["ground"]=TerrainTileField.surface_y(ctx.region,point.x,point.y)
	result["coarse"]=str(WaterField._fill_bilinear_coarse(ctx,point))
	result["untapered"]=str(WaterField._fill_untapered_level(ctx,point))
	var source:=WaterField._source_fill(ctx,ctx.region)
	result["domain"]={"base":str(source.base),"size":source.size,"rows":source.get("rows",source.size)}
	if OS.get_cmdline_user_args().has("--historical"):
		result["escape_witness"]=_escape(plan,source,point,3.0)
	for z in range(-2,3):
		for x in range(-2,3):
			var p:Vector2=(point/6.0).floor()*6.0+Vector2(x*6,z*6)
			var cell:=Vector2i(((p-source.base)/6.0).round())
			var index:int=cell.y*int(source.size)+cell.x
			result.neighbours.append({"p":str(p),"ground":TerrainTileField.surface_y(ctx.region,p.x,p.y),
				"source":str(source.levels[index]),"river":str(source.rivers[index]),"final":str(WaterField.level_at(ctx,p))})
	if OS.get_cmdline_user_args().has("--junction"):
		var width:int=source.size
		var rows:int=source.get("rows",width)
		var centre:Vector2=source.base+Vector2(width-1,rows-1)*3.0
		var owned=plan.compute_region(roundi(centre.x/24.0),roundi(centre.y/24.0),ceili(float(maxi(width,rows)-1)*3.0/24.0)+2)
		var natural:=HeightfieldPlan.new(2697992464,water.amplitude,water.max_storeys,"mean",3)
		natural.set_raw_height_override(func(x:int,z:int)->float:return water.noise_h(Vector2(x,z)*24))
		var natural_region:=natural.compute_region(2,-45,12)
		result["cross_sections"]=[]
		for z:float in [-1080.0,-1070.0]:
			for x in range(18,85):
				var p:=Vector2(x,z)
				result.cross_sections.append({"p":str(p),"ground":TerrainTileField.surface_y(ctx.region,x,z),"owned_ground":TerrainTileField.surface_y(owned,x,z),"natural":TerrainTileField.surface_y(natural_region,x,z),"level":str(WaterField.level_at(ctx,p)),"channel":str(WaterField._channel_membership_level(ctx,p)),"coarse":str(WaterField._fill_bilinear_coarse(ctx,p)),"wet":WaterField.wet(ctx,ctx.region,p)})
	for trace:RiverTrace in ctx.rivers:
		var near:Array=[]
		var profile:=WaterField.profile(trace,ctx.region)
		for i in range(trace.points.size()-1):
			var a:=trace.points[i]
			var b:=trace.points[i+1]
			var t:=clampf((point-a).dot(b-a)/a.distance_squared_to(b),0,1)
			var p:=a.lerp(b,t)
			if p.distance_to(point)<100:
				near.append({"a":str(a),"b":str(b),"distance":p.distance_to(point),"bed":trace.beds[i],"level":profile.levels[i],"width":trace.widths[i]})
		result.traces.append({"source":str(trace.source_cell),"near":near})
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	quit()

func _escape(plan,source:Dictionary,point:Vector2,head:float)->Dictionary:
	var side:int=source.size
	var center:Vector2=source.base+Vector2.ONE*(side-1)*3.0
	var region=plan.compute_region(roundi(center.x/24.0),roundi(center.y/24.0),ceili((side-1)*3.0/24.0)+2)
	var cell:=Vector2i(((point-source.base)/6.0).round())
	var start:int=cell.y*side+cell.x
	var parent:Dictionary={start:-1}
	var queue:Array[int]=[start]
	var cursor:=0
	while cursor<queue.size():
		var index:int=queue[cursor];cursor+=1
		var x:=index%side
		var z:=int(index/side)
		var river:float=source.rivers[index]
		var reason:=""
		if index!=start and is_finite(river) and river<head-0.1:reason="lower flowing river"
		elif x==0 or z==0 or x==side-1 or z==side-1:reason="open source-domain boundary"
		if not reason.is_empty():
			var path:Array=[]
			var max_ground:=-INF
			while index!=-1:
				var p:Vector2=source.base+Vector2(index%side,int(index/side))*6.0
				var g:=TerrainTileField.surface_y(region,p.x,p.y)
				max_ground=maxf(max_ground,g)
				path.push_front([p.x,p.y,g])
				index=parent[index]
			return {"head":head,"max_ground":max_ground,"reason":reason,"river":str(river),"path":path}
		for direction:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var nx:=x+direction.x
			var nz:=z+direction.y
			if nx<0 or nz<0 or nx>=side or nz>=side:continue
			var next:int=nz*side+nx
			if parent.has(next):continue
			var p:Vector2=source.base+Vector2(nx,nz)*6.0
			if TerrainTileField.surface_y(region,p.x,p.y)>=head-WaterField.EPS:continue
			parent[next]=index
			queue.append(next)
	return {"head":head,"reason":"no sampled escape","visited":parent.size()}

extends RefCounted
var _profiles_local:Dictionary={}
## Compare detached fine-grid repairs over the known shared-profile dry reach.
func run(review:Node)->void:
	var box:Array=[review._streamer._fields.water(Vector2i(-1,5)),review._output_dir]
	var job:=WorkerThreadPool.add_task(_trial.bind(box))
	while not WorkerThreadPool.is_task_completed(job):
		await review.get_tree().create_timer(.2).timeout
	WorkerThreadPool.wait_for_task_completion(job)

func _trial(box:Array)->void:
	var water:WaterFieldContext=box[0]
	var output:String=box[1]
	var c:Dictionary=water._ctx
	const B=preload("res://scripts/terrain/water/WaterBankBound.gd")
	var focus:=Rect2(-54,1128,42,42)
	var env=B._bank(water._region,focus,water._region.plan.world_seed)
	var bound:=B.node_bounds(env,focus,c.fill_base,3.0)
	var side:=WaterField.FILL_SUB_M+1
	var plan:HeightfieldPlan=water._region.plan
	var natural_plan:=HeightfieldPlan.new(plan.world_seed,plan.height_amplitude,plan.max_storeys,plan.aggregation,plan.max_step)
	natural_plan.set_raw_height_override(plan.uncarved_height)
	var first:=Vector2i((focus.position/12.0).floor())-Vector2i.ONE*3
	var last:=Vector2i((focus.end/12.0).ceil())+Vector2i.ONE*3
	var natural:=natural_plan.compute_rect_region(Rect2i(first,last-first+Vector2i.ONE))
	var variants:Array=[]
	for floor_depth in [.4,.8]:
		var source:=FileAccess.get_file_as_string("res://scripts/terrain/water/WaterField.gd")
		source=source.replace("class_name WaterField", "").replace("const DESCENT_CLAMP := 0.80", "const DESCENT_CLAMP := %s"%floor_depth)
		var kernel:=GDScript.new();kernel.source_code=source
		assert(kernel.reload()==OK)
		_profiles_local.clear()
		for tr:RiverTrace in c.rivers:
			_profiles_local[tr.get_instance_id()]=kernel._profile_compute(tr,water._region,true,false) if tr.source_cell==Vector2i(-1,1) else WaterField.profile(tr,water._region)
		var clearance:float=-1.0
		var trial:=c.duplicate();trial.fill=c.fill.duplicate()
		var levels:PackedFloat32Array=c.fill.sub_levels.duplicate()
		var ground:PackedFloat32Array=c.fill.sub_ground.duplicate()
		var changed:=0;var max_raise:=0.0
		for z in bound.size.y:
			for x in bound.size.x:
				var node:Vector2i=bound.first+Vector2i(x,z)
				if node.x<0 or node.y<0 or node.x>=side or node.y>=side:continue
				var p:Vector2=c.fill_base+Vector2(node)*3.0
				var g:=TerrainTileField.surface_y(water._region,p.x,p.y)
				var offer:=_offer(c,p)
				var idx:=node.y*side+node.x
				ground[idx]=g
				if offer<=g+WaterField.EPS:continue
				var target:=offer
				if clearance>=0:target=maxf(target,bound.values[z*bound.size.x+x]+clearance)
				max_raise=maxf(max_raise,target-offer)
				if target>WaterField.level_at(c,p):
					levels[idx]=maxf(levels[idx],target);changed+=1
		trial.fill.sub_levels=levels;trial.fill.sub_ground=ground
		var rows:Array=[];var dry:=0;var minimum:=INF
		for i in 57:
			var x:float=-44.0+i*.25
			var p:=Vector2(x,1143.4038+(x+40.91079)*.5744)
			var g:=TerrainTileField.surface_y(water._region,p.x,p.y)
			var depth:=WaterField.level_at(trial,p)-g
			minimum=minf(minimum,depth)
			if depth<=WaterField.EPS:dry+=1
			rows.append({"p":p,"depth":depth})
		var new_wet:=0;var wet_before:=0;var wet_after:=0;var spills:=0;var new_spills:=0
		for z in 85:
			for x in 85:
				var p:=focus.position+Vector2(x,z)*.5
				var g:=TerrainTileField.surface_y(water._region,p.x,p.y)
				var was:=WaterField.level_at(c,p)>g+WaterField.EPS
				var now:=WaterField.level_at(trial,p)>g+WaterField.EPS
				if was:wet_before+=1
				if now:wet_after+=1
				if now and not was:new_wet+=1
				var uncut:=TerrainTileField.surface_y(natural,p.x,p.y)
				if now and WaterField.level_at(trial,p)>uncut+WaterField.EPS:
					spills+=1
					if not was:new_spills+=1
		variants.append({"floor_depth":floor_depth,"changed":changed,"dry":dry,"min_depth":minimum,"max_above_offer":max_raise,"wet_before":wet_before,"wet_after":wet_after,"new_wet":new_wet,"spills":spills,"new_spills":new_spills,"samples":rows})
	FileAccess.open(output+"/river-depth-floor-trial.json",FileAccess.WRITE).store_string(JSON.stringify(variants,"  "))
	for v:Dictionary in variants:
		v.erase("samples");print("RIVER_DEPTH_TRIAL ",JSON.stringify(v))
	box.clear()

func _offer(c:Dictionary,p:Vector2)->float:
	var margin:=INF;var level:=-INF
	for trace:RiverTrace in c.rivers:
		var prof:Dictionary=_profiles_local.get(trace.get_instance_id(),{})
		if prof.is_empty():prof=WaterField.profile(trace,c.region)
		var spans:Array=prof.get("descents",[])
		var segments:Array=[];var covered:Dictionary={}
		for d:Dictionary in spans:
			for i in range(d.lo,d.hi):covered[i]=true
			for i in d.pos.size()-1:segments.append([d.pos[i],d.pos[i+1],d.w[i],d.w[i+1],d.lvl[i],d.lvl[i+1]])
		for i in trace.points.size()-1:
			if not covered.has(i):segments.append([trace.points[i],trace.points[i+1],trace.widths[i],trace.widths[i+1],prof.levels[i],prof.levels[i+1]])
		for s:Array in segments:
			var delta:Vector2=s[1]-s[0]
			var t:=clampf((p-s[0]).dot(delta)/maxf(delta.length_squared(),.0001),0,1)
			var m:=p.distance_to(s[0]+delta*t)-lerpf(s[2],s[3],t)
			if m<margin and m<=0:
				margin=m;level=lerpf(s[4],s[5],t)
	return level

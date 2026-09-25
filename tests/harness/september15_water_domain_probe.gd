extends SceneTree

# Diagnostic only: each pass reports whether a hydraulic calculation ends
# on unsupported wet ground. The pass limit does not certify a complete basin.
func _init() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464, water)
	var bodies := water.bodies_near(Vector2i(-4,-4), 8)
	var bounds := Rect2()
	var started := false
	for river: RiverTrace in bodies.rivers:
		bounds = bounds.merge(river.bounds()) if started else river.bounds()
		started = true
	for pond: PondStamp in bodies.ponds:
		var b := Rect2(pond.center-Vector2.ONE*pond.bound_radius(),Vector2.ONE*pond.bound_radius()*2)
		bounds = bounds.merge(b) if started else b
		started = true
	bounds = bounds.grow(maxf(WaterField.TILE*3,WaterPlan.W_MAX+WaterPlan.BANK_FEATHER))
	var reports := []
	for attempt in 8:
		var base := (bounds.position/6).floor()*6
		var shape := Vector2i(((bounds.end-base)/6).ceil())+Vector2i.ONE
		var first := Vector2i((base/24).floor())-Vector2i.ONE*2
		var last := Vector2i(((base+Vector2(shape-Vector2i.ONE)*6)/24).ceil())+Vector2i.ONE*2
		var region := plan.compute_rect_region(Rect2i(first,last-first+Vector2i.ONE))
		var c := water.bodies_in_rect(Rect2(base,Vector2(shape-Vector2i.ONE)*6))
		c.water = water
		var levels := PackedFloat32Array(); levels.resize(shape.x*shape.y); levels.fill(-INF)
		var anchors := levels.duplicate()
		var ground := WaterField._sample_ground_lattice(region,base,shape.x,6,shape.y)
		var queue := PriorityQueue.new()
		WaterField._seed_rivers(c,region,base,shape.x,levels,ground,anchors,queue)
		WaterField._seed_ponds(c,region,base,shape.x,levels,ground,queue)
		var seeds := {}
		for entry: Dictionary in queue.heap: seeds[int(entry.item[0])] = true
		WaterField._relax_fill(region,base,shape.x,levels,ground,anchors,queue)
		queue.free()
		var origin := Vector2i((-base/6).round())
		var oi := origin.y*shape.x+origin.x
		var spill := WaterField.SpillSearch.new(region,base,shape.x,levels,ground,anchors,6)
		print("DOMAIN_ORIGIN raw=",levels[oi]," ground=",ground[oi]," anchor=",anchors[oi]," spill=",spill.height_at(oi))
		spill.close()
		var natural_plan := HeightfieldPlan.new(plan.world_seed,plan.height_amplitude,plan.max_storeys,plan.aggregation,plan.max_step)
		natural_plan.set_raw_height_override(plan.uncarved_height)
		var natural := natural_plan.compute_rect_region(Rect2i(first,last-first+Vector2i.ONE))
		var candidates := levels.duplicate()
		for index in anchors.size():
			if is_finite(anchors[index]): candidates[index] = -INF
		var flow := WaterField._carved_flow_ceilings(c,region,base,shape.x,candidates)
		WaterField._cap_hydrostatic_fill(region,base,shape.x,levels,ground,anchors,6,null,natural,flow)
		var seen := {oi:true}
		var walk: Array[int] = []
		if is_finite(levels[oi]): walk.append(oi)
		var cursor := 0
		var seed_count := 0
		while cursor < walk.size():
			var index := walk[cursor]; cursor += 1
			if seeds.has(index): seed_count += 1
			var cell := Vector2i(index%shape.x,int(index/shape.x))
			for d: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var n := cell+d
				if n.x<0 or n.y<0 or n.x>=shape.x or n.y>=shape.y: continue
				var ni := n.y*shape.x+n.x
				if seen.has(ni) or not is_finite(levels[ni]): continue
				seen[ni]=true; walk.append(ni)
		print("DOMAIN_CONNECTED cap=",levels[oi]," points=",walk.size()," actual_seeds=",seed_count)
		var counts := [0,0,0,0]
		var heads := [-INF,-INF,-INF,-INF]
		for edge in 4:
			for k in (shape.y if edge<2 else shape.x):
				var index: int = k*shape.x+(0 if edge==0 else shape.x-1) if edge<2 else (0 if edge==2 else shape.y-1)*shape.x+k
				if is_finite(levels[index]) and not is_finite(anchors[index]):
					counts[edge]+=1
					heads[edge]=maxf(heads[edge],levels[index])
		var row := {"pass":attempt,"base":str(base),"shape":str(shape),"unowned_wet_edges":counts,"heads":str(heads)}
		reports.append(row)
		print("DOMAIN_PROBE ",JSON.stringify(row))
		if counts==[0,0,0,0]: break
		bounds=Rect2(base,Vector2(shape-Vector2i.ONE)*6).grow_individual(192 if counts[0]>0 else 0,192 if counts[2]>0 else 0,192 if counts[1]>0 else 0,192 if counts[3]>0 else 0)
	FileAccess.open("res://docs/qa/2026-09-15-manual/03-spawn-water/domain-probe.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"\t"))
	quit()

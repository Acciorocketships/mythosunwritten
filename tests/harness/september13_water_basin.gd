extends SceneTree

# Read-only drainage survey. The finite work cap is diagnostic only: a capped
# run is explicitly incomplete and cannot establish a production spill height.
func _init()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),water,26,0,64)
	var bakes:Dictionary={}
	var seen:Dictionary={Vector2i.ZERO:true}
	var queue:Array[Vector2i]=[Vector2i.ZERO]
	var cursor:=0
	var boundary:Dictionary={}
	var extent:=Rect2(Vector2.ZERO,Vector2.ZERO)
	while cursor<queue.size() and cursor<200000:
		var cell:=queue[cursor];cursor+=1
		for d:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:=cell+d
			if seen.has(next):continue
			seen[next]=true
			var p:=Vector2(next)*WaterField.FILL_STEP
			var coarse:=Vector2i(roundi(p.x/24),roundi(p.y/24))
			if not bakes.has(coarse):bakes[coarse]=TerrainTileField.bake_point(fields.region_at(p),Vector2i(coarse.x, coarse.y))
			var ground:=TerrainTileField.sample_baked(bakes[coarse],Vector2i(coarse.x, coarse.y),p.x,p.y)
			if ground<7.95:
				queue.append(next);extent=extent.expand(p)
			else:boundary[next]=ground
		if cursor%10000==0:print("BASIN_PROGRESS visited=",cursor," pending=",queue.size()-cursor," extent=",extent," regions=",fields.region_build_count)
	var result:={"complete":cursor==queue.size(),"visited":cursor,"wet_points":queue.size(),"rim_points":boundary.size(),"extent":str(extent),"region_builds":fields.region_build_count}
	print("BASIN_RESULT ",JSON.stringify(result))
	FileAccess.open("res://docs/qa/2026-09-13-manual/22-water/origin-basin.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit()

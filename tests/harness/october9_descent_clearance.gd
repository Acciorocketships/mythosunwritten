extends RefCounted
func run(review:Node)->void:
	var water:WaterFieldContext=review._streamer._fields.water(Vector2i(-1,5))
	var rows:Array=[]
	for tr:RiverTrace in water._ctx.rivers:
		if tr.source_cell!=Vector2i(-1,1):continue
		var prof:=WaterField.profile(tr,water._region)
		for d:Dictionary in prof.descents:
			for i in d.pos.size()-1:
				if d.pos[i].distance_to(Vector2(-39,1144))>30:continue
				for k in 9:
					var t:=float(k)/8
					var p:Vector2=d.pos[i].lerp(d.pos[i+1],t)
					var g:=TerrainTileField.surface_y(water._region,p.x,p.y)
					var level:=lerpf(d.lvl[i],d.lvl[i+1],t)
					rows.append({"p":p,"ground":g,"level":level,"clearance":level-g,"node":k==0,"coarse":WaterField._fill_bilinear_coarse(water._ctx,p)})
	FileAccess.open(review._output_dir+"/dense-clearance.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("DENSE_CLEARANCE ",rows.size())

extends RefCounted
## Detached fill experiment; does not replace the live world's water.
func run(review: Node) -> void:
	var water: WaterFieldContext = review._inputs[Vector2i(-1,5)].water
	var c: Dictionary = water._ctx.duplicate()
	c.fill = c.fill.duplicate()
	var levels: PackedFloat32Array = c.fill.sub_levels.duplicate()
	var ground: PackedFloat32Array = c.fill.sub_ground.duplicate()
	var side := WaterField.FILL_SUB_M + 1
	var first := Vector2i(((Vector2(-54,1128) - c.fill_base) / 3.0).floor())
	var last := first + Vector2i(14,14)
	var changed := 0
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var p: Vector2 = c.fill_base + Vector2(x,z)*3.0
			var g := TerrainTileField.surface_y(water._region,p.x,p.y)
			var offered := WaterField._channel_membership_level(c,p)
			ground[z*side+x] = g
			if offered > g + WaterField.EPS and offered > WaterField.level_at(water._ctx,p):
				levels[z*side+x] = maxf(levels[z*side+x], offered)
				changed += 1
	c.fill.sub_levels = levels; c.fill.sub_ground = ground
	var rows: Array = []; var dry := 0
	for i in 29:
		var x := -44.0 + i*0.5
		var p := Vector2(x,1143.4038+(x+40.91079)*0.5744)
		var g := TerrainTileField.surface_y(water._region,p.x,p.y)
		var level := WaterField.level_at(c,p)
		if level <= g+WaterField.EPS: dry+=1
		rows.append({"p":str(p),"ground":g,"before":str(water.level_at(p)),"after":str(level),"clearance":level-g})
	FileAccess.open(review._output_dir+"/shared-fine-trial.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("SHARED_FINE_TRIAL changed=",changed," samples=",rows.size()," dry=",dry)

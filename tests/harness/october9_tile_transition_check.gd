extends SceneTree

func _init() -> void:
	var kernel: Script = preload("res://tests/harness/october9_tile_transition_kernel.gd").make(1.0)
	if "--production" in OS.get_cmdline_user_args():
		kernel = preload("res://scripts/terrain/field/TerrainTileField.gd")
		TerrainTileField.cliff_end = TerrainTileField.CliffEnd.SHARED_PROFILE
	var bounds_error := 0.0; var edge_error := 0.0; var slope_error := 0.0; var monotone_error := 0.0
	var worst: Array = []
	var cases := 0
	for a in 9:
		for b in 9:
			for c in 9:
				for d in 9:
					var p := PackedFloat32Array([a*4,b*4,c*4,d*4,float(absi(a-b)>=2),float(absi(b-c)>=2),float(absi(d-c)>=2),float(absi(a-d)>=2)])
					var grid := PackedFloat64Array(); grid.resize(17*17)
					for z in 17:
						for x in 17:
							var u := x/16.0; var v := z/16.0
							var y: float = kernel.eval_params(p,u,v)
							grid[z*17+x] = y
							bounds_error = maxf(bounds_error,maxf(mini(mini(a,b),mini(c,d))*4-y,y-maxi(maxi(a,b),maxi(c,d))*4))
							if p[4]+p[5]+p[6]+p[7] == 0:
								slope_error = maxf(slope_error,absf(y-TerrainTileField.eval_params(p,u,v,Vector2i.ZERO,0,TerrainTileField.CliffEnd.E3)))
						for edge in 4:
							var heights: Vector2 = [Vector2(a,b),Vector2(b,c),Vector2(d,c),Vector2(a,d)][edge] * 4.0
							var t := z/16.0
							var shape := SlopeProfile.smootherstep(clampf(t,0,1)) if p[4+edge] > 0 else SlopeProfile.smootherstep(t)
							var at: Vector2 = [Vector2(t,0),Vector2(1,t),Vector2(t,1),Vector2(0,t)][edge]
							edge_error = maxf(edge_error,absf(kernel.eval_params(p,at.x,at.y)-lerpf(heights.x,heights.y,shape)))
					for z in 17:
						for x in 16:
							var delta := grid[z*17+x+1]-grid[z*17+x]
							var error := maxf(-delta,0) if a<=b and d<=c else (maxf(delta,0) if a>=b and d>=c else 0.0)
							if error>monotone_error:
								monotone_error=error; worst=[a,b,c,d,x,z]
					for z in 16:
						for x in 17:
							var delta := grid[(z+1)*17+x]-grid[z*17+x]
							var error := maxf(-delta,0) if a<=d and b<=c else (maxf(delta,0) if a>=d and b>=c else 0.0)
							if error>monotone_error:
								monotone_error=error; worst=[a,b,c,d,x,z]
					cases+=1
	var result := {"cases":cases,"bounds_error":bounds_error,"edge_error":edge_error,"plain_slope_error":slope_error,"monotone_error":monotone_error,"worst":worst}
	print("TILE_PROPERTIES ",JSON.stringify(result))
	FileAccess.open("/tmp/oct9-tile-properties.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	quit(1 if maxf(maxf(bounds_error,edge_error),maxf(slope_error,monotone_error)) > 1e-9 else 0)

extends SceneTree
const E=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
func _init()->void:
	preload("res://scripts/native/NativeGridKernels.gd").setup()
	preload("res://scripts/native/NativeTileKernel.gd").setup()
	preload("res://scripts/native/NativeWaterFill.gd").setup()
	var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/october8/surface-input.var.gz").decompress_dynamic(200000000,FileAccess.COMPRESSION_GZIP))
	var tiles:Dictionary={}
	var lowered:=0
	for idx in d.coarse.size():
		if is_finite(d.coarse[idx]) and d.before_reconcile[idx]>d.coarse[idx]+.05:
			var at:Vector2=d.base+Vector2(idx%d.side,idx/d.side)*WaterField.FILL_STEP
			tiles[Vector2i((at/96.0).floor())]=true
			lowered+=1
	print("LOWERED_TILES ",tiles.size()," nodes=",lowered)
	var region:=HeightfieldRegion.new(d.storeys,d.levels,d.carved)
	region.native_control_heights=d.native
	var ground:=func(p:Vector2)->float:return TerrainTileField.surface_y(region,p.x,p.y)
	var grid:=func(origin:Vector2,w:int,h:int)->PackedFloat64Array:
		var xs:=PackedFloat64Array();var zs:=PackedFloat64Array()
		for i in w:xs.append((origin+Vector2(i,0)*E.H).x)
		for k in h:zs.append((origin+Vector2(0,k)*E.H).y)
		return TerrainTileField.sample_grid(region,xs,zs)
	var points:=func(xs:PackedFloat64Array,zs:PackedFloat64Array)->PackedFloat64Array:return TerrainTileField.sample_grid(region,xs,zs)
	var clearance:=1.0 if "--clearance" in OS.get_cmdline_user_args() else 0.0
	# A flowing bed must exceed the existing 0.4 m film threshold;
	# reconciliation itself supplies another 0.1 m above this floor.
	var flow_depth:=E.WATER_SINK if "--flow-depth" in OS.get_cmdline_user_args() else 0.0
	var beds:PackedFloat32Array=d.ground.duplicate()
	var fine_side:int=(d.side-1)*2+1
	var fine_rows:int=(int(beds.size()/d.side)-1)*2+1
	var fine_beds:=PackedFloat32Array();fine_beds.resize(fine_side*fine_rows);fine_beds.fill(-INF)
	var selected:Dictionary={}
	for idx in beds.size():
		if not is_finite(d.coarse[idx]) or d.before_reconcile[idx]<=d.coarse[idx]+.05:continue
		var at:Vector2=d.base+Vector2(idx%d.side,idx/d.side)*WaterField.FILL_STEP
		if not "--all-bank-tiles" in OS.get_cmdline_user_args() and not Rect2(430,1060,110,140).has_point(at):continue
		var tile:=Vector2i((at/96.0).floor())
		if not selected.has(tile):selected[tile]=[]
		selected[tile].append(idx)
	var started:=Time.get_ticks_usec()
	var tile_count:=0
	for tile:Vector2i in selected:
		var indices:Array=selected[tile]
		var focus:=Rect2(d.base+Vector2(indices[0]%d.side,indices[0]/d.side)*WaterField.FILL_STEP,Vector2.ZERO)
		for idx:int in indices:focus=focus.expand(d.base+Vector2(idx%d.side,idx/d.side)*WaterField.FILL_STEP)
		var env=E._build(focus.grow(1),ground,Callable(),2697992464,Callable(),grid,points,false,0)
		var majorant:="--majorant" in OS.get_cmdline_user_args()
		var coarse_bound:Dictionary={}
		var fine_bound:Dictionary={}
		if majorant:
			coarse_bound=preload("res://scripts/terrain/water/WaterBankBound.gd").node_bounds(env,focus,d.base,6.0)
			fine_bound=preload("res://scripts/terrain/water/WaterBankBound.gd").node_bounds(env,focus,d.base,3.0)
		for idx:int in indices:
			var at:Vector2=d.base+Vector2(idx%d.side,idx/d.side)*WaterField.FILL_STEP
			var height:float=env.at(at)+clearance
			if majorant:
				var key:=Vector2i(idx%d.side,idx/d.side)-Vector2i(coarse_bound.first)
				height=coarse_bound.values[key.y*coarse_bound.size.x+key.x]+flow_depth
			beds[idx]=maxf(beds[idx],height)
		var first:=Vector2i(((focus.position-Vector2.ONE*3-d.base)/3.0).ceil())
		var last:=Vector2i(((focus.end+Vector2.ONE*3-d.base)/3.0).floor())
		for z in range(maxi(0,first.y),mini(fine_rows-1,last.y)+1):
			for x in range(maxi(0,first.x),mini(fine_side-1,last.x)+1):
				var height:float=env.at(d.base+Vector2(x,z)*3.0)+clearance
				if majorant:
					var key:=Vector2i(x,z)-Vector2i(fine_bound.first)
					height=fine_bound.values[key.y*fine_bound.size.x+key.x]+flow_depth
				fine_beds[z*fine_side+x]=height
		tile_count+=1
		if tile_count%25==0:print("BED_PROGRESS ",tile_count,"/",selected.size())
	print("BED_BUILD_TOTAL_MS ",(Time.get_ticks_usec()-started)/1000.0," tiles=",selected.size())
	var trial:PackedFloat32Array=d.before_reconcile.duplicate()
	WaterField._reconcile_connected_surface(trial,beds,d.side,WaterField.FILL_STEP)
	for z in range(1101,1162,6):
		var p:=Vector2(465,z)
		var cell:Vector2i=Vector2i(((p-d.base)/WaterField.FILL_STEP).round())
		var idx:int=cell.y*d.side+cell.x
		print("REPLAY ",p," kernel=",d.ground[idx]," sheet=",beds[idx]," before=",d.before_reconcile[idx]," after=",d.coarse[idx]," trial=",trial[idx])
	var refined:=WaterField._build_sub_lattice_rescue(region,d.base,trial,d.river,d.side,PackedFloat32Array(),{},fine_beds)
	var output:Dictionary={"base":d.base,"size":d.side,"rows":int(trial.size()/d.side),"levels":trial,"sub_levels":refined.levels,"sub_ground":refined.ground}
	FileAccess.open("/tmp/oct8-surface-trial.var.gz",FileAccess.WRITE).store_buffer(var_to_bytes(output).compress(FileAccess.COMPRESSION_GZIP))
	quit()

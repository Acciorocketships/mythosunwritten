extends RefCounted

## A bilinear majorant of a sampled bank:
## measure each water cell's largest interpolation deficit at the bank's
## own half-metre nodes and add that deficit to all four water corners.
## Taking the largest incident-cell requirement makes shared corners agree.
## No water is changed here; these are lower bounds for reconciliation.
static func node_bounds(env:RefCounted, focus:Rect2, base:Vector2, step:float, use_native:=true)->Dictionary:
	const PITCH:=0.5
	var first:=Vector2i(((focus.position-base)/step).floor())-Vector2i.ONE
	var last:=Vector2i(((focus.end-base)/step).ceil())+Vector2i.ONE
	var size:=last-first+Vector2i.ONE
	var original:=PackedFloat64Array();original.resize(size.x*size.y)
	for z in size.y:
		for x in size.x:original[z*size.x+x]=env.at(base+Vector2(first+Vector2i(x,z))*step)
	var xs:=PackedInt32Array();var zs:=PackedInt32Array()
	for x in size.x:xs.append(roundi(((base+Vector2(first+Vector2i(x,0))*step).x-env.origin.x)/PITCH))
	for z in size.y:zs.append(roundi(((base+Vector2(first+Vector2i(0,z))*step).y-env.origin.y)/PITCH))
	var native=load("res://scripts/native/NativeGridKernels.gd")
	var values:PackedFloat64Array
	if use_native and native.enabled:values=native.bank_bound(env.surface,env.w,env.h,original,size,xs,zs,roundi(step/PITCH))
	else:values=reference_bound(env.surface,env.w,env.h,original,size,xs,zs,roundi(step/PITCH))
	return {"first":first,"size":size,"values":values}

## Reference kernel; native parity calls it directly, without dispatch.
static func reference_bound(surface:PackedFloat64Array,w:int,h:int,original:PackedFloat64Array,
		size:Vector2i,xs:PackedInt32Array,zs:PackedInt32Array,intervals:int)->PackedFloat64Array:
	var bound:=original.duplicate()
	for z in size.y-1:
		for x in size.x-1:
			var idx:=z*size.x+x
			var a:=original[idx];var b:=original[idx+1]
			var c:=original[idx+size.x];var d:=original[idx+size.x+1]
			var deficit:=0.0
			for j in intervals+1:
				var row:=clampi(zs[z]+j,0,h-1)*w
				var t:=float(j)/intervals
				var left:=lerpf(a,c,t);var right:=lerpf(b,d,t)
				for i in intervals+1:
					var height:float=surface[row+clampi(xs[x]+i,0,w-1)]
					deficit=maxf(deficit,height-lerpf(left,right,float(i)/intervals))
			for at:int in [idx,idx+1,idx+size.x,idx+size.x+1]:bound[at]=maxf(bound[at],original[at]+deficit)
	return bound

## Build only where the original downhill pass would lower a wet node.
## The same smooth bank supports both hydraulic lattices. Dry-rock detail is
## omitted: the later wet bank suppresses that detail beneath the surface.
static func reconciliation_inputs(region:HeightfieldRegion, base:Vector2, columns:int,
		ground:PackedFloat32Array, offered:PackedFloat32Array,
		lowered:PackedFloat32Array, seed_value:int)->Dictionary:
	const E=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
	var selected:Dictionary={}
	for idx in ground.size():
		if not is_finite(lowered[idx]) or offered[idx]<=lowered[idx]+.05:continue
		var at:=base+Vector2(idx%columns,idx/columns)*6.0
		var tile:=Vector2i((at/96.0).floor())
		if not selected.has(tile):selected[tile]=[]
		selected[tile].append(idx)
	if selected.is_empty():return {}
	var beds:=ground.duplicate()
	var fine_side:=(columns-1)*2+1
	var fine_rows:=(int(ground.size()/columns)-1)*2+1
	var fine_beds:=PackedFloat32Array();fine_beds.resize(fine_side*fine_rows);fine_beds.fill(-INF)
	for tile:Vector2i in selected:
		var indices:Array=selected[tile]
		var focus:=Rect2(base+Vector2(indices[0]%columns,indices[0]/columns)*6.0,Vector2.ZERO)
		for idx:int in indices:focus=focus.expand(base+Vector2(idx%columns,idx/columns)*6.0)
		var bound:=tile_bounds(region,tile,seed_value)
		var coarse_bound:Dictionary=bound.coarse
		var fine_bound:Dictionary=bound.fine
		var coarse_offset:=Vector2i(((base-Vector2.ONE*3.0)/6.0).round())-Vector2i(coarse_bound.first)
		var fine_offset:=Vector2i(((base-Vector2.ONE*3.0)/3.0).round())-Vector2i(fine_bound.first)
		for idx:int in indices:
			var key:=Vector2i(idx%columns,idx/columns)+coarse_offset
			beds[idx]=maxf(beds[idx],coarse_bound.values[key.y*coarse_bound.size.x+key.x]+E.WATER_SINK)
		var first:=Vector2i(((focus.position-Vector2.ONE*3-base)/3.0).ceil())
		var last:=Vector2i(((focus.end+Vector2.ONE*3-base)/3.0).floor())
		for z in range(maxi(0,first.y),mini(fine_rows-1,last.y)+1):
			for x in range(maxi(0,first.x),mini(fine_side-1,last.x)+1):
				var key:=Vector2i(x,z)+fine_offset
				fine_beds[z*fine_side+x]=maxf(fine_beds[z*fine_side+x],fine_bound.values[key.y*fine_bound.size.x+key.x]+E.WATER_SINK)
	return {"ground":beds,"fine":fine_beds,"tiles":selected.size()}


## Fixed world footprints make a tile reusable across differently sized
## source domains. Only the compact 3 m and 6 m bounds survive the build.
static func tile_bounds(region:HeightfieldRegion,tile:Vector2i,seed_value:int)->Dictionary:
	var cacheable:=region.plan!=null and region.native_control_heights.is_empty() and region.terrain_grades.is_empty()
	if cacheable:
		var cached:Dictionary=region.plan.water_bank_bound(tile)
		if not cached.is_empty():return cached
	var focus:=Rect2(Vector2(tile)*96.0,Vector2.ONE*96.0)
	var env:=_bank(region,focus,seed_value)
	var result:Dictionary={"coarse":node_bounds(env,focus,Vector2.ONE*3.0,6.0),
		"fine":node_bounds(env,focus,Vector2.ONE*3.0,3.0)}
	if cacheable:region.plan.store_water_bank_bound(tile,result)
	return result


static func _bank(region:HeightfieldRegion,focus:Rect2,seed_value:int)->RefCounted:
	const E=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
	var bank_region:=region
	# Source regions carry a smaller sampling halo than the bank envelope.
	# Extend an edge tile through the same plan, never clamp missing nodes.
	var bounds:=focus.grow(E.PAD+25.0)
	var first_point:=Vector2i((bounds.position/12.0).floor())
	var last_point:=Vector2i((bounds.end/12.0).ceil())
	var required:=Rect2i(first_point,last_point-first_point+Vector2i.ONE)
	if region.plan!=null and not region.certified_points.encloses(required):
		bank_region=region.plan.compute_rect_region(required)
	var sampler:=func(p:Vector2)->float:return TerrainTileField.surface_y(bank_region,p.x,p.y)
	var grid:=func(origin:Vector2,w:int,h:int)->PackedFloat64Array:
		var xs:=PackedFloat64Array();var zs:=PackedFloat64Array()
		for i in w:xs.append((origin+Vector2(i,0)*E.H).x)
		for k in h:zs.append((origin+Vector2(0,k)*E.H).y)
		return TerrainTileField.sample_grid(bank_region,xs,zs)
	var points:=func(xs:PackedFloat64Array,zs:PackedFloat64Array)->PackedFloat64Array:return TerrainTileField.sample_grid(bank_region,xs,zs)
	return E._build(focus.grow(1),sampler,Callable(),seed_value,Callable(),grid,points,false,0)

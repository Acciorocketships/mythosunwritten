extends GutTest

## Re-pinned (dual-grid terrain, 2026-09-30): on 12 m points the photographed
## ledge window (x 677..688, z -1744..-1734) no longer holds a rim boundary.
## The same invariant now covers every unpaired rim vertex of the whole chunk
## (3,-10), which contains that ledge (497 boundary vertices when re-pinned;
## tests/harness/september10_photo16_rescan.gd prints the census).
func test_photo16_actual_free_shore_closes_into_ground_or_connected_water()->void:
	var fields:=preload("res://tests/fixtures/September10WaterFields.gd").get_fields()
	var ctx:=fields.water(Vector2i(3,-10)).raw_context()
	var chunk:=Rect2(Vector2(3,-10)*192.0,Vector2.ONE*192.0)
	var curves:=WaterContour.curves(ctx,chunk)
	var st:Dictionary={"ctx":ctx,"region":ctx.region,"verts":PackedVector3Array(),
		"idx":PackedInt32Array(),"weld":{},"normal_accum":PackedVector3Array()}
	for curve:Dictionary in curves:WaterSkin._rim(st,curve)
	# Inspect actual unpaired mesh edges, rather than an arbitrary permitted
	# height for the smoothed contour. The rounded body must end in terrain
	# or in the other connected water, never in the air above either one.
	var counts:Dictionary={}
	for i in range(0,st.idx.size(),3):
		for k in 3:
			var a:int=st.idx[i+k];var b:int=st.idx[i+(k+1)%3]
			var key:=Vector2i(mini(a,b),maxi(a,b));counts[key]=counts.get(key,0)+1
	var seen:Dictionary={};var worst:=0.0
	for edge:Vector2i in counts:
		if counts[edge]!=1:continue
		for index in [edge.x,edge.y]:
			var vertex:Vector3=st.verts[index];var p:=Vector2(vertex.x,vertex.z)
			if not chunk.has_point(p) or seen.has(index):continue
			seen[index]=true
			var support:=TerrainTileField.surface_y(ctx.region,p.x,p.y)
			var level:=WaterField.level_at(ctx,p)
			if is_finite(level):support=maxf(support,level)
			worst=maxf(worst,vertex.y-support)
	assert_gt(seen.size(),3,"inspect the emitted lower boundary of the photographed chunk")
	assert_lte(worst,.05,"no mesh boundary floats above the ground or lower connected water")

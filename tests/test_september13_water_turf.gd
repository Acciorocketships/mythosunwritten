extends GutTest

func test_shallow_water_trough_keeps_the_actual_native_turf_covered()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),water,26,0,64)
	# Re-pinned (terrain regimes, 2026-10-02): chunk (4,1) is dry now. A scan of
	# chunks -6..6 for the densest 12 x 8 m window of 0..0.4 m-deep water picks
	# (810, 1178) in chunk (4,6).
	var chunk:=Vector2i(4,6)
	var region:=fields.region(chunk)
	var field:=fields.water(chunk)
	var mesher:=TerrainChunkMesher.new();mesher.set_seed(2697992464);mesher.prepare_resources()
	var terrain_data:=mesher.compute_chunk(chunk,region,field)
	var ground:=mesher.commit_chunk(terrain_data);add_child_autofree(ground)
	var skin:=WaterSkin.build(water,chunk,region,field)
	var local:=Rect2(810,1178,12,8)
	var terrain:Array=[]
	for node:MeshInstance3D in ground.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			terrain.append_array(_triangles(node.mesh.surface_get_arrays(surface),local,node.global_transform,0))
	# (World terrain places no native KayKit cliff pieces since the dual-grid
	# tiles: the committed chunk meshes are the whole terrain.)
	var wet:=_triangles(skin.arrays,local,Transform3D.IDENTITY,0)
	var trough:=_triangles(skin.arrays,local,Transform3D.IDENTITY,-WaterSkin.SWELL_TROUGH_BOUND)
	var moderate:=_triangles(skin.arrays,local,Transform3D.IDENTITY,-.5)
	var checked:=0;var exposed:=0;var moderate_exposed:=0;var worst:=INF
	for z in 32:
		for x in 48:
			var p:=local.position+Vector2(x,z)*.25
			var bed:=_height(terrain,p)
			if _height(wet,p)<=bed+.005:continue
			checked+=1
			var gap:=_height(trough,p)-bed
			worst=minf(worst,gap)
			if gap<-.0001:exposed+=1
			if _height(moderate,p)<bed-.0001:moderate_exposed+=1
	print("NATIVE_TURF_TROUGH checked=",checked," exposed=",exposed," moderate=",moderate_exposed," gap=",worst)
	assert_gt(checked,100,"the actual reported wet surface is sampled across a substantial area")
	assert_eq(exposed,0,"the maximum permitted wave trough cannot reveal native turf inside wet water")
	assert_eq(moderate_exposed,0,"ordinary wave amplitudes also keep the raised turf covered")

func _triangles(arrays:Array,area:Rect2,transform:Transform3D,displacement:float)->Array:
	var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	if indices.is_empty():
		indices.resize(verts.size());for i in indices.size():indices[i]=i
	var out:=[]
	for i in range(0,indices.size(),3):
		var tri:=PackedVector3Array()
		for j in 3:
			var ix:=indices[i+j];var v:=verts[ix]
			if displacement!=0:v+=arrays[Mesh.ARRAY_NORMAL][ix]*arrays[Mesh.ARRAY_COLOR][ix].r*displacement
			tri.append(transform*v)
		var bounds:=Rect2(Vector2(tri[0].x,tri[0].z),Vector2.ZERO)
		for v:Vector3 in tri:bounds=bounds.expand(Vector2(v.x,v.z))
		if bounds.intersects(area,true):out.append(tri)
	return out

func _height(triangles:Array,p:Vector2)->float:
	var height:=-INF
	for tri:PackedVector3Array in triangles:
		var hit:Variant=Geometry3D.ray_intersects_triangle(Vector3(p.x,30,p.y),Vector3.DOWN,tri[0],tri[1],tri[2])
		if hit!=null:height=maxf(height,hit.y)
	return height

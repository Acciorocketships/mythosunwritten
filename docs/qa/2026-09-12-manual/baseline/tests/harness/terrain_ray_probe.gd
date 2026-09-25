extends SceneTree
func _init() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464, water)
	var region := plan.compute_region(24,-32,10)
	var player := Vector3(564.9,13.3,-760.7)
	var camera := ReviewCam.solve_cam(player,Vector3(565.2,13.5,-760.5))
	var basis := Basis.looking_at(player-camera)
	var direction := basis * Vector3((600.0/1600.0*2-1)*1600.0/960.0*tan(deg_to_rad(75.0)/2), (1-420.0/960.0*2)*tan(deg_to_rad(75.0)/2),-1).normalized()
	var mesher := TerrainChunkMesher.new()
	mesher.prepare_resources()
	var data := mesher.compute_chunk(Vector2i(2,-4), region)
	print("RAY ",camera," ",direction)
	for key: String in ["surface_arrays","wall_arrays","apron_arrays"]:
		if data.has(key) and not (data[key] as Array).is_empty():
			_ray_arrays(key, data[key], Transform3D.IDENTITY,camera,direction)
	var pieces := CliffDressing.compute(region,22,-34,5)
	for key in pieces:
		var mesh: Mesh = CliffDressing._pieces[key][0]
		for transform: Transform3D in pieces[key]:
			_ray_arrays(key+str(transform.origin),mesh.surface_get_arrays(0),transform * CliffDressing._pieces[key][1],camera,direction)
	quit()
func _ray_arrays(label: String, arrays: Array, transform: Transform3D, camera: Vector3, direction: Vector3) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
	var best := INF
	var point := Vector3.ZERO
	for i in range(0,indices.size(),3):
		var a := transform*verts[indices[i]]
		var b := transform*verts[indices[i+1]]
		var c := transform*verts[indices[i+2]]
		if (b-a).cross(c-a).dot(direction) <= 0.0:
			continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(camera,direction,a,b,c)
		if hit != null and camera.distance_to(hit) < best:
			best = camera.distance_to(hit)
			point=hit
	if best < INF:
		print("HIT ",label," distance=",best," point=",point)

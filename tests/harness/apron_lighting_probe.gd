extends SceneTree
func _init() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var region := TerrainWorldTuning.make_heightfield(2697992464,water).compute_region(32,-62,10)
	var mesher := TerrainChunkMesher.new()
	mesher.prepare_resources()
	mesher.set_seed(2697992464)
	for chunk: Vector2i in [Vector2i(3,-8),Vector2i(4,-8)]:
		var data := mesher.compute_chunk(chunk, region)
		var s: Array = data.surface_arrays
		var a: Array = data.apron_arrays
		for i in (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
			var p: Vector3 = a[Mesh.ARRAY_VERTEX][i]
			if p.distance_to(Vector3(768,22,-1476)) > 9 or (a[Mesh.ARRAY_NORMAL][i] as Vector3).y < 0: continue
			var nearest := 0
			var distance := INF
			for j in (s[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
				var d := p.distance_to(s[Mesh.ARRAY_VERTEX][j])
				if d < distance:
					distance=d
					nearest=j
			print("APRON ",chunk," ",p," n=",a[Mesh.ARRAY_NORMAL][i]," nearest=",s[Mesh.ARRAY_VERTEX][nearest]," n=",s[Mesh.ARRAY_NORMAL][nearest]," d=",distance)
	quit()

extends RefCounted


func run(review: Node) -> void:
	var meshes: Array[MeshInstance3D] = []
	for chunk: Vector2i in [Vector2i(-1, 5), Vector2i(-1, 6)]:
		var root: Node = review._streamer._built[chunk]
		meshes.append(root.find_children("WaterSheet", "MeshInstance3D", true, false)[0])
	var result := []
	for mode: String in ["baseline", "refined"]:
		var boundaries := []
		for instance: MeshInstance3D in meshes:
			var mesh: Mesh = (
				instance.get_meta("unrefined_mesh") if mode == "baseline" else instance.mesh
			)
			boundaries.append(_boundary(mesh))
		var checked := 0
		var failures := 0
		var maximum := 0.0
		for side in 2:
			for edge: Array in boundaries[side]:
				for k in 5:
					var p: Vector3 = edge[0].lerp(edge[1], k * .25)
					var nearest := INF
					for other: Array in boundaries[1 - side]:
						nearest = minf(
							nearest,
							(
								Geometry3D
								. get_closest_point_to_segment(p, other[0], other[1])
								. distance_to(p)
							)
						)
					checked += 1
					maximum = maxf(maximum, nearest)
					if nearest > .002:
						failures += 1
		var row: Dictionary = {
			"mode": mode,
			"edges_a": boundaries[0].size(),
			"edges_b": boundaries[1].size(),
			"checked": checked,
			"failures": failures,
			"max_distance": maximum
		}
		print("WATER_REFINEMENT_SEAM ", row)
		result.append(row)
	(
		FileAccess
		. open(review._output_dir + "/water-refinement-seam.json", FileAccess.WRITE)
		. store_string(JSON.stringify(result, "  "))
	)


func _boundary(mesh: Mesh) -> Array:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var result := []
	var seen: Dictionary = {}
	for ti in range(0, indices.size(), 3):
		for k in 3:
			var a: int = indices[ti + k]
			var b: int = indices[ti + (k + 1) % 3]
			if absf(vertices[a].z - 1152.0) > .001 or absf(vertices[b].z - 1152.0) > .001:
				continue
			var key := Vector2i(mini(a, b), maxi(a, b))
			if seen.has(key):
				continue
			seen[key] = true
			result.append([vertices[a], vertices[b]])
	return result

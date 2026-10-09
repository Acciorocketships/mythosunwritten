extends RefCounted

var _meshes: Dictionary = {}
var _shapes: Dictionary = {}

func run(review: Node) -> void:
	var rows: Array = []
	for chunk: Vector2i in review._streamer._built:
		var row := {"chunk":str(chunk),"nodes":0,"unique_mesh_array_bytes":0,"unique_collision_face_bytes":0,
			"mesh_instances":0,"multimesh_instances":0,"collision_shapes":0,"collision_triangles":0,"vertices":0}
		var pending: Array[Node] = [review._streamer._built[chunk]]
		while not pending.is_empty():
			var node: Node = pending.pop_back()
			row.nodes += 1
			pending.append_array(node.get_children())
			if node is MeshInstance3D:
				row.mesh_instances += 1
				_mesh(node.mesh,row)
			elif node is MultiMeshInstance3D:
				row.multimesh_instances += 1
				if node.multimesh != null: _mesh(node.multimesh.mesh,row)
			elif node is CollisionShape3D:
				row.collision_shapes += 1
				var shape: Shape3D = node.shape
				if shape == null or _shapes.has(shape.get_instance_id()): continue
				_shapes[shape.get_instance_id()] = true
				if shape is ConcavePolygonShape3D:
					var count: int = shape.get_faces().size()
					row.unique_collision_face_bytes += count * 12
					row.collision_triangles += count / 3
		rows.append(row)
	var result := {"rows":rows,"memory_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
		"scope":"unique reachable mesh array payload and concave face bytes, excludes backend BVHs, allocation overhead, worker/cache dictionaries and textures; shared resources counted once across all rows"}
	FileAccess.open(review._output_dir+"/chunk-memory.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CHUNK_MEMORY_DONE ",JSON.stringify(result))

func _mesh(mesh: Mesh, row: Dictionary) -> void:
	if mesh == null or _meshes.has(mesh.get_instance_id()): return
	_meshes[mesh.get_instance_id()] = true
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		row.vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		for value: Variant in arrays:
			match typeof(value):
				TYPE_PACKED_VECTOR3_ARRAY: row.unique_mesh_array_bytes += value.size()*12
				TYPE_PACKED_VECTOR2_ARRAY: row.unique_mesh_array_bytes += value.size()*8
				TYPE_PACKED_COLOR_ARRAY: row.unique_mesh_array_bytes += value.size()*16
				TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY: row.unique_mesh_array_bytes += value.size()*4
				TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT64_ARRAY: row.unique_mesh_array_bytes += value.size()*8
				TYPE_PACKED_BYTE_ARRAY: row.unique_mesh_array_bytes += value.size()

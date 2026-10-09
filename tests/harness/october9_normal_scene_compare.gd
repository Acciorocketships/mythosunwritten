extends RefCounted

func run(review: Node) -> void:
	# Recreate only the preceding normal sampler. Geometry, materials, water,
	# camera and all scene instances remain identical between captures.
	var source := FileAccess.get_file_as_string("res://scripts/terrain/field/TerrainChunkMesher.gd")
	var begin := source.find("const NORMAL_STEP :=")
	var end := source.find("\nfunc _tri_tinted", begin)
	assert(begin >= 0 and end > begin)
	var code := source.substr(begin,end-begin)
	code = code.replace("if TerrainTileField.cliff_end != TerrainTileField.CliffEnd.SHARED_PROFILE \\\n\t\t\tand not is_nan(plus)", "if not is_nan(plus)")
	code = code.replace("if TerrainTileField.cliff_end != TerrainTileField.CliffEnd.SHARED_PROFILE \\\n\t\t\tand absf(", "if absf(")
	var legacy := GDScript.new()
	legacy.source_code = "extends RefCounted\n" + code
	assert(legacy.reload() == OK)
	var restored: Array = []
	var changed := 0
	var maximum := 0.0
	var worst := Vector3.ZERO
	for chunk: Vector2i in review._inputs:
		var node := review._streamer._built[chunk].get_node_or_null("Surface") as MeshInstance3D
		if node == null: continue
		var original := node.mesh
		var arrays := original.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var old_normals: PackedVector3Array = legacy.field_normals(vertices,review._inputs[chunk].region,{})
		var new_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			var error := old_normals[i].distance_to(new_normals[i])
			if error > .0001: changed += 1
			if error > maximum:
				maximum = error
				worst = vertices[i]
		arrays[Mesh.ARRAY_NORMAL] = old_normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,original.surface_get_material(0))
		restored.append([node,original,mesh])
		node.mesh = mesh
	await review._capture_all(1)
	for pair: Array in restored: pair[0].mesh = pair[1]
	await review._capture_all(2)
	var result := {"changed_vertices":changed,"maximum_normal_vector_difference":maximum,"worst_world_vertex":str(worst)}
	FileAccess.open(review._output_dir+"/normal-comparison.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("NORMAL_SCENE_COMPARE_DONE ",JSON.stringify(result))

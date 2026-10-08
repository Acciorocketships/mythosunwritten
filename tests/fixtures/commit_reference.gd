extends RefCounted
## RockSkirt.commit and BiomeChunkFx._point_effect as they were before their
## October 8 split / reorder, the references test_chunk_commit_steps compares
## the stepped builds with.

static func commit(parent: Node3D, skirts: Array) -> void:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	if skirts.is_empty():
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var faces := PackedVector3Array()
	for skirt: Dictionary in skirts:
		var base := vertices.size()
		vertices.append_array(skirt.vertices)
		normals.append_array(skirt.normals)
		colors.append_array(skirt.colors)
		for index: int in skirt.indices:
			indices.append(base + index)
			faces.append((skirt.vertices as PackedVector3Array)[index])
	# The terrain-covering triangles; slope-covering ones render in the sheet.
	if indices.is_empty():
		return
	var uvs := PackedVector2Array()
	uvs.resize(vertices.size())
	uvs.fill(CliffDressing.ground_uv())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, CliffDressing.shared_material())
	var instance := MeshInstance3D.new()
	instance.name = &"RockSkirts"
	instance.mesh = mesh
	instance.add_to_group("tactical_solid_earth", true)
	parent.add_child(instance)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.name = &"RockSkirts"
	collision.shape = shape
	var body := StaticBody3D.new()
	body.name = &"RockSkirtCollision"
	body.add_child(collision)
	parent.add_child(body)


static func point_effect(recipe: StringName, points: PackedVector3Array, data: Dictionary) -> Node3D:
	if recipe == &"fireflies":
		var batch := BiomeChunkFx.SmallOrbRenderer.new()
		batch.setup(points)
		return batch
	var emitter := BiomeChunkFx._emitter(recipe, 1.0, data.lo, data.hi)
	emitter.amount = clampi(points.size() * 5, 8, 240)
	emitter.preprocess = 5.0
	emitter.fixed_fps = 30
	var process := emitter.process_material as ParticleProcessMaterial
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	process.emission_shape_offset = Vector3.ZERO
	process.emission_point_count = points.size()
	var positions := Image.create_empty(points.size(), 1, false, Image.FORMAT_RGBF)
	for i in points.size():
		positions.set_pixel(i, 0, Color(points[i].x, points[i].y, points[i].z))
	process.emission_point_texture = ImageTexture.create_from_image(positions)
	return emitter

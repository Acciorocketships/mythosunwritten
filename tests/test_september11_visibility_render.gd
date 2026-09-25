extends GutTest

func test_shared_render_mesh_fades_only_selected_geometry_and_restores_pixels() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires the native renderer")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,180)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var target := Node3D.new()
	target.position = Vector3(-2,0,0)
	world.add_child(target)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,2,10)
	camera.look_at(Vector3(0,2,0))
	camera.make_current()
	var mesh := ArrayMesh.new()
	for surface in 2:
		var box := BoxMesh.new()
		var arrays := box.get_mesh_arrays()
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for index in points.size(): points[index].y += -.55 if surface==0 else .55
		arrays[Mesh.ARRAY_VERTEX] = points
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var source := ShaderMaterial.new()
		source.shader = Shader.new()
		source.shader.code = "shader_type spatial; render_mode unshaded; uniform vec4 tint: source_color; void fragment(){ ALBEDO=tint.rgb; }"
		source.set_shader_parameter("tint",Color.RED if surface==0 else Color.BLUE)
		mesh.surface_set_material(surface,source)
	var nodes: Array[MultiMeshInstance3D] = []
	for x: float in [-2.0,2.0]:
		var node := MultiMeshInstance3D.new()
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.mesh = mesh
		node.multimesh.instance_count = 1
		node.multimesh.set_instance_transform(0,Transform3D.IDENTITY)
		node.position = Vector3(x,2,4)
		world.add_child(node)
		nodes.append(node)
	# The cutaway now requires genuine ground behind the selected batch.
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(60,60)
	ground.mesh = ground_mesh
	ground.rotation_degrees.x = 35
	ground.add_to_group("tactical_solid_earth")
	var ground_material := StandardMaterial3D.new()
	ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = ground_material
	world.add_child(ground)
	var bubble := CameraVisibilityBubble.new()
	world.add_child(bubble)
	var before := await _frame(viewport)
	bubble._active[nodes[0].get_instance_id()] = bubble._install(nodes[0])
	bubble._query_in = INF
	bubble._last_eye = camera.position
	bubble.update_bubble(camera,target,target.position,8.0,0.0,1.0)
	var faded := await _frame(viewport)
	var changed_left := 0
	var changed_right := 0
	for y in 180:
		for x in 320:
			if before.get_pixel(x,y) != faded.get_pixel(x,y):
				if x<160: changed_left += 1
				else: changed_right += 1
	assert_gt(changed_left,300,"Selected geometry visibly fades")
	assert_eq(changed_right,0,"Unselected geometry sharing the same render mesh stays pixel-identical")
	bubble.clear()
	var restored := await _frame(viewport)
	assert_true(restored.get_data() == before.get_data(),"Release restores the original rendered surfaces")

func _frame(viewport: SubViewport) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

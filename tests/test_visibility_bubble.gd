extends GutTest

func test_generic_material_adapter_restores_shared_resources_and_batch() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var bubble := CameraVisibilityBubble.new()
	world.add_child(bubble)
	var mesh := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.CORAL
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	world.add_child(instance)
	var state := bubble._install(instance)
	assert_ne(instance.get_active_material(0), material)
	assert_eq(mesh.material, material, "Shared mesh and material remain untouched")
	bubble._restore(instance, state)
	assert_null(instance.get_surface_override_material(0))
	assert_eq(instance.get_active_material(0), material)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = 2
	var transform := Transform3D(Basis.IDENTITY, Vector3(15,2,3))
	batch.multimesh.set_instance_transform(1, transform)
	world.add_child(batch)
	var original := batch.multimesh
	var batch_state := bubble._install(batch)
	assert_same(batch.multimesh, original, "Single-surface fade retains the live instance buffer")
	assert_true(batch.material_override is ShaderMaterial)
	assert_eq(batch.multimesh.get_instance_transform(1), original.get_instance_transform(1))
	if DisplayServer.get_name() != "headless":
		assert_eq(batch.multimesh.get_instance_transform(1), transform)
	assert_eq(original.mesh.surface_get_material(0), material)
	bubble._restore(batch, batch_state)
	assert_eq(batch.multimesh, original)

func test_corridor_selects_neighbours_but_excludes_floor_and_distant_objects() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var object := MeshInstance3D.new()
	object.mesh = BoxMesh.new()
	world.add_child(object)
	var eye := Vector3(0,16,14)
	object.position = Vector3(2,2,3)
	assert_true(CameraVisibilityBubble._overlaps_corridor(object, eye, Vector3.ZERO, 3.8),
		"A neighbour away from the exact eye ray still joins the bubble")
	object.position = Vector3(20,2,3)
	assert_false(CameraVisibilityBubble._overlaps_corridor(object, eye, Vector3.ZERO, 3.8))
	object.position = Vector3(0,-1,0)
	assert_false(CameraVisibilityBubble._overlaps_corridor(object, eye, Vector3.ZERO, 3.8))
	object.position = Vector3(0,1,-8)
	assert_false(CameraVisibilityBubble._overlaps_corridor(object, eye, Vector3.ZERO, 3.8))

func test_shader_adapter_preserves_existing_vertex_fragment_and_light_code() -> void:
	var source := "shader_type spatial; void vertex() { VERTEX.x += 1.0; } void fragment() { ALBEDO=vec3(0.5); if (UV.x>0.2) { ROUGHNESS=0.8; } } void light() { DIFFUSE_LIGHT += vec3(0.1); }"
	var result := CameraVisibilityBubble.instrument(source)
	assert_string_contains(result, "VERTEX.x += 1.0;")
	assert_string_contains(result, "ALBEDO=vec3(0.5);")
	assert_string_contains(result, "ROUGHNESS=0.8;")
	assert_string_contains(result, "void light() { DIFFUSE_LIGHT += vec3(0.1); }")
	assert_eq(result.count("tactical_cutout(VERTEX"), 1)

func test_comments_and_early_returns_cannot_bypass_the_bubble() -> void:
	var source := "shader_type spatial; // void fragment() { fake }\nvoid fragment() { if (UV.x > 0.5) { return; } ALBEDO=vec3(1.0); }"
	var result := CameraVisibilityBubble.instrument(source)
	assert_lt(result.find("tactical_cutout(VERTEX"), result.find("if (UV.x"))
	assert_string_contains(result, "// void fragment() { fake }")
	assert_eq(result.count("tactical_cutout(VERTEX"), 1)

func test_step_smoothed_focus_never_lowers_the_protected_physical_floor() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,16,14)
	var target := Node3D.new()
	world.add_child(target)
	target.position.y = 0.5
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	world.add_child(mesh)
	var bubble := CameraVisibilityBubble.new()
	world.add_child(bubble)
	var state := bubble._install(mesh)
	bubble._active[mesh.get_instance_id()] = state
	bubble._query_in = INF
	bubble._last_eye = camera.global_position
	bubble.update_bubble(camera,target,Vector3(0,0.2,0),3.8,0.12,1.0/60)
	var material := state.materials[0] as ShaderMaterial
	assert_eq(material.get_shader_parameter("tactical_floor_y"), 0.5)
	assert_eq(material.get_shader_parameter("tactical_feet"), Vector3(0,0.2,0))
	bubble.clear()

func test_faded_materials_follow_live_source_uniforms_and_resets() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var source := ShaderMaterial.new()
	source.shader = Shader.new()
	source.shader.code = "shader_type spatial; uniform float phase=0.25; void fragment() { ALBEDO=vec3(phase); }"
	source.set_shader_parameter("phase", 0.4)
	var bubble := CameraVisibilityBubble.new()
	world.add_child(bubble)
	for x in 2:
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.material_override = source
		world.add_child(mesh)
		bubble._active[mesh.get_instance_id()] = bubble._install(mesh)
	source.set_shader_parameter("phase", 0.9)
	var arriving := MeshInstance3D.new()
	arriving.mesh = BoxMesh.new()
	arriving.material_override = source
	world.add_child(arriving)
	bubble._active[arriving.get_instance_id()] = bubble._install(arriving)
	bubble._sync_source_parameters()
	for state: Dictionary in bubble._active.values():
		assert_almost_eq(float(state.materials[0].get_shader_parameter("phase")), 0.9, 0.0001)
	source.set_shader_parameter("phase", null)
	bubble._sync_source_parameters()
	for state: Dictionary in bubble._active.values():
		assert_null(state.materials[0].get_shader_parameter("phase"), "Reset withdraws the override so the shader default applies")
	# Let the renderer consume the changed uniforms before restoring the sources.
	for frame in 3: await get_tree().process_frame
	bubble.clear()
	for frame in 3: await get_tree().process_frame

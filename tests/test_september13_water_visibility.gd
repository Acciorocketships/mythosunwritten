extends GutTest

func test_water_keeps_its_native_material_inside_the_obstruction_corridor() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Needs native render broad phase")
		return
	var view := SubViewport.new()
	view.size = Vector2i(320,200)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(0,16,26)
	camera.look_at(Vector3.UP)
	camera.make_current()
	var target := Node3D.new()
	view.add_child(target)
	var plane := PlaneMesh.new()
	plane.size = Vector2(60,60)
	var water := WaterSurfaceBuilder.new().commit_chunk({"arrays":plane.get_mesh_arrays(),"sampler":WaterSampler.new(),"triggers":[]})
	view.add_child(water)
	water.position.y = 3.0
	var sheet := water.get_node("WaterSheet") as MeshInstance3D
	var original := sheet.material_override
	var vertices := sheet.mesh.surface_get_arrays(0)
	var bubble := CameraVisibilityBubble.new()
	view.add_child(bubble)
	for offset in [Vector3.ZERO,Vector3(2,0,1),Vector3(-2,0,-1)]:
		target.position = offset
		for frame in 12:
			bubble.update_bubble(camera,target,offset,14,0,.1)
			await get_tree().process_frame
		assert_same(sheet.material_override,original,"Camera cutaway must preserve the native water shader")
		assert_false(bubble._active.has(sheet.get_instance_id()),"Water is not a camera obstruction")
	assert_eq(sheet.mesh.surface_get_arrays(0),vertices,"Water geometry stays unchanged")
	bubble.clear()

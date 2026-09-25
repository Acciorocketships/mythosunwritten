extends GutTest

func test_upward_foliage_is_not_mistaken_for_ground_support() -> void:
	await _check_foliage(false)

func test_near_foliage_can_reveal_an_actual_cliff_face() -> void:
	await _check_foliage(true)

func _check_foliage(vertical_receiver: bool) -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires native GPU execution")
		return
	var view := SubViewport.new()
	view.size = Vector2i(320,200)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(0,12,20)
	camera.look_at(Vector3.UP)
	camera.fov = 50
	camera.make_current()
	var target := Node3D.new()
	view.add_child(target)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100,100)
	ground.mesh = plane
	if vertical_receiver:
		ground.rotation_degrees.x = 90
		ground.position.z = -10
	ground.add_to_group("tactical_solid_earth")
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(.1,.5,.2)
	ground.material_override = mat
	view.add_child(ground)
	var bare := await _frame(view)
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"kaykit.bush.01",Transform3D(Basis.IDENTITY,Vector3(0,0,2)),Color(1,.2,.6))
	var queue := EnvironmentCommitQueue.new(EnvironmentRenderCache.new(EnvironmentCatalog.load_default()),&"Vegetation")
	queue.register_chunk(Vector2i.ZERO,1)
	var vegetation := Node3D.new()
	view.add_child(vegetation)
	queue.enqueue(Vector2i.ZERO,1,vegetation,payload)
	queue.drain(1000)
	var opaque := await _frame(view)
	var bubble := CameraVisibilityBubble.new()
	view.add_child(bubble)
	for frame in 16:
		bubble.update_bubble(camera,target,Vector3.ZERO,12,0,.1)
		await get_tree().process_frame
	var revealed := await _frame(view)
	var native_pixels := 0
	var retained := 0
	for y in view.size.y:
		for x in view.size.x:
			if opaque.get_pixel(x,y) == bare.get_pixel(x,y): continue
			native_pixels += 1
			if revealed.get_pixel(x,y) != bare.get_pixel(x,y): retained += 1
	assert_gt(native_pixels,30,"Actual native bush visibly obstructs ground")
	assert_eq(retained,0,"All foliage faces clear; upward leaf normals do not grant ground protection")
	bubble.clear()

func _frame(view: SubViewport) -> Image:
	for frame in 4: await get_tree().process_frame
	RenderingServer.force_draw(false)
	return view.get_texture().get_image()

func test_background_earth_stays_closed_even_when_its_top_is_above_actor() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires native GPU execution")
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
	camera.fov = 50
	camera.make_current()
	var target := Node3D.new()
	view.add_child(target)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100,100)
	ground.mesh = plane
	ground.add_to_group("tactical_solid_earth")
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(.1,.5,.2)
	ground.material_override = material
	view.add_child(ground)
	var bank := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(12,8,4)
	bank.mesh = block
	bank.position = Vector3(0,4,-5)
	bank.add_to_group("tactical_solid_earth")
	var bank_material := material.duplicate() as StandardMaterial3D
	bank_material.albedo_color = Color(.5,.1,.8)
	bank.material_override = bank_material
	view.add_child(bank)
	var bubble := CameraVisibilityBubble.new()
	view.add_child(bubble)
	for frame in 16:
		bubble.update_bubble(camera,target,Vector3.ZERO,14,0,.1)
		await get_tree().process_frame
	for id: int in bubble._active: instance_from_id(id).set_instance_shader_parameter("tactical_strength",0.0)
	var opaque := await _frame(view)
	for id: int in bubble._active: instance_from_id(id).set_instance_shader_parameter("tactical_strength",1.0)
	var enabled := await _frame(view)
	assert_true(enabled.get_data() == opaque.get_data(),"A bank wholly behind the actor must retain its top and front cliff, regardless of height")
	bubble.clear()

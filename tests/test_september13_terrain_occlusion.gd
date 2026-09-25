extends GutTest

func test_clear_character_does_not_cut_neighboring_terrain() -> void:
	await _check_obstruction(7.0,false)

func test_intervening_terrain_still_reveals_character() -> void:
	await _check_obstruction(0.0,true)

func _check_obstruction(offset: float, obstructs: bool) -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires native GPU depth")
		return
	var view := SubViewport.new()
	view.size = Vector2i(480,300)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(view)
	var world := Node3D.new()
	view.add_child(world)
	var target := Node3D.new()
	world.add_child(target)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,12,24)
	camera.look_at(Vector3.UP)
	camera.fov = 65
	camera.make_current()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100,100)
	ground.mesh = plane
	ground.add_to_group("tactical_solid_earth")
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(.1,.5,.2)
	ground.material_override = material
	world.add_child(ground)
	var bank := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(4,6,4)
	bank.mesh = block
	bank.position = Vector3(offset,3,7)
	bank.add_to_group("tactical_solid_earth")
	var rock := material.duplicate() as StandardMaterial3D
	rock.albedo_color = Color(.5,.1,.8)
	bank.material_override = rock
	world.add_child(bank)
	var bubble := CameraVisibilityBubble.new()
	world.add_child(bubble)
	for frame in 16:
		bubble.update_bubble(camera,target,Vector3.ZERO,14,0,.1)
		await get_tree().process_frame
	for id: int in bubble._active: instance_from_id(id).set_instance_shader_parameter("tactical_strength",0.0)
	for frame in 4: await get_tree().process_frame
	RenderingServer.force_draw(false)
	var opaque := view.get_texture().get_image()
	for id: int in bubble._active: instance_from_id(id).set_instance_shader_parameter("tactical_strength",1.0)
	for frame in 4: await get_tree().process_frame
	RenderingServer.force_draw(false)
	var revealed := view.get_texture().get_image()
	var changed := 0
	for y in view.size.y:
		for x in view.size.x:
			if opaque.get_pixel(x,y) != revealed.get_pixel(x,y): changed += 1
	if obstructs: assert_gt(changed,100,"Intervening bank still clears to real lower ground")
	else: assert_eq(changed,0,"A clear character must not cause holes in adjacent terrain")
	if not obstructs:
		var pixel := camera.unproject_position(Vector3(offset,6,7))
		var front: Color = bubble._receivers.front_texture().get_image().get_pixelv(pixel)
		var receiver: Color = bubble._receivers.texture().get_image().get_pixelv(pixel)
		assert_eq(receiver,front,"An uncut bank retains its actual top receiver for grass-root protection")
		var expected := opaque.get_pixelv(pixel)
		var damaged_frames := 0
		for frame in 60:
			camera.position = Vector3(0,12,24).rotated(Vector3.UP,sin(float(frame)*TAU/60.0)*.12)
			camera.look_at(Vector3.UP)
			bubble.update_bubble(camera,target,Vector3.ZERO,14,0,1.0/60.0)
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			pixel = camera.unproject_position(Vector3(offset,6,7))
			var actual := view.get_texture().get_image().get_pixelv(pixel)
			if absf(actual.r-expected.r)+absf(actual.g-expected.g)+absf(actual.b-expected.b) > .03:
				damaged_frames += 1
		assert_eq(damaged_frames,0,"The retained bank remains opaque throughout a moving-camera sweep")
	bubble.clear()

extends GutTest

func test_terrain_sheet_and_slopes_stay_opaque_beyond_old_five_metre_radius() -> void:
	await _check_ground(CliffDressing.shared_material())

func test_ground_cover_stays_opaque_with_its_terrain() -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://terrain/grass/grass.gdshader")
	material.set_shader_parameter("ground_palette_texture",CliffDressing.ground_texture())
	material.set_shader_parameter("ground_palette_uv",CliffDressing.ground_uv())
	await _check_ground(material)

func _check_ground(material: Material) -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires native GPU rendering")
		return
	var view := SubViewport.new()
	view.size = Vector2i(320,200)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(view)
	var world := Node3D.new()
	view.add_child(world)
	var target := Node3D.new()
	world.add_child(target)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,16,26)
	camera.look_at(Vector3.UP)
	camera.fov = 50
	camera.make_current()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60,60)
	ground.mesh = plane
	ground.material_override = material
	world.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60,-30,0)
	world.add_child(sun)
	var bubble := CameraVisibilityBubble.new()
	world.add_child(bubble)
	for slope: float in [0.0,12.0,-12.0,35.0]:
		ground.rotation_degrees.x = slope
		var original := await _frame(view)
		for frame in 12:
			bubble.update_bubble(camera,target,target.position,14,.12,.1)
			await get_tree().process_frame
		var revealed := await _frame(view)
		assert_true(revealed.get_data() == original.get_data(),
			"Ground stays pixel-identical with cutaway enabled at slope %s" % slope)
		bubble.clear()

func _frame(view: SubViewport) -> Image:
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func test_cutaway_reveals_context_and_keeps_raised_earth_closed() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires native GPU rendering")
		return
	var view := SubViewport.new()
	view.size = Vector2i(320,200)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(view)
	var world := Node3D.new()
	view.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.MAGENTA
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 1
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,12,20)
	camera.look_at(Vector3.UP)
	camera.make_current()
	var target := Node3D.new()
	world.add_child(target)
	# Two ordinary visible scene objects establish context beyond an actor marker.
	for x: float in [-1.0,1.0]:
		var object := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(.8,1.8,.8)
		object.mesh = box
		object.position = Vector3(x,.9,0)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color.RED if x<0 else Color.BLUE
		object.material_override = material
		world.add_child(object)
	# The ground sheet is a lower clearing and a raised bank. No lower sheet
	# exists inside the solid bank, exactly as in the reported native terrain.
	for specification: Vector3 in [Vector3(0,0,-8.5),Vector3(0,6,16.5)]:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(40,23 if specification.y>0 else 27)
		ground.mesh = plane
		ground.position = specification
		ground.add_to_group("tactical_solid_earth")
		ground.material_override = CliffDressing.shared_material()
		world.add_child(ground)
	var terrain := StaticBody3D.new()
	terrain.add_to_group("tactical_terrain")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40,6,23)
	shape.shape = box
	shape.position = Vector3(0,3,16.5)
	terrain.add_child(shape)
	world.add_child(terrain)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(CameraVisibilityBubble.terrain_blocks_view(camera,target),"The real raised bank obstructs this view")
	var original := await _frame(view)
	var bubble := CameraVisibilityBubble.new()
	world.add_child(bubble)
	for frame in 12:
		bubble.update_bubble(camera,target,target.position,16,0,.1)
		await get_tree().process_frame
	var cutaway := await _frame(view)
	var context_pixels := 0
	var new_void_pixels := 0
	for y in 200:
		for x in 320:
			var old := original.get_pixel(x,y)
			var color := cutaway.get_pixel(x,y)
			if (color.r>.7 and color.b<.3 and color.g<.3) or (color.b>.7 and color.r<.3 and color.g<.3): context_pixels += 1
			if y>100 and color.r>.7 and color.b>.7 and color.g<.3 and not (old.r>.7 and old.b>.7 and old.g<.3):
				# A one-pixel antialiased outer silhouette may reveal adjacent sky.
				# Count new holes only where the original was interior terrain.
				var interior := true
				for dy in range(-1,2):
					for dx in range(-1,2):
						var neighbor := original.get_pixel(clampi(x+dx,0,319),clampi(y+dy,0,199))
						if neighbor.r>.7 and neighbor.b>.7 and neighbor.g<.3: interior = false
				if interior: new_void_pixels += 1
	assert_gt(context_pixels,100,"Both ordinary scene objects become visible through the bank")
	assert_eq(new_void_pixels,0,"Cutting solid terrain never opens a view into the sky below its surface")
	DirAccess.make_dir_recursive_absolute("/tmp/sept12-context-test")
	original.save_png("/tmp/sept12-context-test/before.png")
	cutaway.save_png("/tmp/sept12-context-test/after.png")
	bubble.clear()
	assert_false(bubble._terrain_blocked,"Leaving tactical view releases terrain obstruction state")
	assert_eq(bubble._terrain_cutaway,0.0,"Leaving tactical view resets the transition")
	# An arch/overhang can use the very same terrain material without owning
	# the solid column below it. Its opening must never acquire a soil floor.
	for ground: Node in world.get_children():
		if ground.is_in_group("tactical_solid_earth"):
			ground.remove_from_group("tactical_solid_earth")
	for frame in 12:
		bubble.update_bubble(camera,target,target.position,16,0,.1)
		await get_tree().process_frame
	var open_span := await _frame(view)
	var open_pixels := 0
	for y in range(110,190):
		for x in range(80,240):
			var color := open_span.get_pixel(x,y)
			if color.r>.7 and color.b>.7 and color.g<.3: open_pixels += 1
	assert_gt(open_pixels,1000,"Shared-material overhead spans retain real open space beneath them")
	bubble.clear()

func test_terrain_query_continues_through_other_obstacles_and_releases_when_clear() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,1,10)
	var target := Node3D.new()
	world.add_child(target)
	var support := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(4,.2,4)
	floor_shape.shape = floor_box
	floor_shape.position.y = -.1
	support.add_child(floor_shape)
	world.add_child(support)
	var terrain: StaticBody3D
	for z: float in [3.0,6.0]:
		var body := StaticBody3D.new()
		body.position = Vector3(0,1,z)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		body.add_child(shape)
		world.add_child(body)
		if z==3:
			terrain = body
			terrain.add_to_group("tactical_terrain")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(CameraVisibilityBubble.terrain_blocks_view(camera,target),"A nearer prop cannot hide the terrain blocker from the query")
	terrain.position.x = 10
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(CameraVisibilityBubble.terrain_blocks_view(camera,target),"An ordinary prop alone never enables ground removal")
	for jump_height: float in [0,0.5,2.0,5.0]:
		target.position.y = jump_height
		assert_almost_eq(CameraVisibilityBubble.support_height(target),0.0,.001,
			"Exposed earth stays rooted on the actual support while the actor jumps")

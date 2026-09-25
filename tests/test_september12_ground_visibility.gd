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
	if material is ShaderMaterial and material.shader.code.contains("TIME"):
		material = material.duplicate()
		var frozen := Shader.new()
		frozen.code = material.shader.code.replace("TIME","0.0")
		material.shader = frozen
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
	var bubble := _bubble()
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
	RenderingServer.force_draw(false)
	return view.get_texture().get_image()

func test_only_real_ground_backed_pixels_reveal_context() -> void:
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
	# A two-sided backing skirt crosses behind the player plane. Ordinary
	# frontface culling alone cannot remove its inward-facing duplicate.
	var rear := MeshInstance3D.new()
	var rear_quad := QuadMesh.new()
	rear_quad.size = Vector2(3,3)
	rear.mesh = rear_quad
	rear.position = Vector3(0,1.5,-4)
	rear.add_to_group("tactical_solid_earth")
	var rear_material := ShaderMaterial.new()
	rear_material.shader = Shader.new()
	rear_material.shader.code = "shader_type spatial; render_mode unshaded,cull_disabled;\n#define TACTICAL_TERRAIN_MATERIAL\nvoid fragment(){ ALBEDO=vec3(0,1,1); }"
	rear.material_override = rear_material
	world.add_child(rear)
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
	var original := await _frame(view)
	var bubble := _bubble()
	world.add_child(bubble)
	for frame in 12:
		bubble.update_bubble(camera,target,target.position,16,0,.1)
		await get_tree().process_frame
	var cutaway := await _frame(view)
	var context_pixels := 0
	var new_void_pixels := 0
	var rear_pixels := 0
	for y in 200:
		for x in 320:
			var old := original.get_pixel(x,y)
			var color := cutaway.get_pixel(x,y)
			if color.r<.1 and color.g>.8 and color.b>.8 and not (old.r<.1 and old.g>.8 and old.b>.8): rear_pixels += 1
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
	assert_eq(rear_pixels,0,"No previously hidden reverse cliff skin appears; already visible background remains valid")
	assert_gt(context_pixels,100,"Both ordinary scene objects become visible through the bank")
	assert_eq(new_void_pixels,0,"Receiver-backed cutaway never introduces sky/void pixels")
	DirAccess.make_dir_recursive_absolute("/tmp/sept12-context-test")
	original.save_png("/tmp/sept12-context-test/before.png")
	cutaway.save_png("/tmp/sept12-context-test/after.png")
	for radius: float in [2.0,3.0,4.0,6.0,10.0]:
		for frame in 12:
			bubble.update_bubble(camera,target,target.position,radius,0,.1)
			await get_tree().process_frame
		var edge := await _frame(view)
		var edge_rear := 0
		for y in 200:
			for x in 320:
				var color := edge.get_pixel(x,y)
				var old := original.get_pixel(x,y)
				if color.r<.1 and color.g>.8 and color.b>.8 and not (old.r<.1 and old.g>.8 and old.b>.8): edge_rear += 1
		edge.save_png("/tmp/sept12-context-test/edge_%d.png"%int(radius))
		assert_eq(edge_rear,0,"The bank feather cannot expose a deeper reverse skin, radius %s"%radius)
	bubble.clear()
	# Without a real lower receiver, the foreground must keep its exact
	# original pixels. Recolouring/filling the hole cannot satisfy this check.
	for ground: Node in world.get_children():
		if ground is MeshInstance3D and ground.is_in_group("tactical_solid_earth") and ground.position.y == 0:
			ground.hide()
	var without_receiver := await _frame(view)
	for frame in 12:
		bubble.update_bubble(camera,target,target.position,16,0,.1)
		await get_tree().process_frame
	var preserved := await _frame(view)
	assert_true(preserved.get_data() == without_receiver.get_data(),
		"No backing ground means the original foreground stays pixel-identical, with no substitute fill")
	bubble.clear()

func test_native_house_shell_clears_to_real_ground_without_exposing_its_interior() -> void:
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
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,12,20)
	camera.look_at(Vector3.UP)
	camera.make_current()
	var target := Node3D.new()
	world.add_child(target)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(100,100)
	ground.add_to_group("tactical_solid_earth")
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.1,0.5,0.2)
	ground.material_override = material
	world.add_child(ground)
	var bare_ground := await _frame(view)
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var queue := EnvironmentCommitQueue.new(cache,&"NativeHouse")
	var house := Node3D.new()
	world.add_child(house)
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"lpfv.building.house.03",Transform3D(Basis.IDENTITY,Vector3(1.5,0,0)),Color.WHITE)
	queue.register_chunk(Vector2i.ZERO,1)
	queue.enqueue(Vector2i.ZERO,1,house,payload)
	queue.drain(1000)
	var bubble := _bubble()
	world.add_child(bubble)
	DirAccess.make_dir_recursive_absolute("/tmp/sept12-house-test")
	for turn in 4:
		house.rotation.y = turn*PI*.5
		var original := await _frame(view)
		for frame in 12:
			bubble.update_bubble(camera,target,target.position,16,0,.1)
			await get_tree().process_frame
		var revealed := await _frame(view)
		var changed := 0
		var interiors := 0
		# The middle of the bubble has full coverage and a known genuine
		# receiver. Compare to an independent render with the house absent.
		for y in range(80,125):
			for x in range(125,195):
				if original.get_pixel(x,y) != bare_ground.get_pixel(x,y): changed += 1
				if revealed.get_pixel(x,y) != bare_ground.get_pixel(x,y): interiors += 1
		assert_gt(changed,500,"Native house occupies the tested reveal in orientation %d" % turn)
		assert_eq(interiors,0,"No native inner wall, floor, rear face or roof remains over the ground receiver in orientation %d" % turn)
		original.save_png("/tmp/sept12-house-test/before_%d.png"%turn)
		revealed.save_png("/tmp/sept12-house-test/after_%d.png"%turn)
		bubble.clear()
		# Removal of the receiver must keep exactly the ordinary house.
		ground.hide()
		var no_ground := await _frame(view)
		for frame in 12:
			bubble.update_bubble(camera,target,target.position,16,0,.1)
			await get_tree().process_frame
		var no_ground_after := await _frame(view)
		no_ground.save_png("/tmp/sept12-house-test/no_ground_before_%d.png"%turn)
		no_ground_after.save_png("/tmp/sept12-house-test/no_ground_after_%d.png"%turn)
		# A disabled adapter is the independent zero-cutout control. Native
		# StandardMaterial conversion can round a few channels by one code;
		# that is not clipping and must not hide actual missing shell pixels.
		for state_id: int in bubble._active:
			instance_from_id(state_id).set_instance_shader_parameter("tactical_strength",0.0)
		var disabled := await _frame(view)
		assert_true(no_ground_after.get_data() == disabled.get_data(),"No receiver leaves every house pixel identical to disabled cutout")
		bubble.clear()
		ground.show()

func _bubble() -> Node:
	if OS.get_environment("STORY_TEST_GROUND_EDGE_BEFORE") == "1":
		return preload("res://tests/fixtures/september13/ground_edge_before/CameraVisibilityBubble.gd").new()
	if OS.get_environment("STORY_TEST_ORIGINAL_VISIBILITY") == "1":
		return preload("res://tests/fixtures/september12/VisibilityBefore.gd").new()
	return CameraVisibilityBubble.new()

func test_receiver_world_tracks_actual_mesh_owners_and_releases_evicted_sources() -> void:
	var view := SubViewport.new()
	view.own_world_3d = true
	view.size = Vector2i(320,200)
	add_child_autofree(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(0,12,20)
	camera.look_at(Vector3.UP)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.add_to_group("tactical_solid_earth")
	view.add_child(ground)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = PlaneMesh.new()
	batch.multimesh.instance_count = 1
	batch.add_to_group("tactical_solid_earth")
	view.add_child(batch)
	# Another viewport's ground must never enter this camera's proof.
	var foreign_view := SubViewport.new()
	foreign_view.own_world_3d = true
	add_child_autofree(foreign_view)
	var foreign := MeshInstance3D.new()
	foreign.mesh = PlaneMesh.new()
	foreign.add_to_group("tactical_solid_earth")
	foreign_view.add_child(foreign)
	var receiver := preload("res://scripts/camera/VisibilityGroundDepth.gd").new()
	view.add_child(receiver)
	receiver.update_view(camera,Vector3.ZERO,16)
	assert_eq(receiver._owners.size(),2,"Only actual ground in this camera world is mirrored")
	assert_eq(receiver._front_owners.size(),2,"First-surface masks use the same actual world owners")
	assert_same(receiver._owners[ground.get_instance_id()].mesh,ground.mesh,"Shares actual ground, without generating replacement geometry")
	assert_same(receiver._owners[batch.get_instance_id()].multimesh,batch.multimesh,"Shares the live native buffer without a copy/readback")
	assert_same(receiver._front_owners[batch.get_instance_id()].multimesh,batch.multimesh,"First-surface masking also shares the native buffer")
	ground.mesh = PlaneMesh.new()
	ground.position = Vector3(4,5,6)
	receiver.update_view(camera,Vector3.ZERO,16)
	assert_same(receiver._owners[ground.get_instance_id()].mesh,ground.mesh,"A republished terrain mesh replaces the previous proof")
	assert_eq(receiver._owners[ground.get_instance_id()].global_transform,ground.global_transform)
	assert_same(receiver._front_owners[ground.get_instance_id()].mesh,ground.mesh)
	assert_eq(receiver._front_owners[ground.get_instance_id()].global_transform,ground.global_transform)
	ground.hide()
	receiver.update_view(camera,Vector3.ZERO,16)
	assert_eq(receiver._owners.size(),1,"Hidden ground cannot back a reveal")
	assert_eq(receiver._front_owners.size(),1)
	batch.free()
	receiver.update_view(camera,Vector3.ZERO,16)
	assert_eq(receiver._owners.size(),0,"Evicted chunks release their proxy and shared buffer owner")
	assert_eq(receiver._front_owners.size(),0)
	receiver.free()

func test_grass_on_raised_receiver_survives_foreground_bank_removal() -> void:
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
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,12,20)
	camera.look_at(Vector3.UP)
	camera.make_current()
	var target := Node3D.new()
	world.add_child(target)
	var bank: MeshInstance3D
	for location: Vector3 in [Vector3(0,4,-8.5),Vector3(0,8,16.5)]:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(40,27 if location.y==4 else 23)
		ground.mesh = plane
		ground.position = location
		ground.add_to_group("tactical_solid_earth")
		ground.material_override = CliffDressing.shared_material()
		world.add_child(ground)
		if location.y==8: bank = ground
	var blades := MultiMeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5,2)
	blades.multimesh = MultiMesh.new()
	blades.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	blades.multimesh.mesh = quad
	blades.multimesh.instance_count = 2
	blades.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(0,5,-5)))
	# Real grass batches span both sides of a bank. The second patch lies
	# outside the image but makes this the same mixed foreground/background case.
	blades.multimesh.set_instance_transform(1,Transform3D(Basis.IDENTITY,Vector3(20,9,15)))
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type spatial; render_mode unshaded,cull_disabled;\n#define TACTICAL_TERRAIN_MATERIAL\n#define TACTICAL_GRASS_ROOT\nvarying vec3 tactical_grass_root;\nvoid vertex(){tactical_grass_root=(MODEL_MATRIX*vec4(0,-1,0,1)).xyz;}\nvoid fragment(){ALBEDO=vec3(0,1,0); }"
	blades.material_override = material
	world.add_child(blades)
	var bubble := _bubble()
	world.add_child(bubble)
	for frame in 12:
		bubble.update_bubble(camera,target,Vector3.ZERO,16,0,.1)
		await get_tree().process_frame
	var actual := await _frame(view)
	# Independent original-material reference retains the same softened bank.
	# The bank legitimately covers eight lower-edge pixels, so removing it
	# entirely would wrongly demand transparency through that feather too.
	blades.material_override = material
	var expected := await _frame(view)
	expected.save_png("/tmp/sept13-grass-expected.png")
	actual.save_png("/tmp/sept13-grass-actual.png")
	var expected_green := 0
	var lost_green := 0
	for y in 200:
		for x in 320:
			var reference := expected.get_pixel(x,y)
			if reference.g>.9 and reference.r<.1 and reference.b<.1:
				expected_green += 1
				var pixel := actual.get_pixel(x,y)
				if pixel.g<.9 or pixel.r>.1 or pixel.b>.1: lost_green += 1
	assert_gt(expected_green,40,"The raised clearing supplies visible ground cover")
	assert_eq(lost_green,0,"Removing the bank preserves grass rooted on the raised receiver behind it")
	bubble.clear()

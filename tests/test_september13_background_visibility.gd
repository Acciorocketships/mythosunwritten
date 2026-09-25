extends GutTest

func _frame(view: SubViewport) -> Image:
	for frame in 4: await get_tree().process_frame
	RenderingServer.force_draw(false)
	return view.get_texture().get_image()

func test_background_house_survives_foreground_house_in_same_native_batch() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires native GPU rendering")
		return
	for turn in 4:
		await _check_background(turn)

func _check_background(turn: int) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(480,300)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(view)
	var world := Node3D.new()
	world.rotation.y = turn * PI * .5
	view.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,12,20)
	camera.look_at(Vector3.UP)
	camera.fov = 65
	camera.make_current()
	var target := Node3D.new()
	world.add_child(target)
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
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60,-30,0)
	world.add_child(sun)
	var bare := await _frame(view)
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var background := Node3D.new()
	world.add_child(background)
	var payload := EnvironmentInstancePayload.new()
	var asset := &"lpfv.building.house.03"
	payload.add(asset,Transform3D(Basis.IDENTITY,Vector3(0,0,-10)),Color.WHITE)
	var queue := EnvironmentCommitQueue.new(cache,&"Houses")
	queue.register_chunk(Vector2i.ZERO,1)
	queue.enqueue(Vector2i.ZERO,1,background,payload)
	queue.drain(1000)
	# Keep native material conversion identical in the independent reference;
	# only the foreground house and cutaway strength differ.
	var reference_bubble := _bubble()
	world.add_child(reference_bubble)
	for frame in 12:
		reference_bubble.update_bubble(camera,target,Vector3.ZERO,16,0,.1)
		await get_tree().process_frame
	for id: int in reference_bubble._active:
		instance_from_id(id).set_instance_shader_parameter("tactical_strength",0.0)
	var expected := await _frame(view)
	reference_bubble.clear()
	reference_bubble.free()
	background.hide()
	# Both houses now share each native piece's MultiMesh and material.
	payload.add(asset,Transform3D(Basis.IDENTITY,Vector3(0,0,2)),Color.WHITE)
	queue.enqueue(Vector2i.ZERO,1,world,payload)
	queue.drain(1000)
	var before := await _frame(view)
	var bubble := _bubble()
	world.add_child(bubble)
	for frame in 16:
		bubble.update_bubble(camera,target,Vector3.ZERO,16,0,.1)
		await get_tree().process_frame
	var after := await _frame(view)
	var background_pixels := 0
	var damaged := 0
	var obstructed := 0
	for y in range(40,180):
		for x in range(175,305):
			var reference := expected.get_pixel(x,y)
			if reference == bare.get_pixel(x,y): continue
			background_pixels += 1
			if _different(before.get_pixel(x,y),reference): obstructed += 1
			if _different(after.get_pixel(x,y),reference): damaged += 1
	assert_gt(background_pixels,500,"Reference contains a complete background house")
	assert_gt(obstructed,100,"Foreground house obstructs the reference")
	assert_eq(damaged,0,"Revealing the foreground preserves the background house, including its roof and walls")
	# At the feather, each ray must show either the original closed exterior
	# or the independently rendered scene behind it, never an interior layer.
	for id: int in bubble._active:
		instance_from_id(id).set_instance_shader_parameter("tactical_strength",0.0)
	var opaque := await _frame(view)
	for radius: float in [3.0,6.0,9.0]:
		for frame in 12:
			bubble.update_bubble(camera,target,Vector3.ZERO,radius,0,.1)
			await get_tree().process_frame
		var edge := await _frame(view)
		var interiors := 0
		var revealed := 0
		for y in view.size.y:
			for x in view.size.x:
				var color := edge.get_pixel(x,y)
				if _different(color,opaque.get_pixel(x,y)):
					revealed += 1
					if _different(color,expected.get_pixel(x,y)): interiors += 1
		assert_gt(revealed,100,"Boundary control actually reveals the foreground")
		assert_eq(interiors,0,"Feather rays retain the closed exterior or show context, radius %s yaw %s" % [radius,turn])
	DirAccess.make_dir_recursive_absolute("/tmp/sept13-background-test")
	expected.save_png("/tmp/sept13-background-test/expected.png")
	before.save_png("/tmp/sept13-background-test/before.png")
	after.save_png("/tmp/sept13-background-test/after.png")
	bubble.clear()
	view.queue_free()
	await get_tree().process_frame

func _bubble() -> Node:
	if OS.get_environment("STORY_TEST_ORIGINAL_VISIBILITY") == "1":
		return preload("res://tests/fixtures/september13/background_before/CameraVisibilityBubble.gd").new()
	return CameraVisibilityBubble.new()

func test_visibility_owners_survive_payload_copy_and_chunk_projection() -> void:
	var source := EnvironmentInstancePayload.new()
	var first := AABB(Vector3(-6,2,-4),Vector3(10,8,7))
	var second := AABB(Vector3(14,5,3),Vector3(6,3,9))
	source.add(&"house",Transform3D.IDENTITY,Color.RED,&"a",true,first)
	source.add(&"house",Transform3D(Basis.IDENTITY,Vector3(20,0,5)),Color.BLUE,&"b",false,second)
	var copy := source.duplicate_payload()
	assert_eq(copy.batches[&"house"].visibility_owners,[first,second])
	var chunk := EnvironmentInstancePayload.new()
	chunk.append_from(copy,Rect2(Vector2(10,0),Vector2(20,20)))
	assert_true(chunk.validate())
	assert_eq(chunk.batches[&"house"].visibility_owners,[second])
	assert_eq(chunk.batches[&"house"].ids,[&"b"])
	assert_eq(chunk.batches[&"house"].colors,[Color.BLUE])
	assert_eq(chunk.batches[&"house"].collision_enabled,[false])

func test_roof_overhang_keeps_its_supporting_rooms_visibility_owner() -> void:
	var plan := SettlementFabricPlan.new(&"roof-owner")
	var room_recipe := FabricRecipe.new(&"room",[&"room"],0)
	var roof_recipe := FabricRecipe.new(&"roof",[&"roof"],1)
	plan._recipes = {&"room":room_recipe, &"roof":roof_recipe}
	var room := FabricUnit.new(&"room-a",&"room",Vector3i.ZERO,0)
	room.bounds = AABB(Vector3(-3,0,-9),Vector3(6,4,6))
	var roof := FabricUnit.new(&"roof-a",&"roof",Vector3i.ZERO,0,[&"room-a"])
	roof.bounds = AABB(Vector3(-4,4,-10),Vector3(8,3,11))
	plan._by_id = {&"room-a":room,&"roof-a":roof}
	assert_eq(plan.visibility_owner_bounds(room),room.bounds)
	assert_eq(plan.visibility_owner_bounds(roof),room.bounds,
		"A roof extending across the actor plane stays with its background room")

func test_offset_storeys_share_their_inhabited_enclosure_but_not_other_buildings() -> void:
	var plan := SettlementFabricPlan.new(&"enclosure")
	plan._recipes = {&"room":FabricRecipe.new(&"room",[&"room"],0),&"roof":FabricRecipe.new(&"roof",[&"roof"],0)}
	var lower := FabricUnit.new(&"lower",&"room",Vector3i.ZERO,0)
	lower.bounds = AABB(Vector3(-3,0,-9),Vector3(6,4,6))
	lower.visibility_enclosure_id = &"house-a"
	var upper := FabricUnit.new(&"upper",&"room",Vector3i.ZERO,0)
	upper.bounds = AABB(Vector3(-3,4,-5),Vector3(6,4,6))
	upper.visibility_enclosure_id = &"house-a"
	var other := FabricUnit.new(&"other",&"room",Vector3i.ZERO,0)
	other.bounds = AABB(Vector3(-3,0,-20),Vector3(6,4,6))
	other.visibility_enclosure_id = &"house-b"
	var roof := FabricUnit.new(&"roof",&"roof",Vector3i.ZERO,0,[&"lower"])
	roof.bounds = lower.bounds
	plan.units.assign([lower,upper,other,roof])
	plan._by_id = {&"lower":lower,&"upper":upper,&"other":other,&"roof":roof}
	var enclosure := lower.bounds.merge(upper.bounds)
	assert_eq(plan.visibility_owner_bounds(lower),enclosure)
	assert_eq(plan.visibility_owner_bounds(upper),enclosure)
	assert_eq(plan.visibility_owner_bounds(roof),enclosure)
	assert_eq(plan.visibility_owner_bounds(other),other.bounds)

func _different(a: Color,b: Color) -> bool:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) > .012

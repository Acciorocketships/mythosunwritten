extends GutTest
const TERRACES := preload("res://scripts/terrain/field/CliffTerraces.gd")

func test_only_exposed_native_terrace_top_can_be_a_ground_receiver() -> void:
	await _check_receiver(0.0)

func test_native_terrace_burial_in_rotated_terrain() -> void:
	for angle: float in [PI*.5,PI,PI*1.5]:
		await _check_receiver(angle)

func test_burial_uses_solid_terrain_across_visual_lip_gaps() -> void:
	await _check_receiver(0.0,true)

func _check_receiver(angle: float, visual_gap := false) -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires actual native depth rendering")
		return
	var view := SubViewport.new()
	view.size = Vector2i(480,300)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(view)
	var world := Node3D.new()
	view.add_child(world)
	var terrain_shapes: Array[CollisionShape3D] = []
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,10,20)
	camera.look_at(Vector3(0,1,-2))
	camera.fov = 50
	camera.make_current()
	for specification: Vector3 in [Vector3(0,0,-20),Vector3(0,6,20)]:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(40,40)
		ground.mesh = plane
		ground.position = specification
		ground.add_to_group("tactical_solid_earth")
		world.add_child(ground)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = plane.create_trimesh_shape()
		shape.position = specification
		shape.add_to_group("tactical_terrain_volume")
		terrain_shapes.append(shape)
		body.add_child(shape)
		world.add_child(body)
		if visual_gap and specification.y > 0: ground.visible = false
	TERRACES.prepare()
	var asset := &"kaykit.terrace.4x4x2"
	var bounds := EnvironmentCatalog.load_default().descriptor(asset).measured_aabb
	var transform := Transform3D(Basis.IDENTITY,Vector3(0,-bounds.position.y,0))
	world.add_child(TERRACES.build({"placements":[{"asset":asset,"transform":transform}]},2697992464))
	world.rotation.y = angle
	var receiver := preload("res://scripts/camera/VisibilityGroundDepth.gd").new()
	world.add_child(receiver)
	for frame in 12:
		receiver.update_view(camera,world.to_global(Vector3(0,bounds.size.y,-2)),14)
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	var depths := receiver.texture().get_image()
	var exposed := 0
	var buried := 0
	for y in view.size.y:
		for x in view.size.x:
			var bytes := depths.get_pixel(x,y)
			var depth := (roundf(bytes.r*255)+roundf(bytes.g*255)*256+roundf(bytes.b*255)*65536)*.001
			if depth <= 0: continue
			var ray := camera.project_ray_normal(Vector2(x+.5,y+.5))
			var point := world.to_local(camera.global_position+ray*(depth/(-camera.global_basis.z.dot(ray))))
			if point.y < bounds.size.y-.08 or point.y > bounds.size.y+.08: continue
			if point.z > .08: buried += 1
			elif point.z < -.08: exposed += 1
	assert_gt(exposed,20,"The actual exposed native cap remains a useful receiver")
	assert_eq(buried,0,"Buried native cap cannot appear through the overlying terrain")
	var source_faces: PackedVector3Array = (terrain_shapes[1].shape as ConcavePolygonShape3D).get_faces()
	var owner_id := terrain_shapes[1].get_instance_id()
	var proof_mesh: Mesh = receiver._terrain_owners[owner_id].mesh
	receiver.update_view(camera,world.to_global(Vector3(0,bounds.size.y,-2)),14)
	assert_same(receiver._terrain_owners[owner_id].mesh,proof_mesh,"Stable terrain reuses the CPU-derived proof mesh")
	terrain_shapes[1].disabled = true
	receiver.update_view(camera,world.to_global(Vector3(0,bounds.size.y,-2)),14)
	assert_false(receiver._terrain_owners.has(owner_id),"Disabled terrain immediately loses burial authority and its private mesh")
	assert_eq((terrain_shapes[1].shape as ConcavePolygonShape3D).get_faces(),source_faces,"Visibility leaves the actual physical terrain unchanged")

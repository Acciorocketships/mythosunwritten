extends GutTest
const Marker := preload("res://scripts/camera/OccludedActor.gd")

func test_actor_depth_separates_self_occlusion_from_a_real_obstacle() -> void:
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
	camera.position = Vector3(0,3,10)
	camera.look_at(Vector3(0,1,0))
	var actor := Node3D.new()
	world.add_child(actor)
	for offset: Vector3 in [Vector3(0,1,0),Vector3(0,2,.4)]:
		var mesh := MeshInstance3D.new()
		mesh.mesh = SphereMesh.new()
		mesh.position = offset
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(.2,.1,.4)
		mesh.material_override = material
		actor.add_child(mesh)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(5,5,.5)
	wall.mesh = box
	wall.position = Vector3(0,1,4)
	var wall_material := StandardMaterial3D.new()
	wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall_material.albedo_color = Color(.2,.5,.1)
	wall.material_override = wall_material
	wall.visible = false
	world.add_child(wall)
	var original := await _frame(view)
	var marker := Marker.new()
	add_child_autofree(marker)
	marker.update_actor(camera,actor)
	var visible := await _frame(view)
	assert_true(original.get_data() == visible.get_data(),"Fully visible overlapping body parts remain pixel-identical")
	marker.clear()
	wall.visible = true
	var blocked := await _frame(view)
	marker.update_actor(camera,actor)
	var revealed := await _frame(view)
	var changed := 0
	var outside := 0
	for y in view.size.y:
		for x in view.size.x:
			if blocked.get_pixel(x,y) != revealed.get_pixel(x,y):
				changed += 1
				if x < 125 or x > 195 or y < 50 or y > 135: outside += 1
	assert_gt(changed,150,"Occluded character has a readable visible marker")
	assert_eq(outside,0,"The marker never opens or paints the surrounding ground")
	marker.clear()
	assert_eq(camera.cull_mask,1048575,"Camera render layers restored")
	for mesh: MeshInstance3D in actor.get_children():
		assert_eq(mesh.layers,1,"Actor source layers restored")
		assert_null(mesh.material_overlay,"Actor materials remain authored")
	var restored := await _frame(view)
	assert_true(blocked.get_data() == restored.get_data(),"Clearing marker restores original rendering")
	# Camera/world moves and scene teardown must not free children while the
	# engine is traversing their exit notifications (the first motion replay
	# reproduced a native crash at precisely this boundary).
	marker.reparent(camera)
	marker.update_actor(camera,actor)
	var second_view := SubViewport.new()
	second_view.own_world_3d = true
	add_child_autofree(second_view)
	world.reparent(second_view)
	assert_null(marker._camera,"Leaving the original world releases marker ownership")
	await get_tree().process_frame
	marker.update_actor(camera,actor)
	assert_same(marker._view.world_3d,camera.get_world_3d(),"Re-entered marker shares the new camera world")
	marker.clear()

func _frame(view: SubViewport) -> Image:
	for i in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

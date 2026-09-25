extends GutTest

func test_production_photo_ramp_uses_the_reviewed_plank_material() -> void:
	var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/37-barrel/after-payload.bin",FileAccess.READ).get_var()
	var queue := FeatureCommitQueue.new(EnvironmentRenderCache.new(EnvironmentCatalog.load_default()))
	var block := Node3D.new()
	add_child_autofree(block)
	var tested := 0
	for mesh: Dictionary in data.surface_meshes:
		if not bool(mesh.get("is_transition",false)): continue
		queue.commit_mesh_visual(block,mesh)
		var visual := block.get_node("Visuals").get_child(tested) as MeshInstance3D
		var material := visual.mesh.surface_get_material(0)
		assert_true(material is ShaderMaterial,"Production transition %s must retain its plank pattern"%mesh.stable_id)
		var arrays := visual.mesh.surface_get_arrays(0)
		assert_eq(arrays[Mesh.ARRAY_VERTEX],mesh.vertices,"Assigning a finish cannot move a floor")
		assert_eq(arrays[Mesh.ARRAY_TEX_UV],mesh.uvs,"Preserve the metric plank registration")
		tested += 1
	assert_gt(tested,0,"The photo's generated ramps must be exercised")

func test_transition_material_is_shared_with_native_review() -> void:
	var mesh := WarrenTransitionSurfaceBuilder._empty_payload(&"material-control",[] as Array[Vector3i])
	WarrenTransitionSurfaceBuilder._append_ramp(mesh,Vector3.ZERO,Vector3(0,1,3),Vector3.RIGHT)
	var block := Node3D.new()
	add_child_autofree(block)
	FeatureCommitQueue.new(EnvironmentRenderCache.new(EnvironmentCatalog.load_default())).commit_mesh_visual(block,mesh)
	var visual := block.get_node("Visuals").get_child(0) as MeshInstance3D
	assert_same(visual.mesh.surface_get_material(0),SettlementFabricAssembler._surface_material(PublicRealmSurfacePlan.SurfaceKind.STAIR),"Review and production must use the same material owner")

func test_board_registration_tracks_full_width_and_run_in_four_directions() -> void:
	for side in 4:
		var turn := Basis(Vector3.UP,side*PI/2)
		var start := turn*Vector3(0,0,-3)
		var end := turn*Vector3(0,1.5,3)
		var mesh := WarrenTransitionSurfaceBuilder._empty_payload(&"uv-control",[] as Array[Vector3i])
		WarrenTransitionSurfaceBuilder._append_ramp(mesh,start,end,turn*Vector3.RIGHT)
		var uv: PackedVector2Array = mesh.uvs
		assert_almost_eq(uv[0].y,uv[1].y,.00001,"One board spans the whole hallway")
		assert_almost_eq(absf(uv[1].x-uv[0].x),1.0,.00001,"Full-width registration is three local metres")
		assert_almost_eq(absf(uv[3].y-uv[0].y),start.distance_to(end)/3,.00001,"Board width follows surface distance, not camera or world heading")

func test_photo_payload_changes_only_transition_uvs() -> void:
	var path := "res://docs/qa/2026-09-13-manual/38-floor/"
	var before: Dictionary = FileAccess.open(path+"before-payload.bin",FileAccess.READ).get_var()
	var after: Dictionary = FileAccess.open(path+"after-payload.bin",FileAccess.READ).get_var()
	assert_eq(before.batches,after.batches,"No native asset or transform changes")
	assert_eq(before.collision_boxes,after.collision_boxes)
	assert_eq(before.walked,after.walked)
	assert_eq(before.surface_meshes.size(),after.surface_meshes.size())
	for index in before.surface_meshes.size():
		var a: Dictionary = before.surface_meshes[index].duplicate()
		var b: Dictionary = after.surface_meshes[index].duplicate()
		a.erase("uvs")
		b.erase("uvs")
		assert_eq(a,b,"Surface %d retains every vertex, normal, triangle and collision face"%index)

func test_native_planks_survive_camera_material_adaptation() -> void:
	if DisplayServer.get_name()=="headless":
		pending("Requires native rendering")
		return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(384,256)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.15,.15,.15)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=1
	world.add_child(env)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=8
	world.add_child(camera)
	camera.make_current()
	var output := "res://docs/qa/2026-09-13-manual/38-floor/gpu"
	DirAccess.make_dir_recursive_absolute(output)
	for stairs: bool in [false,true]:
		for side in 4:
			var turn := Basis(Vector3.UP,side*PI/2)
			camera.position=turn*Vector3(4,7,8)
			camera.look_at(Vector3(0,.75,0))
			var mesh := WarrenTransitionSurfaceBuilder._empty_payload(&"gpu-control",[] as Array[Vector3i])
			var start := turn*Vector3(0,0,-3)
			var end := turn*Vector3(0,1.5,3)
			if stairs: WarrenTransitionSurfaceBuilder._append_stairs(mesh,start,end,turn*Vector3.BACK,turn*Vector3.RIGHT)
			else: WarrenTransitionSurfaceBuilder._append_ramp(mesh,start,end,turn*Vector3.RIGHT)
			var block := Node3D.new()
			world.add_child(block)
			FeatureCommitQueue.new(EnvironmentRenderCache.new(EnvironmentCatalog.load_default())).commit_mesh_visual(block,mesh)
			var visual := block.get_node("Visuals").get_child(0) as MeshInstance3D
			var original := await _frame(viewport)
			var plain := StandardMaterial3D.new()
			plain.albedo_color=Color(.68,.52,.34)
			visual.material_override=plain
			var flat := await _frame(viewport)
			visual.material_override=null
			var bubble := CameraVisibilityBubble.new()
			world.add_child(bubble)
			bubble._active[visual.get_instance_id()]=bubble._install(visual)
			var adapted := await _frame(viewport)
			var difference := _pixel_difference(original,adapted)
			assert_lte(difference.maximum,1,"Adapter differences stay within one 8-bit quantization step")
			assert_lt(difference.mean,.001,"Inactive cutaway preserves the rendered plank pattern")
			assert_true(original.get_data()!=flat.get_data(),"The pattern visibly differs from the missing-material control")
			bubble.clear()
			var restored := await _frame(viewport)
			assert_true(original.get_data()==restored.get_data(),"Material release restores the same pixels")
			var name := "%s_%d"%["stairs" if stairs else "ramp",side]
			original.save_png(output.path_join(name+".png"))
			adapted.save_png(output.path_join(name+"_adapted.png"))
			flat.save_png(output.path_join(name+"_flat.png"))
			bubble.free()
			block.free()

func _frame(viewport: SubViewport) -> Image:
	for frame in 5: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _pixel_difference(a: Image, b: Image) -> Dictionary:
	var left := a.get_data()
	var right := b.get_data()
	var maximum := 0
	var total := 0
	for index in left.size():
		var difference := absi(int(left[index])-int(right[index]))
		maximum=maxi(maximum,difference)
		total+=difference
	return {"maximum":maximum,"mean":float(total)/left.size()}

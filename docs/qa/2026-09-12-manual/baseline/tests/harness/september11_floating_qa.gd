extends "res://tests/harness/september11_bubble_qa.gd"

## Rejected compact-knees-only trial. Its strict unchanged-layout assertions
## intentionally refuse the final composition repair. Final live evidence uses
## september11_floating_world_qa.tscn; native pairs use floating_native.gd.

func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	_camera = get_viewport().get_camera_3d()
	_camera.set_physics_process(false)
	_camera.set_process_input(false)
	_camera.set_process_unhandled_input(false)
	_camera._visibility.clear()
	var world := _character.get_parent().get_parent()
	_capture_view = SubViewport.new()
	_capture_view.size = Vector2i(1920,1080)
	_capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_capture_view)
	_show_capture_view()
	world.reparent(_capture_view)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	_camera.make_current()
	_character.anim_tree.active = false
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september11-floating-source.txt"),program)
	var plan := spatial.compiled_fabric_cache()
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-11-manual/05-floating/probe-before.json"))
	var world_pose := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*2),Vector3(-409.5,13.08,-263.5))
	assert(plan.units.size() == baseline.units.size(), "Snapshot delta requires unchanged unit ownership")
	var payload := EnvironmentInstancePayload.new()
	var added := []
	for row: Dictionary in baseline.units:
		var unit := plan.unit(StringName(row.id))
		assert(unit != null and String(unit.recipe_id) == row.recipe)
		assert(str(world_pose*unit.transform()) == row.world)
		var expected_suppressed: Array[StringName] = []
		for value: String in row.suppressed: expected_suppressed.append(StringName(value))
		assert(unit.suppressed_placement_ids == expected_suppressed,
			"%s suppression differs: %s vs %s" % [unit.stable_id,unit.suppressed_placement_ids,expected_suppressed])
		if not String(unit.recipe_id).begins_with("outcrop.support.bracketed."): continue
		for placement: Dictionary in plan.recipe(unit.recipe_id).placements:
			var pose: Transform3D = world_pose*unit.transform()*placement.transform
			var id := StringName("%s/%s" % [unit.stable_id,placement.id])
			payload.add(placement.asset_id,pose,Color.WHITE,id)
			added.append({"id":id,"asset":placement.asset_id,"world":str(pose)})
	var additions := Node3D.new()
	world.add_child(additions)
	var cache := EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	var queue := FeatureCommitQueue.new(cache)
	queue.enqueue(Vector2i.ZERO,1,additions,payload)
	while queue.pending_count()>0:
		queue.drain(100000,100000,100000)
		await get_tree().process_frame
	var output := _output_dir
	var poses := []
	for spot: Array in _spots():
		if spot[0] not in ["03_block","04_village"]: continue
		_character.global_position = spot[2]
		_character.step_visual_offset_y = 0.0
		_character._update_step_visual_smoothing(0.0)
		var eye := ReviewCam.solve_cam(spot[2],spot[3],26,16,1)
		for angle: float in [0.0,-8.0,8.0]:
			_camera.global_position = Vector3(spot[2])+(eye-Vector3(spot[2])).rotated(Vector3.UP,deg_to_rad(angle))
			_camera.look_at(Vector3(spot[2])+Vector3.UP)
			poses.append({"spot":spot[0],"angle":angle,"camera":str(_camera.global_transform)})
			for after: bool in [false,true]:
				additions.visible = after
				var bubble := CameraVisibilityBubble.new()
				add_child(bubble)
				for frame in 12:
					bubble.update_bubble(_camera,_character,spot[2],CameraVisibilityBubble.screen_radius(_camera,spot[2]),.12,.1)
					await get_tree().process_frame
				_output_dir = output.path_join("after" if after else "before")
				DirAccess.make_dir_recursive_absolute(_output_dir)
				await _shot("%s_%d" % [spot[0],int(angle)])
				bubble.clear()
				bubble.free()
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	FileAccess.open(output.path_join("added-native-supports.json"),FileAccess.WRITE).store_string(JSON.stringify(added,"  "))
	_streamer.free()
	get_tree().quit()

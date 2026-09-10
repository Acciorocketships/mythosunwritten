extends "res://tests/harness/september9_orb_replay.gd"

# Controlled lighting study: identical real geometry under each pure profile.
# World-space mist retains its original geography; this is not a biome-location survey.
func _run(camera: Camera3D, fixture: String) -> void:
	DirAccess.make_dir_recursive_absolute(_report)
	var director := AtmosphereDirector.new()
	director.environment_node = _world.get_node("WorldEnvironment")
	director.sun = _world.get_node("DirectionalLight3D")
	director.camera = camera
	director._apply_grade()
	var ids := {"sfv_light_pole_001_00":&"sfv.light_pole.001",
		"lpfv_fabric_prop_lantern_post_02_00":&"lpfv.fabric.prop.lantern.post.02",
		"lpfv_fabric_prop_lantern_table_01_00":&"lpfv.fabric.prop.lantern.table.01"}
	var lamp_count := 0
	if FileAccess.file_exists("res://scripts/terrain/environment/EnvironmentLanternLights.gd"):
		var adapter = load("res://scripts/terrain/environment/EnvironmentLanternLights.gd")
		var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
		for node: MultiMeshInstance3D in _world.find_children("*","MultiMeshInstance3D",true,false):
			if not ids.has(String(node.name)):continue
			var asset_id: StringName = ids[String(node.name)]
			var piece := cache.visual(asset_id).pieces[0]
			node.material_override = adapter.glass_material(asset_id,piece)
			var inverse := piece.local_transform.affine_inverse()
			var poses: Array = []
			for i in node.multimesh.instance_count:
				poses.append(node.transform*node.multimesh.get_instance_transform(i)*inverse)
			adapter.attach(node.get_parent(),asset_id,poses)
			lamp_count += poses.size()
	for orb in _orbs:
		orb.elapsed = 0.0
		orb._process(0.0)
		orb.force_update_transform()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var original := camera.global_transform
	var town: Vector3 = _orbs[5].get_parent().to_global(_orbs[5].anchor)
	for id: StringName in BiomeRegistry.biome_ids():
		if director.has_method("_apply_mood"):
			director.set("_mood_weights",{})
			director.call("_update_mood",0.0,{id:1.0})
		for view in ["landscape","town"]:
			camera.global_transform = original
			if view=="town":
				camera.global_position=town+Vector3(6,4,9)
				camera.look_at(town,Vector3.UP)
			await get_tree().create_timer(0.5).timeout
			RenderingServer.force_draw()
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(_report+"/%s_%s.png"%[id,view])
			var gpu: Array[float] = []
			var frames: Array[float] = []
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
			var last := Time.get_ticks_usec()
			for sample in 60:
				await get_tree().process_frame
				var now := Time.get_ticks_usec()
				frames.append(float(now-last)/1000.0)
				last=now
				if director.has_method("_update_mood"): director.call("_update_mood",1.0/60.0,{id:1.0})
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
			gpu.sort()
			frames.sort()
			Engine.max_fps = 30
			_rows.append({"frame_median_ms":frames[30],"frame_p95_ms":frames[57],"gpu_median_ms":gpu[30],"gpu_p95_ms":gpu[57],"biome":String(id),"view":view,"camera":str(camera.global_transform),
				"ambient_energy":director.environment_node.environment.ambient_light_energy,
				"sun_energy":director.sun.light_energy,"lamp_count":lamp_count})
	FileAccess.open(_report+"/moods.json",FileAccess.WRITE).store_string(JSON.stringify({"fixture":fixture,"sha256":FileAccess.get_sha256(fixture),"rows":_rows},"  "))
	director.free()
	_orbs.clear()
	_world.free()
	await get_tree().process_frame
	get_tree().quit()

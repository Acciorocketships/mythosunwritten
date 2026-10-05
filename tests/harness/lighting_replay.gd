extends "res://tests/harness/atmosphere_review.gd"
## Replay a frozen production capture to iterate lighting without regenerating
## terrain. Streaming, live water and biome travel still require the live harness.

func _ready() -> void:
	_read_args()
	_setup_capture_view()
	_run_replay.call_deferred()

func _run_replay() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--replay")
	if at < 0 or at + 1 >= args.size():
		push_error("Lighting replay requires --replay <world.scn>")
		get_tree().quit(1)
		return
	var packed := load(args[at + 1]) as PackedScene
	if packed == null:
		get_tree().quit(1)
		return
	var world := packed.instantiate() as Node3D
	var density_arg := args.find("--mist-density")
	if density_arg >= 0 and density_arg + 1 < args.size():
		_review_density(world, float(args[density_arg + 1]))
	preload("res://tests/harness/september9_render_fixture.gd").restore_native_adapter_parameters(world, {})
	var lower_scale := args.find("--mist-lower-scale")
	var upper_scale := args.find("--mist-upper-scale")
	if lower_scale >= 0 or upper_scale >= 0:
		_scale_mist_layers(world,
			float(args[lower_scale + 1]) if lower_scale >= 0 and lower_scale + 1 < args.size() else 1.0,
			float(args[upper_scale + 1]) if upper_scale >= 0 and upper_scale + 1 < args.size() else 1.0)
	if args.has("--foundation-baseline"):
		_restore_foundation_cores(world)
	if args.has("--refresh-fx"):
		_refresh_frozen_fx(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var globals: Dictionary = world.get_meta("shader_globals", {})
	for key: StringName in globals:
		if globals[key] != null:
			RenderingServer.global_shader_parameter_set(key, globals[key])
	_capture_view.add_child(world)
	var camera := world.get_node_or_null("Camera3D") as Camera3D
	var environment_node := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := world.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var player_arg := args.find("--player")
	var crosshair_arg := args.find("--crosshair")
	var specified_position := Vector3.INF
	if player_arg >= 0 and crosshair_arg >= 0:
		var player_values := args[player_arg + 1].split(",")
		var crosshair_values := args[crosshair_arg + 1].split(",")
		assert(player_values.size() == 3 and crosshair_values.size() == 3)
		specified_position = Vector3(float(player_values[0]), float(player_values[1]), float(player_values[2]))
		var crosshair := Vector3(float(crosshair_values[0]), float(crosshair_values[1]), float(crosshair_values[2]))
		if camera == null:
			camera = Camera3D.new()
			world.add_child(camera)
		var distance_arg := args.find("--view-distance")
		var height_arg := args.find("--view-height")
		var distance := float(args[distance_arg + 1]) if distance_arg >= 0 and distance_arg + 1 < args.size() else 26.0
		var height := float(args[height_arg + 1]) if height_arg >= 0 and height_arg + 1 < args.size() else 16.0
		camera.global_position = ReviewCam.solve_cam(specified_position, crosshair, distance, height, 1)
		camera.look_at(specified_position + Vector3.UP)
	if camera == null or environment_node == null or sun == null:
		push_error("Replay needs the production camera, environment and sunlight")
		get_tree().quit(1)
		return
	camera.make_current()
	camera.environment = null
	var info: Dictionary = world.get_meta("lighting_review", {})
	_review_position = info.get("position", camera.global_position)
	if specified_position.is_finite():
		_review_position = specified_position
	var weights: Dictionary = info.get("biome_weights", Helper.biome_weights5(_review_position, REVIEW_SEED))
	if specified_position.is_finite():
		weights = Helper.biome_weights5(_review_position, int(info.get("seed", REVIEW_SEED)))
	var director := AtmosphereDirector.new()
	director.environment_node = environment_node
	director.sun = sun
	director.camera = camera
	director.quality = _quality
	add_child(director)
	director.set_process(false)
	director._apply_mood(BiomeRegistry.blend_atmosphere(weights))
	if args.has("--refresh-fx"): director._light_budget.update_lights(camera, _quality)
	if not args.has("--solid-canopy"):
		print("[lighting-replay] porous canopy proxies=", _attach_canopy_shadows(world))
	else:
		_restore_solid_canopies(world)
	if args.has("--sun-facing"):
		camera.global_position = _review_position + Vector3.UP * 2.0
		camera.look_at(camera.global_position + sun.global_basis.z * 30.0)
	var grass_density := AtmosphereDirector.ECONOMICAL_GRASS_DENSITY if _quality == 0 else 1.0
	var grass_fraction := args.find("--grass-fraction")
	if grass_fraction >= 0 and grass_fraction + 1 < args.size():
		grass_density = clampf(float(args[grass_fraction + 1]), 0.1, 1.0)
	_scale_grass_draws(world, grass_density / maxf(0.1, float(globals.get("grass_density_scale", 1.0))))
	RenderingServer.global_shader_parameter_set("grass_density_scale", grass_density)
	# Older snapshots lack the fourth numeric lookup. Rebuild the canonical map
	# for exploration, while clearly identifying legacy captures in the log.
	if not globals.has("biome_surface_map"):
		director._ground_map.update(_review_position, REVIEW_SEED)
		print("[lighting-replay] legacy geometry; fresh material lookup, not current terrain acceptance")
	var environment := environment_node.environment
	if args.has("--foundation-baseline"):
		environment.adjustment_enabled = false
		var defaults := Environment.new()
		environment.glow_blend_mode = defaults.glow_blend_mode
		for i in 7: environment.set_glow_level(i, defaults.get_glow_level(i))
		environment.glow_bloom = 0.035
		environment.glow_hdr_threshold = 1.15
		environment.glow_normalized = true
		environment.volumetric_fog_length = 256.0
		environment.volumetric_fog_ambient_inject = 0.45
		sun.shadow_blur = 2.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_split_1 = 0.3
		if float(weights.get(&"deep_forest", 0.0)) > 0.99: sun.light_volumetric_fog_energy = 2.2
	var fog_ambient_arg := args.find("--fog-ambient")
	if fog_ambient_arg >= 0 and fog_ambient_arg + 1 < args.size():
		environment.volumetric_fog_ambient_inject = float(args[fog_ambient_arg + 1])
	var fog_size_arg := args.find("--fog-size")
	if fog_size_arg >= 0 and fog_size_arg + 1 < args.size():
		RenderingServer.environment_set_volumetric_fog_volume_size(int(args[fog_size_arg + 1]), 128)
	var fog_length_arg := args.find("--fog-length")
	if fog_length_arg >= 0 and fog_length_arg + 1 < args.size():
		environment.volumetric_fog_length = float(args[fog_length_arg + 1])
	var anisotropy_arg := args.find("--anisotropy")
	if anisotropy_arg >= 0 and anisotropy_arg + 1 < args.size():
		environment.volumetric_fog_anisotropy = float(args[anisotropy_arg + 1])
	var scattering_arg := args.find("--sun-scattering")
	if scattering_arg >= 0 and scattering_arg + 1 < args.size():
		sun.light_volumetric_fog_energy = float(args[scattering_arg + 1])
		print("[lighting-replay] volumetric sun energy=", sun.light_volumetric_fog_energy)
	if _gi != "quality":
		environment.ssil_enabled = _gi == "ssil" or _gi == "combined"
		environment.sdfgi_enabled = _gi == "sdfgi" or _gi == "combined"
	environment.fog_enabled = not _disable_fog
	environment.volumetric_fog_enabled = _quality > 0 and not _disable_fog
	environment.glow_enabled = not _disable_glow
	if args.has("--no-ao"):
		environment.ssao_enabled = false
	var msaa_arg := args.find("--msaa")
	if msaa_arg >= 0 and msaa_arg + 1 < args.size():
		camera.get_viewport().msaa_3d = clampi(int(args[msaa_arg + 1]), 0, 3)
	if args.has("--fxaa"):
		camera.get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var scale_arg := args.find("--render-scale")
	if scale_arg >= 0 and scale_arg + 1 < args.size():
		camera.get_viewport().scaling_3d_scale = clampf(float(args[scale_arg + 1]), 0.5, 1.0)
		camera.get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	var grade := args.find("--grade")
	var grade_name := args[grade + 1] if grade >= 0 and grade + 1 < args.size() else "current"
	if grade_name == "contrast":
		environment.ambient_light_energy = maxf(0.24, environment.ambient_light_energy * 0.7)
		environment.glow_bloom = 0.012
		sun.shadow_opacity = 0.82
	elif grade_name == "side":
		# Compare directional form without also changing shadow fill or bloom.
		sun.rotation_degrees.y = -110.0
		sun.shadow_opacity = 0.82
	var sun_yaw := args.find("--sun-yaw")
	if sun_yaw >= 0 and sun_yaw + 1 < args.size():
		sun.rotation_degrees.y = float(args[sun_yaw + 1])
	RenderingServer.global_shader_parameter_set("atmosphere_sun_ray", -sun.global_basis.z)
	if _freeze_time >= 0.0:
		RenderingServer.global_shader_parameter_set("review_visual_time", _freeze_time)
	for frame in 90:
		await RenderingServer.frame_post_draw
	if _measure:
		await _measure_render(camera, environment)
	var result := camera.get_viewport().get_texture().get_image().save_png(_capture_path)
	print("[lighting-replay] source=", args[at + 1], " capture=", _capture_path, " result=", result)
	_save_scene_report(camera, weights, {"source": args[at + 1],
		"position": var_to_str(_review_position), "frozen_replay": true, "grass_density_scale": grass_density})
	var travel := args.find("--travel-end")
	if travel >= 0 and travel + 1 < args.size():
		var values := args[travel + 1].split(",")
		assert(values.size() == 2, "Travel endpoint is world x,z")
		await _capture_mood_travel(camera, director, _review_position,
			Vector3(float(values[0]), _review_position.y, float(values[1])))
	if _orbit:
		await _capture_orbit(camera, _review_position + Vector3.UP * 2.0, director)
	world.queue_free()
	director.queue_free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().quit(0 if result == OK else 1)

## A camera flight through fixed production geometry exercises the real spatial
## biome field, map scrolling and director easing. It does not simulate streaming,
## player grounding or the grass streaming ring; review those in the live harness.
func _capture_mood_travel(camera: Camera3D, director: AtmosphereDirector,
		start: Vector3, finish: Vector3) -> void:
	var frames := maxi(1, ceili(start.distance_to(finish) / 10.0 * 60.0))
	var original := camera.global_transform
	var records: Array[Dictionary] = []
	director._mood_weights.clear()
	director._update_mood(0.0, Helper.biome_weights5(start, REVIEW_SEED))
	# Nine seconds at the destination reveals lingering exposure/fog adaptation.
	for frame in frames + 541:
		var position := start.lerp(finish, minf(float(frame) / frames, 1.0))
		camera.global_position = original.origin + position - start
		director._ground_map.update(position, REVIEW_SEED)
		director._update_mood(1.0 / 60.0, Helper.biome_weights5(position, REVIEW_SEED))
		await RenderingServer.frame_post_draw
		if frame % 180 != 0 and frame != frames + 540:
			continue
		var path := "%s-travel-%04d.png" % [_capture_path.get_basename(), frame]
		var error := camera.get_viewport().get_texture().get_image().save_png(path)
		assert(error == OK)
		records.append({"frame": frame, "position": var_to_str(position),
			"weights": director._mood_weights.duplicate(),
			"sun_energy": director.sun.light_energy,
			"ambient_energy": director.environment_node.environment.ambient_light_energy,
			"map_centre": var_to_str(director._ground_map._centre), "image": path})
	var file := FileAccess.open(_capture_path.get_basename() + "-travel.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "frozen geometry camera flight",
		"speed_mps": 10.0, "step_seconds": 1.0 / 60.0, "frames": records}, "\t"))
	print("[lighting-replay] biome travel saved: ", _capture_path.get_basename())

func _attach_canopy_shadows(node: Node) -> int:
	var count := 0
	for child: Node in node.get_children():
		count += _attach_canopy_shadows(child)
	if node is MultiMeshInstance3D:
		if preload("res://scripts/terrain/biome/CanopyShadows.gd").attach(node) != null:
			count += 1
	return count

func _restore_solid_canopies(node: Node) -> void:
	if node is MultiMeshInstance3D and node.has_node("CanopyShadow"):
		node.get_node("CanopyShadow").free()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child: Node in node.get_children():
		_restore_solid_canopies(child)

func _review_density(node: Node, density: float) -> void:
	if node is FogVolume and node.material is ShaderMaterial:
		node.material.set_shader_parameter("review_density", density)
		node.material.set_shader_parameter("review_legacy_precision", OS.get_cmdline_user_args().has("--legacy-mist"))
	for child: Node in node.get_children():
		_review_density(child, density)

func _scale_grass_draws(node: Node, fraction: float) -> void:
	if node is MultiMeshInstance3D and node.has_meta(&"grass_count"):
		var mesh := node.multimesh as MultiMesh
		if mesh != null:
			var visible := mesh.visible_instance_count
			if visible < 0: visible = mesh.instance_count
			mesh.visible_instance_count = mini(mesh.instance_count, ceili(float(visible) * fraction))
	for child: Node in node.get_children():
		_scale_grass_draws(child, fraction)

func _scale_mist_layers(node: Node, lower: float, upper: float) -> void:
	if node is FogVolume and node.material is ShaderMaterial:
		var source := node.material as ShaderMaterial
		var texture := source.get_shader_parameter("mist_shape_field") as Texture2D
		if texture != null:
			var pixels := texture.get_image()
			for y in pixels.get_height():
				for x in pixels.get_width():
					var shape := pixels.get_pixel(x, y)
					shape.r *= maxf(0.01, lower)
					shape.b *= maxf(0.0, upper)
					pixels.set_pixel(x, y, shape)
			var material := source.duplicate() as ShaderMaterial
			material.set_shader_parameter("mist_shape_field", ImageTexture.create_from_image(pixels))
			node.material = material
	for child: Node in node.get_children():
		_scale_mist_layers(child, lower, upper)

func _process(dt: float) -> void:
	if OS.get_cmdline_user_args().has("--quick-capture"):
		if _capture_view != null and Time.get_ticks_usec() - _last_draw_usec > 100000:
			_forced_draws += 1
			RenderingServer.force_draw(false)
	else:
		super._process(dt)

func _refresh_frozen_fx(node: Node) -> void:
	# Frozen captures store source energies and numeric mist maps, not live recipes.
	if node is GeometryInstance3D:
		var mat: Material = node.material_override
		var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null)
		if mat == null and mesh != null and mesh.get_surface_count() > 0: mat = mesh.surface_get_material(0)
		if mat is ShaderMaterial and mat.shader != null and "orb_color" in mat.shader.code and "world_normal" in mat.shader.code:
			var fresh := mat.duplicate() as ShaderMaterial
			fresh.shader = preload("res://terrain/materials/spirit_orb_core.gdshader")
			node.material_override = fresh
	if node is OmniLight3D:
		if node.name == "SmallOrbLight" or node.name == "Light":
			SpiritOrb.configure_light(node, node.name == "SmallOrbLight")
		elif node.name == "LanternLight":
			node.light_energy *= 2.3
			node.light_volumetric_fog_energy = 2.0
			node.add_to_group("atmosphere_local_light")
			node.set_meta("atmosphere_shadow_candidate", true)
	if node is FogVolume and node.material is ShaderMaterial:
		var mat := node.material as ShaderMaterial
		var ground := (mat.get_shader_parameter("ground_field") as Texture2D).get_image()
		var fog := (mat.get_shader_parameter("atmosphere_field") as Texture2D).get_image()
		var heights := PackedFloat32Array()
		var colours: Array[Color] = []
		for i in 169:
			heights.append(ground.get_pixel(i % 13, i / 13).r)
			colours.append(fog.get_pixel(i % 13, i / 13))
		preload("res://scripts/terrain/biome/BiomeMistWisps.gd").attach(node.get_parent(), {"ground": heights, "fog": colours})
	for child in node.get_children(): _refresh_frozen_fx(child)

func _restore_foundation_cores(node: Node) -> void:
	if node is GeometryInstance3D:
		var mat: Material = node.material_override
		var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null)
		if mat == null and mesh != null and mesh.get_surface_count() > 0: mat = mesh.surface_get_material(0)
		if mat is ShaderMaterial and mat.shader != null and "orb_color" in mat.shader.code and "world_normal" in mat.shader.code:
			var fresh := mat.duplicate() as ShaderMaterial
			fresh.shader = preload("res://tests/harness/lighting_lab/foundation_orb.gdshader")
			node.material_override = fresh
	for child in node.get_children(): _restore_foundation_cores(child)

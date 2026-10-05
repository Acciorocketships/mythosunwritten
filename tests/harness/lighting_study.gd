extends Node3D
## Fast fixed-geometry lighting study. Production streaming remains the acceptance gate.
var _director: AtmosphereDirector
var _biome: StringName = &"deep_forest"
var _capture := "/tmp/lighting-study.png"
var _quality := 1
var _materials := false
var _grade := "current"
var _maps: Array[Texture2D] = []

class ReviewPool extends WaterSampler:
	func level_at(point: Vector2) -> float:
		return 0.8 if absf(point.x) < 11.0 and absf(point.y - 24.0) < 4.0 else NAN

class MotionReview extends "res://tests/harness/atmosphere_review.gd":
	func _ready() -> void:
		pass

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--biome": _biome = StringName(args[i + 1])
		if args[i] == "--capture": _capture = args[i + 1]
		if args[i] == "--quality": _quality = int(args[i + 1])
		if args[i] == "--grade": _grade = args[i + 1]
	_materials = args.has("--materials")
	RenderingServer.global_shader_parameter_set("review_visual_time", 12.0)
	var profile := BiomeRegistry.profile(_biome)
	if profile == null:
		push_error("Unknown biome: %s" % _biome)
		get_tree().quit(1)
		return
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = Sky.new()
	environment.environment.sky.sky_material = ProceduralSkyMaterial.new()
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(27, 10, 34)
	camera.look_at(Vector3(0, 4, -5))
	camera.fov = 55
	# Low, sun-facing canopy-gap probe; isolates volumetric shadowing from
	# terrain occlusion. This is diagnostic geometry, not landscape acceptance.
	if args.has("--shafts"):
		camera.position = Vector3(24, 3, 5)
		camera.look_at(Vector3(0, 8, -6))
	_director = AtmosphereDirector.new()
	_director.environment_node = environment
	_director.sun = sun
	_director.camera = camera
	_director.quality = _quality
	add_child(_director)
	_director.set_process(false)
	_director._apply_mood(BiomeRegistry.blend_atmosphere({_biome: 1.0}))
	var scattering_arg := args.find("--sun-scattering")
	if scattering_arg >= 0 and scattering_arg + 1 < args.size():
		sun.light_volumetric_fog_energy = float(args[scattering_arg + 1])
	# Review-only alternative: stronger light/shadow separation without raising
	# highlights. Keep the production grade unchanged until landscape acceptance.
	if _grade == "contrast":
		environment.environment.ambient_light_energy = maxf(0.24, environment.environment.ambient_light_energy * 0.7)
		environment.environment.glow_bloom = 0.012
		sun.shadow_opacity = 0.82
	elif _grade == "side":
		sun.rotation_degrees.y = -110.0
		sun.shadow_opacity = 0.82
	_box(Vector3(140, 0.5, 140), Vector3(0, -0.25, 0), BiomeRegistry.SUBSTRATES[_biome], 0.95)
	# The same pale stone, wood, foliage and wet stone in every light rig.
	for i in 5:
		_box(Vector3(3, 3 + i * 2, 3), Vector3(-12 + i * 6, 1.5 + i, -13), Color("8c8170"), 0.92)
		_box(Vector3(2, 2, 2), Vector3(-12 + i * 6, 1, 4), Color("69777b"), 0.2 + i * 0.18)
	for i in 5:
		_box(Vector3(1.2, 14, 1.2), Vector3(-18 + i * 9, 7, -6), Color("66513d"), 0.9)
		_box(Vector3(7, 1, 12), Vector3(-18 + i * 9, 14, -6), profile.foliage_tints["tree"], 0.9)
	for i in 3:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("ffd69b")
		mat.emission_enabled = true
		mat.emission = Color("ffb35e")
		mat.emission_energy_multiplier = 3.0
		var orb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.36
		orb.mesh = sphere
		orb.material_override = mat
		orb.position = Vector3(-9 + i * 9, 2.2, 0)
		add_child(orb)
		var light := OmniLight3D.new()
		light.light_color = mat.emission
		light.light_energy = 1.2
		light.omni_range = 7
		orb.add_child(light)
	var mood := BiomeRegistry.blend_atmosphere({_biome: 1.0})
	var fog := PackedColorArray()
	var shape := PackedColorArray()
	var ground := PackedFloat32Array()
	var color: Color = mood[&"fog_color"]
	color.a = mood[&"fog_density"]
	for i in 169:
		fog.append(color)
		shape.append(mood[&"mist_shape"])
		ground.append(0.0)
	var fx := BiomeChunkFx.build_field({"fog": fog, "mist_shape": shape, "ground": ground,
		"lo": 0.0, "hi": 0.0, "origin": Vector3(-96, 0, -96), "points": {}, "orbs": []})
	fx.position = Vector3(-96, 0, -96)
	add_child(fx)
	var volume := fx.get_node_or_null("WorldMist") as FogVolume
	if volume != null:
		(volume.material as ShaderMaterial).set_shader_parameter("review_time", 12.0)
	if _materials:
		_material_samples(profile)
	if args.has("--immersion"):
		var owner := Node.new()
		owner.set_meta("sampler", ReviewPool.new())
		add_child(owner)
		owner.add_to_group("water_surface")
		camera.position = Vector3(0, 1.2, 26)
		camera.look_at(Vector3(0, 2.0, 0))
		_director._underwater.camera = camera
		_director._underwater.world_seed = 2697992464
		_capture_immersion.call_deferred(camera)
		return
	_capture_frame.call_deferred()

func _capture_immersion(camera: Camera3D) -> void:
	for i in 60:
		await RenderingServer.frame_post_draw
	for frame in 121:
		var phase := float(frame) / 60.0
		camera.position.y = lerpf(1.2, 0.3, phase if phase <= 1.0 else 2.0 - phase)
		_director._underwater.update_view()
		await RenderingServer.frame_post_draw
		if frame % 15 == 0:
			var path := _capture.get_basename() + "-%03d.png" % frame
			var error := get_viewport().get_texture().get_image().save_png(path)
			print("[immersion-study] frame=", frame, " eye_y=", camera.position.y,
				" depth=", _director._underwater.depth, " saved=", error)
	get_tree().quit()

func _box(size: Vector3, location: Vector3, color: Color, roughness: float) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	node.material_override = material
	node.position = location
	add_child(node)

func _capture_frame() -> void:
	for i in 90:
		await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(_capture)
	print("[lighting-study] ", _biome, " grade=", _grade, " capture=", _capture, " error=", error)
	if OS.get_cmdline_user_args().has("--orbit"):
		var motion := MotionReview.new()
		motion._capture_path = _capture
		motion._freeze_time = 12.0
		add_child(motion)
		if OS.get_cmdline_user_args().has("--measure"):
			await motion._measure_render(_director.camera, _director.environment_node.environment)
		await motion._capture_orbit(_director.camera, Vector3(0, 4, -5), _director)
	get_tree().quit(0 if error == OK else 1)

func _solid_texture(color: Color) -> ImageTexture:
	var image := Image.create_empty(2, 2, false, Image.FORMAT_RGBAF)
	image.fill(color)
	var texture := ImageTexture.create_from_image(image)
	_maps.append(texture)
	return texture

func _material_samples(profile: BiomeProfile) -> void:
	var weights: Dictionary = {_biome: 1.0}
	var channels := [
		Color(float(weights.get(&"deep_forest", 0)), float(weights.get(&"highland", 0)), float(weights.get(&"blossom_grove", 0)), float(weights.get(&"twilight_marsh", 0))),
		Color(float(weights.get(&"amber_heath", 0)), float(weights.get(&"jade_wetlands", 0)), float(weights.get(&"meadow", 0)), 1),
		BiomeRegistry.substrate_color(weights), BiomeRegistry.surface_response(weights)]
	var names := ["biome_ground_a", "biome_ground_b", "biome_ground_color", "biome_surface_map"]
	for i in channels.size():
		RenderingServer.global_shader_parameter_set(names[i], _solid_texture(channels[i]))
	RenderingServer.global_shader_parameter_set("biome_ground_origin", Vector2(-1536, -1536))
	var palette := _solid_texture(Color("829858"))
	var paths := ["res://terrain/materials/ground_surface.gdshader",
		"res://terrain/materials/cliff_crag.gdshader",
		"res://terrain/environment/materials/biome_canopy.gdshader",
		"res://terrain/materials/meadow_rock.gdshader"]
	for i in paths.size():
		var material := ShaderMaterial.new()
		material.shader = load(paths[i])
		material.set_shader_parameter("ground_palette_texture", palette)
		material.set_shader_parameter("albedo_texture", palette)
		material.set_shader_parameter("base_albedo", _solid_texture(Color("8c8170")))
		material.set_shader_parameter("base_sma", _solid_texture(Color(0.15, 0, 1)))
		material.set_shader_parameter("moss_amount", 0.0)
		var primitive := SphereMesh.new()
		primitive.radius = 1.7
		primitive.height = 3.4
		var arrays := primitive.get_mesh_arrays()
		var colors := PackedColorArray()
		colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		colors.fill(profile.foliage_tints["tree"] if i == 2 else Color.WHITE)
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = material
		node.position = Vector3(-12 + i * 7, 1.7, 13)
		add_child(node)
	var grass := load("res://terrain/environment/visuals/stylized_grass/stylized_grass_collection_05.tres") as EnvironmentVisual
	for piece: EnvironmentVisualPiece in grass.pieces:
		var node := MeshInstance3D.new()
		node.mesh = piece.mesh
		node.transform = piece.local_transform
		node.position += Vector3(15, 0, 13)
		var material := ShaderMaterial.new()
		material.shader = load("res://terrain/grass/grass.gdshader")
		material.set_shader_parameter("ground_palette_texture", palette)
		node.material_override = material
		add_child(node)

	var pool := PlaneMesh.new()
	pool.size = Vector2(22, 8)
	pool.subdivide_width = 44
	pool.subdivide_depth = 16
	var water_arrays := pool.get_mesh_arrays()
	var water_colors := PackedColorArray()
	water_colors.resize((water_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	var tint := profile.water_tint.srgb_to_linear()
	water_colors.fill(Color(0.3, tint.r, tint.g, tint.b))
	water_arrays[Mesh.ARRAY_COLOR] = water_colors
	var water_mesh := ArrayMesh.new()
	water_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, water_arrays)
	var water := MeshInstance3D.new()
	water.mesh = water_mesh
	var water_material := ShaderMaterial.new()
	water_material.shader = load("res://terrain/water/water_unified.gdshader")
	water.material_override = water_material
	water.position = Vector3(0, 0.8, 24)
	add_child(water)

extends "res://tests/harness/atmosphere_review.gd"
const Candidates = preload("res://tests/harness/lighting_lab/candidates.gd")
var mode := "control"
var rig: AtmosphereDirector
var world: Node3D
var screen_effect: Resource

func _ready() -> void:
	_read_args()
	_setup_capture_view()
	var args := OS.get_cmdline_user_args()
	var arg := args.find("--mode")
	if arg >= 0: mode = args[arg + 1]
	world = Node3D.new()
	_capture_view.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	world.add_child(sun)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(26, 18, 32)
	cam.look_at(Vector3(0, 4, -3))
	cam.fov = 52
	if args.has("--low-camera"):
		cam.position = Vector3(20, 3, 24)
		cam.look_at(Vector3(-6, 9, -12))
	rig = AtmosphereDirector.new()
	rig.environment_node = env
	rig.sun = sun
	rig.camera = cam
	add_child(rig)
	rig.set_process(false)
	rig._apply_mood(BiomeRegistry.blend_atmosphere({&"twilight_marsh" if args.has("--twilight") else &"deep_forest": 1.0}))
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.directional_shadow_max_distance = 100
	if args.has("--sun-facing"):
		cam.position = Vector3(16, 2, -25)
		cam.look_at(cam.position + sun.basis.z * 30.0)
	sun.light_volumetric_fog_energy = 4.0
	env.environment.volumetric_fog_length = 100
	env.environment.volumetric_fog_ambient_inject = 0.12
	env.environment.volumetric_fog_anisotropy = 0.28
	RenderingServer.global_shader_parameter_set("atmosphere_sun_ray", -sun.basis.z)
	RenderingServer.global_shader_parameter_set("review_visual_time", 12.0)
	_box(Vector3(90, 0.5, 85), Vector3(0, -0.3, -5), Color("4c6640"), 0.95)
	_box(Vector3(6, 0.12, 55), Vector3(1, 0, -5), Color("8c8068"), 0.9)
	for i in 9:
		_visual("res://terrain/environment/visuals/low_poly_fantasy_village/lpfv_tree_%02d.tres" % (i % 3 + 1), Vector3(-18 + (i % 3) * 13, 0, -18 + (i / 3) * 10), 0.95)
	for i in 5:
		_visual("res://terrain/environment/visuals/meadow/rock_08.res", Vector3(-12 + i * 6, 0, 7), 1.2)
		_box(Vector3(3, 3.5, 2), Vector3(-12 + i * 6, 1.75, 9), Color("797870"), 0.12 + i * 0.20)
	for i in 3:
		_visual("res://terrain/environment/visuals/low_poly_fantasy_village_fabric/lpfv_fabric_prop_lantern_post_02.tres", Vector3(-8 + i * 8, 0, 0), 1.5)
		var orb := SpiritOrb.create(Vector3(-8 + i * 8, 3, 2))
		world.add_child(orb)
		orb.set_process(false)
	if mode != "baseline":
		env.environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		env.environment.glow_intensity = 0.8
		env.environment.glow_bloom = 0.0
		env.environment.glow_hdr_threshold = 1.4
		for i in 7: env.environment.set_glow_level(i, [0.4, 0.9, 0.65, 0.3, 0.12, 0.0, 0.0][i])
		for child in world.get_children():
			if child is SpiritOrb:
				var light := child.get_node("Light") as OmniLight3D
				light.light_energy = 3.0
				light.light_volumetric_fog_energy = 2.5
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color("ffbd6a")
				mat.emission_enabled = true
				mat.emission = Color("ffad48")
				mat.emission_energy_multiplier = 9.0
				child.get_node("Core").material_override = mat
	if mode == "native" or mode == "combined" or mode == "selected": Candidates.native_fog(world, Vector3.ZERO)
	if mode == "geometry" or mode == "geometry-soft" or mode == "combined":
		for p: Vector3 in [Vector3(-8, 18, -12), Vector3(1, 18, -9), Vector3(9, 18, -15)]:
			Candidates.geometry(world, p, -sun.basis.z, mode != "geometry")
	if mode == "sixway" or mode == "sixway-soft" or mode == "selected": Candidates.sixway(world, Vector3.ZERO, mode != "sixway")
	if mode == "raymarch": Candidates.raymarch(world, Vector3.ZERO, -sun.basis.z)
	if mode == "screen": screen_effect = Candidates.screen(env, cam, sun)
	_capture.call_deferred()

func _visual(path: String, location: Vector3, scale_factor: float) -> void:
	var visual := load(path) as EnvironmentVisual
	if visual == null: return
	for piece in visual.pieces:
		var node := MeshInstance3D.new()
		node.mesh = piece.mesh
		node.material_override = piece.material_override
		if "lantern_post" in path:
			node.material_override = preload("res://scripts/terrain/environment/EnvironmentLanternLights.gd").glass_material(&"lpfv.fabric.prop.lantern.post.02", piece)
		if "tree_" in path:
			var source: Material = piece.material_override if piece.material_override != null else piece.mesh.surface_get_material(0)
			if source is ShaderMaterial:
				var adapted := ShaderMaterial.new()
				adapted.shader = Shader.new()
				adapted.shader.code = source.shader.code.replace("instance_tint = COLOR.rgb;", "instance_tint = vec3(0.36, 0.56, 0.27);")
				adapted.set_shader_parameter("albedo_texture", source.get_shader_parameter("albedo_texture"))
				node.material_override = adapted
		node.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_factor), location) * piece.local_transform
		world.add_child(node)

	if "lantern_post" in path:
		preload("res://scripts/terrain/environment/EnvironmentLanternLights.gd").attach(world, &"lpfv.fabric.prop.lantern.post.02", [Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_factor), location)])

func _box(size: Vector3, at: Vector3, color: Color, rough: float) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	node.material_override = mat
	node.position = at
	world.add_child(node)

func _capture() -> void:
	rig._light_budget.update_lights(rig.camera, 1)
	for i in 90: await RenderingServer.frame_post_draw
	var error := _capture_view.get_texture().get_image().save_png(_capture_path)
	print("[lighting-lab] mode=", mode, " saved=", error, " watchdog=", _forced_draws)
	if _measure: await _measure_render(rig.camera, rig.environment_node.environment)
	if _orbit: await _capture_orbit(rig.camera, Vector3(0, 4, -3), rig)
	get_tree().quit(0 if error == OK else 1)

func _process(_dt: float) -> void:
	if _capture_view != null and Time.get_ticks_usec() - _last_draw_usec > 100000:
		_forced_draws += 1
		RenderingServer.force_draw(false)

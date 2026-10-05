extends RefCounted
## External candidates are deliberately confined to this review adapter.
const ROOT := "res://tests/lighting_candidates/"

static func native_fog(parent: Node3D, location: Vector3) -> void:
	var fog := FogVolume.new()
	fog.size = Vector3(52, 22, 46)
	fog.position = location + Vector3(0, 8, 0)
	var mat := FogMaterial.new()
	mat.density = 0.012
	mat.albedo = Color(0.92, 0.96, 1.0)
	mat.height_falloff = 0.10
	mat.edge_fade = 0.25
	fog.material = mat
	parent.add_child(fog)

static func geometry(parent: Node3D, start: Vector3, direction: Vector3, softened := false) -> void:
	var mat := load(ROOT + "joryleech/LightRayMaterial.tres").duplicate() as ShaderMaterial
	mat.set_shader_parameter("MaxOpacity", 0.01)
	mat.set_shader_parameter("LightColor", Color(1.0, 0.83, 0.52))
	if softened:
		mat = ShaderMaterial.new()
		mat.shader = preload("res://tests/harness/lighting_lab/soft_beam.gdshader")
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 2.5
	mesh.height = 19
	mesh.radial_segments = 32
	mesh.cap_top = false
	mesh.cap_bottom = false
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = start + direction * 9.5
	node.quaternion = Quaternion(Vector3.DOWN, direction)

static func screen(environment: WorldEnvironment, camera: Camera3D, sun: DirectionalLight3D) -> Resource:
	var effect = load(ROOT + "ARez2/lens_flare_compositor_effect.gd").new()
	effect.sun_position = camera.unproject_position(camera.global_position + sun.global_basis.z * 100.0) / Vector2(camera.get_viewport().size)
	effect.sun_dir_sign = (-camera.global_basis.z).dot(sun.global_basis.z)
	effect.sun_color = Color(0.65, 0.49, 0.26, 0.6)
	effect.SampleCount = 48
	effect.Anamorphic_Intensity = 0.0
	effect.Anamorphic_Brightness = 0.0
	effect.Effect_Multiplier = 0.2
	var compositor := Compositor.new()
	compositor.compositor_effects = [effect]
	environment.compositor = compositor
	return effect

static func sixway(parent: Node3D, location: Vector3, adapted := false) -> void:
	# Original procedural test maps; no Unity demonstration textures are vendored.
	var maps: Array[Image] = []
	for k in 3: maps.append(Image.create_empty(96, 96, false, Image.FORMAT_RGBA8))
	for y in 96:
		for x in 96:
			var u := (Vector2(x, y) / 95.0 - Vector2.ONE * 0.5) * 2.0
			var density := 0.0
			for center: Vector3 in [Vector3(-0.35, 0.12, 0.48), Vector3(0.2, 0.0, 0.55), Vector3(0.0, -0.25, 0.4)]:
				density += exp(-u.distance_squared_to(Vector2(center.x, center.y)) / (center.z * center.z) * 3.0)
			density = clampf(density * 0.75, 0.0, 1.0) * (1.0 - smoothstep(0.72, 1.0, u.length()))
			maps[0].set_pixel(x, y, Color(0.55 + u.x * 0.35, 0.55 - u.y * 0.35, 0.35, 1))
			maps[1].set_pixel(x, y, Color(0.55 - u.x * 0.35, 0.55 + u.y * 0.35, 0.9, 1))
			maps[2].set_pixel(x, y, Color(density, 0, 0.75, 1))
	var material := ShaderMaterial.new()
	material.shader = load("res://terrain/materials/six_way_mist.gdshader" if adapted else ROOT + "TheAenema/HMSixWayLighting.gdshader")
	for i in 3:
		material.set_shader_parameter(["six_way_map_RTB", "six_way_map_LBF", "six_way_map_TEA"][i], ImageTexture.create_from_image(maps[i]))
	material.set_shader_parameter("normal_power", 0.0)
	material.set_shader_parameter("normal_blend", 0.0)
	material.set_shader_parameter("emission_power", 0.0)
	material.set_shader_parameter("density", 0.52)
	material.set_shader_parameter("billboard_mode", 2)
	material.set_shader_parameter("depth_fade_strength", 1.0 if adapted else 0.0) # Upstream samples colour as depth; do not enable.
	for i in 4:
		var node := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(16, 7)
		node.mesh = mesh
		node.material_override = material
		node.position = location + Vector3(-13 + i * 8, 2.7, -5 + (i % 2) * 5)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)

static func raymarch(parent: Node3D, location: Vector3, direction: Vector3) -> void:
	var slices: Array[Image] = []
	var noise := FastNoiseLite.new()
	noise.seed = 713
	noise.frequency = 0.12
	for z in 32:
		var image := Image.create_empty(32, 32, false, Image.FORMAT_RF)
		for y in 32:
			for x in 32:
				var p := (Vector3(x, y, z) / 31.0 - Vector3.ONE * 0.5) * 2.0
				var value := maxf(0.0, 1.0 - p.length_squared()) * smoothstep(-0.35, 0.5, noise.get_noise_3d(x, y, z))
				image.set_pixel(x, y, Color(value, 0, 0))
		slices.append(image)
	var volume := ImageTexture3D.new()
	volume.create(Image.FORMAT_RF, 32, 32, 32, false, slices)
	var gradient := GradientTexture1D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.colors = PackedColorArray([Color("384453"), Color("ffe4b8")])
	var mat := ShaderMaterial.new()
	mat.shader = load(ROOT + "MangoButtermilch/volumetric.gdshader")
	var values := {"_totalBrightness": 0.22, "_maxSteps": 384, "_stepSize": 0.015,
		"_lightDir": direction, "_maxLightDistance": 0.5, "_transmissionThreshhold": 0.01,
		"_lightStepSize": 0.06, "_lightDensityScale": 0.2, "_maxLightSteps": 8,
		"_volumeOffset": Vector3.ZERO, "_volumeRotation": Vector3.ZERO, "_volumeScale": Vector3.ONE,
		"_densityScale": 1.2, "_darknessThreshhold": 0.2, "_transmittance": 1.0,
		"_lightAbsorb": 1.0, "_epsilon": 0.01, "_gradientTex": gradient,
		"_gradientTex_ST": Vector4(1, 1, 0, 0), "_volumeTex": volume}
	for key in values: mat.set_shader_parameter(key, values[key])
	var node := MeshInstance3D.new()
	node.mesh = BoxMesh.new()
	node.scale = Vector3(28, 14, 24)
	node.position = location + Vector3(0, 6, -2)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

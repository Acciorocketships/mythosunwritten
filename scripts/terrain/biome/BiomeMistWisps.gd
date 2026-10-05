extends RefCounted
## Sparse, depth-faded six-way mist adds nearby structure to the native volume.
## Directional shader: Hamid Memar (CC BY 4.0); maps below are original.
static var _material: ShaderMaterial
static func material() -> ShaderMaterial:
	if _material != null: return _material
	# Original procedural test maps; no Unity demonstration textures are vendored.
	var maps: Array[Image] = []
	for k in 3: maps.append(Image.create_empty(64, 64, false, Image.FORMAT_RGBA8))
	for y in 64:
		for x in 64:
			var u := (Vector2(x, y) / 63.0 - Vector2.ONE * 0.5) * 2.0
			var density := 0.0
			for center: Vector3 in [Vector3(-0.35, 0.12, 0.48), Vector3(0.2, 0.0, 0.55), Vector3(0.0, -0.25, 0.4)]:
				density += exp(-u.distance_squared_to(Vector2(center.x, center.y)) / (center.z * center.z) * 3.0)
			density = clampf(density * 0.75, 0.0, 1.0) * (1.0 - smoothstep(0.72, 1.0, u.length()))
			maps[0].set_pixel(x, y, Color(0.55 + u.x * 0.35, 0.55 - u.y * 0.35, 0.35, 1))
			maps[1].set_pixel(x, y, Color(0.55 - u.x * 0.35, 0.55 + u.y * 0.35, 0.9, 1))
			maps[2].set_pixel(x, y, Color(density, 0, 0.75, 1))
	var material := ShaderMaterial.new()
	material.shader = preload("res://terrain/materials/six_way_mist.gdshader")
	for i in 3:
		material.set_shader_parameter(["six_way_map_RTB", "six_way_map_LBF", "six_way_map_TEA"][i], ImageTexture.create_from_image(maps[i]))
	material.set_shader_parameter("normal_power", 0.0)
	material.set_shader_parameter("normal_blend", 0.0)
	material.set_shader_parameter("emission_power", 0.0)
	material.set_shader_parameter("density", 0.16)
	material.set_shader_parameter("billboard_mode", 2)
	material.set_shader_parameter("depth_fade_strength", 1.0)
	_material = material
	return _material

static func attach(parent: Node3D, data: Dictionary) -> void:
	if data.fog.size() != 169 or not data.has("ground") or data.ground.size() != 169: return
	for index in [42, 48, 120, 126]:
		if data.fog[index].a < 0.006: continue
		var node := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(12, 3.5)
		node.mesh = mesh
		node.material_override = material()
		node.position = Vector3((index % 13) * 16.0, data.ground[index] + 1.3, (index / 13) * 16.0)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin = 6.0
		node.add_to_group("atmosphere_mist_wisp")
		parent.add_child(node)

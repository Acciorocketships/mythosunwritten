extends RefCounted

## Save actual generated render nodes after profiling has stopped generation.
## Runtime scripts are omitted; external shaders stay external for comparisons.
static func save_world(world:Node3D,path:String,extra_globals:Dictionary={})->Error:
	var copy:=world.duplicate(0) as Node3D
	copy.process_mode=Node.PROCESS_MODE_DISABLED
	_own_children(copy,copy)
	# Godot's global readback API is editor-only. Read the owning adapters once,
	# after measurement, instead of synchronizing with the rendering server.
	var stream:=world.get_node("FieldTerrain") as FieldTerrainStreamer
	var grass:=stream._grass_streamer
	var trample:=stream._trample_field
	var map:BiomeGroundMap=world.get_node("AtmosphereDirector")._ground_map
	var globals:Dictionary={
		"grass_density_scale":grass._density_scale,
		"biome_ground_a":map._maps[0],"biome_ground_b":map._maps[1],"biome_ground_color":map._maps[2],
		"biome_ground_origin":map._centre-Vector2.ONE*BiomeGroundMap.SPAN*0.5,
		"grass_lod_origin":grass._lod_origin,"wind_direction":GrassStreamer.WIND_DIRECTION.normalized(),
		"wind_idle_bend":GrassStreamer.WIND_IDLE_BEND,"wind_gust_texture":grass._wind_texture,
		"wind_gust_scale":GrassStreamer.WIND_GUST_SCALE,"wind_gust_speed":GrassStreamer.WIND_GUST_SPEED,
		"wind_gust_bend":GrassStreamer.WIND_GUST_BEND,
		"grass_trample_texture":trample._texture,"grass_static_trample_texture":trample._static_texture,
		"grass_trample_origin":trample._texture_origin,"grass_trample_size":TrampleField.DOMAIN_SIZE,
		"grass_trample_epoch":trample._now}
	if map._maps.size() > 3:
		globals["biome_surface_map"] = map._maps[3]
	var director: AtmosphereDirector = world.get_node("AtmosphereDirector")
	globals["canopy_shadow_detail"] = 1.0 if director.quality >= 1 else 0.0
	var sun_basis := Basis.from_euler(AtmosphereDirector.SUN_ANGLE_DEG * PI / 180.0)
	if is_instance_valid(director.sun):
		sun_basis = director.sun.global_basis if director.sun.is_inside_tree() else director.sun.basis
	globals["atmosphere_sun_ray"] = -sun_basis.z
	var mood := BiomeRegistry.blend_atmosphere(director._mood_weights)
	var sky_top := (mood[&"sky_top"] as Color).srgb_to_linear()
	var sky_horizon := (mood[&"sky_horizon"] as Color).srgb_to_linear()
	globals["atmosphere_sky_top"] = Vector4(sky_top.r, sky_top.g, sky_top.b, 1.0)
	globals["atmosphere_sky_horizon"] = Vector4(sky_horizon.r, sky_horizon.g, sky_horizon.b, 1.0)
	globals["atmosphere_water_gain"] = AtmosphereDirector.water_light_gain(mood)
	globals.merge(extra_globals, true)
	copy.set_meta("shader_globals",globals)
	copy.set_meta("lighting_review", {"seed": stream.world_seed, "position": stream.player.global_position,
		"biome_weights": director._mood_weights.duplicate(), "quality": director.quality})
	restore_native_adapter_parameters(copy, {})
	_freeze_water(copy, {})
	# Water materials now contain captured images rather than viewport paths.
	var ripples := copy.get_node_or_null("WaterRipples")
	if ripples != null: ripples.free()
	var packed:=PackedScene.new()
	var error:=packed.pack(copy)
	if error==OK:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		error=ResourceSaver.save(packed,path)
	copy.free()
	return error

## Visibility adapters for native materials keep parameters on the render server
## only. Reconstruct serializable values from their original surface material.
## Also repairs older snapshots without rebuilding their terrain.
static func restore_native_adapter_parameters(node: Node, cache: Dictionary) -> void:
	var mesh: Mesh
	if node is MultiMeshInstance3D and node.multimesh != null:
		mesh = node.multimesh.mesh
	elif node is MeshInstance3D:
		mesh = node.mesh
	if mesh != null and node.material_override is ShaderMaterial:
		var adapted := node.material_override as ShaderMaterial
		# Early review snapshots incorrectly copied native parameters onto the
		# grass override. Its six bindings are reconstructible from the same
		# canonical sources GrassStreamer uses; leave intact overrides alone.
		if adapted.shader != null and "#define TACTICAL_GRASS_ROOT" in adapted.shader.code \
				and adapted.get_shader_parameter("ground_palette_texture") == null:
			var source := mesh.surface_get_material(0) as StandardMaterial3D
			if source != null:
				var repaired := adapted.duplicate() as ShaderMaterial
				repaired.set_shader_parameter("albedo_texture", source.albedo_texture)
				repaired.set_shader_parameter("source_has_texture", source.albedo_texture != null)
				repaired.set_shader_parameter("ground_palette_texture", CliffDressing.ground_texture())
				repaired.set_shader_parameter("ground_palette_uv", CliffDressing.ground_uv())
				repaired.set_shader_parameter("local_base_y", mesh.get_aabb().position.y)
				repaired.set_shader_parameter("local_height", mesh.get_aabb().size.y)
				node.material_override = repaired
		if adapted.shader != null and "visibility_bubble.gdshaderinc" in adapted.shader.code \
				and "uniform sampler2D texture_albedo" in adapted.shader.code and mesh.get_surface_count() == 1:
			var source := mesh.surface_get_material(0) as BaseMaterial3D
			if source != null:
				if not cache.has(adapted):
					cache[adapted] = capture_native_adapter(adapted, source)
				node.material_override = cache[adapted]
	for child: Node in node.get_children():
		restore_native_adapter_parameters(child, cache)

static func capture_native_adapter(adapted: ShaderMaterial, source: BaseMaterial3D) -> ShaderMaterial:
	var copy := adapted.duplicate() as ShaderMaterial
	var textures := {}
	for property: Dictionary in source.get_property_list():
		if property.type != TYPE_OBJECT: continue
		var value: Variant = source.get(property.name)
		if value is Texture2D:
			textures[value.get_rid()] = value
	for uniform: Dictionary in adapted.shader.get_shader_uniform_list():
		if String(uniform.name).begins_with("tactical_"): continue
		var value: Variant = RenderingServer.material_get_param(source.get_rid(), uniform.name)
		if value is RID:
			value = textures.get(value)
		copy.set_shader_parameter(uniform.name, value)
	return copy

static func _freeze_water(node: Node, materials: Dictionary) -> void:
	if node is GeometryInstance3D and node.material_override is ShaderMaterial:
		var source := node.material_override as ShaderMaterial
		if source.shader != null:
			if not materials.has(source):
				var frozen := source.duplicate() as ShaderMaterial
				# Water may be wrapped by camera visibility. Capture its viewport
				# uniforms by value, including the adapter's depth textures.
				for uniform: Dictionary in source.shader.get_shader_uniform_list():
					var parameter := StringName(uniform.name)
					var texture: Variant = source.get_shader_parameter(parameter)
					if texture is ViewportTexture:
						var pixels: Image = texture.get_image()
						if pixels != null:
							frozen.set_shader_parameter(parameter, ImageTexture.create_from_image(pixels))
				materials[source] = frozen
			node.material_override = materials[source]
	for child: Node in node.get_children():
		_freeze_water(child, materials)

static func _own_children(node:Node,root:Node)->void:
	for child:Node in node.get_children():
		child.owner=root
		_own_children(child,root)

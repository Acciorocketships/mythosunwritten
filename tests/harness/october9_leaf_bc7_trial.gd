extends RefCounted

func run(review: Node) -> void:
	var seen: Dictionary = {}
	var textures: Dictionary = {}
	var restore: Array = []
	var original_bytes := 0
	var packed_bytes := 0
	for visual: EnvironmentVisual in review._streamer._environment_cache._visuals.values():
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var material := piece.mesh.surface_get_material(surface) as ShaderMaterial
				if material == null or not material.shader.resource_path.ends_with("painted_leaf.gdshader"): continue
				if seen.has(material.get_instance_id()): continue
				seen[material.get_instance_id()] = true
				var source := material.get_shader_parameter("albedo_texture") as Texture2D
				if source == null: continue
				if not textures.has(source.resource_path):
					var pixels := source.get_image()
					original_bytes += pixels.get_data().size()
					var compressed := PortableCompressedTexture2D.new()
					compressed.keep_compressed_buffer = true
					compressed.create_from_image(pixels, PortableCompressedTexture2D.COMPRESSION_MODE_BPTC)
					packed_bytes += compressed.get_image().get_data().size()
					textures[source.resource_path] = compressed
				restore.append([material, source])
				material.set_shader_parameter("albedo_texture", textures[source.resource_path])
	await review._capture_all(3)
	for pair: Array in restore: pair[0].set_shader_parameter("albedo_texture", pair[1])
	print("LEAF_BC7_TRIAL_DONE textures=", textures.size(), " original_bytes=", original_bytes, " packed_bytes=", packed_bytes)

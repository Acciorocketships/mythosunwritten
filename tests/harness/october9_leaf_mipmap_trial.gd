extends RefCounted

func run(review: Node) -> void:
	var restored: Array = []
	var seen: Dictionary = {}
	var textures: Dictionary = {}
	for visual: EnvironmentVisual in review._streamer._environment_cache._visuals.values():
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var material := piece.mesh.surface_get_material(surface) as ShaderMaterial
				if material == null or not material.shader.resource_path.ends_with("painted_leaf.gdshader"): continue
				if seen.has(material.get_instance_id()): continue
				seen[material.get_instance_id()] = true
				var source := material.get_shader_parameter("albedo_texture") as Texture2D
				if source == null: continue
				var pixels := source.get_image()
				if pixels == null or pixels.has_mipmaps(): continue
				if not textures.has(source.get_instance_id()):
					if pixels.is_compressed(): pixels.decompress()
					pixels.generate_mipmaps()
					textures[source.get_instance_id()] = ImageTexture.create_from_image(pixels)
				restored.append([material, source])
				material.set_shader_parameter("albedo_texture", textures[source.get_instance_id()])
	print("LEAF_MIPMAP_TRIAL textures=",textures.size()," materials=",restored.size())
	await review._capture_all(1)
	for pair: Array in restored: pair[0].set_shader_parameter("albedo_texture",pair[1])
	print("LEAF_MIPMAP_TRIAL_DONE")

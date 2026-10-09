extends RefCounted

func run(review: Node) -> void:
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
				if not textures.has(source.resource_path):
					textures[source.resource_path] = ResourceLoader.load(source.resource_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
				material.set_shader_parameter("albedo_texture", textures[source.resource_path])
	await review._capture_all(2)
	print("LEAF_MIPMAP_SAVED_DONE textures=", textures.size())

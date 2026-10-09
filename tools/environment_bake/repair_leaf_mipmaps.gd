extends SceneTree

# Narrow texture-only repair. Keeps every material/mesh/descriptor reference intact.
# Default is read-only; pass -- --apply to write only missing leaf mip chains.
func _init() -> void:
	var apply := OS.get_cmdline_user_args().has("--apply")
	var materials: Array[String] = []
	_collect("res://terrain/environment/materials", materials)
	materials.sort()
	var seen: Dictionary = {}
	var repaired := 0
	for path: String in materials:
		if not FileAccess.get_file_as_string(path).contains("painted_leaf.gdshader"): continue
		var material := load(path) as ShaderMaterial
		if material == null or material.shader == null: continue
		if not material.shader.resource_path.ends_with("painted_leaf.gdshader"): continue
		var source := material.get_shader_parameter("albedo_texture") as Texture2D
		if source == null or seen.has(source.resource_path): continue
		seen[source.resource_path] = true
		var pixels := source.get_image()
		if pixels == null or pixels.has_mipmaps(): continue
		if pixels.is_compressed(): pixels.decompress()
		var original := pixels.get_data()
		if pixels.generate_mipmaps() != OK:
			push_error("Cannot generate mipmaps: " + source.resource_path)
			quit(1)
			return
		print("LEAF_MIPMAP ", "repair " if apply else "missing ", source.resource_path)
		if apply:
			var texture := PortableCompressedTexture2D.new()
			texture.keep_compressed_buffer = true
			texture.create_from_image(pixels, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
			if ResourceSaver.save(texture, source.resource_path) != OK:
				quit(1)
				return
			var saved := ResourceLoader.load(source.resource_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
			var check := saved.get_image()
			if not check.has_mipmaps() or check.get_data() != pixels.get_data():
				push_error("Mip chain did not round trip: " + source.resource_path)
				quit(1)
				return
			check.clear_mipmaps()
			if check.get_data() != original:
				push_error("Base pixels changed: " + source.resource_path)
				quit(1)
				return
		repaired += 1
	print("LEAF_MIPMAP_DONE unique_leaf_textures=", seen.size(), " missing=", repaired, " applied=", apply)
	quit()

func _collect(path: String, out: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(path):
		if file.ends_with(".tres"): out.append(path.path_join(file))
	for child: String in DirAccess.get_directories_at(path):
		_collect(path.path_join(child), out)

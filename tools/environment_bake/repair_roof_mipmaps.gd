extends SceneTree

## Texture-only maintenance for the Suntail roofs. No mesh, UV, colour or
## planning changes. Reuses the authored base pixels and adds missing mips.
func _init() -> void:
	var apply := OS.get_cmdline_user_args().has("--apply")
	var directory := "res://terrain/environment/materials/suntail_village_kit"
	var seen: Dictionary = {}
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".tres"): continue
		var path := directory.path_join(file)
		var text := FileAccess.get_file_as_string(path)
		if not text.contains('resource_name = "Roof_'): continue
		var material := load(path) as StandardMaterial3D
		if material == null: continue
		for texture: Texture2D in [material.albedo_texture, material.normal_texture]:
			if texture == null or seen.has(texture.resource_path): continue
			seen[texture.resource_path] = true
			var pixels := texture.get_image()
			print("ROOF_TEXTURE ", texture.resource_path, " size=", pixels.get_size(), " mips=", pixels.has_mipmaps())
			if pixels.has_mipmaps(): continue
			if pixels.is_compressed(): pixels.decompress()
			var base := pixels.get_data()
			assert(pixels.generate_mipmaps(material.normal_texture == texture) == OK)
			if apply:
				var saved := PortableCompressedTexture2D.new()
				saved.keep_compressed_buffer = true
				saved.create_from_image(pixels, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
				assert(ResourceSaver.save(saved, texture.resource_path) == OK)
				var reread := ResourceLoader.load(texture.resource_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
				var check := reread.get_image()
				assert(check.has_mipmaps())
				check.clear_mipmaps()
				assert(check.get_data() == base)
	print("ROOF_TEXTURE_DONE unique=", seen.size(), " apply=", apply)
	quit()

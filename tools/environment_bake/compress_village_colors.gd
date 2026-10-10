extends SceneTree
## Run after a Suntail rebake. Only opaque, albedo-only textures are eligible;
## normal maps, scalar maps and alpha-cutout foliage keep their original data.
## Dry run by default. --apply writes the existing paths without changing materials.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
	var apply := OS.get_cmdline_user_args().has("--apply")
	var uses: Dictionary = {}
	var directory := "res://terrain/environment/materials/suntail_village_kit"
	# Collect every usage before deciding: an atlas shared with a cutout or a
	# non-colour slot must not be compressed through its opaque albedo usage.
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".tres"): continue
		var material := load(directory.path_join(file)) as StandardMaterial3D
		if material == null: continue
		for property: Dictionary in material.get_property_list():
			if property.type != TYPE_OBJECT or not (int(property.usage) & PROPERTY_USAGE_STORAGE): continue
			var texture := material.get(property.name) as Texture2D
			if texture == null: continue
			var path := texture.resource_path
			if not path.begins_with("res://terrain/environment/textures/suntail_village_kit/"): continue
			if not uses.has(path): uses[path] = {"texture":texture,"eligible":true}
			uses[path].eligible = uses[path].eligible and property.name == &"albedo_texture" \
				and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	var count := 0
	var source_bytes := 0
	var packed_bytes := 0
	for path: String in uses:
		if not uses[path].eligible: continue
		var pixels: Image = uses[path].texture.get_image()
		assert(pixels != null, path)
		# Idempotent: never recompress already lossy pixels.
		if pixels.is_compressed() or pixels.get_data_size() < 1048576: continue
		var texture := PortableCompressedTexture2D.new()
		texture.keep_compressed_buffer = true
		texture.create_from_image(pixels, PortableCompressedTexture2D.COMPRESSION_MODE_BPTC)
		var packed := texture.get_image()
		assert(packed.is_compressed() and packed.get_size() == pixels.get_size())
		assert(packed.has_mipmaps() == pixels.has_mipmaps())
		assert(packed.get_data_size() * 3 < pixels.get_data_size())
		count += 1
		source_bytes += pixels.get_data_size()
		packed_bytes += packed.get_data_size()
		if apply:
			assert(ResourceSaver.save(texture,path,ResourceSaver.FLAG_COMPRESS) == OK)
			var check := ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
			assert(check.get_image().get_data() == packed.get_data())
		print("VILLAGE_COLOR ",path," source_bytes=",pixels.get_data_size()," packed_bytes=",packed.get_data_size())
	print("VILLAGE_COLORS_DONE ",JSON.stringify({"apply":apply,"count":count,"source_bytes":source_bytes,"packed_bytes":packed_bytes}))
	quit()

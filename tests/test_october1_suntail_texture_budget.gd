extends GutTest

func test_native_suntail_materials_have_filtered_compressed_maps() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var textures := {}
	for id: StringName in SuntailBuildingKit.create().all_asset_ids():
		for piece in cache.visual(id).pieces:
			for si in piece.mesh.get_surface_count():
				var material := piece.mesh.surface_get_material(si)
				for property: Dictionary in material.get_property_list():
					if property.type != TYPE_OBJECT: continue
					var texture := material.get(property.name) as Texture2D
					if texture != null: textures[texture.resource_path] = texture
	var bytes := 0
	var uncompressed_base := 0
	for path: String in textures:
		var texture := textures[path] as PortableCompressedTexture2D
		assert_not_null(texture,path)
		if texture == null: continue
		var image := texture.get_image()
		assert_true(image.has_mipmaps(),"filter distant native surfaces: %s" % path)
		assert_true(image.is_compressed(),"mipmaps must not inflate the uncompressed runtime budget")
		assert_false(texture.keep_compressed_buffer)
		bytes += image.get_data_size()
		uncompressed_base += image.get_width()*image.get_height()*4
	assert_gt(textures.size(),10,"exercise the complete building family")
	assert_lt(bytes,uncompressed_base/2,"complete mip chains use less than half the former base pixels")
	gut.p("Suntail maps=%d compressed_mips=%d former_base=%d" % [textures.size(),bytes,uncompressed_base])

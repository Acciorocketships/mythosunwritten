extends GutTest
const PURE := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
## The tower-window material adds three full-resolution maps beyond the
## original 44-map wall/roof kit. Keep its cost separate from that budget.
const TOWER_WINDOW_MAPS := ["4d8aeacbed7d39438d4e.res", "54ea79038216890ed497.res",
	"8768803e89af03676435.res"]

func test_native_materials_keep_full_resolution_with_bounded_compressed_mipmaps() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var textures := {}
	for kit: BuildingKit in [PURE.roof_study(),PURE.create(1)]:
		for id: StringName in kit.all_asset_ids():
			if not String(id).begins_with("pure_village."): continue
			for piece in cache.visual(id).pieces:
				for si in piece.mesh.get_surface_count():
					var material := piece.mesh.surface_get_material(si)
					for property: Dictionary in material.get_property_list():
						if property.type != TYPE_OBJECT: continue
						var value = material.get(property.name)
						if value is Texture2D: textures[value.resource_path] = value
	# Mixed-kit projecting bays borrow Suntail geometry/materials. Count their
	# shared texture paths separately, preserving the original native budget.
	var suntail_textures := {}
	for id: StringName in SuntailBuildingKit.create().all_asset_ids():
		if not String(id).begins_with("suntail."): continue
		for piece in cache.visual(id).pieces:
			for si in piece.mesh.get_surface_count():
				var material := piece.mesh.surface_get_material(si)
				for property: Dictionary in material.get_property_list():
					if property.type != TYPE_OBJECT: continue
					var value = material.get(property.name)
					if value is Texture2D: suntail_textures[value.resource_path] = value
	var shared_bytes := 0
	var shared_maps := 0
	var bytes := 0
	var tower_bytes := 0
	var tower_maps := 0
	for path: String in textures:
		var texture := textures[path] as PortableCompressedTexture2D
		assert_not_null(texture,path)
		if texture == null: continue
		assert_eq(texture.get_compression_mode(),PortableCompressedTexture2D.COMPRESSION_MODE_BASIS_UNIVERSAL,path)
		assert_false(texture.keep_compressed_buffer,"runtime does not retain the encoder's source buffer")
		var shared := suntail_textures.has(path)
		if shared:
			var source: Texture2D = suntail_textures[path]
			assert_same(texture, source, "Mixed bays reuse the existing texture resource")
			assert_eq(texture.get_size(), source.get_size(), "Preserve source resolution")
		else:
			assert_eq(texture.get_height(),2048,"preserve source texel resolution")
			assert_true(texture.get_width() in [128,2048])
		var image := texture.get_image()
		assert_not_null(image)
		if image == null: continue
		assert_true(image.has_mipmaps(),"distant roofs need filtered mip levels")
		assert_true(image.is_compressed(),"disk-only lossless compression does not reduce texture payload")
		if shared:
			shared_bytes += image.get_data_size()
			shared_maps += 1
		elif path.get_file() in TOWER_WINDOW_MAPS:
			tower_bytes += image.get_data_size()
			tower_maps += 1
		else:
			bytes += image.get_data_size()
	assert_eq(textures.size()-shared_maps,47,"44 original maps plus three native tower-window maps")
	assert_eq(shared_maps,8,"Mixed bays borrow exactly eight existing Suntail maps")
	assert_lte(shared_bytes,6*5592432+2*1398128,"Six 2048px and two authored 1024px shared maps")
	assert_eq(tower_maps,3)
	assert_lt(bytes,230*1024*1024,"bounded full-resolution compressed payload, including mipmaps")
	# 16 bytes per 4x4 block, including a full block for the 2x2 and 1x1 mips.
	assert_lte(tower_bytes,3*5592432,"three additional 2048px compressed maps with mipmaps")

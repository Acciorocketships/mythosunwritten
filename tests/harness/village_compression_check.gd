extends SceneTree
## Fresh-loader validation of every shipped opaque town texture against its audit.
func _init() -> void:
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/qa/2026-10-09-followup/village-color-compression-audit.json"))
	var total := 0
	for row: Dictionary in rows:
		var texture := load(row.path) as Texture2D
		var pixels := texture.get_image() if texture != null else null
		if pixels == null or not pixels.is_compressed() \
				or pixels.get_width() != int(row.width) or pixels.get_height() != int(row.height) \
				or pixels.has_mipmaps() != row.mips or pixels.get_data_size() != int(row.packed_bytes):
			push_error("Invalid packed town texture: " + row.path)
			quit(1)
			return
		total += pixels.get_data_size()
	print("VILLAGE_COMPRESSION_CHECK PASS textures=", rows.size(), " bytes=", total)
	quit()

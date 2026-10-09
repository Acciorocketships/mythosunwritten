extends RefCounted

var _seen: Dictionary = {}
var _textures: Dictionary = {}

func run(review: Node) -> void:
	for visual: EnvironmentVisual in review._streamer._environment_cache._visuals.values():
		_visit(visual)
	var rows: Array = _textures.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.bytes > b.bytes)
	var bytes := 0
	for row: Dictionary in rows: bytes += row.bytes
	var result := {"textures":rows.size(), "image_bytes":bytes, "rows":rows,
		"texture_mem":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		"scope":"resources reachable from the streamer environment visual cache; per texture instance, includes shadow and imposter materials"}
	FileAccess.open(review._output_dir + "/live-textures.json", FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("LIVE_TEXTURE_INVENTORY_DONE count=", rows.size(), " bytes=", bytes)
	for i in mini(10, rows.size()): print(JSON.stringify(rows[i]))

func _visit(value: Variant) -> void:
	if value is Resource:
		if _seen.has(value.get_instance_id()): return
		_seen[value.get_instance_id()] = true
		if value is Texture2D:
			var pixels: Image = value.get_image()
			if pixels != null:
				_textures[value.get_instance_id()] = {"path":value.resource_path,"bytes":pixels.get_data().size(),
					"width":pixels.get_width(),"height":pixels.get_height(),"format":pixels.get_format(),"mips":pixels.has_mipmaps()}
			return
		if value is ShaderMaterial:
			if value.shader != null:
				for uniform: Dictionary in value.shader.get_shader_uniform_list():
					_visit(value.get_shader_parameter(uniform.name))
		for prop: Dictionary in value.get_property_list():
			if int(prop.usage) & PROPERTY_USAGE_STORAGE: _visit(value.get(prop.name))
	elif value is Array:
		for item: Variant in value: _visit(item)
	elif value is Dictionary:
		for item: Variant in value.values(): _visit(item)

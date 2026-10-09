extends SceneTree

func _init() -> void:
	var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("/tmp/oct9-texture-inventory.json"))
	var names: Dictionary = {}
	for row: Dictionary in inventory.rows:
		var name: String = row.path.get_file()
		if not names.has(name): names[name] = []
		names[name].append(row.path)
	var aliases: Dictionary = {}
	var saved_bytes := 0
	for paths: Array in names.values():
		if paths.size() < 2: continue
		paths.sort()
		var hashes: Dictionary = {}
		for path: String in paths:
			var texture := load(path) as Texture2D
			var pixels := texture.get_image()
			var data := pixels.get_data()
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(data)
			var key := str([pixels.get_width(),pixels.get_height(),pixels.get_format(),pixels.has_mipmaps(),hash.finish().hex_encode()])
			if hashes.has(key):
				aliases[path] = hashes[key]
				saved_bytes += data.size()
			else: hashes[key] = path
	FileAccess.open("/tmp/oct9-texture-aliases.json", FileAccess.WRITE).store_string(JSON.stringify(aliases,"\t",true) + "\n")
	print("TEXTURE_ALIAS_AUDIT aliases=",aliases.size()," potential_image_bytes=",saved_bytes)
	quit()

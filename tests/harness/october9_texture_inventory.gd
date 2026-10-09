extends SceneTree

# Offline inventory only: no source asset is modified or retained after inspection.
func _init() -> void:
	var rows: Array = []
	var paths: Array[String] = []
	_collect("res://terrain/environment/textures", paths)
	paths.sort()
	var total := 0
	for path: String in paths:
		var texture := load(path) as Texture2D
		if texture == null: continue
		var pixels := texture.get_image()
		if pixels == null: continue
		var bytes := pixels.get_data().size()
		total += bytes
		rows.append({"path":path,"width":pixels.get_width(),"height":pixels.get_height(),
			"mips":pixels.has_mipmaps(),"format":pixels.get_format(),
			"compressed":pixels.is_compressed(),"image_bytes":bytes})
	rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.image_bytes>b.image_bytes)
	var result := {"textures":rows.size(),"image_bytes":total,"rows":rows,
		"scope":"all baked environment textures, including assets not used by the current world; image storage, not a live VRAM measurement"}
	FileAccess.open("/tmp/oct9-texture-inventory.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TEXTURE_INVENTORY count=",rows.size()," bytes=",total)
	for i in mini(8,rows.size()): print(JSON.stringify(rows[i]))
	quit()

func _collect(path: String, out: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(path):
		if file.ends_with(".res"): out.append(path.path_join(file))
	for child: String in DirAccess.get_directories_at(path):
		_collect(path.path_join(child),out)

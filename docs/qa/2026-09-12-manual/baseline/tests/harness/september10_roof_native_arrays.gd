extends SceneTree
func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("/tmp/september10-roof-bake.json"))
	var result := {}
	for entry: Dictionary in manifest.assets:
		var visual: EnvironmentVisual = load(catalog.descriptor(StringName(entry.id)).visual_path)
		var surfaces := []
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count(): surfaces.append(piece.mesh.surface_get_arrays(surface))
		result[entry.id]=surfaces
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_var(result)
	quit()

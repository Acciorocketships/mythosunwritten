extends GutTest

func test_every_baked_painted_leaf_texture_has_distance_filtering() -> void:
	var materials: Array[String] = []
	_collect("res://terrain/environment/materials", materials)
	var seen: Dictionary = {}
	for path: String in materials:
		if not FileAccess.get_file_as_string(path).contains("painted_leaf.gdshader"): continue
		var material := load(path) as ShaderMaterial
		if material == null: continue
		var texture := material.get_shader_parameter("albedo_texture") as Texture2D
		if texture == null or seen.has(texture.resource_path): continue
		seen[texture.resource_path] = true
		var pixels := texture.get_image()
		assert_not_null(pixels, texture.resource_path)
		if pixels != null:
			assert_true(pixels.has_mipmaps(), texture.resource_path + " must filter small leaves at distance")
	assert_gt(seen.size(), 0, "check the actual baked catalogue")

func _collect(path: String, out: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(path):
		if file.ends_with(".tres"): out.append(path.path_join(file))
	for child: String in DirAccess.get_directories_at(path):
		_collect(path.path_join(child), out)

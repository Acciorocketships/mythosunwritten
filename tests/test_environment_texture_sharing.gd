extends GutTest

const SHARING := preload("res://scripts/terrain/environment/EnvironmentTextureSharing.gd")

func test_aliases_are_exact_including_every_mip() -> void:
	assert_gt(SHARING._aliases.size(), 0)
	for path: String in SHARING._aliases:
		var source := (load(path) as Texture2D).get_image()
		var target := (load(SHARING._aliases[path]) as Texture2D).get_image()
		assert_eq(source.get_size(), target.get_size(), path)
		assert_eq(source.get_format(), target.get_format(), path)
		assert_eq(source.has_mipmaps(), target.has_mipmaps(), path)
		assert_true(source.get_data() == target.get_data(), path + " pixels and mip levels")

func test_materials_share_the_canonical_resource() -> void:
	var path: String = SHARING._aliases.keys()[0]
	var source := load(path) as Texture2D
	var target := load(SHARING._aliases[path]) as Texture2D
	var standard := StandardMaterial3D.new()
	standard.albedo_texture = source
	SHARING._material(standard)
	assert_same(standard.albedo_texture, target)
	var shader := Shader.new()
	shader.code = "shader_type spatial; uniform sampler2D atlas; void fragment() { ALBEDO = texture(atlas, UV).rgb; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("atlas", source)
	SHARING._material(material)
	assert_same(material.get_shader_parameter("atlas"), target)
	SHARING._material(material)
	assert_same(material.get_shader_parameter("atlas"), target, "idempotent preparation")

func test_load_batch_retains_source_only_until_release() -> void:
	var path: String = SHARING._aliases.keys()[0]
	var source := load(path) as Texture2D
	var reference := weakref(source)
	var material := StandardMaterial3D.new()
	material.albedo_texture = source
	var sources: Dictionary = {}
	SHARING._material(material, sources)
	source = null
	assert_not_null(reference.get_ref(), "the next visual in this batch can reuse its decoded source")
	assert_eq(sources.size(), 1)
	sources.clear()
	assert_null(reference.get_ref(), "the duplicate texture is released after loading")
	assert_not_null(material.albedo_texture, "the canonical texture stays owned by its material")

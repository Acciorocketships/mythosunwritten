extends GutTest

func _bush_set() -> Dictionary:
	var program := DressingCompiler.compile(load("res://terrain/dressing/index.tres"), EnvironmentCatalog.load_default())
	for row: Dictionary in program.sets:
		if row.id == &"ambient.bush": return row
	return {}

func test_bushes_replace_green_hue_using_the_existing_biome_canopy_material() -> void:
	for i in range(1,7):
		var descriptor := EnvironmentCatalog.load_default().descriptor(StringName("kaykit.bush.%02d" % i))
		var visual := load(descriptor.visual_path) as EnvironmentVisual
		assert_eq(descriptor.tint_group, &"bush")
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var material := piece.mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(material, "Bush %d must replace the authored green hue instead of multiplying it" % i)
				if material != null:
					assert_eq(material.shader.resource_path, "res://terrain/environment/materials/biome_canopy.gdshader")

func test_actual_bush_base_rejects_cliff_overhang_at_each_yaw_and_scale() -> void:
	_assert_support_for_step(2, Vector2(-10.9,12))

func test_actual_bush_base_rejects_hanging_off_a_walkable_slope() -> void:
	_assert_support_for_step(1, Vector2(-6,12))

func _assert_support_for_step(storey: int, anchor: Vector2) -> void:
	var set_data := _bush_set()
	assert_false(set_data.is_empty())
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-4,5):
		for x in range(-4,5):
			storeys[Vector2i(x,z)] = storey if x >= 0 else 0
			levels[Vector2i(x,z)] = 0
	var region := HeightfieldRegion.new(storeys, levels)
	var water := WaterFieldContext.new()
	water._ctx = {"ponds":[],"rivers":[],"buckets":{},"region":region}
	water._region=region
	water._coverage=Rect2(Vector2(-96,-96),Vector2(192,192))
	water._shore_limit=0.5
	for choice: Dictionary in set_data.choices:
		assert_false(choice.support_points.is_empty(), "Non-collidable bush still needs a visual ground stencil")
		for yaw in [0.0, PI*0.25, PI*0.5, PI*0.75]:
			for scale in [0.9,1.0,1.1]:
				var basis := Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale)
				assert_true(DressingField._qualify(set_data,anchor,region,water,null,choice,basis).is_empty(), "Grounded centre cannot leave the bush base across a drop or slope")
				assert_true(DressingField._qualify(set_data,Vector2(-24,12),region,water,null,choice,basis).has("y"), "The same bush remains eligible on level ground")

func test_bush_palette_is_an_absolute_color_inside_the_tree_and_substrate_envelope() -> void:
	for id: StringName in BiomeRegistry.biome_ids():
		var profile := BiomeRegistry.profile(id)
		var bush: Color = profile.foliage_tints.bush
		var tree: Color = profile.foliage_tints.tree
		var ground: Color = BiomeRegistry.SUBSTRATES[id]
		for channel in 3:
			assert_gte(bush[channel], minf(tree[channel],ground[channel]), "Bush uses absolute biome colour: %s" % id)
			assert_lte(bush[channel], maxf(tree[channel],ground[channel]), "Texture multipliers must not contaminate replacement hue: %s" % id)

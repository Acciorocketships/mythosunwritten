extends GutTest


func test_suspended_corner_keeps_source_timber_without_stone_block() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var source := (
		load(catalog.descriptor(&"suntail.decor.crossbar_1").visual_path) as EnvironmentVisual
	)
	var target := (
		load(catalog.descriptor(&"suntail.decor.crossbar_1_timber").visual_path)
		as EnvironmentVisual
	)
	var source_wood := _wood(source)
	var target_wood := _wood(target)
	assert_eq(target.pieces[0].mesh.get_surface_count(), 1, "The stone underside is absent")
	assert_eq(
		source_wood[Mesh.ARRAY_VERTEX],
		target_wood[Mesh.ARRAY_VERTEX],
		"All authored timber vertices are preserved"
	)
	assert_eq(
		source_wood[Mesh.ARRAY_INDEX],
		target_wood[Mesh.ARRAY_INDEX],
		"The native corner connection is unchanged"
	)
	var kit := SuntailBuildingKit.create()
	assert_eq(kit.asset(&"trim.floor_beam_corner"), &"suntail.decor.crossbar_1_timber")
	for finish: StringName in [&"oak", &"walnut"]:
		assert_not_null(
			catalog.descriptor(
				StringName("suntail.decor.crossbar_1_timber.finish_" + String(finish))
			)
		)


func _wood(visual: EnvironmentVisual) -> Array:
	for piece: EnvironmentVisualPiece in visual.pieces:
		for index in piece.mesh.get_surface_count():
			var material := piece.mesh.surface_get_material(index)
			if material.resource_name == "Wooden_Planks":
				return piece.mesh.surface_get_arrays(index)
	fail_test("Native timber surface missing")
	return []

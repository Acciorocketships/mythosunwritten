extends GutTest


func test_native_sill_closes_only_exposed_stone_to_plaster_gables() -> void:
	var kit := (
		preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
		. roof_study()
	)
	for axis in 2:
		var mass := BuildingMass.new()
		mass.add_storey(0, BuildingMass.rect_cells(Rect2i(0, 0, 2, 2)), BuildingMass.MATERIAL_STONE)
		var roof := mass.add_roof(Rect2i(0, 0, 2, 2), axis, 2, &"blue")
		var assembler := BuildingKitAssembler.new(kit)
		var beams := _heads(assembler.assemble(mass))
		assert_eq(beams.size(), 4, "Two complete native beams close each gable base")
		for beam: Dictionary in beams:
			assert_eq(beam.asset_id, &"suntail.decor.crossbar_2")
			assert_almost_eq((beam.transform as Transform3D).origin.y, 2.925, 0.001)
		roof.open_max = true
		assert_eq(
			_heads(assembler.assemble(mass)).size(), 2, "No band across an open roof junction"
		)
		roof.eave_band = 4
		assert_eq(
			_heads(assembler.assemble(mass)).size(),
			0,
			"A roof at another level does not band this wall"
		)


func test_timber_heads_are_not_duplicated_and_suntail_keeps_its_built_in_frame() -> void:
	var mass := BuildingMass.new()
	var storey := mass.add_storey(
		0, BuildingMass.rect_cells(Rect2i(0, 0, 2, 2)), BuildingMass.MATERIAL_TIMBER
	)
	mass.add_roof(Rect2i(0, 0, 2, 2), 0, 2, &"blue")
	var pure := (
		preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
		. roof_study()
	)
	assert_eq(_heads(BuildingKitAssembler.new(pure).assemble(mass)).size(), 8)
	storey.material = BuildingMass.MATERIAL_STONE
	assert_eq(
		_heads(BuildingKitAssembler.new(SuntailBuildingKit.create()).assemble(mass)).size(), 0
	)


func _heads(parts: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for part: Dictionary in parts:
		if part.role == &"trim.panel_head":
			result.append(part)
	return result

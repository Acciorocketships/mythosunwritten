extends GutTest

func test_explicit_hanging_crown_has_timber_rim_at_its_datum():
	var mass := BuildingMass.new()
	mass.ground_band = 6
	var storey := mass.add_storey(6, {Vector2i.ZERO:true}, BuildingMass.MATERIAL_STONE)
	storey.retaining = true
	storey.soffit = true
	storey.default_opening = BuildingMass.OPENING_PLAIN
	var parts := BuildingKitAssembler.new(SuntailBuildingKit.create()).assemble(mass)
	var beams := parts.filter(func(part:Dictionary)->bool:
		return part.role in [&"trim.floor_beam",&"trim.floor_beam_corner"])
	assert_eq(beams.size(),4,"An explicitly hanging crown closes every exposed underside edge, even at its own datum")

	var catalog := EnvironmentCatalog.load_default()
	var before: Array[AABB] = []
	for part: Dictionary in beams:
		before.append(part.transform*catalog.descriptor(part.asset_id).measured_aabb)
	KitVillageBuildings._fit_retaining_ceiling(parts,catalog)
	for index in beams.size():
		var part: Dictionary = beams[index]
		var local_beam := catalog.descriptor(part.asset_id).measured_aabb
		var stone: AABB = (part.transform as Transform3D).affine_inverse()*part.soffit_stone_transform \
			* catalog.descriptor(part.soffit_stone_asset).measured_aabb
		assert_lt(local_beam.position.z,stone.position.z,"Timber covers the inward stone projection")
		assert_gt(local_beam.end.z,stone.end.z,"Timber covers the outward stone projection")
		var after: AABB = part.transform*local_beam
		assert_almost_eq(after.position.y,before[index].position.y,.00001,"Fitting depth must not lower passage clearance")
		assert_almost_eq(after.end.y,before[index].end.y,.00001,"Keep the original bearing height")

func test_grounded_retaining_course_does_not_gain_hanging_trim():
	var mass := BuildingMass.new()
	mass.ground_band = 0
	var storey := mass.add_storey(0, {Vector2i.ZERO:true}, BuildingMass.MATERIAL_STONE)
	storey.retaining = true
	storey.default_opening = BuildingMass.OPENING_PLAIN
	var parts := BuildingKitAssembler.new(SuntailBuildingKit.create()).assemble(mass)
	assert_false(parts.any(func(part:Dictionary)->bool:
		return part.role in [&"trim.floor_beam",&"trim.floor_beam_corner"]),"Grounded stone stays grounded")

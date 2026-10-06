extends GutTest


func test_half_and_full_support_courses_share_native_masonry() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	var half := mass.add_storey(
		0, BuildingMass.rect_cells(Rect2i(0, 0, 2, 2)), BuildingMass.MATERIAL_STONE
	)
	half.bands = 1
	half.retaining = true
	var full := mass.add_storey(1, half.cells, BuildingMass.MATERIAL_STONE)
	full.retaining = true
	var parts := BuildingKitAssembler.new(kit).assemble(mass)
	var courses := 0
	for part: Dictionary in parts:
		if not String(part.role).begins_with("wall."):
			continue
		courses += 1
		assert_true(
			(
				part.asset_id
				in [&"pure_village.stone.retaining_half", &"pure_village.wall.stone.plain"]
			)
		)
		assert_almost_eq(
			(part.transform as Transform3D).basis.get_scale().y,
			1.0,
			0.001,
			"Native courses keep brick proportions"
		)
	assert_eq(courses, 16)


func test_reported_tunnel_supports_do_not_switch_to_plaster_or_framed_blue_stone() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var spatial := WarrenVolumetricSolver.generate(
		7, {}, program, WarrenVillageScaleProfile.for_id(&"standard")
	)
	var built := KitVillageBuildings.build(
		spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create()
	)
	var courses := 0
	for mass: BuildingMass in built.masses:
		if mass.stable_id not in [&"kit.retained", &"kit.tunnel-ceilings"]:
			continue
		for floor: Dictionary in mass.storeys:
			courses += 1
			assert_eq(floor.material, BuildingMass.MATERIAL_STONE)
	assert_gt(courses, 5)
	assert_eq(
		KitFloatingMassAudit.audit(spatial, spatial.compiled_fabric_cache(), built.masses).count, 0
	)

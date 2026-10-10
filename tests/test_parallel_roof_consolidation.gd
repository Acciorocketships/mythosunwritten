extends GutTest


func _pair(axis := 0) -> Array[BuildingMass]:
	var a := BuildingMass.new()
	var b := BuildingMass.new()
	a.add_roof(Rect2i(0, 0, 2, 2), axis, 4, &"blue")
	b.add_roof(Rect2i(0, 2, 2, 2) if axis == 0 else Rect2i(2, 0, 2, 2), axis, 4, &"red")
	return [a, b]


func test_short_parallel_piles_become_one_range_in_both_axes():
	for axis in 2:
		var masses := _pair(axis)
		var examined := []
		var count := KitRoofJunctions.combine_parallel(
			masses,
			func(_a, _b, rect, ridge, band):
				examined.append([rect, ridge, band])
				return true
		)
		assert_eq(count, 1)
		assert_eq(masses[0].roofs.size() + masses[1].roofs.size(), 1)
		assert_eq(masses[0].roofs[0].axis, 1 - axis)
		assert_eq(masses[0].roofs[0].rect.get_area(), 8)
		assert_eq(examined.size(), 1, "whole candidate envelope must be admitted")
		assert_eq(
			KitRoofJunctions.combine_parallel(masses, func(_a, _b, _r, _x, _y): return true),
			0,
			"idempotent"
		)


func test_headroom_refusal_preserves_both_roofs():
	var masses := _pair()
	assert_eq(KitRoofJunctions.combine_parallel(masses, func(_a, _b, _r, _x, _y): return false), 0)
	assert_eq(masses[0].roofs.size() + masses[1].roofs.size(), 2)
	assert_eq(
		KitRoofJunctions.combine_parallel(masses, Callable()), 0, "no unchecked envelope changes"
	)


func test_joined_branches_and_different_levels_are_not_rewritten():
	for kind in ["open", "level", "gap", "stagger"]:
		var masses := _pair()
		match kind:
			"open":
				masses[0].roofs[0].open_max = true
			"level":
				masses[1].roofs[0].eave_band = 6
			"gap":
				masses[1].roofs[0].rect = Rect2i(0, 3, 2, 2)
			"stagger":
				masses[1].roofs[0].rect = Rect2i(1, 2, 2, 2)
		assert_eq(
			KitRoofJunctions.combine_parallel(masses, func(_a, _b, _r, _x, _y): return true),
			0,
			kind
		)


func test_reported_skywalk_pair_consolidates_without_public_intrusions():
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		103, {}, program, WarrenVillageScaleProfile.for_id(&"grand")
	)
	assert_not_null(spatial)
	if spatial == null:
		return
	var fabric := spatial.compiled_fabric_cache()
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial, fabric, kit)
	var united := false
	var old_piles := 0
	for roof: Dictionary in built.roofs:
		if int(roof.eave_band) != 9:
			continue
		if (roof.rect as Rect2i).encloses(Rect2i(0, -4, 4, 2)) and int(roof.axis) == 0:
			united = true
		if roof.rect in [Rect2i(0, -4, 2, 2), Rect2i(2, -4, 2, 2)]:
			old_piles += 1
	assert_true(united, "103/grand bridge and landing share a continuous ridge")
	assert_eq(old_piles, 0)
	assert_eq(KitFloatingMassAudit.audit(spatial, fabric, built.masses).count, 0)
	assert_eq(
		preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built, kit).intrusions, 0
	)

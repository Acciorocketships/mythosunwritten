extends GutTest

const PURE := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")

func test_roof_cap_cannot_enter_reserved_square_above_slopes() -> void:
	for kit: BuildingKit in [SuntailBuildingKit.create(), PURE.roof_study()]:
		var designer := BuildingDesigner.new(kit)
		designer.forbidden = func(_cell: Vector2i, band: int) -> bool: return band >= 8
		var mass := BuildingMass.new()
		mass.add_storey(4, BuildingMass.rect_cells(Rect2i(0, 0, 2, 2)), BuildingMass.MATERIAL_TIMBER)
		assert_false(designer._roof_fits(mass, Rect2i(0, 0, 2, 2), 0, 6),
			"%s ridge cap rises above the nominal two-band slope" % kit.kit_id)
		designer.forbidden = func(_cell: Vector2i, band: int) -> bool: return band >= 9
		assert_true(designer._roof_fits(mass, Rect2i(0, 0, 2, 2), 0, 6),
			"A roof with a full free band above its nominal peak still fits")

func test_frozen_upper_court_has_no_roof_ridge_in_its_lawn() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var source := FROZEN.read("res://tests/fixtures/october5-interior-court-bed-source.txt")
	var spatial := FROZEN.spatial(source, SettlementFabricProgram.compile(catalog))
	var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create())
	# Interior of the photographed planted bed, native metres, band eight.
	# Use authored asset bounds, independent of the designer's nominal profile.
	var bed := AABB(Vector3(14.05, 12.05, -3.9), Vector3(1.9, 1.0, 3.8))
	var intrusions := []
	for part: Dictionary in built.placements:
		if not String(part.role).begins_with("trim.ridge"): continue
		var bounds: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		if bounds.intersects(bed): intrusions.append(part.stable_id)
	assert_eq(intrusions, [], "The planted square must not contain roof caps: %s" % [intrusions])
	var rooms_below := 0
	for mass: BuildingMass in built.masses:
		for storey: Dictionary in mass.storeys:
			if int(storey.floor_band) == 4:
				for cell: Vector2i in storey.cells:
					if cell == Vector2i(7, -1): rooms_below += 1
	assert_gt(rooms_below, 0, "Keep the inhabited building beneath the planted square")

func test_clearance_encloses_authored_ridges_for_even_and_odd_roofs() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for kit: BuildingKit in [SuntailBuildingKit.create(), PURE.roof_study()]:
		for depth in [2, 3, 4]:
			var mass := BuildingMass.new()
			mass.stable_id = &"ridge.envelope"
			mass.add_roof(Rect2i(0, 0, 3, depth), 0, 0, &"blue")
			var actual_top := -INF
			for part: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
				if not String(part.role).begins_with("trim.ridge"): continue
				var bounds: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
				actual_top = maxf(actual_top, bounds.end.y)
			assert_gt(actual_top, 0.0)
			assert_almost_eq(kit.roof_clearance_height(depth), actual_top, 0.001,
				"The reserved peak matches the assembled native ridge, including end caps")

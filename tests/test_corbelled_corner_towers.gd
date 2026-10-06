extends GutTest
const TOWER = preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")
const CORNER = preload("res://scripts/terrain/features/villages/kit/KitCornerTowers.gd")


func house() -> BuildingMass:
	var h := BuildingMass.new()
	h.stable_id = &"kit.corbel"
	for y in [0, 2, 4]:
		h.add_storey(y, BuildingMass.rect_cells(Rect2i(0, 0, 4, 3)), BuildingMass.MATERIAL_TIMBER)
	h.add_roof(Rect2i(0, 0, 4, 3), 0, 6, &"blue")
	return h


func fit(h: BuildingMass, blocked := false) -> Dictionary:
	var parts := CORNER.narrow_parts(2)
	parts.push_front(
		{
			"asset_id": &"pure_village.roof_turret.support",
			"role": &"tower.support",
			"transform": Transform3D.IDENTITY
		}
	)
	return TOWER.fit(
		h,
		SuntailBuildingKit.create(),
		EnvironmentCatalog.load_default(),
		Transform3D(Basis(Vector3.UP, -3 * PI / 4), Vector3(0, 3, 0)),
		2,
		TOWER.Form.CORBELLED_ROUND,
		func(_c, _b): return blocked,
		Callable(),
		parts
	)


func test_native_corbel_joins_continuous_corner_without_ground_footing():
	var candidate := fit(house())
	assert_false(candidate.is_empty(), "Native support bears in two adjoining host walls")
	if not candidate.is_empty():
		assert_eq(candidate.parts[0].asset_id, &"pure_village.roof_turret.support")


func test_corbel_cannot_float_bridge_a_missing_floor_or_enter_public_air():
	var h := house()
	h.storeys.remove_at(0)
	assert_true(fit(h).is_empty())
	assert_true(fit(house(), true).is_empty())
	h = house()
	h.storeys[0].inset = true
	assert_true(fit(h).is_empty())


func test_corbel_does_not_cover_lower_doorway_or_appear_on_short_house():
	var h := house()
	h.storeys[0].openings[Vector3i(0, 0, 2)] = BuildingMass.OPENING_DOOR
	var c := fit(h)
	assert_false(c.is_empty())
	if not c.is_empty():
		c.attachment = &"corner"
		assert_true(
			(
				preload("res://scripts/terrain/features/villages/kit/KitTowerHostFit.gd")
				. prepare(h, SuntailBuildingKit.create(), EnvironmentCatalog.load_default(), c)
				. is_empty()
			),
			"Corbel relief must not cover the doorway beneath its shaft"
		)
	h = house()
	h.storeys.resize(2)
	h.roofs[0].eave_band = 4
	assert_true(
		(
			CORNER
			. propose(
				h,
				SuntailBuildingKit.create(),
				EnvironmentCatalog.load_default(),
				[],
				[],
				[],
				Callable(),
				Callable(),
				{},
				true
			)
			. is_empty()
		)
	)


func test_generated_town_gains_a_supported_corner_spire():
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		31, {}, program, WarrenVillageScaleProfile.for_id(&"large")
	)
	assert_not_null(spatial)
	if spatial == null:
		return
	var built := KitVillageBuildings.build(
		spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create()
	)
	var corbels := 0
	for tower: Dictionary in built.towers:
		if int(tower.form) != TOWER.Form.CORBELLED_ROUND:
			continue
		corbels += 1
		assert_eq(tower.attachment, &"corner")
		assert_gte(int(tower.storeys), 2)
		assert_true(
			TOWER._corbel_corner_supported(tower.host, tower.kit, tower.pose, tower.storeys)
		)
		assert_not_null(EnvironmentCatalog.load_default().descriptor(tower.parts[0].asset_id))
	assert_gt(
		corbels,
		0,
		"31/large has no grounded corner sites; native wall support enables a proper spire"
	)

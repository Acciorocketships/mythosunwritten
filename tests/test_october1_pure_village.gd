extends GutTest
const PURE := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
const STYLES := preload("res://scripts/terrain/features/villages/kit/TownBuildingStyles.gd")
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")

func test_production_town_uses_coherent_families_with_measured_high_window_fallbacks() -> void:
	var seed_value := 1260018864828801968
	var source := WarrenMazeSitePlanner.plan(seed_value, {},
		WarrenVillageScaleProfile.select(seed_value), &"", false)
	var spatial := FROZEN.spatial(source, SettlementFabricProgram.compile(EnvironmentCatalog.load_default()))
	var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create())
	var seen := {}
	var checked := 0
	for part: Dictionary in built.placements:
		if part.role not in [&"wall.timber.plain", &"wall.timber.window", &"wall.timber.door",
			&"wall.stone.plain", &"wall.stone.window", &"wall.stone.door"]: continue
		var owner := StringName(String(part.stable_id).get_slice("/k", 0).trim_prefix("kit."))
		if not built.house_kits.has(owner): continue # Public feature masses use the base kit.
		var family: BuildingKit = built.house_kits[owner]
		if not String(part.asset_id).begins_with(String(family.kit_id) + "."):
			assert_eq(part.role,&"wall.timber.window","only the measured high opening may cross facade families")
			assert_true(part.asset_id in family.roles.get(&"wall.timber.window.high",[]))
			assert_eq(part.asset_id,&"pure_village.wall.plaster.window_open")
			var framing := 0
			for trim: Dictionary in built.placements:
				if trim.role != &"trim.high_window_head": continue
				if Vector2(trim.transform.origin.x,trim.transform.origin.z).distance_to(
						Vector2(part.transform.origin.x,part.transform.origin.z))<0.01:
					framing += 1
			assert_gt(framing,0,"the unframed fallback retains its host's native timber head")
		seen[family.kit_id] = true
		checked += 1
	assert_gt(checked, 50)
	assert_true(seen.has(&"suntail"))
	assert_true(seen.has(&"pure_village"))

func test_seeded_house_families_vary_without_changing_shared_datums() -> void:
	var base := SuntailBuildingKit.create()
	var counts: Dictionary = {}
	for seed_value in [7, 38, 2697992464]:
		for i in 20:
			var id := StringName("house.%d" % i)
			var a := STYLES.for_house(base, seed_value, id)
			var b := STYLES.for_house(base, seed_value, id)
			assert_eq(a.kit_id, b.kit_id)
			assert_eq(a.roles, b.roles)
			assert_eq(a.module_width, base.module_width)
			assert_eq(a.storey_height, base.storey_height)
			assert_eq(a.face_of(BuildingMass.MATERIAL_STONE), base.face_of(BuildingMass.MATERIAL_STONE))
			if a.kit_id == &"pure_village":
				assert_true(a.roof_edge_caps,"production uses the native roof grammar")
				assert_true(String(a.roles[&"roof.red.eave"][0]).begins_with("pure_village.roof."))
			counts[a.kit_id] = int(counts.get(a.kit_id, 0)) + 1
	assert_gt(int(counts.get(&"pure_village", 0)), 10)
	assert_gt(int(counts.get(&"suntail", 0)), 10)

func test_baked_facades_share_the_construction_metric_and_have_collision() -> void:
	var kit := PURE.create()
	assert_true(VillageWorldScale.matches_kit(kit))
	var catalog := EnvironmentCatalog.load_default()
	for id: StringName in kit.all_asset_ids():
		assert_true(catalog.has(id), "missing " + String(id))
		if not String(id).begins_with("pure_village."): continue
		var descriptor := catalog.descriptor(id)
		# Wall panels share the construction metric. Authored arches, blocks
		# and oriels deliberately retain different widths and fitted anchors.
		if String(id).begins_with("pure_village.wall."):
			assert_almost_eq(descriptor.measured_aabb.position.x, -1.0, 0.001)
			assert_almost_eq(descriptor.measured_aabb.size.x, 2.0, 0.001)
		assert_gt(descriptor.collision_piece_count, 0)

func test_unframed_panels_join_with_single_timbers() -> void:
	var mass := BuildingMass.new()
	mass.stable_id = &"test.joined_panels"
	mass.add_storey(0, BuildingMass.rect_cells(Rect2i(0, 0, 3, 2)), BuildingMass.MATERIAL_TIMBER)
	var parts := BuildingKitAssembler.new(PURE.create()).assemble(mass)
	var joints: Array[Vector3] = []
	var heads := 0
	for part: Dictionary in parts:
		if part.role == &"trim.panel_joint": joints.append(part.transform.origin)
		if part.role == &"trim.panel_head": heads += 1
	assert_eq(joints.size(), 6, "two long sides have two internal joints, short sides one")
	assert_eq(heads, 10)
	for i in joints.size():
		for j in range(i + 1, joints.size()): assert_gt(joints[i].distance_to(joints[j]), 0.1)

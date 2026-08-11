extends GutTest

## Architectural colour and lived-in dressing are structural recipe choices.
## These tests pin the spatial coherence and measured-asset contracts without
## solving a whole town.

static var _catalog: EnvironmentCatalog
static var _program: SettlementFabricProgram


func before_all() -> void:
	_catalog = EnvironmentCatalog.load_default()
	_program = SettlementFabricProgram.compile(_catalog)


func test_architectural_districts_are_deterministic_clustered_and_varied() \
		-> void:
	var first: Array[StringName] = []
	var second: Array[StringName] = []
	var themes: Dictionary = {}
	var adjacent_pairs := 0
	var matching_pairs := 0
	for z in range(-72, 73, 3):
		for x in range(-72, 73, 3):
			var origin := Vector3i(x, 0, z)
			var theme := WarrenSpatialFabricCompiler \
				._architectural_district_theme(origin, 7007)
			first.append(theme)
			second.append(WarrenSpatialFabricCompiler \
				._architectural_district_theme(origin, 7007))
			themes[theme] = true
			adjacent_pairs += 1
			matching_pairs += int(theme == WarrenSpatialFabricCompiler \
				._architectural_district_theme(origin + Vector3i(2, 0, 0), 7007))
	assert_eq(first, second, "district themes changed between identical queries")
	assert_eq(themes.size(), 3, "the sample did not reach all three facade families")
	assert_gt(float(matching_pairs) / float(adjacent_pairs), 0.72,
		"nearby houses no longer read as coherent architectural quarters")


func test_vertical_storeys_share_a_quarter_but_keep_distinct_recipe_phases() \
		-> void:
	var lower := _room(&"lower", Vector3i(10, 6, -14), 3)
	var upper := _room(&"upper", Vector3i(10, 8, -14), 4)
	var lower_id := WarrenSpatialFabricCompiler._room_recipe_id(lower, 91, false)
	var upper_id := WarrenSpatialFabricCompiler._room_recipe_id(upper, 91, true)
	assert_eq(WarrenSpatialFabricCompiler._room_recipe_facade_family(lower_id),
		WarrenSpatialFabricCompiler._room_recipe_facade_family(upper_id),
		"one vertical lineage crossed an architectural district")
	assert_ne(lower_id, upper_id,
		"successive storeys lost their alternating authored facade treatment")


func test_broad_roofs_counterbalance_the_honestly_orange_compact_roofs() \
		-> void:
	var cool := 0
	var warm := 0
	for z in range(-96, 97, 4):
		for x in range(-96, 97, 4):
			var room := _room(StringName("roof.%d.%d" % [x, z]),
				Vector3i(x, 8, z), 4)
			var recipe_id := WarrenSpatialFabricCompiler \
				._full_roof_recipe_id(room, 7007)
			if WarrenSpatialFabricCompiler._roof_recipe_family(recipe_id) == &"blue":
				cool += 1
			else:
				warm += 1
	assert_gt(cool, warm * 2,
		"wider roofs no longer offset the two orange compact-roof silhouettes")


func test_lived_in_recipes_use_the_new_measured_prop_families() -> void:
	assert_not_null(_program)
	var square := _program.recipe(&"roof.flat.square.terrace.north.lived")
	var square_east := _program.recipe(&"roof.flat.square.terrace.east.lived")
	var long_roof := _program.recipe(&"roof.flat.long.terrace.north.lived")
	var market := _program.recipe(&"market.covered.00.garden")
	assert_not_null(square)
	assert_not_null(square_east)
	assert_not_null(long_roof)
	assert_not_null(market)
	if square != null:
		var ids := square.asset_ids()
		assert_true(ids.has(SettlementFabricProgram.TERRACE_BENCH))
		assert_true(ids.has(SettlementFabricProgram.TERRACE_BARREL_A))
		assert_true(ids.has(SettlementFabricProgram.TERRACE_LANTERN_TABLE))
		assert_true(square.has_tag(&"furnished_roof_terrace"))
		assert_true(ids.has(SettlementFabricProgram.TERRACE_BUCKET))
		assert_true(ids.has(SettlementFabricProgram.TERRACE_CHAIR))
	if square_east != null:
		var ids := square_east.asset_ids()
		assert_true(ids.has(SettlementFabricProgram.TERRACE_BENCH_ALT))
		assert_true(ids.has(SettlementFabricProgram.TERRACE_FIREWOOD))
		assert_true(square_east.has_tag(&"roof_firewood"))
	if long_roof != null:
		assert_true(long_roof.asset_ids().has(
			SettlementFabricProgram.TERRACE_LANTERN_POST))
		assert_true(long_roof.has_tag(&"terrace_lamp"))
	if market != null:
		var ids := market.asset_ids()
		assert_true(ids.has(SettlementFabricProgram.TERRACE_BARREL_B))
		assert_true(ids.has(SettlementFabricProgram.TERRACE_LANTERN_TABLE))
		assert_true(ids.has(SettlementFabricProgram.TERRACE_PLANT_MID))
		assert_true(ids.has(SettlementFabricProgram.TERRACE_CRATE))
		assert_true(ids.has(SettlementFabricProgram.TERRACE_BAG))
		assert_true(ids.has(SettlementFabricProgram.TERRACE_BUCKET))
		assert_true(market.has_tag(&"market_lantern"))
		assert_true(market.has_tag(&"market_work_corner"))


func test_fabric_props_are_small_collisionless_catalog_assets() -> void:
	var expected := {
		SettlementFabricProgram.TERRACE_LANTERN_TABLE: Vector3(0.2, 0.6, 0.4),
		SettlementFabricProgram.TERRACE_LANTERN_POST: Vector3(1.6, 2.5, 0.6),
		SettlementFabricProgram.TERRACE_BARREL_A: Vector3(1.0, 1.1, 1.0),
		SettlementFabricProgram.TERRACE_BARREL_B: Vector3(1.0, 1.1, 1.0),
		SettlementFabricProgram.TERRACE_BAG: Vector3(0.7, 0.6, 0.6),
		SettlementFabricProgram.TERRACE_BENCH_ALT: Vector3(2.4, 0.6, 0.5),
		SettlementFabricProgram.TERRACE_BENCH: Vector3(2.1, 0.5, 0.5),
		SettlementFabricProgram.TERRACE_BUCKET: Vector3(0.6, 0.4, 0.6),
		SettlementFabricProgram.TERRACE_CHAIR: Vector3(0.6, 0.9, 0.5),
		SettlementFabricProgram.TERRACE_CRATE: Vector3(0.8, 0.8, 0.8),
		SettlementFabricProgram.TERRACE_FIREWOOD: Vector3(2.2, 1.3, 2.0),
		SettlementFabricProgram.TERRACE_PLANT_LOW: Vector3(1.0, 0.4, 0.9),
		SettlementFabricProgram.TERRACE_PLANT_MID: Vector3(0.9, 0.6, 0.9),
		SettlementFabricProgram.TERRACE_PLANT_BROAD: Vector3(0.9, 0.4, 0.8),
		SettlementFabricProgram.TERRACE_PLANT_TALL: Vector3(1.0, 0.6, 0.9),
	}
	for asset_id: StringName in expected.keys():
		var descriptor := _catalog.descriptor(asset_id)
		assert_not_null(descriptor, "uncatalogued fabric prop %s" % asset_id)
		if descriptor == null:
			continue
		assert_true(descriptor.tags.has(&"fabric_dressing"))
		assert_eq(descriptor.collision_piece_count, 0,
			"private-roof dressing unexpectedly added physics")
		var limit := expected[asset_id] as Vector3
		assert_lte(descriptor.measured_aabb.size.x, limit.x)
		assert_lte(descriptor.measured_aabb.size.y, limit.y)
		assert_lte(descriptor.measured_aabb.size.z, limit.z)


static func _room(stable_id: StringName, origin: Vector3i,
		storey_index: int) -> WarrenRoomStamp:
	return WarrenRoomStamp.new(stable_id, &"district.probe", &"building",
		origin, 0, storey_index, false, false)

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
	assert_eq(WarrenSpatialFabricCompiler._room_recipe_facade_phase(lower_id) / 2,
		WarrenSpatialFabricCompiler._room_recipe_facade_phase(upper_id) / 2,
		"one vertical lineage crossed its segmented building style")
	assert_ne(lower_id, upper_id,
		"successive storeys lost their alternating authored facade treatment")


func test_building_lineages_deterministically_reach_all_segment_styles() -> void:
	var reached: Dictionary = {}
	for index in 96:
		var source_id := StringName("district.lineage.%d" % index)
		var lower := WarrenRoomStamp.new(StringName("lower.%d" % index),
			source_id, &"building", Vector3i(index * 2, 0, -index),
			0, 0, false, false)
		var upper := WarrenRoomStamp.new(StringName("upper.%d" % index),
			source_id, &"slim", Vector3i(index * 2 + 3, 6, -index + 2),
			1, 3, false, false)
		var lower_style := WarrenSpatialFabricCompiler._building_style_index(
			lower, 7007)
		var upper_style := WarrenSpatialFabricCompiler._building_style_index(
			upper, 7007)
		assert_eq(lower_style, upper_style,
			"a stepped stack changed construction family across its lineage")
		reached[lower_style] = true
	assert_eq(reached.size(), SettlementFabricProgram.BUILDING_STYLE_COUNT,
		"the segmentation assignment cannot reach every building style")


func test_broad_roofs_keep_the_town_palette_cool_weighted() \
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
		"wider roofs no longer preserve the cool-weighted district palette")


func test_compact_blue_roofs_use_real_slate_palette_variants() -> void:
	assert_not_null(_catalog)
	assert_not_null(_program)
	var blue := _program.recipe(&"roof.tower.blue")
	var orange := _program.recipe(&"roof.tower.orange")
	assert_not_null(blue)
	assert_not_null(orange)
	if blue == null or orange == null:
		return
	assert_true(blue.asset_ids().has(
		SettlementFabricProgram.COMPACT_ROOF_SLATE_03))
	assert_false(blue.asset_ids().has(SettlementFabricProgram.COMPACT_ROOF_03),
		"a blue compact recipe silently returned to the orange source visual")
	assert_true(orange.asset_ids().has(SettlementFabricProgram.COMPACT_ROOF_06))
	var slate_descriptor := _catalog.descriptor(
		SettlementFabricProgram.COMPACT_ROOF_SLATE_03)
	var source_descriptor := _catalog.descriptor(
		SettlementFabricProgram.COMPACT_ROOF_03)
	assert_not_null(slate_descriptor)
	assert_not_null(source_descriptor)
	if slate_descriptor == null or source_descriptor == null:
		return
	assert_eq(slate_descriptor.measured_aabb, source_descriptor.measured_aabb,
		"a palette variant changed the compact roof's measured construction")
	var visual := load(slate_descriptor.visual_path) as EnvironmentVisual
	assert_not_null(visual)
	if visual != null and not visual.pieces.is_empty():
		assert_not_null(visual.pieces[0].material_override)
		assert_false(visual.pieces[0].use_instance_color,
			"the instance channel would erase the palette material's authored input")


func test_compact_and_slim_roofs_have_measured_dormer_variants() -> void:
	assert_not_null(_program)
	for recipe_id: StringName in [
			&"roof.tower.blue.dormer.left",
			&"roof.tower.orange.dormer.right",
			&"roof.slim.blue.dormer.left",
			&"roof.slim.orange.dormer.right",
	]:
		var recipe_value := _program.recipe(recipe_id)
		assert_not_null(recipe_value, String(recipe_id))
		if recipe_value == null:
			continue
		assert_true(recipe_value.has_tag(&"dormer"),
			"%s lost its finite dormer construction" % recipe_id)
		var dormer_count := 0
		for placement: Dictionary in recipe_value.placements:
			if not String(placement.id).contains("dormer"):
				continue
			dormer_count += 1
			var descriptor := _catalog.descriptor(StringName(placement.asset_id))
			var bounds := (placement.transform as Transform3D) * \
				descriptor.measured_aabb
			assert_almost_eq(bounds.position.y,
				SettlementFabricProgram.DORMER_EMBED_Y, 0.001,
				"%s exposes the dormer face's construction back" % recipe_id)
			assert_gte(bounds.position.y, 0.0,
				"%s must not hang its construction feet below the building eave" % recipe_id)
			assert_lt(bounds.position.y, 0.2,
				"%s must remain embedded below the host roof slope" % recipe_id)
			assert_lt(minf(bounds.size.x, bounds.size.z), 2.1,
				"%s dormer facade grew into a room-width second gable" % recipe_id)
			assert_lt(bounds.size.y, 2.1,
				"%s dormer grew into a full-storey second room" % recipe_id)
		assert_eq(dormer_count, 1,
			"%s must carry one integrated attic window" % recipe_id)
		assert_true(recipe_value.has_tag(&"complete_authored_dormer"),
			"%s lost its complete authored dormer shell" % recipe_id)
		assert_true(recipe_value.has_tag(&"authored_gabled_dormer"),
			"%s should use the compact gabled family" % recipe_id)
		var authored_shell_count := 0
		for stock_asset: StringName in [
			SettlementFabricProgram.ROOF_WINDOW_01,
			SettlementFabricProgram.ROOF_WINDOW_02,
			SettlementFabricProgram.ROOF_WINDOW_03,
			SettlementFabricProgram.ROOF_WINDOW_04,
		]:
			authored_shell_count += int(recipe_value.asset_ids().has(stock_asset))
		assert_eq(authored_shell_count, 1,
			"%s must contain one uniformly reduced authored dormer" % recipe_id)
		var pitch_count := recipe_value.placements.filter(
			func(value: Dictionary) -> bool:
				return String(value.id).begins_with("compact_roof.pitch.")).size()
		assert_eq(pitch_count, 0,
			"%s must not rebuild an authored dormer from detached awnings" % recipe_id)

	for recipe_id: StringName in [
		&"roof.long.blue.dormer.left",
		&"roof.square.orange.dormer.right",
	]:
		var recipe_value := _program.recipe(recipe_id)
		assert_not_null(recipe_value, String(recipe_id))
		if recipe_value != null:
			assert_true(recipe_value.has_tag(&"complete_authored_dormer"))
			assert_true(recipe_value.has_tag(&"authored_shed_dormer"),
				"%s should preserve the lower-profile shed family" % recipe_id)
			var dormer := recipe_value.placements.filter(
				func(value: Dictionary) -> bool:
					return String(value.id).contains("dormer"))[0] as Dictionary
			assert_almost_eq((dormer.transform as Transform3D).origin.y,
				SettlementFabricProgram.DORMER_SHED_EMBED_Y, 0.001,
				"%s must expose its low window course above the host tiles" % recipe_id)

	var opposed := _program.recipe(&"roof.long.blue.dormer.pair.left")
	assert_not_null(opposed)
	if opposed == null:
		return
	assert_true(opposed.has_tag(&"opposed_dormer"))
	var dormer_xs: Array[float] = []
	for placement: Dictionary in opposed.placements:
		if String(placement.id).contains("dormer"):
			dormer_xs.append((placement.transform as Transform3D).origin.x)
	assert_eq(dormer_xs.size(), 2)
	assert_lt(dormer_xs.min(), -0.75,
		"one longhouse dormer must face the negative eave")
	assert_gt(dormer_xs.max(), -0.75,
		"one longhouse dormer must face the positive eave")


func test_plain_flat_roof_has_a_measured_central_garden_fallback() -> void:
	assert_not_null(_program)
	for kind: String in ["tower", "slim", "square", "long"]:
		var recipe_id := StringName("roof.flat.%s.garden" % kind)
		var recipe_value := _program.recipe(recipe_id)
		assert_not_null(recipe_value, String(recipe_id))
		if recipe_value == null:
			continue
		assert_true(recipe_value.has_tag(&"flat_roof_garden"))
		assert_true(recipe_value.asset_ids().has(
			SettlementFabricProgram.ROOF_PLANTER))
		assert_true(recipe_value.has_tag(&"roof_decoration"))
		var micro := _program.recipe(StringName("%s.micro" % recipe_id))
		assert_not_null(micro, "%s needs the narrow measured fallback" % recipe_id)
		if micro != null:
			assert_true(micro.has_tag(&"micro_roof_garden"))
			assert_eq(micro.asset_ids(), [
				SettlementFabricProgram.ROOF_FLOWER_SMALL] as Array[StringName],
				"the last fallback remains one authored accent, not a bare cap")


func test_wrap_balconies_are_true_l_shaped_floorplates() -> void:
	assert_not_null(_program)
	for recipe_id: StringName in [
			&"balcony.wrap.left.blue.planted",
			&"balcony.wrap.right.orange.planted",
	]:
		var recipe_value := _program.recipe(recipe_id)
		assert_not_null(recipe_value, String(recipe_id))
		if recipe_value == null:
			continue
		assert_true(recipe_value.has_tag(&"wraparound_balcony"))
		var columns: Dictionary = {}
		for cell: Vector3i in recipe_value.walk_cells:
			columns[Vector2i(cell.x, cell.z)] = true
		assert_eq(columns.size(), 6,
			"%s must own a deep doorway landing plus one complete L return" \
				% recipe_id)
		var front_decks := 0
		var return_decks := 0
		var doorway_throats := 0
		var diagonal_supports := 0
		var guards := 0
		var rail_blocks_door := false
		var stair_high_tread_y := INF
		var supports_meet_deck := true
		for placement: Dictionary in recipe_value.placements:
			front_decks += int(String(placement.id).begins_with("floor.front.") \
				and StringName(placement.asset_id) \
				== SettlementFabricProgram.GALLERY_FLOOR)
			return_decks += int(StringName(placement.id) == &"floor.return" \
				and StringName(placement.asset_id) \
					== SettlementFabricProgram.SETBACK_CAP)
			doorway_throats += int(StringName(placement.id) \
					== &"floor.door.throat" and StringName(placement.asset_id) \
					== SettlementFabricProgram.SETBACK_CAP)
			diagonal_supports += int(String(placement.id).begins_with(
					"support.diagonal.") \
				and StringName(placement.asset_id) \
					== SettlementFabricProgram.DIAGONAL_BRACE)
			if String(placement.id).begins_with("support.diagonal."):
				var support_contract := _program.module_program.contract(
					SettlementFabricProgram.DIAGONAL_BRACE)
				supports_meet_deck = supports_meet_deck and is_equal_approx(
					(placement.transform as Transform3D).origin.y \
						+ support_contract.visual_bounds.end.y, 0.0)
			if StringName(placement.id) == &"stair.flight":
				var stair_contract := _program.module_program.contract(
					SettlementFabricProgram.STAIR_FULL)
				stair_high_tread_y = (placement.transform as Transform3D).origin.y \
					+ stair_contract.stair_high_tread_y
			guards += int(String(placement.id).begins_with("guard."))
			if String(placement.id).begins_with("guard."):
				var guard_origin := (placement.transform as Transform3D).origin
				rail_blocks_door = rail_blocks_door or (absf(guard_origin.x) < 0.1 \
					and guard_origin.z > 0.0 \
					and guard_origin.z < SettlementFabricProgram.CELL * 2.1)
		assert_eq(front_decks, 2,
			"%s needs two continuous native 3 m front-deck rows" % recipe_id)
		assert_eq(return_decks, 1,
			"%s needs one native 1.5 m side return" % recipe_id)
		assert_eq(doorway_throats, 1,
			"%s needs a third clear cell on the doorway circulation line" % recipe_id)
		assert_eq(diagonal_supports, 2,
			"%s needs two full-storey load paths below its overhang" % recipe_id)
		assert_true(supports_meet_deck,
			"%s support tops must meet the deck plane" % recipe_id)
		assert_almost_eq(stair_high_tread_y, 0.0, 0.001,
			"%s upper tread must be flush with the deck" % recipe_id)
		assert_eq(guards, 9,
			"%s must guard every exterior edge except its room and stair seams" \
				% recipe_id)
		assert_false(rail_blocks_door,
			"%s must leave three clear cells on the doorway circulation line" \
				% recipe_id)
		assert_true(recipe_value.placements.any(func(value: Dictionary) -> bool:
			return StringName(value.id) == &"stair.flight" \
				and StringName(value.asset_id) \
					== SettlementFabricProgram.STAIR_FULL),
			"%s needs an authored flight at its open guard seam" % recipe_id)
		var stair_high := recipe_value.socket(&"stair.high")
		var stair_low := recipe_value.socket(&"stair.low")
		assert_false(stair_high.is_empty())
		assert_false(stair_low.is_empty())
		assert_true(recipe_value.socket(&"stair.high.other").is_empty())
		assert_true(recipe_value.socket(&"stair.low.other").is_empty())
		assert_eq((stair_high.cell as Vector3i).y, 0)
		assert_eq((stair_low.cell as Vector3i).y, -2)
		assert_eq((stair_high.cell as Vector3i) - (stair_low.cell as Vector3i),
			-(stair_high.facing as Vector3i) * 2 + Vector3i.UP * 2 \
				+ Vector3i(0, 0, (stair_high.facing as Vector3i).x),
			"the switchback's real high tread must meet the deck and its low tread the public floor")


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

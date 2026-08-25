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


func test_a_stone_base_is_one_decision_per_building_not_per_wall() -> void:
	## TASK H1. The user's words were "the base is quite fragmented -- can we
	## fix this in a systematic way?". The systematic fix is that the question
	## is asked ONCE PER LINEAGE, so every ground room of one house answers the
	## same way whatever band, footprint kind, yaw or district it sits in and a
	## base course cannot break in the middle of a facade. Pinned here on the
	## lever itself rather than only on the towns it produces.
	var stone_lineages := 0
	for index in 240:
		var source_id := StringName("base.lineage.%d" % index)
		var answers: Dictionary = {}
		for variant in 6:
			var room := WarrenRoomStamp.new(
				StringName("ground.%d.%d" % [index, variant]), source_id,
				[&"building", &"slim", &"tower", &"row", &"long",
					&"building"][variant],
				Vector3i(index * 2 + variant, variant * 2, -index + variant),
				variant % 4, 0, true, variant % 2 == 0)
			answers[WarrenSpatialFabricCompiler._takes_stone_base(room,
				7007)] = true
		assert_eq(answers.size(), 1,
			("lineage %d disagreed with itself about its own base material " \
				+ "-- that disagreement IS a fragmented base") % index)
		stone_lineages += int(answers.has(true))
	# Both answers must actually occur, or the lever is a constant wearing a
	# hash: an all-timber town has no masonry where a mason would put it and an
	# all-stone town is the fortress this task removed.
	assert_gt(stone_lineages, 0, "no lineage ever takes a masonry ground storey")
	assert_lt(stone_lineages, 240, "every lineage takes a masonry ground storey")
	assert_almost_eq(float(stone_lineages) / 240.0,
		1.0 / float(WarrenSpatialFabricCompiler.STONE_BASE_LINEAGE_MODULUS),
		0.08, "the masonry minority drifted away from its declared rate")


func test_the_fragmented_base_detector_can_actually_fire() -> void:
	## `fragmented_base_run_count` is pinned at zero on every town, and a
	## detector that reads zero because it cannot fire is worse than no detector
	## at all. Driven here on the shapes it exists to tell apart.
	for run: Dictionary in [
		{"materials": [true, false, true], "fragmented": true,
			"why": "stone, timber, stone -- the named defect"},
		{"materials": [true, true, false, false, true], "fragmented": true,
			"why": "a longer masonry run resumed after a timber gap"},
		{"materials": [true, true, true], "fragmented": false,
			"why": "a coherent masonry base"},
		{"materials": [false, false, false], "fragmented": false,
			"why": "an absent masonry base -- the other legal state"},
		{"materials": [true, true, false, false], "fragmented": false,
			"why": "masonry that stops once is a corner, not a fragment"},
		{"materials": [false, true, true], "fragmented": false,
			"why": "masonry that starts once is a corner, not a fragment"},
		{"materials": [], "fragmented": false, "why": "an empty face"},
	]:
		var materials: Array[bool] = []
		materials.assign(run.materials as Array)
		assert_eq(WarrenSpatialFabricCompiler._run_is_fragmented(materials),
			bool(run.fragmented), String(run.why))


func test_the_fragment_detector_reads_a_planted_break_off_a_real_plan() -> void:
	## TASK H1 FIX 1. The test above drives the PREDICATE on hand-built arrays.
	## Nothing drove the ENUMERATION that feeds it -- and the enumeration is
	## where the bug the H1 report discloses actually lived: the run key put the
	## wall PLANE coordinate and the ALONG-RUN coordinate the wrong way round,
	## which cut every face run into runs of length 1 and left
	## `fragmented_base_run_count` structurally unable to fire while every suite
	## in the tree stayed green. So this drives
	## `exterior_wall_material_profile` end to end, on a synthetic plan with a
	## stone-timber-stone base planted along one lineage's own face.
	##
	## Three 2x2x2 tower stamps of ONE lineage stand shoulder to shoulder along
	## X, masonry-timber-masonry. Real towns cannot reach this state -- the
	## material is a property of the lineage -- which is exactly why the
	## detector has to be shown a town that can.
	var world_seed := 7007
	var lineage := &"h1.fragment.lineage"
	var building_id := &"h1.fragment.building"
	var grid := WarrenSpatialGrid.new(Vector3i(-8, 0, -8), Vector3i(24, 6, 24))
	var origins: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(2, 0, 0),
		Vector3i(4, 0, 0)]
	var recipes: Array[StringName] = [&"room.tower.base.rock.closed",
		&"room.tower.base.blue.closed", &"room.tower.base.rock.closed"]
	var all_cells: Array[Vector3i] = []
	for origin: Vector3i in origins:
		all_cells.append_array(WarrenRoomStamp.expected_private_cells(
			&"tower", origin, 0))
	var transaction := grid.begin_transaction(&"h1.fragment.volume")
	assert_true(transaction.assign_use(all_cells,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME, building_id))
	assert_true(transaction.commit(), grid.last_rejection)
	var building := WarrenBuildingVolume.new(building_id, 0)
	assert_true(building.add_private_cells(all_cells))
	assert_true(building.add_private_parent(&"h1.fragment.parent"))
	var units: Array[FabricUnit] = []
	for index in origins.size():
		var room := WarrenRoomStamp.new(
			StringName("h1.fragment.room.%d" % index), lineage, &"tower",
			origins[index], 0, 0, true, false)
		assert_true(room.add_private_cells(
			WarrenRoomStamp.expected_private_cells(&"tower", origins[index], 0)))
		assert_true(room.seal(grid, building_id), room.last_rejection)
		assert_true(building.add_room(room))
		units.append(FabricUnit.new(
			StringName("spatial.fabric.%s" % room.stable_id), recipes[index],
			origins[index], 0))
	assert_true(building.seal(grid), building.last_rejection)
	var plan := WarrenSpatialPlan.new(&"h1.fragment.plan", world_seed, grid)
	assert_true(plan.add_building(building))
	# A flat synthetic massif under the whole probe, so every wall face is
	# measured against a datum instead of falling out as off-massif.
	var columns: Dictionary = {}
	for column_z in range(-4, 5):
		for column_x in range(-4, 5):
			columns[Vector2i(column_x, column_z)] = {"base": 0, "top": 6}
	var massif := WarrenMassif.with_columns(world_seed, columns, 6)
	assert_true(massif.seal(), massif.last_rejection)
	var maze_source := WarrenMazeSourcePlan.new(world_seed, null, massif, null)

	var profile := WarrenSpatialFabricCompiler.exterior_wall_material_profile(
		plan, units, maze_source)
	assert_eq(int(profile.exterior_wall_unprofiled_unit_count), 0,
		"the walk never reached one of the probe's room units")
	assert_eq(int(profile.exterior_wall_off_datum_face_count), 0,
		"the probe left the synthetic massif, so no run was ever keyed")
	# A 6x2 cell slab has 16 perimeter faces per band, and it is two bands tall.
	assert_eq(int(profile.exterior_wall_face_count), 32)
	assert_eq(int(profile.exterior_wall_stone_face_count), 24)
	assert_eq(int(profile.exterior_wall_min_band_offset), 0)
	assert_eq(int(profile.exterior_wall_max_band_offset), 1)
	assert_eq(int(profile.exterior_wall_high_stone_face_count), 0)
	# Eight runs, not thirty-two: the long face at each band assembles along X
	# for both facings, plus the four one-cell end returns. A run count equal to
	# the FACE count is the keying defect -- every run length 1, nothing to
	# interrupt -- and it is what this number is here to catch.
	assert_eq(int(profile.base_face_run_count), 8,
		"base faces are not being assembled along the wall plane")
	# Both long facings, at both bands.
	assert_eq(int(profile.fragmented_base_run_count), 4,
		"the planted stone-timber-stone base went unseen")
	var details := profile.fragmented_base_run_details as Array
	assert_eq(details.size(), 4)
	for detail: Dictionary in details:
		assert_eq(String(detail.materials), "SSttSS",
			"the run was assembled in the wrong order")


func test_no_storey_the_town_wears_is_clad_in_stone_above_its_base() -> void:
	## TASK H1, the other half. Ashlar survives on a chosen shell only as a
	## GROUND storey; every upper storey is plank and plaster. Swept over a wide
	## lattice and every storey index the old masonry accent could reach.
	var upper_stone := 0
	var upper_rooms := 0
	var ground_stone := 0
	for world_seed: int in [0, 7, 91, 7007, 2697992464]:
		for index in 64:
			for storey in 4:
				var source_id := StringName("upper.lineage.%d" % index)
				var terrain_bearing := storey == 0
				var room := WarrenRoomStamp.new(
					StringName("room.%d.%d" % [index, storey]), source_id,
					&"building", Vector3i(index * 3 - 96, storey * 2,
						index - 32), 0, storey, terrain_bearing, false)
				var chosen := WarrenSpatialFabricCompiler._room_recipe_id(room,
					world_seed, true, 0, false, true)
				var stone := WarrenSpatialFabricCompiler \
					._room_recipe_facade_family(chosen) in [&"rock", &"stone"]
				if terrain_bearing:
					ground_stone += int(stone)
					continue
				upper_rooms += 1
				upper_stone += int(stone)
				# The RESERVED shell may still be masonry -- it is the wider of
				# the two authored modules and every space reservation in the
				# pipeline was measured against it (see `_room_recipe_id`).
				# What may never be masonry is what the town wears.
				assert_false(stone,
					"%s clads an upper storey in ashlar" % chosen)
	assert_eq(upper_stone, 0,
		"%d of %d upper storeys still choose ashlar" % [upper_stone,
			upper_rooms])
	assert_gt(ground_stone, 0,
		"removing the upper accent must not also delete the masonry plinth")


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
	## TASK F3 MEMBER 4. This test was RED, and it was the test that was wrong.
	## It asserted the GABLED family's registration (`DORMER_EMBED_Y` = 0.10,
	## `position.y < 0.2`, tag `authored_gabled_dormer`) on all three recipes,
	## and `roof.slim.orange.dormer.right` is a SHED-family dormer on purpose:
	## the blue compact roofs take the gabled attic-window shells 001/002 and
	## the orange ones take the shed shells 003/004, which have their own
	## reviewed 50% scale and 0.22 m registration
	## (`DORMER_SHED_EMBED_Y`). No recipe changed; the test now reads the
	## family each recipe DECLARES and holds it to that family's registration.
	## The split itself is not re-asserted here; it is owned by
	## `test_settlement_fabric::test_dormer_styles_keep_steep_gables_and
	## _replace_the_weak_shell_with_sheds`, which has been GREEN the whole time
	## this one was red -- two suites disagreed about the same recipe and only
	## one of them was measuring it.
	##
	## The `< 0.2` bound was a proxy for one authored rule -- the dormer stays
	## buried under the host pitch -- expressed as a constant that only the
	## gabled family could meet. It is replaced by the rule itself, measured
	## against the host roof's own silhouette in the same recipe. MEASURED
	## 2026-08-25: gabled dormers register at 0.100 and crown at 1.838, shed
	## dormers at 0.220 and 1.776, both inside the compact host's 2.173 m
	## ridge.
	assert_not_null(_program)
	for recipe_id: StringName in [
			&"roof.tower.blue.dormer.left",
			&"roof.slim.blue.dormer.left",
			&"roof.slim.orange.dormer.right",
	]:
		var recipe_value := _program.recipe(recipe_id)
		assert_not_null(recipe_value, String(recipe_id))
		if recipe_value == null:
			continue
		assert_true(recipe_value.has_tag(&"dormer"),
			"%s lost its finite dormer construction" % recipe_id)
		var gabled := recipe_value.has_tag(&"authored_gabled_dormer")
		var shed := recipe_value.has_tag(&"authored_shed_dormer")
		assert_true(gabled != shed,
			("%s must declare exactly one authored dormer family; the " \
				+ "registration it is held to depends on which") % recipe_id)
		var embed_y := SettlementFabricProgram.DORMER_EMBED_Y if gabled \
			else SettlementFabricProgram.DORMER_SHED_EMBED_Y
		# The host crown this dormer has to stay under: every placement in the
		# recipe that is NOT the dormer, which is the roof shell itself.
		var host := AABB()
		var host_started := false
		for placement: Dictionary in recipe_value.placements:
			if String(placement.id).contains("dormer"):
				continue
			var host_descriptor := _catalog.descriptor(
				StringName(placement.asset_id))
			if host_descriptor == null:
				continue
			var host_bounds := (placement.transform as Transform3D) \
				* host_descriptor.measured_aabb
			host = host_bounds if not host_started else host.merge(host_bounds)
			host_started = true
		assert_true(host_started,
			"%s carries no host roof shell for its dormer to sit in" % recipe_id)
		var dormer_count := 0
		for placement: Dictionary in recipe_value.placements:
			if not String(placement.id).contains("dormer"):
				continue
			dormer_count += 1
			var descriptor := _catalog.descriptor(StringName(placement.asset_id))
			var bounds := (placement.transform as Transform3D) * \
				descriptor.measured_aabb
			assert_almost_eq(bounds.position.y, embed_y, 0.001,
				"%s exposes the dormer face's construction back" % recipe_id)
			assert_gte(bounds.position.y, 0.0,
				"%s must not hang its construction feet below the building eave" % recipe_id)
			assert_lt(bounds.position.y + bounds.size.y,
				host.position.y + host.size.y,
				"%s must remain embedded below the host roof ridge" % recipe_id)
			assert_lt(minf(bounds.size.x, bounds.size.z), 2.1,
				"%s dormer facade grew into a room-width second gable" % recipe_id)
			assert_lt(bounds.size.y, 2.1,
				"%s dormer grew into a full-storey second room" % recipe_id)
		assert_eq(dormer_count, 1,
			"%s must carry one integrated attic window" % recipe_id)
		assert_true(recipe_value.has_tag(&"complete_authored_dormer"),
			"%s lost its complete authored dormer shell" % recipe_id)
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
		&"roof.tower.orange.dormer.right",
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
		var pillar_supports := 0
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
			pillar_supports += int(String(placement.id).begins_with(
					"support.pillar.") \
				and StringName(placement.asset_id) \
					== SettlementFabricProgram.DECK_PILLAR)
			if String(placement.id).begins_with("support.pillar."):
				var support_contract := _program.module_program.contract(
					SettlementFabricProgram.DECK_PILLAR)
				supports_meet_deck = supports_meet_deck and is_equal_approx(
					(placement.transform as Transform3D).origin.y \
						+ support_contract.visual_bounds.end.y, 0.0)
				assert_ne((placement.transform as Transform3D).origin.x, 0.0,
					"a balcony support may not stand on the doorway axis")
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
		assert_eq(pillar_supports, 2,
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

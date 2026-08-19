extends GutTest

## The maze front end is one sealed construction, not a ranked survivor. These
## tests exercise the source-plan boundary before any room or asset work can
## obscure a topology failure.

const PROFILE_IDS: Array[StringName] = [
	WarrenVillageScaleProfile.COMPACT,
	WarrenVillageScaleProfile.STANDARD,
	WarrenVillageScaleProfile.LARGE,
	WarrenVillageScaleProfile.GRAND,
]
const PROFILE_SEEDS: Array[int] = [17, 29, 43, 71]
const PRODUCTION_CORPUS: Array[String] = [
	"166029932451774690", "3910114991003307946", "6357506428441529412",
	"3613595803240038080:standard", "7:standard",
	"6052724565602100358", "3360408526109449337", "8702761491571936463",
	"6046713720826375059",
]


func _plan(world_seed: int, profile_id: StringName) -> WarrenMazeSourcePlan:
	var profile := WarrenVillageScaleProfile.for_id(profile_id)
	var massif := WarrenMassifBuilder.build(world_seed, {}, profile)
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	if massif == null:
		return null
	return WarrenMazeCarver.carve(world_seed, massif, profile)


func _reordered(massif: WarrenMassif) -> WarrenMassif:
	var out := WarrenMassif.new(massif.world_seed)
	var keys: Array = massif.columns.keys()
	keys.reverse()
	for column_value: Variant in keys:
		var column := column_value as Vector2i
		out.columns[column] = (massif.columns[column] as Dictionary).duplicate()
	out.core_top_bands = massif.core_top_bands
	assert_true(out.seal(), out.last_rejection)
	return out


func test_each_scale_builds_one_connected_building_fronted_maze() -> void:
	for index in PROFILE_IDS.size():
		var plan := _plan(PROFILE_SEEDS[index], PROFILE_IDS[index])
		assert_not_null(plan, "%s seed %d: %s; %s" % [PROFILE_IDS[index],
			PROFILE_SEEDS[index], WarrenMazeCarver.last_failure,
			WarrenMazeCarver.last_diagnostic])
		if plan == null:
			continue
		assert_true(plan.is_sealed(), plan.last_rejection)
		assert_eq(plan.excavation.portals.size(), 1,
			"v1 owns exactly one entrance")
		assert_eq(plan.summit_cell, plan.excavation.route.back())
		assert_gte(plan.market_zone.size(), 4,
			"every town owns a real market approach")
		assert_eq(plan.market_square_cells.size(), 4,
			"every town owns a typed 6 m by 6 m market square")
		assert_gte(float(plan.audit.frontage_ratio), 0.90,
			"public circulation fronts the buildable mass")
		assert_gte(float(plan.audit.addressed_column_ratio), 0.50,
			"the network materially reaches beyond the original canyon")
		assert_gte(float(plan.audit.source_solid_retention_ratio), 0.60,
			"the carved town still retains a substantial building mountain")
		assert_gte(int(plan.audit.route_span_bands),
			plan.scale_profile.route_span_range.x)
		assert_gt(int(plan.audit.alley_cell_count), 0,
			"the public realm is a network, not one canyon")
		assert_gte(int(plan.audit.loop_join_count), 1,
			"the public realm must contain a deliberate reconnecting loop")
		for cell: Vector3i in plan.excavation.public_cells():
			assert_eq(plan.state_at(cell),
				WarrenMazeSourcePlan.CellState.PASSAGE)


func test_production_seed_corpus_seals_without_attempt_search() -> void:
	var sealed := 0
	for spec: String in PRODUCTION_CORPUS:
		var parts := spec.split(":", false)
		var world_seed := int(parts[0])
		var profile := WarrenVillageScaleProfile.for_id(StringName(parts[1])) \
			if parts.size() > 1 else WarrenVillageScaleProfile.select(world_seed)
		var massif := WarrenMassifBuilder.build(world_seed, {}, profile)
		assert_not_null(massif, WarrenMassifBuilder.last_failure)
		if massif == null:
			continue
		var plan := WarrenMazeCarver.carve(world_seed, massif, profile)
		assert_not_null(plan, "seed %d: %s; %s" % [world_seed,
			WarrenMazeCarver.last_failure, WarrenMazeCarver.last_diagnostic])
		if plan == null:
			continue
		sealed += 1
		assert_true(plan.is_sealed())
		assert_gte(float(plan.audit.frontage_ratio), 0.90)
		assert_gte(int(plan.audit.loop_join_count), 1)
		assert_eq(plan.excavation.portals.size(), 1)
	assert_eq(sealed, PRODUCTION_CORPUS.size(),
		"one deterministic construction seals every corpus seed")


func test_same_inputs_and_dictionary_reordering_keep_the_same_maze() -> void:
	var profile := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.STANDARD)
	var massif := WarrenMassifBuilder.build(29, {}, profile)
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	if massif == null:
		return
	var first := WarrenMazeCarver.carve(29, massif, profile)
	var second := WarrenMazeCarver.carve(29, massif, profile)
	var reordered := WarrenMazeCarver.carve(29, _reordered(massif), profile)
	assert_not_null(first, WarrenMazeCarver.last_failure)
	assert_not_null(second, WarrenMazeCarver.last_failure)
	assert_not_null(reordered, WarrenMazeCarver.last_failure)
	if first == null or second == null or reordered == null:
		return
	assert_eq(first.deterministic_signature(),
		second.deterministic_signature())
	assert_eq(first.deterministic_signature(),
		reordered.deterministic_signature(),
		"dictionary insertion order may not steer construction")


func test_market_zone_is_the_ground_level_spine_prefix() -> void:
	var plan := _plan(17, WarrenVillageScaleProfile.COMPACT)
	assert_not_null(plan, "%s; %s" % [WarrenMazeCarver.last_failure,
		WarrenMazeCarver.last_diagnostic])
	if plan == null:
		return
	for index in plan.market_zone.size():
		var cell := plan.market_zone[index]
		assert_eq(cell, plan.excavation.route[index])
		assert_true(WarrenPassageLatticeRules.is_at_grade(plan.massif, cell))
		assert_eq(plan.passage_kinds[cell],
			WarrenMazeSourcePlan.PASSAGE_SPINE)
	assert_true(WarrenMazeSourcePlan._has_typed_square(
		plan.market_square_cells))
	for cell: Vector3i in plan.market_square_cells:
		assert_true(WarrenPassageLatticeRules.is_at_grade(plan.massif, cell))
		assert_true(cell in plan.market_zone \
			or plan.passage_kinds[cell] == WarrenMazeSourcePlan.PASSAGE_MARKET)


func test_sealed_maze_adapts_without_repair_to_the_common_volume_contract() \
		-> void:
	var plan := _plan(29, WarrenVillageScaleProfile.STANDARD)
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	if plan == null:
		return
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(plan)
	assert_not_null(volume, WarrenMazeVolumeAdapter.last_failure)
	if volume == null:
		return
	assert_true(volume.is_sealed(), volume.last_rejection)
	assert_eq(volume.mass_context.get(&"maze_source_plan"), plan)
	assert_eq(StringName(volume.mass_context.get(&"scale_profile_id", &"")),
		plan.scale_profile.scale_id)
	assert_eq(volume.market_square_cells, plan.market_square_cells)
	assert_eq(int(volume.audit.bore_without_path_count), 0,
		"every bored passage cell must retain a path lane")
	assert_eq(int(volume.audit.path_outside_bore_count), 0,
		"the adapter may not invent a path outside the bore")
	assert_gte(int(volume.audit.minimum_lane_count), 2,
		"every bored passage cell needs a player-width two-lane floor")
	assert_gte(volume.transitions.size(), volume.walk_cells.size(),
		"the connected common-volume graph must preserve a real cycle")
	for cell: Vector3i in plan.excavation.public_cells():
		assert_true(volume.has_frontage(cell),
			"every carved street cell reaches the common address contract")
	for cell: Vector3i in plan.excavation.carved:
		assert_false(volume.has_mass(cell),
			"the adapter may not put solid back into carved air")


func test_one_pass_block_partition_uses_authored_parcel_contracts() -> void:
	# M4 is still behind the production boundary. Pin one compatibility fixture
	# while the corpus-level solid-ownership and reservation gates are developed.
	var seed := 166029932451774690
	var profile := WarrenVillageScaleProfile.select(seed)
	var massif := WarrenMassifBuilder.build(seed, {}, profile)
	var source := WarrenMazeCarver.carve(seed, massif, profile)
	assert_not_null(source, "seed %d source" % seed)
	if source == null:
		return
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
	assert_not_null(volume, "seed %d volume: %s" % [seed,
		WarrenMazeVolumeAdapter.last_failure])
	if volume == null:
		return
	var parcels := WarrenMazeBlockPartitioner.partition(source, volume)
	assert_not_null(parcels, "seed %d partition: %s" % [seed,
		WarrenMazeBlockPartitioner.last_failure])
	if parcels == null:
		return
	assert_true(parcels.is_sealed())
	assert_gt(parcels.parcels.size(), 9)
	assert_gt(float(parcels.audit.get("maze_owned_solid_ratio", 0.0)), 0.35,
		"compatibility proof only; M4's corpus acceptance remains 0.85+")


func test_shared_stride_rules_match_the_transition_vocabulary() -> void:
	assert_eq(WarrenPassageLatticeRules.surface_band_span(1, 2, 1),
		Vector2i(0, 1), "stair intermediate owns both treads")
	assert_eq(WarrenPassageLatticeRules.stride_slot_bands(1, 2, 1),
		WarrenExcavation.HEADROOM_BANDS + 1)
	assert_true(WarrenExcavation.kind_allows(
		WarrenPassageLatticeRules.STAIR_UP.kind, 1, 2))
	assert_true(WarrenExcavation.kind_allows(
		WarrenPassageLatticeRules.RAMP_UP.kind, 1, 3))

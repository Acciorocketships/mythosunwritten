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

## Share of the massif's own authored mass a carved town still stands on.
##
## RE-PINNED DOWNWARD by the Phase E noise massif, 0.60 -> 0.58, on measurement
## and reported as a drop. Per profile, before -> after: compact 0.704 ->
## 0.621, standard 0.695 -> 0.632, large 0.673 -> 0.615, grand 0.633 -> 0.589.
## The mass itself went UP on all four (grand 1965 -> 2148 bands); what fell is
## the SHARE, because the terraced field leaves more of the town at grade and
## the alley ratchet -- which grows until it has fronted the mass, and stops --
## then finds more legal lane to bore: grand carves 722 bands before and 882
## after, on 9 percent more mountain. Frontage is asserted above and holds at
## 0.90 on every profile, so this is street the town gained rather than
## mountain it lost. Pinned one guard step under the measured worst; re-pin
## upward when a later wave narrows the streets again.
const SOURCE_RETENTION_FLOOR := 0.58
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
		assert_gte(float(plan.audit.source_solid_retention_ratio),
			SOURCE_RETENTION_FLOOR,
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
	#
	# Re-targeted onto the plot model (2026-08-22, task B3): the translator
	# reads PLOTS, so the fixture is the whole site planner rather than the
	# bore alone -- a carve-stage plan has no plots and nothing to translate.
	# Every assertion below is the same claim it always made about the
	# authored parcel contract; only the solid-ownership key moved, from the
	# deleted ledger audit's `maze_owned_solid_ratio` to the plot model's own
	# `maze_ownership_ratio` (plot-owned cells over derived solid), at the
	# same 0.35 compatibility bar.
	var seed := 166029932451774690
	var profile := WarrenVillageScaleProfile.select(seed)
	var source := WarrenMazeSitePlanner.plan(seed, {}, profile)
	assert_not_null(source, "seed %d source: %s" % [seed,
		WarrenMazeSitePlanner.last_failure])
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
	assert_gt(float(parcels.audit.get("maze_ownership_ratio", 0.0)), 0.35,
		"compatibility proof only; M4's corpus acceptance remains 0.85+")
	# The test's own name, now asserted rather than implied: every parcel is
	# sealed, opens its authored doorway onto its own address, and is one of
	# the five measured construction shapes.
	for parcel: WarrenBuildingParcel in parcels.parcels:
		assert_true(parcel.is_sealed(),
			"parcel %s is sealed" % parcel.stable_id)
		assert_true(WarrenParcelConstruction.door_serves_address(parcel),
			"parcel %s serves its own address" % parcel.stable_id)
		var profile_kind := StringName(WarrenParcelConstruction.profile_for(
			parcel).get("kind", &""))
		assert_true(profile_kind in [&"tower", &"slim", &"row", &"building",
			&"long"], "parcel %s is an authored contract shape (%s)" % [
				parcel.stable_id, profile_kind])


func test_shared_stride_rules_match_the_transition_vocabulary() -> void:
	assert_eq(WarrenPassageLatticeRules.surface_band_span(1, 2, 1),
		Vector2i(0, 1), "stair intermediate owns both treads")
	assert_eq(WarrenPassageLatticeRules.stride_slot_bands(1, 2, 1),
		WarrenExcavation.HEADROOM_BANDS + 1)
	assert_true(WarrenExcavation.kind_allows(
		WarrenPassageLatticeRules.STAIR_UP.kind, 1, 2))
	assert_true(WarrenExcavation.kind_allows(
		WarrenPassageLatticeRules.RAMP_UP.kind, 1, 3))


func _plan_walks(plan: WarrenMazeSourcePlan) -> Array:
	## Route then each lane's own [anchor] + cells walk, mirroring exactly the
	## sequences WarrenMazeCarver._select_bridge_spans iterated over. A bridge
	## span must be locatable as a contiguous run of one of these.
	var walks: Array = [plan.excavation.route]
	for lane: Dictionary in plan.excavation.lanes:
		var walk: Array[Vector3i] = [lane.anchor as Vector3i]
		walk.append_array(lane.cells as Array[Vector3i])
		walks.append(walk)
	return walks


func _locate_span(walks: Array, span: Array) -> Dictionary:
	var span_cells := span as Array[Vector3i]
	for walk_value: Variant in walks:
		var walk := walk_value as Array[Vector3i]
		for start in range(walk.size() - span_cells.size() + 1):
			var matches := true
			for offset in span_cells.size():
				if walk[start + offset] != span_cells[offset]:
					matches = false
					break
			if matches:
				return {"walk": walk, "start": start}
	return {}


func _neighbor_may_stay_covered(plan: WarrenMazeSourcePlan,
		cell: Vector3i) -> bool:
	## Streets open to sky by default; the only cells that stay covered on
	## purpose are the market approach/square, a facade over/under crossing
	## (WarrenMazeCarver._open_passages_to_air), and another bridge-span cell
	## (review finding 2026-08-22, minor: two spans can sit walk-adjacent when
	## one window ends right where the next begins). A bridge span's immediate
	## walk neighbour is only a genuine "not a tunnel end" proof when it is
	## NOT covered for one of those three documented reasons.
	if cell in plan.market_zone or cell in plan.market_square_cells:
		return true
	for span: Array in plan.excavation.bridge_spans:
		if cell in span:
			return true
	return WarrenMazeCarver._column_is_public_facade(plan.massif,
		plan.excavation, Vector2i(cell.x, cell.z), cell)


func test_bridge_spans_are_retained_over_open_streets() -> void:
	var seeds: Array[int] = [1, 2, 3, 4, 5, 6]
	var seeds_with_spans := 0
	var summary := PackedStringArray()
	for seed in seeds:
		var plan := _plan(seed, WarrenVillageScaleProfile.STANDARD)
		assert_not_null(plan, "seed %d: %s; %s" % [seed,
			WarrenMazeCarver.last_failure, WarrenMazeCarver.last_diagnostic])
		if plan == null:
			continue
		var spans := plan.excavation.bridge_spans
		summary.append("%d:%d" % [seed, spans.size()])
		if spans.is_empty():
			continue
		seeds_with_spans += 1
		var walks := _plan_walks(plan)
		for span_value: Variant in spans:
			var span := span_value as Array[Vector3i]
			assert_gt(span.size(), 0, "seed %d span is non-empty" % seed)
			var located := _locate_span(walks, span)
			assert_false(located.is_empty(),
				"seed %d span %s must lie on the route or a lane" % [seed, span])
			if located.is_empty():
				continue
			var walk := located.walk as Array[Vector3i]
			var start := int(located.start)
			for offset in span.size():
				var cell := span[offset]
				assert_true(bool(plan.excavation.covered.get(cell, false)),
					"seed %d span cell %s must be covered" % [seed, cell])
				assert_false(cell in plan.market_square_cells,
					"seed %d span cell %s must not be a market-square cell" \
						% [seed, cell])
				assert_false(cell in plan.market_zone,
					"seed %d span cell %s must not be the market approach or " \
						% [seed, cell] + "the portal")
				var previous: Vector3i = walk[start + offset - 1]
				var direction := Vector2i(cell.x - previous.x,
					cell.z - previous.z)
				assert_ne(direction, Vector2i.ZERO,
					"seed %d span cell %s needs a level travel direction" \
						% [seed, cell])
				var perpendicular := Vector2i(-direction.y, direction.x)
				var column := Vector2i(cell.x, cell.z)
				var roof := cell.y + WarrenExcavation.HEADROOM_BANDS
				# The whole interval, not its two ends (review finding
				# 2026-08-23, minor): a crossing passage at cell.y + 1 would
				# leave the flank hollow exactly where the skywalk's wall has
				# to be. Mirrors WarrenMazeCarver._bridge_span_is_legal and
				# WarrenExcavation._bridge_spans_are_legal, which both now
				# read range(cell.y, roof + 1).
				for flank: Vector2i in [column + perpendicular,
						column - perpendicular]:
					for band in range(cell.y, roof + 1):
						assert_eq(plan.state_at(
							Vector3i(flank.x, band, flank.y)),
							WarrenMazeSourcePlan.CellState.SOLID,
							("seed %d span cell %s flank %s must be solid " \
								+ "at band %d of [%d, %d]") % [seed, cell,
									flank, band, cell.y, roof])
				assert_gte(plan.massif.top_at(column) - cell.y,
					WarrenExcavation.HEADROOM_BANDS + 2,
					"seed %d span cell %s needs enough retained mass" \
						% [seed, cell])
			# The cells just outside the span, in the same walk, prove this is
			# a bridge crossing an open street rather than a tunnel that
			# happens to stop retaining its roof. Since streets open to sky by
			# default now, the only legitimate reason a neighbour stays covered
			# is that it is itself another deliberately-covered feature (the
			# market, or a facade crossing) -- not an arbitrary dead end.
			var before_index := start - 1
			if before_index >= 0:
				var predecessor := walk[before_index]
				assert_true(not bool(plan.excavation.covered.get(predecessor, false)) \
						or _neighbor_may_stay_covered(plan, predecessor),
					"seed %d span %s predecessor %s must be open, or itself a " \
						% [seed, span, predecessor] + "market/facade cell")
			var after_index := start + span.size()
			if after_index < walk.size():
				var successor := walk[after_index]
				assert_true(not bool(plan.excavation.covered.get(successor, false)) \
						or _neighbor_may_stay_covered(plan, successor),
					"seed %d span %s successor %s must be open, or itself a " \
						% [seed, span, successor] + "market/facade cell")
	assert_gte(seeds_with_spans, 4,
		"at least 4 of 6 standard seeds must retain a bridge span: %s" \
			% ", ".join(summary))


func test_bridge_spans_are_deterministic() -> void:
	var profile := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.STANDARD)
	var massif := WarrenMassifBuilder.build(2, {}, profile)
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	if massif == null:
		return
	var first := WarrenMazeCarver.carve(2, massif, profile)
	var second := WarrenMazeCarver.carve(2, massif, profile)
	assert_not_null(first, WarrenMazeCarver.last_failure)
	assert_not_null(second, WarrenMazeCarver.last_failure)
	if first == null or second == null:
		return
	assert_eq(first.excavation.bridge_spans.size(),
		second.excavation.bridge_spans.size())
	for index in first.excavation.bridge_spans.size():
		assert_eq(first.excavation.bridge_spans[index] as Array[Vector3i],
			second.excavation.bridge_spans[index] as Array[Vector3i])
	assert_eq(first.deterministic_signature(), second.deterministic_signature())


func _bridge_cell_directions(plan: WarrenMazeSourcePlan) -> Dictionary:
	## Vector3i bridge cell -> Vector2i travel direction, re-derived from the
	## walk (route, or an `[anchor] + lane.cells` walk) the same way
	## WarrenExcavation._bridge_span_direction does for seal()'s own
	## flank re-check, so the test's notion of "flank" can never silently
	## diverge from the carver's or the excavation's.
	var walks := _plan_walks(plan)
	var directions: Dictionary = {}
	for span_value: Variant in plan.excavation.bridge_spans:
		var span := span_value as Array[Vector3i]
		var located := _locate_span(walks, span)
		if located.is_empty():
			continue
		var walk := located.walk as Array[Vector3i]
		var start := int(located.start)
		for offset in span.size():
			var cell := span[offset]
			var previous: Vector3i = walk[start + offset - 1]
			directions[cell] = Vector2i(cell.x - previous.x,
				cell.z - previous.z)
	return directions


func _bridge_protected_columns(directions: Dictionary) -> Dictionary:
	## Vector2i column -> int cap, mirroring
	## WarrenMazeCarver._build_bridge_carve_cap exactly, but re-derived here
	## independently rather than calling the carver's helper, so this test
	## does not just check the implementation against itself.
	var protected_columns: Dictionary = {}
	for cell_value: Variant in directions.keys():
		var cell := cell_value as Vector3i
		var direction := directions[cell_value] as Vector2i
		var column := Vector2i(cell.x, cell.z)
		if not protected_columns.has(column) or cell.y < int(protected_columns[column]):
			protected_columns[column] = cell.y
		for flank: Vector2i in WarrenMazeCarver._bridge_flank_columns(cell, direction):
			if not protected_columns.has(flank) or cell.y < int(protected_columns[flank]):
				protected_columns[flank] = cell.y
	return protected_columns


func _assert_bridge_carve_cap_pair(plan: WarrenMazeSourcePlan, other: Vector3i,
		column: Vector2i, bridge_y: int) -> void:
	## `other` may share either the bridge's OWN column or a flank column. On
	## its own column, [bridge_y, bridge_y + HEADROOM_BANDS) is the bridge
	## cell's own pre-existing walk tunnel -- always carved regardless of this
	## fix, so only the specific roof band is a claim this mechanism actually
	## makes; on a flank column there is no such pre-existing tunnel, but the
	## roof band is still the one invariant guaranteed identically in both
	## cases, so that is what gets asserted uniformly.
	var roof := bridge_y + WarrenExcavation.HEADROOM_BANDS
	if other.y < bridge_y:
		for band in range(other.y + WarrenExcavation.HEADROOM_BANDS, bridge_y):
			assert_true(plan.excavation.carved.has(
				Vector3i(other.x, band, other.z)),
				"column %s band %d below the bridge floor %d must be " \
					% [column, band, bridge_y] + "carved (open)")
		assert_false(plan.excavation.carved.has(
			Vector3i(other.x, roof, other.z)),
			"column %s roof band %d for bridge floor %d must stay solid, " \
				% [column, roof, bridge_y] + "not carved")
	else:
		for band in range(other.y, plan.massif.top_at(column)):
			assert_true(plan.excavation.carved.has(
				Vector3i(other.x, band, other.z)),
				"column %s band %d above the bridge floor %d must open " \
					% [column, band, bridge_y] + "fully to sky")


func _assert_bridge_carve_cap_helper_synthetic() -> void:
	## No seed-1..12 standard corpus pair existed on this run; unit-test the
	## factored WarrenMazeCarver._build_bridge_carve_cap helper directly
	## (review finding 2026-08-22, Important) so the cross-column protection
	## mechanism is never left completely untested.
	var bridge_cell := Vector3i(10, 5, 10)
	var direction := Vector2i(1, 0)
	var cap := WarrenMazeCarver._build_bridge_carve_cap(
		{bridge_cell: direction})
	var own_column := Vector2i(10, 10)
	var flank_a := Vector2i(10, 11)
	var flank_b := Vector2i(10, 9)
	assert_eq(int(cap.get(own_column, -1)), 5,
		"the bridge's own column must be capped at its floor")
	assert_eq(int(cap.get(flank_a, -1)), 5,
		"the +z flank column must be capped at the bridge floor")
	assert_eq(int(cap.get(flank_b, -1)), 5,
		"the -z flank column must be capped at the bridge floor")
	# Two bridge cells sharing a column take the lower (tighter) cap.
	var lower_cell := Vector3i(10, 2, 10)
	var cap_two := WarrenMazeCarver._build_bridge_carve_cap(
		{bridge_cell: direction, lower_cell: direction})
	assert_eq(int(cap_two.get(own_column, -1)), 2,
		"two bridges sharing a column must cap at the lower floor")


func test_bridge_carve_cap_protects_decks_and_opens_upper_passages() -> void:
	var found_pair := false
	for seed in range(1, 13):
		var plan := _plan(seed, WarrenVillageScaleProfile.STANDARD)
		if plan == null or plan.excavation.bridge_spans.is_empty():
			continue
		var directions := _bridge_cell_directions(plan)
		var protected_columns := _bridge_protected_columns(directions)
		if protected_columns.is_empty():
			continue
		var bridge_cells: Dictionary = {}
		for cell_value: Variant in directions.keys():
			bridge_cells[cell_value as Vector3i] = true
		for other: Vector3i in plan.excavation.public_cells():
			if bridge_cells.has(other):
				continue
			var column := Vector2i(other.x, other.z)
			if not protected_columns.has(column):
				continue
			# `other` may independently stay covered for a reason unrelated to
			# this fix (the market, or its own facade crossing) -- its carve
			# state then proves nothing about the bridge cap, so skip it rather
			# than asserting a behaviour this mechanism never claimed to cause.
			if other in plan.market_zone or other in plan.market_square_cells \
					or WarrenMazeCarver._column_is_public_facade(plan.massif,
						plan.excavation, column, other):
				continue
			found_pair = true
			var bridge_y := int(protected_columns[column])
			print("seed %d: passage %s shares column %s with a bridge " \
				% [seed, other, column] + "floor at y=%d" % bridge_y)
			_assert_bridge_carve_cap_pair(plan, other, column, bridge_y)
	if not found_pair:
		_assert_bridge_carve_cap_helper_synthetic()

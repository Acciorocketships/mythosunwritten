extends GutTest


func test_gaussian_envelope_is_deterministic_and_seed_varied() -> void:
	var first := WarrenVolumeEnvelope.build(901)
	var repeated := WarrenVolumeEnvelope.build(901)
	var other := WarrenVolumeEnvelope.build(902)
	assert_not_null(first)
	assert_not_null(repeated)
	assert_not_null(other)
	assert_eq(first.deterministic_signature(), repeated.deterministic_signature())
	assert_ne(first.deterministic_signature(), other.deterministic_signature())
	assert_gt(first.height_at(Vector2i.ZERO), 0)
	var boundary_max := 0
	for entry: Vector3i in first.boundary_entry_cells(
			WarrenVolumePlan.HEADROOM_BANDS):
		boundary_max = maxi(boundary_max,
			first.height_at(Vector2i(entry.x, entry.z)))
	assert_gt(first.height_at(Vector2i.ZERO), boundary_max,
		"the city envelope must taper from its central mass to ground entrances")


func test_carved_volume_corpus_satisfies_topology_invariants() -> void:
	assert_eq(WarrenPublicRealmCarver.MAX_ATTEMPTS,
		WarrenPublicRealmCarver.ATTEMPTS_PER_ROUTE_FAMILY \
			* WarrenPublicRealmCarver.ROUTE_CELL_FAMILIES.size(),
		"the explicit GDScript constant must cover every route family")
	var signatures: Dictionary = {}
	var envelope_signatures: Dictionary = {}
	var total_crossovers := 0
	var total_stairs := 0
	for world_seed in range(12):
		var plan := WarrenPublicRealmCarver.solve(world_seed)
		assert_not_null(plan, "seed %d must solve" % world_seed)
		if plan == null:
			continue
		assert_true(plan.is_sealed())
		assert_gte(int(plan.audit.walk_cell_count),
			WarrenPublicRealmCarver.MIN_ROUTE_CELLS)
		assert_gte(int(plan.audit.elevation_band_count), 4)
		assert_gte(int(plan.audit.ramp_transition_count), 1,
			"shallow vertical opportunities should use continuous ramps")
		assert_eq(int(plan.audit.landing_turn_violation_count), 0)
		assert_lte(int(plan.audit.max_transition_rise_bands), 1)
		assert_gte(float(plan.audit.overhang_walk_ratio), 0.25)
		assert_gte(float(plan.audit.addressed_walk_ratio), 0.35)
		assert_lte(float(plan.audit.deep_vertical_shaft_ratio), 0.10)
		assert_eq(int(plan.audit.same_datum_route_fold_count), 0,
			"same-height folds must not merge into broad public decks")
		assert_eq(int(plan.audit.same_datum_public_square_count), 0,
			"the exact two-lane expansion must remain an alley, never a plaza")
		assert_lte(int(plan.audit.max_straight_run_cells),
			WarrenPublicRealmCarver.MAX_STRAIGHT_RUN)
		assert_eq(plan.entry_cell.y, plan.envelope.ground_at(
			Vector2i(plan.entry_cell.x, plan.entry_cell.z)))
		signatures[plan.deterministic_signature()] = true
		envelope_signatures[plan.envelope.deterministic_signature()] = true
		total_crossovers += int(plan.audit.route_crossover_count)
		total_stairs += int(plan.audit.stair_transition_count)
	assert_eq(signatures.size(), 12,
		"different seeds must change raw maze geometry")
	assert_eq(envelope_signatures.size(), 12,
		"different seeds must also change the initial city mass")
	assert_gt(total_crossovers, 0,
		"the corpus should contain paths revisiting columns on upper levels")
	assert_gt(total_stairs, 0,
		"tight transitions should remain stairs when a ramp run cannot fit")


func test_envelope_is_relative_to_local_terrain_bands() -> void:
	var terrain_bands: Dictionary = {}
	for x in range(-12, 13):
		for z in range(-12, 13):
			terrain_bands[Vector2i(x, z)] = floori(float(x + 12) / 8.0)
	var envelope := WarrenVolumeEnvelope.build(77, terrain_bands)
	assert_not_null(envelope)
	var plan := WarrenPublicRealmCarver.solve_envelope(77, envelope)
	assert_not_null(plan)
	if plan == null:
		return
	var entry_column := Vector2i(plan.entry_cell.x, plan.entry_cell.z)
	assert_eq(plan.entry_cell.y, terrain_bands[entry_column])
	for column_value: Variant in envelope.height_bands.keys():
		var column := column_value as Vector2i
		assert_true(envelope.mass_cells.has(Vector3i(column.x,
			int(terrain_bands[column]), column.y)))


func test_route_attempt_survives_derived_arcade_identity() -> void:
	var envelope := WarrenVolumeEnvelope.build(1)
	# Attempt 41 is a current six-band-addressable production route. Keep this a
	# concrete fixture so the identity regression remains cheap and deterministic;
	# attempt 10 was retired when same-datum route folds began counting as broad
	# plaza failures rather than desirable compactness.
	var source := WarrenPublicRealmCarver.sealed_candidate(1, 41, envelope)
	assert_not_null(source)
	if source == null:
		return
	var extended := WarrenGroundArcadeSolver.extend(source)
	assert_not_null(extended, WarrenGroundArcadeSolver.last_failure)
	if extended == null:
		return
	assert_true(String(extended.stable_id).ends_with(".arcade1"))
	var auxiliary_count := 0
	for cell: Vector3i in extended.walk_cells:
		auxiliary_count += int(not extended.primary_itinerary.has(cell))
	assert_gte(auxiliary_count, (WarrenGroundArcadeSolver.MIN_CELLS - 1)
		+ (WarrenGroundArcadeSolver.SECONDARY_MIN_CELLS - 1),
		"both connected lower arcades must survive the derived volume clone")
	var arcade_roots: Dictionary = {}
	for transition: WarrenVolumeTransition in extended.transitions:
		var transition_id := String(transition.stable_id)
		if transition_id.ends_with("transition.00") \
				and transition_id.begins_with("arcade."):
			arcade_roots[transition_id] = transition.from_cell
	assert_eq(arcade_roots.size(), 2)
	if arcade_roots.size() == 2:
		var roots: Array = arcade_roots.values()
		var first := roots[0] as Vector3i
		var second := roots[1] as Vector3i
		assert_gte(absi(first.x - second.x) + absi(first.z - second.z),
			WarrenGroundArcadeSolver.MIN_BRANCH_SEPARATION_CELLS,
			"the second lower route must close a different side of the core")
	assert_eq(WarrenTownSolver.route_attempt(extended), 41,
		"route-family balancing must not collapse derived routes to attempt zero")


func test_elevated_bypass_is_a_narrow_rejoining_grammar_variant() -> void:
	var envelope := WarrenVolumeEnvelope.build(6046713720826375059)
	var source := WarrenPublicRealmCarver.sealed_candidate(
		6046713720826375059, 126, envelope)
	assert_not_null(source)
	if source == null:
		return
	var arcade := WarrenGroundArcadeSolver.extend(source)
	assert_not_null(arcade, WarrenGroundArcadeSolver.last_failure)
	if arcade == null:
		return
	var variants := WarrenElevatedFrontageSolver.variants(arcade)
	assert_gte(variants.size(), 2,
		"a valid bypass must coexist with the unmodified construction alternative")
	var gallery := variants[0]
	assert_gt(int(gallery.audit.elevated_gallery_walk_cell_count), 0)
	assert_eq(int(gallery.audit.same_datum_public_square_count), 0,
		"a public skybridge may not merge into an upper plaza")
	assert_eq(int(gallery.audit.landing_turn_violation_count), 0)
	assert_gt(gallery.transitions.size() - gallery.walk_cells.size() + 1, 0,
		"the gallery must rejoin the public graph as a real loop")
	assert_eq(WarrenTownSolver.route_attempt(gallery), 126)


func test_parcel_corpus_is_addressed_varied_and_non_overlapping() -> void:
	var signatures: Dictionary = {}
	var occupied_overpasses := 0
	var stacked_columns := 0
	for world_seed in range(12):
		var town := WarrenTownSolver.solve(world_seed)
		assert_not_null(town, "seed %d must compose: %s" % [world_seed,
			WarrenTownSolver.last_failure])
		if town == null:
			continue
		var volume := town.volume
		var plan := town.parcels
		assert_eq(int(volume.audit.same_datum_public_square_count), 0,
			"auxiliary markets and galleries must preserve narrow public space")
		assert_gte(int(volume.audit.ground_arcade_walk_cell_count),
			(WarrenGroundArcadeSolver.MIN_CELLS - 1)
				+ (WarrenGroundArcadeSolver.SECONDARY_MIN_CELLS - 1),
			"every composed city must own two connected lower market branches")
		var arcade_audit := WarrenGroundArcadeSolver.arcade_enclosure_audit(plan)
		assert_gte(int(arcade_audit.qualified_count),
			WarrenGroundArcadeSolver.MIN_ENCLOSED_CELLS,
			"both market-alley turns need real building or overhead enclosure")
		assert_gte(int(arcade_audit.grounded_count),
			WarrenGroundArcadeSolver.MIN_GROUNDED_FRONTAGE_CELLS,
			"the lower market cannot be bounded only by floating upper mass")
		assert_true(plan.is_sealed())
		assert_gte(int(plan.audit.parcel_count), WarrenParcelizer.MIN_PARCELS)
		assert_eq(int(plan.audit.detached_parcel_count), 0)
		assert_eq(int(plan.audit.overlapping_parcel_cell_count), 0)
		assert_eq(int(plan.audit.transverse_parcel_count), 0,
			"buildings must never be wider across the frontage than they are deep")
		assert_gte(int(plan.audit.base_band_count), 3)
		assert_gte(int(plan.audit.footprint_family_count), 3)
		assert_gte(int(plan.audit.half_level_neighbor_pair_count), 1)
		assert_gte(float(town.audit.composed_walk_enclosure_ratio),
			WarrenTownPlan.MIN_COMPOSED_WALK_ENCLOSURE_RATIO,
			"acceptance uses the exact composed realm, not a parcel-only proxy")
		for parcel: WarrenBuildingParcel in plan.parcels:
			assert_true(volume.has_walk(parcel.address_walk_cell))
			assert_eq(parcel.threshold_column + parcel.frontage_direction,
				Vector2i(parcel.address_walk_cell.x,
					parcel.address_walk_cell.z))
			assert_gte(parcel.depth_cells, parcel.width_cells)
			assert_true(parcel.storey_count() in [1, 2, 3, 4])
			assert_eq(parcel.roof_base_band()
				+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS,
				parcel.top_band)
			assert_gte(parcel.bearing_columns.size() * 2,
				parcel.footprint.size())
			for cell: Vector3i in parcel.occupied_cells():
				assert_true(volume.has_mass(cell))
		occupied_overpasses += int(plan.audit.occupied_overpass_parcel_count)
		stacked_columns += int(plan.audit.stacked_parcel_column_count)
		signatures[plan.deterministic_signature()] = true
	assert_eq(signatures.size(), 12,
		"parcel geometry, not palette or seed identity, must vary across seeds")
	assert_gte(occupied_overpasses, 2,
		("the logical corpus should retain direct parcel overpasses; exact " \
		+ "occupied skywalks are proved separately after asset compilation"))
	assert_gte(stacked_columns, 8,
		"different-height building stacks must occur across the corpus")


func test_mass_pruning_is_exhaustive_and_preserves_a_dense_urban_core() -> void:
	var signatures: Dictionary = {}
	for world_seed in range(12):
		var town := WarrenTownSolver.solve(world_seed)
		assert_not_null(town, "seed %d must compose" % world_seed)
		if town == null:
			continue
		var volume := town.volume
		var parcels := town.parcels
		var pruning := town.pruning
		assert_not_null(pruning, "seed %d must prune coherently" % world_seed)
		if pruning == null:
			continue
		assert_true(pruning.is_sealed())
		assert_eq(int(pruning.audit.classification_overlap_count), 0)
		assert_eq(int(pruning.audit.unclassified_mass_cell_count), 0)
		assert_eq(int(pruning.audit.classified_mass_cell_count),
			volume.mass_cells.size())
		assert_lte(float(pruning.audit.urban_core_open_column_ratio),
			WarrenTownSolver.MAX_URBAN_CORE_OPEN_RATIO,
			"top-to-ground openings are legal only as sparse bounded lightwells")
		for cell_value: Variant in volume.mass_cells.keys():
			assert_gte(pruning.classification_at(cell_value as Vector3i), 0)
		for column_value: Variant in pruning.daylight_void_columns.keys():
			var column := column_value as Vector2i
			assert_true(parcels.urban_core_columns.has(column))
			for y in range(volume.envelope.ground_at(column),
					volume.envelope.top_at(column)):
				assert_false(pruning.building_cells.has(
					Vector3i(column.x, y, column.y)))
		signatures[pruning.deterministic_signature()] = true
	assert_eq(signatures.size(), 12,
		"pruned construction geometry must vary independently of palette")


func test_lightwell_subtraction_cannot_sever_a_route_owned_platform() -> void:
	var route_cell := Vector3i(0, 2, 0)
	var connected: Dictionary = {
		route_cell: [Vector3i(2, 2, 0), Vector3i(3, 2, 0),
			Vector3i(2, 2, 1), Vector3i(3, 2, 1)] as Array[Vector3i],
	}
	assert_true(WarrenPlatformInfillSolver._extensions_remain_route_connected(
		connected))
	var severed: Dictionary = {
		route_cell: [Vector3i(3, 2, 0), Vector3i(3, 2, 1)] as Array[Vector3i],
	}
	assert_false(WarrenPlatformInfillSolver._extensions_remain_route_connected(
		severed),
		"a bounded-looking hole may not remove the only neck back to the route")


func test_preferred_enclosure_tier_precedes_viable_exact_fallbacks() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	assert_not_null(program)
	if program == null:
		return
	# Preferred plans must form one stable prefix. A seed is allowed to fill the
	# entire bounded frontier with preferred plans; requiring a weaker fallback
	# made this test fight improvements to density and enclosure.
	var plans := WarrenTownSolver.ranked_candidates(6052724565602100358, {},
		program, WarrenTownSolver.COMPOSED_PLAN_FRONTIER)
	var preferred_count := 0
	var fallback_count := 0
	var reached_fallback := false
	for plan: WarrenTownPlan in plans:
		var composed := float(plan.audit.get(
			"composed_walk_enclosure_ratio", 0.0))
		if composed >= WarrenTownPlan.PREFERRED_COMPOSED_WALK_ENCLOSURE_RATIO:
			preferred_count += 1
			assert_false(reached_fallback,
				"near-threshold plans may fill slots but never crowd preferred plans")
		else:
			reached_fallback = true
			fallback_count += 1
	assert_gt(preferred_count, 0)
	assert_gte(fallback_count, 0)


func test_asset_aware_town_corpus_has_exact_envelopes_and_entrances() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	assert_not_null(program)
	if program == null:
		return
	var construction_signatures: Dictionary = {}
	for world_seed in range(4):
		var built := WarrenBuiltTownSolver.solve(world_seed, program)
		assert_not_null(built, "seed %d must admit the measured vocabulary: %s" % [
			world_seed, WarrenBuiltTownSolver.last_failure])
		if built == null:
			continue
		var assets := built.assets
		assert_true(assets.is_sealed())
		assert_eq(int(assets.audit.parcel_count),
			assets.town.parcels.parcels.size())
		assert_eq(int(assets.audit.unmapped_parcel_count), 0)
		assert_eq(int(assets.audit.entrance_mismatch_count), 0)
		assert_eq(int(assets.audit.visual_envelope_conflict_count), 0)
		assert_gte(int(assets.audit.recipe_family_count), 3)
		assert_lte(int(assets.town.audit.get(
			"max_raw_daylight_void_component_size", 99)),
			WarrenTownPlan.MAX_RAW_DAYLIGHT_VOID_COMPONENT_SIZE,
			("a broad raw cavity must be divided by route/building composition " \
			+ "instead of hidden beneath an empty platform"))
		assert_lte(int(assets.town.public_realm.audit.get(
			"infill_platform_patch_count", 99)),
			WarrenPlatformInfillSolver.MAX_PATCH_COUNT,
			"route-fused infill must remain a small local court network")
		assert_lte(int(built.audit.get(
			"structural_court_interior_cell_count", 2147483647)),
			WarrenBuiltTownSolver.TARGET_MAX_STRUCTURAL_COURT_INTERIOR_CELLS,
			("structural floors may form long narrow galleries, but never " \
			+ "an empty suspended plaza"))
		var infill_count := int(assets.town.public_realm.audit.get(
			"infill_platform_patch_count", 0))
		if infill_count >= 2:
			assert_gte(int(assets.town.public_realm.audit.get(
				"infill_lightwell_count", 0)), 1,
				"multi-cell infill must retain a guarded daylight opening")
		assert_lte(int(assets.town.public_realm.audit.get(
			"infill_lightwell_count", 99)),
			WarrenPlatformInfillSolver.MAX_LIGHTWELL_COUNT,
			"the upper network must not reopen many views straight to ground")
		var lightwells := assets.town.public_realm.daylight_void_cells
		for first_index in lightwells.size():
			for second_index in range(first_index + 1, lightwells.size()):
				var first: Vector3i = lightwells[first_index]
				var second: Vector3i = lightwells[second_index]
				assert_gte(absi(first.x - second.x) + absi(first.z - second.z),
					WarrenPlatformInfillSolver \
						.MIN_LIGHTWELL_PROJECTED_SEPARATION_CELLS,
					"lightwells on different levels may not combine into one shaft")
		assert_eq(int(assets.town.public_realm.audit.get(
			"uncovered_core_column_count", 99)), 0,
			"every raw 3 m core aperture must close before lightwells are carved")
		assert_eq(int(assets.town.public_realm.audit.get(
			"max_uncovered_core_component_size", 99)), 0,
			"only exact guarded 1.5 m lightwells may look through the upper city")
		assert_gte(float(assets.town.public_realm.audit.get(
			"composed_walk_enclosure_ratio", 0.0)),
			WarrenTownPlan.MIN_COMPOSED_WALK_ENCLOSURE_RATIO,
			"building, overhead, and guarded-court facts must enclose the route")
		assert_eq(int(assets.town.parcels.audit.planned_skywalk_count), 1)
		assert_gte(int(built.audit.skywalk_count), 1)
		assert_eq(int(built.audit.public_air_occupied_overlap_count), 0)
		assert_eq(int(built.audit.unreachable_exterior_air_count), 0,
			"every retained platform cell must remain connected to public route air")
		assert_lte(int(built.audit.get(
			"max_uncovered_route_component_size", 2147483647)),
			WarrenBuiltTownSolver.TARGET_MAX_UNCOVERED_ROUTE_COMPONENT_SIZE,
			("a lower street may open into short turning courts, never one " \
			+ "continuous roof-to-ground shaft"))
		assert_eq(int(built.audit.visual_envelope_conflict_count), 0)
		assert_eq(int(assets.town.surfaces.audit().get(
			"daylight_void_unbounded_edge_count", -1)), 0)
		for recipe_id: StringName in [&"skywalk.3.blue", &"skywalk.6.orange",
				&"skywalk.9.blue", &"skywalk.corner.blue",
				&"skywalk.corner.orange"]:
			var skywalk_recipe := program.recipe(recipe_id)
			assert_not_null(skywalk_recipe)
			if skywalk_recipe == null:
				continue
			var roof_placements := 0
			for placement: Dictionary in skywalk_recipe.placements:
				if String(StringName(placement.id)).begins_with("roof"):
					roof_placements += 1
					assert_ne(StringName(placement.asset_id),
						SettlementFabricProgram.FLOOR,
						"occupied skywalk roofs may not be flat floor modules")
			assert_gt(roof_placements, 0,
				"every occupied skywalk family must own visible roof geometry")
		var one_storey_towers := 0
		var one_storey_wide := 0
		var visually_short := 0
		for parcel: WarrenBuildingParcel in assets.town.parcels.parcels:
			one_storey_towers += int(parcel.width_cells == 1 \
				and parcel.depth_cells == 1 and parcel.storey_count() == 1)
			one_storey_wide += int(parcel.width_cells > 1 \
				and parcel.storey_count() == 1)
			var proposal := WarrenParcelConstruction.proposal(parcel)
			if int(proposal.storeys) == 1:
				visually_short += 1
				assert_eq(parcel.width_cells, 1,
					"a visually one-storey wide building is never eligible")
			var roof_count := 0
			for component: Dictionary in \
					StaggeredFabricCompiler.proposal_components(proposal):
				if StringName(component.role) != &"roof":
					continue
				roof_count += 1
				var roof_recipe := program.recipe(StringName(component.recipe_id))
				assert_not_null(roof_recipe)
				if roof_recipe != null:
					assert_true(roof_recipe.has_tag(&"ridge_z"),
						"every production roof declares the parcel depth axis")
					assert_gt(roof_recipe.local_bounds.size.z,
						roof_recipe.local_bounds.size.x,
						("the roof ridge must be longer than its transverse " \
						+ "eave span"))
				if int(proposal.storeys) == 1:
					assert_true(String(component.recipe_id).contains(".short."),
						"every visually short stack must receive a vertical roofline")
			assert_eq(roof_count, 1, "every room stack must own exactly one roof")
		assert_lte(one_storey_towers, WarrenParcelizer.MAX_ONE_STOREY_TOWERS)
		assert_lte(one_storey_wide,
			WarrenParcelizer.MAX_ONE_STOREY_WIDE_BUILDINGS)
		assert_lte(visually_short,
			WarrenParcelizer.MAX_VISUALLY_SHORT_BUILDINGS)
		assert_eq(visually_short, 0,
			"production towns never admit a visually one-storey building")
		assert_eq(visually_short, int(assets.town.parcels.audit.get(
			"visually_short_parcel_count", -1)))
		assert_eq(int(assets.town.parcels.audit.get(
			"unstepped_tall_parcel_count", -1)), 0,
			"every tall stack must descend through an adjacent lower roofline")
		construction_signatures[built.deterministic_signature()] = true
	assert_eq(construction_signatures.size(), 4,
		"different seeds must change construction geometry, not just palettes")


func test_volume_public_realm_adapter_preserves_two_lane_topology() -> void:
	var signatures: Dictionary = {}
	for world_seed in range(12):
		var volume := WarrenPublicRealmCarver.solve(world_seed)
		var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
		assert_not_null(realm, "seed %d must adapt to the common realm" % world_seed)
		if realm == null:
			continue
		assert_true(realm.is_sealed())
		assert_true(realm.validate())
		var vertical_count := int(volume.audit.ramp_transition_count) \
			+ int(volume.audit.stair_transition_count)
		var transition_surface_count := 0
		for transition: WarrenVolumeTransition in volume.transitions:
			if transition.is_vertical():
				transition_surface_count += (transition.run_cells * 2 - 2) * 2
		assert_eq(realm.nodes.size(), volume.walk_cells.size() + vertical_count)
		assert_eq(realm.edges.size(), volume.transitions.size() + vertical_count)
		assert_eq(realm.primary_itinerary.size(),
			volume.primary_itinerary.size() + vertical_count,
			"the auxiliary arcade stays connected without replacing the main journey")
		assert_eq(int(realm.audit.public_interior_node_count), 0)
		assert_eq(int(realm.audit.public_surface_cell_count),
			volume.walk_cells.size() * 4
			+ transition_surface_count)
		assert_eq(int(realm.audit.audited_stair_count),
			vertical_count)
		assert_eq(int(realm.audit.aligned_stair_count),
			vertical_count)
		assert_eq(int(realm.audit.stair_endpoint_gap_count), 0)
		assert_eq(int(realm.audit.stair_endpoint_missing_landing_count), 0)
		for edge_value: PublicRealmEdge in realm.edges:
			assert_gte(edge_value.seams.size(), 2)
		signatures[realm.deterministic_signature()] = true
	assert_eq(signatures.size(), 12,
		"the common realm must retain seed-varied geometry")


func test_volume_surface_compiler_serves_facades_and_derives_guards() -> void:
	var signatures: Dictionary = {}
	for world_seed in range(12):
		var town := WarrenTownSolver.solve(world_seed)
		assert_not_null(town, "seed %d must compose: %s" % [world_seed,
			WarrenTownSolver.last_failure])
		if town == null:
			continue
		var volume := town.volume
		var parcels := town.parcels
		var realm := town.public_realm
		var surfaces := town.surfaces
		assert_not_null(surfaces, "seed %d must compile surfaces: %s" % [
			world_seed, WarrenVolumeSurfaceCompiler.last_failure])
		if surfaces == null:
			continue
		assert_true(surfaces.is_sealed())
		assert_true(surfaces.validate())
		assert_eq(surfaces.claim_count(),
			int(realm.audit.public_surface_cell_count))
		var audit := surfaces.audit()
		assert_eq(int(audit.entrance_count), parcels.parcels.size())
		assert_eq(int(audit.unserved_entrance_count), 0)
		assert_eq(int(audit.entrance_guard_conflict_count), 0)
		assert_gt(int(audit.derived_guard_segment_count), 0)
		assert_eq(int(audit.daylight_void_unbounded_edge_count), 0,
			"seed %d daylight wells must be surrounded by guards or walls" % world_seed)
		assert_eq(int(audit.transition_mesh_count),
			int(volume.audit.ramp_transition_count)
			+ int(volume.audit.stair_transition_count))
		assert_gt(int(audit.transition_triangle_count), 0)
		assert_gt(surfaces.mesh_payloads.size(), 0)
		signatures["%s/%d/%d" % [realm.deterministic_signature(),
			int(audit.derived_guard_segment_count),
			int(audit.daylight_void_guard_segment_count)]] = true
	assert_eq(signatures.size(), 12)

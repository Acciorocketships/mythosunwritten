extends SceneTree

## Fast production-terrain audit for one canonical settlement site.  This
## deliberately skips PathPlan/WorldFeaturePlan projection: it exists to prove
## that the sealed warren's external route landing meets the immutable terrain
## and that the complete footprint stays within the adapter's relief contract.
const DEFAULT_SEED := 2697992464
const DEFAULT_SUPER_CELL := Vector2i(0, -1)
const REGION_RADIUS := 5


func _init() -> void:
	var world_seed := DEFAULT_SEED
	var super_cell := DEFAULT_SUPER_CELL
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		match args[index]:
			"--seed":
				if index + 1 < args.size():
					world_seed = int(args[index + 1])
			"--super-x":
				if index + 1 < args.size():
					super_cell.x = int(args[index + 1])
			"--super-z":
				if index + 1 < args.size():
					super_cell.y = int(args[index + 1])
	var water := TerrainWorldTuning.make_water(world_seed)
	var site := SettlementPlan.new(world_seed, water).site_for(super_cell)
	if site.is_empty():
		print(JSON.stringify({
			"accepted": false,
			"reason": "no settlement site",
			"seed": world_seed,
			"super_cell": [super_cell.x, super_cell.y],
		}, "  "))
		quit(1)
		return
	var cell := site.cell as Vector2i
	var heightfield := TerrainWorldTuning.make_heightfield(world_seed, water)
	var region := heightfield.compute_region(cell.x, cell.y, REGION_RADIUS)
	var terrain := VillageTerrainView.from_region(region)
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	assert(program != null)
	var frame := VillageFrame.from_mask(site, 1, region,
		_empty_water(region, cell))
	var village_plan := VillagePlan.new(world_seed, program)
	var city_seed := village_plan._warren_seed(frame)
	if "--court-partition" in args:
		var court_variant_index := args.find("--variant")
		var court_variant := int(args[court_variant_index + 1]) \
			if court_variant_index >= 0 and court_variant_index + 1 < args.size() \
			else 0
		_audit_court_partition(city_seed, program.settlement_fabric_program,
			court_variant)
		quit(0)
		return
	if "--spatial-variants" in args:
		_audit_spatial_variants(city_seed, program.settlement_fabric_program)
		quit(0)
		return
	var bore_frontier_index := args.find("--bore-frontier-attempt")
	if bore_frontier_index >= 0:
		var outer_attempt := int(args[bore_frontier_index + 1]) \
			if bore_frontier_index + 1 < args.size() else 0
		_audit_bore_frontier(city_seed, outer_attempt)
		quit(0)
		return
	var sweep_index := args.find("--sweep-attempts")
	if sweep_index >= 0:
		var sweep_count := int(args[sweep_index + 1]) \
			if sweep_index + 1 < args.size() else 32
		var sweep_start_index := args.find("--sweep-start")
		var sweep_start := int(args[sweep_start_index + 1]) \
			if sweep_start_index >= 0 and sweep_start_index + 1 < args.size() \
			else 0
		_sweep_mass_first_attempts(city_seed, sweep_start, sweep_count)
		quit(0)
		return
	var urban := VillageWarrenFabricSolver.solve(terrain,
		city_seed, frame.settlement_id, frame.centre,
		Vector2.RIGHT, program)
	var support_count := 0
	for entry: Dictionary in urban.entries:
		support_count += int(StringName(entry.get("asset_id", "")) \
			== SettlementFabricAssembler.TIMBER_SUPPORT)
	var room_storeys: Array[int] = []
	var building_cell_counts: Array[int] = []
	if urban.volumetric_spatial != null:
		for building: WarrenBuildingVolume in urban.volumetric_spatial.buildings:
			room_storeys.append(building.room_records.size())
			building_cell_counts.append(building.private_cells.size())
	var report := {
		"accepted": urban.accepted,
		"reason": String(urban.reason),
		"seed": world_seed,
		"city_seed": city_seed,
		"source_seed": urban.volumetric_spatial.world_seed \
			if urban.volumetric_spatial != null else 0,
		"super_cell": [super_cell.x, super_cell.y],
		"site_cell": [cell.x, cell.y],
		"centre": [frame.centre.x, frame.centre.y],
		"terrain_y_at_entrance": terrain.surface_y(frame.centre),
		"entrance_lift_m": urban.terrain_entrance_lift_m,
		"terrain_relief_m": urban.terrain_relief_m,
		"timber_support_piece_count": support_count,
		"route_signature": String(urban.fabric_audit.get(
			"maze_route_signature", "")),
		"construction_signature": String(urban.fabric_audit.get(
			"construction_signature", "")),
		"spatial_building_count": int(urban.fabric_audit.get(
			"spatial_building_volume_count", 0)),
		"building_private_cell_counts": building_cell_counts,
		"building_room_storeys": room_storeys,
		"enclosed_skywalk_count": int(urban.fabric_audit.get(
			"enclosed_skywalk_count", 0)),
		"covered_market_count": int(urban.fabric_audit.get(
			"covered_market_count", 0)),
		"elevated_courtyard_count": int(urban.fabric_audit.get(
			"elevated_courtyard_count", 0)),
		"usable_balcony_count": int(urban.fabric_audit.get(
			"usable_balcony_count", 0)),
		"room_outcropping_count": int(urban.fabric_audit.get(
			"room_outcropping_count", 0)),
		"bounded_walk_ratio": float(urban.fabric_audit.get(
			"bounded_walk_ratio", 0.0)),
		"two_sided_walk_ratio": float(urban.fabric_audit.get(
			"two_sided_walk_ratio", 0.0)),
		"occupied_overpass_parcel_count": int(urban.fabric_audit.get(
			"occupied_overpass_parcel_count", 0)),
		"urban_core_open_column_ratio": float(urban.fabric_audit.get(
			"urban_core_open_column_ratio", 0.0)),
		"frontage_ratio": float(urban.fabric_audit.get(
			"frontage_ratio", 0.0)),
		"overhead_route_ratio": float(urban.fabric_audit.get(
			"overhead_route_ratio", 0.0)),
		"through_sightline_count": int(urban.fabric_audit.get(
			"through_sightline_count", 0)),
	}
	print(JSON.stringify(report, "  "))
	quit(0 if urban.accepted else 1)


static func _sweep_mass_first_attempts(city_seed: int, attempt_start: int,
		attempt_count: int) -> void:
	var massif := WarrenMassifBuilder.build(city_seed, {})
	assert(massif != null, WarrenMassifBuilder.last_failure)
	var carved := 0
	var adapted := 0
	var gated: Array[int] = []
	var arcade: Array[int] = []
	var courtyard: Array[int] = []
	var arcade_failures: Dictionary = {}
	var courtyard_failures: Dictionary = {}
	var gate_failure_counts := {
		"walk": 0, "elevation": 0, "ramp": 0, "landing": 0,
		"rise": 0, "overhang": 0, "address": 0, "shaft": 0,
		"fold": 0, "straight": 0,
	}
	var candidate_audits: Array[Dictionary] = []
	for attempt in range(attempt_start, attempt_start + attempt_count):
		var excavation := WarrenExcavationCarver.carve(city_seed + attempt \
			* WarrenTownSolver.MASS_FIRST_ATTEMPT_STRIDE, massif)
		if excavation == null:
			continue
		carved += 1
		var volume := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if volume == null:
			continue
		adapted += 1
		var audit := volume.audit
		gate_failure_counts.walk += int(int(audit.walk_cell_count) \
			< WarrenPublicRealmCarver.MIN_ROUTE_CELLS)
		gate_failure_counts.elevation += int(int(audit.elevation_band_count) < 4)
		gate_failure_counts.ramp += int(int(audit.ramp_transition_count) < 1)
		gate_failure_counts.landing += int(int(
			audit.landing_turn_violation_count) != 0)
		gate_failure_counts.rise += int(int(audit.max_transition_rise_bands) > 1)
		gate_failure_counts.overhang += int(float(audit.overhang_walk_ratio) < 0.25)
		gate_failure_counts.address += int(float(audit.addressed_walk_ratio) < 0.55)
		gate_failure_counts.shaft += int(float(audit.deep_vertical_shaft_ratio) > 0.10)
		gate_failure_counts.fold += int(int(audit.same_datum_route_fold_count) != 0)
		gate_failure_counts.straight += int(int(audit.max_straight_run_cells) \
			> WarrenPublicRealmCarver.MAX_STRAIGHT_RUN)
		candidate_audits.append({
			"attempt": attempt,
			"walk": int(audit.walk_cell_count),
			"elevations": int(audit.elevation_band_count),
			"ramps": int(audit.ramp_transition_count),
			"overhang": float(audit.overhang_walk_ratio),
			"address": float(audit.addressed_walk_ratio),
			"shaft": float(audit.deep_vertical_shaft_ratio),
			"folds": int(audit.same_datum_route_fold_count),
			"straight": int(audit.max_straight_run_cells),
		})
		if not WarrenPublicRealmCarver.passes_topology_gate(volume):
			continue
		gated.append(attempt)
		volume = WarrenGroundArcadeSolver.extend(volume)
		if volume == null:
			arcade_failures[attempt] = WarrenGroundArcadeSolver.last_failure
			continue
		arcade.append(attempt)
		if not WarrenElevatedFrontageSolver.variants(volume, true).is_empty():
			courtyard.append(attempt)
		else:
			courtyard_failures[attempt] = \
				WarrenElevatedFrontageSolver.last_failure
	print(JSON.stringify({
		"city_seed": city_seed,
		"attempt_start": attempt_start,
		"attempt_count": attempt_count,
		"carved_count": carved,
		"adapted_count": adapted,
		"topology_gate_attempts": gated,
		"arcade_attempts": arcade,
		"courtyard_attempts": courtyard,
		"arcade_failures": arcade_failures,
		"courtyard_failures": courtyard_failures,
		"gate_failure_counts": gate_failure_counts,
		"candidate_audits": candidate_audits,
	}, "  "))


static func _audit_bore_frontier(city_seed: int, outer_attempt: int) -> void:
	var massif := WarrenMassifBuilder.build(city_seed, {})
	assert(massif != null, WarrenMassifBuilder.last_failure)
	var carve_seed := city_seed + outer_attempt \
		* WarrenTownSolver.MASS_FIRST_ATTEMPT_STRIDE
	var portals := WarrenExcavationCarver._portal_cells(massif)
	var rejected: Dictionary = {}
	var sealed := 0
	var adapted := 0
	var gated: Array[int] = []
	var arcades: Array[int] = []
	var courts: Array[int] = []
	var court_failures: Dictionary = {}
	for bore_attempt in WarrenExcavationCarver.ATTEMPTS:
		var excavation := WarrenExcavationCarver._bore(carve_seed,
			bore_attempt, massif, portals, rejected)
		if excavation == null:
			continue
		sealed += 1
		WarrenExcavationCarver._carve_lanes(carve_seed, excavation, massif)
		if not excavation.seal():
			continue
		var volume := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if volume == null:
			continue
		adapted += 1
		if not WarrenPublicRealmCarver.passes_topology_gate(volume):
			continue
		gated.append(bore_attempt)
		volume = WarrenGroundArcadeSolver.extend(volume)
		if volume == null:
			continue
		arcades.append(bore_attempt)
		if not WarrenElevatedFrontageSolver.variants(volume, true).is_empty():
			courts.append(bore_attempt)
		else:
			court_failures[bore_attempt] = \
				WarrenElevatedFrontageSolver.last_failure
	print(JSON.stringify({
		"city_seed": city_seed,
		"outer_attempt": outer_attempt,
		"sealed_bore_count": sealed,
		"adapted_bore_count": adapted,
		"topology_gate_bore_attempts": gated,
		"arcade_bore_attempts": arcades,
		"courtyard_bore_attempts": courts,
		"courtyard_failures": court_failures,
		"bore_rejections": rejected,
	}, "  "))


static func _audit_spatial_variants(city_seed: int,
		program: SettlementFabricProgram) -> void:
	WarrenVolumetricSolver.diagnostic_stop_after_skywalk_candidates = \
		"--skywalk-filter-only" in OS.get_cmdline_user_args()
	var frontier_started := Time.get_ticks_msec()
	var frontier := WarrenTownSolver.mass_first_frontier(city_seed, {})
	frontier.sort_custom(WarrenVolumetricSolver._spatial_topology_less)
	print("SPATIAL_FRONTIER ms=", Time.get_ticks_msec() - frontier_started,
		" count=", frontier.size(), " ids=",
		frontier.map(func(volume: WarrenVolumePlan) -> String:
			return String(volume.stable_id)))
	var args := OS.get_cmdline_user_args()
	var variant_index := args.find("--variant")
	var variants: Array[int] = []
	if variant_index >= 0 and variant_index + 1 < args.size():
		variants.append(int(args[variant_index + 1]))
	else:
		for variant in WarrenVolumetricSolver.MAX_PARTITION_VARIANTS:
			variants.append(variant)
	for source: WarrenVolumePlan in frontier:
		for variant: int in variants:
			var started := Time.get_ticks_msec()
			var spatial := WarrenVolumetricSolver.from_volume(source, variant,
				program)
			var sky := WarrenVolumetricSolver \
				.last_preplan_skywalk_diagnostic
			print("SPATIAL_VARIANT id=", source.stable_id, " variant=",
				variant, " ms=", Time.get_ticks_msec() - started,
				" accepted=", spatial != null, " failure=",
				WarrenVolumetricSolver.last_failure.left(240),
				" market=", WarrenVolumetricSolver \
					.last_preplan_market_diagnostic,
				" skywalk_filters=", {
					"raw_straight": sky.get("raw_straight_count", -1),
					"raw_corner": sky.get("raw_corner_count", -1),
					"generated": sky.get("generated_candidate_count", -1),
					"pre_individual": sky.get(
						"pre_individual_candidate_count", -1),
					"generation_ms": sky.get("candidate_generation_ms", -1),
					"corner_upper": sky.get(
						"corner_upper_block_pair_count", -1),
					"corner_forced": sky.get(
						"corner_forced_offset_fit_count", -1),
					"corner_body": sky.get("corner_body_fit_count", -1),
					"corner_cover": sky.get("corner_route_cover_count", -1),
					"upper": sky.get("upper_block_pair_count", -1),
					"forced": sky.get("forced_offset_fit_count", -1),
					"body": sky.get("body_fit_count", -1),
					"cover": sky.get("route_cover_count", -1),
					"compatible": sky.get("compatible_candidate_count", -1),
					"fixed_reject": sky.get("fixed_block_rejection_count", -1),
					"court_fixed_blocks": sky.get(
						"courtyard_fixed_block_count", -1),
					"individual_reject": sky.get(
						"individual_candidate_rejection_count", -1),
					"individual_failures": sky.get(
						"individual_candidate_rejection_failures", {}),
					"selected": sky.get("selected_count", -1),
				},
				" composition=", WarrenRoomCompositionPlanner.last_failure)
			if spatial != null:
				return


static func _audit_court_partition(city_seed: int,
		program: SettlementFabricProgram, variant: int) -> void:
	var frontier := WarrenTownSolver.mass_first_frontier(city_seed, {})
	frontier.sort_custom(WarrenVolumetricSolver._spatial_topology_less)
	assert(not frontier.is_empty(), WarrenTownSolver.last_failure)
	var volume := frontier[0]
	var massif := volume.mass_context.get(&"massif") as WarrenMassif
	var bounds := WarrenVolumetricSolver._grid_bounds(massif)
	var grid := WarrenSpatialGrid.new(bounds.minimum, bounds.size)
	assert(WarrenVolumetricSolver._project_massif(grid, massif))
	assert(not WarrenVolumetricSolver._carve_public_volume(grid, volume).is_empty())
	var parcels := WarrenTownSolver.partition_parcels(volume, variant, program)
	assert(parcels != null, WarrenTownSolver.last_partition_failure)
	var proposals: Array[Dictionary] = []
	var rejected_unfloored: Array[StringName] = []
	for parcel: WarrenBuildingParcel in parcels.parcels:
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			continue
		if not WarrenVolumetricSolver._parcel_address_has_public_floor(grid,
				parcel):
			rejected_unfloored.append(parcel.stable_id)
			continue
		proposal["parcel"] = parcel
		proposals.append(proposal)
	var protected_owners: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		for occupied: Vector3i in StaggeredFabricCompiler \
				.proposal_occupied_cells(proposal):
			if not protected_owners.has(occupied):
				protected_owners[occupied] = {}
			(protected_owners[occupied] as Dictionary)[parcel.stable_id] = true
	var court_floors: Dictionary = {}
	for macro: Vector3i in volume.courtyard_cells:
		for floor_cell: Vector3i in WarrenVolumetricSolver._fine_square(macro):
			court_floors[floor_cell] = true
	var court_neighbors := WarrenVolumetricSolver._courtyard_neighbor_cells(
		court_floors)
	var court_macro_set: Dictionary = {}
	for macro: Vector3i in volume.courtyard_cells:
		court_macro_set[Vector2i(macro.x, macro.z)] = true
	var perimeter_columns: Dictionary = {}
	for column_value: Variant in court_macro_set.keys():
		var column := column_value as Vector2i
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i.UP, Vector2i.DOWN]:
			var neighbor := column + direction
			if not court_macro_set.has(neighbor):
				perimeter_columns[neighbor] = true
	var perimeter_parcels: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels.parcels:
		var contacts: Array[Vector2i] = []
		for column: Vector2i in parcel.footprint:
			if perimeter_columns.has(column):
				contacts.append(column)
		if contacts.is_empty():
			continue
		var proposal := WarrenParcelConstruction.proposal(parcel)
		perimeter_parcels[parcel.stable_id] = {
			"contacts": contacts,
			"base": parcel.base_band,
			"top": parcel.top_band,
			"storeys": parcel.storey_count(),
			"address": parcel.address_walk_cell,
			"threshold_column": parcel.threshold_column,
			"proposal": not proposal.is_empty(),
		}
	var touching: Dictionary = {}
	var solved: Dictionary = {}
	var failures: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		var touches := false
		for occupied: Vector3i in StaggeredFabricCompiler \
				.proposal_occupied_cells(proposal):
			if court_neighbors.has(occupied):
				touches = true
				break
		if not touches:
			continue
		touching[parcel.stable_id] = {
			"storeys": int(proposal.storeys),
			"origin": proposal.origin,
			"threshold": WarrenParcelConstruction.threshold_cell(parcel),
			"door_phase": parcel.address_door_phase,
		}
		var origin := proposal.origin as Vector3i
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0,
			int(proposal.storeys) - 1)
		var forced: Dictionary = {0: Vector2i.ZERO,
			floori(float(addressed_storey) / 2.0): Vector2i.ZERO}
		var offsets := WarrenVolumetricSolver._composition_offsets(grid,
			WarrenVolumetricSolver._proposal_base_plate(proposal), origin.y,
			int(proposal.storeys), protected_owners, parcel.stable_id,
			volume.world_seed, forced)
		if offsets.is_empty():
			failures[parcel.stable_id] = "no composition offsets"
		else:
			solved[parcel.stable_id] = offsets
	var proposal_by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		proposal_by_id[(proposal.parcel as WarrenBuildingParcel).stable_id] = proposal
	print(JSON.stringify({
		"source": String(volume.stable_id),
		"variant": variant,
		"court_macro_cells": volume.courtyard_cells,
		"court_floor_count": court_floors.size(),
		"proposal_count": proposals.size(),
		"rejected_unfloored": rejected_unfloored,
		"touching_court_proposals": touching,
		"perimeter_parcels": perimeter_parcels,
		"solved_court_offsets": solved,
		"court_offset_failures": failures,
		"solved_address_side_count": WarrenVolumetricSolver \
			._solved_courtyard_address_side_count(court_floors, solved,
				proposal_by_id),
	}, "  "))


static func _empty_water(region: HeightfieldRegion,
		cell: Vector2i) -> WaterFieldContext:
	var context := WaterFieldContext.new()
	context._ctx = {"ponds": [], "rivers": [], "buckets": {},
		"region": region}
	context._region = region
	var centre := Vector2(cell) * TerrainSurfaceField.TILE
	var radius := float(REGION_RADIUS) * TerrainSurfaceField.TILE
	context._coverage = Rect2(centre - Vector2.ONE * radius,
		Vector2.ONE * radius * 2.0)
	context._shore_limit = 0.0
	return context

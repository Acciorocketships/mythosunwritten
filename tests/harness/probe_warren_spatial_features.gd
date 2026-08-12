extends SceneTree

## Text-only planning probe for the in-progress fine-grid feature grammar. This
## intentionally creates no render resources; it exposes whether a sealed seed
## has genuine two-ended bridge corridors and room-scale offset opportunities.

const StampedGround = preload(
	"res://tests/fixtures/warren_stamped_ground.gd")


func _init() -> void:
	var started_ms := Time.get_ticks_msec()
	if "--excavation-terrain-only" in OS.get_cmdline_user_args():
		var terrain_seed := 2
		var terrain_seed_arg := OS.get_cmdline_user_args().find("--seed")
		if terrain_seed_arg >= 0 \
				and terrain_seed_arg + 1 < OS.get_cmdline_user_args().size():
			terrain_seed = int(OS.get_cmdline_user_args()[terrain_seed_arg + 1])
		var terrain_massif := WarrenMassifBuilder.build(terrain_seed,
			StampedGround.hill(WarrenMassifBuilder.RADIUS_CELLS + 4,
				terrain_seed))
		var terrain_excavation := WarrenExcavationCarver.carve(terrain_seed,
			terrain_massif)
		print("TERRAIN_EXCAVATION seed=", terrain_seed, " relief=",
			terrain_massif.relief_bands(), " failure=",
			WarrenExcavationCarver.last_failure)
		if terrain_excavation != null:
			var route_bases := PackedInt32Array()
			for cell: Vector3i in terrain_excavation.route:
				route_bases.append(terrain_massif.base_at(
					Vector2i(cell.x, cell.z)))
			print("ROUTE span=", terrain_excavation.route_span_bands(),
				" cells=", terrain_excavation.route.size(), " bases=",
				route_bases, " route=", terrain_excavation.route)
		quit(0 if terrain_excavation != null else 1)
		return
	if "--excavation-corpus-only" in OS.get_cmdline_user_args():
		var corpus_start := 40
		var corpus_count := 24
		var accepted := 0
		for terrain_seed in range(corpus_start, corpus_start + corpus_count):
			var terrain_massif := WarrenMassifBuilder.build(terrain_seed,
				StampedGround.hill(WarrenMassifBuilder.RADIUS_CELLS + 4,
					terrain_seed))
			var terrain_excavation := WarrenExcavationCarver.carve(terrain_seed,
				terrain_massif)
			accepted += int(terrain_excavation != null)
			print("CORPUS seed=", terrain_seed, " accepted=",
				terrain_excavation != null, " failure=",
				WarrenExcavationCarver.last_failure, " diagnostic=",
				WarrenExcavationCarver.last_diagnostic)
		print("CORPUS_ACCEPTED=", accepted, "/", corpus_count)
		quit()
		return
	WarrenVolumetricSolver.diagnostic_trace_skywalk_timing = \
		"--timing" in OS.get_cmdline_user_args()
	WarrenVolumetricSolver.diagnostic_trace_room_gate = \
		"--gate-trace" in OS.get_cmdline_user_args()
	var market_limit_arg := OS.get_cmdline_user_args().find("--market-limit")
	if market_limit_arg >= 0 \
			and market_limit_arg + 1 < OS.get_cmdline_user_args().size():
		WarrenVolumetricSolver.diagnostic_feature_market_limit = int(
			OS.get_cmdline_user_args()[market_limit_arg + 1])
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	print("PROGRAM_MS=", Time.get_ticks_msec() - started_ms)
	if "--recipe-bounds-only" in OS.get_cmdline_user_args():
		for recipe: FabricRecipe in program.recipes():
			if String(recipe.recipe_id).begins_with("room.") \
					or String(recipe.recipe_id).begins_with("roof.") \
					or String(recipe.recipe_id).begins_with("balcony.") \
					or String(recipe.recipe_id).begins_with("market.covered."):
				print("RECIPE_BOUNDS ", recipe.recipe_id, " ",
					recipe.local_clearance_bounds)
		quit()
		return
	for recipe: FabricRecipe in program.recipes():
		if recipe.has_tag(&"prefab_anchor"):
			print("PREFAB_RECIPE ", recipe.recipe_id, " bounds=",
				recipe.local_clearance_bounds, " solid=", recipe.solid_cells.size(),
				" headroom=", recipe.headroom_cells.size(), " bearing=",
				recipe.terrain_bearing_cells.size())
	var frontier := WarrenTownSolver.mass_first_frontier(7)
	var candidate_token := "8000031"
	var candidate_arg := OS.get_cmdline_user_args().find("--candidate-token")
	if candidate_arg >= 0 \
			and candidate_arg + 1 < OS.get_cmdline_user_args().size():
		candidate_token = OS.get_cmdline_user_args()[candidate_arg + 1]
	var source: WarrenVolumePlan
	var source_generation_index := -1
	var generation_index := 0
	for candidate: WarrenVolumePlan in frontier:
		if String(candidate.stable_id).contains(candidate_token):
			source = candidate
			source_generation_index = generation_index
			break
		generation_index += 1
	var source_rank := -1
	if source != null:
		source_rank = 0
		var source_score := WarrenPublicRealmCarver.topology_score(source)
		for candidate: WarrenVolumePlan in frontier:
			if WarrenPublicRealmCarver.topology_score(candidate) < source_score:
				source_rank += 1
	print("FRONTIER size=", frontier.size(), " source_index=",
		source_generation_index, " source_rank=", source_rank,
		" source_id=", source.stable_id if source != null else &"",
		" source_score=", WarrenPublicRealmCarver.topology_score(source))
	if frontier.is_empty():
		print("FRONTIER_FAILURE ", WarrenTownSolver.last_failure)
	if "--precomposition-rank-only" in OS.get_cmdline_user_args():
		var ranked_variants := WarrenVolumetricSolver \
			._ranked_precomposition_variants(frontier, program)
		for ranked: Dictionary in ranked_variants:
			print("PRECOMPOSITION source=", ranked.volume.stable_id,
				" variant=", ranked.variant, " score=", ranked.score,
				" audit=", ranked.audit)
		if ranked_variants.is_empty() and source != null:
			for diagnostic_variant in WarrenSolidPartitioner.PARTITION_VARIANTS:
				var diagnostic_parcels := WarrenTownSolver.partition_parcels(
					source, diagnostic_variant, program)
				print("PARTITION variant=", diagnostic_variant,
					" parcels=", 0 if diagnostic_parcels == null \
					else diagnostic_parcels.parcels.size(), " failure=",
					WarrenTownSolver.last_partition_failure,
					" partition_audit=", WarrenSolidPartitioner.last_diagnostic)
		quit()
		return
	if "--frontier-only" in OS.get_cmdline_user_args():
		for candidate: WarrenVolumePlan in frontier:
			print("CANDIDATE id=", candidate.stable_id,
				" score=", WarrenPublicRealmCarver.topology_score(candidate),
				" audit=", candidate.audit)
		quit(0 if source != null else 1)
		return
	var requested_variant := 1
	var variant_arg := OS.get_cmdline_user_args().find("--variant")
	if variant_arg >= 0 and variant_arg + 1 < OS.get_cmdline_user_args().size():
		requested_variant = int(OS.get_cmdline_user_args()[variant_arg + 1])
	var parcel_probe := WarrenTownSolver.partition_parcels(source,
		requested_variant, program)
	print("PLANNED_SKYWALKS=", 0 if parcel_probe == null \
		else parcel_probe.connection_reservations.size())
	if parcel_probe != null:
		for reservation: Dictionary in parcel_probe.connection_reservations:
			print("PLANNED ", reservation.get("owner_parcel_ids", []), " ",
				reservation.get("owner_endpoints", []), " components=",
				reservation.get("components", []))
	var solve_started_ms := Time.get_ticks_msec()
	var plan := WarrenVolumetricSolver.solve(7, {}, program) \
		if "--solve-production" in OS.get_cmdline_user_args() \
		else WarrenVolumetricSolver.from_volume(source, requested_variant,
			program)
	print("SPATIAL_SOLVE_MS=", Time.get_ticks_msec() - solve_started_ms)
	if plan == null:
		print("FAIL: ", WarrenVolumetricSolver.last_failure.left(1200))
		print("COMPOSITION_AUDIT_ON_FAILURE: ",
			WarrenRoomCompositionPlanner.last_audit)
		if "--verbose-failure" in OS.get_cmdline_user_args():
			print("COMPOSITION_MERGE_ON_FAILURE: ",
				WarrenRoomCompositionPlanner.last_merge_diagnostic)
		print("PREPLAN_SELECTION: selected=",
			WarrenVolumetricSolver.last_preplan_skywalk_diagnostic.get(
				"selected_count", -1), " candidates=",
			WarrenVolumetricSolver.last_preplan_skywalk_diagnostic.get(
				"compatible_candidate_count", -1), " fixed_reject=",
			WarrenVolumetricSolver.last_preplan_skywalk_diagnostic.get(
				"fixed_block_rejection_count", -1), " failures=",
			WarrenVolumetricSolver.last_preplan_skywalk_diagnostic.get(
				"endpoint_survival_failures", {}))
		print("PREPLAN_TOWER_RANK: combinations=",
			WarrenVolumetricSolver.last_preplan_skywalk_diagnostic.get(
				"composition_ranked_combination_count", -1), " risk=",
			WarrenVolumetricSolver.last_preplan_skywalk_diagnostic.get(
				"selected_tower_risk", -1), " selected=",
			WarrenVolumetricSolver.last_preplan_skywalk_diagnostic.get(
				"selected", []))
		print("SKY_DIAG: ", WarrenSpatialFeatureSolver.last_skywalk_diagnostic)
		print("MARKET_DIAG: ",
			WarrenVolumetricSolver.last_preplan_market_diagnostic)
		print("LANDMARK_COUNTS: candidates=",
			WarrenVolumetricSolver.last_preplan_landmark_diagnostic.get(
				"candidate_count", -1), " pairs=",
			WarrenVolumetricSolver.last_preplan_landmark_diagnostic.get(
				"compatible_pair_count", -1), " attempts=",
			WarrenVolumetricSolver.last_preplan_landmark_diagnostic.get(
				"joint_attempt_count", -1), " max_skywalks=",
			WarrenVolumetricSolver.last_preplan_landmark_diagnostic.get(
				"maximum_joint_skywalk_count", -1), " max_exact_candidates=",
			WarrenVolumetricSolver.last_preplan_landmark_diagnostic.get(
				"maximum_exact_skywalk_candidate_count", -1), " max_pairs=",
			WarrenVolumetricSolver.last_preplan_landmark_diagnostic.get(
				"maximum_skywalk_pair_frontier_count", -1))
		print("LANDMARK_PAIR_PREVIEW: ",
			WarrenVolumetricSolver.last_preplan_landmark_diagnostic.get(
				"pair_preview", []))
		print("LANDMARK_JOINT_PREVIEW: ",
			WarrenVolumetricSolver.last_preplan_landmark_diagnostic.get(
				"joint_pair_preview", []))
		quit(1)
		return
	var composition_only := "--composition-only" in OS.get_cmdline_user_args()
	var compiler_only := "--compiler-only" in OS.get_cmdline_user_args()
	var verbose_failure := "--verbose-failure" in OS.get_cmdline_user_args()
	if not composition_only and not compiler_only:
		print("LANDMARK_DIAG: ",
			WarrenVolumetricSolver.last_preplan_landmark_diagnostic)
	print("MARKET_DIAG: ",
		WarrenVolumetricSolver.last_preplan_market_diagnostic)
	print("COMPOSITION_AUDIT: ", WarrenRoomCompositionPlanner.last_audit)
	if verbose_failure:
		print("COMPOSITION_MERGE_DIAG: ",
			WarrenRoomCompositionPlanner.last_merge_diagnostic)
	print("SPATIAL_RESIDUAL_AUDIT: buildings=",
		plan.audit.get("residual_backfill_building_count", 0), " cells=",
		plan.audit.get("residual_backfill_private_cell_count", 0),
		" new_overhead=",
		plan.audit.get("residual_backfill_overhead_route_cell_count", 0),
		" new_frontage=",
		plan.audit.get("residual_backfill_frontage_side_count", 0),
		" kinds=", plan.audit.get("residual_backfill_kind_counts", {}))
	if compiler_only:
		var compiled := WarrenSpatialFabricCompiler.solve(plan, program)
		print("FABRIC_SEALED=", compiled != null,
			" failure=", WarrenSpatialFabricCompiler.last_failure,
			" audit=", WarrenSpatialFabricCompiler.last_audit)
		if compiled != null:
			print("UNSERVED_ENTRANCES=",
				compiled.surface_plan.unserved_entrances)
			for entrance: Dictionary in compiled.surface_plan.unserved_entrances:
				var landing := entrance.landing_cell as Vector3i
				print("UNSERVED_SOURCE landing=", landing,
					" route_floor=", plan.route_floor_cells.has(landing),
					" use=", plan.grid.use_at(landing),
					" floor_face=", plan.grid.face_claim(landing,
						Vector3i.DOWN))
		if compiled == null and verbose_failure:
			_print_support_handoffs(plan)
			_print_feature_bindings(plan)
		quit(0 if compiled != null else 1)
		return
	if composition_only:
		quit()
		return
	_print_courtyard(plan)
	_print_room_lineages(plan)
	_print_offset_rooms(plan)
	_print_straight_skywalks(plan)
	_print_feature_compilation(plan, program)
	quit()


func _print_support_handoffs(plan: WarrenSpatialPlan) -> void:
	var by_level: Dictionary = {}
	for building: WarrenBuildingVolume in plan.buildings:
		for room: WarrenRoomStamp in building.room_records:
			by_level["%s/%d" % [String(room.source_parcel_id),
				room.source_storey_index]] = room
	for building: WarrenBuildingVolume in plan.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.terrain_bearing or room.support_parent_parcel_id \
					== room.source_parcel_id:
				continue
			var key := "%s/%d" % [String(room.support_parent_parcel_id),
				room.support_parent_storey_index]
			var parent := by_level.get(key) as WarrenRoomStamp
			print("HANDOFF child=", room.stable_id, " kind=", room.kind,
				" origin=", room.lattice_origin, " yaw=", room.yaw_quarters,
				" parent=", key, " parent_kind=",
				&"" if parent == null else parent.kind, " parent_origin=",
				Vector3i.ZERO if parent == null else parent.lattice_origin,
				" parent_yaw=", -1 if parent == null else parent.yaw_quarters)


func _print_feature_bindings(plan: WarrenSpatialPlan) -> void:
	for feature: WarrenFeatureReservation in plan.features:
		if feature.construction_records.is_empty():
			continue
		print("FEATURE_BINDING id=", feature.stable_id, " kind=", feature.kind,
			" endpoints=", feature.endpoints, " records=",
			feature.construction_records, " audit=", feature.audit)


func _print_room_lineages(plan: WarrenSpatialPlan) -> void:
	var by_source: Dictionary = {}
	for building: WarrenBuildingVolume in plan.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not by_source.has(room.source_parcel_id):
				by_source[room.source_parcel_id] = [] as Array[WarrenRoomStamp]
			(by_source[room.source_parcel_id] as Array[WarrenRoomStamp]).append(room)
	var source_ids: Array[StringName] = []
	source_ids.assign(by_source.keys())
	source_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var tall_count := 0
	for source_id: StringName in source_ids:
		var rooms := by_source[source_id] as Array[WarrenRoomStamp]
		rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
			return a.source_storey_index < b.source_storey_index)
		if rooms.size() < 4:
			continue
		tall_count += 1
		var parts := PackedStringArray()
		for room: WarrenRoomStamp in rooms:
			parts.append("s%d:%s@%d,%d,%d/r%d" % [room.source_storey_index,
				String(room.kind), room.lattice_origin.x, room.lattice_origin.y,
				room.lattice_origin.z,
				room.yaw_quarters])
		print("TALL_LINEAGE ", source_id, " storeys=", rooms.size(), " ",
			" | ".join(parts))
	print("TALL_LINEAGE_COUNT=", tall_count)


func _print_courtyard(plan: WarrenSpatialPlan) -> void:
	var volume := plan.source_volume
	print("COURT macro=", volume.courtyard_cells)
	for macro: Vector3i in volume.courtyard_cells:
		for floor: Vector3i in WarrenVolumetricSolver._fine_square(macro):
			var below := PackedStringArray()
			for offset in range(1, 7):
				var cell := floor + Vector3i.DOWN * offset
				below.append("%d/%s" % [plan.grid.use_at(cell),
					String(plan.grid.owner_name_at(cell))])
			print("  ", floor, " below=", ",".join(below))
	for y in range(0, 11):
		print("COURT_LAYER y=", y)
		for z in range(9, 19):
			var row := ""
			for x in range(-4, 9):
				var cell := Vector3i(x, y, z)
				var use := plan.grid.use_at(cell)
				row += "P" if use == WarrenSpatialGrid.Use.PUBLIC_AIR \
					else "B" if use == WarrenSpatialGrid.Use.PRIVATE_VOLUME \
					else "D" if use == WarrenSpatialGrid.Use.DAYLIGHT_AIR \
					else "."
			print("  z%02d %s" % [z, row])


func _print_offset_rooms(plan: WarrenSpatialPlan) -> void:
	var by_source: Dictionary = {}
	for building: WarrenBuildingVolume in plan.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not by_source.has(room.source_parcel_id):
				by_source[room.source_parcel_id] = [] as Array[WarrenRoomStamp]
			(by_source[room.source_parcel_id] as Array[WarrenRoomStamp]).append(room)
	var shifted := 0
	for rooms_value: Variant in by_source.values():
		var rooms := rooms_value as Array[WarrenRoomStamp]
		rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
			return a.source_storey_index < b.source_storey_index)
		for index in range(1, rooms.size()):
			var lower := rooms[index - 1]
			var upper := rooms[index]
			var delta := Vector2i(upper.lattice_origin.x - lower.lattice_origin.x,
				upper.lattice_origin.z - lower.lattice_origin.z)
			if delta != Vector2i.ZERO:
				shifted += 1
				print("OFFSET ", lower.stable_id, " -> ", upper.stable_id,
					" delta=", delta, " kind=", upper.kind)
	print("OFFSET_COUNT=", shifted)


func _print_straight_skywalks(plan: WarrenSpatialPlan) -> void:
	var candidates: Array[Dictionary] = []
	var directions: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.BACK]
	for building: WarrenBuildingVolume in plan.buildings:
		for room: WarrenRoomStamp in building.room_records:
			for endpoint: Vector3i in room.private_cells:
				if endpoint.y != room.lattice_origin.y:
					continue
				for direction: Vector3i in directions:
					if plan.grid.use_at(endpoint + direction) \
							== WarrenSpatialGrid.Use.PRIVATE_VOLUME:
						continue
					for distance: int in [3, 5, 7]:
						var other: Vector3i = endpoint + direction * distance
						if plan.grid.use_at(other) \
								!= WarrenSpatialGrid.Use.PRIVATE_VOLUME:
							continue
						var other_owner := plan.grid.owner_name_at(other)
						if other_owner == building.stable_id:
							continue
						var clear := true
						var lower_public := 0
						for step in range(1, distance):
							var bridge_cell := endpoint + direction * step
							for y_offset in 4:
								var use: int = plan.grid.use_at(bridge_cell \
									+ Vector3i.UP * y_offset)
								if use not in [WarrenSpatialGrid.Use.OUTSIDE,
										WarrenSpatialGrid.Use.SERVICE_VOID]:
									clear = false
							for down in range(1, 9):
								if plan.grid.use_at(bridge_cell \
										+ Vector3i.DOWN * down) \
										== WarrenSpatialGrid.Use.PUBLIC_AIR:
									lower_public += 1
									break
						if clear and lower_public > 0:
							candidates.append({"a": endpoint,
								"a_owner": building.stable_id, "b": other,
								"b_owner": other_owner, "distance": distance,
								"direction": direction,
								"lower_public": lower_public})
	print("SKYWALK_COUNT=", candidates.size())
	for index in mini(candidates.size(), 30):
		print("SKY ", candidates[index])


func _print_feature_compilation(plan: WarrenSpatialPlan,
		program: SettlementFabricProgram) -> void:
	var rooms := WarrenSpatialFabricCompiler.compile_room_units(plan, program)
	var features := WarrenSpatialFabricCompiler.compile_feature_units(plan,
		program, rooms)
	print("FEATURE_COMPILE_COUNT=", features.size(), " failure=",
		WarrenSpatialFabricCompiler.last_failure)
	if not features.is_empty():
		var roofs := WarrenSpatialFabricCompiler.compile_roof_units(plan, program,
			rooms, features)
		print("ROOF_COMPILE_COUNT=", roofs.size(), " failure=",
			WarrenSpatialFabricCompiler.last_failure)
		if not roofs.is_empty():
			var sealed := WarrenSpatialFabricCompiler.solve(plan, program)
			print("FABRIC_SEALED=", sealed != null, " failure=",
				WarrenSpatialFabricCompiler.last_failure)
	for feature: WarrenFeatureReservation in plan.features:
		if feature.construction_records.is_empty():
			continue
		print("FEATURE ", feature.stable_id, " audit=", feature.audit,
			" endpoints=", feature.endpoints)
		for record: Dictionary in feature.construction_records:
			var recipe := program.recipe(StringName(record.recipe_id))
			var feature_bounds := FabricRecipe.lattice_transform(
				record.origin as Vector3i, int(record.yaw_quarters)) \
				* recipe.local_clearance_bounds
			for room_unit: FabricUnit in rooms:
				var room_recipe := program.recipe(room_unit.recipe_id)
				var room_bounds := room_unit.transform() \
					* room_recipe.local_clearance_bounds
				if SettlementFabricPlan._aabb_overlaps_volume(feature_bounds,
						room_bounds):
					print("  OVERLAP component=", record.role, " bounds=",
						feature_bounds, " room=", room_unit.stable_id,
						" recipe=", room_unit.recipe_id, " bounds=", room_bounds)

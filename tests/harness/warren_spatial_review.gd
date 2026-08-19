extends Node3D

## Fast rendered review of the authoritative fine-grid volumetric town. This
## bypasses the expensive whole-corpus selector deliberately: it renders one
## already sealed `WarrenSpatialPlan` candidate through the same measured fabric
## compiler and assembler that production consumes. It is a falsification
## harness, never evidence that the wider candidate selector accepted the seed.
##
##   Godot --path . res://tests/harness/warren_spatial_review.tscn -- \
##     --seed 7 --candidate-id warren.volume.mass.8000031.arcade0.arcade1.gallery2 \
##     --variant 0 --output /tmp/warren-spatial-review
const DEFAULT_PRODUCTION_WORLD_SEED := 2697992464
const DEFAULT_PRODUCTION_SUPER_CELL := Vector2i(0, -1)
const PRODUCTION_REGION_RADIUS := 5

var _output_dir := "/tmp/mythos-warren-spatial-review"
var _world_seed := 7
var _super_cell := DEFAULT_PRODUCTION_SUPER_CELL
var _candidate_token := "8000031"
var _candidate_id := ""
var _partition_variant := 1
var _scale_id := WarrenVillageScaleProfile.LARGE
var _attempt := -1
var _solve_production := false
var _production_terrain_site := false
var _solve_only := false
var _audit_only := false
var _quality_dump := false
var _capture_filter := ""
var _trace_room_gate := false
var _raw_frontier := false
var _maze_source := false
var _probe_ranked_limit := 0
var _camera := Camera3D.new()
var _spatial: WarrenSpatialPlan
var _fabric: SettlementFabricPlan
var _production_urban: VillageUrbanFabricPlan
var _production_heightfield: HeightfieldPlan
var _production_site_cell := Vector2i.ZERO
var _captures: Array[Dictionary] = []


func _ready() -> void:
	_read_args()
	WarrenVolumetricSolver.diagnostic_trace_room_gate = _trace_room_gate
	WarrenVolumetricSolver.diagnostic_trace_skywalk_timing = _trace_room_gate
	WarrenRoomCompositionPlanner.diagnostic_trace = _trace_room_gate
	# The review must render exactly the same strict envelope policy as
	# production. Edge-nick cameras remain as a falsification aid and should now
	# produce no captures.
	SettlementFabricPlan.DIAGNOSTIC_ALLOW_EDGE_ENVELOPE_OVERLAP = false
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_build_environment()
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	if program == null:
		_fail_and_quit("could not compile the settlement fabric program")
		return
	if _probe_ranked_limit > 0:
		_probe_ranked_candidates(program)
		get_tree().quit(0)
		return
	if _production_terrain_site:
		var urban := _solve_production_site(catalog)
		if urban == null or not urban.accepted \
				or urban.volumetric_spatial == null \
				or urban.fabric_plan == null:
			_fail_and_quit("production terrain solve rejected: %s" \
				% String(urban.reason if urban != null else &"missing_plan"))
			return
		_production_urban = urban
		_spatial = urban.volumetric_spatial
		_fabric = urban.fabric_plan
	elif _solve_production:
		_spatial = WarrenVolumetricSolver.solve(_world_seed, {}, program,
			WarrenVillageScaleProfile.for_id(_scale_id))
	elif _maze_source:
		var profile := WarrenVillageScaleProfile.for_id(_scale_id)
		var massif := WarrenMassifBuilder.build(_world_seed, {}, profile)
		var maze := WarrenMazeCarver.carve(_world_seed, massif, profile) \
			if massif != null else null
		var source := WarrenMazeVolumeAdapter.to_volume_plan(maze) \
			if maze != null else null
		if source == null:
			_fail_and_quit("maze source rejected: %s / %s / %s" % [
				WarrenMassifBuilder.last_failure, WarrenMazeCarver.last_failure,
				WarrenMazeVolumeAdapter.last_failure])
			return
		print("[warren_spatial_review] selected maze source=",
			"maze.%d" % maze.world_seed, " signature=",
			maze.deterministic_signature().sha256_text())
		_spatial = WarrenVolumetricSolver.from_volume(source, -1, program,
			profile != null and profile.requires_elevated_courtyard)
	else:
		var source := _select_source(program)
		if source == null:
			_fail_and_quit("no requested volumetric source candidate")
			return
		var direct_profile := WarrenVillageScaleProfile.for_id(_scale_id)
		_spatial = WarrenVolumetricSolver.from_volume(source,
			_partition_variant, program, direct_profile != null \
				and direct_profile.requires_elevated_courtyard)
	if _spatial == null:
		_fail_and_quit("volumetric solve rejected: %s" \
			% WarrenVolumetricSolver.last_failure)
		return
	if _solve_only:
		var landmark_recipes: Array[StringName] = []
		for feature: WarrenFeatureReservation in _spatial.features:
			if feature.kind == &"prefab_landmark" \
					and feature.construction_records.size() == 1:
				landmark_recipes.append(StringName(
					feature.construction_records[0].recipe_id))
		var roof_court := _spatial.audit.get(
			"route_connected_rooftop_court_audit", {}) as Dictionary
		print(("[warren_spatial_review] solve_summary buildings=%d " \
			+ "connected=%d route_floors=%d missing_roofs=%d landmarks=%s " \
			+ "facade_bays=%d room_outcrops=%d unresolved_outcrops=%d " \
			+ "roof_court=%d/%d residual_rooms=%d residual_frontage=%d") % [
			int(_spatial.audit.get("building_count", 0)),
			int(_spatial.audit.get("connected_building_stack_count", 0)),
			int(_spatial.audit.get("public_route_floor_count", 0)),
			int(_spatial.audit.get("missing_roof_face_count", 0)),
			str(landmark_recipes),
			int(_spatial.audit.get("facade_bay_count", 0)),
			int(_spatial.audit.get("room_outcropping_count", 0)),
			int(_spatial.audit.get(
				"unresolved_integrated_cantilever_count", 0)),
			int(roof_court.get("floor_cell_count", 0)),
			int(roof_court.get("combined_floor_cell_count", 0)),
			int(_spatial.audit.get("residual_backfill_building_count", 0)),
			int(_spatial.audit.get("residual_backfill_frontage_side_count", 0)),
		])
		print("[warren_spatial_review] balcony_summary accepted=",
			int(_spatial.audit.get("usable_balcony_count", 0)),
			" candidates=", int(WarrenSpatialFeatureSolver \
				.last_skywalk_diagnostic.get("balcony_candidate_count", 0)),
			" rejections=", str(WarrenSpatialFeatureSolver \
				.last_skywalk_diagnostic.get("balcony_rejection_counts", {})))
		print("[warren_spatial_review] balcony_clearance_samples=",
			str(WarrenSpatialFeatureSolver.last_skywalk_diagnostic.get(
				"balcony_clearance_rejection_samples", [])))
		print("[warren_spatial_review] solve_audit=",
			JSON.stringify(_spatial.audit))
		print("[warren_spatial_review] landmark_preplan=",
			JSON.stringify(WarrenVolumetricSolver.last_preplan_landmark_diagnostic))
		print("[warren_spatial_review] feature_diagnostic=",
			JSON.stringify(WarrenSpatialFeatureSolver.last_skywalk_diagnostic))
		get_tree().quit(0)
		return
	if _fabric == null:
		_fabric = WarrenSpatialFabricCompiler.solve(_spatial, program)
	if _fabric == null:
		_fail_and_quit("fabric compile rejected: %s" \
			% WarrenSpatialFabricCompiler.last_failure)
		return
	if _quality_dump:
		_print_quality_dump(program)
	if _audit_only:
		print("[warren_spatial_review] spatial_audit=",
			JSON.stringify(_spatial.audit))
		print("[warren_spatial_review] fabric_audit=",
			JSON.stringify(_fabric.audit))
		get_tree().quit(0)
		return
	if _production_urban != null:
		_build_production_terrain(_production_urban.world_transform)
	else:
		_build_ground()
	var root := Node3D.new()
	root.name = "AuthoritativeSpatialWarren"
	add_child(root)
	var committed := _commit_production_entries(root, catalog) \
		if _production_urban != null \
		else SettlementFabricAssembler.commit(root, _fabric, catalog, false)
	print("[warren_spatial_review] seed=%d features=%d landmarks=%d balconies=%d instances=%d" \
		% [_world_seed, _spatial.features.size(),
			int(_spatial.audit.get("prefab_landmark_count", 0)),
			int(_spatial.audit.get("usable_balcony_count", 0)),
			int(committed.instance_count)])
	print(("[warren_spatial_review] building_vocabulary lineages=%d " \
		+ "variants=%d styles=%d families=%d kinds=%s") % [
			int(_fabric.audit.get("styled_building_lineage_count", 0)),
			int(_fabric.audit.get("building_variant_count", 0)),
			int(_fabric.audit.get("facade_style_count", 0)),
			(_fabric.audit.get("facade_family_counts", {}) as Dictionary).size(),
			str(_fabric.audit.get("room_storey_kind_counts", {})),
		])
	print(("[warren_spatial_review] composition pairs=%d strong_registration=%d " \
		+ "facade_planes=%d same_kind=%d same_axis=%d roofs=%d pitched=%d " \
		+ "flat=%d roof_terraces=%d bare_flat=%d caps=%d lean_tos=%d " \
		+ "macro_gables=%d macro_fallbacks=%d setback_terraces=%d") % [
			int(_spatial.audit.get("consecutive_floorplate_pair_count", 0)),
			int(_spatial.audit.get(
				"strongly_registered_floorplate_pair_count", 0)),
			int(_spatial.audit.get("registered_facade_plane_count", 0)),
			int(_spatial.audit.get("same_kind_floorplate_pair_count", 0)),
			int(_spatial.audit.get("same_ridge_axis_floorplate_pair_count", 0)),
			int(_fabric.audit.get("roof_unit_count", 0)),
			int(_fabric.audit.get("pitched_roof_count", 0)),
			int(_fabric.audit.get("flat_roof_count", 0)),
			int(_fabric.audit.get("flat_roof_terrace_count", 0)),
			int(_fabric.audit.get("bare_flat_roof_count", 0)),
			int(_fabric.audit.get("setback_cap_unit_count", 0)),
			int(_fabric.audit.get("setback_lean_to_unit_count", 0)),
			int(_fabric.audit.get("setback_macro_gable_unit_count", 0)),
			int(_fabric.audit.get("setback_macro_gable_fallback_count", 0)),
			int(_fabric.audit.get("setback_terrace_unit_count", 0)),
		])
	print(("[warren_spatial_review] roof_neighborhood joins=%d ridges=%d " \
		+ "parallel_valleys=%d perpendicular_valleys=%d flattened=%d trims=%d " \
		+ "dormered=%d paired_dormers=%d facade_bays=%d") % [
			int(_fabric.audit.get("roof_neighborhood_join_count", 0)),
			int(_fabric.audit.get("continuous_ridge_join_count", 0)),
			int(_fabric.audit.get("parallel_valley_join_count", 0)),
			int(_fabric.audit.get("perpendicular_valley_join_count", 0)),
			int(_fabric.audit.get("roof_neighborhood_flattened_room_count", 0)),
			int(_fabric.audit.get("roof_junction_trim_unit_count", 0)),
			int(_fabric.audit.get("dormered_pitched_roof_count", 0)),
			int(_fabric.audit.get("paired_dormer_roof_count", 0)),
			int(_spatial.audit.get("facade_bay_count", 0)),
		])
	_camera.current = true
	_camera.near = 0.08
	_camera.far = 400.0
	add_child(_camera)
	_capture_all.call_deferred()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index + 1 < args.size():
			_output_dir = args[index + 1]
		elif args[index] == "--seed" and index + 1 < args.size():
			_world_seed = int(args[index + 1])
		elif args[index] == "--candidate-token" and index + 1 < args.size():
			_candidate_token = args[index + 1]
		elif args[index] == "--candidate-id" and index + 1 < args.size():
			_candidate_id = args[index + 1]
		elif args[index] == "--variant" and index + 1 < args.size():
			_partition_variant = int(args[index + 1])
		elif args[index] == "--attempt" and index + 1 < args.size():
			_attempt = int(args[index + 1])
		elif args[index] == "--scale" and index + 1 < args.size():
			_scale_id = StringName(args[index + 1])
		elif args[index] == "--solve-production":
			_solve_production = true
		elif args[index] == "--solve-only":
			_solve_only = true
		elif args[index] == "--audit-only":
			_audit_only = true
		elif args[index] == "--quality-dump":
			_quality_dump = true
		elif args[index] == "--capture-filter" and index + 1 < args.size():
			_capture_filter = args[index + 1]
		elif args[index] == "--trace-room-gate":
			_trace_room_gate = true
		elif args[index] == "--raw-frontier":
			_raw_frontier = true
		elif args[index] == "--maze-source":
			_maze_source = true
		elif args[index] == "--probe-ranked" and index + 1 < args.size():
			_probe_ranked_limit = maxi(1, int(args[index + 1]))
		elif args[index] == "--production-terrain-site":
			_production_terrain_site = true
			_world_seed = DEFAULT_PRODUCTION_WORLD_SEED
		elif args[index] == "--super-x" and index + 1 < args.size():
			_super_cell.x = int(args[index + 1])
		elif args[index] == "--super-z" and index + 1 < args.size():
			_super_cell.y = int(args[index + 1])


func _probe_ranked_candidates(program: SettlementFabricProgram) -> void:
	## Quality-pass utility: report the exact room/court result of the ranked
	## source/partition pairs without rendering each rejected town. This makes a
	## candidate-selection change reviewable instead of choosing a prettier source
	## from a debug proxy that never reached the sealed spatial transaction.
	var profile := WarrenVillageScaleProfile.for_id(_scale_id)
	var frontier := WarrenTownSolver.mass_first_attempt_frontier(_world_seed,
		_attempt, {}, profile) if _attempt >= 0 \
		else WarrenTownSolver.mass_first_frontier(_world_seed, {}, profile)
	var ranked := WarrenVolumetricSolver._ranked_precomposition_variants(
		frontier, program)
	for rank_index in mini(_probe_ranked_limit, ranked.size()):
		var ranked_value := ranked[rank_index] as Dictionary
		var source := ranked_value.volume as WarrenVolumePlan
		var variant := int(ranked_value.variant)
		var exact_proxy := WarrenVolumetricSolver \
			._precomposition_enclosure_audit(source, variant, program)
		var spatial := WarrenVolumetricSolver.from_volume(source, variant,
			program, false)
		if spatial == null:
			print("[warren_spatial_review] rank_probe rank=", rank_index,
				" source=", source.stable_id, " variant=", variant,
				" score=", ranked_value.score, " proxy_court=",
				int(exact_proxy.get("broad_rooftop_court_cell_count", 0)),
				" proxy_occupied=", int(exact_proxy.get("occupied_cell_count", 0)),
				" proxy_bounded=", float(exact_proxy.get("bounded_route_ratio", 0.0)),
				" accepted=false failure=",
				WarrenVolumetricSolver.last_failure.left(400))
			continue
		var court := spatial.audit.get(
			"route_connected_rooftop_court_audit", {}) as Dictionary
		print("[warren_spatial_review] rank_probe rank=", rank_index,
			" source=", source.stable_id, " variant=", variant,
			" score=", ranked_value.score, " proxy_court=",
			int(exact_proxy.get("broad_rooftop_court_cell_count", 0)),
			" proxy_occupied=", int(exact_proxy.get("occupied_cell_count", 0)),
			" proxy_bounded=", float(exact_proxy.get("bounded_route_ratio", 0.0)),
			" accepted=true buildings=",
			int(spatial.audit.get("building_count", 0)), " retained=",
			int(spatial.audit.get("retained_private_mass_cell_count", 0)),
			" discarded=", int(spatial.audit.get(
				"unassigned_mass_cell_count", 0)), " court=",
			int(court.get("floor_cell_count", 0)), "/",
			int(court.get("combined_floor_cell_count", 0)), " court_audit=",
			JSON.stringify(court))


func _print_quality_dump(program: SettlementFabricProgram) -> void:
	if _fabric.surface_plan != null:
		print("[warren_spatial_review] QUALITY_ENTRANCES_BEGIN audit=",
			JSON.stringify(_fabric.surface_plan.audit()))
		for entrance: Dictionary in _fabric.surface_plan.entrance_records:
			print("[quality.entrance] ", JSON.stringify(entrance))
		for segment: Dictionary in _fabric.surface_plan.guard_segments:
			print("[quality.guard] ", JSON.stringify(segment))
		var guard_payload := SettlementFabricAssembler.surface_visual_payload(
			_fabric.surface_plan)
		for asset_id: StringName in guard_payload.asset_ids():
			if String(asset_id).contains("railing"):
				var batch := guard_payload.batches[asset_id] as Dictionary
				print("[quality.guard.batch] asset=", asset_id, " count=",
					(batch.transforms as Array).size(), " stable_ids=",
					batch.ids)
		print("[warren_spatial_review] QUALITY_ENTRANCES_END")
	print("[warren_spatial_review] QUALITY_ROOMS_BEGIN")
	for building: WarrenBuildingVolume in _spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			var below := PackedStringArray()
			if not room.terrain_bearing:
				var columns: Dictionary = {}
				for cell: Vector3i in room.private_cells:
					if cell.y == room.lattice_origin.y:
						columns[Vector2i(cell.x, cell.z)] = true
				var ordered_columns: Array[Vector2i] = []
				ordered_columns.assign(columns.keys())
				ordered_columns.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
					return a.y < b.y if a.y != b.y else a.x < b.x)
				for column: Vector2i in ordered_columns:
					var support_cell := Vector3i(column.x,
						room.lattice_origin.y - 1, column.y)
					below.append("%s:u%d:o%s" % [support_cell,
						_spatial.grid.use_at(support_cell),
						String(_spatial.grid.owner_name_at(support_cell))])
			print("[quality.room] id=", room.stable_id, " building=",
				building.stable_id, " kind=", room.kind, " origin=",
				room.lattice_origin, " yaw=", room.yaw_quarters,
				" terrain_bearing=", room.terrain_bearing,
				" addressed=", room.addressed,
				" door_phase=", room.address_door_phase,
				" threshold=", room.threshold_cell,
				" frontage=", room.frontage_direction,
				" landing=", room.threshold_cell + room.frontage_direction \
					if room.addressed else Vector3i.ZERO,
				" foundation=", _quality_foundation_facts(room),
				" parent=", room.support_parent_parcel_id, ":",
				room.support_parent_storey_index, " below=", ";".join(below))
	print("[warren_spatial_review] QUALITY_ROOMS_END")
	print("[warren_spatial_review] QUALITY_FEATURES_BEGIN")
	for feature: WarrenFeatureReservation in _spatial.features:
		var records := PackedStringArray()
		for record: Dictionary in feature.construction_records:
			records.append("%s@%s/r%d/%s" % [String(record.recipe_id),
				str(record.origin), int(record.yaw_quarters), String(record.role)])
		print("[quality.feature] id=", feature.stable_id, " kind=", feature.kind,
			" reserved=", _quality_cell_bounds(feature.reserved_cells),
			" bearing=", _quality_cell_bounds(feature.terrain_bearing_cells),
			" endpoints=", feature.endpoints, " records=", ";".join(records),
			" audit=", feature.audit)
		if feature.kind == &"balcony":
			_print_balcony_neighbor_dump(feature)
	print("[warren_spatial_review] QUALITY_FEATURES_END")
	print("[warren_spatial_review] QUALITY_UNITS_BEGIN")
	for unit: FabricUnit in _fabric.units:
		var recipe := program.recipe(unit.recipe_id)
		var relevant := recipe != null and (recipe.has_tag(&"roof") \
			or recipe.has_tag(&"room") \
			or recipe.has_tag(&"balcony") or recipe.has_tag(&"outcropping") \
			or recipe.has_tag(&"stair") or recipe.has_tag(&"prefab_anchor"))
		if relevant:
			var placements := PackedStringArray()
			for placement: Dictionary in recipe.placements:
				placements.append("%s:%s@%s" % [String(placement.id),
					String(placement.asset_id),
					str((placement.transform as Transform3D).origin)])
			print("[quality.unit] id=", unit.stable_id, " recipe=", unit.recipe_id,
				" origin=", unit.lattice_origin, " yaw=", unit.yaw_quarters,
				" bounds=", unit.bounds, " tags=", recipe.role_tags,
				" parents=", unit.parent_ids, " bonds=", unit.socket_bonds,
				" seams=", unit.visual_seam_ids,
				" suppressed=", unit.suppressed_placement_ids,
				" placements=", ";".join(placements))
	print("[warren_spatial_review] QUALITY_UNITS_END")


func _quality_foundation_facts(room: WarrenRoomStamp) -> String:
	if not room.terrain_bearing or _spatial.source_volume == null:
		return "none"
	var depths: Dictionary = {}
	for cell: Vector3i in room.private_cells:
		if cell.y != room.lattice_origin.y:
			continue
		var macro := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		var bearing := _spatial.source_volume.envelope.bearing_at(macro)
		depths[room.lattice_origin.y - bearing] = true
	var ordered: Array = depths.keys()
	ordered.sort()
	return "depths=%s" % str(ordered)


func _print_balcony_neighbor_dump(feature: WarrenFeatureReservation) -> void:
	## Review evidence for circulation composition: expose every non-outside cell
	## within one lattice cell of the balcony, including the authoritative face
	## kind on its top. This makes a stair/platform mismatch diagnosable without
	## inferring topology from a perspective screenshot.
	if feature.reserved_cells.is_empty():
		return
	var minimum := feature.reserved_cells[0] - Vector3i.ONE
	var maximum := feature.reserved_cells[0] + Vector3i.ONE
	for cell: Vector3i in feature.reserved_cells:
		minimum = Vector3i(mini(minimum.x, cell.x - 1),
			mini(minimum.y, cell.y - 1), mini(minimum.z, cell.z - 1))
		maximum = Vector3i(maxi(maximum.x, cell.x + 1),
			maxi(maximum.y, cell.y + 1), maxi(maximum.z, cell.z + 1))
	var facts := PackedStringArray()
	for y in range(minimum.y, maximum.y + 1):
		for z in range(minimum.z, maximum.z + 1):
			for x in range(minimum.x, maximum.x + 1):
				var cell := Vector3i(x, y, z)
				var use := _spatial.grid.use_at(cell)
				if use == WarrenSpatialGrid.Use.OUTSIDE:
					continue
				var top_face := _spatial.grid.face_claim(cell, Vector3i.UP)
				facts.append("%s:u%d:o%s:t%s" % [cell, use,
					String(_spatial.grid.owner_name_at(cell)),
					str(top_face.get("kind", -1))])
	print("[quality.balcony.neighbors] id=", feature.stable_id,
		" cells=", ";".join(facts))


func _quality_cell_bounds(cells: Array[Vector3i]) -> String:
	if cells.is_empty():
		return "empty"
	var minimum := cells[0]
	var maximum := cells[0]
	for cell: Vector3i in cells:
		minimum = Vector3i(mini(minimum.x, cell.x), mini(minimum.y, cell.y),
			mini(minimum.z, cell.z))
		maximum = Vector3i(maxi(maximum.x, cell.x), maxi(maximum.y, cell.y),
			maxi(maximum.z, cell.z))
	return "%s..%s" % [minimum, maximum]


func _solve_production_site(catalog: EnvironmentCatalog) \
		-> VillageUrbanFabricPlan:
	var water := TerrainWorldTuning.make_water(_world_seed)
	var site := SettlementPlan.new(_world_seed, water).site_for(_super_cell)
	if site.is_empty():
		return null
	var cell := site.cell as Vector2i
	var heightfield := TerrainWorldTuning.make_heightfield(_world_seed, water)
	_production_heightfield = heightfield
	_production_site_cell = cell
	var region := heightfield.compute_region(cell.x, cell.y,
		PRODUCTION_REGION_RADIUS)
	var terrain := VillageTerrainView.from_region(region)
	var village_program := VillageProgram.compile({}, catalog)
	if village_program == null:
		return null
	var frame := VillageFrame.from_mask(site, 1, region,
		_empty_water(region, cell))
	var city_seed := VillagePlan.new(_world_seed,
		village_program)._warren_seed(frame)
	print(("[warren_spatial_review] production terrain world_seed=%d " \
		+ "city_seed=%d scale=%s super_cell=(%d,%d)") % [_world_seed, city_seed,
		String(WarrenVillageScaleProfile.select(city_seed).scale_id),
			_super_cell.x, _super_cell.y])
	return VillageWarrenFabricSolver.solve(terrain, city_seed,
		frame.settlement_id, frame.centre, Vector2.RIGHT, village_program)


func _build_production_terrain(world_frame: Transform3D) -> void:
	## Review the same immutable heightfield the placement solver sampled. Keep
	## the authored town in its convenient local frame and transform real terrain
	## back into that frame; all existing adversarial cameras then remain valid.
	assert(_production_heightfield != null)
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(_world_seed)
	mesher.prepare_resources()
	var centre := Vector2(_production_site_cell) * TerrainSurfaceField.TILE
	var reach := 96.0
	var chunk_lo := Vector2i(floori((centre.x - reach) \
		/ TerrainChunkMesher.CHUNK_WORLD), floori((centre.y - reach) \
		/ TerrainChunkMesher.CHUNK_WORLD))
	var chunk_hi := Vector2i(floori((centre.x + reach) \
		/ TerrainChunkMesher.CHUNK_WORLD), floori((centre.y + reach) \
		/ TerrainChunkMesher.CHUNK_WORLD))
	var terrain_root := Node3D.new()
	terrain_root.name = "ProductionTerrainInTownFrame"
	terrain_root.transform = world_frame.affine_inverse()
	add_child(terrain_root)
	for cz in range(chunk_lo.y, chunk_hi.y + 1):
		for cx in range(chunk_lo.x, chunk_hi.x + 1):
			terrain_root.add_child(mesher.build_chunk(_production_heightfield,
				Vector2i(cx, cz)))


func _commit_production_entries(parent: Node3D,
		catalog: EnvironmentCatalog) -> Dictionary:
	## The ordinary local assembler omits terrain-drop posts because only the
	## production adapter knows the sampled world ground. Render the materialized
	## entry payload here so support review sees those exact fixed modules too.
	var payload := EnvironmentInstancePayload.new()
	var inverse := _production_urban.world_transform.affine_inverse()
	for entry: Dictionary in _production_urban.entries:
		payload.add(StringName(entry.asset_id),
			inverse * (entry.transform as Transform3D), Color.WHITE,
			StringName(entry.stable_id))
	for world_mesh: Dictionary in _production_urban.surface_meshes:
		var local_mesh := world_mesh.duplicate(true)
		var vertices := PackedVector3Array()
		for vertex: Vector3 in world_mesh.vertices as PackedVector3Array:
			vertices.append(inverse * vertex)
		var normals := PackedVector3Array()
		for normal: Vector3 in world_mesh.normals as PackedVector3Array:
			normals.append((inverse.basis * normal).normalized())
		var collision := PackedVector3Array()
		for face_point: Vector3 in world_mesh.collision_faces \
				as PackedVector3Array:
			collision.append(inverse * face_point)
		local_mesh["vertices"] = vertices
		local_mesh["normals"] = normals
		local_mesh["collision_faces"] = collision
		local_mesh["anchor"] = inverse * (world_mesh.get("anchor",
			Vector3.ZERO) as Vector3)
		payload.add_surface_mesh(local_mesh)
	assert(payload.validate())
	var cache := EnvironmentRenderCache.new(catalog)
	assert(cache.prepare(payload.asset_ids()))
	var queue := EnvironmentCommitQueue.new(cache, &"ProductionFabricVisuals")
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, payload)
	while queue.pending_count() > 0:
		queue.drain(64)
	var terrain_support_count := 0
	for entry: Dictionary in _production_urban.entries:
		terrain_support_count += int(String(entry.stable_id).contains(
			"terrain-support/"))
	return {"instance_count": payload.instance_count,
		"terrain_support_count": terrain_support_count}


func _fail_and_quit(reason: String) -> void:
	printerr("[warren_spatial_review] ", reason)
	if not WarrenSpatialFeatureSolver.last_outcropping_diagnostic.is_empty():
		printerr("[warren_spatial_review] outcrop_diagnostic=",
			JSON.stringify(
				WarrenSpatialFeatureSolver.last_outcropping_diagnostic))
	get_tree().quit(1)


static func _empty_water(region: HeightfieldRegion,
		cell: Vector2i) -> WaterFieldContext:
	var context := WaterFieldContext.new()
	context._ctx = {"ponds": [], "rivers": [], "buckets": {},
		"region": region}
	context._region = region
	var centre := Vector2(cell) * TerrainSurfaceField.TILE
	var radius := float(PRODUCTION_REGION_RADIUS) * TerrainSurfaceField.TILE
	context._coverage = Rect2(centre - Vector2.ONE * radius,
		Vector2.ONE * radius * 2.0)
	context._shore_limit = 0.0
	return context


func _select_source(program: SettlementFabricProgram) -> WarrenVolumePlan:
	var profile := WarrenVillageScaleProfile.for_id(_scale_id)
	if profile == null or program == null:
		return null
	var frontier := WarrenTownSolver.mass_first_attempt_frontier(_world_seed,
		_attempt, {}, profile) if _attempt >= 0 \
		else WarrenTownSolver.mass_first_frontier(_world_seed, {}, profile)
	if _raw_frontier:
		for candidate: WarrenVolumePlan in frontier:
			var id_matches := not _candidate_id.is_empty() \
				and String(candidate.stable_id) == _candidate_id
			var token_matches := _candidate_id.is_empty() \
				and (_candidate_token.is_empty() \
					or String(candidate.stable_id).contains(_candidate_token))
			if id_matches or token_matches:
				print("[warren_spatial_review] selected raw source=",
					candidate.stable_id, " variant=", _partition_variant,
					" signature=",
					candidate.deterministic_signature().sha256_text())
				return candidate
		return null
	# The production solver ranks fully threaded precomposition variants, not the
	# raw frontier object that happens to share their stable source id. Render the
	# exact same `(source, partition_variant)` pair as the text proof; otherwise a
	# capture can silently review a different skywalk/court transaction.
	var ranked := WarrenVolumetricSolver._ranked_precomposition_variants(
		frontier, program)
	for ranked_index in ranked.size():
		var candidate_value := ranked[ranked_index]
		if int(candidate_value.variant) != _partition_variant:
			continue
		var candidate := candidate_value.volume as WarrenVolumePlan
		var id_matches := not _candidate_id.is_empty() \
			and String(candidate.stable_id) == _candidate_id
		var token_matches := _candidate_id.is_empty() \
			and (_candidate_token.is_empty() \
				or String(candidate.stable_id).contains(_candidate_token))
		if id_matches or token_matches:
			print("[warren_spatial_review] selected rank=", ranked_index,
				" source=", candidate.stable_id, " variant=",
				candidate_value.variant, " score=", candidate_value.score,
				" signature=",
				candidate.deterministic_signature().sha256_text())
			return candidate
	return null


func _capture_all() -> void:
	for unused in 12:
		await get_tree().process_frame
	var bounds := _fabric_bounds()
	var centre := bounds.get_center()
	var span := maxf(bounds.size.x, bounds.size.z)
	var views: Array[Dictionary] = [
		{"id": "overview-ne", "position": centre + Vector3(span,
			span * 0.8, span), "target": centre, "fov": 52.0},
		{"id": "overview-sw", "position": centre + Vector3(-span,
			span * 0.65, -span), "target": centre, "fov": 54.0},
	]
	views.append_array(_street_views())
	views.append_array(_transition_views())
	views.append_array(_market_views())
	views.append_array(_courtyard_views())
	views.append_array(_route_connected_rooftop_court_views())
	views.append_array(_roof_terrace_views())
	views.append_array(_dormer_views())
	views.append_array(_roof_campaign_views())
	views.append_array(_interstitial_gap_views())
	views.append_array(_interstitial_join_views())
	views.append_array(_residual_jetty_views())
	views.append_array(_addressed_door_views())
	views.append_array(_terrain_foundation_views())
	views.append_array(_arcade_overhang_views())
	views.append_array(_room_overhang_support_views())
	views.append_array(_skywalk_views())
	views.append_array(_room_outcropping_views())
	views.append_array(_tower_annex_views())
	views.append_array(_landmark_views())
	views.append_array(_balcony_views())
	views.append_array(_edge_nick_views())
	for view: Dictionary in views:
		if not _capture_filter.is_empty() \
				and not String(view.id).contains(_capture_filter):
			continue
		_camera.fov = float(view.fov)
		_camera.look_at_from_position(view.position as Vector3,
			view.target as Vector3)
		for unused in 3:
			await get_tree().process_frame
		RenderingServer.force_draw()
		await get_tree().process_frame
		var path := "%s/seed-%03d-%s.png" % [_output_dir, _world_seed,
			String(view.id)]
		var image := get_viewport().get_texture().get_image()
		assert(image != null and image.save_png(path) == OK)
		_captures.append({"screenshot_id": view.id, "image": path,
			"position": _v3(view.position as Vector3),
			"target": _v3(view.target as Vector3), "fov": view.fov,
			"review_disposition": "UNREVIEWED"})
		print("[warren_spatial_review] captured ", path)
	_write_manifest()
	get_tree().quit()


func _street_views() -> Array[Dictionary]:
	## Select complete same-level, two-lane route runs. Merely finding one
	## neighboring route cell can point through the next corner and photograph a
	## facade at zero range; a five-cell run keeps both eye and target inside the
	## actual negative-space street the player traverses.
	var route_set: Dictionary = {}
	for cell: Vector3i in _spatial.route_floor_cells:
		route_set[cell] = true
	var candidates: Array[Dictionary] = []
	for cell: Vector3i in _spatial.route_floor_cells:
		for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK,
				Vector3i.LEFT, Vector3i.FORWARD]:
			if not _has_route_run(route_set, cell, direction, 5):
				continue
			var side := Vector3i(-direction.z, 0, direction.x)
			for lane_side: Vector3i in [side, -side]:
				if not _has_route_run(route_set, cell + lane_side,
						direction, 5):
					continue
				var wall_score := 0
				var overhead_score := 0
				for step in 5:
					var lane_a := cell + direction * step
					var lane_b := lane_a + lane_side
					for outside: Vector3i in [lane_a - lane_side,
							lane_b + lane_side]:
						wall_score += int(_is_building_use(
							_spatial.grid.use_at(outside)) \
							or _is_building_use(_spatial.grid.use_at(
								outside + Vector3i.UP)))
					for height in range(2, 6):
						overhead_score += int(_is_building_use(
							_spatial.grid.use_at(lane_a \
								+ Vector3i.UP * height)))
						overhead_score += int(_is_building_use(
							_spatial.grid.use_at(lane_b \
								+ Vector3i.UP * height)))
				var terminal_enclosure := _street_terminal_enclosure(
					cell + direction * 5, direction, lane_side)
				var score := wall_score * 3 + overhead_score * 2 \
					+ terminal_enclosure * 5
				if wall_score >= 6:
					candidates.append({"cell": cell, "direction": direction,
						"lane_side": lane_side, "score": score,
						"wall_score": wall_score,
						"overhead_score": overhead_score,
						"terminal_enclosure": terminal_enclosure})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return _cell_key(a.cell as Vector3i) < _cell_key(b.cell as Vector3i))
	var selected: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		var separated := true
		for prior: Dictionary in selected:
			var delta := (candidate.cell as Vector3i) - (prior.cell as Vector3i)
			if absi(delta.x) + absi(delta.z) < 8 and absi(delta.y) < 3:
				separated = false
				break
		if not separated:
			continue
		selected.append(candidate)
		if selected.size() >= 4:
			break
	var out: Array[Dictionary] = []
	for index in selected.size():
		var candidate := selected[index]
		var eye := (Vector3(candidate.cell as Vector3i) \
			+ Vector3(candidate.lane_side as Vector3i) * 0.5) \
			* FabricRecipe.CELL_SIZE + Vector3.UP * 1.45
		var direction := candidate.direction as Vector3i
		out.append({"id": "street-%02d-w%d-o%d" % [index,
			int(candidate.wall_score), int(candidate.overhead_score)],
			"position": eye, "target": eye + Vector3(direction) * 6.0 \
				+ Vector3.UP * 0.25, "fov": 72.0})
	return out


func _transition_views() -> Array[Dictionary]:
	## Photograph the real collision-bearing ramp/stair spans from their lower
	## landing. A route graph can be connected while a visual adapter leaves an
	## empty vertical seam, so overviews and same-level street shots are not a
	## sufficient review gate for the complete walk.
	var out: Array[Dictionary] = []
	if _spatial == null or _spatial.source_volume == null:
		return out
	var ordinal := 0
	for transition: WarrenVolumeTransition in \
			_spatial.source_volume.transitions:
		if not transition.is_vertical():
			continue
		var from_centre := Vector3(
			float(transition.from_cell.x) \
				* WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M \
				+ FabricRecipe.CELL_SIZE * 0.5,
			float(transition.from_cell.y) \
				* WarrenVolumePlan.VERTICAL_BAND_SIZE_M,
			float(transition.from_cell.z) \
				* WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M \
				+ FabricRecipe.CELL_SIZE * 0.5)
		var to_centre := Vector3(
			float(transition.to_cell.x) \
				* WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M \
				+ FabricRecipe.CELL_SIZE * 0.5,
			float(transition.to_cell.y) \
				* WarrenVolumePlan.VERTICAL_BAND_SIZE_M,
			float(transition.to_cell.z) \
				* WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M \
				+ FabricRecipe.CELL_SIZE * 0.5)
		var low := from_centre if from_centre.y <= to_centre.y else to_centre
		var high := to_centre if from_centre.y <= to_centre.y else from_centre
		var direction := high - low
		direction.y = 0.0
		if direction.length_squared() <= 0.01:
			continue
		direction = direction.normalized()
		out.append({"id": "transition-%02d" % ordinal,
			"position": low - direction * 0.6 + Vector3.UP * 1.25,
			"target": high + Vector3.UP * 0.45, "fov": 70.0})
		ordinal += 1
		if ordinal >= 3:
			break
	return out


func _roof_terrace_views() -> Array[Dictionary]:
	## Furnished flat roofs are deliberately optional measured recipes. Give
	## them their own adversarial view so benches, barrels, lamps, planters, and
	## rails cannot be credited merely because their asset IDs occur in a recipe
	## the dense-town compiler never managed to place.
	var out: Array[Dictionary] = []
	for unit: FabricUnit in _fabric.units:
		if not String(unit.stable_id).begins_with("spatial.roof."):
			continue
		var recipe := _fabric.recipe(unit.recipe_id)
		if recipe == null or not recipe.has_tag(&"furnished_roof_terrace"):
			continue
		var recipe_text := String(recipe.recipe_id)
		var local_outward := Vector3i.BACK
		if recipe_text.contains(".north"):
			local_outward = Vector3i.FORWARD
		elif recipe_text.contains(".east"):
			local_outward = Vector3i.RIGHT
		elif recipe_text.contains(".west"):
			local_outward = Vector3i.LEFT
		var outward := Vector3(FabricRecipe.transform_direction(local_outward,
			unit.yaw_quarters))
		var bounds := unit.transform() * recipe.local_clearance_bounds
		var target := bounds.get_center()
		target.y = float(unit.lattice_origin.y) * FabricRecipe.CELL_SIZE + 1.1
		var distance := maxf(9.0, maxf(bounds.size.x, bounds.size.z) + 4.0)
		var eye := _best_directional_position(target, outward, distance, 2.3,
			[unit.stable_id] as Array[StringName], bounds)
		out.append({"id": "roof-terrace-%02d-furnished" % out.size(),
			"position": eye, "target": target, "fov": 55.0})
		if out.size() >= 4:
			break
	return out


func _dormer_views() -> Array[Dictionary]:
	## Verify the attic projection in the final selected construction, not just in
	## an isolated recipe lineup. Aim along the slope-normal implied by the
	## authored facing so its face, cheeks, and intersection with the roof plane
	## all remain visible. Recipe bounds and roof centres can be asymmetric at a
	## T-junction, so neither is a reliable proxy for the dormer's real front.
	var out: Array[Dictionary] = []
	for unit: FabricUnit in _fabric.units:
		var recipe := _fabric.recipe(unit.recipe_id)
		if recipe == null or not recipe.has_tag(&"dormer"):
			continue
		var dormer_pose := Transform3D.IDENTITY
		var found := false
		for placement: Dictionary in recipe.placements:
			if not String(placement.id).contains("dormer"):
				continue
			dormer_pose = placement.transform as Transform3D
			found = true
			break
		if not found:
			continue
		var transform := unit.transform()
		# Aim at the authored glazing, not the buried construction sill. The latter
		# is intentionally below the host roof and made correct seating look like an
		# empty gable in the old review frame.
		var target := transform * dormer_pose.origin + Vector3.UP * 1.35
		var bounds := transform * recipe.local_clearance_bounds
		# Every dormer recipe rotates local BACK toward its eave. Transform that
		# authored direction through both placement and unit bearings.
		var outward := transform.basis * dormer_pose.basis * Vector3.BACK
		outward.y = 0.0
		if outward.length_squared() <= 0.01:
			outward = transform.basis * Vector3.BACK
		outward.y = 0.0
		outward = outward.normalized()
		var eye := _best_directional_position(target, outward, 7.5, 1.2,
			[unit.stable_id] as Array[StringName], bounds)
		out.append({"id": "dormer-%02d" % out.size(), "position": eye,
			"target": target, "fov": 48.0})
		if out.size() >= 4:
			break
	return out


func _roof_campaign_views() -> Array[Dictionary]:
	## Dormer-only targets miss the roof neighborhoods deliberately flattened by
	## the compiler. Photograph the classified crossing itself so visual review
	## can prove the replacement is one coherent decorated service-roof campaign.
	var room_by_id: Dictionary = {}
	for building: WarrenBuildingVolume in _spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			room_by_id[room.stable_id] = room
	var out: Array[Dictionary] = []
	# Initial topology flattening is not presently exposed as room IDs. Recover
	# the final decorated flat roofs and select pairs whose room bounds touch.
	var flat_units: Array[FabricUnit] = []
	for unit: FabricUnit in _fabric.units:
		if String(unit.recipe_id).begins_with("roof.flat.") \
				and not String(unit.recipe_id).contains(".garden"):
			flat_units.append(unit)
	for left_index in flat_units.size():
		var left := flat_units[left_index]
		var left_room_id := StringName(String(left.stable_id).trim_prefix(
			"spatial.roof."))
		var left_room := room_by_id.get(left_room_id) as WarrenRoomStamp
		if left_room == null:
			continue
		var left_columns := _room_columns(left_room)
		for right_index in range(left_index + 1, flat_units.size()):
			var right := flat_units[right_index]
			var right_room_id := StringName(String(right.stable_id).trim_prefix(
				"spatial.roof."))
			var right_room := room_by_id.get(right_room_id) as WarrenRoomStamp
			if right_room == null or right_room.lattice_origin.y \
					!= left_room.lattice_origin.y:
				continue
			var adjacent := false
			var right_columns := _room_columns(right_room)
			for column_value: Variant in left_columns.keys():
				var column := column_value as Vector2i
				for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
						Vector2i.UP, Vector2i.DOWN]:
					if right_columns.has(column + direction):
						adjacent = true
						break
				if adjacent:
					break
			if not adjacent:
				continue
			var left_recipe := _fabric.recipe(left.recipe_id)
			var right_recipe := _fabric.recipe(right.recipe_id)
			var left_bounds := left.transform() \
				* left_recipe.local_clearance_bounds
			var right_bounds := right.transform() \
				* right_recipe.local_clearance_bounds
			var bounds := left_bounds.merge(right_bounds)
			var target := bounds.get_center() + Vector3.UP * 0.4
			var outward := Vector3(1.0, 0.0, 1.0).normalized()
			var eye := _best_directional_position(target, outward,
				maxf(9.0, bounds.size.length() * 0.8), 2.5,
				[left.stable_id, right.stable_id] as Array[StringName], bounds)
			out.append({"id": "roof-campaign-%02d" % out.size(),
				"position": eye, "target": target, "fov": 52.0})
			if out.size() >= 4:
				return out
	return out


func _room_columns(room: WarrenRoomStamp) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in room.private_cells:
		out[Vector2i(cell.x, cell.z)] = true
	return out


func _street_terminal_enclosure(cell: Vector3i, direction: Vector3i,
		lane_side: Vector3i) -> int:
	var score := 0
	for forward_step in 3:
		var centre := cell + direction * forward_step
		for side_step in [-1, 2]:
			var outside: Vector3i = centre + lane_side * side_step
			for y_offset in 3:
				score += int(_is_building_use(_spatial.grid.use_at(
					outside + Vector3i.UP * y_offset)))
		for y_offset in range(2, 6):
			score += int(_is_building_use(_spatial.grid.use_at(
				centre + Vector3i.UP * y_offset)))
	return score


func _market_views() -> Array[Dictionary]:
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"covered_market" \
				or feature.construction_records.size() != 1:
			continue
		var centre := _cell_centroid(feature.public_cells)
		var aisle := _market_public_aisle_view(feature)
		var visual_bounds := _feature_visual_bounds(feature)
		# The topology solver may join the market through any side or after a turn;
		# recipe-local BACK is therefore not evidence of the street approach. Walk
		# the actual connected route and select a clear player-height sightline back
		# into the bazaar. This keeps a neighboring house from becoming the entire
		# exterior review image while still photographing the market from traversable
		# public space.
		var approach := _market_route_approach(feature,
			centre + Vector3.UP * 1.25)
		var ignored := [StringName("spatial.fabric.%s" % feature.stable_id)] \
			as Array[StringName]
		var approach_eye := approach.position as Vector3 \
			if not approach.is_empty() else _best_orbit_position(centre,
				12.0, 2.0, ignored, visual_bounds)
		var approach_target := approach.target as Vector3 \
			if not approach.is_empty() else centre + Vector3.UP * 1.25
		return [{"id": "market-aisle", "position": aisle.position,
			"target": aisle.target, "fov": 72.0},
			{"id": "market-approach", "position": approach_eye,
				"target": approach_target, "fov": 68.0}] \
			as Array[Dictionary]
	return [] as Array[Dictionary]


func _market_public_aisle_view(feature: WarrenFeatureReservation) -> Dictionary:
	## Both camera and target sit on the feature's sealed public floor cells.
	## Recipe-local BACK previously put the eye inside an unrelated stone shell.
	var floors: Array[Vector3i] = feature.public_cells.duplicate()
	if floors.is_empty():
		return {"position": Vector3.ZERO, "target": Vector3.FORWARD}
	floors.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return _cell_key(a) < _cell_key(b))
	var best_left: Vector3i = floors[0]
	var best_right: Vector3i = floors[0]
	var best_distance := -1
	for left: Vector3i in floors:
		for right: Vector3i in floors:
			if left.y != right.y:
				continue
			var distance := absi(left.x - right.x) + absi(left.z - right.z)
			if distance > best_distance:
				best_distance = distance
				best_left = left
				best_right = right
	var eye := _route_eye(best_left)
	var target := _route_eye(best_right)
	if best_left == best_right:
		var direction := _best_route_direction(best_left)
		target = eye + Vector3(direction) * 4.5
	return {"position": eye, "target": target}


func _market_route_approach(feature: WarrenFeatureReservation,
		target: Vector3) -> Dictionary:
	var public_set: Dictionary = {}
	for cell: Vector3i in feature.public_cells:
		public_set[cell] = true
	var route_set: Dictionary = {}
	for cell: Vector3i in _spatial.route_floor_cells:
		route_set[cell] = true
	var queue: Array[Vector3i] = []
	var distance_by_cell: Dictionary = {}
	for public_cell: Vector3i in feature.public_cells:
		for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK,
				Vector3i.LEFT, Vector3i.FORWARD]:
			var neighbor := public_cell + direction
			if neighbor.y != public_cell.y or public_set.has(neighbor) \
					or not route_set.has(neighbor) \
					or distance_by_cell.has(neighbor):
				continue
			distance_by_cell[neighbor] = 0
			queue.append(neighbor)
	if queue.is_empty():
		return {}
	var candidates: Array[Vector3i] = []
	while not queue.is_empty():
		var current: Vector3i = queue.pop_front()
		var route_distance := int(distance_by_cell[current])
		if route_distance >= 1:
			candidates.append(current)
		if route_distance >= 12:
			continue
		for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK,
				Vector3i.LEFT, Vector3i.FORWARD]:
			var neighbor := current + direction
			if neighbor.y != current.y or distance_by_cell.has(neighbor) \
					or not route_set.has(neighbor):
				continue
			distance_by_cell[neighbor] = route_distance + 1
			queue.append(neighbor)
	if candidates.is_empty():
		candidates.append_array(distance_by_cell.keys())
	var ignored := [StringName("spatial.fabric.%s" % feature.stable_id)] \
		as Array[StringName]
	var best_eye := _route_eye(candidates[0])
	var best_score := 1 << 30
	for candidate: Vector3i in candidates:
		var candidate_eye := _route_eye(candidate)
		var horizontal_distance := Vector2(candidate_eye.x - target.x,
			candidate_eye.z - target.z).length()
		var score := _view_occlusion_score(candidate_eye, target, ignored) * 100 \
			+ roundi(absf(horizontal_distance - 10.5) * 10.0)
		if score < best_score:
			best_score = score
			best_eye = candidate_eye
	return {"position": best_eye, "target": target}


func _courtyard_views() -> Array[Dictionary]:
	var floors: Array[Vector3i] = []
	for macro: Vector3i in _spatial.source_volume.courtyard_cells:
		floors.append_array(WarrenVolumetricSolver._fine_square(macro))
	if floors.is_empty():
		return [] as Array[Dictionary]
	var centre := _cell_centroid(floors)
	var minimum := floors[0]
	var maximum := floors[0]
	for floor: Vector3i in floors:
		minimum = minimum.min(floor)
		maximum = maximum.max(floor)
	var along_x := maximum.x - minimum.x >= maximum.z - minimum.z
	var eye_cell := Vector3(
		float(minimum.x) if along_x else float(minimum.x + maximum.x) * 0.5,
		float(minimum.y),
		float(minimum.z + maximum.z) * 0.5 if along_x else float(minimum.z))
	var target_cell := Vector3(
		float(maximum.x) if along_x else float(minimum.x + maximum.x) * 0.5,
		float(minimum.y),
		float(minimum.z + maximum.z) * 0.5 if along_x else float(maximum.z))
	var court_eye := eye_cell * FabricRecipe.CELL_SIZE + Vector3.UP * 1.45
	var court_target := target_cell * FabricRecipe.CELL_SIZE \
		+ Vector3.UP * 1.45
	var out: Array[Dictionary] = [
		{"id": "courtyard-eye", "position": court_eye,
			"target": court_target, "fov": 74.0},
		# The court deliberately has route/building mass above it. An exterior
		# top-down camera therefore photographs roofs, not the typed court. Keep
		# this eye inside the court's protected four-cell (6 m) exterior-air shaft
		# and look diagonally down across the full 6 x 6 m floor instead.
		{"id": "courtyard-protected-air", "position": centre \
			+ Vector3(-2.4, 2.6, -2.4), "target": centre \
			+ Vector3(1.2, 1.4, 1.2), "fov": 78.0},
	]
	var floor_columns: Dictionary = {}
	var court_y := floors[0].y
	for cell: Vector3i in floors:
		floor_columns[Vector2i(cell.x, cell.z)] = true
	var lower: Array[Vector3i] = []
	var upper: Array[Vector3i] = []
	for route: Vector3i in _spatial.route_floor_cells:
		if not floor_columns.has(Vector2i(route.x, route.z)):
			continue
		if route.y < court_y:
			lower.append(route)
		elif route.y > court_y:
			upper.append(route)
	if not lower.is_empty():
		lower.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return a.y > b.y)
		var eye := _route_eye(lower[0])
		var direction := _best_route_direction(lower[0])
		out.append({"id": "courtyard-under-route", "position": eye,
			"target": eye + Vector3(direction) * 6.0 \
				+ Vector3.UP * 0.2, "fov": 72.0})
	if not upper.is_empty():
		upper.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return a.y < b.y)
		var eye := _route_eye(upper[0])
		out.append({"id": "courtyard-upper-route", "position": eye,
			"target": centre + Vector3.UP * 1.0, "fov": 68.0})
	return out


func _route_connected_rooftop_court_views() -> Array[Dictionary]:
	## The compact/standard roof court is selected from final room crowns rather
	## than `source_volume.courtyard_cells`, so the legacy courtyard cameras cannot
	## find it. Resolve the exact canonical owner here: these captures must show the
	## generated court and its real route opening, not whichever flat roof happens
	## to be most visible from the campaign camera.
	var floors: Array[Vector3i] = []
	for cell: Vector3i in _spatial.route_floor_cells:
		if _spatial.grid.owner_name_at(cell) == &"public.rooftop_court.00":
			floors.append(cell)
	if floors.is_empty():
		return [] as Array[Dictionary]
	var centre := _cell_centroid(floors)
	var floor_set: Dictionary = {}
	for floor: Vector3i in floors:
		floor_set[floor] = true
	var seam_floor := Vector3i.ZERO
	var seam_route := Vector3i.ZERO
	var has_seam := false
	for floor: Vector3i in floors:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := floor + direction
			if floor_set.has(neighbor) \
					or _spatial.grid.owner_name_at(neighbor) != &"public.route":
				continue
			seam_floor = floor
			seam_route = neighbor
			has_seam = true
			break
		if has_seam:
			break
	var target := centre + Vector3.UP * 0.55
	var overview_eye := _best_orbit_position(target, 13.5, 7.0)
	var out: Array[Dictionary] = [{
		"id": "rooftop-court-overview", "position": overview_eye,
		"target": target, "fov": 56.0,
	}]
	if has_seam:
		var entry_eye := _route_eye(seam_route)
		var inward := Vector3(seam_floor - seam_route).normalized()
		out.append({"id": "rooftop-court-entry", "position": entry_eye,
			"target": entry_eye + inward * 7.5 + Vector3.UP * 0.25,
			"fov": 72.0})
	return out


func _skywalk_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"enclosed_skywalk":
			continue
		var visual_bounds := _feature_visual_bounds(feature)
		var centre := visual_bounds.get_center() if visual_bounds.size.length() \
			> 0.0 else _cell_centroid(feature.reserved_cells)
		var ignored: Array[StringName] = [StringName("spatial.fabric.%s" \
			% feature.stable_id)]
		var orbit_distance := maxf(15.0, maxf(visual_bounds.size.x,
			visual_bounds.size.z) + 10.0)
		var span_eye := _best_orbit_position(centre, orbit_distance, 1.2,
			ignored, visual_bounds)
		var under_view := _public_route_view_below(feature, centre)
		var under_eye := under_view.position as Vector3 \
			if not under_view.is_empty() else _best_orbit_position(
				centre - Vector3.UP, orbit_distance, -2.0, ignored,
				visual_bounds)
		var under_target := under_view.target as Vector3 \
			if not under_view.is_empty() else centre - Vector3.UP
		out.append({"id": "skywalk-%02d-span" % ordinal,
			"position": span_eye,
			"target": centre, "fov": 52.0})
		out.append({"id": "skywalk-%02d-under" % ordinal,
			"position": under_eye,
			"target": under_target, "fov": 66.0})
		var bindings := feature.audit.get("skywalk_endpoint_bindings", []) \
			as Array
		var body_set: Dictionary = {}
		for body_cell: Vector3i in feature.reserved_cells:
			body_set[body_cell] = true
		for endpoint_index in mini(bindings.size(), feature.endpoints.size()):
			var binding := bindings[endpoint_index] as Dictionary
			if StringName(binding.get("endpoint_kind", &"room")) != &"room":
				continue
			var facing := binding.get("facing", Vector3i.ZERO) as Vector3i
			if facing.length_squared() <= 0:
				continue
			var endpoint_cell := (feature.endpoints[endpoint_index] \
				as Dictionary).cell as Vector3i
			var seam_target := Vector3(endpoint_cell) * FabricRecipe.CELL_SIZE \
				+ Vector3.UP * 1.4
			# Graph adjacency is already sealed by the feature reservation. Review the
			# architectural joint from outside instead: an eye inside this narrow
			# occupied bridge collides with a wall module and produces an unusable
			# close-up. Two opposing obliques expose the door sill, the first bridge
			# floor, and both side-wall returns in one image.
			if not body_set.has(endpoint_cell + facing):
				continue
			var outward := Vector3(facing).normalized()
			var tangent := Vector3(-outward.z, 0.0, outward.x)
			for side in [-1, 1]:
				var seam_eye := seam_target + outward * 9.0 \
					+ tangent * float(side) * 7.5 + Vector3.UP * 5.0
				out.append({"id": "skywalk-%02d-endpoint-%d-%s" % [ordinal,
					endpoint_index, "left" if side < 0 else "right"],
					"position": seam_eye,
					"target": seam_target + outward * 0.45 \
						- Vector3.UP * 0.20, "fov": 46.0})
		ordinal += 1
	return out


func _residual_jetty_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"frontier_gateway_support" \
				or not bool(feature.audit.get("gateway_is_flank_borne", false)):
			continue
		var bounds := _feature_visual_bounds(feature)
		var centre := _cell_centroid(feature.reserved_cells)
		if bounds.size.length_squared() > 0.0:
			centre = bounds.get_center() + Vector3.UP * 1.4
		var ignored := [StringName("spatial.fabric.%s" % feature.stable_id)] \
			as Array[StringName]
		out.append({"id": "residual-jetty-%02d-oblique" % ordinal,
			"position": _best_orbit_position(centre, 12.0, 2.5, ignored,
				bounds), "target": centre, "fov": 58.0})
		out.append({"id": "residual-jetty-%02d-underside" % ordinal,
			"position": _best_orbit_position(centre - Vector3.UP * 2.0,
				8.0, -1.5, ignored, bounds),
			"target": centre - Vector3.UP * 1.5, "fov": 64.0})
		ordinal += 1
	return out


func _arcade_overhang_views() -> Array[Dictionary]:
	## Review the actual load path rather than the room crown.  The front camera
	## stands beyond the unsupported half of the upper plate and looks through
	## its stone portal; the oblique camera exposes both the portal, the soffit,
	## and the tower half carrying the opposite end.
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"arcade_overhang_support":
			continue
		var bounds := _feature_visual_bounds(feature)
		var centre := bounds.get_center() if bounds.size.length_squared() > 0.0 \
			else _cell_centroid(feature.reserved_cells)
		var direction_2d := feature.audit.get(
			"arcade_projection_direction", Vector2i.ZERO) as Vector2i
		var outward := Vector3(direction_2d.x, 0.0, direction_2d.y)
		if outward.length_squared() <= 0.0:
			outward = Vector3.BACK
		var across := Vector3(-outward.z, 0.0, outward.x)
		var ignored := [StringName("spatial.fabric.%s" % feature.stable_id)] \
			as Array[StringName]
		var front_target := centre + Vector3.UP * 0.35
		var front_eye := _best_directional_position(front_target, outward,
			10.5, 1.6, ignored, bounds)
		var oblique_preferred := (outward + across * 0.85).normalized()
		var oblique_target := centre + Vector3.UP * 1.25
		var oblique_eye := _best_directional_position(oblique_target,
			oblique_preferred, 10.5, 2.8, ignored, bounds)
		out.append({"id": "arcade-overhang-%02d-front" % ordinal,
			"position": front_eye, "target": front_target, "fov": 58.0})
		out.append({"id": "arcade-overhang-%02d-oblique" % ordinal,
			"position": oblique_eye, "target": oblique_target, "fov": 58.0})
		ordinal += 1
	return out


func _room_overhang_support_views() -> Array[Dictionary]:
	## A room-scale jetty is only successful when the visual support reads as a
	## load path between the projecting floor and the parent facade. Photograph
	## every retained course from below and obliquely from its projection side;
	## overviews routinely turn an attached diagonal into an unexplained hanging
	## pole and cannot falsify either endpoint.
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"room_overhang_support":
			continue
		var bounds := _feature_visual_bounds(feature)
		var centre := bounds.get_center() if bounds.size.length_squared() > 0.0 \
			else _cell_centroid(feature.reserved_cells)
		var direction_2d := feature.audit.get(
			"overhang_projection_direction", Vector2i.ZERO) as Vector2i
		var outward := Vector3(direction_2d.x, 0.0, direction_2d.y)
		if outward.length_squared() <= 0.0:
			outward = Vector3.BACK
		outward = outward.normalized()
		var across := Vector3(-outward.z, 0.0, outward.x)
		var ignored := [StringName("spatial.fabric.%s" % feature.stable_id)] \
			as Array[StringName]
		var underside_target := centre - Vector3.UP \
			* maxf(0.9, bounds.size.y * 0.22)
		var underside_eye := _best_directional_position(underside_target,
			outward, 7.5, -1.5, ignored, bounds)
		var oblique_target := centre + Vector3.UP * 0.15
		var oblique_eye := _best_directional_position(oblique_target,
			(outward + across * 0.72).normalized(), 10.0, 2.2, ignored,
			bounds)
		out.append({"id": "room-overhang-%02d-underside" % ordinal,
			"position": underside_eye, "target": underside_target,
			"fov": 60.0})
		out.append({"id": "room-overhang-%02d-oblique" % ordinal,
			"position": oblique_eye, "target": oblique_target,
			"fov": 56.0})
		ordinal += 1
	return out


func _addressed_door_views() -> Array[Dictionary]:
	## Every source threshold becomes an adversarial close-up.  The camera stands
	## on the route-facing side, so a shifted facade aperture, absent platform,
	## or guard crossing the doorway is visible rather than hidden by an overview.
	var out: Array[Dictionary] = []
	var rooms: Array[WarrenRoomStamp] = []
	for building: WarrenBuildingVolume in _spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.addressed:
				rooms.append(room)
	rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	for ordinal in rooms.size():
		var room := rooms[ordinal]
		var threshold := Vector3(room.threshold_cell) * FabricRecipe.CELL_SIZE
		var target := threshold + Vector3.UP * 1.05
		var outward := Vector3(room.frontage_direction)
		var unit_id := StringName("spatial.fabric.%s" % room.stable_id)
		var own_bounds := _unit_visual_bounds(unit_id)
		# A threshold close-up must show the landing and its approach. Standing on
		# the landing-cell centre regularly put the camera inside a guard, stair,
		# or facade trim—the exact geometry this view is meant to judge. Search a
		# narrow outward cone instead, at several pedestrian-scale distances and
		# heights, while still refusing to look around a different facade.
		var threshold_directions: Array[Vector3] = [outward,
			outward.rotated(Vector3.UP, PI / 12.0),
			outward.rotated(Vector3.UP, -PI / 12.0),
			outward.rotated(Vector3.UP, PI / 6.0),
			outward.rotated(Vector3.UP, -PI / 6.0)]
		var landing_eye := target + outward * 3.0 + Vector3.UP * 0.65
		var landing_score := 1 << 30
		for direction: Vector3 in threshold_directions:
			for distance: float in [2.6, 3.8, 5.0]:
				for height: float in [0.45, 1.15, 1.85]:
					var candidate := target + direction * distance \
						+ Vector3.UP * height
					var score := _view_occlusion_score(candidate, target,
						[unit_id] as Array[StringName])
					if own_bounds.grow(0.25).has_point(candidate):
						score += 1000
					if score < landing_score:
						landing_score = score
						landing_eye = candidate
		out.append({"id": "door-%02d-phase-%d-threshold" % [ordinal,
			room.address_door_phase], "position": landing_eye,
			"target": target, "fov": 68.0})
		# The context view may dodge a neighboring facade by thirty degrees, but it
		# must never rotate to a different wall. That keeps the intended doorway and
		# its landing legible together while still working inside a narrow canyon.
		var directions: Array[Vector3] = [outward,
			outward.rotated(Vector3.UP, PI / 6.0),
			outward.rotated(Vector3.UP, -PI / 6.0)]
		var context_eye := target + outward * 5.5 + Vector3.UP * 2.5
		var best_score := 1 << 30
		for direction: Vector3 in directions:
			var candidate := target + direction * 5.5 + Vector3.UP * 2.5
			var score := _view_occlusion_score(candidate, target,
				[unit_id] as Array[StringName])
			if score < best_score:
				best_score = score
				context_eye = candidate
		out.append({"id": "door-%02d-phase-%d-context" % [ordinal,
			room.address_door_phase], "position": context_eye,
			"target": target, "fov": 58.0})
	return out


func _terrain_foundation_views() -> Array[Dictionary]:
	## One independently selected camera in each compass quadrant exposes every
	## side and the ground seam.  Constraining each search to its quadrant prevents
	## the least-occluded selector from returning the same attractive facade four
	## times, while the small angle/distance/height search keeps dense neighboring
	## roofs from completely masking a required stone course.
	var out: Array[Dictionary] = []
	var rooms: Array[WarrenRoomStamp] = []
	for building: WarrenBuildingVolume in _spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.terrain_bearing:
				rooms.append(room)
	rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	for ordinal in rooms.size():
		var room := rooms[ordinal]
		var foundation_kind := "retained" \
			if _room_has_retained_foundation(room) else "flush"
		var unit_id := StringName("spatial.fabric.%s" % room.stable_id)
		var unit := _fabric.unit(unit_id)
		if unit == null:
			continue
		var room_base_y := float(room.lattice_origin.y) \
			* FabricRecipe.CELL_SIZE
		# Retained courses live below the room floor. Aiming at the room wall made
		# the camera selection prefer pretty facades while leaving the actual
		# ground seam off-screen. Flush foundations remain just above floor level.
		var target_y := room_base_y - 0.70 \
			if foundation_kind == "retained" else room_base_y + 0.45
		var target := Vector3(unit.bounds.get_center().x, target_y,
			unit.bounds.get_center().z)
		var own_bounds := _unit_visual_bounds(unit_id)
		for view: Dictionary in [
			{"id": "se", "direction": Vector3(1.0, 0.0, 1.0).normalized()},
			{"id": "sw", "direction": Vector3(-1.0, 0.0, 1.0).normalized()},
			{"id": "nw", "direction": Vector3(-1.0, 0.0, -1.0).normalized()},
			{"id": "ne", "direction": Vector3(1.0, 0.0, -1.0).normalized()},
		]:
			var quadrant := view.direction as Vector3
			var eye := target + quadrant * 10.5 + Vector3.UP * 2.0
			var best_score := 1 << 30
			for angle: float in [-PI / 4.0, -PI / 8.0, 0.0,
					PI / 8.0, PI / 4.0]:
				var direction := quadrant.rotated(Vector3.UP, angle).normalized()
				for distance: float in [10.5, 14.0, 18.0, 22.0]:
					for height: float in [2.0, 4.0, 6.0]:
						var candidate := target + direction * distance \
							+ Vector3.UP * height
						var score := _view_occlusion_score(candidate, target,
							[unit_id] as Array[StringName])
						if own_bounds.grow(0.25).has_point(candidate):
							score += 1000
						if score < best_score:
							best_score = score
							eye = candidate
			out.append({"id": "foundation-%s-%02d-%s" % [foundation_kind,
				ordinal, String(view.id)], "position": eye,
				"target": target, "fov": 58.0})
	return out


func _room_has_retained_foundation(room: WarrenRoomStamp) -> bool:
	if room == null or not room.terrain_bearing \
			or _spatial.source_volume == null:
		return false
	for cell: Vector3i in room.private_cells:
		if cell.y != room.lattice_origin.y:
			continue
		var macro := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if _spatial.source_volume.envelope.bearing_at(macro) \
				< room.lattice_origin.y:
			return true
	return false


func _interstitial_gap_views() -> Array[Dictionary]:
	## Photograph every final sub-tolerance building slot as its own review
	## obligation. Grouping by the two exact owners avoids one duplicate camera per
	## fine cell while retaining deterministic ids for before/after recaptures.
	var groups: Dictionary = {}
	for detail_value: Variant in _spatial.audit.get(
			"one_cell_interstitial_gap_details", []) as Array:
		var detail := detail_value as Dictionary
		var key := "%s/%s/%s" % [String(detail.negative_owner),
			String(detail.positive_owner), String(detail.axis)]
		if not groups.has(key):
			groups[key] = {"axis": StringName(detail.axis),
				"cells": [] as Array[Vector3i]}
		(groups[key].cells as Array[Vector3i]).append(detail.cell as Vector3i)
	var keys := PackedStringArray(groups.keys())
	keys.sort()
	var out: Array[Dictionary] = []
	for ordinal in keys.size():
		var group := groups[keys[ordinal]] as Dictionary
		var cells := group.cells as Array[Vector3i]
		cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return _cell_key(a) < _cell_key(b))
		var centre := _cell_centroid(cells) + Vector3.UP * 0.75
		var across := Vector3.RIGHT if StringName(group.axis) == &"x" \
			else Vector3.BACK
		var along := Vector3(-across.z, 0.0, across.x)
		out.append({"id": "gap-%02d-oblique" % ordinal,
			"position": centre + along * 6.0 + across * 3.0 \
				+ Vector3.UP * 5.0,
			"target": centre, "fov": 48.0})
		out.append({"id": "gap-%02d-profile" % ordinal,
			"position": centre + along * 7.0 + Vector3.UP * 0.8,
			"target": centre, "fov": 52.0})
	return out


func _tower_annex_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind not in [&"tower_annex", &"facade_bay"] \
				or feature.construction_records.size() != 1:
			continue
		var record := feature.construction_records[0]
		var centre := _cell_centroid(feature.reserved_cells)
		var outward := Vector3(feature.audit.get("annex_endpoint_facing",
			FabricRecipe.transform_direction(Vector3i.BACK,
				int(record.yaw_quarters))))
		var token := "tower-annex" if feature.kind == &"tower_annex" \
			else "facade-bay"
		var bounds := _feature_visual_bounds(feature)
		var target := bounds.get_center() if bounds.size.length_squared() > 0.0 \
			else centre + Vector3.UP * 1.5
		var ignored := [StringName("spatial.fabric.%s" % feature.stable_id)] \
			as Array[StringName]
		var preferred := outward
		if feature.kind == &"tower_annex":
			# A corner-wrap bump-out is a diagonal union of two full-scale room
			# plates. Photograph it from outside both exposed faces; a normal-only
			# facade view hid the shared quadrant behind one cheek and made the
			# feature read like a straight box pasted onto the wall.
			var hand := -1.0 if ".left." in String(record.recipe_id) else 1.0
			var side := Vector3(-outward.z, 0.0, outward.x) * hand
			preferred = (outward + side).normalized()
		# The 1.5 m embedded oriel was unreadably small in the same ten-metre
		# composition used for the room-scale union.  Keep the annex contextual,
		# but move the bay camera close enough to expose the parent wall crossing.
		var distance := maxf(10.0, maxf(bounds.size.x, bounds.size.z) + 6.0) \
			if feature.kind == &"tower_annex" else 5.5
		var eye := _best_directional_position(target, preferred, distance,
			3.0 if feature.kind == &"tower_annex" else 0.9, ignored, bounds)
		out.append({"id": "%s-%02d-oblique" % [token, ordinal],
			"position": eye, "target": target,
			"fov": 54.0 if feature.kind == &"tower_annex" else 46.0})
		if feature.kind == &"facade_bay":
			# The oblique view proves the projection and return cheeks, but can hide
			# the window face behind either cheek on a 1.5 m bay. Keep a true
			# facade-normal capture as a separate obligation so a bay made from
			# open framing or an accidentally recessed face cannot pass review.
			var front_eye := _best_directional_position(target, outward, 4.8,
				0.45, ignored, bounds)
			out.append({"id": "%s-%02d-front" % [token, ordinal],
				"position": front_eye, "target": target,
				"fov": 42.0})
		ordinal += 1
	return out


func _interstitial_join_views() -> Array[Dictionary]:
	## Photograph every typed interstitial join along its open reveal so review
	## can falsify that the slot reads as an intentional stepped or sealed
	## course, not a thin patch hiding an opening between two facades.
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"interstitial_join":
			continue
		if feature.reserved_cells.is_empty():
			continue
		var centre := _cell_centroid(feature.reserved_cells)
		var trap_axis := StringName(feature.audit.get(
			"interstitial_trap_axis", &"x"))
		var run_direction := Vector3(0, 0, 1) if trap_axis == &"x" \
			else Vector3(1, 0, 0)
		for side_index in 2:
			var run_sign := 1.0 if side_index == 0 else -1.0
			var eye := centre + run_direction * run_sign * 9.0 \
				+ Vector3.UP * 3.0
			out.append({"id": "interstitial-join-%02d-%s" % [ordinal,
				"a" if side_index == 0 else "b"],
				"position": eye, "target": centre, "fov": 50.0})
		ordinal += 1
	return out


func _room_outcropping_views() -> Array[Dictionary]:
	## These are not attached facade props: each reservation names a complete
	## inhabited upper WarrenRoomStamp whose floorplate leaves the room below.
	## Photograph the exposed displacement side and its underside so review can
	## falsify whether the volumetric recomposition actually reads as a room-scale
	## projection in the assembled town.
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"room_outcropping":
			continue
		var upper := _room_by_id(StringName(
			feature.audit.outcrop_upper_room_id))
		var lower := _room_by_id(StringName(
			feature.audit.outcrop_lower_room_id))
		if upper == null or lower == null:
			continue
		var upper_bounds := _unit_visual_bounds(StringName(
			"spatial.fabric.%s" % upper.stable_id))
		if upper_bounds.size.length_squared() <= 0.0:
			continue
		var upper_centre := upper_bounds.get_center()
		var lower_centre := _cell_centroid(lower.private_cells)
		var offset := upper_centre - lower_centre
		offset.y = 0.0
		if offset.length_squared() <= 0.01:
			continue
		var outward := offset.normalized()
		var distance := maxf(10.0, maxf(upper_bounds.size.x,
			upper_bounds.size.z) + 7.0)
		var ignored: Array[StringName] = [StringName(
			"spatial.fabric.%s" % upper.stable_id)]
		var front_eye := _best_directional_position(upper_centre, outward,
			distance, 2.0, ignored, upper_bounds)
		var underside_target := Vector3(upper_centre.x,
			upper_bounds.position.y + 0.35, upper_centre.z)
		var underside_eye := _best_directional_position(underside_target,
			outward, distance * 0.8, -1.0, ignored, upper_bounds)
		out.append({"id": "room-outcrop-%02d-front" % ordinal,
			"position": front_eye, "target": upper_centre,
			"fov": 52.0})
		out.append({"id": "room-outcrop-%02d-under" % ordinal,
			"position": underside_eye, "target": underside_target,
			"fov": 58.0})
		ordinal += 1
	return out


func _balcony_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"balcony" or feature.construction_records.size() != 1:
			continue
		var record := feature.construction_records[0]
		var yaw := int(record.yaw_quarters)
		var outward3 := FabricRecipe.transform_direction(Vector3i.BACK, yaw)
		var outward := Vector3(outward3)
		var wraparound := bool(feature.audit.get("balcony_wraparound", false))
		var recipe_text := String(feature.audit.get("balcony_recipe_id", ""))
		var hand := -1.0 if recipe_text.contains(".left.") else 1.0
		var tangent := Vector3(-outward3.z, 0.0, outward3.x) * hand
		var target := Vector3((feature.endpoints[0] as Dictionary).cell \
			as Vector3i) * FabricRecipe.CELL_SIZE + Vector3.UP * 1.35
		var bounds := _feature_visual_bounds(feature)
		var feature_prefix := StringName("spatial.fabric.%s" % feature.stable_id)
		var room_prefix := StringName("spatial.fabric.%s" % StringName(
			feature.audit.get("balcony_room_id", &"")))
		var ignored := [feature_prefix, room_prefix] as Array[StringName]
		var view_direction := (outward + tangent * 0.72).normalized() \
			if wraparound else outward
		var front_eye := _best_directional_position(target, view_direction, 6.0,
			0.8,
			ignored, bounds)
		var under_eye := _best_directional_position(target - Vector3.UP * 0.7,
			outward, 5.0, -1.0, ignored, bounds)
		var token := "-wrap" if wraparound else ""
		out.append({"id": "balcony-%02d%s-front" % [ordinal, token],
			"position": front_eye,
			"target": target, "fov": 56.0})
		var door_axis_eye := target + outward * 7.5 + Vector3.UP * 0.45
		out.append({"id": "balcony-%02d%s-door-axis" % [ordinal, token],
			"position": door_axis_eye,
			"target": target + Vector3.UP * 0.15, "fov": 48.0})
		out.append({"id": "balcony-%02d%s-underside" % [ordinal, token],
			"position": under_eye,
			"target": target + Vector3.UP * -0.4, "fov": 58.0})
		var stair_high_cells: Array[Vector3i] = []
		for raw_cell: Variant in feature.audit.get(
				"balcony_stair_high_landing_cells", []):
			stair_high_cells.append(raw_cell as Vector3i)
		var stair_low_cells: Array[Vector3i] = []
		for raw_cell: Variant in feature.audit.get(
				"balcony_stair_low_landing_cells", []):
			stair_low_cells.append(raw_cell as Vector3i)
		if not stair_high_cells.is_empty() and not stair_low_cells.is_empty():
			var stair_high := _cell_centroid(stair_high_cells)
			var stair_low := _cell_centroid(stair_low_cells)
			var circulation := stair_high - stair_low
			circulation.y = 0.0
			if circulation.length_squared() > 0.01:
				circulation = circulation.normalized()
				var circulation_target := stair_high + Vector3.UP * 0.9
				var entry_eye := stair_low - circulation * 3.25 \
					+ Vector3.UP * 2.0
				out.append({"id": "balcony-%02d%s-stair-entry" % [
						ordinal, token], "position": entry_eye,
					"target": circulation_target, "fov": 54.0})
				var profile_direction := Vector3(-circulation.z, 0.0,
					circulation.x)
				var profile_target := (stair_low + stair_high) * 0.5 \
					+ Vector3.UP * 0.65
				var profile_eye := profile_target + profile_direction * 6.0 \
					+ Vector3.UP * 1.1
				out.append({"id": "balcony-%02d%s-stair-profile" % [
						ordinal, token], "position": profile_eye,
					"target": profile_target, "fov": 52.0})
				var top_eye := bounds.get_center() + outward * 1.5 \
					+ Vector3.UP * 11.0
				out.append({"id": "balcony-%02d%s-circulation-top" % [
						ordinal, token], "position": top_eye,
					"target": bounds.get_center(), "fov": 48.0})
		ordinal += 1
	return out


func _landmark_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"prefab_landmark" \
				or feature.construction_records.size() != 1:
			continue
		var record := feature.construction_records[0]
		var origin := record.origin as Vector3i
		var entrance := feature.audit.landmark_entrance_cell as Vector3i
		var landing := feature.audit.landmark_public_landing_cell as Vector3i
		var outward3 := landing - entrance
		var outward := Vector3(outward3)
		var side := Vector3(-outward3.z, 0.0, outward3.x)
		var bounds := _feature_visual_bounds(feature)
		var height_m := float(feature.audit.landmark_height_cell_count) \
			* FabricRecipe.CELL_SIZE
		var target := bounds.get_center() if bounds.size.length_squared() > 0.0 \
			else Vector3(origin) * FabricRecipe.CELL_SIZE \
				+ Vector3.UP * height_m * 0.48
		var distance := maxf(18.0, maxf(bounds.size.x, bounds.size.z) + 8.0)
		var ignored := [StringName("spatial.fabric.%s" % feature.stable_id)] \
			as Array[StringName]
		var front_eye := _best_directional_position(target, outward, distance,
			2.5, ignored, bounds)
		var side_eye := _best_directional_position(target,
			(outward + side).normalized(), distance, 3.5, ignored, bounds)
		out.append({"id": "landmark-%02d-front" % ordinal,
			"position": front_eye,
			"target": target, "fov": 56.0})
		out.append({"id": "landmark-%02d-side" % ordinal,
			"position": side_eye,
			"target": target + Vector3.UP * 1.0, "fov": 58.0})
		for skywalk: WarrenFeatureReservation in _spatial.features:
			if skywalk.kind != &"enclosed_skywalk":
				continue
			for endpoint: Dictionary in skywalk.endpoints:
				if StringName(endpoint.owner_id) != feature.stable_id:
					continue
				var socket_target := Vector3(endpoint.cell as Vector3i) \
					* FabricRecipe.CELL_SIZE + Vector3.UP * 1.5
				out.append({"id": "landmark-%02d-skywalk-seam" % ordinal,
					"position": socket_target + side * 8.0 \
						+ outward * 5.0 + Vector3.UP * 2.0,
					"target": socket_target, "fov": 55.0})
		ordinal += 1
	return out


func _fabric_bounds() -> AABB:
	var out := AABB()
	var initialized := false
	for bounds: AABB in _fabric.transformed_visual_clearance_bounds():
		out = bounds if not initialized else out.merge(bounds)
		initialized = true
	return out


func _edge_nick_views() -> Array[Dictionary]:
	## Put a falsification camera directly on every overlap admitted only by the
	## review-only edge switch. These captures decide whether the generator needs
	## a different room placement, an authored joint, or a narrower module.
	var out: Array[Dictionary] = []
	for left_index in _fabric.units.size():
		var left := _fabric.units[left_index]
		var left_recipe := _fabric.recipe(left.recipe_id)
		if left_recipe == null or left_recipe.placements.is_empty():
			continue
		var left_bounds := left.transform() * left_recipe.local_clearance_bounds
		for right_index in range(left_index + 1, _fabric.units.size()):
			var right := _fabric.units[right_index]
			var right_recipe := _fabric.recipe(right.recipe_id)
			if right_recipe == null or right_recipe.placements.is_empty() \
					or _fabric._units_declare_connection(left, right):
				continue
			var right_bounds := right.transform() \
				* right_recipe.local_clearance_bounds
			if not SettlementFabricPlan._aabb_overlaps_volume(left_bounds,
					right_bounds) or not SettlementFabricPlan._is_edge_nick(
						left_bounds, right_bounds):
				continue
			var overlap_min := left_bounds.position.max(right_bounds.position)
			var overlap_max := left_bounds.end.min(right_bounds.end)
			var target := (overlap_min + overlap_max) * 0.5
			var ignored := [left.stable_id, right.stable_id] as Array[StringName]
			var union_bounds := left_bounds.merge(right_bounds)
			var eye := _best_orbit_position(target, 8.0, 1.5, ignored,
				union_bounds)
			out.append({"id": "edge-nick-%02d" % out.size(),
				"position": eye, "target": target, "fov": 54.0})
			print("[warren_spatial_review] edge nick ", left.stable_id,
				" <-> ", right.stable_id, " overlap=", overlap_max - overlap_min)
			if out.size() >= 6:
				return out
	return out


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("527faf")
	sky_material.sky_horizon_color = Color("c5dce0")
	sky_material.ground_bottom_color = Color("596152")
	sky_material.ground_horizon_color = Color("aebd9f")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -37.0, 0.0)
	sun.light_color = Color("ffe4b9")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("718d50")
	material.roughness = 1.0
	if _spatial == null or _spatial.source_volume == null \
			or _spatial.source_volume.envelope == null:
		var fallback := MeshInstance3D.new()
		var fallback_mesh := BoxMesh.new()
		fallback_mesh.size = Vector3(120.0, 0.4, 120.0)
		fallback.mesh = fallback_mesh
		fallback.position = Vector3(0.0, -0.2, 0.0)
		fallback.material_override = material
		add_child(fallback)
		return
	# The town is terrain-relative. A single y=0 review plane made correctly
	# terrain-rooted edge houses appear to hover on posts whenever their natural
	# ground band was higher. Render the sealed envelope's own stepped datum as
	# deep terrain columns so visual support review matches production rather than
	# showing thin green slabs floating below otherwise valid foundations.
	var envelope := _spatial.source_volume.envelope
	var review_columns: Dictionary = {}
	for column_value: Variant in envelope.height_bands.keys():
		var envelope_column := column_value as Vector2i
		review_columns[envelope_column] = float(
			envelope.ground_at(envelope_column)) * FabricRecipe.CELL_SIZE
	# A complete prefab may stand just beyond the authored massif while still
	# bearing on immutable natural terrain. The old review surface stopped at the
	# massif dictionary and therefore falsified those valid foundations as houses
	# floating over the void. Extend only the exact sealed bearing columns; this
	# cannot conceal a genuinely unsupported footprint.
	for feature: WarrenFeatureReservation in _spatial.features:
		for bearing_cell: Vector3i in feature.terrain_bearing_cells:
			var bearing_column := Vector2i(floori(float(bearing_cell.x) / 2.0),
				floori(float(bearing_cell.z) / 2.0))
			review_columns[bearing_column] = float(bearing_cell.y) \
				* FabricRecipe.CELL_SIZE
	for column_value: Variant in review_columns.keys():
		var column := column_value as Vector2i
		var top := float(review_columns[column])
		var instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		const REVIEW_GROUND_DEPTH_M := 30.0
		mesh.size = Vector3(WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M,
			REVIEW_GROUND_DEPTH_M,
			WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M)
		instance.mesh = mesh
		# The envelope key identifies the first of two 1.5 m fine cells, so the
		# rendered 3 m column centre is half a fine cell beyond that key.
		instance.position = Vector3(float(column.x) \
			* WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M \
			+ FabricRecipe.CELL_SIZE * 0.5,
			top - REVIEW_GROUND_DEPTH_M * 0.5, float(column.y) \
			* WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M \
			+ FabricRecipe.CELL_SIZE * 0.5)
		instance.material_override = material
		add_child(instance)


func _write_manifest() -> void:
	var path := "%s/index.json" % _output_dir
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"world_seed": _world_seed,
		"diagnostic_allow_edge_envelope_overlap":
			SettlementFabricPlan.DIAGNOSTIC_ALLOW_EDGE_ENVELOPE_OVERLAP,
		"spatial_signature": _spatial.deterministic_signature().sha256_text(),
		"audit": _spatial.audit, "fabric_audit": _fabric.audit,
		"captures": _captures}, "  "))


func _best_route_direction(cell: Vector3i) -> Vector3i:
	var route_set: Dictionary = {}
	for route: Vector3i in _spatial.route_floor_cells:
		route_set[route] = true
	var best := Vector3i.RIGHT
	var best_length := 0
	for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK,
			Vector3i.LEFT, Vector3i.FORWARD]:
		var length := 0
		for step in range(1, 7):
			if not route_set.has(cell + direction * step):
				break
			length += 1
		if length > best_length:
			best = direction
			best_length = length
	return best


func _public_route_view_below(feature: WarrenFeatureReservation,
		feature_centre: Vector3) -> Dictionary:
	## An occupied bridge-house is meaningful because a player traverses the
	## negative-space street beneath it. Put the underside camera on that exact
	## canonical route rather than on an arbitrary low orbit that can land inside
	## neighboring mass.
	if feature.reserved_cells.is_empty():
		return {}
	var columns: Dictionary = {}
	var minimum_feature_y := feature.reserved_cells[0].y
	for cell: Vector3i in feature.reserved_cells:
		columns[Vector2i(cell.x, cell.z)] = true
		minimum_feature_y = mini(minimum_feature_y, cell.y)
	var best := Vector3i(2147483647, 2147483647, 2147483647)
	var best_score := 1 << 30
	for route: Vector3i in _spatial.route_floor_cells:
		if not columns.has(Vector2i(route.x, route.z)) \
				or route.y + 2 > minimum_feature_y:
			continue
		var world := Vector3(route) * FabricRecipe.CELL_SIZE
		var score := roundi(Vector2(world.x - feature_centre.x,
			world.z - feature_centre.z).length() * 10.0) \
			+ (minimum_feature_y - route.y) * 3
		if score < best_score:
			best = route
			best_score = score
	if best.x == 2147483647:
		return {}
	var route_set: Dictionary = {}
	for route: Vector3i in _spatial.route_floor_cells:
		route_set[route] = true
	var target_y := float(minimum_feature_y) * FabricRecipe.CELL_SIZE + 1.0
	var target := Vector3(feature_centre.x, target_y, feature_centre.z)
	# Walk the connected same-level public route away from the exact bridge
	# column. Looking obliquely back from 6--9 m shows both the street canyon and
	# its occupied ceiling; a camera directly below can only photograph a flat
	# black soffit. The search is deliberately small and deterministic.
	var queue: Array[Vector3i] = [best]
	var distance_by_cell: Dictionary = {best: 0}
	var candidates: Array[Vector3i] = []
	while not queue.is_empty():
		var current: Vector3i = queue.pop_front()
		var route_distance := int(distance_by_cell[current])
		if route_distance >= 2:
			candidates.append(current)
		if route_distance >= 10:
			continue
		for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK,
				Vector3i.LEFT, Vector3i.FORWARD]:
			var neighbor: Vector3i = current + direction
			if neighbor.y != best.y or distance_by_cell.has(neighbor) \
					or not route_set.has(neighbor):
				continue
			distance_by_cell[neighbor] = route_distance + 1
			queue.append(neighbor)
	if candidates.is_empty():
		candidates.append(best)
	var feature_prefix := StringName("spatial.fabric.%s" % feature.stable_id)
	var eye_cell := candidates[0]
	var eye_position := _route_eye(eye_cell)
	var best_view_score := 1 << 30
	for candidate: Vector3i in candidates:
		var candidate_eye := _route_eye(candidate)
		var horizontal_distance := Vector2(candidate_eye.x - target.x,
			candidate_eye.z - target.z).length()
		var candidate_score := _view_occlusion_score(candidate_eye, target,
			[feature_prefix] as Array[StringName]) * 100 \
			+ roundi(absf(horizontal_distance - 13.5) * 10.0)
		if columns.has(Vector2i(candidate.x, candidate.z)):
			candidate_score += 500
		if candidate_score < best_view_score:
			best_view_score = candidate_score
			eye_cell = candidate
			eye_position = candidate_eye
	return {"position": eye_position, "target": target}


func _feature_visual_bounds(feature: WarrenFeatureReservation) -> AABB:
	var prefix := "spatial.fabric.%s" % feature.stable_id
	var bounds := AABB()
	var has_bounds := false
	for unit: FabricUnit in _fabric.units:
		if not String(unit.stable_id).begins_with(prefix):
			continue
		var recipe := _fabric.recipe(unit.recipe_id)
		if recipe == null or recipe.placements.is_empty():
			continue
		var unit_bounds := unit.transform() * recipe.local_clearance_bounds
		bounds = bounds.merge(unit_bounds) if has_bounds else unit_bounds
		has_bounds = true
	return bounds


func _unit_visual_bounds(stable_id: StringName) -> AABB:
	for unit: FabricUnit in _fabric.units:
		if unit.stable_id != stable_id:
			continue
		var recipe := _fabric.recipe(unit.recipe_id)
		if recipe != null and not recipe.placements.is_empty():
			return unit.transform() * recipe.local_clearance_bounds
	return AABB()


func _room_by_id(stable_id: StringName) -> WarrenRoomStamp:
	for building: WarrenBuildingVolume in _spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.stable_id == stable_id:
				return room
	return null


func _best_directional_position(target: Vector3, preferred: Vector3,
		distance: float, height: float,
		ignored_prefixes: Array[StringName], own_bounds: AABB) -> Vector3:
	var directions: Array[Vector3] = [
		preferred.normalized(),
		preferred.rotated(Vector3.UP, PI * 0.25).normalized(),
		preferred.rotated(Vector3.UP, -PI * 0.25).normalized(),
		preferred.rotated(Vector3.UP, PI * 0.5).normalized(),
		preferred.rotated(Vector3.UP, -PI * 0.5).normalized(),
	]
	var distance_scales: Array[float] = [1.0, 1.35]
	var best := target + directions[0] * distance + Vector3.UP * height
	var best_score := 1 << 30
	for distance_scale: float in distance_scales:
		for direction: Vector3 in directions:
			var candidate: Vector3 = target \
				+ direction * distance * distance_scale \
				+ Vector3.UP * height
			var score := _view_occlusion_score(candidate, target,
				ignored_prefixes)
			if own_bounds.grow(0.25).has_point(candidate):
				score += 1000
			if score < best_score:
				best = candidate
				best_score = score
	return best


func _best_orbit_position(target: Vector3, distance: float, height: float,
		ignored_prefixes: Array[StringName] = [], own_bounds := AABB()) -> Vector3:
	## Pick the least-occluded of eight deterministic orbit positions against the
	## same measured envelopes that gate construction. This is not image scoring;
	## it only prevents a review camera from spawning inside an unrelated house or
	## aiming through several buildings before reaching its requested feature.
	var directions: Array[Vector3] = [
		Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD,
		(Vector3.RIGHT + Vector3.BACK).normalized(),
		(Vector3.LEFT + Vector3.BACK).normalized(),
		(Vector3.LEFT + Vector3.FORWARD).normalized(),
		(Vector3.RIGHT + Vector3.FORWARD).normalized(),
	]
	var distance_scales: Array[float] = [1.0, 1.35]
	var best := target + directions[0] * distance + Vector3.UP * height
	var best_score := 1 << 30
	for distance_scale: float in distance_scales:
		for direction: Vector3 in directions:
			var candidate: Vector3 = target \
				+ direction * distance * distance_scale \
				+ Vector3.UP * height
			var score := _view_occlusion_score(candidate, target,
				ignored_prefixes)
			if own_bounds.size.length_squared() > 0.0 \
					and own_bounds.grow(0.25).has_point(candidate):
				score += 1000
			if score < best_score:
				best = candidate
				best_score = score
	return best


func _view_occlusion_score(position: Vector3, target: Vector3,
		ignored_prefixes: Array[StringName]) -> int:
	var score := 0
	for sample_index in 24:
		# Stop short of the target because the feature being photographed may join
		# an endpoint room there. The ignored feature prefix handles its own shell.
		var weight := 100 if sample_index == 0 else 1
		var point := position.lerp(target, float(sample_index) / 26.0)
		for unit: FabricUnit in _fabric.units:
			var ignored := false
			for prefix: StringName in ignored_prefixes:
				if String(unit.stable_id).begins_with(String(prefix)):
					ignored = true
					break
			if ignored:
				continue
			var recipe := _fabric.recipe(unit.recipe_id)
			if recipe == null or recipe.placements.is_empty():
				continue
			var bounds := unit.transform() * recipe.local_clearance_bounds
			if bounds.grow(0.1).has_point(point):
				score += weight
	return score


static func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z] as Array[float]


static func _is_building_use(use_value: int) -> bool:
	return use_value in [WarrenSpatialGrid.Use.PRIVATE_VOLUME,
		WarrenSpatialGrid.Use.STRUCTURAL_VOLUME]


static func _has_route_run(route_set: Dictionary, start: Vector3i,
		direction: Vector3i, length: int) -> bool:
	for step in length:
		if not route_set.has(start + direction * step):
			return false
	return true


static func _route_eye(cell: Vector3i) -> Vector3:
	return Vector3(cell) * FabricRecipe.CELL_SIZE + Vector3.UP * 1.45


static func _cell_centroid(cells: Array[Vector3i]) -> Vector3:
	if cells.is_empty():
		return Vector3.ZERO
	var total := Vector3.ZERO
	for cell: Vector3i in cells:
		total += Vector3(cell) * FabricRecipe.CELL_SIZE
	return total / float(cells.size())


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]

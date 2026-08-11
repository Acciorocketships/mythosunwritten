extends SceneTree

## Text-only diagnostic for one size profile. It exercises the real
## massif -> excavation -> arcade -> threaded-court source transaction without
## compiling meshes, and reports physical counts useful for comparing sizes.
##
##   Godot --headless --path . -s res://tests/harness/warren_scale_probe.gd \
##     -- --seed 7 --scale compact


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var full_requested := args.find("--full") >= 0
	print("ARGS ", args, " full=", full_requested)
	var world_seed := _int_arg(args, "--seed", 7)
	var scale_id := StringName(_string_arg(args, "--scale", "compact"))
	var source_token := _string_arg(args, "--source-token", "")
	var source_id := _string_arg(args, "--source-id", "")
	var requested_variant := _int_arg(args, "--variant", -1)
	var minimum_variant := _int_arg(args, "--min-variant", 0)
	var maximum_tower_run := _int_arg(args, "--max-tower-run", -1)
	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	if profile == null:
		printerr("SCALE_FAILURE invalid scale id ", scale_id)
		quit(2)
		return
	var massif := WarrenMassifBuilder.build(world_seed, {}, profile)
	if massif == null:
		printerr("MASSIF_FAILURE ", WarrenMassifBuilder.last_failure)
		quit(1)
		return
	print("SCALE id=", profile.scale_id, " signature=",
		profile.deterministic_signature(), " columns=", massif.columns.size(),
		" core_bands=", massif.core_top_bands,
		" footprint_diameter_m=", (profile.radius_cells * 2 + 1) * 3)
	var started := Time.get_ticks_msec()
	var frontier := WarrenTownSolver.mass_first_frontier(world_seed, {}, profile)
	print("FRONTIER count=", frontier.size(), " ms=",
		Time.get_ticks_msec() - started, " failure=", WarrenTownSolver.last_failure)
	for index in mini(4, frontier.size()):
		var candidate := frontier[index]
		print("CANDIDATE index=", index, " id=", candidate.stable_id,
			" walk=", candidate.walk_cells.size(), " court=",
			candidate.courtyard_cells.size(), " span=",
			candidate.audit.get("elevation_band_count", 0), " overhead=",
			candidate.audit.get("all_overhang_walk_ratio", 0.0),
			" addressed=", candidate.audit.get(
				"all_addressed_walk_ratio", 0.0))
	if full_requested and not frontier.is_empty():
		print("FULL_BEGIN")
		var program := SettlementFabricProgram.compile(
			EnvironmentCatalog.load_default())
		print("PROGRAM_READY ", program != null)
		var full_started := Time.get_ticks_msec()
		var ranked := WarrenVolumetricSolver._ranked_precomposition_variants(
			frontier, program)
		print("PRECOMPOSITION count=", ranked.size())
		if args.find("--list-ranked") >= 0:
			for candidate: Dictionary in ranked:
				print("RANKED source=", (candidate.volume as WarrenVolumePlan).stable_id,
					" variant=", candidate.variant, " score=", candidate.score)
		var trace_requested := args.find("--trace") >= 0
		WarrenVolumetricSolver.diagnostic_trace_skywalk_timing = trace_requested
		WarrenVolumetricSolver.diagnostic_trace_room_gate = trace_requested
		var spatial: WarrenSpatialPlan
		for candidate: Dictionary in ranked:
			var source := candidate.volume as WarrenVolumePlan
			if not source_id.is_empty() and String(source.stable_id) != source_id:
				continue
			if not source_token.is_empty() \
					and source.stable_id.find(source_token) < 0:
				continue
			if requested_variant >= 0 \
					and int(candidate.variant) != requested_variant:
				continue
			if int(candidate.variant) < minimum_variant:
				continue
			print("TRY source=", source.stable_id,
				" variant=", candidate.variant, " score=", candidate.score,
				" signature=", source.deterministic_signature().sha256_text())
			spatial = WarrenVolumetricSolver.from_volume(source,
				int(candidate.variant), program)
			if spatial != null and maximum_tower_run >= 0 \
					and int(spatial.audit.get(
						"max_identical_tower_floorplate_run_storeys", 0)) \
						> maximum_tower_run:
				print("REJECT_TOWER_RUN source=", source.stable_id,
					" variant=", candidate.variant, " run=", spatial.audit.get(
						"max_identical_tower_floorplate_run_storeys", 0))
				spatial = null
				continue
			if spatial != null:
				break
		print("SPATIAL accepted=", spatial != null, " ms=",
			Time.get_ticks_msec() - full_started, " failure=",
			WarrenVolumetricSolver.last_failure.left(2000))
		if spatial != null:
			var fabric := WarrenSpatialFabricCompiler.solve(spatial, program)
			print("FABRIC accepted=", fabric != null, " buildings=",
				spatial.buildings.size(), " rooms=",
				spatial.audit.get("room_stamp_count", 0), " route_floors=",
				spatial.route_floor_cells.size(), " features=",
				spatial.features.size(), " audit=", spatial.audit,
				" failure=", WarrenSpatialFabricCompiler.last_failure,
				" volume_diagnostic=", FabricVolumeClassifier.last_diagnostic)
			quit(0 if fabric != null else 1)
			return
		quit(1)
		return
	quit(0 if not frontier.is_empty() else 1)


static func _string_arg(args: PackedStringArray, key: String,
		fallback: String) -> String:
	var index := args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() \
		else fallback


static func _int_arg(args: PackedStringArray, key: String,
		fallback: int) -> int:
	return int(_string_arg(args, key, str(fallback)))

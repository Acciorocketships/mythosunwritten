extends SceneTree


func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert(program != null)
	var args := OS.get_cmdline_user_args()
	var first_seed := _argument_int(args, "--first-seed", 0)
	var seed_count := _argument_int(args, "--seed-count", 12)
	var failures := 0
	for world_seed in range(first_seed, first_seed + seed_count):
		var built := WarrenBuiltTownSolver.solve(world_seed, program)
		if built == null:
			failures += 1
			print("seed=%d BUILT_REJECTED: %s" % [world_seed,
				WarrenBuiltTownSolver.last_failure])
			if args.has("--print-candidate-failures"):
				print("  volume diagnostic=%s" % \
					FabricVolumeClassifier.last_diagnostic)
				var town := WarrenTownSolver.solve(world_seed, {}, program)
				if town == null:
					print("  town rejected=%s diagnostic=%s" % [
						WarrenTownSolver.last_failure,
						WarrenTownSolver.last_timing_diagnostic])
					continue
				var assets_probe := WarrenAssetCompiler.solve(town, program)
				var fabric_probe := WarrenFabricCompiler.solve(assets_probe)
				for reservation: Dictionary in town.parcels.connection_reservations:
					print("  reservation kind=%s components=%s" % [
						reservation.kind, reservation.components])
				for candidate: Dictionary in WarrenOverheadSolver.candidate_specs(
						program, fabric_probe, world_seed, false):
					if StringName(candidate.category) == &"skywalk":
						print("  raw candidate %s specs=%s" % [
							candidate.stable_id, candidate.specs])
			continue
		var assets := built.assets
		var fabric := built.fabric
		var raw_overhead := WarrenOverheadSolver.candidate_specs(program,
			fabric, world_seed, false)
		var raw_skywalks := 0
		for candidate: Dictionary in raw_overhead:
			raw_skywalks += int(StringName(candidate.category) == &"skywalk")
		var extended_stacks := 0
		var mixed_spans := 0
		var construction_storeys := 0
		var construction_kinds: Dictionary = {}
		for parcel: WarrenBuildingParcel in assets.town.parcels.parcels:
			var proposal := WarrenParcelConstruction.proposal(parcel)
			extended_stacks += int((proposal.origin as Vector3i).y \
				< parcel.base_band)
			mixed_spans += int(parcel.support_mode == &"mixed_span")
			construction_storeys += int(proposal.storeys)
			var kind := StringName(proposal.kind)
			construction_kinds[kind] = int(construction_kinds.get(kind, 0)) + 1
		if args.has("--print-candidate-failures"):
			var printed := 0
			for candidate: Dictionary in raw_overhead:
				if StringName(candidate.category) != &"skywalk":
					continue
				var trial_specs: Array[Dictionary] = []
				for spec: Dictionary in candidate.specs as Array:
					trial_specs.append(spec)
				var trial := WarrenFabricCompiler.solve(assets, trial_specs)
				print("  raw skywalk %s => %s" % [candidate.stable_id,
					"ACCEPTED" if trial != null else WarrenFabricCompiler.last_failure])
				printed += 1
				if printed >= 6:
					break
		print(("seed=%d attempt=%d parcels=%d units=%d placements=%d assets=%d " \
			+ "families=%d visual_conflicts=%d public_air_overlap=%d " \
			+ "skywalks=%d outcrops=%d raw_skywalks=%d bounded=%.2f/%.2f " \
			+ "extended=%d mixed=%d storeys=%d infill=%d wells=%d " \
			+ "enclosure=%.2f kinds=%s") % [world_seed,
			int(assets.town.audit.route_attempt),
			int(assets.audit.parcel_count), int(assets.audit.unit_count),
			int(assets.audit.placement_count), int(assets.audit.asset_count),
			int(assets.audit.recipe_family_count),
			int(assets.audit.visual_envelope_conflict_count),
			int(fabric.audit.get("public_air_occupied_overlap_count", -1)),
			int(built.audit.skywalk_count), int(built.audit.outcropping_count),
			raw_skywalks, float(assets.town.parcels.audit.bounded_walk_ratio),
			float(assets.town.parcels.audit.two_sided_walk_ratio),
			extended_stacks, mixed_spans, construction_storeys,
			int(assets.town.public_realm.audit.get(
				"infill_platform_patch_count", 0)),
			int(assets.town.public_realm.audit.get("infill_lightwell_count", 0)),
			float(assets.town.public_realm.audit.get(
				"composed_walk_enclosure_ratio", 0.0)),
			construction_kinds])
		if args.has("--print-selection"):
			for diagnostic: Dictionary in \
					WarrenBuiltTownSolver.last_selection_diagnostic:
				print(("  selection attempt=%d parcels=%d frontage=%.3f " \
					+ "overhead=%.3f sightlines=%d links=%d violation=%.3f " \
					+ "score=%.1f") % [int(diagnostic.route_attempt),
					int(diagnostic.parcel_count), float(diagnostic.frontage_ratio),
					float(diagnostic.overhead_route_ratio),
					int(diagnostic.through_sightline_count),
					int(diagnostic.skywalk_link_count),
					float(diagnostic.target_violation),
					float(diagnostic.quality_score)])
			for diagnostic: Dictionary in \
					WarrenBuiltTownSolver.last_candidate_failure_diagnostic:
				print("  rejected attempt=%d failure=%s" % [
					int(diagnostic.route_attempt), String(diagnostic.failure)])
		if args.has("--print-conflicts"):
			for conflict: Dictionary in assets.visual_envelope_conflicts().slice(0, 40):
				print("  conflict %s [%s] <> %s [%s] overlap=%s" % [
					conflict.left, conflict.left_recipe, conflict.right,
					conflict.right_recipe, conflict.overlap])
		if args.has("--print-parcels"):
			for parcel: WarrenBuildingParcel in assets.town.parcels.parcels:
				var proposal := WarrenParcelConstruction.proposal(parcel)
				print("  parcel=%s size=%dx%d base/top=%d/%d built=%d+%d kind=%s" % [
					parcel.stable_id, parcel.width_cells, parcel.depth_cells,
					parcel.base_band, parcel.top_band,
					int((proposal.origin as Vector3i).y), int(proposal.storeys),
					proposal.kind])
		if args.has("--print-overhead-placements"):
			for unit: FabricUnit in fabric.units:
				var recipe := fabric.recipe(unit.recipe_id)
				if recipe == null or not recipe.has_tag(&"overhead_occupied"):
					continue
				print("  overhead unit=%s recipe=%s origin=%s turns=%d" % [
					unit.stable_id, unit.recipe_id, unit.lattice_origin,
					unit.yaw_quarters])
				for placement: Dictionary in recipe.placements:
					if String(placement.id).contains("roof"):
						var world_transform := unit.transform() * \
							(placement.transform as Transform3D)
						print("    roof=%s asset=%s origin=%s" % [placement.id,
							placement.asset_id, world_transform.origin])
	print("summary seeds=%d failures=%d" % [seed_count, failures])
	quit(0 if failures == 0 else 1)


static func _argument_int(args: PackedStringArray, key: String,
		fallback: int) -> int:
	var index := args.find(key)
	return fallback if index < 0 or index + 1 >= args.size() \
		else int(args[index + 1])

extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first_seed := _argument_int(args, "--first-seed", 0)
	var seed_count := _argument_int(args, "--seed-count", 12)
	var failures := 0
	var signatures: Dictionary = {}
	for world_seed in range(first_seed, first_seed + seed_count):
		var plan := WarrenTownSolver.solve(world_seed)
		if plan == null:
			failures += 1
			print("seed=%d REJECTED: %s" % [world_seed,
				WarrenTownSolver.last_failure])
			continue
		signatures[plan.deterministic_signature()] = true
		print(("seed=%d attempt=%d walk=%d levels=%d parcels=%d bounded=%.2f " \
			+ "half=%d families=%d stacked=%d overpass=%d open=%.2f " \
			+ "bounded2=%.2f composed=%.2f infill=%d entrances=%d/%d") % [
			world_seed, int(plan.audit.route_attempt),
			int(plan.audit.walk_cell_count), int(plan.audit.elevation_band_count),
			int(plan.audit.parcel_count), float(plan.audit.bounded_walk_ratio),
			int(plan.audit.half_level_neighbor_pair_count),
			int(plan.audit.footprint_family_count),
			int(plan.audit.stacked_parcel_column_count),
			int(plan.audit.occupied_overpass_parcel_count),
			float(plan.audit.urban_core_open_column_ratio),
			float(plan.parcels.audit.two_sided_walk_ratio),
			float(plan.audit.composed_walk_enclosure_ratio),
			int(plan.audit.infill_platform_patch_count),
			int(plan.audit.served_entrance_count),
			plan.parcels.parcels.size()])
		for entrance: Dictionary in plan.surfaces.unserved_entrances:
			var parcel: WarrenBuildingParcel
			for candidate: WarrenBuildingParcel in plan.parcels.parcels:
				if String(entrance.stable_id).begins_with(String(candidate.stable_id)):
					parcel = candidate
					break
			print("  UNSERVED %s threshold=%s landing=%s facing=%s" % [
				entrance.stable_id, entrance.threshold_cell,
				entrance.landing_cell, entrance.facing])
			if parcel != null:
				var expanded := Vector3i(parcel.address_walk_cell.x * 2,
					parcel.address_walk_cell.y, parcel.address_walk_cell.z * 2)
				print("    address=%s expanded=%s..%s has=%s" % [
					parcel.address_walk_cell, expanded,
					expanded + Vector3i(1, 0, 1),
					plan.surfaces.has_cell(entrance.landing_cell)])
	print("summary seeds=%d failures=%d unique=%d" % [seed_count, failures,
		signatures.size()])
	quit(0 if failures == 0 and signatures.size() == seed_count else 1)


static func _argument_int(args: PackedStringArray, key: String,
		fallback: int) -> int:
	var index := args.find(key)
	return fallback if index < 0 or index + 1 >= args.size() \
		else int(args[index + 1])

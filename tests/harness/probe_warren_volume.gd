extends SceneTree

## Fast worker-only diagnostic for the volumetric warren source plan.  This is
## intentionally render-free so broad seed failures can be found before asset
## compilation or screenshot review.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first_seed := _argument_int(args, "--first-seed", 0)
	var seed_count := _argument_int(args, "--seed-count", 12)
	var failures := 0
	var signatures: Dictionary = {}
	for world_seed in range(first_seed, first_seed + seed_count):
		var plan := WarrenPublicRealmCarver.solve(world_seed)
		if plan == null:
			failures += 1
			print("seed=%d REJECTED" % world_seed)
			var diagnostic_envelope := WarrenVolumeEnvelope.build(world_seed, {}, true)
			print("  envelope_sealed=%s rejection=%s entries=%d columns=%d" % [
				diagnostic_envelope.is_sealed(), diagnostic_envelope.last_rejection,
				diagnostic_envelope.boundary_entry_cells(
					WarrenVolumePlan.HEADROOM_BANDS).size(),
				diagnostic_envelope.height_bands.size()])
			for attempt in 6:
				var diagnostic := WarrenPublicRealmCarver.diagnostic_candidate(
					world_seed, attempt)
				if diagnostic != null:
					print("  attempt=%d sealed=%s rejection=%s walk=%d audit=%s" % [
						attempt, diagnostic.is_sealed(), diagnostic.last_rejection,
						diagnostic.walk_cells.size(), diagnostic.audit])
					break
			continue
		signatures[plan.deterministic_signature()] = true
		print(("seed=%d attempt=%s signature=%s walk=%d levels=%d ramps=%d " \
			+ "stairs=%d overhang=%.2f " \
			+ "frontage=%.2f crossovers=%d shafts=%.2f straight=%d") % [
			world_seed, String(plan.stable_id).get_slice(".", 3),
			plan.deterministic_signature().sha256_text().left(12),
			int(plan.audit.walk_cell_count),
			int(plan.audit.elevation_band_count),
			int(plan.audit.ramp_transition_count),
			int(plan.audit.stair_transition_count),
			float(plan.audit.overhang_walk_ratio),
			float(plan.audit.addressed_walk_ratio),
			int(plan.audit.route_crossover_count),
			float(plan.audit.deep_vertical_shaft_ratio),
			int(plan.audit.max_straight_run_cells),
		])
	print("summary seeds=%d failures=%d unique=%d" % [
		seed_count, failures, signatures.size()])
	quit(0 if failures == 0 and signatures.size() == seed_count else 1)


static func _argument_int(args: PackedStringArray, key: String,
		fallback: int) -> int:
	var index := args.find(key)
	if index < 0 or index + 1 >= args.size():
		return fallback
	return int(args[index + 1])

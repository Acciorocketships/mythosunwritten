extends SceneTree

## Worker-only composed-town corpus probe. This is intentionally narrower than
## the visual harness: it exposes which logical parcel geometry wins the ranked
## frontier without compiling render assets or opening a window.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first_seed := _argument_int(args, "--first-seed", 0)
	var seed_count := _argument_int(args, "--seed-count", 12)
	var failures := 0
	var stacked_total := 0
	var overpass_total := 0
	for world_seed in range(first_seed, first_seed + seed_count):
		var town := WarrenTownSolver.solve(world_seed)
		if town == null:
			failures += 1
			print("seed=%d REJECTED %s" % [world_seed,
				WarrenTownSolver.last_failure])
			continue
		var audit := town.parcels.audit
		var stacked := int(audit.stacked_parcel_column_count)
		var overpasses := int(audit.occupied_overpass_parcel_count)
		stacked_total += stacked
		overpass_total += overpasses
		print(("seed=%d attempt=%d parcels=%d stacked=%d overpasses=%d " \
			+ "short=%d core_component=%d") % [world_seed,
			int(town.audit.route_attempt), int(audit.parcel_count), stacked,
			overpasses, int(audit.visually_short_parcel_count),
			int(town.audit.max_uncovered_core_component_size)])
	print("summary seeds=%d failures=%d stacked=%d overpasses=%d" % [
		seed_count, failures, stacked_total, overpass_total])
	quit(0 if failures == 0 else 1)


static func _argument_int(args: PackedStringArray, key: String,
		fallback: int) -> int:
	var index := args.find(key)
	if index < 0 or index + 1 >= args.size():
		return fallback
	return int(args[index + 1])

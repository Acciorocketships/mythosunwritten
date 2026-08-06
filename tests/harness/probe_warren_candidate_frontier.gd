extends SceneTree

## Resource-free/contract-aware view of the complete volumetric town frontier.
## This isolates parcel and public-realm quality before the more expensive
## market/overhead detail transaction is run.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var city_seed := _argument_int(args, "--seed", 6046713720826375059)
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert(program != null)
	var rank_attempt := _argument_int(args, "--rank-attempt", -1)
	if rank_attempt >= 0:
		_print_topology_rank(city_seed, rank_attempt)
		quit(0)
		return
	var asset_frontier := _argument_int(args, "--asset-frontier", -1)
	var plans := WarrenTownSolver.ranked_candidates(city_seed, {}, program,
		WarrenTownSolver.COMPOSED_PLAN_FRONTIER, asset_frontier)
	var rows: Array[Dictionary] = []
	for plan: WarrenTownPlan in plans:
		var audit := plan.audit
		var attempt := int(audit.get("route_attempt", -1))
		rows.append({
			"attempt": attempt,
			"route_family": "escape" if attempt >= \
				WarrenPublicRealmCarver.COMPACT_ROUTE_ATTEMPTS else "compact",
			"walk_cells": plan.volume.primary_itinerary.size(),
			"parcels": int(audit.get("parcel_count", 0)),
			"bounded": float(audit.get("bounded_walk_ratio", 0.0)),
			"two_sided": float(plan.parcels.audit.get(
				"two_sided_walk_ratio", 0.0)),
			"ground_primary_bounded": float(plan.parcels.audit.get(
				"ground_primary_bounded_walk_ratio", 0.0)),
			"ground_primary_two_sided": float(plan.parcels.audit.get(
				"ground_primary_two_sided_walk_ratio", 0.0)),
			"unstepped_tall": int(plan.parcels.audit.get(
				"unstepped_tall_parcel_count", 0)),
			"overpasses": int(audit.get("occupied_overpass_parcel_count", 0)),
			"open_core": float(audit.get("urban_core_open_column_ratio", 0.0)),
			"composed": float(audit.get("composed_walk_enclosure_ratio", 0.0)),
			"arcade_bounded": float(plan.parcels.audit.get(
				"ground_arcade_bounded_walk_ratio", 0.0)),
			"grounded_parcels": int(plan.parcels.audit.get(
				"grounded_parcel_count", 0)),
			"infill": int(audit.get("infill_platform_patch_count", 0)),
			"itinerary": plan.volume.primary_itinerary,
			"route_signature": plan.volume.deterministic_signature().sha256_text(),
		})
	print(JSON.stringify({"seed": city_seed, "plans": rows,
		"failure": WarrenTownSolver.last_failure}, "  "))
	quit(0 if not plans.is_empty() else 1)


static func _print_topology_rank(city_seed: int, requested_attempt: int) -> void:
	var envelope := WarrenVolumeEnvelope.build(city_seed, {})
	var volumes: Array[WarrenVolumePlan] = []
	for attempt in WarrenPublicRealmCarver.MAX_ATTEMPTS:
		var volume := WarrenPublicRealmCarver.sealed_candidate(city_seed,
			attempt, envelope)
		if volume == null:
			continue
		volume = WarrenGroundArcadeSolver.extend(volume)
		if volume != null:
			volumes.append(volume)
	volumes.sort_custom(func(a: WarrenVolumePlan, b: WarrenVolumePlan) -> bool:
		return WarrenPublicRealmCarver.topology_score(a) \
			< WarrenPublicRealmCarver.topology_score(b))
	var global_rank := -1
	var family_rank := -1
	var family_seen := 0
	var requested_family := int(requested_attempt >= \
		WarrenPublicRealmCarver.COMPACT_ROUTE_ATTEMPTS)
	for index in volumes.size():
		var attempt := _volume_attempt(volumes[index])
		var family := int(attempt >= \
			WarrenPublicRealmCarver.COMPACT_ROUTE_ATTEMPTS)
		if attempt == requested_attempt:
			global_rank = index
			family_rank = family_seen
			break
		if family == requested_family:
			family_seen += 1
	print(JSON.stringify({"seed": city_seed, "attempt": requested_attempt,
		"global_rank": global_rank, "family_rank": family_rank,
		"survivor_count": volumes.size()}, "  "))


static func _volume_attempt(volume: WarrenVolumePlan) -> int:
	var parts := String(volume.stable_id).split(".")
	for index in range(parts.size() - 1, -1, -1):
		var token := parts[index] as String
		if token.is_valid_int():
			return int(token)
	return -1


static func _argument_int(args: PackedStringArray, key: String,
		fallback: int) -> int:
	var index := args.find(key)
	return fallback if index < 0 or index + 1 >= args.size() \
		else int(args[index + 1])

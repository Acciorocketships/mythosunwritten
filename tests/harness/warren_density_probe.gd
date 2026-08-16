# tests/harness/warren_density_probe.gd
# Frontier-level density/enclosure metrics for the mass-first warren, per city
# seed over its 12 excavation attempts — cheap (no composition), so lane and
# reserve rules can be compared before running the full search oracle:
#   attempts that yield a candidate, arcade/topology failure counts, lanes and
#   lane cells on the taken bore, houses partitioned (variant 0), proposed mass
#   ratio, and the precomposition through/ground sightline + overhead proxies.
#
#   Godot --headless --path . -s res://tests/harness/warren_density_probe.gd \
#     -- [--city-seeds a,b:standard] [--label name] \
#        [--reserve-radius N] [--reserve-clearance-bands H]
#
# The two tuning flags override the carver/arcade lane-reserve rules for the
# run (experiment only; production values are the class constants).
extends SceneTree

const DEFAULT_CITY_SEEDS: Array[String] = [
	"166029932451774690", "3910114991003307946", "6357506428441529412",
	"3613595803240038080:standard", "7:standard",
	"6052724565602100358", "3360408526109449337", "8702761491571936463",
	"6046713720826375059"]


func _init() -> void:
	var city_seeds: Array[String] = DEFAULT_CITY_SEEDS.duplicate()
	var label := "density"
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--city-seeds" and index + 1 < args.size():
			city_seeds.clear()
			for value: String in args[index + 1].split(",", false):
				city_seeds.append(value)
		elif args[index] == "--label" and index + 1 < args.size():
			label = args[index + 1]
		elif args[index] == "--reserve-radius" and index + 1 < args.size():
			WarrenExcavationCarver.lane_reserve_radius = int(args[index + 1])
		elif args[index] == "--reserve-clearance-bands" \
				and index + 1 < args.size():
			WarrenExcavationCarver.lane_reserve_clearance_bands = \
				int(args[index + 1])
			WarrenGroundArcadeSolver.auxiliary_separation_clearance_bands = \
				int(args[index + 1])
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	var totals := {"attempts": 0, "candidates": 0, "arcade_fail": 0,
		"topology_fail": 0, "gallery_fail": 0, "other_fail": 0,
		"lanes": 0, "lane_cells": 0, "houses": 0, "mass_ratio": 0.0,
		"through": 0, "ground": 0, "overhead": 0.0, "measured": 0}
	for spec: String in city_seeds:
		var parts := spec.split(":", false)
		var city_seed := int(parts[0])
		var profile := WarrenVillageScaleProfile.for_id(StringName(parts[1])) \
			if parts.size() > 1 else WarrenVillageScaleProfile.select(city_seed)
		var row := {"attempts": 0, "candidates": 0, "arcade_fail": 0,
			"topology_fail": 0, "gallery_fail": 0, "other_fail": 0,
			"lanes": 0, "lane_cells": 0, "houses": 0, "mass_ratio": 0.0,
			"through": 0, "ground": 0, "overhead": 0.0, "measured": 0}
		for attempt in WarrenTownSolver.MASS_FIRST_EXCAVATION_ATTEMPTS:
			row.attempts += 1
			var frontier := WarrenTownSolver.mass_first_attempt_frontier(
				city_seed, attempt, {}, profile)
			if frontier.is_empty():
				var failure := WarrenTownSolver.last_failure
				if failure.contains("ground-arcade") \
						or failure.contains("ground arcade"):
					row.arcade_fail += 1
				elif failure.contains("topology gate"):
					row.topology_fail += 1
				elif failure.contains("courtyard") or failure.contains("gallery"):
					row.gallery_fail += 1
				else:
					row.other_fail += 1
				continue
			row.candidates += 1
			var volume: WarrenVolumePlan = frontier[0]
			var bore := volume.mass_context.get(&"excavation") as WarrenExcavation
			row.lanes += bore.lanes.size()
			for lane: Dictionary in bore.lanes:
				row.lane_cells += (lane["cells"] as Array).size()
			var parcels := WarrenTownSolver.partition_parcels(volume, 0, program)
			row.houses += parcels.parcels.size() if parcels != null else 0
			var audit := WarrenVolumetricSolver._precomposition_enclosure_audit(
				volume, 0, program)
			if not audit.is_empty():
				row.measured += 1
				row.mass_ratio += float(audit.proposed_mass_ratio)
				row.through += int(audit.through_sightline_count)
				row.ground += int(audit.ground_through_sightline_count)
				row.overhead += float(audit.overhead_route_ratio)
		_print_row(label, "seed=%d %s" % [city_seed, String(profile.scale_id)],
			row)
		for key: String in totals:
			totals[key] += row[key]
	_print_row(label, "TOTAL", totals)
	quit()


func _print_row(label: String, name: String, row: Dictionary) -> void:
	var m := maxi(1, int(row.measured))
	var c := maxi(1, int(row.candidates))
	print("DENSITY %s %s attempts=%d candidates=%d fails(arcade=%d topology=%d gallery=%d other=%d) lanes/cand=%.2f lane_cells/cand=%.2f houses/cand=%.1f mass_ratio=%.3f through=%.1f ground=%.1f overhead=%.3f" % [
		label, name, int(row.attempts), int(row.candidates),
		int(row.arcade_fail), int(row.topology_fail), int(row.gallery_fail),
		int(row.other_fail), float(row.lanes) / c, float(row.lane_cells) / c,
		float(row.houses) / c, float(row.mass_ratio) / m,
		float(row.through) / m, float(row.ground) / m, float(row.overhead) / m])

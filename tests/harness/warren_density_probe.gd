# tests/harness/warren_density_probe.gd
# Frontier-level density/enclosure metrics for the mass-first warren, per city
# seed over its 12 excavation attempts — cheap (no composition), so lane and
# reserve rules can be compared before running the full search oracle:
#   attempts that yield a candidate, arcade/topology failure counts, lanes and
#   lane cells on the taken bore, houses partitioned (variant 0), proposed mass
#   ratio, and the precomposition through/ground sightline + overhead proxies.
#
#   Godot --headless --path . -s res://tests/harness/warren_density_probe.gd \
#     -- [--city-seeds a,b:standard] [--label name] [--maze] \
#        [--maze-partition] \
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
	var maze := false
	var maze_partition := false
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--city-seeds" and index + 1 < args.size():
			city_seeds.clear()
			for value: String in args[index + 1].split(",", false):
				city_seeds.append(value)
		elif args[index] == "--label" and index + 1 < args.size():
			label = args[index + 1]
		elif args[index] == "--maze":
			maze = true
		elif args[index] == "--maze-partition":
			maze = true
			maze_partition = true
		elif args[index] == "--reserve-radius" and index + 1 < args.size():
			WarrenExcavationCarver.lane_reserve_radius = int(args[index + 1])
		elif args[index] == "--reserve-clearance-bands" \
				and index + 1 < args.size():
			WarrenExcavationCarver.lane_reserve_clearance_bands = \
				int(args[index + 1])
			WarrenGroundArcadeSolver.auxiliary_separation_clearance_bands = \
				int(args[index + 1])
	if maze:
		_run_maze(city_seeds, label, maze_partition)
		quit()
		return
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


func _run_maze(city_seeds: Array[String], label: String,
		measure_partition: bool) -> void:
	## Source-plan metrics only: this deliberately stops before volume adaptation,
	## partition, assets, and composition so the new one-pass carver's topology
	## cost and guarantees are visible without the retired search obscuring them.
	var totals := {"sealed": 0, "failed": 0, "elapsed_ms": 0,
		"passages": 0, "spine": 0, "alleys": 0, "markets": 0, "loops": 0,
		"frontage": 0.0, "columns": 0.0, "two_sided": 0.0,
		"covered": 0.0, "solid": 0.0, "partitioned": 0,
		"partition_ms": 0, "parcels": 0, "mass_assignment": 0.0}
	for spec: String in city_seeds:
		var parts := spec.split(":", false)
		var city_seed := int(parts[0])
		var profile := WarrenVillageScaleProfile.for_id(StringName(parts[1])) \
			if parts.size() > 1 else WarrenVillageScaleProfile.select(city_seed)
		var started := Time.get_ticks_msec()
		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		var plan := WarrenMazeCarver.carve(city_seed, massif, profile) \
			if massif != null else null
		var elapsed := Time.get_ticks_msec() - started
		if plan == null:
			totals.failed += 1
			print("MAZE_DENSITY %s seed=%d %s FAILED ms=%d reason=%s massif=%s diagnostic=%s" \
				% [label, city_seed, String(profile.scale_id), elapsed,
					WarrenMazeCarver.last_failure,
					WarrenMassifBuilder.last_failure,
					str(WarrenMazeCarver.last_diagnostic)])
			continue
		var audit := plan.audit
		totals.sealed += 1
		totals.elapsed_ms += elapsed
		totals.passages += int(audit.passage_cell_count)
		totals.spine += int(audit.spine_cell_count)
		totals.alleys += int(audit.alley_cell_count)
		totals.markets += int(audit.market_cell_count)
		totals.loops += int(audit.loop_join_count)
		totals.frontage += float(audit.frontage_ratio)
		totals.columns += float(audit.addressed_column_ratio)
		totals.two_sided += float(audit.two_sided_passage_ratio)
		totals.covered += float(audit.covered_passage_ratio)
		totals.solid += float(audit.source_solid_retention_ratio)
		var partition_summary := ""
		if measure_partition:
			var partition_started := Time.get_ticks_msec()
			var volume := WarrenMazeVolumeAdapter.to_volume_plan(plan)
			var parcels := WarrenTownSolver.partition_parcels(volume, 0) \
				if volume != null else null
			var partition_elapsed := Time.get_ticks_msec() - partition_started
			totals.partition_ms += partition_elapsed
			if parcels == null:
				var reason := WarrenTownSolver.last_partition_failure \
					if volume != null else WarrenMazeVolumeAdapter.last_failure
				partition_summary = " partition=FAILED partition_ms=%d reason=%s" % [
					partition_elapsed, reason]
			else:
				var assignment := float(parcels.audit.get(
					"maze_owned_solid_ratio", float(
						parcels.retained_mass_cells.size()) \
						/ float(maxi(1, volume.mass_cells.size()))))
				totals.partitioned += 1
				totals.parcels += parcels.parcels.size()
				totals.mass_assignment += assignment
				partition_summary = " partition_ms=%d parcels=%d mass_assignment=%.3f" \
					% [partition_elapsed, parcels.parcels.size(), assignment]
		print(("MAZE_DENSITY %s seed=%d %s ms=%d passages=%d spine=%d " \
			+ "alleys=%d market=%d loops=%d frontage=%.3f columns=%.3f two_sided=%.3f " \
			+ "covered=%.3f source_solid=%.3f thickness=%s%s") % [label,
				city_seed, String(profile.scale_id), elapsed,
				int(audit.passage_cell_count), int(audit.spine_cell_count),
				int(audit.alley_cell_count), int(audit.market_cell_count),
				int(audit.loop_join_count),
				float(audit.frontage_ratio),
				float(audit.addressed_column_ratio),
				float(audit.two_sided_passage_ratio),
				float(audit.covered_passage_ratio),
				float(audit.source_solid_retention_ratio),
				str(audit.block_thickness_histogram), partition_summary])
	var count := maxi(1, int(totals.sealed))
	print(("MAZE_DENSITY %s TOTAL sealed=%d failed=%d mean_ms=%.1f " \
		+ "passages=%.1f spine=%.1f alleys=%.1f market=%.1f loops=%.1f frontage=%.3f " \
		+ "columns=%.3f two_sided=%.3f covered=%.3f source_solid=%.3f") % [
			label, int(totals.sealed), int(totals.failed),
			float(totals.elapsed_ms) / count, float(totals.passages) / count,
			float(totals.spine) / count, float(totals.alleys) / count,
			float(totals.markets) / count, float(totals.loops) / count,
			float(totals.frontage) / count,
			float(totals.columns) / count, float(totals.two_sided) / count,
			float(totals.covered) / count, float(totals.solid) / count])
	if measure_partition:
		var partitioned := maxi(1, int(totals.partitioned))
		print(("MAZE_PARTITION %s TOTAL sealed=%d partitioned=%d failed=%d " \
			+ "mean_ms=%.1f parcels=%.1f mass_assignment=%.3f") % [label,
				int(totals.sealed), int(totals.partitioned),
				int(totals.sealed) - int(totals.partitioned),
				float(totals.partition_ms) / count,
				float(totals.parcels) / partitioned,
				float(totals.mass_assignment) / partitioned])


func _print_row(label: String, name: String, row: Dictionary) -> void:
	var m := maxi(1, int(row.measured))
	var c := maxi(1, int(row.candidates))
	print("DENSITY %s %s attempts=%d candidates=%d fails(arcade=%d topology=%d gallery=%d other=%d) lanes/cand=%.2f lane_cells/cand=%.2f houses/cand=%.1f mass_ratio=%.3f through=%.1f ground=%.1f overhead=%.3f" % [
		label, name, int(row.attempts), int(row.candidates),
		int(row.arcade_fail), int(row.topology_fail), int(row.gallery_fail),
		int(row.other_fail), float(row.lanes) / c, float(row.lane_cells) / c,
		float(row.houses) / c, float(row.mass_ratio) / m,
		float(row.through) / m, float(row.ground) / m, float(row.overhead) / m])

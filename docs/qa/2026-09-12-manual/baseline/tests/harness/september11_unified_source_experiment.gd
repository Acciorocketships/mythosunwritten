extends SceneTree

class SourceField:
	extends WarrenMassifBuilder
	static func experiment(world_seed: int, ground_bands: Dictionary = {},
			scale_profile: WarrenVillageScaleProfile = null) -> WarrenMassif:
		last_failure = ""
		var profile := scale_profile if scale_profile != null \
			else WarrenVillageScaleProfile.review_fixture()
		if not profile.validate():
			last_failure = "invalid village scale profile"
			return null
		var radius_cells := profile.radius_cells
		var footprint_core := profile.core_target_band_range.x \
			+ posmod(_hash(world_seed, 5, 0, 0),
				profile.core_target_band_range.y \
					- profile.core_target_band_range.x + 1)
		var warp_phase := float(posmod(_hash(world_seed, 7, 0, 0), 1000)) \
			/ 1000.0 * TAU
		var warp_strength := 0.22 + float(posmod(_hash(world_seed, 11, 0, 0),
			100)) / 100.0 * 0.18

		var raw_at: Dictionary = {}
		var form: StringName = [&"hill", &"crescent", &"courtyard", &"ridge"][
			posmod(_hash(world_seed, 0xC17, 0, 0), 4)]
		var open_court: Dictionary = {}
		var extent := ceili(float(radius_cells) * 2.0)
		for z in range(-extent, extent + 1):
			for x in range(-extent, extent + 1):
				var radius := Vector2(float(x), float(z)).length()
				var angle := atan2(float(z), float(x))
				var warped := radius * (1.0 + warp_strength \
					* sin(angle * 3.0 + warp_phase))
				var gaussian := exp(-pow(warped / float(radius_cells) * 1.9,
					2.0))
				var raw := float(footprint_core) * gaussian
				if form != &"hill":
					var p := Vector2(x, z) / float(radius_cells)
					if form == &"ridge":
						var q := Vector2(p.x / 1.4, p.y / 0.8).length()
						raw = 12.0 * sqrt(maxf(0.0, 1.0 - q * q))
					else:
						var q := Vector2(p.x / 1.2, p.y).length()
						raw = float(footprint_core) * sqrt(maxf(0.0, 1.0 - q * q))
						var court_center := Vector2i(roundi(radius_cells * 0.55), 0)
						var court_half := maxi(1, radius_cells / 4)
						var in_court := absi(z) <= court_half and (
							x >= court_center.x - court_half if form == &"crescent"
							else absi(x - court_center.x) <= court_half)
						if in_court:
							if form == &"courtyard":
								open_court[Vector2i(x, z)] = true
							continue
				# QA source-field experiment: every height contributes to the same
				# construction field before any public route or plot exists.
				for lobe in 2:
					var direction := warp_phase + float(lobe)*2.2
					var centre := Vector2.from_angle(direction)*float(radius_cells)*0.85
					var q := (Vector2(x,z)-centre).length()/(float(radius_cells)*0.68)
					var low := 4.0*exp(-pow(q,4.0))
					raw = maxf(raw,low)
				if raw < float(MIN_COLUMN_BANDS):
					continue
				raw_at[Vector2i(x, z)] = raw

		var massif := _terraced_massif(world_seed, raw_at, ground_bands)
		massif.form_id = form
		massif.open_court = open_court
		massif.core_top_bands = 0
		for column: Vector2i in massif.columns:
			massif.core_top_bands = maxi(massif.core_top_bands,
				massif.layer_at(column))
		massif.finish_construction()
		return massif

func _init() -> void:
	var original := preload("res://tests/fixtures/frozen_maze_source.gd").read("res://tests/fixtures/september11-floating-source.txt")
	var reports: Array[Dictionary] = []
	for seed_value: int in [original.world_seed,2,9,11]:
		for mode: String in ["baseline","wider","composite"]:
			var profile := WarrenVillageScaleProfile.for_id(&"compact")
			if mode != "baseline":
				profile.landmark_range = Vector2i(5,6)
				profile.lane_budget = 5
				profile.lane_cell_budget = 20
			if mode == "wider": profile.radius_cells = 6
			var mass := SourceField.experiment(seed_value,{},profile) if mode == "composite" else WarrenMassifBuilder.build(seed_value,{},profile)
			var report := {"seed":seed_value,"mode":mode,"columns":mass.columns.size(),"form":mass.form_id,"mass_valid":mass.validate_construction(),"mass_failure":mass.last_rejection}
			var source := WarrenMazeCarver.carve(seed_value,mass,profile,false)
			if source == null:
				report["failure"] = WarrenMazeCarver.last_failure
			else:
				WarrenPlotPlanner.reserve(source,profile)
				WarrenPlotPlanner.partition(source,profile)
				source.finish_construction()
				var assets := 0
				for plot: Dictionary in source.plots: assets += int(plot.kind == WarrenMazeSourcePlan.PLOT_ASSET)
				report.merge({"assets":assets,"plots":source.plots.size(),"passages":source.passage_kinds.size(),"outcomes":source.audit.get("plot_outcomes",{})})
			reports.append(report)
			print("UNIFIED_SOURCE ",seed_value," ",mode," columns=",report.columns," assets=",report.get("assets",-1)," failure=",report.get("failure",""))
	FileAccess.open("res://docs/qa/2026-09-11-manual/10-unified-city/source-experiments.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	quit()

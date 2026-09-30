extends SceneTree
## Raised-district (WarrenTownPlatform) corpus probe. Builds each town through
## the production entry and reports whether it sealed, whether it has a
## platform, and the platform facts the tests pin:
##   godot --headless --path . -s res://tests/harness/suntail/town_platform_probe.gd -- \
##     --seeds 1-24 --scale compact,standard,large [--map] [--no-build]
## --map prints an ASCII plan of each platform: '#' plinth rock top, 'H' house
## on the plinth, 'u' upper street at the plinth top, 't' bored passage inside
## the plinth, '.' lower town column, ' ' outside the massif.

func _init() -> void: call_deferred("_run")


func _run() -> void:
	var seeds: Array[int] = []
	var scales: Array[StringName] = [&"compact"]
	var draw_map := false
	var build := true
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--seeds":
				for part in args[i + 1].split(","):
					if "-" in part and not part.begins_with("-"):
						for s in range(int(part.get_slice("-", 0)), int(part.get_slice("-", 1)) + 1):
							seeds.append(s)
					else:
						seeds.append(int(part))
			"--scale":
				scales.clear()
				for part in args[i + 1].split(","):
					scales.append(StringName(part))
			"--map": draw_map = true
			"--no-build": build = false
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default()) \
		if build else null
	var towns := 0
	var sealed := 0
	var raised := 0
	for seed_value in seeds:
		for scale in scales:
			towns += 1
			var profile := WarrenVillageScaleProfile.for_id(scale)
			var started := Time.get_ticks_msec()
			var row := {"seed": seed_value, "scale": String(scale)}
			var source: WarrenMazeSourcePlan = null
			if build:
				var plan := WarrenVolumetricSolver.generate(seed_value, {}, program, profile)
				row["sealed"] = plan != null
				if plan == null:
					row["failure"] = WarrenVolumetricSolver.last_failure
				else:
					sealed += 1
					source = plan.source_volume.mass_context.get(&"maze_source_plan")
			else:
				source = WarrenMazeSitePlanner.plan(seed_value, {}, profile, &"", false)
				row["sealed"] = source != null
				if source == null:
					row["failure"] = WarrenMazeSitePlanner.last_failure
				else:
					sealed += 1
			row["ms"] = Time.get_ticks_msec() - started
			if source != null:
				row.merge(platform_facts(source))
				if int(row.platform_columns) > 0:
					raised += 1
			print("ROW ", row)
			if draw_map and source != null and int(row.get("platform_columns", 0)) > 0:
				for line: String in platform_map(source):
					print("MAP ", line)
	print("SUMMARY towns=%d sealed=%d platform=%d" % [towns, sealed, raised])
	quit()


static func platform_facts(source: WarrenMazeSourcePlan) -> Dictionary:
	var massif := source.massif
	var columns := massif.platform_columns()
	var out := {"platform_columns": columns.size(), "plinth_bands": massif.platform_bands}
	if columns.is_empty():
		return out
	var inside := {}
	for column: Vector2i in columns:
		inside[column] = true
	var houses_on: Dictionary = {}
	var buried := 0
	for plot: Dictionary in source.plots:
		for column: Vector2i in plot.cells:
			if inside.has(column):
				houses_on[column] = true
				if int(plot.floor) < massif.bearing_at(column):
					buried += 1
	var bored := 0
	var upper := 0
	for cell: Vector3i in source.passage_kinds:
		var column := Vector2i(cell.x, cell.z)
		if not inside.has(column):
			continue
		if cell.y < massif.bearing_at(column):
			bored += 1
		elif cell.y == massif.bearing_at(column):
			upper += 1
	var holes := 0
	for column: Vector2i in columns:
		for band in range(massif.base_at(column), massif.bearing_at(column)):
			var cell := Vector3i(column.x, band, column.y)
			if not source.solid_at(cell) and not source.excavation.carved.has(cell):
				holes += 1
	var refusals := {}
	var outcomes: Dictionary = source.audit.get("plot_outcomes", {})
	for refusal: Dictionary in outcomes.get("seed_refusals", []):
		if inside.has(refusal.column):
			var key := "%s@%d" % [refusal.reason, int(refusal.band) - massif.bearing_at(refusal.column)]
			refusals[key] = int(refusals.get(key, 0)) + 1
	for record: Dictionary in outcomes.get("buildings", []):
		if String(record.get("reason", "")) != "":
			refusals["building: " + String(record.reason).left(60)] = 1
	out["platform_refusals"] = refusals
	out["plot_columns_on_platform"] = houses_on.size()
	out["plots_inside_plinth"] = buried
	out["bored_platform_cells"] = bored
	out["upper_street_cells"] = upper
	out["plinth_holes"] = holes
	return out


static func platform_map(source: WarrenMazeSourcePlan) -> Array[String]:
	var massif := source.massif
	var lo := Vector2i(999, 999)
	var hi := Vector2i(-999, -999)
	for column: Vector2i in massif.columns:
		lo = lo.min(column)
		hi = hi.max(column)
	var streets := {}
	for cell: Vector3i in source.passage_kinds:
		var column := Vector2i(cell.x, cell.z)
		streets[column] = mini(int(streets.get(column, 1 << 20)), cell.y)
	var plotted := {}
	for plot: Dictionary in source.plots:
		for column: Vector2i in plot.cells:
			plotted[column] = true
	var lines: Array[String] = []
	for z in range(lo.y, hi.y + 1):
		var line := ""
		for x in range(lo.x, hi.x + 1):
			var column := Vector2i(x, z)
			if not massif.has_column(column):
				line += " "
			elif not massif.is_platform(column):
				line += "s" if streets.has(column) else "."
			elif streets.has(column) and int(streets[column]) < massif.bearing_at(column):
				line += "t"
			elif streets.has(column):
				line += "u"
			elif plotted.has(column):
				line += "H"
			else:
				line += "#"
		lines.append(line)
	return lines

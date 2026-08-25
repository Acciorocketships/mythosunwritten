extends SceneTree

## TASK F2 RULING 2. The GOLDEN RECORD of a maze town, plus the median wall
## clock the >= 3000 ms bar is judged on. One optimisation may not change one
## byte of what a town IS, so this harness writes every sealed town down in a
## form `diff` can localise: the whole audit flattened to sorted `key = value`
## lines, the sealed plan's own deterministic signature (whole, grid, per
## building, per feature), and the compiled fabric's units.
##
##   Godot --headless --path . -s res://tests/harness/warren_maze_identity_probe.gd -- \
##     --seeds 12,4 --scale compact --runs 3 --out /abs/dir
##
## `--runs N` solves the same town N times IN ONE PROCESS and reports every
## run's ms plus the median. Runs 2..N are also compared against run 1's
## record, which is ruling 3's determinism probe: a static cache that outlives
## a solve, or an insertion order that depends on a previous town, shows up
## here as `IDENTITY ... same=false` rather than as a corpus that drifts a
## month later.
##
## `--production` additionally repeats TASK D2's production measurement --
## `VillageWarrenFabricSolver.solve` on the pinned settlement's real sampled
## heightfield -- which is ruling 5's before/after number.

## The sealed audit's four wall-clock keys. Ruling 2 exempts wall clock and
## nothing else; these are named one by one rather than matched by suffix, so
## a future `..._ms` key that is a COUNT of milliseconds of construction rather
## than a measurement of this machine still has to be argued for.
const WALL_CLOCK_KEYS: Dictionary = {
	"audit.maze_source_ms": true,
	"audit.maze_spatial_ms": true,
	"audit.maze_fabric_ms": true,
	"audit.maze_stage_ms": true,
}

const PRODUCTION_WORLD_SEED := 2697992464
const PRODUCTION_SUPER_CELL := Vector2i(0, -1)
const PRODUCTION_REGION_RADIUS := 5


func _init() -> void:
	var seeds: Array[int] = []
	var scale_ids: Array[StringName] = []
	var runs := 1
	var out_dir := ""
	var production := false
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--seeds" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				seeds.append(int(token.strip_edges()))
		elif args[index] == "--scale" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				scale_ids.append(StringName(token.strip_edges()))
		elif args[index] == "--runs" and index + 1 < args.size():
			runs = maxi(1, int(args[index + 1]))
		elif args[index] == "--out" and index + 1 < args.size():
			out_dir = args[index + 1]
		elif args[index] == "--production":
			production = true
	if seeds.is_empty():
		seeds = [12, 4]
	if scale_ids.is_empty():
		scale_ids = [WarrenVillageScaleProfile.COMPACT]
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir)

	# The vocabulary is compiled once per process and BEFORE any clock starts,
	# exactly as `test_warren_maze_composition.gd::_solve` does it, so the
	# numbers here and the numbers that file's ceilings hold are the same kind
	# of number.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	for city_seed: int in seeds:
		for scale_id: StringName in scale_ids:
			_measure(city_seed, scale_id, program, runs, out_dir)
	if production:
		_measure_production()
	quit()


func _measure(city_seed: int, scale_id: StringName,
		program: SettlementFabricProgram, runs: int, out_dir: String) -> void:
	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	var key := "%d-%s" % [city_seed, String(scale_id)]
	var samples: Array[int] = []
	var first_record := PackedStringArray()
	for run in runs:
		var started_ms := Time.get_ticks_msec()
		var plan := WarrenVolumetricSolver.solve(city_seed, {}, program,
			profile)
		var elapsed_ms := Time.get_ticks_msec() - started_ms
		samples.append(elapsed_ms)
		if plan == null:
			print("IDENTITY seed=%d scale=%s run=%d FAILED %s" % [city_seed,
				String(scale_id), run, WarrenVolumetricSolver.last_failure
					.left(160)])
			continue
		var record := _record(plan)
		if run == 0:
			first_record = record
			if not out_dir.is_empty():
				var path := "%s/%s.record.txt" % [out_dir, key]
				var file := FileAccess.open(path, FileAccess.WRITE)
				if file == null:
					print("IDENTITY unwritable path=%s" % path)
				else:
					file.store_string("\n".join(record) + "\n")
					file.close()
					print("IDENTITY seed=%d scale=%s wrote=%s lines=%d" % [
						city_seed, String(scale_id), path, record.size()])
		else:
			print("IDENTITY seed=%d scale=%s run=%d same=%s %s" % [city_seed,
				String(scale_id), run,
				str(_same(first_record, record)),
				_first_difference(first_record, record)])
	var sorted_samples := samples.duplicate()
	sorted_samples.sort()
	print("SOLVE seed=%d scale=%s runs=%s median_ms=%d" % [city_seed,
		String(scale_id), str(samples),
		sorted_samples[sorted_samples.size() / 2]])


func _record(plan: WarrenSpatialPlan) -> PackedStringArray:
	## Everything a town IS, in sorted lines. The signature halves are hashed
	## because a grid signature is megabytes of cells; every hash is over a
	## string this file did not build, so a change anywhere inside one still
	## shows up, and the per-building and per-unit lines say WHERE.
	var out := PackedStringArray()
	out.append("plan.stable_id = %s" % String(plan.stable_id))
	out.append("plan.world_seed = %d" % plan.world_seed)
	out.append("plan.signature_sha256 = %s" % plan.deterministic_signature()
		.sha256_text())
	out.append("plan.grid_sha256 = %s" % plan.grid.deterministic_signature()
		.sha256_text())
	out.append("plan.support_sha256 = %s" % plan.support_graph
		.deterministic_signature().sha256_text())
	out.append("plan.construction_sha256 = %s" % plan.construction_plan
		.deterministic_signature().sha256_text())
	out.append("plan.entry_floor_cell = %s" % str(plan.entry_floor_cell))
	out.append("plan.route_floor_cell_count = %d" % plan.route_floor_cells
		.size())
	var routes := PackedStringArray()
	for cell: Vector3i in plan.route_floor_cells:
		routes.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	out.append("plan.route_order_sha256 = %s" % ",".join(routes).sha256_text())
	routes.sort()
	out.append("plan.route_set_sha256 = %s" % ",".join(routes).sha256_text())
	out.append("plan.building_count = %d" % plan.buildings.size())
	for building: WarrenBuildingVolume in plan.buildings:
		out.append("building.%s = %s" % [String(building.stable_id),
			building.deterministic_signature().sha256_text()])
	out.append("plan.feature_count = %d" % plan.features.size())
	for feature: WarrenFeatureReservation in plan.features:
		out.append("feature.%s = %s" % [String(feature.stable_id),
			feature.deterministic_signature().sha256_text()])
	_flatten("audit", plan.audit, out)
	var fabric := plan.compiled_fabric_cache()
	if fabric == null:
		out.append("fabric = <none>")
	else:
		out.append("fabric.stable_id = %s" % String(fabric.stable_id))
		out.append("fabric.unit_count = %d" % fabric.units.size())
		for unit: FabricUnit in fabric.units:
			out.append("fabric.unit.%s = %s@%s/yaw%d/parents=%s/node=%s" % [
				String(unit.stable_id), String(unit.recipe_id),
				str(unit.lattice_origin), unit.yaw_quarters,
				",".join(_names(unit.parent_ids)),
				String(unit.public_node_id)])
		_flatten("fabric.audit", fabric.audit, out)
	out.sort()
	return out


static func _names(values: Array[StringName]) -> PackedStringArray:
	var out := PackedStringArray()
	for value: StringName in values:
		out.append(String(value))
	return out


static func _flatten(prefix: String, value: Variant,
		out: PackedStringArray) -> void:
	## One line per leaf, plus one `__keys` line per dictionary holding its
	## INSERTION ORDER. Ruling 3: a bucketed or cached rebuild can leave every
	## set equal and every order different, and a downstream loop over that
	## dictionary then builds a different town. The order is part of the
	## record, so a reordering is a failed identity check rather than a
	## surprise three commits later.
	##
	## The four wall-clock keys are the ONLY exemption (ruling 2), and their
	## names still appear in their parent's `__keys` line, so a new timing key
	## leaking into a sealed audit is a failed identity check rather than a
	## second exemption.
	if WALL_CLOCK_KEYS.has(prefix):
		return
	if value is Dictionary:
		var dict := value as Dictionary
		var keys := PackedStringArray()
		for key: Variant in dict.keys():
			keys.append(str(key))
			_flatten(prefix + "." + str(key), dict[key], out)
		out.append(prefix + ".__keys = " + ",".join(keys))
	elif value is Array:
		var array := value as Array
		for index in array.size():
			_flatten("%s[%d]" % [prefix, index], array[index], out)
		out.append(prefix + ".__size = " + str(array.size()))
	else:
		# `var_to_str` round-trips every value this audit carries -- floats at
		# full precision, Vector3i and StringName unambiguously -- and never
		# runs the result through a format string, so a `%` inside an audit
		# value cannot break the record.
		out.append(prefix + " = " + var_to_str(value))


static func _same(left: PackedStringArray,
		right: PackedStringArray) -> bool:
	if left.size() != right.size():
		return false
	for index in left.size():
		if left[index] != right[index]:
			return false
	return true


static func _first_difference(left: PackedStringArray,
		right: PackedStringArray) -> String:
	for index in mini(left.size(), right.size()):
		if left[index] != right[index]:
			return "first_diff=[%s] vs [%s]" % [left[index].left(120),
				right[index].left(120)]
	if left.size() == right.size():
		return ""
	return "line_count=%d vs %d" % [left.size(), right.size()]


func _measure_production() -> void:
	## TASK D2's measurement, repeated: the pinned settlement's real sampled
	## heightfield through `VillageWarrenFabricSolver.solve`, which is the
	## entry the terrain worker calls. The site build is timed separately
	## because it is not a fact about a town.
	var site_started_ms := Time.get_ticks_msec()
	var water := TerrainWorldTuning.make_water(PRODUCTION_WORLD_SEED)
	var site := SettlementPlan.new(PRODUCTION_WORLD_SEED,
		water).site_for(PRODUCTION_SUPER_CELL)
	if site.is_empty():
		print("PRODUCTION site=NONE")
		return
	var cell := site.cell as Vector2i
	var region := TerrainWorldTuning.make_heightfield(PRODUCTION_WORLD_SEED,
		water).compute_region(cell.x, cell.y, PRODUCTION_REGION_RADIUS)
	var village_program := VillageProgram.compile({},
		EnvironmentCatalog.load_default())
	if village_program == null:
		print("PRODUCTION program=NONE")
		return
	var context := WaterFieldContext.new()
	context._ctx = {"ponds": [], "rivers": [], "buckets": {},
		"region": region}
	context._region = region
	var centre := Vector2(cell) * TerrainSurfaceField.TILE
	var radius := float(PRODUCTION_REGION_RADIUS) * TerrainSurfaceField.TILE
	context._coverage = Rect2(centre - Vector2.ONE * radius,
		Vector2.ONE * radius * 2.0)
	context._shore_limit = 0.0
	var frame := VillageFrame.from_mask(site, 1, region, context)
	var terrain := VillageTerrainView.from_region(region)
	var city_seed := VillagePlan.new(PRODUCTION_WORLD_SEED,
		village_program)._warren_seed(frame)
	print("PRODUCTION site=%s cell=%s city_seed=%d site_ms=%d" % [
		String(frame.settlement_id), str(cell), city_seed,
		Time.get_ticks_msec() - site_started_ms])
	for run in 3:
		var started_ms := Time.get_ticks_msec()
		var urban := VillageWarrenFabricSolver.solve(terrain, city_seed,
			frame.settlement_id, frame.centre, Vector2.RIGHT, village_program)
		var elapsed_ms := Time.get_ticks_msec() - started_ms
		print("PRODUCTION run=%d ms=%d accepted=%s entries=%d signature=%s" % [
			run, elapsed_ms,
			str(urban != null and urban.accepted),
			0 if urban == null else urban.entries.size(),
			"" if urban == null or urban.volumetric_spatial == null \
				else urban.volumetric_spatial.deterministic_signature()
					.sha256_text()])

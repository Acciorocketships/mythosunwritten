extends SceneTree
## Layout metrics over the town corpus (dead ends, openness, intricacy).
##   godot --headless --path . -s res://tests/harness/layout_judging/layout_corpus.gd -- \
##     --seeds 1,2,...,12 [--scale compact,standard,large,grand | --scale select] [--out FILE]
## Without --scale (or with `select`) each seed uses the production profile roll.
const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

func _init() -> void: call_deferred("_run")


func _run() -> void:
	var seeds: Array[int] = []
	var scales: Array[StringName] = [&""]
	var out := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--seeds":
				for part in args[i + 1].split(","):
					if "-" in part:
						for s in range(int(part.get_slice("-", 0)), int(part.get_slice("-", 1)) + 1):
							seeds.append(s)
					else:
						seeds.append(int(part))
			"--scale":
				scales.clear()
				for part in args[i + 1].split(","):
					scales.append(&"" if part == "select" else StringName(part))
			"--out": out = args[i + 1]
	if seeds.is_empty():
		push_error("layout_corpus: no --seeds")
		quit(2)
		return
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var rows: Array[Dictionary] = []
	for seed_value in seeds:
		for scale in scales:
			var profile := WarrenVillageScaleProfile.select(seed_value) if scale == &"" \
				else WarrenVillageScaleProfile.for_id(scale)
			var started := Time.get_ticks_msec()
			var plan := WarrenVolumetricSolver.generate(seed_value, {}, program, profile)
			var row := {"seed": seed_value, "scale": String(scale if scale != &"" else &"select"),
				"profile": String(profile.scale_id), "ms": Time.get_ticks_msec() - started,
				"sealed": plan != null}
			if plan == null:
				row["failure"] = WarrenVolumetricSolver.last_failure
				print("ROW ", row)
				rows.append(row)
				continue
			row.merge(measure(plan))
			print("ROW ", row)
			rows.append(row)
	_summarize(rows)
	if not out.is_empty():
		var file := FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify(rows, " "))
	quit()


static func measure(plan: WarrenSpatialPlan) -> Dictionary:
	var fabric := plan.compiled_fabric_cache()
	var source: WarrenMazeSourcePlan = plan.source_volume.mass_context.get(&"maze_source_plan")
	var out: Dictionary = {}
	var walk := PublicWalkAudit.audit(fabric, plan)
	out["dead_end_nodes"] = walk.summary.dead_end_nodes
	out["dead_end_cells"] = walk.summary.dead_end_cells
	out["dead_ends"] = walk.dead_ends.map(func(d: Dictionary) -> String: return "%s:%d" % [d.id, d.cells])
	# --- Massif shape (issue 3) ---
	var massif := source.massif
	var cols: Dictionary = massif.columns
	var bounds := Rect2i()
	var first := true
	for c: Vector2i in cols:
		if first:
			bounds = Rect2i(c, Vector2i.ONE)
			first = false
		else:
			bounds = bounds.expand(c).expand(c + Vector2i.ONE)
	var area := bounds.get_area()
	var air_in_box: Dictionary = {}
	for x in range(bounds.position.x, bounds.end.x):
		for z in range(bounds.position.y, bounds.end.y):
			if not cols.has(Vector2i(x, z)):
				air_in_box[Vector2i(x, z)] = true
	out["columns"] = cols.size()
	out["open_fraction"] = snappedf(float(air_in_box.size()) / maxf(1.0, float(area)), 0.001)
	var interior := _components(air_in_box, bounds, true)
	out["interior_clearings"] = interior.size()
	out["largest_clearing"] = 0 if interior.is_empty() else interior.map(func(a): return a.size()).max()
	var tall: Dictionary = {}
	var max_layer := 0
	for c: Vector2i in cols:
		max_layer = maxi(max_layer, massif.layer_at(c))
	for c: Vector2i in cols:
		if massif.layer_at(c) >= maxi(4, max_layer / 2):
			tall[c] = true
	var tall_components := _components(tall, Rect2i(), false)
	out["high_massifs"] = tall_components.filter(func(a): return a.size() >= 3).size()
	out["max_layer"] = max_layer
	var ground_level := 0
	for c: Vector2i in cols:
		if massif.layer_at(c) <= 2:
			ground_level += 1
	out["low_fraction"] = snappedf(float(ground_level) / maxf(1.0, float(cols.size())), 0.001)
	# --- Route intricacy (issue 4) ---
	var ex := source.excavation
	out["tunnel_cells"] = ex.tunnel_cells.size()
	var covered := 0
	for cell: Vector3i in ex.covered:
		if bool(ex.covered[cell]):
			covered += 1
	out["covered_source_cells"] = covered
	out["bridge_spans"] = ex.bridge_spans.size()
	out["lanes"] = ex.lanes.size()
	out["loop_edges"] = ex.loop_edges.size()
	var volume := plan.source_volume
	out["walk_macros"] = volume.walk_cells.size()
	var vertical := 0
	for t: WarrenVolumeTransition in volume.transitions:
		if t.is_vertical():
			vertical += 1
	out["vertical_transitions"] = vertical
	var levels: Dictionary = {}
	for cell: Vector3i in volume.walk_cells:
		levels[cell.y] = true
	out["walk_levels"] = levels.size()
	out["turns_per_10"] = snappedf(_turn_rate(ex), 0.01)
	var realm := fabric.public_realm
	out["cycle_rank"] = realm.edges.size() - realm.nodes.size() + 1
	var walked := SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)
	var inhabited := fabric.inhabited_room_cells()
	var inhabited_columns: Dictionary = {}
	for cell: Vector3i in inhabited:
		var key := Vector2i(cell.x, cell.z)
		inhabited_columns[key] = maxi(int(inhabited_columns.get(key, -999)), cell.y)
	var under := 0
	for cell: Vector3i in walked:
		if int(inhabited_columns.get(Vector2i(cell.x, cell.z), -999)) > cell.y + 1:
			under += 1
	out["walked_cells"] = walked.size()
	out["walked_under_inhabited"] = under
	out["under_ratio"] = snappedf(float(under) / maxf(1.0, float(walked.size())), 0.001)
	out["skywalks"] = int(fabric.audit.get("maze_skywalk_span_count", 0)) \
		+ int(fabric.audit.get("modular_box_skywalk_count", 0))
	out["bridge_rooms"] = int(plan.audit.get("maze_bridge_rooms", 0))
	out["buildings"] = plan.buildings.size()
	return out


static func _turn_rate(ex: WarrenExcavation) -> float:
	var paths: Array = [ex.route]
	for lane: Dictionary in ex.lanes:
		var cells: Array = [lane.anchor]
		cells.append_array(lane.cells)
		paths.append(cells)
	var turns := 0
	var cells := 0
	for path: Array in paths:
		var last := Vector2i.ZERO
		for i in range(1, path.size()):
			var d := Vector2i((path[i] as Vector3i).x - (path[i - 1] as Vector3i).x,
				(path[i] as Vector3i).z - (path[i - 1] as Vector3i).z).sign()
			if d == Vector2i.ZERO:
				continue
			cells += 1
			if last != Vector2i.ZERO and d != last:
				turns += 1
			last = d
	return 10.0 * float(turns) / maxf(1.0, float(cells))


static func _components(cells: Dictionary, bounds: Rect2i, interior_only: bool) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for start: Vector2i in cells:
		if seen.has(start):
			continue
		var members: Array[Vector2i] = [start]
		seen[start] = true
		var touches := false
		var i := 0
		while i < members.size():
			var c: Vector2i = members[i]
			i += 1
			if interior_only and (c.x == bounds.position.x or c.y == bounds.position.y \
					or c.x == bounds.end.x - 1 or c.y == bounds.end.y - 1):
				touches = true
			for d: Vector2i in CARDINALS:
				var n := c + d
				if cells.has(n) and not seen.has(n):
					seen[n] = true
					members.append(n)
		if not (interior_only and touches):
			out.append(members)
	return out


static func _summarize(rows: Array[Dictionary]) -> void:
	var keys := ["dead_end_nodes", "dead_end_cells", "columns", "open_fraction",
		"interior_clearings", "largest_clearing", "high_massifs", "low_fraction",
		"tunnel_cells", "covered_source_cells", "bridge_spans", "lanes", "loop_edges",
		"walk_macros", "vertical_transitions", "walk_levels", "turns_per_10",
		"cycle_rank", "walked_cells", "walked_under_inhabited", "under_ratio",
		"skywalks", "bridge_rooms", "buildings", "ms"]
	var sealed := rows.filter(func(r): return r.sealed)
	print("SUMMARY sealed=%d/%d" % [sealed.size(), rows.size()])
	for key in keys:
		var values: Array = sealed.map(func(r): return float(r.get(key, 0)))
		if values.is_empty():
			continue
		var mean := 0.0
		for v in values: mean += v
		mean /= values.size()
		var variance := 0.0
		for v in values: variance += (v - mean) * (v - mean)
		variance /= values.size()
		print("SUMMARY %s mean=%.3f sd=%.3f min=%.3f max=%.3f total=%.1f" % [key, mean,
			sqrt(variance), values.min(), values.max(), mean * values.size()])

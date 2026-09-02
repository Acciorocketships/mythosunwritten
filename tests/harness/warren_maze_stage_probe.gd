extends SceneTree

var _trace_roof_closures := false
var _trace_roof_room := StringName()
var _trace_bridges := false

## How far does a town actually get before a gate discards it, and
## WHERE does the wall clock go? Walks the solid-first pipeline stage by stage
## and reports what EXISTS at each step, so "the carver makes nothing" can be
## told apart from "the carver makes a town that a downstream feature
## requirement then throws away".
##
##   Godot --headless --path . -s res://tests/harness/warren_maze_stage_probe.gd -- \
##     --seeds 1,2,3,4,5,6,7,8,9
##
## `--scale compact,standard` runs every seed at each named profile instead of
## the one `WarrenVillageScaleProfile.select()` rolls for it, which is how the
## four planner seeds (12/4 compact, 3/9 standard) are measured.
##
## TASK C6 RULING 4. Every stage is timed, and the COMPOSITION is broken down
## into the sub-stages the solver stamps into `plan.audit.maze_stage_ms` while
## it runs (parcels, hero beam, room composition, residual/back rooms, feature
## pass, authored room envelope gate). The probe drives `from_volume` itself,
## so it reads those stamps off `WarrenVolumetricSolver.last_maze_stage_ms`
## rather than needing a second production solve.

func _init() -> void:
	var seeds: Array[int] = []
	var scale_ids: Array[StringName] = []
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--seeds" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				seeds.append(int(token.strip_edges()))
		elif args[index] == "--scale" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				scale_ids.append(StringName(token.strip_edges()))
		elif args[index] == "--trace-fabric":
			# TASK F2 RULING 1. The compile is the second cost and `solve` is a
			# fifteen-step pipeline; this names the step.
			WarrenSpatialFabricCompiler.diagnostic_trace_timing = true
		elif args[index] == "--trace-composition":
			# TASK F2 RULING 1. `room_composition` is one stamp over two very
			# different things -- the per-parcel exact block preflight and the
			# whole room-grammar solve -- and the planner already knows how to
			# break the second one down. This turns that on, which is how the
			# composition's inner loops are named rather than guessed at.
			WarrenRoomCompositionPlanner.diagnostic_trace = true
		elif args[index] == "--trace-roof-closures":
			_trace_roof_closures = true
		elif args[index] == "--trace-roof-room" and index + 1 < args.size():
			_trace_roof_closures = true
			_trace_roof_room = StringName(args[index + 1])
		elif args[index] == "--trace-bridges":
			_trace_bridges = true
	if seeds.is_empty():
		seeds = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	if scale_ids.is_empty():
		# The empty id means "whatever this seed rolls" — the profile
		# production would actually pick for it.
		scale_ids = [StringName()]

	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	for city_seed: int in seeds:
		for scale_id: StringName in scale_ids:
			_probe(city_seed, scale_id, program)
	quit()


func _probe(city_seed: int, scale_id: StringName,
		program: SettlementFabricProgram) -> void:
	var profile := WarrenVillageScaleProfile.select(city_seed) \
		if scale_id == StringName() \
		else WarrenVillageScaleProfile.for_id(scale_id)
	var line := "STAGE seed=%d scale=%s" % [city_seed,
		String(profile.scale_id)]
	# Every stamped sub-stage belongs to ONE town, so the accumulator is reset
	# here exactly as `_solve_maze` resets it in production.
	WarrenVolumetricSolver.last_maze_stage_ms = {}
	var timings: Array[String] = []

	var started_ms := Time.get_ticks_msec()
	var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
	timings.append("massif=%d" % (Time.get_ticks_msec() - started_ms))
	if massif == null:
		print(line + " massif=REJECTED")
		return
	line += " massif=ok"

	# The SOURCE is the site planner's whole one-pass pipeline, not the bare
	# bore: `WarrenMazeCarver.carve` alone returns a plan with no plots, and the
	# block partitioner rightly refuses one. Walked stage by stage here rather
	# than through `WarrenMazeSitePlanner.plan` so each phase is timed, in
	# exactly the order that function runs them.
	started_ms = Time.get_ticks_msec()
	var maze := WarrenMazeCarver.carve(city_seed, massif, profile, false)
	timings.append("carve=%d" % (Time.get_ticks_msec() - started_ms))
	if maze == null:
		print(line + " carve=REJECTED:" + WarrenMazeCarver.last_failure.left(70))
		return
	var bridge_seeded := maze.excavation.bridge_span_audit.get("seeded", []) \
		as Array
	var bridge_refused := maze.excavation.bridge_span_audit.get("refused", []) \
		as Array
	line += " carve=ok source_bridges=%d bridge_refusals=%d" % [
		maze.excavation.bridge_spans.size(), bridge_refused.size()]
	if _trace_bridges:
		var bridge_reasons: Dictionary = {}
		for refusal_value: Variant in bridge_refused:
			var reason := String((refusal_value as Dictionary).get("reason", ""))
			bridge_reasons[reason] = int(bridge_reasons.get(reason, 0)) + 1
		print("BRIDGE_CANDIDATES seed=%d scale=%s legal=%d reasons=%s" % [
			city_seed, String(profile.scale_id), int(maze.excavation \
				.bridge_span_audit.get("legal_candidate_count", 0)),
			JSON.stringify(bridge_reasons)])
	if bridge_seeded.size() != maze.excavation.bridge_spans.size():
		print("BRIDGE_LEDGER_MISMATCH seed=%d scale=%s spans=%d seeded=%d" % [
			city_seed, String(profile.scale_id),
			maze.excavation.bridge_spans.size(), bridge_seeded.size()])
	if not bridge_seeded.is_empty():
		print("BRIDGE_SOURCE seed=%d scale=%s %s" % [city_seed,
			String(profile.scale_id), JSON.stringify(bridge_seeded)])

	started_ms = Time.get_ticks_msec()
	WarrenPlotPlanner.reserve(maze, profile)
	WarrenPlotPlanner.partition(maze, profile)
	if _trace_bridges:
		print("BRIDGE_PLOTS seed=%d scale=%s %s" % [city_seed,
			String(profile.scale_id), JSON.stringify((maze.audit.get(
				"plot_outcomes", {}) as Dictionary).get("bridges", []))])
	timings.append("plots=%d" % (Time.get_ticks_msec() - started_ms))
	if not maze.seal():
		print(line + " plots=REJECTED:" + maze.last_rejection.left(70))
		return
	line += " plots=%d" % maze.plots.size()

	started_ms = Time.get_ticks_msec()
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(maze)
	timings.append("adapt=%d" % (Time.get_ticks_msec() - started_ms))
	if volume == null:
		print(line + " adapt=REJECTED:" \
			+ WarrenMazeVolumeAdapter.last_failure.left(70))
		return
	line += " adapt=ok"
	var bridge_compounds := WarrenVolumetricSolver \
		._maze_bridge_compound_plans(volume)
	for compound_value: Variant in bridge_compounds.get("plans", []) as Array:
		var compound := compound_value as Dictionary
		var endpoint_support: Array[Dictionary] = []
		for group_value: Variant in compound.get("endpoint_groups", []) as Array:
			var group: Array[Vector2i] = []
			group.assign(group_value as Array)
			var columns: Array[Dictionary] = []
			for column: Vector2i in group:
				var bearing := volume.envelope.bearing_at(column)
				var floor_band := int(compound.floor)
				var whole := true
				for band in range(bearing, floor_band):
					whole = whole and volume.has_mass(Vector3i(column.x,
						band, column.y))
				columns.append({"column": column, "bearing": bearing,
					"floor": floor_band, "whole": whole,
					"below": volume.has_mass(Vector3i(column.x,
						floor_band - 1, column.y))})
			endpoint_support.append({"columns": columns})
		print("BRIDGE_SUPPORT_SOURCE seed=%d scale=%s %s" % [city_seed,
			String(profile.scale_id), JSON.stringify(endpoint_support)])

	# The parcels ARE the buildings: this is the "substitute groups of grid
	# cells for houses" step. If this succeeds, a town physically exists.
	var parcels := WarrenTownSolver.partition_parcels(volume)
	if parcels == null:
		print(line + " parcels=REJECTED:" \
			+ WarrenTownSolver.last_partition_failure.left(4000))
		return
	line += " parcels=%d" % parcels.parcels.size()

	started_ms = Time.get_ticks_msec()
	var plan := WarrenVolumetricSolver.from_volume(volume, -1, program,
		profile.requires_elevated_courtyard)
	var compose_ms := Time.get_ticks_msec() - started_ms
	timings.append("compose=%d" % compose_ms)
	if plan == null:
		print(line + " compose=REJECTED:" \
			+ WarrenVolumetricSolver.last_failure.left(4000))
		if not WarrenSpatialFabricCompiler.last_audit.is_empty():
			print("COMPOSE_ROOM_AUDIT seed=%d scale=%s %s" % [city_seed,
				String(profile.scale_id), JSON.stringify(
					WarrenSpatialFabricCompiler.last_audit)])
		print("STAGE_MS seed=%d scale=%s %s %s" % [city_seed,
			String(profile.scale_id), " ".join(timings),
			_sub_stages(compose_ms)])
		return
	var room_count := 0
	for building: WarrenBuildingVolume in plan.buildings:
		room_count += building.room_records.size()
	line += " buildings=%d rooms=%d bridge_rooms=%d planned_skywalks=%d" % [
		plan.buildings.size(), room_count,
		int(plan.audit.get("maze_bridge_rooms", 0)),
		int(plan.audit.get("preplanned_skywalk_count", 0))]
	if maze.excavation.bridge_spans.size() > 0:
		print("BRIDGE_OUTCOMES seed=%d scale=%s %s" % [city_seed,
			String(profile.scale_id), JSON.stringify(plan.audit.get(
				"maze_bridge_outcomes", []))])
	if _trace_roof_closures:
		var closures := WarrenSpatialFabricCompiler \
			.required_roof_closure_options(plan.grid, plan.buildings, program,
				plan.world_seed)
		var shown: Array[Dictionary] = []
		for closure: Dictionary in closures:
			if not _trace_roof_room.is_empty() \
					and StringName(closure.owner_room_id) != _trace_roof_room:
				continue
			shown.append(closure)
		print("ROOF_CLOSURES seed=%d scale=%s count=%d %s" % [city_seed,
			String(profile.scale_id), closures.size(), JSON.stringify(shown)])
		var filtered: Array[Dictionary] = []
		for closure_value: Variant in WarrenSpatialFeatureSolver \
				.last_skywalk_diagnostic.get("required_roof_closures", []):
			var closure := closure_value as Dictionary
			if not _trace_roof_room.is_empty() \
					and StringName(closure.owner_room_id) != _trace_roof_room:
				continue
			filtered.append(closure)
		print("FEATURE_ROOF_CLOSURES seed=%d scale=%s count=%d %s" % [
			city_seed, String(profile.scale_id), int(WarrenSpatialFeatureSolver \
				.last_skywalk_diagnostic.get("required_roof_closure_count", 0)),
			JSON.stringify(filtered)])

	started_ms = Time.get_ticks_msec()
	var fabric := WarrenSpatialFabricCompiler.solve(plan, program)
	timings.append("fabric=%d" % (Time.get_ticks_msec() - started_ms))
	if fabric == null:
		print(line + " fabric=REJECTED:" \
			+ WarrenSpatialFabricCompiler.last_failure.left(4000))
		print("STAGE_MS seed=%d scale=%s %s %s" % [city_seed,
			String(profile.scale_id), " ".join(timings),
			_sub_stages(compose_ms)])
		return
	var route_holes := _route_support_holes(plan, fabric)
	if not route_holes.is_empty():
		print("ROUTE_SUPPORT_HOLES seed=%d scale=%s %s" % [city_seed,
			String(profile.scale_id), JSON.stringify(route_holes)])
	line += " open_skywalks=%d occupied_skywalks=%d" % [int(
		fabric.audit.get("maze_skywalk_span_count", 0)), int(
		fabric.audit.get("modular_box_skywalk_count", 0))]
	print(line + " fabric=ok SEALED")
	print("STAGE_MS seed=%d scale=%s %s %s" % [city_seed,
		String(profile.scale_id), " ".join(timings),
		_sub_stages(compose_ms)])


func _sub_stages(compose_ms: int) -> String:
	## The composition's own breakdown, plus the REMAINDER — the grid
	## projection, the public carve, the lineage/volume build, the shell
	## derivation and the seal — so the parts always add up to the whole and a
	## missing stamp can never hide inside a plausible-looking table.
	var stamps := WarrenVolumetricSolver.last_maze_stage_ms
	var ordered: Array[StringName] = [&"parcels", &"hero_beam",
		&"room_composition", &"residual_rooms", &"feature_solver",
		&"room_gate"]
	var parts := PackedStringArray()
	var accounted := 0
	for stage: StringName in ordered:
		var value := int(stamps.get(stage, -1))
		parts.append("%s=%d" % [String(stage), value])
		# `partition_rooms` is the sum of the three stages inside it plus its
		# own lineage build; counting it here would double every one of them.
		if value > 0 and stage != &"hero_beam":
			accounted += value
	accounted += int(stamps.get(&"hero_beam", 0))
	parts.append("other=%d" % maxi(0, compose_ms - accounted))
	return " ".join(parts)


func _route_support_holes(plan: WarrenSpatialPlan,
		fabric: SettlementFabricPlan) -> Array[Dictionary]:
	## Diagnostic mirror of the corpus gate: name the surface classification of
	## every public floor whose lower band is genuinely empty and has no explicit
	## support datum. This makes a floating court distinguishable from a stair
	## transition or a deliberately terrain-borne street in one probe run.
	var out: Array[Dictionary] = []
	var solids := fabric.transformed_cells(&"solid")
	var retained := fabric.retained_terrace_cells
	var maze_source := plan.source_volume.mass_context.get(
		&"maze_source_plan") as WarrenMazeSourcePlan if plan.source_volume != null \
		else null
	for cell: Vector3i in plan.route_floor_cells:
		var below := cell + Vector3i.DOWN
		var macro_column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		var on_terrain: bool = maze_source != null and maze_source.massif != null \
			and maze_source.massif.has_column(macro_column) \
			and below.y < maze_source.massif.base_at(macro_column)
		if plan.grid.use_at(below) != WarrenSpatialGrid.Use.OUTSIDE \
				or solids.has(below) or retained.has(below) or on_terrain:
			continue
		var supported := fabric.surface_plan != null \
			and fabric.surface_plan.has_cell(cell) \
			and (fabric.surface_plan.has_support_base(cell) \
				or fabric.surface_plan.has_transition_geometry(cell))
		if supported:
			continue
		out.append({"cell": cell, "below": below,
			"surface_kind": fabric.surface_plan.kind_at(cell) \
				if fabric.surface_plan != null else -1,
			"has_surface": fabric.surface_plan != null \
				and fabric.surface_plan.has_cell(cell)})
		if out.size() >= 16:
			break
	return out

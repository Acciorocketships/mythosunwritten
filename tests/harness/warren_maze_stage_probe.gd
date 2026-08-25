extends SceneTree

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
		elif args[index] == "--trace-composition":
			# TASK F2 RULING 1. `room_composition` is one stamp over two very
			# different things -- the per-parcel exact block preflight and the
			# whole room-grammar solve -- and the planner already knows how to
			# break the second one down. This turns that on, which is how the
			# composition's inner loops are named rather than guessed at.
			WarrenRoomCompositionPlanner.diagnostic_trace = true
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
	line += " carve=ok"

	started_ms = Time.get_ticks_msec()
	WarrenPlotPlanner.reserve(maze, profile)
	WarrenPlotPlanner.partition(maze, profile)
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

	# The parcels ARE the buildings: this is the "substitute groups of grid
	# cells for houses" step. If this succeeds, a town physically exists.
	var parcels := WarrenTownSolver.partition_parcels(volume)
	if parcels == null:
		print(line + " parcels=REJECTED:" \
			+ WarrenTownSolver.last_partition_failure.left(70))
		return
	line += " parcels=%d" % parcels.parcels.size()

	started_ms = Time.get_ticks_msec()
	var plan := WarrenVolumetricSolver.from_volume(volume, -1, program,
		profile.requires_elevated_courtyard)
	var compose_ms := Time.get_ticks_msec() - started_ms
	timings.append("compose=%d" % compose_ms)
	if plan == null:
		print(line + " compose=REJECTED:" \
			+ WarrenVolumetricSolver.last_failure.left(90))
		print("STAGE_MS seed=%d scale=%s %s %s" % [city_seed,
			String(profile.scale_id), " ".join(timings),
			_sub_stages(compose_ms)])
		return
	var room_count := 0
	for building: WarrenBuildingVolume in plan.buildings:
		room_count += building.room_records.size()
	line += " buildings=%d rooms=%d" % [plan.buildings.size(), room_count]

	started_ms = Time.get_ticks_msec()
	var fabric := WarrenSpatialFabricCompiler.solve(plan, program)
	timings.append("fabric=%d" % (Time.get_ticks_msec() - started_ms))
	if fabric == null:
		print(line + " fabric=REJECTED:" \
			+ WarrenSpatialFabricCompiler.last_failure.left(90))
		print("STAGE_MS seed=%d scale=%s %s %s" % [city_seed,
			String(profile.scale_id), " ".join(timings),
			_sub_stages(compose_ms)])
		return
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

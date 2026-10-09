extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_instrument()
	var seed_value := 2697992464
	preload("res://scripts/terrain/field/PlanningDiskCache.gd").configure(seed_value)
	preload("res://scripts/native/NativeGridKernels.gd").setup()
	preload("res://scripts/native/NativeTileKernel.gd").setup()
	preload("res://scripts/terrain/field/CliffRockStyle.gd").apply("sheet_bedrock")
	var water := TerrainWorldTuning.make_water(seed_value)
	var plan := TerrainWorldTuning.make_heightfield(seed_value, water)
	var catalog := EnvironmentCatalog.load_default()
	var program := DressingCompiler.compile(load("res://terrain/dressing/index.tres"), catalog)
	var feature_program := FeatureProgram.compile(catalog)
	var fields := WorldFieldBlockCache.new(
		plan,
		water,
		maxf(program.query_margin, feature_program.query_margin),
		maxf(program.shore_distance_limit, feature_program.shore_distance_limit),
		feature_program.field_cache_cap
	)
	var features := WorldFeaturePlan.new(
		seed_value, water, fields, feature_program, SettlementPlan.new(seed_value, water)
	)
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(seed_value)
	mesher.profile_enabled = true
	mesher.prepare_resources()
	var chunks: Array[Vector2i] = [Vector2i(-3, 0), Vector2i(-2, -4)]
	if not OS.get_cmdline_user_args().is_empty():
		var pair := OS.get_cmdline_user_args()[0].split(",")
		chunks = [Vector2i(int(pair[0]), int(pair[1]))]
	for chunk: Vector2i in chunks:
		print("TAIL_PROFILE_BEGIN ", chunk)
		var started := Time.get_ticks_usec()
		var feature_context := features.context_for(chunk)
		var region: HeightfieldRegion = feature_context.graded_region(fields.region(chunk))
		var water_context := fields.water(chunk)
		var view_keys: Array[Vector2i] = []
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				view_keys.append(chunk + Vector2i(dx, dz))
		mesher.water_blocks = fields.frozen_view(view_keys)
		var planned := Time.get_ticks_usec()
		print("TAIL_PROFILE_PLANNED ", chunk, " ms=", (planned - started) / 1000.0)
		var terrain := mesher.compute_chunk(chunk, region, water_context, feature_context)
		var terrain_done := Time.get_ticks_usec()
		print(
			"TAIL_PROFILE_TERRAIN ",
			chunk,
			" ms=",
			(terrain_done - planned) / 1000.0,
			" profile=",
			terrain.profile
		)
		var sheet := WaterSurfaceBuilder.new().compute_chunk(water, chunk, region, water_context)
		var water_done := Time.get_ticks_usec()
		print(
			"TAIL_PROFILE_WATER ",
			chunk,
			" ms=",
			(water_done - terrain_done) / 1000.0,
			" hash=",
			preload("res://tests/harness/profile_mesh_phases.gd").payload_hash(
				{"arrays": sheet.get("arrays", [])}
			)
		)
		var dressing_features := feature_context
		if not terrain.structure_clearance.is_empty():
			dressing_features = feature_context.extended(
				[], terrain.structure_clearance, EnvironmentInstancePayload.new(), Rect2()
			)
		var dressing := DressingField.compute(
			program,
			seed_value,
			Rect2(Vector2(chunk) * 192, Vector2.ONE * 192),
			region,
			water_context,
			dressing_features,
			terrain.cliff_terraces.ground_reservations
		)
		var dressing_done := Time.get_ticks_usec()
		print("TAIL_PROFILE_DRESSING ", chunk, " ms=", (dressing_done - water_done) / 1000.0)
		var supports: Array = terrain.cliff_terraces.grass_supports.duplicate()
		for skirt: Dictionary in dressing.ground_skirts:
			supports.append(skirt.grass_support)
		var sampling := GrassSamplingContext.detached(
			region, water_context, dressing_features, supports
		)
		var finished := Time.get_ticks_usec()
		print(
			"TAIL_PROFILE_GRASS ",
			chunk,
			" ms=",
			(finished - dressing_done) / 1000.0,
			" total=",
			(finished - planned) / 1000.0
		)
		print(
			"TAIL_PROFILE_TERRAIN_HASH ",
			preload("res://tests/harness/profile_mesh_phases.gd").payload_hash(terrain)
		)
		sheet.clear()
		terrain.clear()
		dressing = null
		sampling = null
	quit()


func _instrument() -> void:
	var targets := {
		"res://scripts/terrain/field/CliffSlopeField.gd":
		[
			" for wall:Dictionary in walls:_add_wall(wall)",
			" _add_outer_corners(walls)",
			" _find_open_ends()",
			" _build_groups()",
			" _find_rocks()",
			" _thin_rocks()"
		],
		"res://scripts/terrain/field/CliffRockDressing.gd":
		[
			" var owned:=owned_rect(chunk)",
			" var slope:=SLOPE_FIELD.new",
			" var placements:Array[Dictionary]=slope.solid",
			" if not placements.is_empty():slope.add_skirts",
			" var collision:=PackedVector3Array()",
			" var reservations:Array[Rect2]=",
			" var supports:Array[Dictionary]=",
			" var slope_rocks:Dictionary={}",
			' return {"placements":placements'
		],
		"res://scripts/terrain/water/WaterSkin.gd":
		[
			"\tvar ctx: Dictionary = field_context.raw_context()",
			"\tvar curves: Array = WaterContour.curves",
			"\tvar buckets: Dictionary = _build_buckets",
			"\tvar lattice: Dictionary = _interior_lattice",
			"\t_interior_mesh(st, lattice)",
			"\t_seal_local_surface_holes(st)",
			"\tSURFACE_REFINEMENT.refine",
			"\tvar sampler_grid: Dictionary = _sampler_grid",
			"\tvar flow: Dictionary = _flow_frame_grid",
			"\tvar sampler := WaterSampler.build",
			"\tvar payload: Dictionary = _vertex_payload",
			'\treturn {"arrays": arrays, "triggers": _triggers(st)'
		]
	}
	for path: String in targets:
		var script := load(path) as GDScript
		var source := script.source_code
		for index in targets[path].size():
			var marker: String = targets[path][index]
			assert(source.contains(marker), marker)
			var indent := "\t" if marker.begins_with("\t") else " "
			var stamp := (
				indent
				+ 'print("TAIL_STAGE %s %d ",Time.get_ticks_usec())\n' % [path.get_file(), index]
			)
			source = source.replace("\n" + marker, "\n" + stamp + marker)
		script.source_code = source
		assert(script.reload(true) == OK)

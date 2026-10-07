# tests/harness/profile_mesh_phases.gd
# Attributes TerrainChunkMesher.compute_chunk ("terrain mesh payload" in
# profile_terrain.gd) to its sub-phases on a chunk subset, and fingerprints
# every payload so a performance change can be proved output-identical.
#   godot --headless --path . -s res://tests/harness/profile_mesh_phases.gd -- \
#     [--chunks "0,-1;1,-1"] [--detail] [--style sheet_bedrock]
#     [--hash-out f.txt] [--hash-check f.txt] [--seed N]
# Without --chunks it runs the 3x3 block x 0..2, z -1..1 of the profiler's seed.
# --detail re-runs the cliff dressing step by step (branch layout) after the
# timed mesher call; it does not affect the mesher timings or the hashes.
# Works on the pre-migration baseline too (no --detail there): only the
# mesher's own profile dictionary and phase callback are read.
extends SceneTree

var SEED := 3046246887
const AMP := TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE
const MAX_STOREYS := TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS
const MAX_STEP := TerrainWorldTuning.MAX_CLIFF_STEP

var _marks: Dictionary = {}

func _mark(_chunk: Vector2i, phase: StringName) -> void:
	_marks[phase] = Time.get_ticks_usec()

static func _feed(ctx: HashingContext, value) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			for key in value:
				_feed(ctx, key)
				_feed(ctx, value[key])
		TYPE_ARRAY:
			ctx.update(var_to_bytes(value.size()))
			for item in value:
				_feed(ctx, item)
		TYPE_OBJECT:
			ctx.update(String(value.get_class() if value != null else "null").to_utf8_buffer())
		TYPE_CALLABLE:
			pass
		_:
			ctx.update(var_to_bytes(value))

static func payload_hash(payload: Dictionary) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for key in payload:
		if key == "profile" or key == "profile_counts":
			continue
		_feed(ctx, key)
		_feed(ctx, payload[key])
	return ctx.finish().hex_encode()

func _chunks(args: PackedStringArray) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var at := args.find("--chunks")
	if at >= 0:
		for item in args[at + 1].split(";", false):
			var xz := item.split(",")
			out.append(Vector2i(int(xz[0]), int(xz[1])))
		return out
	for dz in range(-1, 2):
		for dx in range(0, 3):
			out.append(Vector2i(dx, dz))
	return out

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.find("--seed") >= 0:
		SEED = int(args[args.find("--seed") + 1])
	# As the streamer does: the C# grid kernels when the .NET build has them.
	preload("res://scripts/native/NativeGridKernels.gd").setup()
	print("native grid kernels: ", preload("res://scripts/native/NativeGridKernels.gd").enabled)
	# The baseline's default cliff style was not the game's (`sheet_bedrock`,
	# set by world.tscn); pass --style sheet_bedrock there for a fair comparison.
	var style_at := args.find("--style")
	if style_at >= 0:
		load("res://scripts/terrain/field/CliffRockStyle.gd").apply(args[style_at + 1])
	var water := WaterPlan.new(SEED, AMP, MAX_STOREYS)
	var settlements := SettlementPlan.new(SEED, water)
	var plan := HeightfieldPlan.new(SEED, AMP, MAX_STOREYS, "mean", MAX_STEP)
	plan.set_water_plan(water)
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(SEED)
	mesher.profile_enabled = true
	mesher.phase_callback = Callable(self, "_mark")
	var catalog := EnvironmentCatalog.load_default()
	var index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var dressing_program := DressingCompiler.compile(index, catalog)
	var feature_program := FeatureProgram.compile(catalog)
	var fields := WorldFieldBlockCache.new(plan, water,
		maxf(dressing_program.query_margin, feature_program.query_margin),
		maxf(dressing_program.shore_distance_limit, feature_program.shore_distance_limit),
		feature_program.field_cache_cap)
	var features := WorldFeaturePlan.new(SEED, water, fields, feature_program, settlements)
	if "water_blocks" in mesher:
		mesher.water_blocks = fields  # as FieldTerrainStreamer wires it
	mesher.prepare_resources()
	var detail := args.has("--detail")
	var hashes: Array[String] = []
	var totals: Dictionary = {}
	for chunk: Vector2i in _chunks(args):
		var feature_context := features.context_for(chunk)
		var region: HeightfieldRegion = feature_context.graded_region(fields.region(chunk))
		var context := fields.water(chunk)
		_marks.clear()
		var started := Time.get_ticks_usec()
		var payload := mesher.compute_chunk(chunk, region, context, feature_context)
		var finished := Time.get_ticks_usec()
		var prof: Dictionary = payload.profile
		var row := {
			"total": finished - started,
			"sheet (excl paths)": int(prof.surface) - int(prof.paths),
			"paths": prof.paths,
			"normals": prof.normals,
			"walls": prof.get("walls", prof.get("aprons_and_walls", 0)),
			"arches": int(_marks[&"cliff_formations"]) - int(_marks[&"terrain_arches"]),
			"cliff dressing": finished - int(_marks[&"cliff_formations"]),
		}
		if detail:
			row.merge(_cliff_detail(region, chunk, feature_context, context))
		var line := "chunk %s" % chunk
		for key in row:
			totals[key] = int(totals.get(key, 0)) + int(row[key])
			line += "  %s=%.0f" % [key, float(row[key]) / 1000.0]
		print(line)
		var h := payload_hash(payload)
		hashes.append("%s %s" % [chunk, h])
		print("HASH ", chunk, " ", h)
	var summary := "TOTAL ms:"
	for key in totals:
		summary += "\n  %-22s %10.1f" % [key, float(totals[key]) / 1000.0]
	print(summary)
	var out_at := args.find("--hash-out")
	if out_at >= 0:
		var f := FileAccess.open(args[out_at + 1], FileAccess.WRITE)
		f.store_string("\n".join(hashes) + "\n")
	var check_at := args.find("--hash-check")
	if check_at >= 0:
		var expected := FileAccess.get_file_as_string(args[check_at + 1]).strip_edges().split("\n")
		var ok := Array(expected) == Array(hashes)
		print("HASH CHECK: ", "IDENTICAL" if ok else "DIFFERENT")
		if not ok:
			for i in mini(expected.size(), hashes.size()):
				if expected[i] != hashes[i]:
					print("  differs: ", hashes[i], " expected ", expected[i])
	quit()

## Branch layout of CliffRockDressing.compute, step by step.
func _cliff_detail(region: HeightfieldRegion, chunk: Vector2i,
		features: FeatureContext, water: WaterFieldContext) -> Dictionary:
	var dressing = load("res://scripts/terrain/field/CliffRockDressing.gd")
	var slope_script = load("res://scripts/terrain/field/CliffSlopeField.gd")
	var crags = load("res://scripts/terrain/field/CliffRockCrags.gd")
	var out := {}
	var owned: Rect2 = dressing.owned_rect(chunk)
	var t := Time.get_ticks_usec()
	var walls = load("res://scripts/terrain/field/TerrainTileField.gd").wall_segments(
		region, owned.grow(dressing.WALL_HALO))
	out["d.wall_segments"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var slope = slope_script.new(walls, SEED, region, owned, features, water)
	out["d.slope_init(rocks)"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	slope.envelope()
	out["d.envelope_build"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var placements: Array = slope.solid(owned)
	out["d.solid"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	if not placements.is_empty():
		slope.add_skirts(placements[0], owned)
	out["d.add_skirts"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	for p: Dictionary in placements:
		crags.mesh_arrays(p, region, SEED)
	out["d.mesh_arrays"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	slope.reservations(owned.grow(16.0))
	out["d.reservations"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var grass_core := Rect2(Vector2(chunk) * TerrainChunkMesher.CHUNK_WORLD,
		Vector2.ONE * TerrainChunkMesher.CHUNK_WORLD)
	slope.grass_support(grass_core.grow(12.0))
	out["d.grass_support"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	slope.skirts()
	slope.rocks(owned)
	slope.skirt_terrain(owned)
	out["d.rocks+skirts"] = Time.get_ticks_usec() - t
	return out

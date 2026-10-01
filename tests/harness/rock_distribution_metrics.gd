extends SceneTree
## Numeric rock-placement review at the owner's September 27 site (seed
## 2697992464, chunk (1,4)): which system places each rock, density on the
## pinned plateau, clustering (Clark-Evans R and isolated singles), base
## overlaps, and the height of every ambient rock's visible base stencil above
## the terrain (positive = floating edge).
##   Godot --headless --path . -s res://tests/harness/rock_distribution_metrics.gd -- [--features] [--out FILE]
## Without --features the authored-feature context (roads, towns) is omitted;
## the reported chunk has no settlement, so only road clearance differs.
const SEED := 2697992464
const STYLE = preload("res://scripts/terrain/field/CliffRockStyle.gd")
const ROCK_DRESSING = preload("res://scripts/terrain/field/CliffRockDressing.gd")
const CHUNKS := [Vector2i(1, 4)]
## The owner's snowy mountaintop plateau and the grass slope below it.
const PLATEAU := Rect2(290, 860, 100, 110)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := "user://rock_distribution_metrics.json"
	if args.has("--out"):
		out = args[args.find("--out") + 1]
	STYLE.apply("sheet_bedrock")
	var water_plan := TerrainWorldTuning.make_water(SEED)
	var plan := TerrainWorldTuning.make_heightfield(SEED, water_plan)
	var catalog := EnvironmentCatalog.load_default()
	var program := DressingCompiler.compile(load("res://terrain/dressing/index.tres"), catalog)
	var feature_program := FeatureProgram.compile(catalog)
	var fields := WorldFieldBlockCache.new(plan, water_plan,
		maxf(program.query_margin, feature_program.query_margin),
		maxf(program.shore_distance_limit, feature_program.shore_distance_limit))
	var world_features: WorldFeaturePlan = null
	if args.has("--features"):
		world_features = WorldFeaturePlan.new(SEED, water_plan, fields, feature_program,
			SettlementPlan.new(SEED, water_plan), maxf(feature_program.query_margin,
				program.feature_query_margin))
	ROCK_DRESSING.prepare()
	var ambient: Array[Dictionary] = []
	var slope: Array[Dictionary] = []
	for chunk: Vector2i in CHUNKS:
		var features: FeatureContext = world_features.context_for(chunk) if world_features else null
		var region: HeightfieldRegion = fields.region(chunk)
		if features != null:
			region = features.graded_region(region)
		var water := fields.water(chunk)
		var cliff: Dictionary = ROCK_DRESSING.compute(region, chunk, SEED, features, water)
		var core := Rect2(Vector2(chunk) * 192.0, Vector2.ONE * 192.0)
		var payload := DressingField.compute(program, SEED, core, region, water,
			features, cliff.ground_reservations)
		ambient.append_array(ambient_rocks(program, payload, region))
		for piece: String in cliff.slope_rocks:
			for rock: Dictionary in cliff.slope_rocks[piece]:
				var t: Transform3D = rock.transform
				var bounds: Vector3 = preload("res://scripts/terrain/field/CliffSlopeRocks.gd").PIECES[piece][1]
				slope.append({"asset": piece, "p": Vector2(t.origin.x, t.origin.z), "y": t.origin.y,
					"r": .5 * maxf(bounds.x * t.basis.x.length(), bounds.z * t.basis.z.length())})
	var report := {
		"ambient": summary(ambient, PLATEAU), "slope": summary(slope, PLATEAU),
		"all": summary(ambient + slope, PLATEAU),
		"ambient_chunk": summary(ambient, Rect2(192, 768, 192, 192)),
		"slope_chunk": summary(slope, Rect2(192, 768, 192, 192)),
		"by_asset": by_asset(ambient + slope, PLATEAU),
		"gap_max": ambient.reduce(func(m: float, r: Dictionary) -> float: return maxf(m, r.gap), -INF),
		"gap_positive": ambient.filter(func(r: Dictionary) -> bool: return r.gap > 0.0).size(),
		"ambient_count": ambient.size(),
	}
	var rows := []
	for r: Dictionary in ambient + slope:
		rows.append([String(r.asset), snappedf(r.p.x, .01), snappedf(r.p.y, .01), snappedf(r.y, .01), snappedf(r.r, .01), snappedf(r.get("gap", 0.0), .01)])
	report["rocks"] = rows
	FileAccess.open(out, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	report.erase("rocks")
	print("[rock_metrics] ", JSON.stringify(report))
	quit()

## Ambient rock instances with their base radius and the highest point of the
## compiled near-ground stencil above the terrain surface under it.
static func ambient_rocks(program: DressingProgram, payload: EnvironmentInstancePayload,
		region: HeightfieldRegion) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for asset_id: StringName in payload.asset_ids():
		if not String(asset_id).contains("rock"):
			continue
		var stencil: PackedVector2Array = program.ground_stencil_by_asset.get(asset_id, PackedVector2Array())
		for t: Transform3D in payload.batches[asset_id].transforms:
			var gap := -INF
			for local: Vector2 in stencil:
				var w := t * Vector3(local.x, 0.0, local.y)
				gap = maxf(gap, w.y - TerrainTileField.surface_y(region, w.x, w.z))
			out.append({"asset": asset_id, "p": Vector2(t.origin.x, t.origin.z), "y": t.origin.y,
				"r": float(program.ground_radius_by_asset.get(asset_id, 0.0)) * t.basis.x.length(),
				"gap": gap})
	return out

## Density per hectare, Clark-Evans R (mean nearest-neighbour distance over its
## Poisson expectation: < 1 clustered, 1 random, > 1 regular), the share of
## isolated rocks (no other within 8 m), base-overlapping pairs, and the share
## of rocks whose base overlaps a neighbour's (nestled).
static func summary(rocks: Array, rect: Rect2) -> Dictionary:
	var inside := rocks.filter(func(r: Dictionary) -> bool: return rect.has_point(r.p))
	var n := inside.size()
	if n < 2:
		return {"count": n}
	var nn_sum := 0.0
	var isolated := 0
	var overlaps := 0
	var touching := 0
	for i in n:
		var best := INF
		var gap := INF
		for j in n:
			if i == j:
				continue
			var d: float = (inside[i].p as Vector2).distance_to(inside[j].p)
			best = minf(best, d)
			gap = minf(gap, d - float(inside[i].r) - float(inside[j].r))
			if j > i and d < 0.9 * (float(inside[i].r) + float(inside[j].r)):
				overlaps += 1
		nn_sum += best
		if best > 8.0:
			isolated += 1
		# September 27 judging: nestled clusters, bases slightly overlapping.
		if gap < 0.0:
			touching += 1
	var density := n / rect.get_area()
	return {"count": n, "per_hectare": snappedf(n / rect.get_area() * 10000.0, .1),
		"clark_evans": snappedf(nn_sum / n / (0.5 / sqrt(density)), .001),
		"isolated_share": snappedf(float(isolated) / n, .001), "overlap_pairs": overlaps,
		"touching_share": snappedf(float(touching) / n, .001)}

static func by_asset(rocks: Array, rect: Rect2) -> Dictionary:
	var out := {}
	for r: Dictionary in rocks:
		if rect.has_point(r.p):
			out[String(r.asset)] = int(out.get(String(r.asset), 0)) + 1
	return out

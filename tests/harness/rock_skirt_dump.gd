extends SceneTree
## Dumps the ground skirt nearest a world point (chunk inputs as production,
## seed 2697992464): per vertex its ring, classification, envelope and
## terrain heights, and final height.
##   Godot --headless --path . -s res://tests/harness/rock_skirt_dump.gd -- x,z
const SEED := 2697992464
const STYLE = preload("res://scripts/terrain/field/CliffRockStyle.gd")
const ROCK_DRESSING = preload("res://scripts/terrain/field/CliffRockDressing.gd")
const SLOPE_FIELD = preload("res://scripts/terrain/field/CliffSlopeField.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var at := Vector2(float(OS.get_cmdline_user_args()[0].split(",")[0]), float(OS.get_cmdline_user_args()[0].split(",")[1]))
	STYLE.apply("sheet_bedrock")
	var water_plan := TerrainWorldTuning.make_water(SEED)
	var plan := TerrainWorldTuning.make_heightfield(SEED, water_plan)
	var catalog := EnvironmentCatalog.load_default()
	var feature_program := FeatureProgram.compile(catalog)
	var fields := WorldFieldBlockCache.new(plan, water_plan, 26.0, 4.0)
	var features := WorldFeaturePlan.new(SEED, water_plan, fields, feature_program,
		SettlementPlan.new(SEED, water_plan), feature_program.query_margin)
	var chunk := Vector2i(floori(at.x / 192.0), floori(at.y / 192.0))
	var context := features.context_for(chunk)
	var region := context.graded_region(fields.region(chunk))
	var water := fields.water(chunk)
	ROCK_DRESSING.prepare()
	var lo := chunk * 8
	var owned := Rect2(Vector2(lo) * 24.0 - Vector2(12, 12), Vector2.ONE * 192.0)
	var cliffs := CliffDressing.compute(region, lo.x - 1, lo.y - 1, 10)
	var corners = preload("res://scripts/terrain/field/CliffCornerCrags.gd")
	var neighbors: Array = ROCK_DRESSING.formations(cliffs.wall, SEED, region, context, water)
	neighbors.append_array(corners.formations(cliffs.outer_wall, SEED, region, context, false, water))
	neighbors.append_array(corners.formations(cliffs.inner_wall, SEED, region, context, true, water))
	var slope = SLOPE_FIELD.new(neighbors, SEED, region, owned, context, water)
	var best: Dictionary = {}
	for rock: Dictionary in slope.skirts():
		if best.is_empty() or SLOPE_FIELD._base_centre(rock).distance_to(at) < SLOPE_FIELD._base_centre(best).distance_to(at):
			best = rock
	var sk: Dictionary = slope.skirts()[best]
	var env = slope.envelope()
	var terrain := RockSkirt.terrain_ground(region)
	print("[dump] rock ", best.piece, " centre ", (best.transform as Transform3D).origin, " top ", sk.top, " sheet_tris ", (sk.sheet_indices as PackedInt32Array).size() / 3, " terrain_tris ", (sk.indices as PackedInt32Array).size() / 3)
	var vertices: PackedVector3Array = sk.vertices
	for i in vertices.size():
		var q := Vector2(vertices[i].x, vertices[i].z)
		print("[dump] ring=%d side=%d sheet=%d y=%.3f env=%.3f terrain=%.3f surfy=%.3f n=%s" % [i / RockSkirt.SIDES, i % RockSkirt.SIDES,
			sk.on_sheet[i], vertices[i].y, env.sample(q), terrain.call(q), TerrainSurfaceField.surface_y(region, q.x, q.y), (sk.normals[i] as Vector3).snapped(Vector3.ONE * .01)])
	quit()

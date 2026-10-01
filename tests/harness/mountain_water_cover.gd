extends SceneTree
## Does the rendered `sheet_bedrock` slope envelope cover the water field?
## For one chunk: along every river centreline and over a grid, compare the
## water level with the heightfield the water solver fills and with the slope
## surface the player actually sees.
## Usage: Godot --headless --path . -s res://tests/harness/mountain_water_cover.gd -- OUT.json X Z [half]
const SEED := 2697992464

func _init() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var site := Vector2(float(args[1]), float(args[2]))
	var half := float(args[3]) if args.size() > 3 else 60.0
	load("res://scripts/terrain/field/CliffRockStyle.gd").apply("sheet_bedrock")
	var water := TerrainWorldTuning.make_water(SEED)
	var plan := TerrainWorldTuning.make_heightfield(SEED, water)
	var fields := WorldFieldBlockCache.new(plan, water, 0, 0, 64)
	var chunk := WorldFieldBlockCache.key_of(site)
	var region := fields.region(chunk)
	var ctx := fields.water(chunk)
	var area := Rect2(Vector2(chunk * 8) * 24.0 - Vector2(12, 12), Vector2.ONE * 192.0)
	var field = load("res://scripts/terrain/field/CliffSlopeField.gd").new([], SEED, region, area, null, ctx)
	var env = field.envelope()
	var out := {"chunk": str(chunk), "centre": [], "grid": []}
	var raw := ctx.raw_context()
	for tr: RiverTrace in raw.rivers:
		for i in tr.points.size() - 1:
			var a := tr.points[i]; var b := tr.points[i + 1]
			for k in 12:
				var p := a.lerp(b, float(k) / 12.0)
				if p.distance_to(site) > half or not area.has_point(p): continue
				var level := ctx.level_at(p)
				out.centre.append([tr.source_cell.x, tr.source_cell.y, i, p.x, p.y,
					TerrainTileField.surface_y(region, p.x, p.y), level, env.sample(p)])
	for x in range(-int(half), int(half) + 1, 3):
		for z in range(-int(half), int(half) + 1, 3):
			var p := site + Vector2(x, z)
			if not area.has_point(p): continue
			out.grid.append([p.x, p.y, TerrainTileField.surface_y(region, p.x, p.y),
				ctx.level_at(p), env.sample(p)])
	FileAccess.open(args[0], FileAccess.WRITE).store_string(JSON.stringify(out))
	print("done")
	quit()

extends SceneTree
## Source-head corpus: per super-cell source, how the raw contour walk ends and
## how deeply its source pool and terminal lake excavate the natural ground.
## Usage: Godot --headless --path . -s res://tests/harness/mountain_water_corpus.gd -- OUT.json [radius] [seed]
func _init() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var radius := int(args[1]) if args.size() > 1 else 3
	var seed_value := int(args[2]) if args.size() > 2 else 2697992464
	var water := TerrainWorldTuning.make_water(seed_value)
	var rows := []
	for z in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var sc := Vector2i(x, z)
			if not water.has_source(sc): continue
			var t := water.river_for(sc, 0)
			var src := t.points[0]
			var end := t.points[-1]
			rows.append({"cell": [x, z], "n": t.points.size(),
				"source": [src.x, src.y], "source_natural": water.noise_h(src),
				"pool_surface": t.source_pool.surface_y(),
				"end_natural": water.noise_h(end), "end_grad": water.grad(end).length(),
				"end_from_source": end.distance_to(src),
				"pond_surface": t.pond.surface_y(), "pond_radius": t.pond.radius,
				"end_bed": t.beds[-1]})
	FileAccess.open(args[0], FileAccess.WRITE).store_string(JSON.stringify(rows, " "))
	print("sources ", rows.size())
	quit()

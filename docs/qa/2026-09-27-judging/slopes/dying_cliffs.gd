extends SceneTree
## Lists cliff edges that die into a hillside (an open corner) in a block
## range: high cell, direction, drop in storeys, corner world point.
##   godot --headless --path . -s res://docs/qa/2026-09-27-judging/slopes/dying_cliffs.gd -- --blocks 1,3:3,5
func _init() -> void:
	var seed_value := 2697992464
	var lo := Vector2i(1, 3)
	var hi := Vector2i(3, 5)
	var args := OS.get_cmdline_user_args()
	var natural := args.has("--natural")
	for i in args.size():
		if args[i] == "--blocks":
			var p := args[i + 1].split(":")
			var a := p[0].split(","); var b := p[1].split(",")
			lo = Vector2i(int(a[0]), int(a[1])); hi = Vector2i(int(b[0]), int(b[1]))
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heightfield, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var world := WorldFeaturePlan.new(seed_value, water, fields, program, SettlementPlan.new(seed_value, water))
	for bz in range(lo.y, hi.y + 1):
		for bx in range(lo.x, hi.x + 1):
			var block := Vector2i(bx, bz)
			var region: HeightfieldRegion = fields.region(block) if natural else world.context_for(block).graded_region(fields.region(block))
			for cz in range(bz * 8, bz * 8 + 8):
				for cx in range(bx * 8, bx * 8 + 8):
					for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if not TerrainSurfaceField.is_wall_edge(region, cx, cz, d): continue
						var h := region.surface_height(cx, cz)
						var low := region.surface_height(cx + d.x, cz + d.y)
						for side in [-1, 1]:
							var sx: int = d.x if d.x != 0 else side
							var sz: int = d.y if d.y != 0 else side
							var corner := TerrainSurfaceField._corner_control(region, cx, cz, sx, sz, h)
							if corner <= low + 0.0001:
								print("DYING cell=(%d,%d) d=%s storeys=%d corner=(%.0f,%.0f) h=%.0f wet=%s" % [cx, cz, d,
									region.storey_at(cx, cz) - region.storey_at(cx + d.x, cz + d.y),
									(cx + 0.5 * sx) * 24.0, (cz + 0.5 * sz) * 24.0, h, region.is_carved(cx + d.x, cz + d.y)])
	quit()

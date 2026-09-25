extends SceneTree

func _initialize() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464, water)
	var fields := WorldFieldBlockCache.new(plan, water, 0.0, 0.0, 128)
	var chunk := Vector2i(-3, -2)
	var region := fields.region(chunk)
	var wet := fields.water(chunk)
	var out := {"cells": [], "lines": [], "rivers": []}
	for z in range(-13, -6):
		for x in range(-25, -17):
			out.cells.append({"cell": [x,z], "natural": water.noise_h(Vector2(x,z)*24),
				"carve": water.carve_at_cell(x,z), "height": region.surface_height(x,z),
				"cliff": TerrainSurfaceField._is_cliff_top(region,x,z)})
	for x in [-552.0, -528.0, -518.4, -504.0, -480.0]:
		var samples := []
		for i in 161:
			var p := Vector2(x, -300.0 + i * 0.5)
			var level := wet.level_at(p)
			samples.append([p.y, TerrainSurfaceField.surface_y(region,p.x,p.y),
				level if is_finite(level) else null])
		out.lines.append({"x": x, "samples": samples})
	var bodies := water.bodies_near(Vector2i(-22,-10),4)
	for trace: RiverTrace in bodies.rivers:
		var nearby := []
		for i in trace.points.size():
			if trace.points[i].distance_to(Vector2(-518.4,-229.6)) < 150:
				nearby.append({"point":str(trace.points[i]),"bed":trace.beds[i],"width":trace.widths[i]})
		if not nearby.is_empty(): out.rivers.append({"source":str(trace.source_cell),"samples":nearby})
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() else "/tmp/september8-river-bank.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(out,"  "))
	print("RIVER_BANK_PROBE ",path)
	quit()

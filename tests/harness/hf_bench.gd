extends SceneTree
## Micro-benchmark of the heightfield plan's reference (per-cell) cost.
## Run: /Applications/Godot.app/Contents/MacOS/Godot --headless -s --path . res://tests/harness/hf_bench.gd

func _init() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 40.0, 8, "mean")
	# Warm up (first call builds noise tables etc.)
	plan.surface_height(50, 50)

	# --- per-cell surface_height (storey_at + level_at, the reference path) ---
	var n: int = 2000
	var t0: int = Time.get_ticks_usec()
	for i in range(n):
		plan.surface_height(50 + (i % 97), 50 + int(i / 97))
	var t1: int = Time.get_ticks_usec()
	print("[bench] surface_height: %.3f ms/call (%d calls)" % [float(t1 - t0) / 1000.0 / float(n), n])

	# --- batched region build (radius 8) + per-cell descriptor reads ---
	var t2: int = Time.get_ticks_usec()
	var region: HeightfieldRegion = plan.compute_region(100, 100, 8)
	var t3: int = Time.get_ticks_usec()
	print("[bench] compute_region radius-8 (one batched clamp pair): %.1f ms" % [float(t3 - t2) / 1000.0])
	var t4: int = Time.get_ticks_usec()
	for dz in range(-8, 9):
		for dx in range(-8, 9):
			HeightfieldInstantiator.placement_for_cell(region, 100 + dx, 100 + dz)
	var t5: int = Time.get_ticks_usec()
	print("[bench] 289 descriptor reads from region: %.1f ms" % [float(t5 - t4) / 1000.0])

	quit()

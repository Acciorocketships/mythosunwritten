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

	# --- one render-region of placement records (radius 8 = 289 cells, no spawn) ---
	var t2: int = Time.get_ticks_usec()
	var count: int = 0
	for dz in range(-8, 9):
		for dx in range(-8, 9):
			HeightfieldInstantiator.placement_for_cell(plan, 100 + dx, 100 + dz)
			count += 1
	var t3: int = Time.get_ticks_usec()
	print("[bench] placement_for_cell x%d (one radius-8 region): %.1f ms" % [count, float(t3 - t2) / 1000.0])

	# --- moving frontier: one ring of new cells when the player crosses one tile (radius 8) ---
	var t4: int = Time.get_ticks_usec()
	var ring: int = 0
	for d in range(-8, 9):
		HeightfieldInstantiator.placement_for_cell(plan, 209, 200 + d)  # new east column
		ring += 1
	var t5: int = Time.get_ticks_usec()
	print("[bench] frontier column x%d (one tile of movement): %.1f ms" % [ring, float(t5 - t4) / 1000.0])

	quit()

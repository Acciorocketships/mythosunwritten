extends SceneTree
## Profiles the phases of compute_region to see where the time goes.
## Run: /Applications/Godot.app/Contents/MacOS/Godot --headless -s --path . res://tests/harness/hf_profile.gd

func _init() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 40.0, 8, "mean")
	plan.surface_height(100, 100)  # warm

	var ccx: int = 100
	var ccz: int = 100
	var radius: int = 8
	var place_r: int = radius + 1
	var level_r: int = place_r + 8          # LEVELS_PER_STOREY
	var storey_final_r: int = level_r + 8   # _CLIFF_SEARCH_MAX
	var storey_outer: int = storey_final_r + plan.max_storeys

	var t0: int = Time.get_ticks_usec()
	var targets: Dictionary = {}
	for dz in range(-storey_outer, storey_outer + 1):
		for dx in range(-storey_outer, storey_outer + 1):
			var cell: Vector2i = Vector2i(ccx + dx, ccz + dz)
			targets[cell] = plan.quantize_storey(plan.raw_height(cell.x, cell.y))
	var t1: int = Time.get_ticks_usec()
	var storeys: Dictionary = HeightfieldPlan.clamp_field(targets)
	var t2: int = Time.get_ticks_usec()
	var cliff_field: Dictionary = HeightfieldPlan._cliff_distance_field(storeys, 8)
	var l0: Dictionary = {}
	for dz in range(-level_r, level_r + 1):
		for dx in range(-level_r, level_r + 1):
			var cell: Vector2i = Vector2i(ccx + dx, ccz + dz)
			var s: int = int(storeys[cell])
			var residual: float = plan.raw_height(cell.x, cell.y) - float(s) * 4.0
			var detail: int = clampi(plan._round_mode(residual / 0.5), 0, 7)
			var cliff_cap: int = cliff_field.get(cell, 999) - 1
			l0[cell] = clampi(mini(detail, cliff_cap), 0, 7)
	var t3: int = Time.get_ticks_usec()
	var levels: Dictionary = HeightfieldPlan._clamp_levels(l0, storeys)
	var t4: int = Time.get_ticks_usec()

	print("[prof] targets+quantize (%d cells): %.1f ms" % [targets.size(), float(t1 - t0) / 1000.0])
	print("[prof] storey clamp_field: %.1f ms" % [float(t2 - t1) / 1000.0])
	print("[prof] L0 + BFS cliff_field (%d cells): %.1f ms" % [l0.size(), float(t3 - t2) / 1000.0])
	print("[prof] level clamp: %.1f ms" % [float(t4 - t3) / 1000.0])
	print("[prof] TOTAL: %.1f ms" % [float(t4 - t0) / 1000.0])

	var w0: int = Time.get_ticks_usec()
	plan.compute_region(100, 100, 8)   # cold: fills the plan's sample memo
	var w1: int = Time.get_ticks_usec()
	plan.compute_region(101, 100, 8)   # warm: shifted one tile, ~98% memo hits
	var w2: int = Time.get_ticks_usec()
	print("[prof] compute_region cold: %.1f ms ; warm (shifted 1 tile): %.1f ms" % [float(w1 - w0) / 1000.0, float(w2 - w1) / 1000.0])
	quit()

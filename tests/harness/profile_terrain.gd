# tests/harness/profile_terrain.gd
# End-to-end terrain-generation profiler: replays the streamer's startup
# (49 chunks at radius 3) and prints per-phase timings. Run:
#   godot --headless --path . -s res://tests/harness/profile_terrain.gd
# Numbers are the acceptance metric for the 2026-07-05 performance plan —
# paste the summary into each perf commit message.
extends SceneTree

const SEED := 3046246887   # pinned in world.tscn; known water beyond the spawn ring
const AMP := 22.0
const MAX_STOREYS := 8
const MAX_STEP := 3

var _acc := 0.0   # defeat dead-code elimination / accidental laziness

func _ms(us: int) -> String:
	return "%.1f ms" % (float(us) / 1000.0)

func _init() -> void:
	print("=== terrain profile, seed %d ===" % SEED)
	var cells: int = TerrainChunkMesher.CELLS_PER_CHUNK
	var grid: int = TerrainChunkMesher.GRID
	var step: float = TerrainChunkMesher.STEP

	var plan := HeightfieldPlan.new(SEED, AMP, MAX_STOREYS, "mean", MAX_STEP)
	var water := WaterPlan.new(SEED, AMP, MAX_STOREYS)
	plan.set_water_plan(water)
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(SEED)
	var wb := WaterSurfaceBuilder.new()

	# --- micro: noise cost, dry vs water-attached ---
	var plan_dry := HeightfieldPlan.new(SEED, AMP, MAX_STOREYS, "mean", MAX_STEP)
	var t0 := Time.get_ticks_usec()
	for i in 4489:
		_acc += plan_dry.raw_height(i % 67 + 20, i / 67 + 20)
	print("raw_height x4489 (no water):        %s" % _ms(Time.get_ticks_usec() - t0))
	t0 = Time.get_ticks_usec()
	for i in 4489:
		_acc += plan.raw_height(i % 67 + 20, i / 67 + 20)
	print("raw_height x4489 (water, cold):     %s" % _ms(Time.get_ticks_usec() - t0))
	t0 = Time.get_ticks_usec()
	for i in 4489:
		_acc += plan.raw_height(i % 67 + 20, i / 67 + 20)
	print("raw_height x4489 (water, warm):     %s" % _ms(Time.get_ticks_usec() - t0))

	# --- micro: compute_region cold/warm ---
	t0 = Time.get_ticks_usec()
	var region = plan.compute_region(100, 100, cells)
	print("compute_region (cold area):         %s" % _ms(Time.get_ticks_usec() - t0))
	t0 = Time.get_ticks_usec()
	region = plan.compute_region(100 + cells, 100, cells)   # neighbour chunk: overlapping window
	print("compute_region (overlapping):       %s" % _ms(Time.get_ticks_usec() - t0))

	# --- startup sweep: 49 chunks in streamer order ---
	print("\n=== startup: 49 chunks (radius 3) ===")
	var total := 0
	var worst := 0
	var worst_c := Vector2i.ZERO
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var c := Vector2i(dx, dz)
			t0 = Time.get_ticks_usec()
			var node := mesher.build_chunk(plan, c)
			var wnode := wb.build_chunk(water, c)
			var dt := Time.get_ticks_usec() - t0
			total += dt
			if dt > worst:
				worst = dt
				worst_c = c
			node.free()
			if wnode != null:
				wnode.free()
	print("TOTAL 49 chunks: %s   avg: %s   worst: %s at %s"
		% [_ms(total), _ms(total / 49), _ms(worst), str(worst_c)])

	# --- phase attribution on the worst chunk (all caches warm) ---
	print("\n=== phase attribution, chunk %s ===" % str(worst_c))
	var ccx := worst_c.x * cells + cells / 2
	var ccz := worst_c.y * cells + cells / 2
	t0 = Time.get_ticks_usec()
	var reg2 = plan.compute_region(ccx, ccz, cells)
	print("  compute_region:        %s" % _ms(Time.get_ticks_usec() - t0))
	# Mirror the mesher's ACTUAL grid path: bake each cell's sampler once, then
	# read the four quad corners with sample_baked (pure float math). Sampling
	# surface_y_in_cell directly here would measure the OLD, un-baked path and
	# misreport what the mesher now does.
	t0 = Time.get_ticks_usec()
	var o := Vector2(float(worst_c.x) * 192.0, float(worst_c.y) * 192.0)
	var baked_cache := {}
	for iz in grid:
		for ix in grid:
			var x0 := o.x + float(ix) * step
			var z0 := o.y + float(iz) * step
			var qcx := TerrainSurfaceField._cell_of(x0 + step * 0.5)
			var qcz := TerrainSurfaceField._cell_of(z0 + step * 0.5)
			var qkey := Vector2i(qcx, qcz)
			var baked: PackedFloat32Array = baked_cache.get(qkey, PackedFloat32Array())
			if baked.is_empty():
				baked = TerrainSurfaceField.bake_cell(reg2, qcx, qcz)
				baked_cache[qkey] = baked
			_acc += TerrainSurfaceField.sample_baked(baked, qcx, qcz, x0, z0)
			_acc += TerrainSurfaceField.sample_baked(baked, qcx, qcz, x0 + step, z0)
			_acc += TerrainSurfaceField.sample_baked(baked, qcx, qcz, x0 + step, z0 + step)
			_acc += TerrainSurfaceField.sample_baked(baked, qcx, qcz, x0, z0 + step)
	print("  grid sampling (4x%dx%d): %s" % [grid, grid, _ms(Time.get_ticks_usec() - t0)])
	t0 = Time.get_ticks_usec()
	var dd := CliffDressing.compute(reg2, worst_c.x * cells, worst_c.y * cells, cells)
	print("  CliffDressing.compute:  %s (pieces: %d)" % [_ms(Time.get_ticks_usec() - t0), dd["wall"].size() + dd["lip"].size()])
	t0 = Time.get_ticks_usec()
	var node2 := mesher.build_chunk(plan, worst_c)
	print("  build_chunk TOTAL:      %s" % _ms(Time.get_ticks_usec() - t0))
	node2.free()
	print("(acc %f)" % _acc)
	quit()

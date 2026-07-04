extends GutTest

# ------------------------------------------------------------
# WaterSurfaceBuilder — ribbon profile math + chunk node assembly
# ------------------------------------------------------------

const SEED := 991177

func _water() -> WaterPlan:
	return WaterPlan.new(SEED, 22.0, 8)

func _a_river(plan: WaterPlan) -> RiverTrace:
	for sz in range(-4, 5):
		for sx in range(-4, 5):
			var t: RiverTrace = plan.river_for(Vector2i(sx, sz))
			if t != null and t.points.size() > 10:
				return t
	assert_true(false, "no river with >10 samples in the window")
	return null

func test_surface_profile_monotone_and_above_bed() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var prof: PackedFloat32Array = WaterSurfaceBuilder.surface_profile(river)
	assert_eq(prof.size(), river.points.size(), "one surface sample per polyline sample")
	for i in prof.size():
		assert_true(prof[i] >= river.beds[i] + 0.1,
			"surface stays above the bed (i=%d)" % i)
	for i in range(1, prof.size()):
		assert_true(prof[i] <= prof[i - 1] + 0.0001,
			"surface never flows uphill (i=%d)" % i)

func test_surface_profile_ends_at_terminal_pond_level() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = null
	for sz in range(-4, 5):
		for sx in range(-4, 5):
			var t: RiverTrace = plan.river_for(Vector2i(sx, sz))
			if t != null and t.pond != null and t.points.size() > 10:
				river = t
				break
		if river != null:
			break
	if river == null:
		pass_test("no ponded river in window on this seed")
		return
	var prof: PackedFloat32Array = WaterSurfaceBuilder.surface_profile(river)
	assert_almost_eq(prof[prof.size() - 1], river.pond.surface_y(), 0.6,
		"backwater reach flattens into the pond")

func test_build_chunk_makes_meshes_and_swim_volumes() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var mid: Vector2 = river.points[river.points.size() / 2]
	var chunk: Vector2i = Vector2i(int(floor(mid.x / 192.0)), int(floor(mid.y / 192.0)))
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(plan, chunk)
	assert_not_null(node, "chunk containing a river builds a water node")
	var meshes: int = 0
	var areas: int = 0
	for c in node.get_children():
		if c is MeshInstance3D:
			meshes += 1
		if c is Area3D:
			areas += 1
			assert_true(c.has_meta("surface_y"), "swim volume carries surface_y")
			assert_eq(c.collision_layer, 1 << 7, "swim volume on the water layer")
	assert_true(meshes > 0, "water meshes present")
	assert_true(areas > 0, "swim volumes present")
	node.free()

func test_build_chunk_returns_null_when_dry() -> void:
	var plan: WaterPlan = _water()
	# Scan for a chunk whose window has no bodies (seed-independent), then
	# assert the builder agrees. (The spawn chunk's corners poke past the dry
	# radius, so it is NOT guaranteed dry — don't hardcode it.)
	var dry: Vector2i = Vector2i.MAX
	for cz in range(0, 40):
		for cx in range(0, 40):
			var b: Dictionary = plan.bodies_near(Vector2i(cx * 8 + 4, cz * 8 + 4), 5)
			if b.ponds.is_empty() and b.rivers.is_empty():
				dry = Vector2i(cx, cz)
				break
		if dry != Vector2i.MAX:
			break
	assert_true(dry != Vector2i.MAX, "found a dry chunk in the scan band")
	assert_null(WaterSurfaceBuilder.new().build_chunk(plan, dry), "dry chunk => no node")

# ------------------------------------------------------------
# Water field — the sheet reaches land at its own height
# ------------------------------------------------------------

func _river_chunk(plan: WaterPlan, river: RiverTrace) -> Vector2i:
	var mid: Vector2 = river.points[river.points.size() / 2]
	return Vector2i(int(floor(mid.x / 192.0)), int(floor(mid.y / 192.0)))

func test_field_rim_overshoots_every_wet_cell() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var chunk: Vector2i = _river_chunk(plan, river)
	var field: Dictionary = WaterSurfaceBuilder.compute_field(plan, chunk)
	assert_true(field.size() > 0, "river chunk has a water field")
	var lo: Vector2i = Vector2i(chunk.x * 8, chunk.y * 8)
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for cell in field:
		if not field[cell].wet:
			continue
		if cell.x < lo.x or cell.x >= lo.x + 8 or cell.y < lo.y or cell.y >= lo.y + 8:
			continue
		for d in dirs:
			var nb: Vector2i = cell + d
			if field.has(nb):
				continue
			# The only neighbours allowed OUTSIDE the sheet are drop-offs far
			# below this cell's level (a lower reach owns that water; a plane
			# there would hover in midair over the drop).
			var g: float = WaterSurfaceBuilder.ground_estimate(plan, nb.x, nb.y)
			assert_true(g < field[cell].level - WaterSurfaceBuilder.WET_EPS,
				"neighbour %s of wet %s is in the sheet or is a drop-off" % [nb, cell])

func test_field_wet_cells_sit_below_their_level() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var field: Dictionary = WaterSurfaceBuilder.compute_field(plan, _river_chunk(plan, river))
	var wet_seen: int = 0
	for cell in field:
		if not field[cell].wet:
			continue
		wet_seen += 1
		assert_true(WaterSurfaceBuilder.ground_estimate(plan, cell.x, cell.y) < field[cell].level,
			"wet cell %s ground sits below its water level" % cell)
	assert_true(wet_seen > 0, "field contains wet cells")

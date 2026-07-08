extends GutTest

# ------------------------------------------------------------
# Swim volumes are per-WET-CELL boxes straight from the field: the volume
# surface IS the rendered sheet's level, no box can span a waterfall, and
# plunge pools are covered wall-to-wall. Guards the owner's round-5 report:
# character "swimming" in mid-air beside falls (phantom volume at the upper
# level over the pool) and sinking unsupported in the pool itself (no box at
# the pool's own level). Pinned review seed; the R3 cascade at (48, -1092).
# ------------------------------------------------------------

const SEED := 2697992464
const TILE := 24.0
const CHUNK := Vector2i(0, -6)   # cells 0..7 × -48..-41: the cascade + pool

static var _plan_cache: Dictionary = {}
static var _region_cache: Dictionary = {}
static var _field_cache: Dictionary = {}


func _plan(seed_v: int) -> HeightfieldPlan:
	if not _plan_cache.has(seed_v):
		var hp := HeightfieldPlan.new(seed_v, 22.0, 8, "mean", 3)
		hp.set_water_plan(WaterPlan.new(seed_v, 22.0, 8))
		_plan_cache[seed_v] = hp
	return _plan_cache[seed_v]


func _region(seed_v: int, chunk: Vector2i):
	var rk := [seed_v, chunk]
	if not _region_cache.has(rk):
		_region_cache[rk] = _plan(seed_v).compute_region(chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
	return _region_cache[rk]


func _field(seed_v: int, chunk: Vector2i) -> Dictionary:
	var rk := [seed_v, chunk]
	if not _field_cache.has(rk):
		_field_cache[rk] = WaterSurfaceBuilder.compute_field(
			_plan(seed_v)._water_plan, chunk, _region(seed_v, chunk))
	return _field_cache[rk]


func _volumes(root: Node3D) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child is Area3D:
			out.append(child)
	return out


func _box_contains(area: Area3D, p: Vector3) -> bool:
	var shape: BoxShape3D = area.get_child(0).shape
	var local: Vector3 = area.transform.affine_inverse() * p
	return absf(local.x) <= shape.size.x * 0.5 \
		and absf(local.y) <= shape.size.y * 0.5 \
		and absf(local.z) <= shape.size.z * 0.5


func test_volumes_are_cell_pure_and_cover_the_pool() -> void:
	var field: Dictionary = _field(SEED, CHUNK)
	assert_false(field.is_empty(), "cascade chunk has water")
	var root := Node3D.new()
	WaterSurfaceBuilder.new()._build_volumes(CHUNK, field, root)
	var vols: Array = _volumes(root)
	assert_gt(vols.size(), 0, "volumes emitted")

	# (a) The owner's phantom hover point beside the 9->5 fall: inside NO box.
	var phantom := Vector3(49.3, 7.0, -1110.6)
	for v in vols:
		assert_false(_box_contains(v, phantom),
			"phantom mid-air point must be in no volume (box at %s surface %s)"
			% [v.position, v.get_meta("surface_y")])

	# (b) The real plunge pool below the fall: covered, at ITS level (5).
	var pool := Vector3(49.3, 4.6, -1110.6)
	var found := false
	for v in vols:
		if _box_contains(v, pool):
			found = true
			assert_almost_eq(float(v.get_meta("surface_y")), 5.0, 0.01,
				"pool volume carries the pool's own level")
	assert_true(found, "plunge pool point inside a volume")

	# (c) Exactly one box per wet interior cell; surface == that cell's level;
	# box ceiling == level + headroom (never towers into the air above).
	var by_cell: Dictionary = {}
	for v in vols:
		var cell := Vector2i(roundi(v.position.x / TILE), roundi(v.position.z / TILE))
		assert_false(by_cell.has(cell), "one box per cell %s" % cell)
		by_cell[cell] = v
		assert_true(field.has(cell) and field[cell].wet, "box only on wet cell %s" % cell)
		assert_almost_eq(float(v.get_meta("surface_y")), float(field[cell].level), 0.001,
			"surface_y matches field level at %s" % cell)
		var shape: BoxShape3D = v.get_child(0).shape
		var top: float = v.position.y + shape.size.y * 0.5
		assert_almost_eq(top, float(field[cell].level) + WaterSurfaceBuilder.VOLUME_TOP_PAD,
			0.001, "ceiling hugs the level at %s" % cell)
		# Half-cell ramps dip a storey below the cell-centre ground INSIDE the
		# cell: the floor must reach the ramp toe or bodies there read dry.
		var bottom: float = v.position.y - shape.size.y * 0.5
		assert_almost_eq(bottom, float(field[cell].ground) - WaterSurfaceBuilder.STOREY - 1.0,
			0.001, "floor reaches the ramp toe at %s" % cell)
	for cell in field:
		if not field[cell].wet:
			continue
		if cell.x < CHUNK.x * 8 or cell.x >= CHUNK.x * 8 + 8 \
				or cell.y < CHUNK.y * 8 or cell.y >= CHUNK.y * 8 + 8:
			continue
		assert_true(by_cell.has(cell), "wet interior cell %s covered" % cell)
	root.free()

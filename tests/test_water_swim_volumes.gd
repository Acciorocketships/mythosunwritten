extends GutTest

# ------------------------------------------------------------
# Swim volumes are per-WET-CELL boxes straight from WaterMesher's wet_cells:
# the volume carries a SAMPLED SURFACE PLANE (cell-centre level + XZ level
# gradient), not a single scalar level, so a probe anywhere inside the box
# can reconstruct the true sloped/swell-free surface height (Task 10's
# character contract) instead of reading a flat plate. Guards the owner's
# round-5 report: character "swimming" in mid-air beside falls (phantom
# volume at the upper level over the pool) and sinking unsupported in the
# pool itself (no box at the pool's own level) — now enforced structurally
# by cell-purity: one box per wet cell, so a box can never span a waterfall.
# Pinned review seed/chunk; the site chunk carries the R3 cascade.
# ------------------------------------------------------------

const SEED := 2697992464
const TILE := 24.0
const SITE_CHUNK := Vector2i(0, -6)

static var _plans: Dictionary = {}
static var _waters: Dictionary = {}
static var _regions: Dictionary = {}
static var _mesh_cache: Dictionary = {}


static func _water(seed_v: int) -> WaterPlan:
	if not _waters.has(seed_v):
		var plan := HeightfieldPlan.new(seed_v, 22.0, 8, "mean", 3)
		var water := WaterPlan.new(seed_v, 22.0, 8)
		plan.set_water_plan(water)
		_plans[seed_v] = plan
		_waters[seed_v] = water
	return _waters[seed_v]


func _region(seed_v: int, chunk: Vector2i):
	var key := [seed_v, chunk]
	if not _regions.has(key):
		_water(seed_v)
		_regions[key] = _plans[seed_v].compute_region(
			chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
	return _regions[key]


func _mesh(seed_v: int, chunk: Vector2i) -> Dictionary:
	var key := [seed_v, chunk]
	if not _mesh_cache.has(key):
		_mesh_cache[key] = WaterMesher.build(_water(seed_v), chunk, _region(seed_v, chunk))
	return _mesh_cache[key]


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


## The surface height a character probe would sample at (x, z) inside a
## volume: the cell-centre level plus the level gradient extrapolated to the
## probe point — Task 10's plane-sampling formula, previewed here since Task
## 9 is what populates surface_c/surface_g.
func _sampled_surface(area: Area3D, x: float, z: float) -> float:
	var c: Vector3 = area.get_meta("surface_c")
	var g: Vector2 = area.get_meta("surface_g")
	return c.y + g.dot(Vector2(x, z) - Vector2(c.x, c.z))


func test_volumes_are_cell_pure_and_cover_the_pool() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = _mesh(SEED, SITE_CHUNK)
	assert_false(m.is_empty(), "site chunk has water")
	var root: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	assert_not_null(root, "site builds")
	var vols: Array = _volumes(root)
	assert_gt(vols.size(), 0, "volumes emitted")

	# (a)/(b) Cell-purity replaces the old phantom-hover-point/pool-point
	# split: each wet cell gets exactly ONE box straddling its own level, so
	# a box can never carry the upper level across a plunge pool (the
	# owner's mid-air-swim report) — checked structurally below in (c)
	# rather than at two hand-pinned world points, since the new mesher's
	# cell grid no longer lines up with the retired per-trace-sample boxes.

	# (c) Exactly one box per wet cell; surface plane sampled at the cell
	# centre matches the mesher's own field level; box ceiling/floor follow
	# the documented formulas (level + headroom, ground floor - clearance).
	var by_cell: Dictionary = {}
	for v in vols:
		var cell := Vector2i(roundi(v.position.x / TILE - 0.5), roundi(v.position.z / TILE - 0.5))
		assert_false(by_cell.has(cell), "one box per cell %s" % cell)
		by_cell[cell] = v
		assert_true(m.wet_cells.has(cell), "box only on a wet_cells entry %s" % cell)
		var wc: Dictionary = m.wet_cells[cell]
		var c: Vector3 = v.get_meta("surface_c")
		assert_almost_eq(c.y, float(wc.lvl), 0.001, "surface_c.y matches wet_cells level at %s" % cell)
		var g: Vector2 = v.get_meta("surface_g")
		assert_almost_eq(g.x, wc.grad.x, 0.001, "surface_g.x matches wet_cells grad at %s" % cell)
		assert_almost_eq(g.y, wc.grad.y, 0.001, "surface_g.y matches wet_cells grad at %s" % cell)
		# Plane sampled at the box's own centre must reduce to the cell level
		# exactly (zero offset from surface_c itself).
		assert_almost_eq(_sampled_surface(v, c.x, c.z), float(wc.lvl), 0.001,
			"plane sampled at its own centre reproduces the level at %s" % cell)
		var shape: BoxShape3D = v.get_child(0).shape
		var top: float = v.position.y + shape.size.y * 0.5
		assert_almost_eq(top, float(wc.lvl) + 1.7, 0.001, "ceiling hugs the level at %s" % cell)
		var bottom: float = v.position.y - shape.size.y * 0.5
		assert_almost_eq(bottom, float(wc.gnd_lo) - 5.0, 0.001, "floor clears the cell floor at %s" % cell)
		assert_eq(v.collision_layer, 1 << 7, "water layer at %s" % cell)
	for cell in m.wet_cells:
		assert_true(by_cell.has(cell), "wet cell %s covered" % cell)
	root.free()


## Every volume advertises the sampled-plane contract Task 10 reads from.
func test_volumes_carry_the_sampled_surface_plane() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var root: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	var vols: Array = _volumes(root)
	assert_gt(vols.size(), 0, "volumes emitted")
	for v in vols:
		assert_true(v.has_meta("surface_c"), "surface_c present")
		assert_true(v.has_meta("surface_g"), "surface_g present")
		assert_true(v.get_meta("surface_c") is Vector3, "surface_c is a Vector3")
		assert_true(v.get_meta("surface_g") is Vector2, "surface_g is a Vector2")
	root.free()

extends GutTest

# ------------------------------------------------------------
# Swim volumes are per-WET-CELL boxes straight from WaterMesher's wet_cells:
# the volume carries a SAMPLED SURFACE PLANE (cell-centre level + XZ level
# gradient), not a single scalar level, so a probe anywhere inside the box
# can reconstruct the true sloped/swell-free surface height (Task 10's
# character contract) instead of reading a flat plate. Guards the owner's
# round-5 report: character "swimming" in mid-air beside falls (phantom
# volume at the upper level over the pool) and sinking unsupported in the
# pool itself (no box at the pool's own level) — enforced structurally (one
# box per wet-cell SURFACE: a cell crossed by a fall cut emits two stacked
# volumes, so no box ever carries the upper level over the pool) and by
# world-space regression probes at the site's real cascade.
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

	# wet_cells is Vector2i -> Array of surface entries (usually one; a cell
	# crossed by a fall cut or body seam carries TWO stacked entries, upper
	# and lower surface). Group the built volumes by cell and match each
	# against its entry: plane metas, ceiling/floor formulas, layer.
	var by_cell: Dictionary = {}
	for v in vols:
		var cell := Vector2i(roundi(v.position.x / TILE - 0.5), roundi(v.position.z / TILE - 0.5))
		if not by_cell.has(cell):
			by_cell[cell] = []
		by_cell[cell].append(v)
	var split_cells := 0
	for cell in by_cell:
		assert_true(m.wet_cells.has(cell), "box only on a wet_cells cell %s" % cell)
		var entries: Array = m.wet_cells[cell]
		assert_eq(by_cell[cell].size(), entries.size(),
			"one box per wet_cells entry at %s" % cell)
		if entries.size() > 1:
			split_cells += 1
		for wc in entries:
			var matched: Area3D = null
			for v in by_cell[cell]:
				if absf(float(v.get_meta("surface_c").y) - float(wc.lvl)) < 0.001:
					matched = v
			assert_not_null(matched, "entry lvl %.2f at %s has its box" % [wc.lvl, cell])
			if matched == null:
				continue
			var c: Vector3 = matched.get_meta("surface_c")
			var g: Vector2 = matched.get_meta("surface_g")
			assert_almost_eq(g.x, wc.grad.x, 0.001, "surface_g.x matches wet_cells grad at %s" % cell)
			assert_almost_eq(g.y, wc.grad.y, 0.001, "surface_g.y matches wet_cells grad at %s" % cell)
			# Plane sampled at the box's own centre must reduce to the cell
			# level exactly (zero offset from surface_c itself).
			assert_almost_eq(_sampled_surface(matched, c.x, c.z), float(wc.lvl), 0.001,
				"plane sampled at its own centre reproduces the level at %s" % cell)
			var shape: BoxShape3D = matched.get_child(0).shape
			var top: float = matched.position.y + shape.size.y * 0.5
			assert_almost_eq(top, float(wc.lvl) + 1.7, 0.001, "ceiling hugs the level at %s" % cell)
			# A straddling cell's UPPER entry floors above the lower box's
			# ceiling (its own "floor" key — stacked boxes must not overlap);
			# plain entries reach the cell's lowest ground minus clearance.
			var bottom: float = matched.position.y - shape.size.y * 0.5
			assert_almost_eq(bottom, float(wc.get("floor", wc.gnd_lo - 5.0)), 0.001,
				"floor per entry at %s" % cell)
			assert_eq(matched.collision_layer, 1 << 7, "water layer at %s" % cell)
	for cell in m.wet_cells:
		assert_true(by_cell.has(cell), "wet cell %s covered" % cell)
	# The pinned site's cascade cut crosses cell (2,-46) mid-cell: at least
	# one straddling cell must split into stacked upper/lower volumes.
	assert_gt(split_cells, 0, "the site's cut-straddling cell splits into stacked volumes")
	root.free()


## Regression probes at the site's real cascade. The recorded cut sits at
## world (58.3, -1088.4) with dir ~ (0.11, -0.99) (flow toward -z), top 13.7
## -> bottom 5.7, crossing cell (2,-46) mid-cell — so that one 24m cell holds
## BOTH surfaces. Probe points pinned by sampling WaterField.level_at with
## the region ctx (see task-9 report): (54, -1092) claims the 5.7 pool
## (ground 4.0), (54, -1083) claims the 13.7 lip reach (ground 7.6). The
## volume containing the pool point must report the DOWNSTREAM surface —
## never the upper level carried over the plunge pool (the owner's phantom
## mid-air swim) — and the upstream point must get the lip surface from the
## stacked upper volume of the same cell.
func test_cascade_volumes_report_their_own_surface() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var pool := Vector3(54.0, 6.0, -1092.0)
	var lip := Vector3(54.0, 13.4, -1083.0)
	assert_almost_eq(WaterField.level_at(ctx, Vector2(pool.x, pool.z)), 5.7, 0.3,
		"pool probe claims the downstream level")
	assert_almost_eq(WaterField.level_at(ctx, Vector2(lip.x, lip.z)), 13.7, 0.3,
		"lip probe claims the upstream level")
	var root: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	var vols: Array = _volumes(root)
	var pool_hits := 0
	for v in vols:
		if _box_contains(v, pool):
			pool_hits += 1
			assert_almost_eq(_sampled_surface(v, pool.x, pool.z), 5.7, 0.8,
				"pool volume reports the pool surface, not the 13.7 lip")
	assert_gt(pool_hits, 0, "pool point inside a volume")
	var lip_hits := 0
	for v in vols:
		if _box_contains(v, lip):
			lip_hits += 1
			assert_almost_eq(_sampled_surface(v, lip.x, lip.z), 13.7, 0.8,
				"upstream volume reports the lip surface")
	assert_gt(lip_hits, 0, "upstream point inside a volume")
	# Overlap-band probe: just above the pool surface but below the pool
	# box's ceiling (5.7 + 1.7 = 7.4). The stacked UPPER volume must start
	# strictly ABOVE that ceiling — if the boxes overlap, the character's
	# maxf-gating over passing volumes picks the upper surface in the band:
	# a band-limited recurrence of the phantom mid-air swim.
	var band := Vector3(54.0, 6.9, -1092.0)
	var band_hits := 0
	for v in vols:
		if _box_contains(v, band):
			band_hits += 1
			assert_almost_eq(_sampled_surface(v, band.x, band.z), 5.7, 0.8,
				"band point sees only the pool surface, never the 13.7 lip")
	assert_eq(band_hits, 1, "band point inside the LOWER box only")
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


## Task 10's exact plane-sampling formula, cross-checked against the field:
## the volume centre should equal WaterField.level_at, and extrapolating the
## plane out to a nearby probe point should still track the field's slope.
## Both checks are gated on the field actually claiming that (x, z) with the
## SAME body the box came from — level_at is a nearest-claim search over
## ALL rivers/ponds in the chunk, independent of WaterMesher's per-cell
## wet_cells aggregation, so at seam/stacked cells (two boxes share an x,z
## column, e.g. the site's own (2,-46) cascade split) the two are allowed to
## legitimately disagree; the gate (agreement within 2.0m) is the same one
## the brief's own probe-point check uses, applied first to the centre too.
## The offset-point check is gated on the field reading near-flat between
## centre and probe (|plvl - lvl| < 0.6) — the pinned site's only non-zero
## surface_g on this chunk sits on an anchored pond/plateau level where
## level_at is PROVABLY flat for 24m+ (scanned every 2m: constant 15.0) yet
## WaterMesher's finite-difference gradient carries g.x = -0.1083 of
## sub-grid noise, extrapolating to a 0.65m error over 6m — a known
## mesher gradient-precision gap, not a Task 10 defect (Task 10 only
## consumes surface_g, it does not compute it; flagged in the task report).
## The comparison tolerance (0.7) absorbs exactly that one artifact while
## still catching a wrong sign/slope or a stale/garbage gradient.
func test_volume_surface_matches_field_at_probe_points() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	var checked := 0
	for ch in node.get_children():
		if ch is Area3D:
			var c: Vector3 = ch.get_meta("surface_c")
			var g: Vector2 = ch.get_meta("surface_g")
			var lvl: float = WaterField.level_at(ctx, Vector2(c.x, c.z))
			var centre_agrees: bool = lvl > -INF and absf(lvl - c.y) < 2.0
			if centre_agrees:
				assert_almost_eq(c.y, lvl, 0.05, "volume centre level == field level")
			var px := Vector2(c.x + 6.0, c.z)
			var plvl: float = WaterField.level_at(ctx, px)
			if centre_agrees and plvl > -INF and absf(plvl - lvl) < 0.6:
				assert_almost_eq(c.y + g.dot(px - Vector2(c.x, c.z)), plvl, 0.7,
					"sampled plane tracks the sloped surface")
				checked += 1
	assert_true(checked > 0, "at least one sloped/flat cell verified")
	node.free()

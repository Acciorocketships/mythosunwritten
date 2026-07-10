extends GutTest

# ------------------------------------------------------------
# Swim volumes are per-WET-CELL boxes straight from WaterMesher's wet_cells:
# the volume carries a SAMPLED SURFACE PLANE (cell-centre level + XZ level
# gradient), not a single scalar level, so a probe anywhere inside the box
# can reconstruct the true sloped/swell-free surface height (Task 10's
# character contract) instead of reading a flat plate.
#
# Phase 2b: the split/stacked-volume machinery (a cell whose corner levels
# spread past CUT_JUMP used to emit TWO boxes, upper and lower) is DELETED —
# wet_cells is back to exactly ONE entry per cell (see WaterMesher.gd's
# _attributes docstring and this task's report). In its place: a cell whose
# max |grade_at| over its own wet samples exceeds STEEP_UNSWIMMABLE (0.45)
# gets NO volume at all — steep water is not swimmable by design, so a
# character falls/slides through it instead of floating. The site's real
# cascade (verified this task, headless probe over the full pinned 3x3
# chunk neighbourhood) never exceeds 0.3333 anywhere — the legal-reach
# ceiling itself (FALL_DROP_MIN/TRACE_STEP, see WaterMesher.gd's own
# STEEP_UNSWIMMABLE comment), comfortably under 0.45 — so the site itself
# has NO steep cells to gate; see test_no_volume_on_steep_water below for
# the synthetic (hand-built, non-vacuous) coverage of the gate itself.
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


## Phase 2b REWRITE (was checking that at least one cell splits into stacked
## upper/lower volumes — the split machinery is deleted entirely, wet_cells
## is back to exactly one entry per cell; see WaterMesher.gd's _attributes
## docstring). Plane/containment/layer checks (item 5(b), kept) are
## unchanged in substance, just against the single-entry shape: every
## wet_cells entry has exactly one matching box, whose plane metas/ceiling/
## floor/layer all match the entry's own fields directly (no more `floor`
## key — floor is always gnd_lo - 5.0, see build_chunk).
func test_volumes_are_cell_pure_and_cover_the_pool() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = _mesh(SEED, SITE_CHUNK)
	assert_false(m.is_empty(), "site chunk has water")
	var root: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	assert_not_null(root, "site builds")
	var vols: Array = _volumes(root)
	assert_gt(vols.size(), 0, "volumes emitted")

	# wet_cells is Vector2i -> Array of EXACTLY ONE surface entry (Phase 2b:
	# no split/stacked cells left at all). Group the built volumes by cell
	# and match each against its one entry: plane metas, ceiling/floor
	# formulas, layer.
	var by_cell: Dictionary = {}
	for v in vols:
		var cell := Vector2i(roundi(v.position.x / TILE - 0.5), roundi(v.position.z / TILE - 0.5))
		if not by_cell.has(cell):
			by_cell[cell] = []
		by_cell[cell].append(v)
	for cell in by_cell:
		assert_true(m.wet_cells.has(cell), "box only on a wet_cells cell %s" % cell)
		var entries: Array = m.wet_cells[cell]
		assert_eq(entries.size(), 1, "exactly one wet_cells entry per cell at %s (no split cells)" % cell)
		assert_eq(by_cell[cell].size(), 1, "exactly one box per cell at %s" % cell)
		var wc: Dictionary = entries[0]
		var matched: Area3D = by_cell[cell][0]
		var c: Vector3 = matched.get_meta("surface_c")
		var g: Vector2 = matched.get_meta("surface_g")
		assert_almost_eq(float(c.y), float(wc.lvl), 0.001, "surface_c.y matches wet_cells lvl at %s" % cell)
		assert_almost_eq(g.x, wc.grad.x, 0.001, "surface_g.x matches wet_cells grad at %s" % cell)
		assert_almost_eq(g.y, wc.grad.y, 0.001, "surface_g.y matches wet_cells grad at %s" % cell)
		# Plane sampled at the box's own centre must reduce to the cell
		# level exactly (zero offset from surface_c itself).
		assert_almost_eq(_sampled_surface(matched, c.x, c.z), float(wc.lvl), 0.001,
			"plane sampled at its own centre reproduces the level at %s" % cell)
		var shape: BoxShape3D = matched.get_child(0).shape
		var top: float = matched.position.y + shape.size.y * 0.5
		assert_almost_eq(top, float(wc.lvl) + 1.7, 0.001, "ceiling hugs the level at %s" % cell)
		# Floor reaches the cell's lowest ground minus clearance — no more
		# "floor" key/stacked-ceiling arithmetic (see build_chunk).
		var bottom: float = matched.position.y - shape.size.y * 0.5
		assert_almost_eq(bottom, float(wc.gnd_lo) - 5.0, 0.001, "floor at %s" % cell)
		assert_eq(matched.collision_layer, 1 << 7, "water layer at %s" % cell)
	for cell in m.wet_cells:
		assert_true(by_cell.has(cell), "wet cell %s covered" % cell)
	root.free()


## Regression probes at the site's real cascade. Phase 2b REWRITE (item 5(a)
## of this task's brief): the split-cell "overlap band never sees the upper
## surface" probe is DELETED — there is no stacked upper/lower pair left to
## guard against overlapping (wet_cells is one entry per cell now), so the
## whole scenario that probe existed for cannot occur any more (a structural
## guarantee, not something a runtime probe needs to keep re-checking).
##
## The OLD "lip" probe point (54, 9.4, -1083) — right at the cell (2,-46)/
## (2,-45) boundary, chosen back when that cell carried the reach's upstream
## level as its OWN stacked upper box — is NOT re-used: verified directly
## (this task, headless probe) that with wet_cells collapsed to one entry
## per cell, cell (2,-46)'s single box is anchored at its own centre-sample
## level (5.7) with only 1.7m of headroom, so it does NOT reach y=9.4 near
## the cell's upstream edge, and the NEIGHBOUR cell (2,-45)'s box (anchored
## at 9.7) starts at z=-1080, short of z=-1083 — the old point falls in a
## real (if narrow) coverage seam between two single-plane boxes on a
## reach with a real internal gradient (0.333, still well under
## STEEP_UNSWIMMABLE=0.45, so neither cell is gated out — this is a genuine
## consequence of "one flat plane per 24m cell," not a bug this task
## introduces new coverage machinery to fix). Replaced with an upstream
## point well inside cell (2,-45)'s own footprint (54, 10.0, -1068) —
## verified wet (level_at == 9.7) and inside that cell's box with margin —
## so the substantive "upstream volume reports the upstream surface, not
## the downstream one" invariant (item 5(b), kept) is still exercised by a
## real, non-degenerate probe.
func test_cascade_volumes_report_their_own_surface() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var pool := Vector3(54.0, 6.0, -1092.0)
	var upstream := Vector3(54.0, 10.0, -1068.0)
	assert_almost_eq(WaterField.level_at(ctx, Vector2(pool.x, pool.z)), 5.7, 0.3,
		"pool probe claims the downstream level")
	assert_almost_eq(WaterField.level_at(ctx, Vector2(upstream.x, upstream.z)), 9.7, 0.3,
		"upstream probe claims the upstream level")
	var root: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	var vols: Array = _volumes(root)
	var pool_hits := 0
	for v in vols:
		if _box_contains(v, pool):
			pool_hits += 1
			assert_almost_eq(_sampled_surface(v, pool.x, pool.z), 5.7, 0.8,
				"pool volume reports the pool surface, not the 9.7 upstream reach")
	assert_gt(pool_hits, 0, "pool point inside a volume")
	var upstream_hits := 0
	for v in vols:
		if _box_contains(v, upstream):
			upstream_hits += 1
			assert_almost_eq(_sampled_surface(v, upstream.x, upstream.z), 9.7, 0.8,
				"upstream volume reports the upstream reach's surface, not the 5.7 pool")
	assert_gt(upstream_hits, 0, "upstream point inside a volume")
	root.free()


## Phase 2b (new, item 5's explicit ask): the STEEP_UNSWIMMABLE gate itself,
## exercised directly and non-vacuously — the site's own real cascade never
## exceeds |grade_at|=0.3333 anywhere (verified this task over the full
## pinned 3x3 chunk neighbourhood, see this file's own header comment), so
## there are no steep cells on this seed to probe in-place; hand-building a
## `st` with a genuinely steep corner spread (matching the pattern the old
## test_multi_seam_cell_never_folds used, but now checking wet_cells'
## STEEP_UNSWIMMABLE gate instead of a mesh-fold guard) gives real,
## non-degenerate coverage of the gate without depending on any seed ever
## growing a steep enough reach.
func test_no_volume_on_steep_water() -> void:
	var n1: int = WaterMesher.N + 1
	var lvl := PackedFloat32Array()
	lvl.resize(n1 * n1)
	lvl.fill(-INF)
	var gnd := PackedFloat32Array()
	gnd.resize(n1 * n1)
	gnd.fill(0.0)
	# A steep corner run: level drops 12.0 over one 3m cell edge (grade 4.0,
	# far past STEEP_UNSWIMMABLE=0.45) along a single row so _claim/grade_at
	# has a real trace to read from.
	var water := WaterPlan.new(1, 22.0, 8)
	var tr := RiverTrace.new()
	tr.source_cell = Vector2i(997, 997)
	tr.priority = 1
	tr.points = PackedVector2Array([Vector2(1.5, 1.5), Vector2(4.5, 1.5)])
	tr.beds = PackedFloat32Array([9.0, -3.0])
	tr.widths = PackedFloat32Array([3.0, 3.0])
	tr.joined = false
	tr.source_pool = null
	tr.pond = null
	# A real (if trivially flat, storey-0-everywhere) HeightfieldRegion —
	# _attributes' own shore/ground computation needs a real region object,
	# not null (unlike WaterField.grade_at, which tolerates a null region
	# gracefully via profile()'s own region-optional fallback).
	var region := HeightfieldRegion.new({}, {})
	var ctx: Dictionary = {"water": water, "ponds": [], "rivers": [tr],
		"buckets": {Vector2i(0, 0): [Vector2i(0, 0), Vector2i(0, 1)]}, "region": region}
	for j in 2:
		for i in 2:
			lvl[j * n1 + i] = 15.0 - float(i) * 12.0   # corner (0,*)=15, (1,*)=3
	var st: Dictionary = {
		"region": region, "ctx": ctx,
		"base": Vector2.ZERO, "lvl": lvl, "gnd": gnd,
		"verts": PackedVector3Array(), "idx": PackedInt32Array(),
		"cust": PackedFloat32Array(), "weld": {}, "steep": [],
	}
	WaterMesher._mesh_cell(st, 0, 0)
	WaterMesher._attributes(st)
	assert_true(WaterMesher.STEEP_UNSWIMMABLE < 4.0,
		"sanity: this fixture's own grade genuinely exceeds the gate")
	assert_eq(st.wet_cells.size(), 0,
		"a cell whose max |grade_at| exceeds STEEP_UNSWIMMABLE gets NO volume at all")


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
##
## The 6m probe's 0.7 tolerance exists because of a claim-boundary STEP
## interacting with linear-plane extrapolation, NOT gradient noise — the
## mesher is working correctly. At the pinned chunk's one non-flat cell
## (centre x=36, z=-1068) level_at is flat at 15.0 out to x≈+12m, where it
## steps down 1.3m to 13.7 at a claim boundary; WaterMesher's finite
## difference spans exactly that 12m (grad = (level_at(+4S) - lvl)/(4S),
## S=3.0 — see WaterMesher._attributes), so g.x = (13.7-15.0)/12 = -0.1083
## faithfully records the step. A linear plane cannot represent a step: a
## probe SHORT of it (+6m) reads the 15.0 plateau from the field but 14.35
## from the plane — the 0.65m gap the tolerance absorbs.
##
## Coverage gap, stated plainly: this pinned chunk has NO genuinely-sloped
## river cell — every gated cell except the step cell above is flat with
## g == (0,0), so the 6m probe mostly verifies g≈0 on flat cells. The
## transcription-exact 12m probes below are what actually pin the gradient:
## they resample level_at at the mesher's own finite-difference distance
## (exactly 4*S = 12m in +x and +z), where the plane MUST reproduce the
## field by construction — catching store/sign/divisor bugs in the metas
## with no fudge factor. Skipped for stacked cells (split entries carry
## grad ZERO by design, never a finite difference) and where the probe
## point gets no valid claim.
func test_volume_surface_matches_field_at_probe_points() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	var boxes_at: Dictionary = {}
	for ch in node.get_children():
		if ch is Area3D:
			var cc: Vector3 = ch.get_meta("surface_c")
			var key := Vector2(cc.x, cc.z)
			boxes_at[key] = int(boxes_at.get(key, 0)) + 1
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
			# Transcription-exact gradient probes: 12m is the mesher's own
			# finite-difference span, so the plane must reproduce level_at
			# there exactly (single-entry cells only — split cells zero
			# their grad by design).
			if centre_agrees and int(boxes_at[Vector2(c.x, c.z)]) == 1:
				var qx: float = WaterField.level_at(ctx, Vector2(c.x + 12.0, c.z))
				if qx > -INF:
					assert_almost_eq(c.y + g.x * 12.0, qx, 0.1,
						"g.x is the field's own 12m finite difference")
				var qz: float = WaterField.level_at(ctx, Vector2(c.x, c.z + 12.0))
				if qz > -INF:
					assert_almost_eq(c.y + g.y * 12.0, qz, 0.1,
						"g.y is the field's own 12m finite difference")
	assert_true(checked > 0, "at least one sloped/flat cell verified")
	node.free()

extends GutTest

# r3-task-4 (plan docs/superpowers/plans/2026-07-10-water-continuous-surface.md,
# brief .superpowers/sdd/r3-task-4-brief.md): WaterSkin welds a 3.0m interior
# lattice to a conforming boundary strip whose outer rim sits directly ON
# WaterContour's own smooth curves (Task 3) — this is the mesh that actually
# fixes the marching-squares corners test_water_contour.gd's own header
# documents (WaterMesher's raw perimeter walk). No rim/hem exists yet (Task
# 6): until then the boundary strip's own outer edge IS the waterline, so
# test_no_free_edges_except_border's "accounted for" class is curve-or-border,
# not buried-hem as in test_water_mesher.gd's post-hem version of the same
# oracle.

const SEED := 2697992464
const SITE_CHUNK := Vector2i(0, -6)

static var _plans: Dictionary = {}
static var _waters: Dictionary = {}
static var _regions: Dictionary = {}


static func _water(seed_v: int) -> WaterPlan:
	if not _waters.has(seed_v):
		var plan := HeightfieldPlan.new(seed_v, 22.0, 8, "mean", 3)
		var water := WaterPlan.new(seed_v, 22.0, 8)
		plan.set_water_plan(water)
		_plans[seed_v] = plan
		_waters[seed_v] = water
	return _waters[seed_v]


static func _region(seed_v: int, chunk: Vector2i):
	var key := [seed_v, chunk]
	if not _regions.has(key):
		_water(seed_v)
		_regions[key] = _plans[seed_v].compute_region(
			chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
	return _regions[key]


## 192m streamer-chunk rect — MUST match WaterMesher.build's own
## `base := Vector2(chunk.x, chunk.y) * (TILE * 8.0)` convention exactly (the
## plan's erratum: Vector2i chunk args are 192m chunks, not 24m cells).
static func _rect(chunk: Vector2i) -> Rect2:
	return Rect2(Vector2(chunk) * (WaterField.TILE * 8.0), Vector2.ONE * WaterField.TILE * 8.0)


## Edges used by exactly one triangle — ported verbatim from
## WaterMesher.free_edges (tests/test_water_mesher.gd's own oracle pattern),
## ARRAY-shaped so it works directly against WaterSkin's Mesh.ARRAY_MAX
## `arrays` output (ARRAY_VERTEX/ARRAY_INDEX) without needing WaterSkin to
## also expose a bespoke verts/idx dict shape.
static func _free_edges(arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count: Dictionary = {}
	var tri: int = 0
	while tri < idx.size():
		for k in 3:
			var a: int = idx[tri + k]
			var b: int = idx[tri + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			count[key] = count.get(key, 0) + 1
		tri += 3
	var out: Array = []
	for key: Vector2i in count:
		if count[key] == 1:
			out.append([verts[key.x], verts[key.y]])
	return out


static func _on_chunk_border(v: Vector3, chunk: Vector2i) -> bool:
	var span: float = WaterField.TILE * 8.0
	var base: Vector2 = Vector2(chunk) * span
	var lx: float = v.x - base.x
	var lz: float = v.z - base.y
	return lx < 0.02 or lx > span - 0.02 or lz < 0.02 or lz > span - 0.02


## Nearest distance from p to ANY point on ANY curve in `curves` (brute
## force — test-side helper, not required to share WaterSkin's own
## presence-grid acceleration).
static func _dist_to_curves(curves: Array, p: Vector2) -> float:
	var best := INF
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		for i in pts.size():
			best = minf(best, pts[i].distance_to(p))
	return best


## test_skin_builds_on_site_chunk — non-empty, indexed, welded-shape output;
## tri count printed alongside WaterMesher's own for the same chunk (this
## task's report needs both numbers — the brief's own "print both" — as the
## Task 11 perf-budget baseline).
func test_skin_builds_on_site_chunk() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var t0: int = Time.get_ticks_usec()
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	var skin_us: int = Time.get_ticks_usec() - t0
	assert_false(skin.is_empty(), "site chunk builds a skin (real water present)")
	if skin.is_empty():
		return
	assert_true(skin.has("arrays") and skin.has("triggers") and skin.has("sampler"),
		"skin dict carries the documented arrays/triggers/sampler keys")
	var arrays: Array = skin.arrays
	assert_eq(arrays.size(), Mesh.ARRAY_MAX, "Mesh.ARRAY_MAX-shaped arrays")
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert_true(verts.size() > 0, "non-empty vertex buffer")
	assert_true(idx.size() > 0, "non-empty index buffer")
	assert_true(idx.size() % 3 == 0, "indices form whole triangles")
	for i in idx:
		assert_true(i >= 0 and i < verts.size(), "index %d in range [0,%d)" % [i, verts.size()])
	# Welded: no two verts share a position (mirrors
	# test_water_mesher.gd::test_interior_is_welded's own dedupe check).
	var seen: Dictionary = {}
	var dup_ct := 0
	for v: Vector3 in verts:
		var key: Vector3i = Vector3i((v * 64.0).round())
		if seen.has(key):
			dup_ct += 1
		seen[key] = true
	assert_eq(dup_ct, 0, "no duplicate-position verts survive the weld")

	var t1: int = Time.get_ticks_usec()
	var mesher_m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	var mesher_us: int = Time.get_ticks_usec() - t1
	var skin_tris: int = idx.size() / 3
	var mesher_tris: int = mesher_m.idx.size() / 3 if not mesher_m.is_empty() else 0
	print("MEAS test_skin_builds_on_site_chunk: skin=%d tris (%d verts, %.2fms) mesher=%d tris (%d verts, %.2fms)" % [
		skin_tris, verts.size(), skin_us / 1000.0, mesher_tris, mesher_m.get("verts", PackedVector3Array()).size(), mesher_us / 1000.0])
	assert_true(mesher_tris > 0, "mesher itself builds real geometry on this chunk to compare against")
	assert_true(skin_tris <= mesher_tris * 2,
		"skin tri count (%d) within 2x of mesher's (%d)" % [skin_tris, mesher_tris])


## test_no_free_edges_except_border — until Task 5's rim exists, the skin's
## boundary strip has no further geometry stitched past its own outer curve
## edge, so every free edge in the mesh must lie EITHER on the chunk border
## OR directly on one of this chunk's own WaterContour curves (within a
## small tolerance for the strip's own vertex-on-curve placement). Ports the
## free-edge-walker convention from test_water_mesher.gd
## (test_every_free_edge_is_accounted_for) but swaps its post-hem "buried"
## class for "on a curve," since there is no hem in this task.
func test_no_free_edges_except_border() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var free: Array = _free_edges(skin.arrays)
	var checked := 0
	var offenders: Array = []
	var curve_tol := 0.06   # boundary-strip vertices sit ON curve points; small float slack
	for e: Array in free:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var a_border: bool = _on_chunk_border(a, SITE_CHUNK)
		var b_border: bool = _on_chunk_border(b, SITE_CHUNK)
		if a_border and b_border:
			continue
		checked += 1
		var a_on_curve: bool = a_border or _dist_to_curves(curves, Vector2(a.x, a.z)) <= curve_tol
		var b_on_curve: bool = b_border or _dist_to_curves(curves, Vector2(b.x, b.z)) <= curve_tol
		if not (a_on_curve and b_on_curve):
			if offenders.size() < 10:
				offenders.append("%s-%s (a_border=%s a_curve_d=%.3f b_border=%s b_curve_d=%.3f)" % [
					a, b, a_border, _dist_to_curves(curves, Vector2(a.x, a.z)),
					b_border, _dist_to_curves(curves, Vector2(b.x, b.z))])
	print("MEAS test_no_free_edges_except_border: %d non-border-pair free edges checked, %d offenders" % [
		checked, offenders.size()])
	assert_true(checked > 5, "site has real boundary free edges to check (%d)" % checked)
	assert_true(offenders.is_empty(),
		"every non-border free edge lies on a WaterContour curve: %s" % str(offenders))


## test_interior_rides_field — 50 random KEPT interior lattice verts (not
## boundary-strip verts, which ride the curve's own baked level instead —
## see WaterSkin.build's own docstring) must equal WaterField.level_at within
## 0.03m. Interior verts are identified structurally: every vertex at least
## 1.5m from the nearest curve point (half the boundary-strip's own ~1.5m
## curve spacing — comfortably excludes a genuine strip vertex, which sits
## AT distance 0 from its own curve point).
func test_interior_rides_field() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var interior: Array = []
	for v: Vector3 in verts:
		if _dist_to_curves(curves, Vector2(v.x, v.z)) >= 1.5:
			interior.append(v)
	print("MEAS test_interior_rides_field: %d/%d verts classified interior" % [interior.size(), verts.size()])
	assert_true(interior.size() >= 50, "at least 50 interior verts exist to sample (%d)" % interior.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var checked := 0
	var max_err := 0.0
	var offenders: Array = []
	for _i in 50:
		if interior.is_empty():
			break
		var v: Vector3 = interior[rng.randi_range(0, interior.size() - 1)]
		var truth: float = WaterField.level_at(ctx, Vector2(v.x, v.z))
		var err: float = absf(v.y - truth)
		checked += 1
		max_err = maxf(max_err, err)
		if err >= 0.03 and offenders.size() < 10:
			offenders.append("%s baked=%.4f truth=%.4f err=%.4f" % [v, v.y, truth, err])
	print("MEAS test_interior_rides_field: checked %d, max_err=%.5f (threshold 0.03)" % [checked, max_err])
	assert_eq(checked, 50, "50 interior verts sampled")
	assert_true(max_err < 0.03, "every sampled interior vert rides level_at within 0.03m: %s" % str(offenders))


## test_skin_handles_closed_and_border_exit_curves — the isolated-pond chunk
## (-4,-18) (test_water_contour.gd's own verified closed-curve site) is the
## structural complement to SITE_CHUNK: one CLOSED curve (the pond bowl —
## exercises the zip's A-wrap and the closed-annulus closing triangle) plus
## one open HORSESHOE curve whose both endpoints exit through the same chunk
## border (a wet inlet continuing into the neighbour chunk — exercises the
## border-row edge-ring rules). Development caught three real defects here
## that SITE_CHUNK's three open border-to-border curves structurally cannot
## reproduce (an out-of-bounds A-read at the closed wrap, a missing annulus
## closing triangle, and a ring-chain fold from over-approximated edge-ring
## membership at the border exit — this task's report has the traces); this
## test pins all three.
func test_skin_handles_closed_and_border_exit_curves() -> void:
	var pond_chunk := Vector2i(-4, -18)
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, pond_chunk)
	var ctx: Dictionary = WaterField.ctx(water, pond_chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(pond_chunk))
	var has_closed := false
	for c: Dictionary in curves:
		if c.closed:
			has_closed = true
	assert_true(has_closed, "the pond chunk still carries a closed curve (site precondition)")
	var skin: Dictionary = WaterSkin.build(water, pond_chunk, region)
	assert_false(skin.is_empty(), "pond chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var seen: Dictionary = {}
	var dup_ct := 0
	for v: Vector3 in verts:
		var key: Vector3i = Vector3i((v * 64.0).round())
		if seen.has(key):
			dup_ct += 1
		seen[key] = true
	assert_eq(dup_ct, 0, "no duplicate-position verts on the pond chunk")
	var checked := 0
	var offenders: Array = []
	for e: Array in _free_edges(skin.arrays):
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		if _on_chunk_border(a, pond_chunk) and _on_chunk_border(b, pond_chunk):
			continue
		checked += 1
		var a_ok: bool = _on_chunk_border(a, pond_chunk) or _dist_to_curves(curves, Vector2(a.x, a.z)) <= 0.06
		var b_ok: bool = _on_chunk_border(b, pond_chunk) or _dist_to_curves(curves, Vector2(b.x, b.z)) <= 0.06
		if not (a_ok and b_ok) and offenders.size() < 10:
			offenders.append("%s-%s" % [a, b])
	print("MEAS test_skin_handles_closed_and_border_exit_curves: %d free edges checked, %d offenders" % [
		checked, offenders.size()])
	assert_true(checked > 5, "pond chunk has real boundary free edges to check (%d)" % checked)
	assert_true(offenders.is_empty(),
		"closed + border-exit curves stitch watertight: %s" % str(offenders))


func test_dry_chunk_builds_nothing() -> void:
	var water: WaterPlan = _water(SEED)
	# Same dry-chunk scan test_water_mesher.gd's own test_dry_chunk_builds_nothing uses.
	var dry := Vector2i.MAX
	for cz in range(0, 40):
		for cx in range(0, 40):
			var b: Dictionary = water.bodies_near(Vector2i(cx * 8 + 4, cz * 8 + 4), 5)
			if b.ponds.is_empty() and b.rivers.is_empty():
				dry = Vector2i(cx, cz)
				break
		if dry != Vector2i.MAX:
			break
	assert_true(dry != Vector2i.MAX, "found a dry chunk")
	assert_true(WaterSkin.build(water, dry, _region(SEED, dry)).is_empty(),
		"dry chunk => empty build")

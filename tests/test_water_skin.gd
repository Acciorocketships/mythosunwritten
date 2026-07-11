extends GutTest

# r3-task-4/5 (plan docs/superpowers/plans/2026-07-10-water-continuous-surface.md,
# briefs .superpowers/sdd/r3-task-4-brief.md, r3-task-5-brief.md): WaterSkin
# welds a 3.0m interior lattice to a conforming boundary strip whose outer
# rim sits directly ON WaterContour's own smooth curves (Task 3) — this is
# the mesh that actually fixes the marching-squares corners
# test_water_contour.gd's own header documents (WaterMesher's raw perimeter
# walk) — PLUS (Task 5) a meniscus rim that curls the strip's own curve edge
# down and outward into a buried seal under the terrain. Task 4 left the
# curve itself as the mesh's free edge ("no rim yet"); Task 5's rim heals
# that edge into interior geometry and TIGHTENS the invariant:
# test_free_edges_only_buried_rim_or_border's "accounted for" class is now
# buried-outer-row(row3)-or-border, replacing Task 4's curve-or-border.

const SEED := 2697992464
const SITE_CHUNK := Vector2i(0, -6)

# --- Task 5 rim classification (mirrors WaterSkin's OWN row2/row3 numeric
# structure, not its reach/pinch formula — see _on_rim_outer_row) ---
const RIM_MAX_REACH := 0.7    # >= WaterSkin.RIM_ROW3_REACH (0.55) with slack
const RIM_ROW3_Y_GATE := 0.25 # strictly between row2's fixed -0.18 and row3's -0.30 ceiling
const RIM_BURY_GATE := 0.25   # brief's own "test_rim_outer_row_is_buried ... >= 0.25"

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


## Nearest curve point to p across every curve, returning both its distance
## and its own water level — the level is what _on_rim_outer_row needs (row3
## is defined relative to ITS OWN curve point's level, not a global constant).
static func _nearest_curve_pt(curves: Array, p: Vector2) -> Dictionary:
	var best := INF
	var best_level := 0.0
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		var levels: PackedFloat32Array = c.levels
		for i in pts.size():
			var d: float = pts[i].distance_to(p)
			if d < best:
				best = d
				best_level = levels[i]
	return {"dist": best, "level": best_level}


## True when v is a meniscus-rim OUTER (row3) vertex — Task 5's one allowed
## off-curve free-edge class. Deliberately does NOT reproduce WaterSkin's own
## reach/pinch/wall-blend formula (that would test the implementation against
## itself and could never catch a reach/pinch bug); instead it exploits the
## brief's own NUMERIC structure, which is a property of the row DEFINITIONS,
## not of any particular implementation: row0 sits at level L, row1 at
## L-0.02, row2 at a FIXED L-0.18 (no ground dependency), and row3 at
## min(L-0.30, ground-0.30) <= L-0.30 always. A y-gate strictly between
## row2's ceiling (-0.18) and row3's ceiling (-0.30) — RIM_ROW3_Y_GATE=0.25 —
## therefore admits row3 and ONLY row3, regardless of what reach WaterSkin
## chose at a wall-pinched or blended point; RIM_MAX_REACH (0.7, comfortably
## past the brief's own max reach of 0.55) scopes the search to "near some
## curve point" so an unrelated low-lying vertex elsewhere in the mesh (e.g.
## a different curve reach downstream at a lower level) can't false-positive.
static func _on_rim_outer_row(curves: Array, v: Vector3) -> bool:
	var near: Dictionary = _nearest_curve_pt(curves, Vector2(v.x, v.z))
	return near.dist <= RIM_MAX_REACH and v.y <= near.level - RIM_ROW3_Y_GATE


## --- Task 6 (flow frames + real normals) test helpers ---

## Brute-force point-to-trace-polyline distance, and its min over every trace
## in ctx.rivers — deliberately independent of WaterSkin's own projection
## code (_project_on_trace/_flow_frame_at), so a river/pond-mode test built
## on this cannot validate the implementation against itself (same discipline
## _on_rim_outer_row's own docstring documents for the Task 5 rim tests).
static func _dist_point_to_trace(tr: RiverTrace, p: Vector2) -> float:
	var pts: PackedVector2Array = tr.points
	var n: int = pts.size()
	var best := INF
	for i in n - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg: Vector2 = b - a
		var seg_len2: float = seg.length_squared()
		var t: float = clampf((p - a).dot(seg) / seg_len2, 0.0, 1.0) if seg_len2 > 0.000001 else 0.0
		best = minf(best, p.distance_to(a + seg * t))
	return best


static func _dist_to_rivers(ctx: Dictionary, p: Vector2) -> float:
	var best := INF
	for tr: RiverTrace in ctx.rivers:
		best = minf(best, _dist_point_to_trace(tr, p))
	return best


## Linear scan for a welded vertex at `target` within `tol` — the same
## pattern test_rim_welds_to_strip already uses inline, factored out so the
## Task 6 tests can look up a specific curve point's own baked vertex (and
## read back its CUSTOM0/normal) without re-deriving WaterSkin's own weld key.
static func _find_vertex(verts: PackedVector3Array, target: Vector3, tol: float) -> int:
	for i in verts.size():
		if verts[i].distance_to(target) <= tol:
			return i
	return -1


## Structurally locates curve point (p, nrm2d, level)'s own row2 rim vertex —
## WITHOUT reproducing WaterSkin's own reach/wall-blend formula (same
## discipline _on_rim_outer_row already documents): row2 is always exactly
## `level - 0.18` (the brief's own fixed, ground-independent row2 height,
## mirrored here as a literal rather than a WaterSkin.RIM_ROW2_DROP reference
## for the same "don't test the implementation against itself" reason),
## offset from `p` PURELY along the curve's own outward normal n̂ (no
## tangential component) by SOME reach in (0, 0.35] — this searches for a
## vertex matching the height exactly and the offset DIRECTION (not
## magnitude), so it finds row2 regardless of whatever reach the wall blend
## actually chose at this point.
static func _find_row2_vertex(verts: PackedVector3Array, p: Vector2, nrm2d: Vector2, level: float) -> int:
	var target_y: float = level - 0.18
	for i in verts.size():
		var v: Vector3 = verts[i]
		if absf(v.y - target_y) > 0.01:
			continue
		var off: Vector2 = Vector2(v.x, v.z) - p
		var along: float = off.dot(nrm2d)
		var cross: float = off.dot(Vector2(-nrm2d.y, nrm2d.x))
		if along >= -0.01 and along <= 0.4 and absf(cross) < 0.05:
			return i
	return -1


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


## test_free_edges_only_buried_rim_or_border (r3-task-5-brief.md's own name —
## the FINAL form of the free-edge invariant): now that the meniscus rim
## exists, Task 4's old "on a curve" class is GONE — the rim's row0-row1 band
## covers every curve-chain edge the strip used to leave free (see
## WaterSkin._rim's own docstring on this exact healing mechanism), so a
## surviving non-border free edge may only lie on the rim's own buried OUTER
## row (row3; _on_rim_outer_row). Ports the free-edge-walker convention from
## test_water_mesher.gd (test_every_free_edge_is_accounted_for), same as
## Task 4's version, with the accounted-for class swapped.
func test_free_edges_only_buried_rim_or_border() -> void:
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
	for e: Array in free:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var a_border: bool = _on_chunk_border(a, SITE_CHUNK)
		var b_border: bool = _on_chunk_border(b, SITE_CHUNK)
		if a_border and b_border:
			continue
		checked += 1
		var a_ok: bool = a_border or _on_rim_outer_row(curves, a)
		var b_ok: bool = b_border or _on_rim_outer_row(curves, b)
		if not (a_ok and b_ok):
			if offenders.size() < 10:
				offenders.append("%s-%s (a_border=%s a_rim=%s b_border=%s b_rim=%s)" % [
					a, b, a_border, _on_rim_outer_row(curves, a), b_border, _on_rim_outer_row(curves, b)])
	print("MEAS test_free_edges_only_buried_rim_or_border: %d non-border-pair free edges checked, %d offenders" % [
		checked, offenders.size()])
	assert_true(checked > 5, "site has real boundary free edges to check (%d)" % checked)
	assert_true(offenders.is_empty(),
		"every non-border free edge lies on the meniscus rim's buried outer row: %s" % str(offenders))


## test_rim_outer_row_is_buried (brief's own name) — every row3 vertex sits
## >= 0.25m below the region's own ground at that xz (brief's literal
## formula guarantees >=0.30; 0.25 matches the brief's own stated threshold,
## leaving slack for the structural classifier above rather than for any
## real precision gap — row3's own y = min(L-0.30, g-0.30) is exact). Row3
## verts are the SAME _on_rim_outer_row structural class the free-edge test
## uses, so this test independently checks the ONE property that class is
## named for (burial), keeping the two tests from validating each other in a
## circle.
func test_rim_outer_row_is_buried() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var checked := 0
	var offenders: Array = []
	for v: Vector3 in verts:
		if not _on_rim_outer_row(curves, v):
			continue
		checked += 1
		var g: float = TerrainSurfaceField.surface_y(region, v.x, v.z)
		var buried: float = g - v.y
		if buried < RIM_BURY_GATE and offenders.size() < 10:
			offenders.append("%s buried=%.3f (ground=%.3f)" % [v, buried, g])
	print("MEAS test_rim_outer_row_is_buried: %d row3 verts checked, %d offenders" % [checked, offenders.size()])
	assert_true(checked > 5, "site has real rim outer-row verts to check (%d)" % checked)
	assert_true(offenders.is_empty(),
		"every rim outer-row vert sits >=%.2fm under ground: %s" % [RIM_BURY_GATE, str(offenders)])


## test_rim_welds_to_strip (brief's own name) — row0 (the rim's innermost
## row, reused from _boundary_strip's own curve_vi — see WaterSkin._rim's
## docstring) never duplicates the strip's own vertex: exactly one mesh
## vertex exists at each curve point's own (p, level) position. This is the
## externally-observable proxy for "row0 index == strip index" (the weld
## dict's own semantics make index equality automatic once the position+level
## key matches, per _weld_vert; what could actually go WRONG — and what this
## test actually catches — is a stray near-duplicate from an off-by-epsilon
## position or level mismatch between the two call sites).
func test_rim_welds_to_strip() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	# Tight on purpose: row1 sits exactly RIM_ROW1_DROP=0.02 BELOW row0 at the
	# SAME xz (the brief's own hairline meniscus-crest lip) — a tolerance at
	# or above 0.02 double-counts row1 as a "hit" for row0's own target
	# (caught directly: 10 offenders each reporting hits=2 at exactly the
	# 0.02 boundary before this was tightened). 0.005 sits safely below that
	# real intentional neighbour and comfortably above float weld noise.
	var tol := 0.005
	var checked := 0
	var offenders: Array = []
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		var levels: PackedFloat32Array = c.levels
		for i in pts.size():
			var target := Vector3(pts[i].x, levels[i], pts[i].y)
			var hits := 0
			for v: Vector3 in verts:
				if v.distance_to(target) <= tol:
					hits += 1
			checked += 1
			if hits != 1 and offenders.size() < 10:
				offenders.append("%s hits=%d" % [target, hits])
	print("MEAS test_rim_welds_to_strip: %d curve points checked, %d offenders" % [checked, offenders.size()])
	assert_true(checked > 5, "site has real curve points to check (%d)" % checked)
	assert_true(offenders.is_empty(),
		"every curve point has exactly one welded vertex (row0 reuses the strip's own index): %s" % str(offenders))


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
		# Tightened per Task 5 (test_free_edges_only_buried_rim_or_border's own
		# class): the rim heals every curve-level free edge Task 4 left behind,
		# so a surviving non-border free edge must lie on the rim's buried
		# outer row instead of merely "near a curve point."
		var a_ok: bool = _on_chunk_border(a, pond_chunk) or _on_rim_outer_row(curves, a)
		var b_ok: bool = _on_chunk_border(b, pond_chunk) or _on_rim_outer_row(curves, b)
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


## Shared walker for test_s_is_continuous_along_river: reads curve c's own
## welded row0 vertices over curve indices [lo..hi], walking hi -> lo (this
## curve's index order runs upstream, so the reversed walk reads downstream /
## s-INcreasing, matching the brief's "strictly increasing" wording), and
## asserts per step: s strictly increases AND |Δs − spatial step| < 0.5 (the
## brief's own tolerance).
func _assert_s_window(skin: Dictionary, c: Dictionary, lo: int, hi: int, label: String) -> void:
	var pts: PackedVector2Array = c.pts
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var cust: PackedFloat32Array = skin.arrays[Mesh.ARRAY_CUSTOM0]
	var s_vals: Array = []
	var walk_pts: Array = []
	for i in range(hi, lo - 1, -1):
		var target := Vector3(pts[i].x, c.levels[i], pts[i].y)
		var vi: int = _find_vertex(verts, target, 0.01)
		assert_true(vi >= 0, "%s: curve point %d has a welded mesh vertex" % [label, i])
		if vi < 0:
			return
		s_vals.append(cust[vi * 4 + 0])
		walk_pts.append(pts[i])
	var checked := 0
	var worst := 0.0
	var offenders: Array = []
	for k in range(0, s_vals.size() - 1):
		var d_space: float = walk_pts[k].distance_to(walk_pts[k + 1])
		var d_s: float = s_vals[k + 1] - s_vals[k]
		checked += 1
		worst = maxf(worst, absf(d_s - d_space))
		if d_s <= 0.0:
			offenders.append("%s k=%d s not strictly increasing: %.4f -> %.4f" % [label, k, s_vals[k], s_vals[k + 1]])
		elif absf(d_s - d_space) >= 0.5:
			offenders.append("%s k=%d |Δs(%.4f) - step(%.4f)|=%.4f >= 0.5" % [label, k, d_s, d_space, absf(d_s - d_space)])
	print("MEAS test_s_is_continuous_along_river[%s]: %d steps checked, worst |Δs-step|=%.4f, %d offenders" % [
		label, checked, worst, offenders.size()])
	assert_eq(checked, hi - lo, "%s: %d consecutive steps checked" % [label, hi - lo])
	assert_true(offenders.is_empty(),
		"%s: s strictly increases and tracks the real spatial step along the river: %s" % [label, str(offenders)])


## test_s_is_continuous_along_river (brief's own name) — CUSTOM0.x (arc
## length s) walked along 30 consecutive points of a REAL river shoreline
## curve (row0 vertices — see WaterSkin._rim's own docstring on why row0 IS
## the strip's welded vertex) must strictly increase, with each step's own
## |Δs| tracking the vertices' real-world spacing within 0.5m — s
## approximates true arc length, so a baked value that drifts from the
## actual distance walked would misdrive Task 8's travelling-wave phase (the
## Task 6 reviewer quantified it: a 1.0m per-step shortfall is ~109° of phase
## error on the λ≈3.3m river train and ~185° on the λ≈1.8m crossed train — a
## third to half a wave cycle of crests bunching at one shoreline spot).
## SITE_CHUNK's curve[0] runs from a river reach into its own terminal lake
## (verified this task: dist-to-nearest-trace ranges 0.76m at pts[0] out to
## 32.98m by pts[142] — see r3-task-6-report.md); pts[0..36] sits in the
## river-close end (all <18m from a real trace, checked below as a site
## precondition independent of WaterSkin's own bake).
## TWO windows assert, per the Task 6 review verdict (r3-task-6-report.md,
## "Fix: bend s-compression"):
##   - pts[0..30], the BEND stretch: pts[4..8] sweeps past a ~6.2° bend in
##     the claimed trace's polyline (trace ti=1, sample 9) from ~9m offset.
##     Nearest-point projection stalls at a polyline corner (the whole
##     outside wedge of angular width θ projects onto the corner vertex, so
##     s stops advancing for d·θ ≈ 0.96m of shoreline walk) — this window
##     was RED against the un-blended Task 6 projection (worst
##     |Δs−step|=1.008, transcript in the report) and is the regression pin
##     for WaterSkin._project_on_trace's segment-tie blend, which spreads
##     that geometric arc-length deficit over the tie band instead of
##     concentrating it in one step.
##   - pts[6..36], the CLEAN stretch (no wedge transition mid-window): pins
##     that the blend does not degrade ordinary shoreline tracking.
## This curve's OWN point order runs upstream (index increasing = toward the
## source, s DEcreasing) — _assert_s_window walks each window in the opposite
## (index-decreasing, s-increasing) direction; the underlying data is
## identical either way.
func test_s_is_continuous_along_river() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	assert_true(curves.size() > 0, "site chunk has curves")
	if curves.is_empty():
		return
	var c: Dictionary = curves[0]
	var pts: PackedVector2Array = c.pts
	assert_true(pts.size() >= 37, "curve[0] has >=37 points to walk pts[0..36] (%d)" % pts.size())
	if pts.size() < 37:
		return
	for i in range(0, 37):
		assert_true(_dist_to_rivers(ctx, pts[i]) < 18.0,
			"pts[%d] sits within the brief's own river gate (site precondition)" % i)
	_assert_s_window(skin, c, 0, 30, "bend pts[0..30]")
	_assert_s_window(skin, c, 6, 36, "clean pts[6..36]")


## test_slope_is_continuous (brief's own name) — CUSTOM0.z (profile slope)
## between ADJACENT points of the same river window test_s_is_continuous_
## along_river uses (pts[6..36] — see that test's own docstring for why the
## window starts at 6, not 0) must never jump by >=0.15 — the brief's own
## literal tolerance for its "central-difference prof at the projected
## segment, sampled continuously" rule (see WaterSkin._project_on_trace's own
## docstring): a real jump there would show up as a visible pop in the Task 8
## wave-train amplitude (A ≈ base*(1+k_slope*slope)), which is keyed directly
## off this lane.
func test_slope_is_continuous() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	assert_true(curves.size() > 0, "site chunk has curves")
	if curves.is_empty():
		return
	var c: Dictionary = curves[0]
	var pts: PackedVector2Array = c.pts
	assert_true(pts.size() >= 37, "curve[0] has >=37 points to walk pts[6..36] (%d)" % pts.size())
	if pts.size() < 37:
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var cust: PackedFloat32Array = skin.arrays[Mesh.ARRAY_CUSTOM0]
	var slopes: Array = []
	for i in range(36, 5, -1):
		var target := Vector3(pts[i].x, c.levels[i], pts[i].y)
		var vi: int = _find_vertex(verts, target, 0.01)
		assert_true(vi >= 0, "curve point %d has a welded mesh vertex" % i)
		if vi < 0:
			return
		slopes.append(cust[vi * 4 + 2])
	var checked := 0
	var offenders: Array = []
	for k in range(0, 30):
		var d_slope: float = absf(slopes[k + 1] - slopes[k])
		checked += 1
		if d_slope >= 0.15:
			offenders.append("k=%d |Δslope|=%.4f >= 0.15 (%.4f -> %.4f)" % [k, d_slope, slopes[k], slopes[k + 1]])
	print("MEAS test_slope_is_continuous: %d adjacent pairs checked, %d offenders" % [checked, offenders.size()])
	assert_true(checked == 30, "30 adjacent pairs checked")
	assert_true(offenders.is_empty(), "slope never jumps by >=0.15 between adjacent river verts: %s" % str(offenders))


## test_pond_frames_are_calm (brief's own name) — lake verts get slope==0 and
## d==0 (brief's literal pond/lake rule: "no trace within 18m"; s==0 is also
## checked here since WaterSkin's pond branch returns all three as one hard
## early-return, per _flow_frame_at's own docstring). Pond chunk (-4,-18) is
## NOT uniformly far from every river — it carries a real feeding inlet
## (verified this task: curve[1]'s own dist-to-nearest-trace ranges from
## 0.38m up to 36.09m across its 124 points, see r3-task-6-report.md) — so
## this test scopes to the verified-calm stretch of the pond's own closed
## curve (pts[39..78], all independently confirmed >=18m from every trace
## below) rather than every vertex in the chunk, which would wrongly include
## the inlet's own river-engaged points.
func test_pond_frames_are_calm() -> void:
	var pond_chunk := Vector2i(-4, -18)
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, pond_chunk)
	var ctx: Dictionary = WaterField.ctx(water, pond_chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(pond_chunk))
	var closed_curve: Dictionary = {}
	for c: Dictionary in curves:
		if c.closed:
			closed_curve = c
			break
	assert_true(not closed_curve.is_empty(), "pond chunk has a closed (pond bowl) curve (site precondition)")
	if closed_curve.is_empty():
		return
	var pts: PackedVector2Array = closed_curve.pts
	assert_true(pts.size() >= 79, "pond curve has >=79 points for the verified-calm window (%d)" % pts.size())
	if pts.size() < 79:
		return
	for i in range(39, 79):
		assert_true(_dist_to_rivers(ctx, pts[i]) >= 18.0,
			"pts[%d] sits outside the brief's own river gate (site precondition)" % i)
	var skin: Dictionary = WaterSkin.build(water, pond_chunk, region)
	assert_false(skin.is_empty(), "pond chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var cust: PackedFloat32Array = skin.arrays[Mesh.ARRAY_CUSTOM0]
	var checked := 0
	var offenders: Array = []
	for i in range(39, 79):
		var target := Vector3(pts[i].x, closed_curve.levels[i], pts[i].y)
		var vi: int = _find_vertex(verts, target, 0.01)
		assert_true(vi >= 0, "curve point %d has a welded mesh vertex" % i)
		if vi < 0:
			continue
		checked += 1
		var s_v: float = cust[vi * 4 + 0]
		var d_v: float = cust[vi * 4 + 1]
		var slope_v: float = cust[vi * 4 + 2]
		if s_v != 0.0 or d_v != 0.0 or slope_v != 0.0:
			if offenders.size() < 10:
				offenders.append("%s s=%.4f d=%.4f slope=%.4f" % [target, s_v, d_v, slope_v])
	print("MEAS test_pond_frames_are_calm: %d curve points checked, %d offenders" % [checked, offenders.size()])
	assert_true(checked == 40, "40 curve points checked")
	assert_true(offenders.is_empty(), "every calm-window pond vert has s==0, d==0, slope==0: %s" % str(offenders))


## test_rim_normals_curl_outward (controller brief's own name) — two
## independent checks of the controller addition (real vertex normals,
## replacing the Task 4-5 blanket Vector3.UP):
##   1. At a non-wall rim point, row0's normal is near-UP (the meniscus crest
##      reads as flat water) and row2's normal has a positive outward (n̂)
##      component (the visible curl) — WaterSkin._curl_normal's own contract.
##      Located structurally (_find_row2_vertex — does NOT reproduce
##      WaterSkin's own reach/wall-blend formula, same discipline
##      _on_rim_outer_row already documents) on the pond chunk's own closed
##      curve, whose 2 non-wall points were verified this task (see
##      r3-task-6-report.md).
##   2. On SITE_CHUNK, at least one interior-classified vertex (>=1.5m from
##      any curve point, mirrors test_interior_rides_field's own classifier)
##      whose surface genuinely slopes (an INDEPENDENT, test-side central
##      difference of WaterField.level_at at +-1.5m — the same formula the
##      brief prescribes for _interior_normal, so this is a wiring/weld-
##      average check, not a reach/pinch-style tautology guard) has a baked
##      normal that measurably deviates from UP.
func test_rim_normals_curl_outward() -> void:
	var water: WaterPlan = _water(SEED)
	var pond_chunk := Vector2i(-4, -18)
	var region = _region(SEED, pond_chunk)
	var ctx: Dictionary = WaterField.ctx(water, pond_chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(pond_chunk))
	var found := false
	var p := Vector2.ZERO
	var nrm2d := Vector2.ZERO
	var lvl := 0.0
	for c: Dictionary in curves:
		var wall: PackedByteArray = c.wall
		var pts: PackedVector2Array = c.pts
		for i in wall.size():
			if wall[i] == 0:
				p = pts[i]
				nrm2d = c.normals[i]
				lvl = c.levels[i]
				found = true
				break
		if found:
			break
	assert_true(found, "pond chunk has a non-wall curve point (site precondition)")
	if not found:
		return
	var skin: Dictionary = WaterSkin.build(water, pond_chunk, region)
	assert_false(skin.is_empty(), "pond chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = skin.arrays[Mesh.ARRAY_NORMAL]
	assert_eq(norms.size(), verts.size(), "one normal per vertex")
	var vi0: int = _find_vertex(verts, Vector3(p.x, lvl, p.y), 0.01)
	var vi2: int = _find_row2_vertex(verts, p, nrm2d, lvl)
	assert_true(vi0 >= 0, "row0 vertex found at the non-wall point")
	assert_true(vi2 >= 0, "row2 vertex found at the non-wall point")
	if vi0 < 0 or vi2 < 0:
		return
	var n0: Vector3 = norms[vi0]
	var n2: Vector3 = norms[vi2]
	var outward3 := Vector3(nrm2d.x, 0.0, nrm2d.y)
	print("MEAS test_rim_normals_curl_outward: non-wall pt=%s row0.normal=%s (dot_up=%.4f) row2.normal=%s (outward_comp=%.4f)" % [
		p, n0, n0.dot(Vector3.UP), n2, n2.dot(outward3)])
	assert_true(n0.dot(Vector3.UP) > 0.9, "row0's normal is near-UP at a non-wall point: %s" % n0)
	assert_true(n2.dot(outward3) > 0.0, "row2's normal has a positive outward component at a non-wall point: %s" % n2)

	# Part 2: interior normals deviate from UP where the surface slopes.
	var region2 = _region(SEED, SITE_CHUNK)
	var ctx2: Dictionary = WaterField.ctx(water, SITE_CHUNK, region2)
	var curves2: Array = WaterContour.curves(ctx2, _rect(SITE_CHUNK))
	var skin2: Dictionary = WaterSkin.build(water, SITE_CHUNK, region2)
	assert_false(skin2.is_empty(), "site chunk builds a skin")
	if skin2.is_empty():
		return
	var verts2: PackedVector3Array = skin2.arrays[Mesh.ARRAY_VERTEX]
	var norms2: PackedVector3Array = skin2.arrays[Mesh.ARRAY_NORMAL]
	var e := 1.5
	var sloped_found := 0
	var offenders2: Array = []
	var sample_line := ""
	for vi in verts2.size():
		var v: Vector3 = verts2[vi]
		var p2 := Vector2(v.x, v.z)
		if _dist_to_curves(curves2, p2) < 1.5:
			continue
		var hx1: float = WaterField.level_at(ctx2, p2 + Vector2(e, 0.0))
		var hx0: float = WaterField.level_at(ctx2, p2 - Vector2(e, 0.0))
		var hz1: float = WaterField.level_at(ctx2, p2 + Vector2(0.0, e))
		var hz0: float = WaterField.level_at(ctx2, p2 - Vector2(0.0, e))
		var dhdx := 0.0
		var dhdz := 0.0
		if hx1 > -INF and hx0 > -INF:
			dhdx = (hx1 - hx0) / (2.0 * e)
		if hz1 > -INF and hz0 > -INF:
			dhdz = (hz1 - hz0) / (2.0 * e)
		var slope_mag: float = sqrt(dhdx * dhdx + dhdz * dhdz)
		if slope_mag <= 0.1:
			continue
		sloped_found += 1
		var dot_up: float = norms2[vi].dot(Vector3.UP)
		if sloped_found == 1:
			sample_line = "%s slope_mag=%.4f normal=%s dot_up=%.4f" % [v, slope_mag, norms2[vi], dot_up]
		if dot_up > 0.999 and offenders2.size() < 10:
			offenders2.append("%s slope_mag=%.4f dot_up=%.4f" % [v, slope_mag, dot_up])
	print("MEAS test_rim_normals_curl_outward: interior sloped verts found=%d, sample: %s" % [sloped_found, sample_line])
	assert_true(sloped_found > 0, "site has at least one interior vertex with a real (>0.1) surface slope")
	assert_true(offenders2.is_empty(),
		"every sloped interior vertex's normal measurably deviates from UP: %s" % str(offenders2))

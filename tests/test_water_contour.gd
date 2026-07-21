extends GutTest

# r3-task-2 (plan docs/superpowers/plans/2026-07-10-water-continuous-surface.md,
# brief .superpowers/sdd/r3-task-2-brief.md) recorded the RED evidence that the
# pre-WaterContour boundary (the old marching-squares mesher's own
# perimeter-walk on a 3m sub-grid) produces angular, grid-quantized corners:
# max_turn_deg (raw, all corners) = 90.00 at SITE_CHUNK, isolated skip-guard
# active, transcript preserved in .superpowers/sdd/r3-task-2-report.md ("Red
# run transcript" section — 9 offending corners, 45-90 degree turns, all on
# the OLD mesher's own boundary). r3-task-3 (.superpowers/sdd/
# r3-task-3-brief.md) is what makes this GREEN: WaterContour.curves() now
# EXISTS and replaces the boundary source entirely — this file's
# test_pond_yields_smooth_closed_curve below is the direct GREEN half of that
# red-green pair, measuring the NEW curve's own turn angle instead of walking
# the old mesher's free edges (the old _sheet_free_edges/_chain_edges/_is_wall
# mesh-walking helpers this file used to carry are gone: WaterContour.curves()
# supplies pts/wall/normals directly, so there is no mesh to walk any more).

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


static func _ctx(seed_v: int, chunk: Vector2i) -> Dictionary:
	return WaterField.ctx(_water(seed_v), chunk, _region(seed_v, chunk))


static func _rect(chunk: Vector2i) -> Rect2:
	return Rect2(Vector2(chunk) * (WaterField.TILE * 8.0), Vector2.ONE * WaterField.TILE * 8.0)


## INDEPENDENT wall cross-check (hardening pass): the same 8-ring scan Task
## 2's oracle used, kept as a GROUND-TRUTH witness against WaterContour's
## own single-outward-normal wall probe — NOT as the primary wall source
## (the curve's own flag is; see _curve_turn_stats). Rise is measured
## relative to the point's own water level, the same anchor Task 2's
## _is_wall used (a mesh boundary vert's v.y rides the water level, the old
## mesher's own boundary-vertex convention). MAX over 8 directions at both
## probe distances is the most GENEROUS wall reading: a point only reads
## non-wall here if EVERY direction around it is gentle — so
## formula-wall && !ring-wall is a structural impossibility for a correct
## formula (the formula probes ONE direction; if that one direction rises,
## some ring direction rises too on this quantized terrain) and any such
## point is evidence of over-tagging.
const _RING: Array[Vector2] = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.70710678, 0.70710678), Vector2(-0.70710678, 0.70710678),
	Vector2(0.70710678, -0.70710678), Vector2(-0.70710678, -0.70710678),
]


static func _ring_wall(region, p: Vector2, lvl: float) -> bool:
	for d: Vector2 in _RING:
		var g05: float = TerrainSurfaceField.surface_y(region, p.x + d.x * 0.5, p.y + d.y * 0.5)
		var g15: float = TerrainSurfaceField.surface_y(region, p.x + d.x * 1.5, p.y + d.y * 1.5)
		if (g05 - lvl) / 0.5 > WaterContour.WALL_SLOPE or (g15 - lvl) / 1.5 > WaterContour.WALL_SLOPE:
			return true
	return false


## A contour wall flag may intentionally bridge one short, gentle sample at
## a rounded wall turn. Validate that exception against the independent ring
## witness on both sides: real walls must bracket it within four samples and
## their outward normals must describe a substantial turn.
static func _valid_short_corner_bridge(region, c: Dictionary, i: int) -> bool:
	var n: int = c.pts.size()
	var before := -1
	var after := -1
	var before_i := -1
	var after_i := -1
	for d in range(1, 5):
		var bi: int = posmod(i - d, n)
		var ai: int = posmod(i + d, n)
		if before < 0 and _ring_wall(region, c.pts[bi], c.levels[bi]):
			before = d
			before_i = bi
		if after < 0 and _ring_wall(region, c.pts[ai], c.levels[ai]):
			after = d
			after_i = ai
	return before > 0 and after > 0 and before + after <= 4 \
		and c.normals[before_i].dot(c.normals[after_i]) < 0.8


## Max turn angle (degrees, XZ plane) between consecutive segment direction
## vectors along one curve's own point array, restricted to NON-WALL points
## (curve.wall[i] == 0) per the brief's own "for non-wall points" framing —
## WaterContour.curves() supplies its own wall flag directly (Task 2's report
## closing notes: "the plan's point 6 suggests using the polyline frame's own
## normal directly instead, which would be strictly more precise than my ring
## scan" — this is that upgrade: no more 8-ring scan, no more _is_wall, the
## curve's own outward-normal wall probe IS the ground truth now).
## Returns {"max_turn": float, "max_turn_nonwall": float, "offenders": Array,
## "wall_ct": int, "nonwall_ct": int} — offenders lists every corner
## (wall-inclusive) turning >= 25deg, for diagnostic printing.
static func _curve_turn_stats(c: Dictionary) -> Dictionary:
	var pts: PackedVector2Array = c.pts
	var n: int = pts.size()
	var closed: bool = c.closed
	var max_turn := 0.0
	var max_turn_nonwall := 0.0
	var wall_ct := 0
	var nonwall_ct := 0
	var offenders: Array = []
	var lo: int = 0 if closed else 1
	var hi: int = n if closed else n - 1
	for i in range(lo, hi):
		var p0: Vector2 = pts[(i - 1 + n) % n]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % n]
		var d1 := p1 - p0
		var d2 := p2 - p1
		if d1.length() < 0.001 or d2.length() < 0.001:
			continue   # degenerate (near-zero-length) segment, no turn to measure
		var ang: float = absf(rad_to_deg(d1.normalized().angle_to(d2.normalized())))
		var wall: bool = c.wall[i] == 1
		if wall:
			wall_ct += 1
		else:
			nonwall_ct += 1
			max_turn_nonwall = maxf(max_turn_nonwall, ang)
		max_turn = maxf(max_turn, ang)
		if ang >= 25.0:
			offenders.append("i=%d p=%s turn=%.1fdeg wall=%s" % [i, p1, ang, wall])
	return {"max_turn": max_turn, "max_turn_nonwall": max_turn_nonwall,
		"offenders": offenders, "wall_ct": wall_ct, "nonwall_ct": nonwall_ct}


## Consecutive-segment spacing (metres) along one curve — min/max over every
## edge (closed curves wrap; open curves do not check the tail edge back to
## point 0).
static func _curve_spacing_range(c: Dictionary) -> Vector2:
	var pts: PackedVector2Array = c.pts
	var n: int = pts.size()
	var lim: int = n if c.closed else n - 1
	var lo := INF
	var hi := 0.0
	for i in lim:
		var d: float = pts[i].distance_to(pts[(i + 1) % n])
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return Vector2(lo, hi)


## test_pond_yields_smooth_closed_curve — the GREEN half of the r3-task-2 red
## evidence: WaterContour.curves() on a pinned, VERIFIED-isolated pond chunk
## must produce at least one CLOSED curve whose non-wall points turn less
## than 25 degrees and whose spacing sits in [1.0, 2.0]m. Hardening pass
## adds a wall-flag sanity block (fraction printed; zero over-tagging vs an
## independent 8-ring ground-truth witness; non-wall points must exist) —
## see the inline comment there for why the review's literal "fraction <
## 0.25" premise is false for this pond.
##
## Site choice: SITE_CHUNK (0,-6) itself does NOT work for this test — probed
## directly (this task): every water body reaching SITE_CHUNK's own mesh
## (the 2 rivers + their source/terminal ponds Task 2's report already
## found) is ONE hydrostatically-connected flood spanning 6000+ presence-grid
## samples over a multi-hundred-metre bbox (WaterField's fill has "no
## radius/depth gates... water stands exactly where ground is below source
## level" per the architecture — rivers and their ponds genuinely fuse into
## one body here), so no chunk-local closed loop exists there at all. Chunk
## (-4,-18) on this SAME seed was found by scanning for a small
## (SOURCE_POOL_R=26) pond whose OWN flood-fill stays small (192 presence-
## grid samples, tight ~45x45m bbox, independently verified isolated from
## any river network) AND sits comfortably centred inside its own chunk
## (nearest edge 65.8m away, well past bound_radius 33.8 + MARGIN 12 +
## smoothing-drift slack) — the practical equivalent of scanning both pinned
## seeds for a qualifying chunk, same discipline
## test_no_triangle_bridges_a_fall_except_legitimate_steep_terrain
## (test_water_mesher.gd) already used to find its own steep-chunk site.
func test_pond_yields_smooth_closed_curve() -> void:
	var pond_chunk := Vector2i(-4, -18)
	var ctx: Dictionary = _ctx(SEED, pond_chunk)
	var curves: Array = WaterContour.curves(ctx, _rect(pond_chunk))
	assert_false(curves.is_empty(), "isolated-pond chunk builds real water")

	var closed_curves: Array = []
	for c: Dictionary in curves:
		if c.closed:
			closed_curves.append(c)
	print("MEAS test_pond_yields_smooth_closed_curve: %d curves total, %d closed" % [
		curves.size(), closed_curves.size()])
	assert_true(closed_curves.size() >= 1, "at least one closed curve at the isolated pond chunk")
	if closed_curves.is_empty():
		return

	var max_turn := 0.0
	var max_turn_nonwall := 0.0
	var all_offenders: Array = []
	var spacing_ok := true
	for c: Dictionary in closed_curves:
		var stats: Dictionary = _curve_turn_stats(c)
		max_turn = maxf(max_turn, stats.max_turn)
		max_turn_nonwall = maxf(max_turn_nonwall, stats.max_turn_nonwall)
		all_offenders.append_array(stats.offenders)
		var sp: Vector2 = _curve_spacing_range(c)
		print("MEAS test_pond_yields_smooth_closed_curve: closed curve n=%d spacing=[%.3f,%.3f] max_turn=%.1f max_turn_nonwall=%.1f wall=%d nonwall=%d" % [
			c.pts.size(), sp.x, sp.y, stats.max_turn, stats.max_turn_nonwall, stats.wall_ct, stats.nonwall_ct])
		if sp.x < 1.0 or sp.y > 2.0:
			spacing_ok = false

	print("MEAS test_pond_yields_smooth_closed_curve: max_turn_deg (raw) = %.2f, (non-wall) = %.2f" % [
		max_turn, max_turn_nonwall])
	assert_true(spacing_ok, "every closed-curve segment spacing sits in [1.0, 2.0]m")
	assert_true(max_turn_nonwall < 25.0,
		"non-wall points turn < 25deg (max %.1fdeg): %s" % [max_turn_nonwall, all_offenders])

	# --- Wall-flag sanity (hardening pass): over-tagging must fail loudly ---
	#
	# The review asked for "wall fraction < 0.25, shores are known-gentle" —
	# that premise is FALSE for this pond and the fraction assert would fail
	# on reality, not on a defect: probed directly (r3-task-3-report.md,
	# Hardening section), this pond sits in a sheer rock bowl — ground steps
	# from 8.0 (3m BELOW its 11.0 surface) to 20.0 (9m ABOVE it) within
	# 0.5m across almost the whole shoreline, i.e. a 12m canyon wall at the
	# waterline. That is the terrain's own design, not an artifact:
	# TerrainSurfaceField._is_cliff_top walls ANY dry cell overlooking a
	# water-carved cell ("shorelines read as crisp dressed banks"), so on
	# this terrain nearly every carved shore is a genuine wall. Measured
	# fraction here: 122/124 = 0.984, with EVERY formula-wall point
	# independently confirmed steep by the generous 8-ring witness
	# (over_tag = 0).
	#
	# What actually catches systematic over-tagging (the review's real
	# concern — points exempted from the turn oracle that shouldn't be):
	# A formula-wall point whose independent 8-ring witness is gentle is valid
	# only as the intentionally closed 1-3-sample gap at a rounded wall turn.
	# Independently verify the two bracketing walls and the normal turn here;
	# any broader/systematic over-tagging still fails loudly with coordinates.
	var wall_ct := 0
	var pt_total := 0
	var corner_bridges := 0
	var invalid_tags: Array = []
	var region = _region(SEED, pond_chunk)
	for c: Dictionary in closed_curves:
		var pts: PackedVector2Array = c.pts
		for i in pts.size():
			pt_total += 1
			if c.wall[i] == 1:
				wall_ct += 1
				if not _ring_wall(region, pts[i], c.levels[i]):
					if _valid_short_corner_bridge(region, c, i):
						corner_bridges += 1
					else:
						invalid_tags.append("i=%d p=%s lvl=%.2f" % [i, pts[i], c.levels[i]])
	var frac: float = float(wall_ct) / maxf(1.0, float(pt_total))
	print("MEAS test_pond_yields_smooth_closed_curve: wall fraction = %d/%d = %.3f, validated corner bridges=%d invalid=%d" % [
		wall_ct, pt_total, frac, corner_bridges, invalid_tags.size()])
	assert_true(invalid_tags.is_empty(),
		"every ring-gentle wall flag is a short bridge across a proven wall turn: %s" % str(invalid_tags))
	assert_true(corner_bridges > 0,
		"pinned pond exercises the short rounded-wall-corner bridge path")


## Border-curve points of one chunk's curves() output lying on the border
## line `p[axis] == coord` (0.01 gather tolerance), each with its "arc
## inside" — the arc length from the border point to the FARTHER end of its
## own piece, i.e. how much curve genuinely lives on this chunk's side. Used
## by test_border_curves_weld's mid-arc gate: a crossing with a large arc on
## BOTH sides sits mid-arc of the underlying waterline, far from either
## side's natural polyline endpoints (where each chunk anchors its own
## resample phase) — exactly the crossings where an endpoint/phase-alignment
## coincidence CANNOT explain a weld match.
static func _border_pts(curves: Array, axis: int, coord: float) -> Array:
	var out: Array = []
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		var n: int = pts.size()
		for i in n:
			var p: Vector2 = pts[i]
			if absf(p[axis] - coord) >= 0.01:
				continue
			var arc_fwd := 0.0
			for k in range(i, n - 1):
				arc_fwd += pts[k].distance_to(pts[k + 1])
			var arc_bwd := 0.0
			for k in range(1, i + 1):
				arc_bwd += pts[k - 1].distance_to(pts[k])
			out.append({"p": p, "arc_inside": maxf(arc_fwd, arc_bwd)})
	return out


## test_border_curves_weld — the plan's chunk-seam-determinism constraint
## made concrete: two neighbouring chunks' own curves() calls must agree on
## every point that lands on their shared border, at an EXPLICIT 1e-4
## distance ceiling (the brief's own "bit-equality target; tolerance 1e-4
## max"). NOTE: the first version of this test used Vector2.is_equal_approx,
## which is a RELATIVE comparison — at world coordinates ~1000-4000 its
## effective tolerance is ~0.01-0.04m, far looser than 1e-4; the hardened
## assert below measures the actual distance and holds it to 1e-4.
##
## HARDENED (post-review): the original two-pair/one-crossing-each oracle
## was flagged as thin ("plausible, not proven" for crossings far from a
## polyline's natural resample-phase alignment — each chunk clips its OWN
## independently-phased resample of a differently-truncated polyline). This
## version scans every adjacent pair inside two VERIFIED wet clusters (all
## cardinal borders where water actually crosses), covering both pinned
## seeds, accumulating border crossings past the assert floor (total >= 6),
## most of them MID-ARC (>= 10m — measured range 45-330m — of curve inside
## BOTH chunks; also gated at >= 6 — see mid_arc_ct below, not a frozen
## count): crossings that deep into both sides' curves cannot be explained
## by endpoint/phase coincidence. Probe evidence (r3-task-3-report.md,
## Hardening section, 13 crossings/12 mid-arc at the time): all measured
## distances were 0.000000000 at 9 printed decimals — genuinely bit-equal,
## not merely inside 1e-4.
##
## Residual limitation, stated honestly: every real crossing on both pinned
## seeds sits on a locally STRAIGHT waterline reach (max nearby turn 0.0deg
## at all 13 — storey-quantized terrain crosses chunk borders along straight
## contour runs; rounded corner arcs are a few metres long and none coincide
## with a border line on these seeds). A crossing ON a curved arc — where
## the two sides' 1.5m chords could in principle disagree up to
## O(spacing^2 * curvature) — is therefore not exercised by any real site
## this suite can pin; if a future seed produces one, this oracle (explicit
## 1e-4 distance, no is_equal_approx slack) is what will catch it.
##
## The brief's literal chunk pair ((0,-47),(0,-46)) carries ZERO water on
## 2697992464 (verified: bodies_near on both chunks returns 0 ponds/0
## rivers) so it cannot exercise a weld at all; the clusters below are real,
## probed substitutes covering both pinned seeds as the brief intended.
func test_border_curves_weld() -> void:
	var weld_tol := 0.0001   # 1e-4 — the brief's explicit ceiling
	var mid_arc_min := 10.0  # metres of curve inside BOTH chunks => mid-arc crossing
	var clusters := [
		# The pinned site's river/lake system (flood bbox spans chunk columns
		# -1..2, rows -7..-6 — verified by flood-fill, see the report).
		{"seed": SEED, "chunks": [
			Vector2i(-1, -7), Vector2i(0, -7), Vector2i(1, -7), Vector2i(2, -7),
			Vector2i(-1, -6), Vector2i(0, -6), Vector2i(1, -6), Vector2i(2, -6)]},
		# 991177's known water cluster (test_water_field.gd's own border-
		# agreement cluster); of its adjacent pairs only (-8,6)|(-8,7) has a
		# wet border crossing (probed: the other pair borders are dry), so
		# only those two chunks are built here.
		{"seed": 991177, "chunks": [Vector2i(-8, 6), Vector2i(-8, 7)]},
	]
	var total := 0
	var mid_arc_ct := 0
	var worst := 0.0
	for cluster: Dictionary in clusters:
		var seed_v: int = cluster.seed
		var chunks: Array = cluster.chunks
		var curve_cache: Dictionary = {}
		for chunk: Vector2i in chunks:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb: Vector2i = chunk + d
				if not (nb in chunks):
					continue
				var axis: int = 0 if d.x == 1 else 1
				var coord: float = float(nb.x if axis == 0 else nb.y) * (WaterField.TILE * 8.0)
				if not curve_cache.has(chunk):
					curve_cache[chunk] = WaterContour.curves(_ctx(seed_v, chunk), _rect(chunk))
				if not curve_cache.has(nb):
					curve_cache[nb] = WaterContour.curves(_ctx(seed_v, nb), _rect(nb))
				var a_pts: Array = _border_pts(curve_cache[chunk], axis, coord)
				var b_pts: Array = _border_pts(curve_cache[nb], axis, coord)
				if a_pts.is_empty() and b_pts.is_empty():
					continue
				assert_eq(a_pts.size(), b_pts.size(),
					"%s|%s (seed %d): both sides report the same number of border points" % [chunk, nb, seed_v])
				for ap: Dictionary in a_pts:
					var best_d := INF
					var best_bp = null
					for bp: Dictionary in b_pts:
						var dd: float = ap.p.distance_to(bp.p)
						if dd < best_d:
							best_d = dd
							best_bp = bp
					total += 1
					worst = maxf(worst, best_d if best_d < INF else 999.0)
					var is_mid: bool = best_bp != null \
						and ap.arc_inside >= mid_arc_min and best_bp.arc_inside >= mid_arc_min
					if is_mid:
						mid_arc_ct += 1
					if best_bp != null:
						print("MEAS test_border_curves_weld: seed=%d %s|%s coord=%.1f a=(%.9f, %.9f) b=(%.9f, %.9f) dist=%.9f a_arc=%.1f b_arc=%.1f mid_arc=%s" % [
							seed_v, chunk, nb, coord, ap.p.x, ap.p.y, best_bp.p.x, best_bp.p.y,
							best_d, ap.arc_inside, best_bp.arc_inside, is_mid])
					else:
						print("MEAS test_border_curves_weld: seed=%d %s|%s coord=%.1f a=(%.9f, %.9f) UNMATCHED (no b-side point)" % [
							seed_v, chunk, nb, coord, ap.p.x, ap.p.y])
					assert_true(best_bp != null and best_d <= weld_tol,
						"%s|%s (seed %d): border point %s matches the neighbour within 1e-4 (dist %.9f)" % [
							chunk, nb, seed_v, ap.p, best_d])
	print("MEAS test_border_curves_weld: %d total crossings (%d mid-arc), worst distance %.9f" % [
		total, mid_arc_ct, worst])
	assert_true(total >= 6, "at least 6 border crossings accumulated across both seeds (got %d)" % total)
	assert_true(mid_arc_ct >= 6, "at least 6 crossings are mid-arc (>= %.0fm of curve inside BOTH chunks; got %d)" % [
		mid_arc_min, mid_arc_ct])


## test_wall_stays_straight — the I4 wall reach (a genuine sheer vertical
## cliff at x=36). The old oracle used a broad 24x32m box and flattened every
## wall point from every contour into one array. That box also contains the
## separate perpendicular wall at z=-1092, so it incorrectly demanded that
## an intentional L-shaped cliff be globally collinear. Pin the actual
## vertical reach instead: its wall samples may round by <0.75m at the corner
## after contour smoothing, but they may not fan or wobble away from x=36.
func test_wall_stays_straight() -> void:
	var ctx: Dictionary = _ctx(SEED, SITE_CHUNK)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var reach := Rect2(Vector2(35.0, -1108.0), Vector2(2.0, 32.0))
	var wall_pts: Array = []
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		for i in pts.size():
			if c.wall[i] == 1 and reach.has_point(pts[i]):
				wall_pts.append(pts[i])
	print("MEAS test_wall_stays_straight: %d wall-flagged points in the I4 reach" % wall_pts.size())
	assert_true(wall_pts.size() >= 4, "at least 4 wall-flagged points found along the vertical I4 reach")
	if wall_pts.size() < 4:
		return
	var max_dev := 0.0
	var offenders: Array = []
	for p: Vector2 in wall_pts:
		var dev: float = absf(p.x - 36.0)
		max_dev = maxf(max_dev, dev)
		if dev > 0.75:
			offenders.append("%s dev=%.3f" % [p, dev])
	print("MEAS test_wall_stays_straight: max x deviation = %.4f m (threshold 0.75)" % max_dev)
	assert_true(max_dev <= 0.75,
		"vertical I4 wall points stay aligned to x=36 within the rounded-corner allowance: %s" % str(offenders))


## test_curve_levels_match_field — every curve point's baked `levels[i]` must
## equal WaterField.level_at(ctx, pt) (the field truth it was sampled from)
## within 0.05, across SITE_CHUNK (3 boundary curves, 2 rivers + ponds) AND
## the isolated pond chunk (1 closed curve) — two structurally different
## sites (open river/lake network vs. one small closed loop) so the check
## isn't only exercised against one curve shape.
func test_curve_levels_match_field() -> void:
	var sites := [
		{"seed": SEED, "chunk": SITE_CHUNK},
		{"seed": SEED, "chunk": Vector2i(-4, -18)},
	]
	var total_checked := 0
	var max_err := 0.0
	var offenders: Array = []
	for site: Dictionary in sites:
		var seed_v: int = site.seed
		var chunk: Vector2i = site.chunk
		var ctx: Dictionary = _ctx(seed_v, chunk)
		var curves: Array = WaterContour.curves(ctx, _rect(chunk))
		assert_false(curves.is_empty(), "%s (seed %d): builds real water to check" % [chunk, seed_v])
		for c: Dictionary in curves:
			var pts: PackedVector2Array = c.pts
			for i in pts.size():
				var truth: float = WaterField.level_at(ctx, pts[i])
				var err: float = absf(c.levels[i] - truth)
				total_checked += 1
				max_err = maxf(max_err, err)
				if err >= 0.05 and offenders.size() < 10:
					offenders.append("%s baked=%.3f truth=%.3f err=%.3f" % [pts[i], c.levels[i], truth, err])
	print("MEAS test_curve_levels_match_field: checked %d points, max_err=%.5f (threshold 0.05)" % [
		total_checked, max_err])
	assert_true(total_checked > 0, "at least one curve point checked")
	# str() first — see test_wall_stays_straight's own comment on why "%s" %
	# <Array> (GDScript's splat semantics) breaks whenever the array isn't
	# exactly 1 element, including the empty (success-path) case.
	assert_true(max_err < 0.05, "every curve point's baked level matches field truth within 0.05: %s" % str(offenders))


## Saddle topology guard. The original reported corner was a centre-wet
## diagonal saddle and exposed the missing "isolate dry corners" branch.
## Continuous segment carving now makes a third corner wet there, so pin the
## asymptotic-decider invariant directly instead of freezing that incidental
## bathymetry: wet centres preserve the wet diagonal; dry centres split it.
func test_saddle_cells_connect_the_wedge() -> void:
	# The exact old corner is intentionally no longer a saddle after the
	# continuous segment carve: a third corner is now wet. Test the ambiguous
	# topology as a pure invariant instead of freezing incidental bathymetry.
	# Centre wet means the dry diagonal is isolated and the wet diagonal stays
	# joined; centre dry means the inverse split.
	var wet_02: Array = [true, false, true, false]
	var wet_13: Array = [false, true, false, true]
	assert_eq(WaterContour._saddle_isolated_corners(wet_02, true), PackedInt32Array([1, 3]),
		"wet centre isolates the dry corners and preserves wet diagonal 0-2")
	assert_eq(WaterContour._saddle_isolated_corners(wet_13, true), PackedInt32Array([0, 2]),
		"wet centre isolates the dry corners and preserves wet diagonal 1-3")
	assert_eq(WaterContour._saddle_isolated_corners(wet_02, false), PackedInt32Array([0, 2]),
		"dry centre isolates the wet corners into separate islands")
	assert_eq(WaterContour._saddle_isolated_corners(wet_13, false), PackedInt32Array([1, 3]),
		"dry centre handles the opposite diagonal symmetrically")


## Exact 2026-07-21 saddle at cell (-11,-31).  The contour is G1 after its
## two smoothing passes, so its dry-side frame cannot reverse by 180 degrees
## between adjacent 1.5m samples.  The old pointwise wetness gradient does
## exactly that at the saddle's zero-gradient centre, turning the wall shelf
## into a self-crossing bow tie and leaving the connected wet wedge unmeshed.
func test_reported_saddle_outward_frame_does_not_reverse() -> void:
	var chunk := Vector2i(-2, -4)
	var curves: Array = WaterContour.curves(_ctx(SEED, chunk), _rect(chunk))
	var pin := Vector2(-250.6, -754.0)
	var checked := 0
	var worst_dot := 1.0
	var offenders: Array[String] = []
	for c: Dictionary in curves:
		for i in range(1, c.pts.size()):
			if Vector2(c.pts[i]).distance_to(pin) > 5.0 \
					and Vector2(c.pts[i - 1]).distance_to(pin) > 5.0:
				continue
			checked += 1
			var d: float = Vector2(c.normals[i - 1]).dot(Vector2(c.normals[i]))
			worst_dot = minf(worst_dot, d)
			if d < 0.0:
				offenders.append("%s n=%s -> %s n=%s dot=%.3f" % [
					c.pts[i - 1], c.normals[i - 1], c.pts[i], c.normals[i], d])
	print("MEAS 2026-07-21 saddle frame checked=%d worst_dot=%.3f offenders=%s" % [
		checked, worst_dot, str(offenders)])
	assert_true(checked >= 3, "reported saddle exercises several adjacent contour frames")
	assert_true(offenders.is_empty(),
		"a smooth contour's outward frame never reverses across the reported saddle: %s" % str(offenders))


## The curve-consistent frame must also choose the correct one of its two
## possible sides. This isolated-pond pin was the existing free-drop fixture;
## an inward frame sees six metres of pond water and makes the renderer build
## a bogus long shelf instead of the compact outer meniscus.
func test_outward_frame_points_to_the_drier_side() -> void:
	var chunk := Vector2i(-4, -18)
	var ctx: Dictionary = _ctx(SEED, chunk)
	var curves: Array = WaterContour.curves(ctx, _rect(chunk))
	var hint := Vector2(-633.9844, -3394.641)
	var nearest := {"distance": INF}
	for ci in curves.size():
		var c: Dictionary = curves[ci]
		for i in c.pts.size():
			var d: float = Vector2(c.pts[i]).distance_to(hint)
			if d < nearest.distance:
				nearest = {"distance": d, "curve": ci, "index": i,
					"point": c.pts[i], "normal": c.normals[i]}
	assert_true(nearest.distance < 0.2,
		"stable isolated-pond contour pin still exists (distance %.3f)" % nearest.distance)
	if nearest.distance >= 0.2:
		return
	var p: Vector2 = nearest.point
	var nrm: Vector2 = nearest.normal
	var probe := WaterField.FILL_STEP
	var outward: Vector2 = p + nrm * probe
	var inward: Vector2 = p - nrm * probe
	var out_level: float = WaterField.level_at(ctx, outward)
	var in_level: float = WaterField.level_at(ctx, inward)
	var out_depth: float = out_level - TerrainSurfaceField.surface_y(
		ctx.region, outward.x, outward.y) \
		if out_level != -INF else -INF
	var in_depth: float = in_level - TerrainSurfaceField.surface_y(
		ctx.region, inward.x, inward.y) \
		if in_level != -INF else -INF
	print("MEAS pond outward-frame p=%s n=%s out_depth=%.3f in_depth=%.3f curve=%d index=%d" % [
		p, nrm, out_depth, in_depth, nearest.curve, nearest.index])
	assert_true(out_depth < in_depth - 0.05,
		"outward frame points toward the drier side (out %.3f, in %.3f)" % [
			out_depth, in_depth])

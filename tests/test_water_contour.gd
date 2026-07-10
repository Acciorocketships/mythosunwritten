extends GutTest

# r3-task-2 (plan docs/superpowers/plans/2026-07-10-water-continuous-surface.md,
# brief .superpowers/sdd/r3-task-2-brief.md) recorded the RED evidence that the
# pre-WaterContour boundary (WaterMesher's own perimeter-walk marching squares
# on a 3m sub-grid) produces angular, grid-quantized corners: max_turn_deg
# (raw, all corners) = 90.00 at SITE_CHUNK, isolated skip-guard active,
# transcript preserved in .superpowers/sdd/r3-task-2-report.md ("Red run
# transcript" section — 9 offending corners, 45-90 degree turns, all on the
# OLD WaterMesher.build() boundary). r3-task-3 (.superpowers/sdd/
# r3-task-3-brief.md) is what makes this GREEN: WaterContour.curves() now
# EXISTS and replaces the boundary source entirely — this file's
# test_pond_yields_smooth_closed_curve below is the direct GREEN half of that
# red-green pair, measuring the NEW curve's own turn angle instead of walking
# WaterMesher's free edges (the old _sheet_free_edges/_chain_edges/_is_wall
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
## than 25 degrees and whose spacing sits in [1.0, 2.0]m.
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


## test_border_curves_weld — the plan's Free-edge/chunk-seam-determinism
## constraint made concrete: two neighbouring chunks' own curves() calls must
## agree bit-exactly (tolerance 1e-4) on every point that lands on their
## shared border. Both pairs are VERIFIED wet-crossing borders (probed this
## task): (0,-6)|(1,-6) on the pinned SEED (the SITE_CHUNK's own east curve
## genuinely reaches x=192), and (-8,6)|(-8,7) on 991177 (a real north-south
## river crossing at z=1344 inside the seed's own known water cluster,
## tests/test_water_field.gd's test_wet_agreement_across_all_chunk_borders
## cluster list) — chosen because the brief's literal chunk pair
## ((0,-47),(0,-46)) carries ZERO water on 2697992464 (verified: bodies_near
## on both chunks returns 0 ponds/0 rivers) so it cannot exercise a weld at
## all; these two pairs are real, checked substitutes covering both pinned
## seeds as the brief intended.
func test_border_curves_weld() -> void:
	var pairs := [
		{"seed": SEED, "a": Vector2i(0, -6), "b": Vector2i(1, -6), "axis": 0},
		{"seed": 991177, "a": Vector2i(-8, 6), "b": Vector2i(-8, 7), "axis": 1},
	]
	for pair: Dictionary in pairs:
		var seed_v: int = pair.seed
		var a_chunk: Vector2i = pair.a
		var b_chunk: Vector2i = pair.b
		var axis: int = pair.axis
		var a_ctx: Dictionary = _ctx(seed_v, a_chunk)
		var b_ctx: Dictionary = _ctx(seed_v, b_chunk)
		var a_rect: Rect2 = _rect(a_chunk)
		var b_rect: Rect2 = _rect(b_chunk)
		var border_coord: float = b_rect.position.x if axis == 0 else b_rect.position.y

		var a_curves: Array = WaterContour.curves(a_ctx, a_rect)
		var b_curves: Array = WaterContour.curves(b_ctx, b_rect)

		var a_pts: Array = []
		for c: Dictionary in a_curves:
			for p: Vector2 in c.pts:
				if absf(p[axis] - border_coord) < 0.01:
					a_pts.append(p)
		var b_pts: Array = []
		for c: Dictionary in b_curves:
			for p: Vector2 in c.pts:
				if absf(p[axis] - border_coord) < 0.01:
					b_pts.append(p)

		print("MEAS test_border_curves_weld: seed=%d pair=%s|%s border_coord=%.1f a_border_pts=%d b_border_pts=%d" % [
			seed_v, a_chunk, b_chunk, border_coord, a_pts.size(), b_pts.size()])
		assert_true(a_pts.size() > 0, "%s|%s: chunk a has at least one border-curve point" % [a_chunk, b_chunk])
		assert_eq(a_pts.size(), b_pts.size(),
			"%s|%s: both sides report the same number of border-crossing points" % [a_chunk, b_chunk])

		var unmatched: Array = []
		for ap: Vector2 in a_pts:
			var found := false
			for bp: Vector2 in b_pts:
				if ap.is_equal_approx(bp):
					found = true
					break
			if not found:
				unmatched.append(ap)
		assert_true(unmatched.is_empty(),
			"%s|%s: every a-side border point has a matching (is_equal_approx) b-side point — unmatched: %s" % [
				a_chunk, b_chunk, unmatched])


## test_wall_stays_straight — the I4 wall reach (VERIFIED this task: a
## genuine sheer vertical cliff running the full length x=36.0,
## z~-1104..-1080, ground jumping from 8.0 to 4.0 with zero horizontal run —
## wet on the east/high-x side). Every wall-flagged curve point inside this
## reach must be collinear (the curve should track the straight cliff face,
## not wobble) within 0.15m perpendicular deviation from the line through
## the reach's own first/last wall point.
func test_wall_stays_straight() -> void:
	var ctx: Dictionary = _ctx(SEED, SITE_CHUNK)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	# x in [30,54] safely brackets the reach's own x=36 line with slack on
	# both sides; z in [-1108,-1076] safely brackets the verified
	# z~-1104..-1080 span with a few metres of margin.
	var reach := Rect2(Vector2(30.0, -1108.0), Vector2(24.0, 32.0))
	var wall_pts: Array = []
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		for i in pts.size():
			if c.wall[i] == 1 and reach.has_point(pts[i]):
				wall_pts.append(pts[i])
	print("MEAS test_wall_stays_straight: %d wall-flagged points in the I4 reach" % wall_pts.size())
	assert_true(wall_pts.size() >= 2, "at least 2 wall-flagged points found in the I4 reach to check collinearity")
	if wall_pts.size() < 2:
		return

	var a: Vector2 = wall_pts[0]
	var b: Vector2 = wall_pts[-1]
	var dir: Vector2 = (b - a)
	if dir.length() < 0.001:
		dir = Vector2(0, 1)   # degenerate (identical first/last) — fall back to a fixed axis, deviation is 0 regardless
	else:
		dir = dir.normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var max_dev := 0.0
	var offenders: Array = []
	for p: Vector2 in wall_pts:
		var dev: float = absf((p - a).dot(nrm))
		max_dev = maxf(max_dev, dev)
		if dev > 0.15:
			offenders.append("%s dev=%.3f" % [p, dev])
	print("MEAS test_wall_stays_straight: max perpendicular deviation = %.4f m (threshold 0.15)" % max_dev)
	# str(offenders) computed first and passed as a single scalar: GDScript's
	# % operator treats an ARRAY right-hand side as an arg-list to splat into
	# the format string's own placeholders, so "%s" % offenders (an Array,
	# even a populated one) does not mean "print this array" — it means
	# "splat its elements," which throws "not enough arguments" whenever
	# offenders.size() != 1 (empty on the success path, but also >1 whenever
	# more than one offender is found). str() first avoids the splat
	# entirely by handing % a String, not an Array.
	assert_true(max_dev <= 0.15,
		"wall-flagged points in the I4 reach stay collinear within 0.15m: %s" % str(offenders))


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

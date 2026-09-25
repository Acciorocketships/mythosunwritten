# Waterline -> smooth, chunk-welded curves. Pure function of (ctx, rect); no
# nodes, no mesh. Consumed by WaterSkin (plan Task 4+): the boundary a mesher
# stitches into a conforming strip must be a small set of clean G1 polylines,
# not the raw ~45-90 degree marching-squares corners the old mesher's own
# perimeter walk produced (see tests/test_water_contour.gd's red evidence,
# .superpowers/sdd/r3-task-2-report.md). Six-step pipeline (brief's own
# numbering, .superpowers/sdd/r3-task-3-brief.md):
#   1. presence grid (STEP=3.0) over rect.grow(MARGIN)
#   2. per-edge crossing refinement (3 bisection steps against the REAL
#      fields, not the coarse grid — same discipline the old mesher's own
#      edge-vertex bisection used)
#   3. chain crossings into polylines (marching-squares-style per-cell
#      segment extraction, then position-keyed chaining)
#   4. two Chaikin passes + uniform 1.5m resample
#   5. clip to rect LAST (after smoothing) — this ordering is what makes the
#      border weld: two neighbouring chunks both smooth the SAME extended
#      polyline (built from rect.grow(MARGIN), which reaches past either
#      chunk's own border into world-grid-aligned territory the neighbour
#      also samples identically), so clipping each to its own rect afterward
#      yields bit-identical border-crossing points — clip-before-smooth would
#      let each side's Chaikin see a different (independently truncated)
#      polyline and drift apart at the cut.
#   6. per-point level/normal/wall attributes, wall via the curve's OWN frame
#      normal (not a ring scan — Task 2's report closing notes flag this: a
#      real outward normal is strictly more precise than probing 8 fixed
#      ring directions blind).
class_name WaterContour
extends Object

const STEP := 3.0
const MARGIN := 12.0
const SPACING := 1.5
const WALL_SLOPE := 1.2
const _WET_EPS := 0.02
const _CLOSE_EPS := 0.5       # chain-end proximity that promotes a polyline to closed
const _WELD_EPS := 0.01       # position-key rounding for chaining segment endpoints (world metres)


## Ground height at p (thin wrapper kept local so every field read in this
## file goes through one name — mirrors this codebase's own per-file
## `_ground`-style helper convention rather than repeating the ctx.region
## destructure at every call site).
static func _ground(ctx: Dictionary, p: Vector2) -> float:
	return TerrainSurfaceField.surface_y(ctx.region, p.x, p.y)


static func _wet_f(ctx: Dictionary, p: Vector2) -> float:
	var lvl: float = WaterField.level_at(ctx, p)
	if lvl == -INF:
		return -1.0
	return lvl - _ground(ctx, p)


static func _is_wet(ctx: Dictionary, p: Vector2) -> bool:
	return _wet_f(ctx, p) > _WET_EPS


## Marching-squares saddle decider: return the two corners that the centre
## sample says are isolated. A wet centre isolates DRY corners (the wet
## diagonal stays joined); a dry centre isolates WET corners. Kept as a pure
## helper so both ambiguous topologies remain testable even when a particular
## procedural seed no longer happens to contain a saddle after bathymetry
## changes.
static func _saddle_isolated_corners(wf: Array, centre_wet: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in 4:
		if wf[k] != centre_wet:
			out.append(k)
	return out


## curves(ctx, rect) -> Array[Dictionary], each:
##   pts: PackedVector2Array      # world xz, ~1.5 m spacing, G1-smooth
##   levels: PackedFloat32Array   # water level at each pt (field truth)
##   normals: PackedVector2Array  # outward (dry-side) unit normals
##   wall: PackedByteArray        # 1 where local ground slope across the line > WALL_SLOPE
##   closed: bool
## ctx MUST carry a region (WaterField.ctx(water, chunk, region)) — ground()
## reads ctx.region directly, same requirement every production ctx caller has.
static func curves(ctx: Dictionary, rect: Rect2) -> Array:
	var grown: Rect2 = rect.grow(MARGIN)
	var segments: Array = _presence_segments(ctx, grown)
	var polylines: Array = _chain_segments(segments)
	var out: Array = []
	for poly: Dictionary in polylines:
		var pts: PackedVector2Array = poly.pts
		var closed: bool = poly.closed
		if pts.size() < 2:
			continue
		pts = _chaikin(pts, closed)
		pts = _chaikin(pts, closed)
		pts = _resample(pts, closed, SPACING)
		if pts.size() < 2:
			continue
		var clipped: Dictionary = _clip_to_rect(pts, closed, rect)
		for piece: PackedVector2Array in clipped.pieces:
			if piece.size() < 2:
				continue
			out.append(_attributes(ctx, piece, clipped.closed))
	return out


## --- Step 1+2: presence grid + per-cell marching-squares segment walk ---
##
## One "segment" is a single waterline stroke through one grid cell (its two
## endpoints are refined edge-crossings, see _refine_crossing), exactly
## mirroring the old mesher's own per-cell corner/edge classification but
## emitting a boundary STROKE instead of a triangulated wet polygon.
##
## SADDLE cells (marching-squares case 5/10: two diagonally-opposite corners
## wet, the other two dry — wet_n==2 and wf[0]==wf[2]) are the one place this
## grid is genuinely ambiguous: the four edge crossings could pair up either
## way. Resolved by the standard asymptotic-decider / centre-sample
## disambiguation (r3-task-15, .superpowers/sdd/r3-task-15-brief.md): sample
## the field at the cell CENTRE (world-grid-aligned, so neighbouring chunks
## agree on it too — same determinism argument as the corner grid itself,
## see the origin-snap comment below). Centre DRY: the two wet corners are
## NOT connected — isolate each as its own short stroke (a separate wet
## island poking into the cell). Centre WET: the two wet corners ARE
## connected — the water wedge joins across the diagonal through the centre
## — so instead the two DRY corners are isolated, one short stroke each,
## leaving the rest of the cell (both wet corners plus the centre) as one
## continuous region. A prior version of this function only special-cased
## the centre-dry split and let centre-wet fall through to the generic
## "exactly two edges change sign" path below — which is never true for a
## genuine saddle (all four edges change sign, by construction) — so that
## cell silently contributed NO segments at all: the owner's missing
## diagonal corner (r3-task-15-report.md).
static func _presence_segments(ctx: Dictionary, grown: Rect2) -> Array:
	var nx: int = int(ceil(grown.size.x / STEP))
	var nz: int = int(ceil(grown.size.y / STEP))
	var origin: Vector2 = grown.position
	# World-grid-aligned sampling (floor(x/STEP)*STEP) is what makes two
	## neighbouring chunks compute IDENTICAL wet flags over their shared
	## MARGIN overlap — origin itself must snap to the world STEP lattice,
	## not float at rect.grow's own (chunk-relative) offset.
	origin.x = floor(origin.x / STEP) * STEP
	origin.y = floor(origin.y / STEP) * STEP
	var w := nx + 1
	var h := nz + 1
	var wet := PackedByteArray()
	wet.resize(w * h)
	for j in h:
		for i in w:
			var p: Vector2 = origin + Vector2(i, j) * STEP
			wet[j * w + i] = 1 if _is_wet(ctx, p) else 0

	var segs: Array = []
	for j in nz:
		for i in nx:
			var corners: Array = [
				Vector2i(i, j), Vector2i(i + 1, j),
				Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			var wf: Array = []
			var wet_n := 0
			for c: Vector2i in corners:
				var v: int = wet[c.y * w + c.x]
				wf.append(v == 1)
				wet_n += v
			if wet_n == 0 or wet_n == 4:
				continue   # fully dry or fully wet: no waterline crosses this cell
			var saddle: bool = wet_n == 2 and wf[0] == wf[2]
			if saddle:
				var cp: Vector2 = origin + Vector2(float(i) + 0.5, float(j) + 0.5) * STEP
				var centre_wet: bool = _is_wet(ctx, cp)
				# Isolate whichever pair of diagonal corners the centre sample
				# disagrees with: centre dry -> isolate the two WET corners
				# (split, not connected); centre wet -> isolate the two DRY
				# corners (joined, the wet diagonal band stays one region).
				# Exactly two of the four corners satisfy wf[k] != centre_wet
				# by construction (two wet, two dry, one fixed centre value),
				# so this always emits exactly two strokes, same as the split
				# branch it generalizes.
				for k: int in _saddle_isolated_corners(wf, centre_wet):
					var a: Vector2 = _refine_crossing(ctx, origin, corners[k], corners[(k + 3) % 4])
					var b: Vector2 = _refine_crossing(ctx, origin, corners[k], corners[(k + 1) % 4])
					segs.append([a, b])
				continue
			# Ordinary (non-saddle) cell: exactly two edges change sign; the
			# crossings on those two edges are the segment endpoints.
			var pts: Array = []
			for k in 4:
				var a: Vector2i = corners[k]
				var b: Vector2i = corners[(k + 1) % 4]
				if wf[k] != wf[(k + 1) % 4]:
					pts.append(_refine_crossing(ctx, origin, a, b))
			if pts.size() == 2:
				segs.append([pts[0], pts[1]])
			# pts.size() != 2 cannot happen for a non-saddle wet_n in {1,2,3}
			# (exactly two sign changes walking the 4-cycle) — defensive, not
			# reachable; no else branch needed.
	return segs


## Refines the wet/dry crossing on grid edge a-b (grid indices, STEP apart)
## against the REAL continuous fields (WaterField.level_at + ground), not
## the coarse presence grid alone — 3 bisection steps narrows the [lo,hi]
## wet/dry bracket from the full STEP=3.0m edge down to a ~0.375m final
## width (3.0 -> 1.5 -> 0.75 -> 0.375), matching the brief's "1.5 m -> 0.4 m
## resolution" sequence. `lo` (the last verified-wet parameter, loop
## invariant) is returned so the crossing always sits marginally on the wet
## side, the same convention the old mesher's own edge-vertex bisection
## used for its own waterline vertex.
static func _refine_crossing(ctx: Dictionary, origin: Vector2, a: Vector2i, b: Vector2i) -> Vector2:
	var pa: Vector2 = origin + Vector2(a) * STEP
	var pb: Vector2 = origin + Vector2(b) * STEP
	var fa: float = _wet_f(ctx, pa)
	var fb: float = _wet_f(ctx, pb)
	var lo := 0.0
	var hi := 1.0
	if fa < 0.0:   # ensure lo starts on the wet end
		var tmp: Vector2 = pa
		pa = pb
		pb = tmp
	var t := 0.5
	for _pass in 3:
		var p: Vector2 = pa.lerp(pb, t)
		if _is_wet(ctx, p):
			lo = t
		else:
			hi = t
		t = (lo + hi) * 0.5
	return pa.lerp(pb, lo)


## --- Step 3: chain segments into polylines ---
##
## Segments are position pairs, not indices (unlike a welded mesh's own
## shared vertex buffer) — chaining keys on a rounded position string, the
## same "quantize a float position into a dictionary key" pattern this
## codebase's own weld passes already use elsewhere (pos_key-style), reused
## here because two segments from adjacent cells share
## their crossing point only up to float rounding, never bit-exact from two
## independent bisection walks starting at different cell corners.
static func _pos_key(p: Vector2) -> String:
	return "%d:%d" % [roundi(p.x / _WELD_EPS), roundi(p.y / _WELD_EPS)]


## Chains an unordered set of [a, b] Vector2 segments into maximal simple
## polylines. Endpoints are matched by _pos_key (see above); a vertex with
## degree != 2 is an open end (walked first, so branches never get split
## mid-chain), degree-2 vertices left over form pure cycles. A polyline is
## marked closed when its own two ends key-match OR sit within _CLOSE_EPS of
## each other (the brief's own "closed loops when ends meet within 0.5m" —
## covers a cycle whose last segment's refined crossing didn't land on
## EXACTLY the same key as its first, e.g. a saddle-cell split stroke
## re-entering the loop from a slightly different sub-cell path).
static func _chain_segments(segments: Array) -> Array:
	var pos_of: Dictionary = {}       # key -> Vector2 (one representative position per key)
	var adj: Dictionary = {}          # key -> Array[key] (may repeat: parallel edges)
	var keys: Array = []
	var key_index: Dictionary = {}

	var key_id := func(p: Vector2) -> int:
		var k: String = _pos_key(p)
		if key_index.has(k):
			return key_index[k]
		var idx: int = keys.size()
		keys.append(k)
		key_index[k] = idx
		pos_of[idx] = p
		adj[idx] = []
		return idx

	for seg: Array in segments:
		var ia: int = key_id.call(seg[0])
		var ib: int = key_id.call(seg[1])
		if ia == ib:
			continue   # degenerate (both ends refined onto the same point) — skip
		adj[ia].append(ib)
		adj[ib].append(ia)

	var visited: Dictionary = {}   # Vector2i(min,max) key-id pair -> true
	var polylines: Array = []

	var edge_key := func(x: int, y: int) -> Vector2i:
		return Vector2i(mini(x, y), maxi(x, y))

	var walk := func(start: int, nxt: int) -> Array:
		var chain: Array = [start]
		var prev := start
		var cur := nxt
		while true:
			chain.append(cur)
			visited[edge_key.call(prev, cur)] = true
			var next_opt := -1
			for o: int in adj.get(cur, []):
				var ek: Vector2i = edge_key.call(cur, o)
				if not visited.has(ek):
					next_opt = o
					break
			if next_opt == -1:
				break
			prev = cur
			cur = next_opt
		return chain

	# Open ends / branches first (degree != 2), same two-pass discipline
	# tests/test_water_contour.gd's own _chain_edges already uses.
	for k in keys.size():
		if adj[k].size() == 2:
			continue
		for nb: int in adj[k]:
			var ek: Vector2i = edge_key.call(k, nb)
			if visited.has(ek):
				continue
			var chain: Array = walk.call(k, nb)
			if chain.size() >= 2:
				polylines.append(chain)
	# Leftover pure cycles (every vertex degree 2).
	for k in keys.size():
		if adj[k].size() != 2:
			continue
		for nb: int in adj[k]:
			var ek: Vector2i = edge_key.call(k, nb)
			if visited.has(ek):
				continue
			var chain: Array = walk.call(k, nb)
			if chain.size() >= 2:
				polylines.append(chain)

	var out: Array = []
	for chain: Array in polylines:
		var pts := PackedVector2Array()
		for idx: int in chain:
			pts.append(pos_of[idx])
		var closed: bool = chain[0] == chain[-1]
		if not closed and pts.size() >= 3 and pts[0].distance_to(pts[-1]) < _CLOSE_EPS:
			closed = true
			pts.remove_at(pts.size() - 1)   # drop the duplicate-ish closing point; loop wraps implicitly
		elif closed and pts.size() >= 2:
			pts.remove_at(pts.size() - 1)   # same point twice (exact key match) — drop the repeat
		out.append({"pts": pts, "closed": closed})
	return out


## --- Step 4: Chaikin corner-cutting + uniform resample ---
##
## Corner-cutting 1/4-3/4: each edge (p0,p1) contributes two new points at
## t=0.25 and t=0.75, replacing the original vertices — the standard Chaikin
## subdivision. OPEN polylines keep their first/last point fixed (endpoint
## preservation — the brief's own requirement, needed so a polyline that
## ends at the grown-rect boundary doesn't retreat from it before clipping);
## CLOSED loops wrap with no fixed points at all.
static func _chaikin(pts: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var n: int = pts.size()
	if n < 3:
		return pts
	var out := PackedVector2Array()
	if closed:
		for i in n:
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[(i + 1) % n]
			out.append(p0.lerp(p1, 0.25))
			out.append(p0.lerp(p1, 0.75))
	else:
		out.append(pts[0])
		for i in n - 1:
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			out.append(p0.lerp(p1, 0.25))
			out.append(p0.lerp(p1, 0.75))
		out.append(pts[-1])
	return out


## Uniform arc-length resample at `spacing`. Walks the (already-smoothed)
## polyline's own segments, dropping a point every `spacing` metres of
## accumulated arc length — the standard "walk and drip" resampler, closed
## loops wrap the last segment back to point 0.
static func _resample(pts: PackedVector2Array, closed: bool, spacing: float) -> PackedVector2Array:
	var n: int = pts.size()
	if n < 2:
		return pts
	# CLOSED curves resample by EVEN DIVISION of the circumference — a fixed
	# `spacing` walk leaves the wrap-back segment as an arbitrary remainder in
	# (0, spacing), which fails "every segment in [1.0, 2.0]m" whenever the
	# circumference is not a clean multiple of spacing (e.g. the 117m pond
	# bowl's own 0.185m leftover, tipped below 1.0m by the descent-level
	# change). Dividing the loop into `cnt` equal arcs of `eff = circ/cnt`
	# (eff ~ spacing) removes the remainder entirely and keeps determinism —
	# same circumference -> same cnt/eff/points on both sides of a chunk
	# border, so the weld still holds.
	if closed:
		return _resample_closed(pts, spacing)
	var out := PackedVector2Array([pts[0]])
	var carry := 0.0
	for i in n - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len < 0.000001:
			continue
		var d: Vector2 = (b - a) / seg_len
		var t := spacing - carry
		while t < seg_len:
			out.append(a + d * t)
			t += spacing
		carry = seg_len - (t - spacing)
	# Preserve the exact original open endpoint (the resample's own drip stops
	# just short of it — see t < seg_len above) so an open polyline's tip never
	# drifts before clipping runs.
	if out[-1].distance_to(pts[n - 1]) > 0.001:
		out.append(pts[n - 1])
	return out


## Even-arc resample of a CLOSED ring (points are a cycle: the last connects
## back to the first). Returns `cnt` points, all consecutive gaps equal to
## `circ/cnt` (~spacing), with NO remainder segment. cnt >= 3 so the loop is
## always a valid polygon; the floor pins cnt at 3 for any small loop, so eff
## only risks dropping under the 1.0m resample floor when circumference itself
## is under 3.0m — a puddle that tiny is already at the resolution floor and
## none occurs on the pinned seeds.
static func _resample_closed(pts: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var m: int = pts.size()
	if m < 3:
		return pts
	var cum := PackedFloat32Array()
	cum.resize(m)
	var circ := 0.0
	for i in m:
		cum[i] = circ
		circ += pts[i].distance_to(pts[(i + 1) % m])
	if circ < 0.000001:
		return pts
	var cnt: int = maxi(3, roundi(circ / spacing))
	var eff: float = circ / float(cnt)
	var out := PackedVector2Array()
	var seg := 0
	for k in cnt:
		var target: float = eff * float(k)
		while seg + 1 < m and cum[seg + 1] <= target:
			seg += 1
		var a: Vector2 = pts[seg]
		var b: Vector2 = pts[(seg + 1) % m]
		var seg_len: float = a.distance_to(b)
		var d: Vector2 = (b - a) / seg_len if seg_len > 0.000001 else Vector2.ZERO
		out.append(a + d * (target - cum[seg]))
	return out


## --- Step 5: clip to rect (runs LAST, after smoothing) ---
##
## Splits the (already smoothed+resampled) polyline into pieces whose points
## all lie inside `rect`, inserting an EXACT border-crossing point wherever
## consecutive points straddle the rect boundary — that exact interpolation
## is the weld: two neighbouring chunks both smoothed the SAME
## rect.grow(MARGIN)-derived polyline (world-grid-aligned presence sampling
## makes it identical on both sides), so clipping each to its own
## (different) rect against that shared curve yields the SAME point at the
## shared edge, up to float lerp determinism.
## Returns {"pieces": Array[PackedVector2Array], "closed": bool} — closed is
## true only when the WHOLE input loop stayed inside rect untouched (no
## piece was cut, so there is exactly one piece and it is still a genuine
## loop); any polyline that gets clipped at all becomes one or more OPEN
## pieces (a closed pond curve that pokes past a chunk edge is not closed
## from that chunk's own point of view — its recorded shape here is the arc
## actually owned by this chunk).
static func _clip_to_rect(pts: PackedVector2Array, closed: bool, rect: Rect2) -> Dictionary:
	var n: int = pts.size()
	if n == 0:
		return {"pieces": [], "closed": false}
	if closed:
		var all_in := true
		for p: Vector2 in pts:
			if not rect.has_point(p):
				all_in = false
				break
		if all_in:
			return {"pieces": [pts], "closed": true}

	var ring: PackedVector2Array = pts.duplicate()
	if closed:
		ring.append(pts[0])
	var pieces: Array = []
	var cur := PackedVector2Array()
	for i in ring.size():
		var p: Vector2 = ring[i]
		var inside: bool = rect.has_point(p)
		if inside:
			if cur.is_empty() and i > 0:
				# Entering the rect from outside: insert the exact boundary
				# crossing first (see _rect_crossing) — UNLESS the resampled
				# point p already sits right on the boundary itself (a real,
				# fairly common case: Rect2.has_point is boundary-inclusive,
				# so a resample step can land its very next point exactly on
				# the rect edge — e.g. z=-1152.0 landing on rect.position.y
				# =-1152.0 — and the interpolated crossing would then be a
				# near-duplicate of p, appended immediately before it).
				var prev: Vector2 = ring[i - 1]
				if not rect.has_point(prev):
					var cross: Vector2 = _rect_crossing(prev, p, rect)
					if cross.distance_to(p) > 0.001:
						cur.append(cross)
			cur.append(p)
		else:
			if not cur.is_empty():
				var prev: Vector2 = ring[i - 1]
				var cross: Vector2 = _rect_crossing(prev, p, rect)
				# Same near-duplicate guard on the exit side: prev (cur's own
				# last appended point) may already sit essentially on the
				# boundary itself, making cross nearly coincide with it.
				if cross.distance_to(cur[-1]) > 0.001:
					cur.append(cross)
				pieces.append(cur)
				cur = PackedVector2Array()
	if not cur.is_empty():
		pieces.append(cur)
	return {"pieces": pieces, "closed": false}


## Exact rect-boundary crossing along segment a(in)->b(out) or a(out)->b(in)
## — parametric line/rect intersection, clamped to the segment. Since a
## `Rect2` clip is against one convex box, the segment crosses at most one
## boundary line before the point classification (has_point) flips, so the
## smallest positive t across the (up to) four half-plane tests is the
## correct single crossing.
static func _rect_crossing(a: Vector2, b: Vector2, rect: Rect2) -> Vector2:
	var d: Vector2 = b - a
	var best_t := 1.0
	var lo: Vector2 = rect.position
	var hi: Vector2 = rect.position + rect.size
	for axis in 2:
		var av: float = a[axis]
		var dv: float = d[axis]
		if absf(dv) < 0.000001:
			continue
		for bound in [lo[axis], hi[axis]]:
			var t: float = (bound - av) / dv
			if t < -0.0001 or t > 1.0001:
				continue
			var p: Vector2 = a + d * t
			# Only a genuine boundary-line crossing that also falls within
			# the rect's OTHER axis range counts — a t that merely crosses
			# one bound's infinite line far outside the box's other extent
			# is not where has_point actually flips.
			var other: int = 1 - axis
			if p[other] < lo[other] - 0.001 or p[other] > hi[other] + 0.001:
				continue
			if t < best_t:
				best_t = t
	return a + d * clampf(best_t, 0.0, 1.0)


## --- Step 6: per-point level/normal/wall attributes ---
##
## Pointwise wetness-gradient fallback used only when an entire clipped
## curve has no decisive wet/dry side samples.  A gradient is a useful side
## witness, but it is NOT a stable moving frame: at a centre-wet diagonal
## saddle it can pass through zero and reverse 180 degrees between adjacent
## 1.5m contour samples.  WaterSkin then extrudes neighbouring rim columns to
## opposite sides, forming a bow tie and leaving the genuinely wet saddle
## unmeshed.  `_curve_outward_side` below therefore chooses one consistent
## side of the G1 curve and this helper is only the degenerate fallback.
static func _gradient_outward_normal(ctx: Dictionary, p: Vector2) -> Vector2:
	var h := 1.0
	var fx1: float = _wet_f(ctx, p + Vector2(h, 0.0))
	var fx0: float = _wet_f(ctx, p - Vector2(h, 0.0))
	var fz1: float = _wet_f(ctx, p + Vector2(0.0, h))
	var fz0: float = _wet_f(ctx, p - Vector2(0.0, h))
	var grad := Vector2(fx1 - fx0, fz1 - fz0)
	if grad.length_squared() < 0.000001:
		return Vector2(1, 0)   # degenerate (locally flat wetness — no direction to derive) — arbitrary but fixed
	return -grad.normalized()   # outward = away from increasing wetness = toward dry


## Unit tangent of the already-smoothed/resampled curve.  Central difference
## is used in the interior and one-sided differences at open endpoints.  A
## closed curve wraps, so its frame stays continuous across point 0.
static func _curve_tangent(pts: PackedVector2Array, closed: bool, i: int) -> Vector2:
	var n: int = pts.size()
	var lo: int = (i - 1 + n) % n if closed else maxi(i - 1, 0)
	var hi: int = (i + 1) % n if closed else mini(i + 1, n - 1)
	var tangent: Vector2 = pts[hi] - pts[lo]
	if tangent.length_squared() < 0.000001:
		return Vector2(1, 0)
	return tangent.normalized()


## Selects one globally consistent side of a clipped G1 contour as outward.
## `+1` means the tangent's left normal, `-1` its right normal. Each point
## walks 0.5/1.5/3/6m probes on both sides and votes at the FIRST distance
## that distinguishes them; the long probes are necessary because two
## Chaikin passes can move the visual curve more than 1.5m inside a broad
## wet fill. Magnitudes are intentionally discarded so one very tall cliff
## cannot outweigh a long run of ordinary shoreline. The contour separates
## wet from dry by construction, so all decisive votes should agree. Using one
## side for the whole curve makes a 180-degree adjacent-frame reversal
## impossible while still letting the frame turn smoothly with the curve.
##
## The old concern with tangent normals was wall CLASSIFICATION at a convex
## corner whose tangent bisected two cliff arms. `_attributes` now probes
## this normal plus +/-45-degree guards, so either real arm is still seen;
## the tangent frame here controls geometry, while those guarded probes
## control the wall flag.
static func _curve_outward_side(ctx: Dictionary, pts: PackedVector2Array,
		closed: bool) -> float:
	var votes := 0
	for i in pts.size():
		var tangent: Vector2 = _curve_tangent(pts, closed, i)
		var left := Vector2(-tangent.y, tangent.x)
		for d in [0.5, 1.5, 3.0, WaterField.FILL_STEP]:
			var left_score: float = _wet_f(ctx, pts[i] + left * float(d))
			var right_score: float = _wet_f(ctx, pts[i] - left * float(d))
			if left_score < right_score - 0.01:
				votes += 1
				break
			if right_score < left_score - 0.01:
				votes -= 1
				break
	if votes != 0:
		return 1.0 if votes > 0 else -1.0
	var mid: int = pts.size() / 2
	var tangent: Vector2 = _curve_tangent(pts, closed, mid)
	var left := Vector2(-tangent.y, tangent.x)
	return 1.0 if left.dot(_gradient_outward_normal(ctx, pts[mid])) >= 0.0 else -1.0


## Per-point level/normal/wall attributes. Wall flag probes ground at +0.5m
## and +1.5m along the outward normal and its +/-45-degree corner guards:
## either sample rising past WALL_SLOPE metres-per-metre flags the point a
## wall. The flanking directions matter after smoothing at a cliff corner:
## the wetness gradient can bisect the two real faces and send the centre
## probe through the diagonal notch even though both adjacent faces rise.
##
## Rise is measured from the point's own WATER LEVEL, not its own ground
## sample (`g_here`) — found necessary (not the brief's literal first
## reading, but required to make its own formula behave correctly at a
## sharp convex rock corner): TWO Chaikin passes cut a raw ~90-degree
## corner down to a mathematically-expected ~26.57-degree residual (verified
## by direct simulation, this task's report), and the interpolated corner
## point can land ON a stepped/quantized rock shelf whose OWN ground sample
## already sits well above the water (measured on this seed: one offender
## read g_here=24.0 against level=13.7, i.e. already 10.3m up the wall with
## nothing left to "rise" INTO in any direction — the crest of the corner,
## not a real shoreline point). Anchoring the rise measurement to the
## point's stable field-truth water level instead of its own (possibly
## smoothing-drifted) ground sample correctly reclassifies every such crest
## point as a wall (both known offenders verified: (35.23,-1044.02) and
## (-660.05,-3323.30), see the report) while a genuine gentle shore point —
## whose ground sample sits close to its own level BY CONSTRUCTION (it came
## from a bisection-refined wet/dry crossing before smoothing ever moved
## it) — is unaffected: the two anchors only diverge once smoothing has
## already carried the point somewhere the raw crossing never was.
static func _attributes(ctx: Dictionary, pts: PackedVector2Array, closed: bool) -> Dictionary:
	var n: int = pts.size()
	var levels := PackedFloat32Array()
	var normals := PackedVector2Array()
	var wall := PackedByteArray()
	levels.resize(n)
	normals.resize(n)
	wall.resize(n)
	var outward_side: float = _curve_outward_side(ctx, pts, closed)
	for i in n:
		var p: Vector2 = pts[i]
		var lvl: float = WaterField.level_at(ctx, p)
		levels[i] = lvl
		var tangent: Vector2 = _curve_tangent(pts, closed, i)
		var nrm := Vector2(-tangent.y, tangent.x) * outward_side
		normals[i] = nrm
		var is_wall := false
		var probes: Array[Vector2] = [nrm, nrm.rotated(PI * 0.25), nrm.rotated(-PI * 0.25)]
		for probe: Vector2 in probes:
			var g05: float = _ground(ctx, p + probe * 0.5)
			var g15: float = _ground(ctx, p + probe * 1.5)
			var slope05: float = (g05 - lvl) / 0.5
			var slope15: float = (g15 - lvl) / 1.5
			if slope05 > WALL_SLOPE or slope15 > WALL_SLOPE:
				is_wall = true
				break
		wall[i] = 1 if is_wall else 0
	# A rounded 90-degree corner can briefly point its probes through the low
	# diagonal pocket even though both straight reaches on either side are the
	# same dressed cliff.  Leaving those 2-3 smoothed samples untagged retracts
	# the meniscus precisely at the corner and opens a diagonal slot.  Close
	# only short gaps bracketed by proven wall samples; a genuinely gentle shore
	# (no wall on one side) is untouched.
	var original: PackedByteArray = wall.duplicate()
	for i in n:
		if original[i] == 1:
			continue
		var before := -1
		var after := -1
		var before_i := -1
		var after_i := -1
		for d in range(1, 5):
			var bi: int = i - d
			var ai: int = i + d
			if closed:
				bi = posmod(bi, n)
				ai = posmod(ai, n)
			if before < 0 and bi >= 0 and bi < n and original[bi] == 1:
				before = d
				before_i = bi
			if after < 0 and ai >= 0 and ai < n and original[ai] == 1:
				after = d
				after_i = ai
		var turns_corner: bool = before_i >= 0 and after_i >= 0 \
			and normals[before_i].dot(normals[after_i]) < 0.8
		if before > 0 and after > 0 and before + after <= 4 and turns_corner:
			wall[i] = 1
	return {"pts": pts, "levels": levels, "normals": normals, "wall": wall, "closed": closed}

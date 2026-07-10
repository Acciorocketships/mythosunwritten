# Waterline -> smooth, chunk-welded curves. Pure function of (ctx, rect); no
# nodes, no mesh. Consumed by WaterSkin (plan Task 4+): the boundary a mesher
# stitches into a conforming strip must be a small set of clean G1 polylines,
# not the raw ~45-90 degree marching-squares corners WaterMesher's own
# perimeter walk produces (see tests/test_water_contour.gd's red evidence,
# .superpowers/sdd/r3-task-2-report.md). Six-step pipeline (brief's own
# numbering, .superpowers/sdd/r3-task-3-brief.md):
#   1. presence grid (STEP=3.0) over rect.grow(MARGIN)
#   2. per-edge crossing refinement (3 bisection steps against the REAL
#      fields, not the coarse grid — same discipline as WaterMesher._edge_vert)
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
## file goes through one name — mirrors WaterField.gd/WaterMesher.gd's own
## per-file `_ground`-style helpers rather than repeating the ctx.region
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


## curves(ctx, rect) -> Array[Dictionary], each:
##   pts: PackedVector2Array      # world xz, ~1.5 m spacing, G1-smooth
##   levels: PackedFloat32Array   # water level at each pt (field truth)
##   normals: PackedVector2Array  # outward (dry-side) unit normals
##   wall: PackedByteArray        # 1 where local ground slope across the line > WALL_SLOPE
##   closed: bool
## ctx MUST carry a region (WaterField.ctx(water, chunk, region)) — ground()
## reads ctx.region directly, same requirement WaterMesher.build's own ctx has.
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
## mirroring WaterMesher._mesh_cell's own corner/edge classification but
## emitting a boundary STROKE instead of a triangulated wet polygon — the
## saddle tie-break (opposite-corner wet, centre sample decides
## joined/split) is copied verbatim from that function for the same reason
## documented there: it is the one place a marching-squares grid is
## genuinely ambiguous, and the two consumers must resolve it identically or
## a saddle cell would mesh one shape while the contour walks another.
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
			var centre_wet := false
			if saddle:
				var cp: Vector2 = origin + Vector2(float(i) + 0.5, float(j) + 0.5) * STEP
				centre_wet = _is_wet(ctx, cp)
			if saddle and not centre_wet:
				# Split saddle: two disjoint crossings, one per wet corner —
				# each wet corner contributes its own short stroke between
				# its two adjacent edges (mirrors _mesh_cell's two
				# corner-triangle branch).
				for k in 4:
					if not wf[k]:
						continue
					var a: Vector2 = _refine_crossing(ctx, origin, corners[k], corners[(k + 3) % 4])
					var b: Vector2 = _refine_crossing(ctx, origin, corners[k], corners[(k + 1) % 4])
					segs.append([a, b])
				continue
			# Ordinary (or joined-saddle) cell: exactly two edges change sign;
			# the crossings on those two edges are the segment endpoints.
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
## side, same convention WaterMesher._edge_vert uses for its own waterline
## vertex.
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
## Segments are position pairs, not indices (unlike WaterMesher, which welds
## into one shared vertex buffer) — chaining keys on a rounded position
## string, the same "quantize a float position into a dictionary key"
## pattern WaterMesher._hem_vert already uses for its own weld pass
## (pos_key), reused here because two segments from adjacent cells share
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


## --- Step 4: Chaikin corner-cutting (2 passes) + uniform resample ---
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
	var ring: PackedVector2Array = pts.duplicate()
	if closed:
		ring.append(pts[0])
	var out := PackedVector2Array([ring[0]])
	var carry := 0.0
	for i in ring.size() - 1:
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[i + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len < 0.000001:
			continue
		var d: Vector2 = (b - a) / seg_len
		var t := spacing - carry
		while t < seg_len:
			out.append(a + d * t)
			t += spacing
		carry = seg_len - (t - spacing)
	if closed:
		# The wrap-around duplicate of ring[0] was only a walking aid; the
		# resampled ring already implicitly closes back to out[0] (the
		# consumer treats a closed poly's point array as a cycle, no
		# explicit repeat of the first point at the end — same convention
		# _chain_segments' own closed output already uses).
		if out.size() > 1 and out[0].distance_to(out[-1]) < 0.001:
			out.remove_at(out.size() - 1)
	else:
		# Preserve the exact original open endpoint (the resample's own
		# drip stops just short of it — see t < seg_len above) so an open
		# polyline's tip never drifts before clipping runs.
		if out[-1].distance_to(ring[-1]) > 0.001:
			out.append(ring[-1])
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
## Outward (dry-side) normal from a CENTRAL-DIFFERENCE gradient of the
## wetness field `_wet_f` (level-ground) at p, not from the polyline's own
## tangent — the tangent-perpendicular approach was tried first and found
## unreliable exactly at a sharp (near-90-degree) convex wall corner: after
## 2 Chaikin passes a corner-adjacent point can sit on a stepped/quantized
## rock shelf whose LOCAL tangent bisects the two real wall faces, so a
## single probe along that bisector can miss both (measured directly on
## this seed's site: point (12.79,-1043.53), tangent-normal (0.47,0.88)
## read a flat 0.0 m/m slope in that one direction while ground genuinely
## rises past WALL_SLOPE in every OTHER direction around the same point —
## see this task's report). The wetness gradient has no such blind spot: it
## is a property of the CONTINUOUS field itself (independent of how the
## smoothed polyline happens to be parameterized at that point), always
## points toward increasing wetness by construction, and at the same
## offending corner correctly resolves to the wall-facing direction
## (verified: -gradient there triggers the +1.5m wall probe at slope 5.33,
## comfortably past WALL_SLOPE). `h=1.0` central difference (four
## WaterField.level_at + TerrainSurfaceField.surface_y calls per point) is
## the natural sample width for a boundary lying on a STEP=3.0m grid.
static func _outward_normal(ctx: Dictionary, p: Vector2) -> Vector2:
	var h := 1.0
	var fx1: float = _wet_f(ctx, p + Vector2(h, 0.0))
	var fx0: float = _wet_f(ctx, p - Vector2(h, 0.0))
	var fz1: float = _wet_f(ctx, p + Vector2(0.0, h))
	var fz0: float = _wet_f(ctx, p - Vector2(0.0, h))
	var grad := Vector2(fx1 - fx0, fz1 - fz0)
	if grad.length_squared() < 0.000001:
		return Vector2(1, 0)   # degenerate (locally flat wetness — no direction to derive) — arbitrary but fixed
	return -grad.normalized()   # outward = away from increasing wetness = toward dry


## Per-point level/normal/wall attributes. Wall flag probes ground at +0.5m
## and +1.5m along the outward normal (brief's own two probe distances):
## either sample rising past WALL_SLOPE metres-per-metre flags the point a
## wall (probing both catches a wall whose face sits slightly set back from
## the sampled waterline point as well as one that rises immediately).
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
	for i in n:
		var p: Vector2 = pts[i]
		var lvl: float = WaterField.level_at(ctx, p)
		levels[i] = lvl
		var nrm: Vector2 = _outward_normal(ctx, p)
		normals[i] = nrm
		var g05: float = _ground(ctx, p + nrm * 0.5)
		var g15: float = _ground(ctx, p + nrm * 1.5)
		var slope05: float = (g05 - lvl) / 0.5
		var slope15: float = (g15 - lvl) / 1.5
		wall[i] = 1 if (slope05 > WALL_SLOPE or slope15 > WALL_SLOPE) else 0
	return {"pts": pts, "levels": levels, "normals": normals, "wall": wall, "closed": closed}

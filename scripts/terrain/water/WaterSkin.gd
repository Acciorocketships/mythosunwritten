# A boundary-conforming water sheet whose outer rim sits directly on
# WaterContour's smooth curves (Task 3), not on WaterMesher's own
# marching-squares grid corners — this is the mesh that actually fixes the
# angular shoreline test_water_contour.gd's header documents. Two vertex
# families welded into one indexed surface:
#   - INTERIOR: a 3.0m world-aligned lattice, kept only at points >= 2.0m
#     inside a curve. "Inside" = WaterField.level_at's OWN field-truth
#     wetness (the exact same wet/dry oracle WaterContour._is_wet uses to
#     place the curves in the first place — see _lattice_wet below), gated by
#     a presence-grid-accelerated distance-to-nearest-curve-point for the
#     INSET margin. A first implementation tried a pure geometric proxy
#     instead (nearest curve point + which side of ITS outward normal p sits
#     on, no field query at all) reasoning it was the direct generalization
#     of point-in-polygon to boundaries that may not close (a chunk's curves
#     are routinely OPEN here — verified empirically on SITE_CHUNK: 3/3
#     curves open, 0 closed, a river/lake network clipped by the chunk rect
#     never closes into a polygon on this terrain) — this task's OWN
#     test_no_free_edges_except_border caught it red-handed: a curve point's
#     normal is only a reliable inside/outside signal NEAR that point: at
#     world (45,-1149), 14.6m from the nearest curve point across a wide
#     open lake, the nearest point's LOCAL outward normal pointed the wrong
#     way for this far-away query, misclassifying real wet field territory
#     as dry and leaving a hole in the interior mesh with free edges nowhere
#     near any curve (see this task's report for the full transcript). The
#     field itself has no such blind spot — it is the ground truth the
#     curves are already contours OF, so lattice wetness and curve position
#     are consistent by construction, not by geometric coincidence. Height =
#     WaterField.level_at (the brief's own rule).
#   - BOUNDARY STRIP: one vertex per curve point, ON the curve, at the
#     curve's own baked level — zippered to the interior lattice's own
#     jagged edge ring via a greedy two-polyline triangle-strip walk (the
#     standard "bridge two open polylines" algorithm), so every triangle
#     touching the curve has exactly one edge shared with its strip neighbour
#     and one edge on each polyline — no T-junction is possible by
#     construction, because the interior grid's own quad triangulation never
#     touches a boundary vertex directly; only the strip does.
# MENISCUS RIM (Task 5, see _rim): three more rows per curve point, curling
# OUTWARD (dry side) and DOWN from the strip's own curve vertex (reused as
# row0) to a buried seal under the terrain. This is what heals the strip's
# own former free edge (the curve itself, Task 4's documented "no rim yet"
# waterline) into interior geometry — the free-edge invariant TIGHTENS here:
# only the rim's own buried outer row (row3) and true chunk borders may be
# free edges from this task onward.
class_name WaterSkin
extends Object

const STEP := 3.0             # interior lattice spacing — brief's own "3.0m world-aligned lattice"
const INSET := 2.0            # brief's own "points >= 2.0m inside a curve"
const BUCKET := 3.0           # presence-grid bucket size for nearest-curve-point acceleration
const WELD_Q := 64.0          # position-quantize scale for the shared vertex weld (brief: "y*64")
const WELD_XZ_Q := 100.0      # 1cm horizontal precision — finer than WELD_Q since strip verts must weld exactly
const TILE := 24.0            # trigger tiling — matches WaterMesher.TILE / WaterSurfaceBuilder.TILE
const TRIGGER_TOP_CLEAR := 1.7
const TRIGGER_BOTTOM_CLEAR := 5.0

# --- Meniscus rim (Task 5) — brief's own literal per-point profile, local
# frame (outward normal n, level L, ground g): row0 = the strip's own curve
# vertex (weld-reused, not a new position); row1 = p, y=L-ROW1_DROP; row2 =
# p + reach2*n, y=L-ROW2_DROP; row3 = p + reach3*n, y = min(L-ROW3_DROP,
# g-GROUND_BURY). reach2/reach3 default to (ROW2_REACH, ROW3_REACH) and pinch
# toward WALL_PINCH at wall-flagged points — see _rim's own docstring.
const RIM_ROW1_DROP := 0.02
const RIM_ROW2_DROP := 0.18
const RIM_ROW3_DROP := 0.30
const RIM_ROW2_REACH := 0.35
const RIM_ROW3_REACH := 0.55
const RIM_WALL_PINCH := 0.05
const RIM_GROUND_BURY := 0.30


## build(water, chunk, region) -> {} when dry, else:
##   arrays: Array           # Mesh.ARRAY_MAX arrays, indexed, welded (VERTEX/NORMAL/INDEX/CUSTOM0)
##   triggers: Array[Dictionary]  # {rect: Rect2, top: float, bottom: float}
##   sampler: WaterSampler   # Task 7 deliverable — null until then (interface is forward-declared
##                           # by the plan's own Produces contract; this task's own checklist
##                           # tests arrays/tri-count/free-edges/interior-height only, never sampler)
## chunk is a 192m streamer chunk (site (0,-6)) — same convention
## WaterMesher.build's own `base := Vector2(chunk.x, chunk.y) * (TILE * 8.0)` uses (plan erratum,
## docs/superpowers/plans/2026-07-10-water-continuous-surface.md).
static func build(water: WaterPlan, chunk: Vector2i, region) -> Dictionary:
	var ctx: Dictionary = WaterField.ctx(water, chunk, region)
	if ctx.ponds.is_empty() and ctx.rivers.is_empty():
		return {}
	var span: float = WaterField.TILE * 8.0
	var rect := Rect2(Vector2(chunk) * span, Vector2.ONE * span)
	var curves: Array = WaterContour.curves(ctx, rect)
	if curves.is_empty():
		return {}

	var buckets: Dictionary = _build_buckets(curves)
	var st: Dictionary = {
		"ctx": ctx, "region": region, "rect": rect, "curves": curves, "buckets": buckets,
		"verts": PackedVector3Array(), "idx": PackedInt32Array(), "weld": {},
	}
	var lattice: Dictionary = _interior_lattice(st)
	if lattice.kept.is_empty():
		return {}
	_interior_mesh(st, lattice)
	for c: Dictionary in curves:
		_boundary_strip(st, lattice, c)
		_rim(st, c)
	if st.idx.is_empty():
		return {}

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = st.verts
	arrays[Mesh.ARRAY_INDEX] = st.idx
	var normals := PackedVector3Array()
	normals.resize(st.verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_CUSTOM0] = _custom0(st)

	return {"arrays": arrays, "triggers": _triggers(st), "sampler": null}


## Per-vertex CUSTOM0 = (flow.x, shore, flow.y, steep) — the water shader's
## CURRENT contract (water_unified.gdshader reads flow_v/steep_v/shore_v from
## exactly these lanes), mirroring WaterMesher._attributes' own per-vertex
## loop minus its plunge-churn band (steep_spans is empty at the pinned site
## per H1, and Task 6/8 replace both the band and these CUSTOM0 semantics
## outright — baking the retiring band into the NEW mesher would be dead
## code on arrival). Without this array the skin renders with flow/shore/
## steep all zero — visibly flow-dead water and no shore fade, which would
## corrupt this task's own visual-gate comparison against the WaterMesher
## look for reasons that have nothing to do with the waterline shape under
## review.
static func _custom0(st: Dictionary) -> PackedFloat32Array:
	var cust := PackedFloat32Array()
	cust.resize(st.verts.size() * 4)
	for vi in st.verts.size():
		var v: Vector3 = st.verts[vi]
		var p := Vector2(v.x, v.z)
		var fl: Vector2 = WaterField.flow_at(st.ctx, p)
		var g: float = TerrainSurfaceField.surface_y(st.region, v.x, v.z)
		var shore: float = clampf(1.0 - (v.y - g) * 1.2, 0.0, 1.0) \
			if v.y > g - 0.5 else 1.0
		var steep: float = clampf(WaterField.grade_at(st.ctx, p) * 8.0, 0.0, 0.85)
		cust[vi * 4 + 0] = fl.x
		cust[vi * 4 + 1] = shore
		cust[vi * 4 + 2] = fl.y
		cust[vi * 4 + 3] = steep
	return cust


## Assembles the committed ArrayMesh from build()'s own `arrays` — the same
## surface format WaterMesher.commit produces (CUSTOM0 as RGBA float), so the
## one shared sheet material reads either mesh identically.
static func commit(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh


## --- Presence-grid acceleration (brief's own "point-in-polygon by winding
## over the chunk's curves + presence-grid acceleration") ---
##
## Buckets every curve point by its floor(p/BUCKET) cell so nearest-point
## lookup only ever scans the query point's own cell + 8 neighbours instead
## of every curve point in the chunk — the same "world-aligned spatial hash"
## acceleration pattern WaterField.ctx's own `buckets` (river samples by 24m
## cell) already uses for the same reason.
static func _build_buckets(curves: Array) -> Dictionary:
	var buckets: Dictionary = {}
	for ci in curves.size():
		var c: Dictionary = curves[ci]
		var pts: PackedVector2Array = c.pts
		for i in pts.size():
			var cell := Vector2i(int(floor(pts[i].x / BUCKET)), int(floor(pts[i].y / BUCKET)))
			if not buckets.has(cell):
				buckets[cell] = []
			buckets[cell].append(Vector2i(ci, i))
	return buckets


## Nearest curve-point distance to `p`, searched via the bucket (radius_cells
## bucket neighbourhood — 1 comfortably covers any curve point within INSET=
## 2.0 of p given BUCKET=STEP=3.0, since a point up to 2.0m outside p's own
## cell can only ever land in an immediately-adjacent cell). Returns INF when
## no curve point exists within that window — for the INSET gate (see
## _lattice_wet) that already means "far enough from every curve," so the
## caller never needs to widen the search: INF is a fully decided answer, not
## an inconclusive one, unlike a "which side" test that needs a REAL nearest
## point to have any direction to compare against.
static func _nearest_curve_dist(st: Dictionary, p: Vector2, radius_cells: int) -> float:
	var cell := Vector2i(int(floor(p.x / BUCKET)), int(floor(p.y / BUCKET)))
	var best := INF
	for dz in range(-radius_cells, radius_cells + 1):
		for dx in range(-radius_cells, radius_cells + 1):
			var b: Array = st.buckets.get(cell + Vector2i(dx, dz), [])
			for ref: Vector2i in b:
				var q: Vector2 = st.curves[ref.x].pts[ref.y]
				best = minf(best, p.distance_to(q))
	return best


## True when p is >= INSET metres inside a curve: WaterField.level_at's own
## field-truth wetness (identical oracle to WaterContour._is_wet — the exact
## source the curves themselves are contours of, so this can never disagree
## with where the curves say the shore is) AND no curve point lies within
## INSET of p (the presence-grid-accelerated bucket scan above — a cheap
## existence check, not a full nearest-point search: for the sole purpose of
## "does anything sit closer than INSET," an early INF from a 1-cell-radius
## bucket scan already means "no," since nothing outside that radius could
## be closer than INSET < BUCKET). See this file's header for why the FIELD
## (not a curve point's own local outward-normal side) decides wet/dry: a
## curve point's normal is only reliable near that point, and this task's
## own test_no_free_edges_except_border caught the geometric-only version
## misclassifying real wet territory 14.6m from the nearest curve point
## across a wide lake.
static func _lattice_wet(st: Dictionary, p: Vector2) -> Dictionary:
	var lvl: float = WaterField.level_at(st.ctx, p)
	if lvl == -INF:
		return {"wet": false, "dist": 0.0}
	var g: float = TerrainSurfaceField.surface_y(st.region, p.x, p.y)
	if lvl <= g + 0.02:
		return {"wet": false, "dist": 0.0}
	var dist: float = _nearest_curve_dist(st, p, 1)
	return {"wet": dist >= INSET, "dist": dist}


## Builds the kept-point set: 3.0m world-aligned lattice (origin snapped to
## the world STEP grid, same "floor(x/STEP)*STEP" convention WaterContour's
## own presence grid uses — this is what makes two neighbouring chunks'
## lattices land on IDENTICAL world columns/rows at their shared border) over
## `rect`, each point tested by _lattice_wet, height = WaterField.level_at
## (the brief's own rule for interior vertices).
## Index bounds are computed directly from the rect span (a 192m chunk is
## EXACTLY 64 * STEP, same as WaterMesher's own N=64/S=3.0 lattice), NOT
## filtered through Rect2.has_point: an earlier version used has_point as a
## belt-and-braces bounds check and it silently dropped the entire i=64 /
## j=64 column and row — Godot's Rect2.has_point treats the far edge as
## EXCLUSIVE (verified directly: has_point(rect.position+rect.size) is
## false), so the lattice's own rightmost/bottommost world-border column
## never got a vertex at all. That produced a REAL free-edge defect (this
## task's report): the interior mesh's second-to-last column (one lattice
## step shy of the true border) had nothing to zip to — no curve runs there
## either, since the water is simply wet straight through to the border with
## no shoreline in that stretch — leaving a dangling jagged edge nowhere
## near border OR curve. Plain integer index loops need no such filter: the
## chunk span is an exact multiple of STEP by construction, so i/j in
## [0, nx-1]/[0, nz-1] can never leave [origin, origin+span] in the first
## place.
## Returns {"kept": Dictionary[Vector2i -> {p: Vector2, y: float}], "nx": int,
## "nz": int, "origin": Vector2} — kept is keyed by LATTICE INDEX (i,j), not
## world position, so _interior_mesh can do O(1) neighbour lookups.
static func _interior_lattice(st: Dictionary) -> Dictionary:
	var rect: Rect2 = st.rect
	var origin: Vector2 = rect.position
	origin.x = floor(origin.x / STEP) * STEP
	origin.y = floor(origin.y / STEP) * STEP
	var nx: int = int(round((rect.position.x + rect.size.x - origin.x) / STEP)) + 1
	var nz: int = int(round((rect.position.y + rect.size.y - origin.y) / STEP)) + 1
	var kept: Dictionary = {}
	for j in nz:
		for i in nx:
			var p: Vector2 = origin + Vector2(i, j) * STEP
			var w: Dictionary = _lattice_wet(st, p)
			if not w.wet:
				continue
			var y: float = WaterField.level_at(st.ctx, p)
			if y == -INF:
				continue
			kept[Vector2i(i, j)] = {"p": p, "y": y}
	return {"kept": kept, "nx": nx, "nz": nz, "origin": origin}


## Emits the interior sheet: for every 2x2 lattice-cell block whose all 4
## corners are kept, two triangles (a standard quad split, +Y winding to
## match every other water mesh in this codebase — see WaterMesher._mesh_cell
## and its own "+Y like the quad branch" comment). A kept point missing ANY
## of its 4 potential quads (i.e. it borders at least one dropped neighbour
## or the lattice edge) is recorded into lattice.edge_ring — the jagged
## interior boundary the boundary strip zips onto next.
static func _interior_mesh(st: Dictionary, lattice: Dictionary) -> void:
	var kept: Dictionary = lattice.kept
	var nx: int = lattice.nx
	var nz: int = lattice.nz
	var vi: Dictionary = {}   # Vector2i(i,j) -> vertex index, only for kept points USED by a quad
	var on_edge: Dictionary = {}   # Vector2i(i,j) -> true (kept point touches >=1 missing quad)

	var vert_for := func(ij: Vector2i) -> int:
		if vi.has(ij):
			return vi[ij]
		var e: Dictionary = kept[ij]
		var idx: int = _weld_vert(st, e.p, e.y)
		vi[ij] = idx
		return idx

	for j in nz - 1:
		for i in nx - 1:
			var c00 := Vector2i(i, j)
			var c10 := Vector2i(i + 1, j)
			var c01 := Vector2i(i, j + 1)
			var c11 := Vector2i(i + 1, j + 1)
			var quad_ok: bool = kept.has(c00) and kept.has(c10) and kept.has(c01) and kept.has(c11)
			if not quad_ok:
				for c: Vector2i in [c00, c10, c01, c11]:
					if kept.has(c):
						on_edge[c] = true
				continue
			var a: int = vert_for.call(c00)
			var b: int = vert_for.call(c10)
			var cc: int = vert_for.call(c11)
			var d: int = vert_for.call(c01)
			for t in [[a, d, cc], [a, cc, b]]:
				for k in 3:
					st.idx.append(t[k])
	# Edge-ring membership is EXACTLY "kept point with a missing IN-RANGE
	# quad" (flagged by the sweep above) — deliberately NOT also every kept
	# point on the lattice's outer index bound. A first version blanket-
	# flagged the outer bound too ("never has all 4 quads available"), which
	# is true but answers the wrong question: a border-row point whose
	# in-chunk quads all exist needs no strip coverage (its missing quads lie
	# ACROSS the chunk border, where the NEIGHBOUR chunk's own lattice —
	# world-aligned, same columns — provides the geometry; a free edge along
	# the border line is the one legitimately-free class this pipeline has,
	# same as WaterMesher's own border exemption). Injecting such points into
	# a curve's ring is not just wasted work — it FOLDS the ring chain:
	# caught red-handed on pond chunk (-4,-18)'s south border, where a wet
	# inlet's horseshoe curve exits the chunk and fully-quad-covered border
	# point (-606,-3456) (5.6m from the curve, inside capture) got chained
	# between (-609,-3456) and (-609,-3453) — a 3.0m-tie the greedy walk
	# broke toward the geometrically wrong side, doubling the chain back on
	# itself and stranding 2 free edges where the fold overlapped the
	# interior quads (this task's report has the full trace).
	lattice["edge_ring"] = on_edge
	lattice["vi"] = vi


## Orders a scattered set of ring points into a "necklace" by greedy nearest-
## neighbour chaining in plain 2D space, starting from whichever ring point
## sits closest to the curve's own first point (so the chain's own start end
## agrees with the curve's index-0 end — see _boundary_strip's own
## direction-agreement requirement). This REPLACED an earlier version that
## sorted ring points by projecting each onto the curve's own arc-length
## parameterization (nearest-point-on-polyline, standard technique) — that
## approach is fundamentally unsound within about one lattice-STEP (3.0m) of
## any curve corner tighter than the lattice spacing: TWO incoming/outgoing
## curve segments meeting at a sharp vertex both clamp their nearest-point
## projection to that SAME vertex for every nearby ring point regardless of
## which side of the corner it is actually on, collapsing distinct points to
## identical (or, with an unclamped-projection variant tried next,
## unreliably ordered) arc values. Measured directly on this task's own
## pinned site (see the report): a genuine L-shaped shore corner at
## (35.23,-1044.02) — already WaterContour's own documented hard case, see
## that file's _outward_normal docstring — produced 2-4 ring points whose
## nearest curve segments were all >2m away at wildly extrapolated
## projection parameters (measured t_raw up to 5.48 on a ~1.5m segment,
## meaningless that far out), so NEITHER arc-projection variant could order
## them correctly; the resulting locally non-monotonic ring left 4 free
## edges stranded exactly at that corner. A pure 2D nearest-neighbour chain
## has no such blind spot: it never touches the curve's own parameterization
## at all, only the ring points' mutual distances, which stay well-behaved
## (each ring point's true nearest ring neighbour is always another ring
## point roughly one lattice STEP away, corner or not) — verified directly
## against the same offending corner: the chain visits ...(30,-1041),
## (33,-1041), (36,-1041), (39,-1041), (39,-1044), (39,-1047)... in exactly
## the geometrically correct order, and independently verified globally
## (sampling the curve's own point index at 7 checkpoints from 0 to 221 and
## finding each one's nearest ring-chain position) that chain order tracks
## curve index order monotonically end to end, not just locally at the
## corner.
## Bucket-accelerated (same BUCKET-sized spatial hash the curve-point lookup
## already uses — ring points are LATTICE points, always exactly STEP=3.0m
## apart from a true neighbour, so a 3x3-bucket search around the current
## chain tip always finds its real nearest unvisited neighbour without
## scanning the whole ring): O(ring_size) amortised per curve instead of the
## naive O(ring_size^2) a linear scan would cost.
static func _order_ring_by_nn_chain(ring_pts: Array, start_ref: Vector2) -> Array:
	var n: int = ring_pts.size()
	if n <= 1:
		return range(n)
	var rbuckets: Dictionary = {}
	for i in n:
		var cell := Vector2i(int(floor(ring_pts[i].x / BUCKET)), int(floor(ring_pts[i].y / BUCKET)))
		if not rbuckets.has(cell):
			rbuckets[cell] = []
		rbuckets[cell].append(i)

	var start_i := 0
	var start_d := INF
	for i in n:
		var d: float = ring_pts[i].distance_to(start_ref)
		if d < start_d:
			start_d = d
			start_i = i

	var visited := PackedByteArray()
	visited.resize(n)
	var order: Array = [start_i]
	visited[start_i] = 1
	var cur := start_i
	for _k in n - 1:
		var cur_p: Vector2 = ring_pts[cur]
		var cell := Vector2i(int(floor(cur_p.x / BUCKET)), int(floor(cur_p.y / BUCKET)))
		var best_i := -1
		var best_d := INF
		var radius := 1
		# Widen the bucket search until a candidate is found — bounded by n
		# (the whole ring), so this always terminates even for a
		# pathologically sparse leftover set near the very end of the chain.
		while best_i == -1 and radius <= n:
			for dz in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if maxi(absi(dx), absi(dz)) != radius and radius > 1:
						continue   # only scan the NEW outer ring on widened passes
					for i: int in rbuckets.get(cell + Vector2i(dx, dz), []):
						if visited[i] == 1:
							continue
						var d: float = cur_p.distance_to(ring_pts[i])
						if d < best_d:
							best_d = d
							best_i = i
			radius += 1
		order.append(best_i)
		visited[best_i] = 1
		cur = best_i
	return order


## Bridges curve `c`'s own point chain (one vertex per point, ON the curve,
## at the curve's OWN baked level — the brief's literal rule) to the interior
## lattice's edge-ring vertices that lie near this curve, via a greedy
## two-polyline triangle-strip walk (the standard "zipper" algorithm for
## triangulating the region between two roughly-parallel open polylines: at
## each step, compare the two candidate diagonals — advancing the curve
## cursor vs advancing the ring cursor — and take whichever is SHORTER,
## which keeps the strip from producing long, crossing, or degenerate
## triangles). Both polylines are walked in the SAME direction (the ring is
## pre-ordered by _order_ring_by_nn_chain, whose chain starts at the ring
## point nearest this curve's own first point, so index order on both sides
## already agrees) — this is what guarantees no T-junction: the
## interior lattice's own quad triangulation (_interior_mesh) never emits a
## triangle touching a boundary vertex at all, so the strip is the ONLY
## geometry connecting the two, and every strip triangle shares a full edge
## with its neighbour in the strip, never a partial one.
static func _boundary_strip(st: Dictionary, lattice: Dictionary, c: Dictionary) -> void:
	var pts: PackedVector2Array = c.pts
	var levels: PackedFloat32Array = c.levels
	var n: int = pts.size()
	if n < 2:
		return
	# Curve-chain vertices: one per curve point, ON the curve, at its own level.
	var curve_vi := PackedInt32Array()
	curve_vi.resize(n)
	for i in n:
		curve_vi[i] = _weld_vert(st, pts[i], levels[i])

	# Ring: interior edge-ring points within a short capture radius of THIS
	# curve (a chunk can carry multiple curves — a ring point must only zip
	# to the curve it actually borders, not a distant unrelated one), ordered
	# by 2D nearest-neighbour chaining (_order_ring_by_nn_chain — see its own
	# docstring for why this replaced an arc-length-projection sort).
	# Capture radius is DERIVED from the worst-case edge-ring geometry, not
	# tuned: a kept point lands on the edge ring because one of its quad
	# neighbours was dropped, and an inset-dropped neighbour sits < INSET
	# (2.0m) from the curve; the kept point itself sits at most one lattice
	# diagonal (STEP*sqrt(2) ~= 4.24m) from that neighbour, so a genuine
	# edge-ring point can legitimately lie up to INSET + STEP*sqrt(2) ~= 6.24m
	# from the curve it borders. The first version used STEP*1.8 = 5.4m
	# ("comfortably catches the adjacent lattice row") and was caught
	# under-derived on the isolated-pond chunk (-4,-18): a real edge-ring
	# point at 5.625m (diagonally inside the pond bowl's corner) missed
	# capture, stranding 3 free edges on interior lattice points (this task's
	# report). INSET + STEP*1.5 = 6.5m covers the true bound with slack.
	var capture: float = INSET + STEP * 1.5
	var ring_pts: Array = []
	var ring_y: Array = []
	for ij: Vector2i in lattice.edge_ring:
		var e: Dictionary = lattice.kept[ij]
		var d: float = _dist_point_to_curve(c, e.p)
		if d > capture:
			continue
		ring_pts.append(e.p)
		ring_y.append(e.y)
	if ring_pts.is_empty():
		return   # nothing nearby yet kept (e.g. a sliver curve with no adjacent interior) — no strip to build
	var order: Array = _order_ring_by_nn_chain(ring_pts, pts[0])
	var ring_vi := PackedInt32Array()
	ring_vi.resize(order.size())
	for k in order.size():
		var oi: int = order[k]
		ring_vi[k] = _weld_vert(st, ring_pts[oi], ring_y[oi])

	_zip_strip(st, curve_vi, ring_vi, c.closed)


## Meniscus rim (Task 5): three new vertex rows per curve point, curling the
## water's visible edge DOWN and OUTWARD (toward the dry bank, +normal) from
## the boundary strip's own curve vertex, then diving under the terrain so
## the sheet always seals against the ground with no gap — the brief's own
## literal per-point profile (local frame: outward normal n, level L, ground
## g):
##   row0 = the EXISTING strip curve vertex (p, L) itself — reused by weld
##          key, NOT a new vertex. This is the load-bearing seam: row0 must
##          resolve to the exact same index _boundary_strip already put in
##          curve_vi (guaranteed by _weld_vert's own key = quantized (x,z,y),
##          identical inputs here (pts[i], levels[i]) to what _boundary_strip
##          just used two lines above the call site in build()). Without this
##          reuse, Task 4's own documented free edge (the curve itself — "no
##          rim yet, the boundary strip's own outer edge IS the waterline's
##          free edge") never gets covered by the row0-row1 band below, and
##          would stay free forever instead of healing into interior mesh —
##          this is the concrete mechanism behind this task's tightened
##          free-edge invariant (see test_free_edges_only_buried_rim_or_border).
##   row1 = p,             y = L - 0.02   (the meniscus crest: a hairline dip
##          right at the water's own edge before the surface curls away —
##          same xz as row0, so this first "riser" is a near-vertical 2cm lip)
##   row2 = p + reach2*n,  y = L - 0.18
##   row3 = p + reach3*n,  y = min(L - 0.30, g(p + reach3*n) - 0.30) (buried
##          seal, ALWAYS >=0.30m under both the water level AND the actual
##          ground sample at its own xz, so it can never pop back above
##          either regardless of local terrain undulation — the "ALWAYS
##          under ground" the brief itself calls out).
## reach2/reach3 default to (RIM_ROW2_REACH, RIM_ROW3_REACH) and pinch toward
## a flush RIM_WALL_PINCH at wall-flagged points (brief: "water meets wall
## flush, no bulge into rock") — SMOOTHED across neighbouring curve points
## (_smoothed_wall, a 3-tap tent filter over the raw wall flags) rather than
## switched hard per point: a lone wall flag flapping true/false between
## adjacent ~1.5m-spaced curve points (a real occurrence near the WALL_SLOPE
## threshold, see WaterContour._attributes' own rise-from-level probe) would
## otherwise zigzag the rim's outer silhouette in and out every segment; the
## smoothed reach eases the pinch in/out over roughly one segment either side
## of a transition instead of jumping.
## Triangulation: 3 "bands" (row0-row1, row1-row2, row2-row3), each a
## standard quad split per curve segment — same [a,d,cc],[a,cc,b] corner
## convention _interior_mesh's own quad split uses (a=row_k[i], b=row_k[j],
## d=row_{k+1}[i], cc=row_{k+1}[j]) — through _emit_tri, so winding stays
## whatever consistent rule the rest of this file already applies; this
## function never picks triangle order by hand. Closed curves wrap (j wraps
## to 0 at the last segment); open curves stop one segment short and instead
## get an end cap at each of their two exposed ends (_rim_end_cap) — without
## it the three riser edges at an open end (row0-row1, row1-row2, row2-row3)
## are each used by exactly one band triangle (no i-1 column to share the
## other side), a real free-edge defect caught directly on SITE_CHUNK's own
## three open (border-to-border) curves before the cap existed (this task's
## report has the transcript).
static func _rim(st: Dictionary, c: Dictionary) -> void:
	var pts: PackedVector2Array = c.pts
	var levels: PackedFloat32Array = c.levels
	var normals: PackedVector2Array = c.normals
	var wall: PackedByteArray = c.wall
	var n: int = pts.size()
	if n < 2:
		return
	var closed: bool = c.closed
	var wf: PackedFloat32Array = _smoothed_wall(wall, closed)

	var row0 := PackedInt32Array()
	var row1 := PackedInt32Array()
	var row2 := PackedInt32Array()
	var row3 := PackedInt32Array()
	row0.resize(n)
	row1.resize(n)
	row2.resize(n)
	row3.resize(n)
	for i in n:
		var p: Vector2 = pts[i]
		var nrm: Vector2 = normals[i]
		var lvl: float = levels[i]
		row0[i] = _weld_vert(st, p, lvl)
		row1[i] = _weld_vert(st, p, lvl - RIM_ROW1_DROP)
		var reach2: float = lerpf(RIM_ROW2_REACH, RIM_WALL_PINCH, wf[i])
		var reach3: float = lerpf(RIM_ROW3_REACH, RIM_WALL_PINCH, wf[i])
		var p2: Vector2 = p + nrm * reach2
		row2[i] = _weld_vert(st, p2, lvl - RIM_ROW2_DROP)
		var p3: Vector2 = p + nrm * reach3
		var g3: float = TerrainSurfaceField.surface_y(st.region, p3.x, p3.y)
		var y3: float = minf(lvl - RIM_ROW3_DROP, g3 - RIM_GROUND_BURY)
		row3[i] = _weld_vert(st, p3, y3)

	var lim: int = n if closed else n - 1
	for i in lim:
		var j: int = (i + 1) % n
		_emit_tri(st, row0[i], row1[i], row1[j])
		_emit_tri(st, row0[i], row1[j], row0[j])
		_emit_tri(st, row1[i], row2[i], row2[j])
		_emit_tri(st, row1[i], row2[j], row1[j])
		_emit_tri(st, row2[i], row3[i], row3[j])
		_emit_tri(st, row2[i], row3[j], row2[j])

	if not closed:
		_rim_end_cap(st, row0[0], row1[0], row2[0], row3[0])
		var last: int = n - 1
		_rim_end_cap(st, row0[last], row1[last], row2[last], row3[last])


## Caps an open curve's rim ladder at one exposed end (see _rim's own
## docstring for why this is needed). A 2-triangle fan from row0 through
## row1/row2/row3 — (row0,row1,row2) and (row0,row2,row3) — shares an edge
## with each of the three band triangles that otherwise left row0-row1,
## row1-row2, row2-row3 single-used (now double-used, healed), at the cost of
## exactly one NEW free edge: the fan's own closing diagonal row0-row3. That
## is the minimum any triangulation of an open 4-point profile can achieve —
## the quad (row0,row1,row2,row3) has 4 boundary edges, 3 already carry one
## use each from the bands, so 2 triangles can heal those 3 but must open a
## 4th boundary edge to close the shape (any 2-triangle fan, from any apex,
## has this same count — verified by hand for all four apex choices before
## picking row0, the simplest to reach from this call site). The remaining
## row0-row3 edge is itself accounted for under this task's tightened
## invariant: row0 sits exactly at the curve's own point, which for every
## open curve WaterContour._clip_to_rect produces is an exact chunk-border
## crossing (verified directly on both pinned sites — SITE_CHUNK's three
## open curves and the pond chunk's horseshoe — this task's report has the
## coordinates), and row3 trivially satisfies the buried-outer-row test at
## distance 0 from itself.
static func _rim_end_cap(st: Dictionary, i0: int, i1: int, i2: int, i3: int) -> void:
	_emit_tri(st, i0, i1, i2)
	_emit_tri(st, i0, i2, i3)


## Tent-filtered (0.25/0.5/0.25) copy of `wall` as a continuous per-point
## blend weight for _rim's own reach2/reach3 lerp — see _rim's docstring for
## why a hard per-point pinch switch zigzags the rim at wall/shore
## transitions. Open curves clamp at their own ends (duplicate the edge
## value, the standard fixed-boundary convention for a 1D filter); closed
## curves wrap.
static func _smoothed_wall(wall: PackedByteArray, closed: bool) -> PackedFloat32Array:
	var n: int = wall.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var prev_i: int = (i - 1 + n) % n if closed else maxi(i - 1, 0)
		var next_i: int = (i + 1) % n if closed else mini(i + 1, n - 1)
		out[i] = 0.25 * float(wall[prev_i]) + 0.5 * float(wall[i]) + 0.25 * float(wall[next_i])
	return out


## Position lookup for a welded vertex index — used by the zipper's own
## distance comparisons (verts are already in world space post-weld, so this
## is just an array read, not a recompute).
static func _vpos(st: Dictionary, vi: int) -> Vector3:
	return st.verts[vi]


## The zipper walk itself: bridges chain A (curve, size n) to chain B (sorted
## ring, size m) with a greedy shortest-diagonal triangle strip. `closed`
## wraps A back to index 0 at the end (a closed curve's own last point
## connects to its first). Every read of A's frontier vertex goes through
## `a[i % n]`, never `a[i]` raw: with closed=true the A-cursor legitimately
## exhausts AT i == end_a == n (one past the last index — the state meaning
## "wrapped fully back to a[0]"), and the B-only advance branch still needs
## the frontier vertex then — a raw a[i] read there is an out-of-bounds
## crash, caught red-handed on the isolated-pond chunk (-4,-18)'s closed
## curve (n=124: "Out of bounds get index '124'", trace in this task's
## report; the open-curve site chunk never trips it because an open A stops
## at end_a == n-1, a valid index). For open curves i % n == i in every
## reachable state, so the wrap arithmetic is a no-op there.
## CLOSED-ANNULUS CLOSING TRIANGLE: for a closed curve the strip region
## between the curve loop and its ring is an annulus — after the main walk
## ends (frontier edge (a[0], b[m-1]), since A has wrapped to a[0] and B
## stands at its last point) the strip must close back to its own START
## edge (a[0], b[0]) or the gap between the ring's last and first points is
## left as a hole in the sheet (free edges on interior lattice points,
## nowhere near curve or border). The two edges share a[0], so ONE triangle
## (a[0], b[m-1], b[0]) spans the gap exactly. m == 1 needs none (the walk
## already fanned every A segment around the single ring vertex); open
## curves need none (their strip has two genuine ends, not a loop).
static func _zip_strip(st: Dictionary, a: PackedInt32Array, b: PackedInt32Array, closed: bool) -> void:
	var n: int = a.size()
	var m: int = b.size()
	if m == 0:
		return
	var end_a: int = n if closed else n - 1   # closed: n segments (wraps); open: n-1 segments
	var i := 0
	var j := 0
	while i < end_a or j < m - 1:
		var can_adv_a: bool = i < end_a
		var can_adv_b: bool = j < m - 1
		if can_adv_a and can_adv_b:
			var a_next: int = a[(i + 1) % n]
			# Candidate 1: advance A — triangle (a[i], a_next, b[j]).
			var d1: float = _vpos(st, a_next).distance_to(_vpos(st, b[j]))
			# Candidate 2: advance B — triangle (a[i], b[j+1], b[j]).
			var d2: float = _vpos(st, a[i % n]).distance_to(_vpos(st, b[j + 1]))
			if d1 <= d2:
				_emit_tri(st, a[i % n], a_next, b[j])
				i += 1
			else:
				_emit_tri(st, a[i % n], b[j + 1], b[j])
				j += 1
		elif can_adv_a:
			var a_next2: int = a[(i + 1) % n]
			_emit_tri(st, a[i % n], a_next2, b[j])
			i += 1
		else:
			_emit_tri(st, a[i % n], b[j + 1], b[j])
			j += 1
	if closed and m >= 2:
		_emit_tri(st, a[0], b[m - 1], b[0])


## Emits one strip triangle. Winding: the curve chain `a` runs along the
## WATER'S edge and the ring chain `b` runs along the interior (wet) side —
## for the sheet to wind +Y (this codebase's universal water-mesh
## convention, see WaterMesher._mesh_cell's "+Y like the quad branch"), the
## triangle order (p0, p1, p2) must place the INTERIOR vertex so the
## computed normal points up; empirically fixed against the interior mesh's
## own known-+Y quads (see test_all_triangles_wind_up-style check in this
## task's own test suite) as (p_a_first, p_b_or_a_next, p_ring_or_a) below.
static func _emit_tri(st: Dictionary, i0: int, i1: int, i2: int) -> void:
	var v0: Vector3 = st.verts[i0]
	var v1: Vector3 = st.verts[i1]
	var v2: Vector3 = st.verts[i2]
	var nrm: Vector3 = (v1 - v0).cross(v2 - v0)
	var order: Array = [i0, i1, i2] if nrm.y >= 0.0 else [i0, i2, i1]
	for k in order:
		st.idx.append(k)


## Distance from p to curve c's own polyline (segment-nearest, not just
## point-nearest) — used only to gate which ring points capture to which
## curve when a chunk carries several (a straight point-to-point distance
## can miss a ring point that projects cleanly onto a segment MIDPOINT).
static func _dist_point_to_curve(c: Dictionary, p: Vector2) -> float:
	var pts: PackedVector2Array = c.pts
	var n: int = pts.size()
	var lim: int = n if c.closed else n - 1
	var best := INF
	for i in lim:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var seg: Vector2 = b - a
		var seg_len2: float = seg.length_squared()
		var t: float = clampf((p - a).dot(seg) / seg_len2, 0.0, 1.0) if seg_len2 > 0.000001 else 0.0
		best = minf(best, p.distance_to(a + seg * t))
	return best


## Shared weld: dedupes by quantized (x, z, y*64) per the brief's explicit
## key — WELD_XZ_Q (1cm) horizontal precision is finer than the y*64
## (~1.6cm) vertical precision because two DIFFERENT strip triangles
## legitimately reuse the exact SAME curve point (a curve-chain vertex is
## referenced by every triangle touching that point along the strip) and
## must resolve to one shared index, while two merely-nearby interior lattice
## points must NOT collapse into each other.
static func _weld_vert(st: Dictionary, p: Vector2, y: float) -> int:
	var key := Vector3i(roundi(p.x * WELD_XZ_Q), roundi(p.y * WELD_XZ_Q), roundi(y * WELD_Q))
	if st.weld.has(key):
		return st.weld[key]
	var idx: int = st.verts.size()
	st.verts.append(Vector3(p.x, y, p.y))
	st.weld[key] = idx
	return idx


## Triggers: one box per 24m TILE cell touched by any built vertex (kept
## interior OR boundary-strip), matching WaterSurfaceBuilder's EXISTING
## swim-volume tiling/clearance convention (top = max level + 1.7, bottom =
## min ground - 5.0) so a future adapter swap-in is a drop-in shape match.
## This is scaffolding for Task 7's real sampler-backed trigger wiring (the
## plan's own Task 7 brief: "one box per 24m wet coverage tile... every
## Area3D carries set_meta('sampler', sampler)") — this task's own checklist
## never exercises `triggers` (WaterSurfaceBuilder keeps using WaterMesher's
## wet_cells for volumes until Task 7, per this task's own context brief), so
## the shape only needs to satisfy the documented dict contract, not yet
## drive real gameplay.
static func _triggers(st: Dictionary) -> Array:
	var cells: Dictionary = {}   # Vector2i cell -> {top: float, bottom: float}
	for v: Vector3 in st.verts:
		var cell := Vector2i(int(floor(v.x / TILE)), int(floor(v.z / TILE)))
		var g: float = TerrainSurfaceField.surface_y(st.region, v.x, v.z)
		if not cells.has(cell):
			cells[cell] = {"top": v.y, "bottom": g}
		else:
			cells[cell].top = maxf(cells[cell].top, v.y)
			cells[cell].bottom = minf(cells[cell].bottom, g)
	var out: Array = []
	for cell: Vector2i in cells:
		var e: Dictionary = cells[cell]
		out.append({
			"rect": Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE),
			"top": e.top + TRIGGER_TOP_CLEAR,
			"bottom": e.bottom - TRIGGER_BOTTOM_CLEAR,
		})
	return out

# Boundary-conforming water sheet: marching squares over the 3m sub-grid on
# f(x,z) = level(x,z) - ground(x,z). Interior cells emit welded grid quads;
# boundary cells emit contour polygons whose edge vertices sit ON the
# waterline (Task 4); fall cuts split cells into upstream/downstream parts
# (Task 5); every contour free edge grows a buried hem (Task 6).
class_name WaterMesher
extends Object

const TILE := 24.0
const N := 64                 # marching cells per chunk side
const S := 3.0                # sub-grid step (TILE * 8 cells / 64)
const EPS := 0.05
const CUT_JUMP := 2.0         # adjacent-sample level jump that marks a cut
const HEM_DROP := 1.2
const HEM_W := 1.5


## st: shared build state. One per build() call.
static func build(water: WaterPlan, chunk: Vector2i, region) -> Dictionary:
	# ctx built WITH region so the lattice and _edge_vert see the flooded
	# field (level_at's flood extension over low ground).
	var c: Dictionary = WaterField.ctx(water, chunk, region)
	if c.ponds.is_empty() and c.rivers.is_empty():
		return {}
	var base := Vector2(chunk.x, chunk.y) * (TILE * 8.0)
	var st: Dictionary = {
		"region": region, "ctx": c, "base": base,
		"lvl": PackedFloat32Array(), "gnd": PackedFloat32Array(),
		"verts": PackedVector3Array(), "idx": PackedInt32Array(),
		"cust": PackedFloat32Array(), "weld": {},
		"cuts": WaterField.fall_cuts(c, Rect2(base, Vector2.ONE * TILE * 8.0)),
		"cut_hits": {},   # cut index -> Array of lip/base vert records (Task 5)
	}
	st.lvl.resize((N + 1) * (N + 1))
	st.gnd.resize((N + 1) * (N + 1))
	var any_wet := false
	for j in N + 1:
		for i in N + 1:
			var p: Vector2 = base + Vector2(i, j) * S
			var lvl: float = WaterField.level_at(c, p)
			st.lvl[j * (N + 1) + i] = lvl
			st.gnd[j * (N + 1) + i] = TerrainSurfaceField.surface_y(region, p.x, p.y)
			if lvl > -INF and lvl > st.gnd[j * (N + 1) + i] + EPS:
				any_wet = true
	if not any_wet:
		return {}
	for j in N:
		for i in N:
			_mesh_cell(st, i, j)
	_hem(st)          # no-op until Task 6
	_attributes(st)   # no-op until Task 7
	var cut_records: Array = []
	for ci: int in st.cut_hits:
		var cut: Dictionary = st.cuts[ci]
		var rec := {"cut": cut, "lip": PackedVector3Array(), "base": PackedVector3Array()}
		for side_key in ["lip", "base"]:
			var vis: Array = st.cut_hits[ci][side_key]
			vis.sort_custom(func(x, y):
				var px := Vector2(st.verts[x].x, st.verts[x].z)
				var py := Vector2(st.verts[y].x, st.verts[y].z)
				return (px - cut.p).dot(cut.across) < (py - cut.p).dot(cut.across))
			for vi: int in vis:
				rec[side_key].append(st.verts[vi])
		cut_records.append(rec)
	st["cut_records"] = cut_records
	return {"verts": st.verts, "idx": st.idx, "cust": st.cust,
		"cuts": st.get("cut_records", []), "wet_cells": st.get("wet_cells", {})}


static func _f(st: Dictionary, i: int, j: int) -> float:
	var lvl: float = st.lvl[j * (N + 1) + i]
	return -INF if lvl == -INF else lvl - st.gnd[j * (N + 1) + i]


static func _wet(st: Dictionary, i: int, j: int) -> bool:
	return _f(st, i, j) > EPS


static func _lattice_vert(st: Dictionary, i: int, j: int) -> int:
	var key := "L:%d:%d" % [i, j]
	if st.weld.has(key):
		return st.weld[key]
	var p: Vector2 = st.base + Vector2(i, j) * S
	var vi: int = st.verts.size()
	st.verts.append(Vector3(p.x, st.lvl[j * (N + 1) + i], p.y))
	st.weld[key] = vi
	return vi


## Perimeter-walk marching squares. Corners in CCW order; walking the cell
## boundary and inserting a waterline vertex at every wet/dry sign change
## yields the wet polygon directly (fan-triangulated). Saddle rule: the
## cell-centre sample decides connectivity (documented spec choice).
static func _mesh_cell(st: Dictionary, i: int, j: int) -> void:
	var corners: Array = [
		Vector2i(i, j), Vector2i(i + 1, j),
		Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
	var wet_flags: Array = []
	var wet_n := 0
	for cnr: Vector2i in corners:
		var w: bool = _wet(st, cnr.x, cnr.y)
		wet_flags.append(w)
		wet_n += 1 if w else 0
	if wet_n == 0:
		return
	if _cell_jump(st, i, j):
		_mesh_cut_cell(st, i, j, corners, wet_flags)   # Task 5
		return
	if wet_n == 4:
		var a: int = _lattice_vert(st, i, j)
		var b: int = _lattice_vert(st, i + 1, j)
		var cc: int = _lattice_vert(st, i + 1, j + 1)
		var d: int = _lattice_vert(st, i, j + 1)
		for t in [[a, d, cc], [a, cc, b]]:
			for k in 3:
				st.idx.append(t[k])
		return
	# Saddle: wet at opposite corners only -> centre sample picks joined/split.
	var saddle: bool = wet_n == 2 and wet_flags[0] == wet_flags[2]
	var centre_wet := false
	if saddle:
		var cp: Vector2 = st.base + Vector2(float(i) + 0.5, float(j) + 0.5) * S
		var clvl: float = WaterField.level_at(st.ctx, cp)
		centre_wet = clvl > -INF \
			and clvl > TerrainSurfaceField.surface_y(st.region, cp.x, cp.y) + EPS
	if saddle and not centre_wet:
		for k in 4:   # two separate corner triangles
			if wet_flags[k]:
				st.idx.append(_lattice_vert(st, corners[k].x, corners[k].y))
				st.idx.append(_edge_vert(st, corners[k], corners[(k + 3) % 4]))
				st.idx.append(_edge_vert(st, corners[k], corners[(k + 1) % 4]))
		return
	var poly: Array = []
	for k in 4:
		var a: Vector2i = corners[k]
		var b: Vector2i = corners[(k + 1) % 4]
		if wet_flags[k]:
			poly.append(_lattice_vert(st, a.x, a.y))
		if wet_flags[k] != wet_flags[(k + 1) % 4]:
			poly.append(_edge_vert(st, a, b))
	# _edge_vert snaps a crossing within weld tolerance of the wet corner to
	# that corner's OWN lattice vertex (its documented behaviour): a corner
	# immediately followed or preceded by an edge-crossing can then repeat
	# the same vert index back to back in poly (e.g. [42, 42, 43, 43]).
	# Fan straight through that and every triangle touching the repeat is
	# zero-area — collapse adjacent duplicates first so the fan only ever
	# sees distinct perimeter points.
	poly = _dedupe_adjacent(poly)
	# Perimeter order is clockwise from above in Godot axes; the fan is
	# reversed so all sheet triangles wind +Y like the quad branch.
	for k in range(1, poly.size() - 1):   # fan
		st.idx.append(poly[0])
		st.idx.append(poly[k + 1])
		st.idx.append(poly[k])


## Collapses consecutive (including wrap-around) equal entries in a
## perimeter-walk poly. _edge_vert/_cut_vert legitimately return a corner's
## own lattice vertex when a crossing snaps to it; left in place that
## produces a repeated index adjacent to itself in the poly, and every fan
## triangle spanning the repeat is zero-area (pollutes the free-edge parity
## count downstream — see free_edges/_free_edge_indices). A poly is a closed
## loop, so the LAST entry can also duplicate the FIRST; drop that too, but
## never below a 3-entry (one triangle) result — an under-3 poly means the
## whole cell degenerated and the caller's fan range already emits nothing.
static func _dedupe_adjacent(poly: Array) -> Array:
	if poly.size() < 2:
		return poly
	var out: Array = [poly[0]]
	for k in range(1, poly.size()):
		if poly[k] != out[-1]:
			out.append(poly[k])
	if out.size() > 1 and out[0] == out[-1]:
		out.remove_at(out.size() - 1)
	return out


## Waterline vertex on the lattice edge a-b. XZ: linear interp on f refined
## by bisection against the real fields — [lo, hi] narrows until tight, and
## lo (the last verified-wet t, by loop invariant) is the reported position,
## so the vertex is guaranteed on the water side of the crossing (a wall
## face, a claim edge, or a beach). Y: the vertex RIDES THE WATER LEVEL,
## never the ground (amended rule) — on this cliff-heavy terrain most shores
## are vertical walls, and the waterline there IS the wall face at water
## height. Welded by edge key so both cells sharing the edge reuse it.
static func _edge_vert(st: Dictionary, a: Vector2i, b: Vector2i) -> int:
	var key := "X:%d:%d:%d:%d" % [mini(a.x, b.x), mini(a.y, b.y),
		absi(b.x - a.x), absi(b.y - a.y)]
	if st.weld.has(key):
		return st.weld[key]
	var fa: float = _f(st, a.x, a.y)
	var fb: float = _f(st, b.x, b.y)
	if fa == -INF:
		fa = -1.0
	if fb == -INF:
		fb = -1.0
	var t: float = clampf(fa / (fa - fb), 0.05, 0.95)
	var pa: Vector2 = st.base + Vector2(a) * S
	var pb: Vector2 = st.base + Vector2(b) * S
	var wet_c: Vector2i = a
	var lo: float = 0.0
	var hi: float = 1.0
	if fa < 0.0:   # ensure lo is the wet end
		var tmp: Vector2 = pa
		pa = pb
		pb = tmp
		wet_c = b
		t = 1.0 - t
	for _pass in 20:
		if hi - lo < 0.0005:
			break
		var p: Vector2 = pa.lerp(pb, t)
		var lvl: float = WaterField.level_at(st.ctx, p)
		var g: float = TerrainSurfaceField.surface_y(st.region, p.x, p.y)
		if lvl > -INF and lvl - g > 0.0:
			lo = t
		else:
			hi = t
		t = (lo + hi) * 0.5
	var p: Vector2 = pa.lerp(pb, lo)
	var lvl: float = WaterField.level_at(st.ctx, p)
	if lvl == -INF:
		lvl = st.lvl[wet_c.y * (N + 1) + wet_c.x]   # wet end's own level
	# A crossing within the weld/dedup tolerance of the wet corner IS that
	# corner — reuse its lattice vertex instead of a near-duplicate.
	if p.distance_to(pa) < 0.05:
		var vi_corner: int = _lattice_vert(st, wet_c.x, wet_c.y)
		st.weld[key] = vi_corner
		return vi_corner
	var vi: int = st.verts.size()
	st.verts.append(Vector3(p.x, lvl, p.y))
	st.weld[key] = vi
	return vi


## A cell whose corner levels jump more than CUT_JUMP: two water surfaces
## meet inside it. Mesh each side separately. Near a recorded fall cut the
## sides are the fall's lip and base sheets and the seam verts are
## registered for FallMesher; elsewhere (a body seam — two claimants with
## different levels meeting where no fall exists) the cell is split the
## same way against a synthetic local cut but records nothing: no fall
## will be built there (Task 6's hem owns those free edges).
## Corner membership is by LEVEL (nearer top vs bottom), NOT by cut-plane
## side: at a cut's lateral extremity the claim boundary bends away from
## the plane, and plane-side classification puts wrong-level corners into
## a side's poly, bridging it vertically. Edges crossing between the
## sides get one vertex PER SIDE at the claim boundary, each riding its
## own side's level — the two sides deliberately do NOT weld across the
## jump; FallMesher's curtain (or the hem) owns the face between them.
static func _mesh_cut_cell(st: Dictionary, i: int, j: int,
		corners: Array, wet_flags: Array) -> void:
	var ci: int = _cell_cut(st, i, j)
	var cut: Dictionary = st.cuts[ci] if ci != -1 else _synth_cut(st, i, j, corners)
	for side in [1, -1]:   # 1 = the higher surface, -1 = the lower
		var poly: Array = []
		for k in 4:
			var a: Vector2i = corners[k]
			var b: Vector2i = corners[(k + 1) % 4]
			var a_in: bool = wet_flags[k] and _lvl_side(st, cut, a) == side
			var b_in: bool = wet_flags[(k + 1) % 4] and _lvl_side(st, cut, b) == side
			if a_in:
				poly.append(_lattice_vert(st, a.x, a.y))
			if a_in != b_in:
				# Crossing the waterline or the seam? Seam when both wet.
				if wet_flags[k] and wet_flags[(k + 1) % 4]:
					poly.append(_cut_vert(st, ci, a, b, side))
				else:
					poly.append(_edge_vert(st, a, b))
		# Same corner-snap repeat as _mesh_cell's poly (see
		# _dedupe_adjacent) — _edge_vert/_cut_vert can return a corner's own
		# lattice vertex back to back with that corner's own poly entry.
		poly = _dedupe_adjacent(poly)
		# Guard: a cell whose wet corners span >= 3 level clusters (two
		# seams/cuts crossing one 3m cell at a 3-body corner) cannot 2-way
		# split cleanly — one side necessarily groups two far-apart levels
		# and its fan would fold across the jump. Drop that polygon LOUDLY
		# instead of emitting it: a rare hole at a triple seam beats a
		# silent bridge, and Task 6's free-edge accounting will surface it
		# if it ever occurs in practice.
		var span_lo: float = INF
		var span_hi: float = -INF
		for vi: int in poly:
			span_lo = minf(span_lo, st.verts[vi].y)
			span_hi = maxf(span_hi, st.verts[vi].y)
		if span_hi - span_lo > CUT_JUMP + 0.5:
			var lvls: Array = []
			for k in 4:
				if wet_flags[k]:
					lvls.append(st.lvl[corners[k].y * (N + 1) + corners[k].x])
			lvls.sort()
			var clusters: int = 1
			for k in range(1, lvls.size()):
				if lvls[k] - lvls[k - 1] > CUT_JUMP:
					clusters += 1
			push_warning(
				"WaterMesher: %d-level cell at (%d,%d) — polygon spread %.1f dropped (multi-seam cell, see Task 5 review)"
				% [clusters, i, j, span_hi - span_lo])
			continue
		# Perimeter order is clockwise from above; reversed fan -> +Y (same
		# convention as _mesh_cell's general fan).
		for k in range(1, poly.size() - 1):
			st.idx.append(poly[0])
			st.idx.append(poly[k + 1])
			st.idx.append(poly[k])


## Which side of the jump a corner's own level puts it on.
## Cross-cell staircase note (Task 5 review adjudication): on a level
## staircase (3 -> 9 -> 15 across two adjacent cells) the shared 9-corner
## classifies HIGH in the 3|9 cell and LOW in the 9|15 cell. That is
## BENIGN: the corner vertex is welded at its OWN lattice level (9) and
## both cells emit surface at 9 around it — the low cell's top terrace
## and the high cell's bottom terrace. The no-weld-across-jump invariant
## is carried by the side-keyed "S:" cut verts, never by side labels on
## lattice corners.
## Single-cell limitation: wet corners spanning >= 3 level clusters
## (two seams crossing ONE cell) cannot 2-way split cleanly — one side
## groups two far-apart levels; _mesh_cut_cell's spread guard drops that
## polygon loudly instead of emitting a fold.
static func _lvl_side(st: Dictionary, cut: Dictionary, c: Vector2i) -> int:
	var lvl: float = st.lvl[c.y * (N + 1) + c.x]
	return 1 if absf(lvl - cut.top) <= absf(lvl - cut.bottom) else -1


## Local synthetic cut for a body seam with no recorded fall nearby: the
## split machinery needs top/bottom (the cell's own level extremes); p and
## dir (downhill gradient of the corner levels, high -> low) describe the
## local jump line for anything downstream that inspects the dict. Never
## registered into cut_records — no fall curtain is built at a body seam.
## top/bottom are the cell's EXTREMES: with >= 3 level clusters in one
## cell the middle level lands on whichever side it is nearer to and that
## side's polygon over-spreads — see _lvl_side's note and the spread
## guard in _mesh_cut_cell that degrades it loudly.
static func _synth_cut(st: Dictionary, i: int, j: int, corners: Array) -> Dictionary:
	var lo: float = INF
	var hi: float = -INF
	for c: Vector2i in corners:
		var l: float = st.lvl[c.y * (N + 1) + c.x]
		if l > -INF:
			lo = minf(lo, l)
			hi = maxf(hi, l)
	var mid: float = (hi + lo) * 0.5
	var centre := Vector2(float(i) + 0.5, float(j) + 0.5)
	var g := Vector2.ZERO
	for c: Vector2i in corners:
		var l: float = st.lvl[c.y * (N + 1) + c.x]
		if l == -INF:
			l = mid
		g += (Vector2(c) - centre) * (mid - l)   # high corners push away: high -> low
	var dirv: Vector2 = g.normalized() if g.length() > 0.001 else Vector2.RIGHT
	return {"p": st.base + centre * S, "dir": dirv,
		"across": Vector2(-dirv.y, dirv.x), "half": S * 2.0,
		"top": hi, "bottom": lo}


## Vertex where lattice edge a-b crosses the seam between two water
## levels, at `side`'s level. XZ: bisection on level_at from `side`'s own
## corner finds the true claim boundary — the recorded cut plane is only
## right within the channel; at the cut's lateral edge and at body seams
## the boundary is the claimants' own edge, so intersecting the plane
## would drop verts where that side's water does not exist. Y: the edge's
## own side level (== cut.top/bottom on the channel edges, where corners
## sit exactly at the cut levels). t is clamped off the corners so the
## vert never lands in a lattice vert's weld bucket. Real cuts (ci >= 0)
## register the vert into cut_hits for the lip/base records; synthetic
## seams (ci == -1) record nothing.
static func _cut_vert(st: Dictionary, ci: int, a: Vector2i, b: Vector2i, side: int) -> int:
	var key := "S:%d:%d:%d:%d:%d" % [side, mini(a.x, b.x), mini(a.y, b.y),
		absi(b.x - a.x), absi(b.y - a.y)]
	if st.weld.has(key):
		var vi_prev: int = st.weld[key]
		_register_cut_hit(st, ci, side, vi_prev)   # neighbour may be the real cut
		return vi_prev
	var la: float = st.lvl[a.y * (N + 1) + a.x]
	var lb: float = st.lvl[b.y * (N + 1) + b.x]
	var top_e: float = maxf(la, lb)
	var bot_e: float = minf(la, lb)
	var lvl: float = top_e if side == 1 else bot_e
	var other: float = bot_e if side == 1 else top_e
	var pa: Vector2 = st.base + Vector2(a) * S
	var pb: Vector2 = st.base + Vector2(b) * S
	if (side == 1) != (la >= lb):   # walk out from this side's own corner
		var tmp: Vector2 = pa
		pa = pb
		pb = tmp
	var lo: float = 0.0
	var hi: float = 1.0
	var t: float = 0.5
	for _pass in 20:
		if hi - lo < 0.0005:
			break
		var q: Vector2 = pa.lerp(pb, t)
		var l: float = WaterField.level_at(st.ctx, q)
		if l > -INF and absf(l - lvl) < absf(l - other):
			lo = t   # still on our side of the seam
		else:
			hi = t
		t = (lo + hi) * 0.5
	var p: Vector2 = pa.lerp(pb, clampf(lo, 0.03, 0.97))
	var vi: int = st.verts.size()
	st.verts.append(Vector3(p.x, lvl, p.y))
	st.weld[key] = vi
	_register_cut_hit(st, ci, side, vi)
	return vi


static func _register_cut_hit(st: Dictionary, ci: int, side: int, vi: int) -> void:
	if ci < 0:
		return
	if not st.cut_hits.has(ci):
		st.cut_hits[ci] = {"lip": [], "base": []}
	var arr: Array = st.cut_hits[ci]["lip" if side == 1 else "base"]
	if not arr.has(vi):
		arr.append(vi)


## True when the cell's corner levels jump more than CUT_JUMP — two water
## surfaces (a fall's lip/base, or two bodies at a seam) meet inside it.
static func _cell_jump(st: Dictionary, i: int, j: int) -> bool:
	var l00: float = st.lvl[j * (N + 1) + i]
	var l10: float = st.lvl[j * (N + 1) + i + 1]
	var l11: float = st.lvl[(j + 1) * (N + 1) + i + 1]
	var l01: float = st.lvl[(j + 1) * (N + 1) + i]
	var lo: float = INF
	var hi: float = -INF
	for l in [l00, l10, l11, l01]:
		if l > -INF:
			lo = minf(lo, l)
			hi = maxf(hi, l)
	return hi - lo > CUT_JUMP


## Index of a fall cut affecting this cell, or -1. A jumping cell only
## matches a cut when it sits near that cut's line — a level jump alone
## isn't enough (two unrelated bodies with different levels can claim
## adjacent lattice samples at a body seam, far from any fall; picking the
## "nearest" cut with no distance gate there would slice the cell along a
## cut plane that has nothing to do with the jump, corrupting both that
## geometry and the real cut's lip/base records — those cells get a
## synthetic seam split instead, see _mesh_cut_cell). Gate by the cut's
## own across-line half extent (channel half-width + feather) plus one
## lattice step of slack.
static func _cell_cut(st: Dictionary, i: int, j: int) -> int:
	if not _cell_jump(st, i, j):
		return -1
	var centre: Vector2 = st.base + Vector2(float(i) + 0.5, float(j) + 0.5) * S
	var best := -1
	var best_d := INF
	for ci in st.cuts.size():
		var cut: Dictionary = st.cuts[ci]
		var along: float = absf((centre - cut.p).dot(cut.dir))
		var across: float = absf((centre - cut.p).dot(cut.across))
		if along > S * 1.5 or across > cut.half + S * 1.5:
			continue
		if along < best_d:
			best_d = along
			best = ci
	return best


## One uniform edge rule replaces every legacy shore special case: each
## CONTOUR free edge (not chunk border, not a fall cut) extrudes a strip
## outward and down to ground - HEM_DROP, INSIDE the bank. Swells raise the
## surface; the waterline slides up the bank; the edge never lifts free.
## Synthetic seam edges (a claim-boundary split with no recorded fall) are
## NOT in st.cuts, so _near_cut does not exempt them: the upper side's hem
## folds down past the lower water and forms a small curtain face there —
## the best available look at a bodiless seam (Task 6 amendment note 1).
static func _hem(st: Dictionary) -> void:
	var span: float = TILE * 8.0
	var outer: Dictionary = {}   # inner vert index -> hem vert index
	for e_idx: Array in _free_edge_indices(st):
		var a: int = e_idx[0]
		var b: int = e_idx[1]
		var va: Vector3 = st.verts[a]
		var vb: Vector3 = st.verts[b]
		if _border2(st.base, span, va) and _border2(st.base, span, vb):
			continue
		if _near_cut(st, va) and _near_cut(st, vb):
			continue
		# Outward = away from the water: the free edge belongs to exactly one
		# triangle; its third vertex lies IN the water.
		var third: Vector3 = st.verts[_third_vert(st, a, b)]
		var edge2 := Vector2(vb.x - va.x, vb.z - va.z)
		var n2 := Vector2(-edge2.y, edge2.x).normalized()
		var to_third := Vector2(third.x - va.x, third.z - va.z)
		if n2.dot(to_third) > 0.0:
			n2 = -n2
		var ha: int = _hem_vert(st, outer, a, n2, span)
		var hb: int = _hem_vert(st, outer, b, n2, span)
		# Winding: _free_edge_indices now returns (a, b) in the directed order
		# the lone owning (+Y-wound) triangle actually walks it. Continuing
		# that same rotational sense onto the outward strip requires
		# [a, ha, hb] / [a, hb, b] here, NOT [a, b, hb] / [a, hb, ha] — the
		# latter comes out backwards (verified against test_all_triangles_wind_up).
		for t in [[a, ha, hb], [a, hb, b]]:
			for k in 3:
				st.idx.append(t[k])


## Two DIFFERENT source verts (different free edges) can project outward to
## nearly the same point — most often at a concave shore corner, where
## adjacent edges' outward normals converge. outer{} only dedupes by source
## index, which misses that; a second weld pass keyed on the rounded
## outward position (st.weld, shared with every other vert kind in this
## class) catches it so test_interior_is_welded's global no-duplicate
## invariant holds for hem verts too.
## A source vert already sitting ON the chunk border stays on it: an edge
## that runs nearly parallel to the border projects outward with a tiny
## along-border component (rounding, not a real crossing), which nudges the
## hem vert a few cm past the border line. Left alone that breaks the
## "both ends on the border" free-edge exemption for the hem quad's own
## side edge (border shore vert -> its hem vert) — clamp the projected
## coordinate back to the border so a border-anchored hem vert stays
## border-anchored, same as every other border vert in the sheet.
static func _hem_vert(st: Dictionary, outer: Dictionary, src: int, n2: Vector2, span: float) -> int:
	if outer.has(src):
		return outer[src]
	var v: Vector3 = st.verts[src]
	var p := Vector2(v.x, v.z) + n2 * HEM_W
	if absf(v.x - st.base.x) < 0.01:
		p.x = st.base.x
	elif absf(v.x - (st.base.x + span)) < 0.01:
		p.x = st.base.x + span
	if absf(v.z - st.base.y) < 0.01:
		p.y = st.base.y
	elif absf(v.z - (st.base.y + span)) < 0.01:
		p.y = st.base.y + span
	var g: float = TerrainSurfaceField.surface_y(st.region, p.x, p.y)
	var y: float = minf(v.y, g) - HEM_DROP
	var pos_key := "H:%d:%d:%d" % [roundi(p.x * 8.0), roundi(y * 8.0), roundi(p.y * 8.0)]
	if st.weld.has(pos_key):
		var vi_prev: int = st.weld[pos_key]
		outer[src] = vi_prev
		return vi_prev
	var vi: int = st.verts.size()
	st.verts.append(Vector3(p.x, y, p.y))
	st.weld[pos_key] = vi
	outer[src] = vi
	return vi


static func _border2(base: Vector2, span: float, v: Vector3) -> bool:
	var lx: float = v.x - base.x
	var lz: float = v.z - base.y
	return lx < 0.01 or lx > span - 0.01 or lz < 0.01 or lz > span - 0.01


static func _near_cut(st: Dictionary, v: Vector3) -> bool:
	for cut: Dictionary in st.cuts:
		if absf((Vector2(v.x, v.z) - cut.p).dot(cut.dir)) < S:
			return true
	return false


## free_edges but returning DIRECTED index pairs (in the winding order the
## lone owning triangle actually uses) plus a helper to find its third
## vertex. Directed order matters: the hem quad's own winding must match
## the sheet triangle it extends, or it comes out backwards (caught by
## test_all_triangles_wind_up) — undirected (min,max) keys lose that.
static func _free_edge_indices(st: Dictionary) -> Array:
	var count: Dictionary = {}
	var dir: Dictionary = {}   # undirected key -> last-seen directed [a, b]
	var tri: int = 0
	while tri < st.idx.size():
		for k in 3:
			var a: int = st.idx[tri + k]
			var b: int = st.idx[tri + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			count[key] = count.get(key, 0) + 1
			dir[key] = [a, b]
		tri += 3
	var out: Array = []
	for key: Vector2i in count:
		if count[key] == 1:
			out.append(dir[key])
	return out


static func _third_vert(st: Dictionary, a: int, b: int) -> int:
	var tri: int = 0
	while tri < st.idx.size():
		var tvs: Array = [st.idx[tri], st.idx[tri + 1], st.idx[tri + 2]]
		if a in tvs and b in tvs:
			for v: int in tvs:
				if v != a and v != b:
					return v
		tri += 3
	return a


static func _attributes(st: Dictionary) -> void:
	st["cust"] = PackedFloat32Array()
	st.cust.resize(st.verts.size() * 4)   # zeros until Task 7


## Edges used by exactly one triangle — the continuity oracle.
static func free_edges(verts: PackedVector3Array, idx: PackedInt32Array) -> Array:
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

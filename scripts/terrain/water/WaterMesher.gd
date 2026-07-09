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
	# Perimeter order is clockwise from above in Godot axes; the fan is
	# reversed so all sheet triangles wind +Y like the quad branch.
	for k in range(1, poly.size() - 1):   # fan
		st.idx.append(poly[0])
		st.idx.append(poly[k + 1])
		st.idx.append(poly[k])


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
		# Perimeter order is clockwise from above; reversed fan -> +Y (same
		# convention as _mesh_cell's general fan).
		for k in range(1, poly.size() - 1):
			st.idx.append(poly[0])
			st.idx.append(poly[k + 1])
			st.idx.append(poly[k])


## Which side of the jump a corner's own level puts it on.
static func _lvl_side(st: Dictionary, cut: Dictionary, c: Vector2i) -> int:
	var lvl: float = st.lvl[c.y * (N + 1) + c.x]
	return 1 if absf(lvl - cut.top) <= absf(lvl - cut.bottom) else -1


## Local synthetic cut for a body seam with no recorded fall nearby: the
## split machinery needs top/bottom (the cell's own level extremes); p and
## dir (downhill gradient of the corner levels, high -> low) describe the
## local jump line for anything downstream that inspects the dict. Never
## registered into cut_records — no fall curtain is built at a body seam.
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


static func _hem(_st: Dictionary) -> void:
	pass   # Task 6


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

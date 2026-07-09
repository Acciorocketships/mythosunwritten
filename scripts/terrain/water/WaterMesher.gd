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
	var c: Dictionary = WaterField.ctx(water, chunk)
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


## Task 3 handles only fully-wet, cut-free cells: one welded quad.
static func _mesh_cell(st: Dictionary, i: int, j: int) -> void:
	if not (_wet(st, i, j) and _wet(st, i + 1, j)
			and _wet(st, i + 1, j + 1) and _wet(st, i, j + 1)):
		return
	if _cell_cut(st, i, j) != -1:
		return   # Task 5
	var a: int = _lattice_vert(st, i, j)
	var b: int = _lattice_vert(st, i + 1, j)
	var cc: int = _lattice_vert(st, i + 1, j + 1)
	var d: int = _lattice_vert(st, i, j + 1)
	for t in [[a, d, cc], [a, cc, b]]:   # +Y winding matches the old sheet
		for k in 3:
			st.idx.append(t[k])


## Index of a fall cut affecting this cell, or -1. A cell is cut when any
## of its four edges jumps more than CUT_JUMP between wet samples.
static func _cell_cut(st: Dictionary, i: int, j: int) -> int:
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
	if hi - lo <= CUT_JUMP:
		return -1
	var centre: Vector2 = st.base + Vector2(float(i) + 0.5, float(j) + 0.5) * S
	var best := -1
	var best_d := INF
	for ci in st.cuts.size():
		var d: float = absf((centre - st.cuts[ci].p).dot(st.cuts[ci].dir))
		if d < best_d:
			best_d = d
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

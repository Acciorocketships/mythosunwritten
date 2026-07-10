# Boundary-conforming water sheet: marching squares over the 3m sub-grid on
# f(x,z) = level(x,z) - ground(x,z). Interior cells emit welded grid quads;
# boundary cells emit contour polygons whose edge vertices sit ON the
# waterline (Task 4); every contour free edge grows a buried hem (Task 6).
# Phase 2b: falls are no longer a discrete cut object split into two sheets —
# WaterField.profile() now shapes a continuous, monotone descent even across
# what used to be a fall (see WaterField.gd's own docstring), so every cell
# meshes through the ordinary _mesh_cell path; there is nothing left to
# detect or split (_cell_jump/_cell_cut/_mesh_cut_cell/_synth_cut/_lvl_side/
# _cut_vert/_register_cut_hit and the multi-seam spread guard they fed are
# all deleted — see this task's report). CUT_JUMP survives only as the
# vertical-span sanity bound test_no_triangle_bridges_a_fall (pinned
# SITE_CHUNK, which H1 confirmed has zero steep spans — so the strict bound
# there really does mean "this triangle should never span this far") and
# test_no_triangle_bridges_a_fall_except_legitimate_steep_terrain (a REAL
# steep chunk, seed 991177) still check, not as a splitting threshold. I-2
# (final-review-run2.md): a genuine storey cliff CAN legitimately produce a
# triangle span well past CUT_JUMP+0.5 (measured on real production
# terrain: up to ~7m) — the bound is not a universal "this can never happen"
# ceiling, only a bridging-bug detector for ORDINARY (non-cliff) terrain;
# the second test above independently re-verifies real ground truth (not
# WaterField.steep_spans' own channel-anchored bookkeeping — see that
# test's own docstring) before exempting a wide triangle.
class_name WaterMesher
extends Object

const TILE := 24.0
const N := 64                 # marching cells per chunk side
const S := 3.0                # sub-grid step (TILE * 8 cells / 64)
const EPS := 0.05
const CUT_JUMP := 2.0         # vertical-span sanity bound only (see file header) — no longer a split trigger
const HEM_DROP := 1.2
const HEM_W := 1.5
# Max |grade_at| a wet cell may carry and still get a swim volume. grade_at
# is a secant over one TRACE_STEP=12m river-trace segment (WaterField.gd);
# the legal ceiling for an ordinary (non-fall) reach is FALL_DROP_MIN/
# TRACE_STEP = 4.0/12.0 = 0.3333 — anything steeper is already classified a
# fall face by WaterField's own FALL_DROP_MIN rule, so no legitimate
# swimmable reach can secant above ~0.333. True fall faces plunge far
# harder, producing secants of ~0.5 or more. 0.45 sits between the two with
# margin on both sides: comfortably above the legal-reach ceiling (no
# swimmable water gets gated by accident) and comfortably below real fall
# secants (no fall face slips through and gets a volume).
const STEEP_UNSWIMMABLE := 0.45


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
		# steep_spans, NOT part of the returned dict (Phase 2b: no geometry
		# consumer left — FallMesher is deleted). Kept on st only so
		# _attributes can re-key its plunge-churn bake on it without
		# recomputing (see _attributes' own docstring).
		"steep": WaterField.steep_spans(c, Rect2(base, Vector2.ONE * TILE * 8.0)),
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
	# _hem runs LAST of the triangle emitters (nothing after it appends to
	# idx), so every triangle at index >= hem_start is hem geometry and
	# everything below is sheet geometry. Exposed in the returned dict: hem
	# faces are DELIBERATE near-vertical/downward folds, exempt from the
	# sheet invariants (+Y winding, no vertical span > CUT_JUMP) that the
	# tests enforce strictly on everything below the mark.
	var hem_start: int = st.idx.size()
	_hem(st)
	_attributes(st)   # CUSTOM0 (flow/shore/steep) + wet_cells (Task 7)
	return {"verts": st.verts, "idx": st.idx, "cust": st.cust,
		"wet_cells": st.get("wet_cells", {}), "hem_start": hem_start}


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
## perimeter-walk poly. _edge_vert legitimately returns a corner's own
## lattice vertex when a crossing snaps to it; left in place that
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


## One uniform edge rule replaces every legacy shore special case: each
## CONTOUR free edge (not chunk border) extrudes a strip outward and down to
## ground - HEM_DROP, INSIDE the bank. Swells raise the surface; the
## waterline slides up the bank; the edge never lifts free. Phase 2b: falls
## are an ordinary sheet + hem now (there is no cut left to exempt) — EVERY
## non-border free edge gets hemmed, including what used to be a fall's own
## lip/base line (_near_cut and its exemption are deleted; see the file
## header).
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


## CUSTOM0 per vertex: (flow.x, shore, flow.y, steep) — the water shader's
## existing contract. shore is 1.0 at/under the ground sample (the very
## shoreline) and fades over 1.2m of depth above it; steep is the level
## gradient scaled for a foam/turbulence read, clamped below the plunge
## band's own ceiling so the band (below) is always the strongest signal.
## Plunge band (Phase 2b: re-keyed on WaterField.steep_spans — `st.steep`,
## computed once in build() — instead of the retired cut records): within
## 3.5m of a real steep span's OWN BASE point (span.base_p — the span's
## plunge/landing end, not the lip; see steep_spans' own docstring on why
## `base_p` exists), steep and shore both ramp up over the last 2m of
## approach so the mesh alone hints at the drop before the shader's own
## continuous falling-look blend (water_unified.gdshader) takes over.
## Direction is measured from the LIP along `dir` (still the right axis: the
## channel run from lip to base), but the falloff distance itself is
## measured from the BASE, not the lip — a tall span's plunge band must not
## start 3.5m past the lip and never reach the base at all. Hem verts
## (emitted after every real vertex, see build()'s hem_start) fall through
## to the same per-vertex loop below and pick up shore = 1.0 from the
## v.y <= g branch, same as the brief's else-case.
static func _attributes(st: Dictionary) -> void:
	var cust := PackedFloat32Array()
	cust.resize(st.verts.size() * 4)
	for vi in st.verts.size():
		var v: Vector3 = st.verts[vi]
		var p := Vector2(v.x, v.z)
		var fl: Vector2 = WaterField.flow_at(st.ctx, p)
		var g: float = TerrainSurfaceField.surface_y(st.region, v.x, v.z)
		var shore: float = clampf(1.0 - (v.y - g) * 1.2, 0.0, 1.0) \
			if v.y > g - 0.5 else 1.0   # near/below ground = the very shoreline
		var steep: float = clampf(WaterField.grade_at(st.ctx, p) * 8.0, 0.0, 0.85)
		for span: Dictionary in st.steep:
			var along: float = (p - span.p).dot(span.dir)
			if absf((p - span.p).dot(span.across)) < span.half + S:
				var dist_from_base: float = (span.base_p - p).length()
				var w: float = clampf((3.5 - dist_from_base) / 2.0, 0.0, 1.0)
				if along > -0.5:   # only downstream of the lip, same as before
					steep = maxf(steep, w)
					shore = maxf(shore, 0.85 * w)
		cust[vi * 4 + 0] = fl.x
		cust[vi * 4 + 1] = shore
		cust[vi * 4 + 2] = fl.y
		cust[vi * 4 + 3] = steep
	st["cust"] = cust
	# wet_cells: swim-volume source data, keyed by 24m cell, value = ARRAY of
	# ONE surface entry (Phase 2b: the split/stacked-volume machinery is
	# deleted — falls are a continuous surface now, not two disjoint sheets
	# meeting at a cut, so there is no "upper surface over the plunge pool"
	# to guard against with a second stacked box; see this task's report).
	# AGGREGATED over the cell's full sub-grid (9x9 lattice samples, shared
	# edge rows included). gnd_lo is the MIN ground over the cell (half-cell
	# ramps dip well below the corner sample; the volume floor must reach the
	# ramp toe). STEEP GATE (Phase 2b, new): a cell whose max |grade_at| over
	# its own sub-grid exceeds STEEP_UNSWIMMABLE gets NO volume at all — a
	# steep fall face is not swimmable water (the owner's rule), so a
	# character must fall/slide through it rather than float. Only cells
	# OWNED by this chunk emit — border cells belong to the neighbour that
	# meshes them (same ownership rule as the retired _build_volumes).
	var wet_cells: Dictionary = {}
	var cell0 := Vector2i(int(roundf(st.base.x / TILE)), int(roundf(st.base.y / TILE)))
	for cz in 8:
		for cx in 8:
			var lo_i: int = cx * 8
			var lo_j: int = cz * 8
			var gnd_lo: float = INF
			var c_lvl: float = -INF   # level at the most central wet sample
			var c_i: int = 0
			var c_j: int = 0
			var c_d: int = 1 << 30
			var any_wet_cell := false
			var max_grade := 0.0
			for dj in 9:
				for di in 9:
					var i2: int = lo_i + di
					var j2: int = lo_j + dj
					var lvl: float = st.lvl[j2 * (N + 1) + i2]
					var g: float = st.gnd[j2 * (N + 1) + i2]
					gnd_lo = minf(gnd_lo, g)
					if lvl == -INF or lvl <= g + EPS:
						continue
					any_wet_cell = true
					var p2: Vector2 = st.base + Vector2(i2, j2) * S
					max_grade = maxf(max_grade, absf(WaterField.grade_at(st.ctx, p2)))
					var d2: int = (di - 4) * (di - 4) + (dj - 4) * (dj - 4)
					if d2 < c_d:
						c_d = d2
						c_lvl = lvl
						c_i = i2
						c_j = j2
			if not any_wet_cell:
				continue
			if max_grade > STEEP_UNSWIMMABLE:
				continue   # steep water: no volume, unswimmable by design
			var cell: Vector2i = cell0 + Vector2i(cx, cz)
			# LOCAL (one-subgrid-step, S=3m) finite difference — h-task-4 fix
			# (I4, "swim controls on dry-looking land"). WAS a 4*S=12m secant
			# from the central wet sample to a point near the cell's own edge:
			# a single LINEAR plane fit through those two points, then
			# extrapolated across the WHOLE 24m cell. WaterField.level_at is
			# NOT linear in general — profile()'s terrain-hugging descent
			# (WaterField.gd) is flat over a pond/reach's own level, then rises
			# through a kink toward a neighbouring reach (see this task's
			# report for the measured curve: flat 3.00 for 10+m, then 3.00 ->
			# 4.35 -> 5.70 over the final 6m to the cell edge) — a 12m secant
			# through that shape draws a straight line whose slope is a
			# blend of "mostly flat" and "steep near the edge", so the line
			# UNDERSHOOTS near the flat interior (a real depth read as
			# shallower than it is — safe direction, merely conservative) but
			# OVERSHOOTS just past the kink (shallow/wading water read as
			# confidently swimmable — the actual I4 defect: verified this
			# task, (36.0,-1107.0) true depth 0.76m/wading vs the old 12m
			# plane's 1.44m/swimming, one cell-row from the owner's own
			# (36.4,3.2,-1108.7)). A first-order (LOCAL) derivative estimate
			# is the mathematically sound thing to extrapolate a plane from —
			# trustworthy only near its own sample point, which is exactly
			# what "one plane per 24m cell, anchored at the most-central wet
			# sample" needs. Re-verified (this task): with this S-baseline,
			# EVERY wet_cells-covered subgrid sample on the pinned site (1472
			# samples) reads a depth class (dry/wading/swim, character.gd's
			# own ENTER thresholds) no wetter than WaterField.level_at's own
			# truth at that point — zero classification violations, versus 8
			# wade->swim violations with the old 12m baseline (this task's
			# own red oracle, test_no_dry_pocket_below_adjacent_water_level).
			# Every non-flat wet_cells entry on this seed shares the same
			# flat-then-kink shape (verified: the OTHER two non-flat cells,
			# (1,-46)/(1,-45), profile identically), so there is no known
			# "genuinely smoothly-sloped" cell on this site whose hint this
			# regresses; grad simply reads (0,0) there now (flat near the
			# centre sample, same as any other flat cell) rather than a
			# secant that lied about the far side of a kink it never saw.
			var pr: Vector2 = st.base + Vector2(c_i + 1, c_j) * S
			var pd: Vector2 = st.base + Vector2(c_i, c_j + 1) * S
			var gx: float = (WaterField.level_at(st.ctx, pr) - c_lvl) / S
			var gz: float = (WaterField.level_at(st.ctx, pd) - c_lvl) / S
			wet_cells[cell] = [{"lvl": c_lvl,
				"grad": Vector2(gx if absf(gx) < 1.0 else 0.0, gz if absf(gz) < 1.0 else 0.0),
				"gnd_lo": gnd_lo}]
	st["wet_cells"] = wet_cells


## Assembles the committed ArrayMesh: positions/indices from build(), UP
## normals (the water shader computes its own from the flow/steep custom
## attributes, not from mesh geometry), and CUSTOM0 as RGBA float carrying
## (flow.x, shore, flow.y, steep) per _attributes' layout above.
static func commit(m: Dictionary) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = m.verts
	arrays[Mesh.ARRAY_INDEX] = m.idx
	var normals := PackedVector3Array()
	normals.resize(m.verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_CUSTOM0] = m.cust
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh


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

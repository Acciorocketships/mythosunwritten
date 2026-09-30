# scripts/terrain/field/TerrainTileField.gd
# Dual-grid terrain tiles (docs/superpowers/specs/2026-09-30-dual-grid-terrain-tiles-design.md).
#
# Heights live on lattice POINTS 12 m apart (region.surface_height(i, j) /
# storey_at(i, j)). Each 12 m tile between four points is a function of its
# four corner heights alone:
#
#   height = t0 + sum over the gaps [t(n-1), t(n)] of gap * layer_n(u, v)
#
# where t0 < t1 < ... are the corners' distinct heights and layer_n sees a
# BINARY tile (corner bit = height >= t(n)). A layer's crossing on a tile edge
# is a SLOPE (the two endpoints are at most one storey apart) or a CLIFF (two
# or more storeys). Slopes use the smootherstep profile across the whole
# tile; cliffs step at the tile midline, so every wall lies on the border of
# the 12 m "dual cell" around a lattice point. A saddle keeps its two high
# corners as separate bumps. Where a layer mixes cliff and slope crossings
# (a cliff end) the rule is `cliff_end` (E2 by default: wall to the tile
# centre, then a ramp that fans out to the slope profile at the slope edge).
#
# Along any tile edge the surface depends only on that edge's two endpoints,
# so neighbouring tiles agree by construction; walls are the only
# double-valued places, and both owners agree where they are.
class_name TerrainTileField
extends RefCounted

const SPACING := 12.0
const STOREY := 4.0

enum EdgeCategory { FLAT, LEVEL, SLOPE, CLIFF }
## E1: blend slope and cliff layers inside the tile (the wall shortens across
## one tile, the high side dips). E2: the wall runs to the tile centre, then
## a compact ramp fans out to the slope profile (no dip).
enum CliffEnd { E1, E2 }
static var cliff_end: int = CliffEnd.E2

const _CARDINALS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func spacing(region = null) -> float:
	if region != null and region.has_method("terrain_tile_size"):
		var value: float = region.terrain_tile_size()
		assert(is_finite(value) and value > 0.0)
		return value
	return SPACING


## Index of the lattice point whose dual cell contains coordinate v. The
## midline v = 12 (i + 1/2) belongs to point i + 1 for every i (floor, not
## round-half-away), matching tile_y's rule that the u > 0.5 corner owns it.
static func point_of(v: float, region = null) -> int:
	return floori(v / spacing(region) + 0.5)


# --- edges ------------------------------------------------------------------

static func edge_category(region, p: Vector2i, d: Vector2i) -> int:
	var q := p + d
	var ds := absi(int(region.storey_at(p.x, p.y)) - int(region.storey_at(q.x, q.y)))
	if ds >= 2:
		return EdgeCategory.CLIFF
	if ds == 1:
		return EdgeCategory.SLOPE
	if is_equal_approx(float(region.surface_height(p.x, p.y)), float(region.surface_height(q.x, q.y))):
		return EdgeCategory.FLAT
	return EdgeCategory.LEVEL


static func is_cliff_edge(region, p: Vector2i, d: Vector2i) -> bool:
	return absi(int(region.storey_at(p.x, p.y)) - int(region.storey_at(p.x + d.x, p.y + d.y))) >= 2


## The HIGH side of a cliff edge: the edges that carry a vertical rock face.
static func is_wall_edge(region, p: Vector2i, d: Vector2i) -> bool:
	return int(region.storey_at(p.x, p.y)) - int(region.storey_at(p.x + d.x, p.y + d.y)) >= 2


## Walkability of a lattice edge is exactly "not a cliff edge".
static func is_walkable_edge(region, p: Vector2i, d: Vector2i) -> bool:
	assert(absi(d.x) + absi(d.y) == 1, "walkability requires a cardinal unit direction")
	return not is_cliff_edge(region, p, d)


# --- the tile function -------------------------------------------------------

## Tile parameters: corner heights a(0,0) b(1,0) c(1,1) d(0,1) and cliff flags
## for the edges bottom (a-b), right (b-c), top (d-c), left (a-d).
static func tile_params(region, tile: Vector2i) -> PackedFloat32Array:
	var i := tile.x
	var j := tile.y
	var out := PackedFloat32Array()
	out.resize(8)
	out[0] = region.surface_height(i, j)
	out[1] = region.surface_height(i + 1, j)
	out[2] = region.surface_height(i + 1, j + 1)
	out[3] = region.surface_height(i, j + 1)
	out[4] = 1.0 if is_cliff_edge(region, Vector2i(i, j), Vector2i(1, 0)) else 0.0
	out[5] = 1.0 if is_cliff_edge(region, Vector2i(i + 1, j), Vector2i(0, 1)) else 0.0
	out[6] = 1.0 if is_cliff_edge(region, Vector2i(i, j + 1), Vector2i(1, 0)) else 0.0
	out[7] = 1.0 if is_cliff_edge(region, Vector2i(i, j), Vector2i(0, 1)) else 0.0
	return out


## Height on tile `tile` at local (u, v) in [0,1]. `side` breaks the tie on a
## wall exactly at a midline: side.x = -1 resolves u == 0.5 to the low-u
## corners, +1 to the high-u corners (likewise side.y for v); 0 = high side
## rule (the u > 0.5 corner owns the midline).
static func tile_y(region, tile: Vector2i, u: float, v: float, side := Vector2i.ZERO) -> float:
	return _apply_grade(region, (float(tile.x) + u) * spacing(region), (float(tile.y) + v) * spacing(region),
		eval_params(tile_params(region, tile), u, v, side))


## `o` is the offset of the 8-value tile block inside `p` (sample_baked passes
## its per-point bake directly; no slice per call). This is the mesher's hot
## path: no Array literals.
static func eval_params(p: PackedFloat32Array, u: float, v: float, side := Vector2i.ZERO, o := 0) -> float:
	var h0 := p[o]
	var h1 := p[o + 1]
	var h2 := p[o + 2]
	var h3 := p[o + 3]
	var lo := minf(minf(h0, h1), minf(h2, h3))
	var hi := maxf(maxf(h0, h1), maxf(h2, h3))
	if hi - lo <= 0.0:
		return lo
	var cb := p[o + 4]
	var cr := p[o + 5]
	var ct := p[o + 6]
	var cl := p[o + 7]
	# Fast path: every crossing a slope and no saddle -> the bilinear smootherstep
	# patch (bilinear is linear in the corner values, so the layers collapse).
	if cb + cr + ct + cl == 0.0 and not _has_saddle_layer(h0, h1, h2, h3):
		var su := SlopeProfile.smootherstep(u)
		var sv := SlopeProfile.smootherstep(v)
		return lerpf(lerpf(h0, h1, su), lerpf(h3, h2, su), sv)
	var result := lo
	var prev := lo
	while true:
		var t := INF
		if h0 > prev and h0 < t:
			t = h0
		if h1 > prev and h1 < t:
			t = h1
		if h2 > prev and h2 < t:
			t = h2
		if h3 > prev and h3 < t:
			t = h3
		if t == INF:
			break
		result += (t - prev) * _layer(h0 >= t, h1 >= t, h2 >= t, h3 >= t, cb, cr, ct, cl, u, v, side)
		prev = t
	return result


# Only the middle distinct value(s) can form a saddle layer; one check covers all.
static func _has_saddle_layer(h0: float, h1: float, h2: float, h3: float) -> bool:
	return _saddle_at(h0, h1, h2, h3, h0) or _saddle_at(h0, h1, h2, h3, h1) \
		or _saddle_at(h0, h1, h2, h3, h2) or _saddle_at(h0, h1, h2, h3, h3)


static func _saddle_at(h0: float, h1: float, h2: float, h3: float, t: float) -> bool:
	var b0 := h0 >= t
	var b1 := h1 >= t
	return b0 != b1 and b0 == (h2 >= t) and b1 == (h3 >= t)


static func _layer(ba: bool, bb: bool, bc: bool, bd: bool,
		cb: float, cr: float, ct: float, cl: float,
		u: float, v: float, side: Vector2i) -> float:
	# A layer's value on an edge it does not cross is constant, so a non-crossing
	# edge is a slope end (k = 0) ONLY in a mixed layer, where it lets the wall
	# fade to the slope profile. When every crossing of the layer is a cliff
	# (k = 1) there is nothing to fade to: the non-crossing edges are cliff ends
	# too, which keeps a pure-cliff layer a clean step (exact quadrants).
	var xb := ba != bb
	var xt := bd != bc
	var xl := ba != bd
	var xr := bb != bc
	var any_slope := (xb and cb < 1.0) or (xt and ct < 1.0) or (xl and cl < 1.0) or (xr and cr < 1.0)
	var idle := 0.0 if any_slope else 1.0
	var kb := cb if xb else idle
	var kt := ct if xt else idle
	var kl := cl if xl else idle
	var kr := cr if xr else idle
	var pu := _profile(u, kb, kt, v, side.x)
	var pv := _profile(v, kl, kr, u, side.y)
	var a := 1.0 if ba else 0.0
	var b := 1.0 if bb else 0.0
	var c := 1.0 if bc else 0.0
	var d := 1.0 if bd else 0.0
	if ba == bc and bb == bd and ba != bb:
		# Saddle: the low diagonal connects, the two high corners are separate bumps.
		if ba:
			return maxf((1.0 - pu) * (1.0 - pv), pu * pv)
		return maxf(pu * (1.0 - pv), (1.0 - pu) * pv)
	return lerpf(lerpf(a, b, pu), lerpf(d, c, pu), pv)


## Profile of one direction's crossing at coordinate t, given the cliff weight
## k0 of the crossing edge at s = 0 and k1 at s = 1 (s = transverse coordinate).
static func _profile(t: float, k0: float, k1: float, s: float, side: int) -> float:
	if cliff_end == CliffEnd.E1:
		var k := lerpf(k0, k1, s)
		return lerpf(SlopeProfile.smootherstep(t), _step(t, side), k)
	var w: float
	if k0 == k1:
		w = 1.0 - k0
	elif k0 > k1:   # cliff at s = 0: wall to the centre, then fan out
		w = 0.0 if s <= 0.5 else SlopeProfile.smootherstep((s - 0.5) * 2.0)
	else:
		w = 0.0 if s >= 0.5 else SlopeProfile.smootherstep((0.5 - s) * 2.0)
	if w <= 0.0:
		return _step(t, side)
	return SlopeProfile.smootherstep((t - 0.5) / w + 0.5)


static func _step(t: float, side: int) -> float:
	if t > 0.5:
		return 1.0
	if t < 0.5:
		return 0.0
	return 0.0 if side < 0 else 1.0


# --- world-space sampling ------------------------------------------------------

static func surface_y(region, x: float, z: float) -> float:
	return surface_y_on_side(region, x, z, Vector2i(point_of(x, region), point_of(z, region)))


## Height at (x, z) as seen from lattice point `owner`: the position is clamped
## into the owner's dual cell and a wall on its border resolves to the owner's
## side. Inside the owner's dual cell away from walls this is surface_y.
## Grading is applied at the UNCLAMPED (x, z) on purpose: the grade patch is a
## world-space field, only the tile shape is resolved on the owner's side.
static func surface_y_on_side(region, x: float, z: float, owner: Vector2i) -> float:
	var s := spacing(region)
	var cx := float(owner.x) * s
	var cz := float(owner.y) * s
	var lx := clampf(x, cx - s * 0.5, cx + s * 0.5)
	var lz := clampf(z, cz - s * 0.5, cz + s * 0.5)
	var ti := owner.x if lx >= cx else owner.x - 1
	var tj := owner.y if lz >= cz else owner.y - 1
	var side := Vector2i(-1 if ti == owner.x else 1, -1 if tj == owner.y else 1)
	var u := (lx - float(ti) * s) / s
	var v := (lz - float(tj) * s) / s
	return _apply_grade(region, x, z, eval_params(tile_params(region, Vector2i(ti, tj)), u, v, side))


static func _apply_grade(region, x: float, z: float, height: float) -> float:
	return region.graded_height(x, z, height) \
		if region != null and region.has_method("graded_height") else height


# --- per-point bake ------------------------------------------------------------
# The mesher samples ~37k points per chunk. bake_point gathers the four
# quadrant tiles of one dual cell once; sample_baked is then float math.
# Layout: [0] flat flag, [1] point height, then 4 quadrant blocks of 8 floats
# (tile_params) in order (-x,-z), (+x,-z), (-x,+z), (+x,+z).

static func bake_point(region, p: Vector2i) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(34)
	var h: float = region.surface_height(p.x, p.y)
	out[1] = h
	var flat := true
	for q in 4:
		var tile := Vector2i(p.x - 1 + (q & 1), p.y - 1 + (q >> 1))
		var params := tile_params(region, tile)
		for k in 8:
			out[2 + q * 8 + k] = params[k]
		for k in 4:
			flat = flat and params[k] == h
	out[0] = 1.0 if flat else 0.0
	return out


## Grading uses the unclamped (x, z), like surface_y_on_side (world-space field).
static func sample_baked(baked: PackedFloat32Array, p: Vector2i, x: float, z: float, region = null) -> float:
	if baked[0] > 0.5:
		return _apply_grade(region, x, z, baked[1])
	var s := spacing(region)
	var cx := float(p.x) * s
	var cz := float(p.y) * s
	var lx := clampf(x, cx - s * 0.5, cx + s * 0.5)
	var lz := clampf(z, cz - s * 0.5, cz + s * 0.5)
	var qx := 1 if lx >= cx else 0
	var qz := 1 if lz >= cz else 0
	var ti := p.x - 1 + qx
	var tj := p.y - 1 + qz
	var side := Vector2i(-1 if qx == 1 else 1, -1 if qz == 1 else 1)
	return _apply_grade(region, x, z, eval_params(baked, (lx - float(ti) * s) / s,
		(lz - float(tj) * s) / s, side, 2 + (qz * 2 + qx) * 8))


# --- walls -----------------------------------------------------------------------

## Exact wall outline intersecting `rect`: one entry per 6 m half-segment of a
## dual-cell border where the two owners' surfaces differ. Each entry names the
## segment ends `a`/`b`, the owners `high`/`low`, the owners' heights at the
## ends as `top` (high side) / `bottom` (low side), and `normal`, the unit
## horizontal direction from the high owner toward the low owner. `high` is
## decided from the SUMMED samples along the half-segment (both ends and the
## middle), so under E1 it can disagree with the higher lattice endpoint.
static func wall_segments(region, rect: Rect2) -> Array[Dictionary]:
	var s := spacing(region)
	var out: Array[Dictionary] = []
	var i0 := floori(rect.position.x / s) - 1
	var i1 := ceili(rect.end.x / s) + 1
	var j0 := floori(rect.position.y / s) - 1
	var j1 := ceili(rect.end.y / s) + 1
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := Vector2i(i, j)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var q := p + d
				var mid := (Vector2(p) + Vector2(d) * 0.5) * s
				var along := Vector2(-d.y, d.x) * s * 0.5
				for pair: Array in [[mid - along, mid], [mid, mid + along]]:
					var a: Vector2 = pair[0]
					var b: Vector2 = pair[1]
					var seg := Rect2(a, Vector2.ZERO).expand(b)
					if not seg.intersects(rect, true):
						continue
					var inset := (b - a) * 0.001
					var pa := surface_y_on_side(region, a.x + inset.x, a.y + inset.y, p)
					var pb := surface_y_on_side(region, b.x - inset.x, b.y - inset.y, p)
					var qa := surface_y_on_side(region, a.x + inset.x, a.y + inset.y, q)
					var qb := surface_y_on_side(region, b.x - inset.x, b.y - inset.y, q)
					var mid_p := surface_y_on_side(region, (a.x + b.x) * 0.5, (a.y + b.y) * 0.5, p)
					var mid_q := surface_y_on_side(region, (a.x + b.x) * 0.5, (a.y + b.y) * 0.5, q)
					if maxf(maxf(absf(pa - qa), absf(pb - qb)), absf(mid_p - mid_q)) <= 0.001:
						continue
					var p_high := (pa + pb + mid_p) >= (qa + qb + mid_q)
					out.append({
						"a": a, "b": b,
						"high": p if p_high else q, "low": q if p_high else p,
						"top": Vector2(pa, pb) if p_high else Vector2(qa, qb),
						"bottom": Vector2(qa, qb) if p_high else Vector2(pa, pb),
						"normal": Vector2(d) if p_high else -Vector2(d),
					})
	return out


# --- bounds ------------------------------------------------------------------------

## Conservative [min, max] of the surface over a world rectangle. Exact on
## flat, slope-only and pure-cliff tiles; a mixed layer contributes its full
## [0, 1] range. Property 4 (a tile stays within its corners) makes this safe.
static func height_bounds(region, footprint: Rect2) -> Vector2:
	assert(not region.has_method("graded_height") or region.has_method("graded_height_bounds"),
		"a region that grades heights must also bound them (graded_height_bounds)")
	var natural := _natural_height_bounds(region, footprint)
	if region.has_method("graded_height_bounds"):
		return region.graded_height_bounds(footprint, natural)
	return natural


static func _natural_height_bounds(region, footprint: Rect2) -> Vector2:
	assert(footprint.size.x >= 0.0 and footprint.size.y >= 0.0)
	var s := spacing(region)
	var minimum := INF
	var maximum := -INF
	for tj in range(floori(footprint.position.y / s), floori(footprint.end.y / s) + 1):
		var v0 := clampf(footprint.position.y / s - float(tj), 0.0, 1.0)
		var v1 := clampf(footprint.end.y / s - float(tj), 0.0, 1.0)
		for ti in range(floori(footprint.position.x / s), floori(footprint.end.x / s) + 1):
			var u0 := clampf(footprint.position.x / s - float(ti), 0.0, 1.0)
			var u1 := clampf(footprint.end.x / s - float(ti), 0.0, 1.0)
			var b := _tile_bounds(tile_params(region, Vector2i(ti, tj)), u0, u1, v0, v1)
			minimum = minf(minimum, b.x)
			maximum = maxf(maximum, b.y)
	assert(minimum != INF)
	return Vector2(minimum, maximum)


## Like height_bounds, but for the surface as owned by lattice point `owner`:
## `footprint` must lie inside the owner's dual cell, and a wall on the cell's
## border contributes only the owner's side (no second, neighbouring top).
## Exact on flat, slope-only and pure-cliff tiles; a mixed layer contributes the
## tile's full corner range (conservative, like height_bounds).
static func height_bounds_on_side(region, footprint: Rect2, owner: Vector2i) -> Vector2:
	assert(not region.has_method("graded_height") or region.has_method("graded_height_bounds"),
		"a region that grades heights must also bound them (graded_height_bounds)")
	assert(footprint.size.x >= 0.0 and footprint.size.y >= 0.0)
	var s := spacing(region)
	var cell := Rect2(Vector2(owner) * s - Vector2.ONE * s * 0.5, Vector2.ONE * s)
	assert(cell.encloses(footprint), "the footprint must lie inside the owner's dual cell")
	var minimum := INF
	var maximum := -INF
	for qz in 2:
		for qx in 2:
			# Quadrant (qx, qz) of the dual cell is the owner's corner of tile (owner - 1 + q).
			var quad := Rect2(Vector2(float(owner.x) * s - (0.0 if qx == 1 else s * 0.5),
				float(owner.y) * s - (0.0 if qz == 1 else s * 0.5)), Vector2.ONE * s * 0.5)
			if quad.position.x > footprint.end.x or quad.end.x < footprint.position.x \
					or quad.position.y > footprint.end.y or quad.end.y < footprint.position.y:
				continue
			var lo_x := maxf(footprint.position.x, quad.position.x)
			var hi_x := minf(footprint.end.x, quad.end.x)
			var lo_z := maxf(footprint.position.y, quad.position.y)
			var hi_z := minf(footprint.end.y, quad.end.y)
			var tile := Vector2i(owner.x - 1 + qx, owner.y - 1 + qz)
			var side := Vector2i(-1 if qx == 1 else 1, -1 if qz == 1 else 1)
			var b := _tile_bounds(tile_params(region, tile),
				lo_x / s - float(tile.x), hi_x / s - float(tile.x),
				lo_z / s - float(tile.y), hi_z / s - float(tile.y), side)
			minimum = minf(minimum, b.x)
			maximum = maxf(maximum, b.y)
	assert(minimum != INF)
	var natural := Vector2(minimum, maximum)
	if region.has_method("graded_height_bounds"):
		return region.graded_height_bounds(footprint, natural)
	return natural


## `side` (non-zero) names the owner whose quadrant a pure-cliff tile reports;
## ZERO takes every quadrant the rectangle touches.
static func _tile_bounds(p: PackedFloat32Array, u0: float, u1: float, v0: float, v1: float,
		side := Vector2i.ZERO) -> Vector2:
	var h := [p[0], p[1], p[2], p[3]]
	var lo: float = h.min()
	var hi: float = h.max()
	if hi <= lo:
		return Vector2(lo, lo)
	var slope_only := p[4] + p[5] + p[6] + p[7] == 0.0
	var cliff_only := true
	# A pure-cliff tile: every crossing edge is a cliff (non-crossing edges are
	# flat, which never mixes a slope in).
	for e in 4:
		var ha: float = h[[0, 1, 3, 0][e]]
		var hb: float = h[[1, 2, 2, 3][e]]
		if ha != hb and p[4 + e] == 0.0:
			cliff_only = false
	if slope_only and not _has_saddle_layer(p[0], p[1], p[2], p[3]):
		# Bilinear in monotone smootherstep coordinates: extrema at the clipped corners.
		var out := Vector2(INF, -INF)
		for uv: Vector2 in [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]:
			var y := eval_params(p, uv.x, uv.y)
			out = Vector2(minf(out.x, y), maxf(out.y, y))
		return out
	if cliff_only and side != Vector2i.ZERO:
		# One owner's quadrant: flat at that corner's height.
		var corner: int = [[0, 3], [1, 2]][1 if side.x > 0 else 0][1 if side.y > 0 else 0]
		return Vector2(h[corner], h[corner])
	if cliff_only:
		# Each quadrant is flat at its own corner's height.
		var out := Vector2(INF, -INF)
		var qs := [[0, u0 <= 0.5, v0 <= 0.5], [1, u1 >= 0.5, v0 <= 0.5],
			[2, u1 >= 0.5, v1 >= 0.5], [3, u0 <= 0.5, v1 >= 0.5]]
		for q: Array in qs:
			if q[1] and q[2]:
				out = Vector2(minf(out.x, h[q[0]]), maxf(out.y, h[q[0]]))
		return out
	return Vector2(lo, hi)

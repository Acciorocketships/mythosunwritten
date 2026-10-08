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
# the 12 m "dual cell" around a lattice point. A layer with one high (or one
# low) corner is the product of its two crossings' own edge profiles, and a
# saddle is the sum of its two corner shapes (for slopes, the smooth bilinear
# saddle), so every tile only rises or only falls along each axis: no divots
# (owner review 2026-10-04). Where a tile's one cliff edge ends beside a slope
# the rule is `cliff_end` (E3 by default: a full wall to the tile centre, a
# vertical end face on the centre line, then exactly the slope tile; tiles
# where walls turn a corner beside slopes keep E2).
#
# Along any tile edge the surface depends only on that edge's two endpoints,
# so neighbouring tiles agree by construction; walls are the only
# double-valued places, and both owners agree where they are.
class_name TerrainTileField
extends RefCounted

const NATIVE_TILE := preload("res://scripts/native/NativeTileKernel.gd")
const SPACING := 12.0
const STOREY := 4.0
## A neighbour surface this far below a point's flat top exposes the border.
const EXPOSE_EPS := 0.25

enum EdgeCategory { FLAT, LEVEL, SLOPE, CLIFF }
## E1: blend slope and cliff layers inside the tile (the wall shortens across
## one tile, the high side dips). E2: the wall runs at full height to the tile
## centre, then shortens to nothing 2.4 m before the slope edge (the
## same blend as E1, confined to that stretch; owner review October 1: the former E2 fan,
## centimetres wide beside the wall's end, cut a V-notch into the plateau).
## E3: the wall runs at full height to the tile centre and ends there in a
## vertical end face on the centre line (a dual-cell border, like every wall);
## beyond it the layer is the plain slope. No wall shortens over a ramp, so
## there is no fan, crease or scoop at a cliff's end (owner review October 4,
## second photo: the E2 ramp read as a dark dent).
enum CliffEnd { E1, E2, E3 }
## Under E2 the last fifth of the tile (2.4 m) before the slope edge carries no
## wall at all: a road crossing that slope edge (4 m wide, on the lattice line)
## never meets a step (test_september13_world_paths).
const CLIFF_END_CLEAR := 0.2
static var cliff_end: int = CliffEnd.E3

const _CARDINALS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func spacing(region = null) -> float:
	# HeightfieldRegion answers HeightfieldPlan.POINT; the type test spares the
	# hot sampling paths a method lookup by name.
	if region is HeightfieldRegion:
		return HeightfieldPlan.POINT
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


## One physical transition profile for natural slopes and sealed ground edits:
## a smootherstep over `width`, by default one whole tile (12 m).
static func transition_weight(distance: float, width: float = SPACING) -> float:
	return SlopeProfile.smootherstep(clampf(distance / width, 0.0, 1.0))


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
	# The four edges' cliff flags (is_cliff_edge) from the corners' storeys.
	var sa := int(region.storey_at(i, j))
	var sb := int(region.storey_at(i + 1, j))
	var sc := int(region.storey_at(i + 1, j + 1))
	var sd := int(region.storey_at(i, j + 1))
	out[4] = 1.0 if absi(sa - sb) >= 2 else 0.0
	out[5] = 1.0 if absi(sb - sc) >= 2 else 0.0
	out[6] = 1.0 if absi(sd - sc) >= 2 else 0.0
	out[7] = 1.0 if absi(sa - sd) >= 2 else 0.0
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
static func eval_params(p: PackedFloat32Array, u: float, v: float, side := Vector2i.ZERO, o := 0, mode := -1) -> float:
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
	# Fast path: every crossing a slope -> the bilinear smootherstep patch
	# (every layer is bilinear in the same profiles, so the layers collapse).
	if cb + cr + ct + cl == 0.0:
		var su := SlopeProfile.smootherstep(u)
		var sv := SlopeProfile.smootherstep(v)
		return lerpf(lerpf(h0, h1, su), lerpf(h3, h2, su), sv)
	var end_mode := cliff_end if mode < 0 else mode
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
		result += (t - prev) * _layer(h0 >= t, h1 >= t, h2 >= t, h3 >= t, cb, cr, ct, cl, u, v, side, end_mode)
		prev = t
	return result


static func _layer(ba: bool, bb: bool, bc: bool, bd: bool,
		cb: float, cr: float, ct: float, cl: float,
		u: float, v: float, side: Vector2i, mode: int) -> float:
	var highs := int(ba) + int(bb) + int(bc) + int(bd)
	# E3 ends a cliff cleanly only where it truly ends: the tile's one cliff
	# edge. Where walls turn a corner beside slopes the tile keeps the E2 rule
	# (a clean end there left a trough at the foot of the turning wall).
	var ends := mode == CliffEnd.E3 and int(cb >= 1.0) + int(cr >= 1.0) + int(ct >= 1.0) + int(cl >= 1.0) == 1
	if highs != 2 or ba == bc:
		# One high corner, one low corner or a saddle is built from CORNER
		# shapes: a corner's shape is the product of its two crossings' profiles
		# (_corner_profile), so it only falls away from the corner along both
		# axes. One high corner is its shape; one low corner the complement of
		# its shape; a saddle is the plateau with both low corners carved out.
		# Every edge reproduces its crossing exactly and no row or column dips
		# (owner review 2026-10-04: the former saddle, max(bump_a, bump_c),
		# sagged between the bumps, and a cliff weight varied across the whole
		# tile undercut the slope beside a wall's end).
		var mixed := ((ba != bb) and cb < 1.0) or ((bd != bc) and ct < 1.0) \
			or ((ba != bd) and cl < 1.0) or ((bb != bc) and cr < 1.0)
		var corners := [
			(1.0 - _corner_profile(u, cb, v, 0.0, mixed, side.x, side.y, ends, mode)) * (1.0 - _corner_profile(v, cl, u, 0.0, mixed, side.y, side.x, ends, mode)),
			_corner_profile(u, cb, v, 1.0, mixed, side.x, side.y, ends, mode) * (1.0 - _corner_profile(v, cr, 1.0 - u, 0.0, mixed, side.y, -side.x, ends, mode)),
			_corner_profile(u, ct, 1.0 - v, 1.0, mixed, side.x, -side.y, ends, mode) * _corner_profile(v, cr, 1.0 - u, 1.0, mixed, side.y, -side.x, ends, mode),
			(1.0 - _corner_profile(u, ct, 1.0 - v, 0.0, mixed, side.x, -side.y, ends, mode)) * _corner_profile(v, cl, u, 1.0, mixed, side.y, side.x, ends, mode)]
		var bits := [ba, bb, bc, bd]
		if highs == 1:
			return corners[bits.find(true)]
		var plateau := 1.0
		for k in 4:
			if not bits[k]:
				plateau *= 1.0 - float(corners[k])
		return plateau
	# Two adjacent high corners: one straight pair of crossings.
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
	var pu := _profile(u, kb, kt, v, side.x, side.y, ends, mode)
	var pv := _profile(v, kl, kr, u, side.y, side.x, ends, mode)
	var a := 1.0 if ba else 0.0
	var b := 1.0 if bb else 0.0
	var c := 1.0 if bc else 0.0
	var d := 1.0 if bd else 0.0
	return lerpf(lerpf(a, b, pu), lerpf(d, c, pu), pv)


## A crossing's profile inside one CORNER shape: t runs across the crossing,
## the corner lies at t = corner_t (0 or 1), s is the distance from the
## crossing's own edge (0) toward the opposite edge (1), where the corner's
## other factor vanishes. A slope is the smootherstep; a cliff in a pure-cliff
## layer is the full step. A cliff in a mixed layer is the full wall from its
## edge to the tile centre (E2) that then gives way to a half-tile ramp on the
## corner's own side: the far side of the wall stays level (no notch), and
## the corner only deepens toward its corner along t.
static func _corner_profile(t: float, k: float, s: float, corner_t: float, mixed: bool, side: int, side_s: int, ends: bool, mode: int) -> float:
	if k <= 0.0:
		return SlopeProfile.smootherstep(t)
	if not mixed:
		return _step(t, side)
	# E3 where the tile's one cliff ends: the full wall up to its end face on
	# the centre line, beyond it the ordinary slope profile, exactly as every
	# slope tile has it.
	if ends:
		return _step(t, side) if _step(s, side_s) == 0.0 else SlopeProfile.smootherstep(t)
	var wall := 1.0 - s if mode == CliffEnd.E1 else \
		SlopeProfile.smootherstep(clampf((1.0 - CLIFF_END_CLEAR - s) / (0.5 - CLIFF_END_CLEAR), 0.0, 1.0))
	# A cubic smoothstep: over half a tile a storey ramp peaks at 45 degrees,
	# lawn (SlopeProfile.LAWN_STEEPNESS); the smootherstep peaked at 51 and read
	# as a dark moss groove beside the wall's end.
	var ramp := smoothstep(0.0, 1.0, clampf((t - 0.5 * corner_t) * 2.0, 0.0, 1.0))
	return lerpf(ramp, _step(t, side), wall)


## Profile of one direction's crossing at coordinate t, given the cliff weight
## k0 of the crossing edge at s = 0 and k1 at s = 1 (s = transverse coordinate).
static func _profile(t: float, k0: float, k1: float, s: float, side: int, side_s: int, ends: bool, mode: int) -> float:
	var k: float
	if mode == CliffEnd.E1 or k0 == k1:
		k = lerpf(k0, k1, s)
	elif ends:   # E3: the wall ends on the centre line
		k = k0 if _step(s, side_s) == 0.0 else k1
	elif k0 > k1:   # cliff at s = 0: full wall to the centre, then it shortens
		k = SlopeProfile.smootherstep(clampf((1.0 - CLIFF_END_CLEAR - s) / (0.5 - CLIFF_END_CLEAR), 0.0, 1.0))
	else:
		k = SlopeProfile.smootherstep(clampf((s - CLIFF_END_CLEAR) / (0.5 - CLIFF_END_CLEAR), 0.0, 1.0))
	if k >= 1.0:
		return _step(t, side)
	if k <= 0.0:
		return SlopeProfile.smootherstep(t)
	return lerpf(SlopeProfile.smootherstep(t), _step(t, side), k)


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
	if region is HeightfieldRegion:
		# graded_height folds the (often empty) grade list over the height.
		return height if region.terrain_grades.is_empty() else region.graded_height(x, z, height)
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


## Corner data for every lattice point in [lo, lo + size): what tile_params
## reads, gathered once. heights are float32 exactly as tile_params stores them.
static func dense_window(region, lo: Vector2i, size: Vector2i) -> Dictionary:
	var heights := PackedFloat32Array(); heights.resize(size.x * size.y)
	var storeys := PackedInt32Array(); storeys.resize(size.x * size.y)
	for j in size.y:
		for i in size.x:
			heights[j * size.x + i] = region.surface_height(lo.x + i, lo.y + j)
			storeys[j * size.x + i] = int(region.storey_at(lo.x + i, lo.y + j))
	return {"lo": lo, "w": size.x, "h": size.y, "heights": heights, "storeys": storeys,
		"spacing": spacing(region)}


## Ungraded surface height of each sample (x[k], z[k]) on the side of lattice
## point (owner_i[k], owner_j[k]); == surface_y_on_side without grading. The
## window must hold every corner of the owners' four quadrant tiles (callers
## assert _window_holds on the owners' bounds).
static func sample_window(window: Dictionary, xs: PackedFloat64Array, zs: PackedFloat64Array,
		owner_i: PackedInt32Array, owner_j: PackedInt32Array) -> PackedFloat64Array:
	if NATIVE_TILE.on():
		return NATIVE_TILE.sample_owned(window, xs, zs, owner_i, owner_j)
	return _sample_window_gd(window, xs, zs, owner_i, owner_j)


## sample_window over the grid xs x zs (row-major, z outer) with one owner per
## column (owner_xs[i]) and per row (owner_zs[k]); no flattened sample arrays.
static func sample_grid_window(window: Dictionary, xs: PackedFloat64Array, zs: PackedFloat64Array,
		owner_xs: PackedInt32Array, owner_zs: PackedInt32Array) -> PackedFloat64Array:
	if NATIVE_TILE.on():
		return NATIVE_TILE.sample_grid(window, xs, zs, owner_xs, owner_zs)
	return _sample_grid_gd(window, xs, zs, owner_xs, owner_zs)


## sample_grid_window rounded to float32 exactly as a PackedFloat32Array store
## rounds each double.
static func sample_grid_window32(window: Dictionary, xs: PackedFloat64Array, zs: PackedFloat64Array,
		owner_xs: PackedInt32Array, owner_zs: PackedInt32Array) -> PackedFloat32Array:
	if NATIVE_TILE.on():
		return NATIVE_TILE.sample_grid32(window, xs, zs, owner_xs, owner_zs)
	return _to_float32(_sample_grid_gd(window, xs, zs, owner_xs, owner_zs))


static func _to_float32(values: PackedFloat64Array) -> PackedFloat32Array:
	var out := PackedFloat32Array(); out.resize(values.size())
	for n in values.size():
		out[n] = values[n]
	return out


## O(1) debug check: owners in [owner_lo, owner_hi] keep [owner - 1, owner + 1]
## inside the window on both axes.
static func _window_holds(window: Dictionary, owner_lo: Vector2i, owner_hi: Vector2i) -> bool:
	var lo: Vector2i = window.lo
	return owner_lo.x - 1 >= lo.x and owner_lo.y - 1 >= lo.y \
		and owner_hi.x + 1 < lo.x + int(window.w) and owner_hi.y + 1 < lo.y + int(window.h)


## Whether _apply_grade can change a height on this region (decided once per
## batch instead of per sample).
static func grades(region) -> bool:
	if region is HeightfieldRegion:
		return not region.terrain_grades.is_empty()
	return region != null and region.has_method("graded_height")


## surface_y over the grid xs x zs (row-major, z outer), each sample owned by
## point_of and graded exactly as sample_baked(..., region) grades it: one
## dense window and one batched grid sample instead of a bake per point.
static func sample_grid(region, xs: PackedFloat64Array, zs: PackedFloat64Array) -> PackedFloat64Array:
	var grid := _grid_owners(region, xs, zs)
	if grid.is_empty():
		return PackedFloat64Array()
	var out := sample_grid_window(grid.window, xs, zs, grid.owner_xs, grid.owner_zs)
	if grades(region):
		var w := xs.size()
		for k in zs.size():
			for i in w:
				out[k * w + i] = _apply_grade(region, xs[i], zs[k], out[k * w + i])
	return out


## sample_grid stored as float32 (each value rounded like a PackedFloat32Array
## store of the double); ungraded regions take the float32 native entry.
static func sample_grid32(region, xs: PackedFloat64Array, zs: PackedFloat64Array) -> PackedFloat32Array:
	if grades(region):
		return _to_float32(sample_grid(region, xs, zs))
	var grid := _grid_owners(region, xs, zs)
	if grid.is_empty():
		return PackedFloat32Array()
	return sample_grid_window32(grid.window, xs, zs, grid.owner_xs, grid.owner_zs)


## point_of owners per column / row and the dense window holding their tiles.
static func _grid_owners(region, xs: PackedFloat64Array, zs: PackedFloat64Array) -> Dictionary:
	if xs.is_empty() or zs.is_empty():
		return {}
	var pxs := PackedInt32Array(); pxs.resize(xs.size())
	var pzs := PackedInt32Array(); pzs.resize(zs.size())
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for i in xs.size():
		pxs[i] = point_of(xs[i], region)
		lo.x = mini(lo.x, pxs[i]); hi.x = maxi(hi.x, pxs[i])
	for k in zs.size():
		pzs[k] = point_of(zs[k], region)
		lo.y = mini(lo.y, pzs[k]); hi.y = maxi(hi.y, pzs[k])
	var window := dense_window(region, lo - Vector2i.ONE, hi - lo + Vector2i(3, 3))
	assert(_window_holds(window, lo, hi))
	return {"window": window, "owner_xs": pxs, "owner_zs": pzs}


## Per-sample check, for the parity gate and tests only (O(n)).
static func _owners_inside(window: Dictionary, owner_i: PackedInt32Array, owner_j: PackedInt32Array) -> bool:
	var lo: Vector2i = window.lo
	var w: int = window.w
	var h: int = window.h
	for k in owner_i.size():
		if owner_i[k] - 1 < lo.x or owner_i[k] + 1 >= lo.x + w or owner_j[k] - 1 < lo.y or owner_j[k] + 1 >= lo.y + h:
			return false
	return true


## The GDScript references (the native parity gate compares against these).
## `mode`: the cliff end rule (CliffEnd; -1 = cliff_end). The parity gate
## passes each mode instead of setting the shared cliff_end (it may run on a
## worker while other threads sample).
static func _sample_window_gd(window: Dictionary, xs: PackedFloat64Array, zs: PackedFloat64Array,
		owner_i: PackedInt32Array, owner_j: PackedInt32Array, mode := -1) -> PackedFloat64Array:
	var out := PackedFloat64Array(); out.resize(xs.size())
	var params := PackedFloat32Array(); params.resize(8)
	var heights: PackedFloat32Array = window.heights
	var storeys: PackedInt32Array = window.storeys
	for k in xs.size():
		out[k] = _window_sample(heights, storeys, window.w, window.lo, window.spacing, params,
			xs[k], zs[k], owner_i[k], owner_j[k], mode)
	return out


static func _sample_grid_gd(window: Dictionary, xs: PackedFloat64Array, zs: PackedFloat64Array,
		owner_xs: PackedInt32Array, owner_zs: PackedInt32Array, mode := -1) -> PackedFloat64Array:
	var w := xs.size()
	var out := PackedFloat64Array(); out.resize(w * zs.size())
	var params := PackedFloat32Array(); params.resize(8)
	var heights: PackedFloat32Array = window.heights
	var storeys: PackedInt32Array = window.storeys
	var ww: int = window.w
	var lo: Vector2i = window.lo
	var sp: float = window.spacing
	for k in zs.size():
		for i in w:
			out[k * w + i] = _window_sample(heights, storeys, ww, lo, sp, params,
				xs[i], zs[k], owner_xs[i], owner_zs[k], mode)
	return out


## One sample of the reference over the window's arrays: `params` is
## caller-owned scratch (8 floats).
static func _window_sample(heights: PackedFloat32Array, storeys: PackedInt32Array, w: int,
		lo: Vector2i, s: float, params: PackedFloat32Array, x: float, z: float, oi: int, oj: int,
		mode := -1) -> float:
	var cx := float(oi) * s
	var cz := float(oj) * s
	var lx := clampf(x, cx - s * 0.5, cx + s * 0.5)
	var lz := clampf(z, cz - s * 0.5, cz + s * 0.5)
	var ti := oi if lx >= cx else oi - 1
	var tj := oj if lz >= cz else oj - 1
	var side := Vector2i(-1 if ti == oi else 1, -1 if tj == oj else 1)
	var a := (tj - lo.y) * w + (ti - lo.x)
	params[0] = heights[a]; params[1] = heights[a + 1]
	params[2] = heights[a + w + 1]; params[3] = heights[a + w]
	var sa := storeys[a]; var sb := storeys[a + 1]; var sc := storeys[a + w + 1]; var sd := storeys[a + w]
	params[4] = 1.0 if absi(sa - sb) >= 2 else 0.0
	params[5] = 1.0 if absi(sb - sc) >= 2 else 0.0
	params[6] = 1.0 if absi(sd - sc) >= 2 else 0.0
	params[7] = 1.0 if absi(sa - sd) >= 2 else 0.0
	return eval_params(params, (lx - float(ti) * s) / s, (lz - float(tj) * s) / s, side, 0, mode)


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
	# A half-segment lies inside one tile, where both owners evaluate the same
	# tile at the same (u, v) and differ only in `side`, which matters only on
	# a cliff crossing: a tile without a cliff edge has no wall (both owners'
	# heights are bit-identical there), so it is skipped before sampling.
	var storeys := {}
	var cliff_tiles := {}
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
					var tile := Vector2i(floori((a.x + b.x) * 0.5 / s), floori((a.y + b.y) * 0.5 / s))
					if not _tile_has_cliff(region, tile, storeys, cliff_tiles):
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


## Whether any edge of `tile` is a cliff edge (storeys two or more apart),
## memoized per call in `cliff_tiles`, with the corner storeys in `storeys`.
static func _tile_has_cliff(region, tile: Vector2i, storeys: Dictionary, cliff_tiles: Dictionary) -> bool:
	if cliff_tiles.has(tile):
		return cliff_tiles[tile]
	var c := PackedInt32Array()
	c.resize(4)
	for k in 4:
		var corner := tile + Vector2i([0, 1, 1, 0][k], [0, 0, 1, 1][k])
		if not storeys.has(corner):
			storeys[corner] = int(region.storey_at(corner.x, corner.y))
		c[k] = storeys[corner]
	var cliff := absi(c[0] - c[1]) >= 2 or absi(c[1] - c[2]) >= 2 \
		or absi(c[3] - c[2]) >= 2 or absi(c[0] - c[3]) >= 2
	cliff_tiles[tile] = cliff
	return cliff


# --- dual-cell border profiles (village turf rims) --------------------------------

## The NEIGHBOUR's surface sampled along the shared border of point `p` toward
## `d`: samples+1 heights ordered along pdir = (d.y, d.x) from the -pdir end to
## the +pdir end (the same along-edge axis the mesher grid uses).
static func edge_profile(region, p: Vector2i, d: Vector2i, samples: int) -> PackedFloat32Array:
	return _border_profile(region, p, d, samples, p + d)


## The point's OWN surface along the same border (same ordering as edge_profile).
## Where the two differ the border is a wall: the face spans from this profile
## down to the neighbour's.
static func own_edge_profile(region, p: Vector2i, d: Vector2i, samples: int) -> PackedFloat32Array:
	return _border_profile(region, p, d, samples, p)


static func _border_profile(region, p: Vector2i, d: Vector2i, samples: int,
		owner: Vector2i) -> PackedFloat32Array:
	var span := spacing(region)
	var half := span * 0.5
	var bx := float(p.x) * span + float(d.x) * half
	var bz := float(p.y) * span + float(d.y) * half
	var out := PackedFloat32Array()
	for i in samples + 1:
		var t := (float(i) / float(samples)) * 2.0 - 1.0
		out.append(surface_y_on_side(region, bx + float(d.y) * half * t, bz + float(d.x) * half * t, owner))
	return out


## The border of point `p` toward `d` is EXPOSED: its own surface is flat at the
## point's height along the whole border while the neighbour's falls at least
## EXPOSE_EPS below it somewhere. The dressable subset of the wall borders.
static func is_exposed_edge(region, p: Vector2i, d: Vector2i) -> bool:
	var h: float = region.surface_height(p.x, p.y)
	for f in own_edge_profile(region, p, d, 8):
		if f < h - 0.01:
			return false
	for f in edge_profile(region, p, d, 8):
		if f < h - EXPOSE_EPS:
			return true
	return false


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
	if slope_only:
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

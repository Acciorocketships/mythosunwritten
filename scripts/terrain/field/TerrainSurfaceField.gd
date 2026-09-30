# scripts/terrain/field/TerrainSurfaceField.gd
# Pure walkable-surface height reconstructed from a HeightfieldRegion. Each cell
# quadrant is a smootherstep patch through four SHARED controls: its centre, the
# controls at its two edge midpoints, and its corner control. Classification is
# per EDGE: a cliff edge (two or more storeys) keeps each owner's height and is
# the only multi-valued seam (the rock skirt fills it); every other edge is an
# ordinary slope whose owners evaluate the exact same boundary curve.
class_name TerrainSurfaceField
extends RefCounted

const TILE := 24.0
const HALF := TILE * 0.5   # 12.0
const STOREY := 4.0        # one cliff storey; slopes ramp at most this much per cell

const _CARDINALS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func tile_size(region = null) -> float:
	## HeightfieldRegion uses the world's authored 24 m field. Structural
	## terrain (village benches, future bridge abutments) may expose the same
	## field contract on another deterministic lattice. Keeping scale in the
	## region lets both consumers share the classifier and smootherstep kernel
	## instead of copying a visually similar slope rule.
	if region != null and region.has_method("terrain_tile_size"):
		var value: float = region.terrain_tile_size()
		assert(is_finite(value) and value > 0.0)
		return value
	return TILE


static func _cell_of(v: float, region = null) -> int:
	return int(roundf(v / tile_size(region)))

# Ramp the full drop over the whole half-cell, EXACTLY like the old SlopeProfile.edge_height
# (4m over CELL=12u ≈ 18°, smooth & walkable). `off_along_dir` runs 0 (centre, weight 0) ..
# HALF (edge, weight 1) so the drop reaches the neighbour height at the shared seam.
# smootherstep is flat at both ends, so the centre stays level and the seam tangent is 0.
# (The previous outer-half-only band crammed the drop into ~6u ≈ 34° — angular & barely
# climbable; this restores the gentle slopes the owner liked in the old slope tiles.)
static func _edge_weight(off_along_dir: float, half: float = HALF) -> float:
	return transition_weight(off_along_dir, half)


## One physical transition profile for natural slopes and sealed ground edits.
## Construction pitch controls snapping, not the length of an outdoor slope.
static func transition_weight(distance: float, width: float = HALF) -> float:
	return SlopeProfile.smootherstep(clampf(distance / width, 0.0, 1.0))

const _DIAGONALS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

## Terrain is classified per EDGE, not per tile (owner, September 27 judging
## pass). Two cardinal neighbours two or more storeys apart meet at a CLIFF
## edge: each keeps its own height up to that seam and the vertical rock face
## between them is a wall. Every other edge, including a one-storey side of a
## cell that walls elsewhere, is the ordinary smootherstep slope with one
## shared boundary curve. Diagonal differences never wall by themselves; they
## meet through the shared corner control below.
static func is_cliff_edge(region, cx: int, cz: int, d: Vector2i) -> bool:
	return absi(int(region.storey_at(cx, cz)) - int(region.storey_at(cx + d.x, cz + d.y))) >= 2

# A cell is a CLIFF TOP when at least one cardinal side is the high side of a
# cliff edge. It is no longer drawn flat as a whole: only its cliff sides keep
# the cell height; its slope sides ramp like any other cell.
static func _is_cliff_top(region, cx: int, cz: int) -> bool:
	for d in _CARDINALS:
		if _is_wall_edge(region, cx, cz, d):
			return true
	return false

# Whether the edge of (cx,cz) toward `d` is the HIGH side of a cliff edge:
# the only edges that carry a vertical rock face.
static func _is_wall_edge(region, cx: int, cz: int, d: Vector2i) -> bool:
	return int(region.storey_at(cx, cz)) - int(region.storey_at(cx + d.x, cz + d.y)) >= 2

## Public name of the per-edge wall fact (renderer skirts, grass, walkability).
static func is_wall_edge(region, cx: int, cz: int, d: Vector2i) -> bool:
	return _is_wall_edge(region, cx, cz, d)

# Edge-midpoint control of (cx,cz) toward cardinal d. A slope edge uses the
# pairwise minimum, which both owners name identically; a cliff edge keeps
# each owner's own height (the lower owner's minimum is its own height too).
# There is no special cliff-end profile (owner, September 29): where a cliff's
# corner ring is slope-connected, the corner control meets the hillside and
# the end quadrant blends to it like every other quadrant. Lowering the edge
# midpoint toward that corner (September 27) dented the plateau beside it.
static func _edge_control(region, cx: int, cz: int, d: Vector2i, h: float) -> float:
	if not is_cliff_edge(region, cx, cz, d):
		return minf(h, region.surface_height(cx + d.x, cz + d.y))
	return h

# Corner control of the quadrant of (cx,cz) toward (sx,sz). The four cells
# around the corner form a ring A-X-D-Z; cells joined through slope edges
# must name one corner height, so the corner is the minimum over the slope-
# connected component of A in that ring. Components separated by cliff edges
# keep their own corners (the wall between them). Every member computes the
# same component, so the corner is single-valued wherever a seam is.
static func _corner_control(region, cx: int, cz: int, sx: int, sz: int, h: float) -> float:
	var ring: Array[Vector2i] = [Vector2i(cx, cz), Vector2i(cx + sx, cz),
		Vector2i(cx + sx, cz + sz), Vector2i(cx, cz + sz)]
	var linked: Array[bool] = []
	for i in 4:
		var a: Vector2i = ring[i]
		var b: Vector2i = ring[(i + 1) % 4]
		linked.append(not is_cliff_edge(region, a.x, a.y, b - a))
	var corner := h
	for k in range(1, 4):          # forward: A -> X -> D -> Z
		if not linked[k - 1]:
			break
		corner = minf(corner, region.surface_height(ring[k].x, ring[k].y))
	for k in range(3, 0, -1):      # backward: A -> Z -> D -> X
		if not linked[k]:
			break
		corner = minf(corner, region.surface_height(ring[k].x, ring[k].y))
	return corner

# A concave INNER CORNER: the diagonal `cdir` neighbour is lower, BOTH adjoining cardinal arms
# sit at this cell's level, and each arm walls the drop into that diagonal pocket. The corner
# control then keeps this cell at its height (the pocket is a separate component), and the
# legacy dressing places an inner-corner piece there.
static func _is_inner_corner(region, cx: int, cz: int, cdir: Vector2i) -> bool:
	var s := int(region.storey_at(cx, cz))
	if int(region.storey_at(cx + cdir.x, cz + cdir.y)) >= s:
		return false
	var ax := Vector2i(cdir.x, 0)
	var az := Vector2i(0, cdir.y)
	if int(region.storey_at(cx + ax.x, cz + ax.y)) != s:
		return false
	if int(region.storey_at(cx + az.x, cz + az.y)) != s:
		return false
	# each level arm must itself wall the drop into the diagonal (so the pocket is a real cliff)
	return _is_wall_edge(region, cx + ax.x, cz + ax.y, az) \
		and _is_wall_edge(region, cx + az.x, cz + az.y, ax)

# Whether the cell is the high corner of any inner-corner pocket.
static func has_inner_corner(region, cx: int, cz: int) -> bool:
	for d in _DIAGONALS:
		if _is_inner_corner(region, cx, cz, d):
			return true
	return false

const EXPOSE_EPS := 0.25   # a neighbour surface this far below the flat top exposes the boundary

# A cell rendered completely FLAT at its height that walls at least one side
# or owns an inner corner. Only these cells carry the legacy native wall/lip
# pieces; a cliff cell whose slope sides ramp has bare rock skirts on its
# cliff edges (the sheet slope covers them).
static func is_flat_cell(region, cx: int, cz: int) -> bool:
	if not (_is_cliff_top(region, cx, cz) or has_inner_corner(region, cx, cz)):
		return false
	var baked := bake_cell(region, cx, cz)
	return baked[0] > 0.5

# The neighbour's pinned surface sampled along the shared edge of cell (cx,cz) toward d — the
# profile a cliff face on this edge must cover. Returns samples+1 heights ordered along
# pdir=(d.y,d.x) from the -pdir end to the +pdir end (the same along-edge axis the mesher grid
# and the dressing slots use).
static func edge_profile(region, cx: int, cz: int, d: Vector2i, samples: int) -> PackedFloat32Array:
	return _boundary_profile(region, cx, cz, d, samples, Vector2i(cx + d.x, cz + d.y))

## The cell's OWN boundary profile along its edge toward d (same ordering as
## edge_profile). Where the two differ the edge is a wall: the face spans
## from this profile down to the neighbour's.
static func own_edge_profile(region, cx: int, cz: int, d: Vector2i, samples: int) -> PackedFloat32Array:
	return _boundary_profile(region, cx, cz, d, samples, Vector2i(cx, cz))

static func _boundary_profile(region, cx: int, cz: int, d: Vector2i, samples: int,
		owner: Vector2i) -> PackedFloat32Array:
	var span := tile_size(region)
	var half := span * 0.5
	var bx := float(cx) * span + float(d.x) * half
	var bz := float(cz) * span + float(d.y) * half
	var out := PackedFloat32Array()
	for i in samples + 1:
		var t := (float(i) / float(samples)) * 2.0 - 1.0
		out.append(surface_y_in_cell(region, bx + float(d.y) * half * t, bz + float(d.x) * half * t, owner.x, owner.y))
	return out

# Is the cell's OWN surface flat at its cell height along this edge? A cliff
# edge whose ends meet a slope side descends toward that corner, and such an
# edge must not carry native lips pinned at the flat height.
static func own_edge_flat(region, cx: int, cz: int, d: Vector2i) -> bool:
	var h: float = region.surface_height(cx, cz)
	for f in own_edge_profile(region, cx, cz, d, 8):
		if f < h - 0.01:
			return false
	return true

# Neighbour d is a HIGHER flat cell: its recessed wall pieces will face this cell, so this
# cell's terrain (ground sheet, wall/lip lines, skirts) must continue UNDERNEATH it to the back
# of those pieces — otherwise the junction band shows a slit (owner: "extend the tile at the
# current level underneath the higher tile so there aren't any gaps").
static func is_higher_flat(region, cx: int, cz: int, d: Vector2i) -> bool:
	return int(region.storey_at(cx + d.x, cz + d.y)) > int(region.storey_at(cx, cz)) \
		and is_flat_cell(region, cx + d.x, cz + d.y)

# The boundary face of flat cell (cx,cz) toward d is EXPOSED: the cell's own edge is flat at its
# height while the neighbour's surface falls below it somewhere along the shared edge. This is
# the dressable subset of the wall edges (native wall + lip pieces).
static func is_exposed_edge(region, cx: int, cz: int, d: Vector2i) -> bool:
	if not is_flat_cell(region, cx, cz):
		return false
	if not own_edge_flat(region, cx, cz, d):
		return false
	var h: float = region.surface_height(cx, cz)
	for f in edge_profile(region, cx, cz, d, 8):
		if f < h - EXPOSE_EPS:
			return true
	return false

# Traversal uses the same boundary fact as rendering: a cardinal edge is
# walkable exactly when it is not a cliff edge, the only seams with a
# vertical face. Ordinary storey/level slopes remain legal without a second
# terrain classifier that could drift from the mesh.
static func is_walkable_edge(region, cell: Vector2i, d: Vector2i,
		half_width: float = -1.0) -> bool:
	assert(absi(d.x) + absi(d.y) == 1, "walkability requires a cardinal unit direction")
	if half_width >= 0.0:
		assert(is_finite(half_width) and half_width <= tile_size(region) * 0.5)
		var boundary := (Vector2(cell) + Vector2(d) * 0.5) * tile_size(region)
		var tangent := Vector2(-d.y, d.x)
		# Both owners use the same monotone quadrant interpolation. Along each
		# half of a shared edge their height difference has its extrema at the
		# interval ends. Check the complete requested strip, split at its centre;
		# a distant corner wall does not block an otherwise walkable narrow road.
		for offset: float in [-half_width, 0.0, half_width]:
			var point := boundary + tangent * offset
			var a := surface_y_in_cell(region, point.x, point.y, cell.x, cell.y)
			var b := surface_y_in_cell(region, point.x, point.y, cell.x + d.x, cell.y + d.y)
			if absf(a - b) > EXPOSE_EPS:
				return false
		return true
	return not is_cliff_edge(region, cell.x, cell.y, d)


## Proves that a grid-aligned strip crosses no rendered wall. Village streets,
## future boardwalks, and other authored corridors use this finished-surface
## fact instead of reproducing cliff rules or accepting a centre-point sample.
static func cardinal_strip_is_walkable(region, start: Vector2,
		end: Vector2, half_width: float) -> bool:
	assert(region != null)
	assert(is_finite(half_width) and half_width >= 0.0)
	var delta := end - start
	assert((is_zero_approx(delta.x) and not is_zero_approx(delta.y)) \
		or (is_zero_approx(delta.y) and not is_zero_approx(delta.x)),
		"walkable strips must be cardinal and non-empty")
	var direction := Vector2i(signi(roundi(delta.x)), signi(roundi(delta.y)))
	var perpendicular := Vector2(-direction.y, direction.x)
	for offset: float in [-half_width, 0.0, half_width]:
		if not _cardinal_line_is_walkable(region, start + perpendicular * offset,
				end + perpendicular * offset, direction):
			return false
	return true


static func _cardinal_line_is_walkable(region,
		start: Vector2, end: Vector2, direction: Vector2i) -> bool:
	var cell := Vector2i(_cell_of(start.x, region), _cell_of(start.y, region))
	var end_cell := Vector2i(_cell_of(end.x, region), _cell_of(end.y, region))
	assert((direction.x == 0 and cell.x == end_cell.x) \
		or (direction.y == 0 and cell.y == end_cell.y))
	while cell != end_cell:
		if not is_walkable_edge(region, cell, direction):
			return false
		cell += direction
	return true


static func surface_y(region, x: float, z: float) -> float:
	return surface_y_in_cell(region, x, z, _cell_of(x, region),
		_cell_of(z, region))

## Exact conservative extrema for every clipped quadrant patch intersecting a
## world-space AABB. Within one quadrant the surface is bilinear in two
## monotone smootherstep coordinates, so its extrema over a rectangular
## parameter interval occur at the four clipped corners. This keeps narrow
## structural stencils from inheriting an unrelated far edge of the same 12 m
## quadrant while retaining a proof rather than a sample-density assumption.
static func height_bounds(region, footprint: Rect2) -> Vector2:
	var natural := _natural_height_bounds(region, footprint)
	if region.has_method("graded_height_bounds"):
		return region.graded_height_bounds(footprint, natural)
	return natural


## One-sided support at a deliberately multi-valued cliff boundary. The
## footprint must remain inside this owner; neighboring vertical faces do
## not contribute a second top to its surface interval.
static func height_bounds_in_cell(region, footprint: Rect2, owner: Vector2i) -> Vector2:
	var span := tile_size(region)
	var cell_bounds := Rect2(Vector2(owner) * span - Vector2.ONE * span * 0.5, Vector2.ONE * span)
	assert(cell_bounds.encloses(footprint))
	var natural := _natural_height_bounds(region, footprint, owner)
	return region.graded_height_bounds(footprint, natural) if region.has_method("graded_height_bounds") else natural


static func _natural_height_bounds(region, footprint: Rect2, owner: Variant = null) -> Vector2:
	assert(region != null)
	assert(is_finite(footprint.position.x) and is_finite(footprint.position.y))
	assert(is_finite(footprint.size.x) and is_finite(footprint.size.y))
	assert(footprint.size.x >= 0.0 and footprint.size.y >= 0.0)
	var span := tile_size(region)
	var half := span * 0.5
	var min_cell := Vector2i(
		ceili((footprint.position.x - half) / span),
		ceili((footprint.position.y - half) / span))
	var max_cell := Vector2i(
		floori((footprint.end.x + half) / span),
		floori((footprint.end.y + half) / span))
	var minimum := INF
	var maximum := -INF
	for cz in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			if owner != null and owner != Vector2i(cx, cz): continue
			var centre := Vector2(float(cx) * span, float(cz) * span)
			for z_sign: int in [-1, 1]:
				var quadrant_min_z := centre.y \
					+ (-half if z_sign < 0 else 0.0)
				var quadrant_max_z := centre.y \
					+ (0.0 if z_sign < 0 else half)
				var lo_z := maxf(footprint.position.y, quadrant_min_z)
				var hi_z := minf(footprint.end.y, quadrant_max_z)
				if lo_z > hi_z + 0.000001:
					continue
				for x_sign: int in [-1, 1]:
					var quadrant_min_x := centre.x \
						+ (-half if x_sign < 0 else 0.0)
					var quadrant_max_x := centre.x \
						+ (0.0 if x_sign < 0 else half)
					var lo_x := maxf(footprint.position.x, quadrant_min_x)
					var hi_x := minf(footprint.end.x, quadrant_max_x)
					if lo_x > hi_x + 0.000001:
						continue
					for point: Vector2 in [Vector2(lo_x, lo_z),
							Vector2(hi_x, lo_z), Vector2(hi_x, hi_z),
							Vector2(lo_x, hi_z)]:
						var height := _natural_surface_y_in_cell(region,
							point.x, point.y, cx, cz)
						minimum = minf(minimum, height)
						maximum = maxf(maximum, height)
	assert(minimum != INF and maximum != -INF)
	return Vector2(minimum, maximum)

# Surface height at (x,z) evaluated as if the point belongs to cell (cx,cz) — even past the cell's
# edge. The mesher pins each quad to its own cell so a cliff side stays at the cell height right
# up to its boundary (no slanted face); the vertical drop to the lower cell is then a rock skirt.
# For a point inside its natural cell this is identical to surface_y.
static func surface_y_in_cell(region, x: float, z: float, cx: int, cz: int) -> float:
	return _apply_grade(region, x, z, _natural_surface_y_in_cell(region, x, z, cx, cz))

static func _apply_grade(region, x: float, z: float, height: float) -> float:
	return region.graded_height(x, z, height) \
		if region != null and region.has_method("graded_height") else height

static func _natural_surface_y_in_cell(region, x: float, z: float,
		cx: int, cz: int) -> float:
	var h: float = region.surface_height(cx, cz)
	var span := tile_size(region)
	var half := span * 0.5
	var lx := x - float(cx) * span
	var lz := z - float(cz) * span
	var dx_sign := 1 if lx >= 0.0 else -1
	var dz_sign := 1 if lz >= 0.0 else -1
	var a := _edge_weight(lx * float(dx_sign), half)            # weight toward facing x-edge
	var b := _edge_weight(lz * float(dz_sign), half)            # weight toward facing z-edge
	# Shared controls: per-edge midpoints and the slope-connected corner.
	# Bilerping them with smootherstep coordinates preserves the 1-D slope
	# profile while making every slope seam single-valued; a cliff edge keeps
	# each owner's height and the rock skirt fills the difference.
	var edge_x := _edge_control(region, cx, cz, Vector2i(dx_sign, 0), h)
	var edge_z := _edge_control(region, cx, cz, Vector2i(0, dz_sign), h)
	var corner := _corner_control(region, cx, cz, dx_sign, dz_sign, h)
	var near_edge := lerpf(h, edge_x, a)
	var far_edge := lerpf(edge_z, corner, a)
	return lerpf(near_edge, far_edge, b)

# --- baked per-cell sampler --------------------------------------------------
# The mesher evaluates ~37k surface points per chunk; surface_y_in_cell
# re-derives the cell's classification and neighbour heights from the region
# dictionaries on EVERY call. bake_cell does that derivation once per cell;
# sample_baked is then pure float math (and a single constant on flat cells).
# sample_baked(bake_cell(r, cx, cz), cx, cz, x, z) == surface_y_in_cell(r, x, z, cx, cz)
# for every point — guarded by test_baked_sampler_matches_surface_y_in_cell.
#
# Layout (PackedFloat32Array, 10 floats):
#   [0]      1.0 = flat cell (surface is the constant [1])
#   [1]      h, the cell surface height
#   [2..3]   drop toward the x neighbour, sign - / +   (>= 0)
#   [4..5]   drop toward the z neighbour, sign - / +
#   [6..9]   drop at the shared corner control, (x,z) order --, -+, +-, ++

static func bake_cell(region, cx: int, cz: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(10)
	var h: float = region.surface_height(cx, cz)
	out[1] = h
	var any_drop := false
	for i in 2:
		var sgn := -1 if i == 0 else 1
		out[2 + i] = h - _edge_control(region, cx, cz, Vector2i(sgn, 0), h)
		out[4 + i] = h - _edge_control(region, cx, cz, Vector2i(0, sgn), h)
	for ix in 2:
		for iz in 2:
			out[6 + ix * 2 + iz] = h - _corner_control(region, cx, cz,
				-1 if ix == 0 else 1, -1 if iz == 0 else 1, h)
	for i in range(2, 10):
		any_drop = any_drop or out[i] > 0.0
	out[0] = 0.0 if any_drop else 1.0
	return out


# The ramp math of surface_y_in_cell, reading baked per-cell data. Keep the
# two functions in lockstep — the equivalence test enforces it.
static func sample_baked(baked: PackedFloat32Array, cx: int, cz: int,
		x: float, z: float, region = null) -> float:
	if baked[0] > 0.5:
		return _apply_grade(region, x, z, baked[1])
	var h := baked[1]
	var span := tile_size(region)
	var half := span * 0.5
	var lx := x - float(cx) * span
	var lz := z - float(cz) * span
	var ix := 1 if lx >= 0.0 else 0
	var iz := 1 if lz >= 0.0 else 0
	var a := _edge_weight(absf(lx), half)
	var b := _edge_weight(absf(lz), half)
	var d_x := baked[2 + ix]
	var d_z := baked[4 + iz]
	var d_corner := baked[6 + ix * 2 + iz]
	var near_drop := lerpf(0.0, d_x, a)
	var far_drop := lerpf(d_z, d_corner, a)
	var drop := lerpf(near_drop, far_drop, b)
	return _apply_grade(region, x, z, h - drop)

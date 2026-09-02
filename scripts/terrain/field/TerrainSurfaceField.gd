# scripts/terrain/field/TerrainSurfaceField.gd
# Pure walkable-surface height reconstructed from a HeightfieldRegion. Each cell
# quadrant is a smootherstep patch through four SHARED controls: its centre, the
# minima at its two edge midpoints, and the minimum of the four cells meeting at
# its corner. Adjacent cell owners therefore evaluate the exact same boundary
# curve. Only deliberate flat cliff/inner-corner tops are multi-valued; their
# vertical difference is filled by the rock skirt.
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
	return SlopeProfile.smootherstep(clampf(off_along_dir / half, 0.0, 1.0))

const _DIAGONALS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

# A cell is a CLIFF TOP if any neighbour — cardinal OR diagonal — sits ≥2 storeys below it.
# A cliff top is drawn FLAT across its whole surface, so the KayKit grass lip that sits on its
# edge is always backed by flat terrain at the same height (never overhanging into midair or
# undercut by a slope behind it). Slopes live on the ADJACENT (non-cliff) cells, which ramp up
# to meet the flat cliff top — see surface_y.
static func _is_cliff_top(region, cx: int, cz: int) -> bool:
	var s: int = region.storey_at(cx, cz)
	var dry_bank: bool = region.has_method("is_carved") and not region.is_carved(cx, cz)
	for d in (_CARDINALS + _DIAGONALS):
		var nb_s: int = int(region.storey_at(cx + d.x, cz + d.y))
		if s - nb_s >= 2:
			return true
		# A DRY cell overlooking a water-CARVED cell walls even a 1-storey
		# drop: shorelines read as crisp dressed banks, not bare ramps dipping
		# into the water (the shingle plates / extraneous-corner mess around
		# carved channels). Inert without a water plan (carved map empty).
		if s - nb_s >= 1 and dry_bank and region.is_carved(cx + d.x, cz + d.y):
			return true
	return false

# Whether the edge of cliff top (cx,cz) toward `d` carries a rock wall + grass lip. A CLIFF TOP is
# a flat plateau drawn level to its edges, so EVERY storey drop off it is a vertical wall — nothing
# ramps the lower ground up to meet it. Non-cliff cells never wall; they only slope (surface_y ramps
# them DOWN to their lower neighbours, so a ≤1-storey drop between them is a walkable slope).
static func _is_wall_edge(region, cx: int, cz: int, d: Vector2i) -> bool:
	if not _is_cliff_top(region, cx, cz):
		return false
	return int(region.storey_at(cx, cz)) - int(region.storey_at(cx + d.x, cz + d.y)) >= 1

# A concave INNER CORNER: the diagonal `cdir` neighbour is lower, BOTH adjoining cardinal arms
# sit at this cell's level, and each arm walls the drop into that diagonal pocket. Then this cell
# is the high corner of a clean cliff pocket — it must read as a vertical inner-corner cliff (flat
# top + inner-corner piece), NOT a diagonal slope dipping into the notch. Mirrors the old tile
# system's rule (HeightfieldVariant.missing_from_heights: a diagonal is an inner-corner notch only
# when its neighbour is lower AND both adjoining cardinals are connected/level).
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
	if not _arm_walls(region, cx + ax.x, cz + ax.y, az):
		return false
	if not _arm_walls(region, cx + az.x, cz + az.y, ax):
		return false
	return true

# Does the arm cell wall the storey drop toward `d`? It does when it renders FLAT: a cliff top,
# or a cell held flat by an inner-corner pocket of its own — checked with CLIFF-TOP-ONLY arms
# (first order) so this never recurses through has_inner_corner. Owner round 12 (seed 613274262,
# corner (-156,-228)): an arm flat only via its own inner corner failed the old cliff-top-only
# check, so the classic corner never fired while the slope pocket's unregistered GHOST did — and
# the arms' held-nowhere sheet clips draped a notch into the plateau around the piece.
static func _arm_walls(region, ax: int, az: int, d: Vector2i) -> bool:
	if int(region.storey_at(ax, az)) - int(region.storey_at(ax + d.x, az + d.y)) < 1:
		return false
	if _is_cliff_top(region, ax, az):
		return true
	for dd in _DIAGONALS:
		if _is_inner_corner_strict(region, ax, az, dd):
			return true
	return false

# The pre-round-12 inner-corner rule (arms must be CLIFF TOPS) — the terminal, non-recursive
# form _arm_walls falls back on.
static func _is_inner_corner_strict(region, cx: int, cz: int, cdir: Vector2i) -> bool:
	var s := int(region.storey_at(cx, cz))
	if int(region.storey_at(cx + cdir.x, cz + cdir.y)) >= s:
		return false
	var ax := Vector2i(cdir.x, 0)
	var az := Vector2i(0, cdir.y)
	if int(region.storey_at(cx + ax.x, cz + ax.y)) != s:
		return false
	if int(region.storey_at(cx + az.x, cz + az.y)) != s:
		return false
	if not _is_wall_edge(region, cx + ax.x, cz + ax.y, az):
		return false
	if not _is_wall_edge(region, cx + az.x, cz + az.y, ax):
		return false
	return true

# Whether the cell is the high corner of any inner-corner pocket (so it must stay flat + be dressed).
static func has_inner_corner(region, cx: int, cz: int) -> bool:
	for d in _DIAGONALS:
		if _is_inner_corner(region, cx, cz, d):
			return true
	return false

const EXPOSE_EPS := 0.25   # a neighbour surface this far below the flat top exposes the boundary

# A cell that renders FLAT at its cell height: a cliff top, or the high corner of an
# inner-corner pocket (kept flat so its corner piece is backed).
static func is_flat_cell(region, cx: int, cz: int) -> bool:
	return _is_cliff_top(region, cx, cz) or has_inner_corner(region, cx, cz)

# The neighbour's pinned surface sampled along the shared edge of cell (cx,cz) toward d — the
# profile a cliff face on this edge must cover. Returns samples+1 heights ordered along
# pdir=(d.y,d.x) from the -pdir end to the +pdir end (the same along-edge axis the mesher grid
# and the dressing slots use). Where this falls below the cell's flat height the boundary face
# is exposed: a storey drop, a same-storey SLOPE neighbour descending along the edge toward its
# own lower ground, or both — cell-centre storey differences alone miss the slope cases (owner's
# see-through voids next to slopes).
static func edge_profile(region, cx: int, cz: int, d: Vector2i, samples: int) -> PackedFloat32Array:
	var span := tile_size(region)
	var half := span * 0.5
	var bx := float(cx) * span + float(d.x) * half
	var bz := float(cz) * span + float(d.y) * half
	var out := PackedFloat32Array()
	for i in samples + 1:
		var t := (float(i) / float(samples)) * 2.0 - 1.0
		out.append(surface_y_in_cell(region, bx + float(d.y) * half * t, bz + float(d.x) * half * t, cx + d.x, cz + d.y))
	return out

# Is the cell's OWN surface flat at its cell height along this edge? A cliff top always is; a
# has_inner_corner cell that is not a cliff top ramps down toward its lower cardinals, and those
# edges must not carry walls/lips pinned at the flat height.
static func own_edge_flat(region, cx: int, cz: int, d: Vector2i) -> bool:
	if _is_cliff_top(region, cx, cz):
		return true
	var h: float = region.surface_height(cx, cz)
	var span := tile_size(region)
	var half := span * 0.5
	var bx := float(cx) * span + float(d.x) * half
	var bz := float(cz) * span + float(d.y) * half
	for i in 9:
		var t := (float(i) / 8.0) * 2.0 - 1.0
		if surface_y_in_cell(region, bx + float(d.y) * half * t, bz + float(d.x) * half * t, cx, cz) < h - 0.01:
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
# height while the neighbour's surface falls below it somewhere along the shared edge.
# Generalises _is_wall_edge (a ≥1-storey drop off a cliff top) to same-storey slope neighbours.
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
# walkable exactly when neither owner exposes a vertical face there. Ordinary
# storey/level slopes remain legal, while cliffs, inner-corner walls, diagonal
# cliff shoulders, and edges facing a higher flat cell are rejected without a
# second terrain classifier that could drift from the mesh.
static func is_walkable_edge(region, cell: Vector2i, d: Vector2i) -> bool:
	assert(absi(d.x) + absi(d.y) == 1, "walkability requires a cardinal unit direction")
	return not is_exposed_edge(region, cell.x, cell.y, d) \
		and not is_exposed_edge(region, cell.x + d.x, cell.y + d.y, -d)


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
						var height := surface_y_in_cell(region,
							point.x, point.y, cx, cz)
						minimum = minf(minimum, height)
						maximum = maxf(maximum, height)
	assert(minimum != INF and maximum != -INF)
	return Vector2(minimum, maximum)

# Height of the shared corner control in one cell quadrant. Normally this is
# simply the minimum of the four centres meeting there: the no-up-ramp rule in
# a symmetric form, so every owner gets the same value. Two deliberate cliff
# configurations keep the current cell's corner flat instead:
#   * a classic inner corner, whose vertical pocket is dressed; and
#   * the historical higher-cardinal guard, where dipping toward a lower
#     diagonal would cut a crack beside a higher flat cliff arm.
# The guard only applies when neither cardinal edge is already descending.
static func _quadrant_corner_height(region, cx: int, cz: int,
		dx_sign: int, dz_sign: int, h: float, edge_x: float, edge_z: float) -> float:
	var diag: float = region.surface_height(cx + dx_sign, cz + dz_sign)
	var corner := minf(minf(h, edge_x), minf(edge_z, diag))
	if corner >= h - 0.0001 or edge_x < h - 0.0001 or edge_z < h - 0.0001:
		return corner
	var s_here := int(region.storey_at(cx, cz))
	var arms_share_storey := int(region.storey_at(cx + dx_sign, cz)) == s_here \
		and int(region.storey_at(cx, cz + dz_sign)) == s_here
	if not arms_share_storey \
		or _is_inner_corner(region, cx, cz, Vector2i(dx_sign, dz_sign)):
		return h
	return corner

# Surface height at (x,z) evaluated as if the point belongs to cell (cx,cz) — even past the cell's
# edge. The mesher pins each quad to its own cell so a cliff top renders FLAT right up to its
# boundary (no slanted face); the vertical drop to the lower cell is then a separate rock skirt.
# For a point inside its natural cell this is identical to surface_y.
static func surface_y_in_cell(region, x: float, z: float, cx: int, cz: int) -> float:
	var h: float = region.surface_height(cx, cz)
	# A cliff top is FLAT (its lip needs flat backing); the KayKit tile draws its edges.
	if _is_cliff_top(region, cx, cz):
		return h
	var span := tile_size(region)
	var half := span * 0.5
	var lx := x - float(cx) * span
	var lz := z - float(cz) * span
	var dx_sign := 1 if lx >= 0.0 else -1
	var dz_sign := 1 if lz >= 0.0 else -1
	var a := _edge_weight(lx * float(dx_sign), half)            # weight toward facing x-edge
	var b := _edge_weight(lz * float(dz_sign), half)            # weight toward facing z-edge
	# Shared controls. Edge midpoint heights are pairwise minima: a higher cell
	# ramps down, a lower cell never ramps up, and BOTH owners nevertheless name
	# the same seam value. The corner is the corresponding four-cell minimum.
	# Bilerping the controls with smootherstep coordinates preserves the old 1-D
	# slope profile while making every 2-D seam profile single-valued.
	var edge_x := minf(h, region.surface_height(cx + dx_sign, cz))
	var edge_z := minf(h, region.surface_height(cx, cz + dz_sign))
	var corner := _quadrant_corner_height(
		region, cx, cz, dx_sign, dz_sign, h, edge_x, edge_z)
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
#   [0]      1.0 = cliff top (surface is the constant [1])
#   [1]      h, the cell surface height
#   [2..3]   drop toward the x neighbour, sign - / +   (>= 0)
#   [4..5]   drop toward the z neighbour, sign - / +
#   [6..9]   drop at the shared corner control, (x,z) order --, -+, +-, ++

static func bake_cell(region, cx: int, cz: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(10)
	var h: float = region.surface_height(cx, cz)
	out[1] = h
	if _is_cliff_top(region, cx, cz):
		out[0] = 1.0
		return out
	for i in 2:
		var sgn := -1 if i == 0 else 1
		out[2 + i] = maxf(0.0, h - region.surface_height(cx + sgn, cz))
		out[4 + i] = maxf(0.0, h - region.surface_height(cx, cz + sgn))
	for ix in 2:
		for iz in 2:
			var k := ix * 2 + iz
			var dxs := -1 if ix == 0 else 1
			var dzs := -1 if iz == 0 else 1
			var edge_x := h - out[2 + ix]
			var edge_z := h - out[4 + iz]
			var corner := _quadrant_corner_height(
				region, cx, cz, dxs, dzs, h, edge_x, edge_z)
			out[6 + k] = h - corner
	return out


# The ramp math of surface_y_in_cell, reading baked per-cell data. Keep the
# two functions in lockstep — the equivalence test enforces it.
static func sample_baked(baked: PackedFloat32Array, cx: int, cz: int,
		x: float, z: float, region = null) -> float:
	if baked[0] > 0.5:
		return baked[1]
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
	return h - drop

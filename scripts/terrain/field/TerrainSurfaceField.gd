# scripts/terrain/field/TerrainSurfaceField.gd
# Pure, continuous walkable-surface height reconstructed from a HeightfieldRegion.
# Flat on cell interiors; ramps toward lower neighbours (added in later tasks).
# Single-valued everywhere ⇒ when sampled on a shared grid, adjacent cells/chunks
# share identical boundary vertices ⇒ the mesh is gap-free by construction.
class_name TerrainSurfaceField
extends RefCounted

const TILE := 24.0
const HALF := TILE * 0.5   # 12.0
const STOREY := 4.0        # one cliff storey; slopes ramp at most this much per cell

const _CARDINALS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func _cell_of(v: float) -> int:
	return int(roundf(v / TILE))

# Ramp the full drop over the whole half-cell, EXACTLY like the old SlopeProfile.edge_height
# (4m over CELL=12u ≈ 18°, smooth & walkable). `off_along_dir` runs 0 (centre, weight 0) ..
# HALF (edge, weight 1) so the drop reaches the neighbour height at the shared seam.
# smootherstep is flat at both ends, so the centre stays level and the seam tangent is 0.
# (The previous outer-half-only band crammed the drop into ~6u ≈ 34° — angular & barely
# climbable; this restores the gentle slopes the owner liked in the old slope tiles.)
static func _edge_weight(off_along_dir: float) -> float:
	return SlopeProfile.smootherstep(clampf(off_along_dir / HALF, 0.0, 1.0))

const _DIAGONALS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

# A cell is a CLIFF TOP if any neighbour — cardinal OR diagonal — sits ≥2 storeys below it.
# A cliff top is drawn FLAT across its whole surface, so the KayKit grass lip that sits on its
# edge is always backed by flat terrain at the same height (never overhanging into midair or
# undercut by a slope behind it). Slopes live on the ADJACENT (non-cliff) cells, which ramp up
# to meet the flat cliff top — see surface_y.
static func _is_cliff_top(region, cx: int, cz: int) -> bool:
	var s: int = region.storey_at(cx, cz)
	for d in (_CARDINALS + _DIAGONALS):
		if s - int(region.storey_at(cx + d.x, cz + d.y)) >= 2:
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
	var bx := float(cx) * TILE + float(d.x) * HALF
	var bz := float(cz) * TILE + float(d.y) * HALF
	var out := PackedFloat32Array()
	for i in samples + 1:
		var t := (float(i) / float(samples)) * 2.0 - 1.0
		out.append(surface_y_in_cell(region, bx + float(d.y) * HALF * t, bz + float(d.x) * HALF * t, cx + d.x, cz + d.y))
	return out

# Is the cell's OWN surface flat at its cell height along this edge? A cliff top always is; a
# has_inner_corner cell that is not a cliff top ramps down toward its lower cardinals, and those
# edges must not carry walls/lips pinned at the flat height.
static func own_edge_flat(region, cx: int, cz: int, d: Vector2i) -> bool:
	if _is_cliff_top(region, cx, cz):
		return true
	var h: float = region.surface_height(cx, cz)
	var bx := float(cx) * TILE + float(d.x) * HALF
	var bz := float(cz) * TILE + float(d.y) * HALF
	for i in 9:
		var t := (float(i) / 8.0) * 2.0 - 1.0
		if surface_y_in_cell(region, bx + float(d.y) * HALF * t, bz + float(d.x) * HALF * t, cx, cz) < h - 0.01:
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

static func surface_y(region, x: float, z: float) -> float:
	return surface_y_in_cell(region, x, z, _cell_of(x), _cell_of(z))

# Surface height at (x,z) evaluated as if the point belongs to cell (cx,cz) — even past the cell's
# edge. The mesher pins each quad to its own cell so a cliff top renders FLAT right up to its
# boundary (no slanted face); the vertical drop to the lower cell is then a separate rock skirt.
# For a point inside its natural cell this is identical to surface_y.
static func surface_y_in_cell(region, x: float, z: float, cx: int, cz: int) -> float:
	var h: float = region.surface_height(cx, cz)
	# A cliff top is FLAT (its lip needs flat backing); the KayKit tile draws its edges.
	if _is_cliff_top(region, cx, cz):
		return h
	var lx := x - float(cx) * TILE
	var lz := z - float(cz) * TILE
	var dx_sign := 1 if lx >= 0.0 else -1
	var dz_sign := 1 if lz >= 0.0 else -1
	var a := _edge_weight(lx * float(dx_sign))                 # weight toward facing x-edge
	var b := _edge_weight(lz * float(dz_sign))                 # weight toward facing z-edge
	# Ramp DOWN toward lower neighbours (≤1-storey slopes; a non-cliff cell has no ≥2 drop).
	var d_x: float = maxf(0.0, h - region.surface_height(cx + dx_sign, cz))
	var d_z: float = maxf(0.0, h - region.surface_height(cx, cz + dz_sign))
	var d_d: float = maxf(0.0, h - region.surface_height(cx + dx_sign, cz + dz_sign))
	# Ramp DOWN toward lower neighbours only — there is NO up-ramp. A cell never rises to meet a
	# higher cliff (that lean-to ramp produced mounds/spikes where the cell also dropped elsewhere);
	# the higher cell is a flat cliff top and walls down to this one vertically instead.
	var drop := 0.0
	if d_x > 0.0 or d_z > 0.0:
		var wx := a if d_x > 0.0 else 0.0
		var wz := b if d_z > 0.0 else 0.0
		var delta := maxf(d_x, d_z)
		drop = delta * (wx + wz - wx * wz)
	elif d_d > 0.0:
		# A lower diagonal pulls the corner down (concave slope) ONLY when BOTH adjoining cardinal
		# arms sit at THIS cell's level — then the dip stays continuous with both edges. If an arm is
		# HIGHER (a cliff walls down to this cell), dipping toward the diagonal would crack the shared
		# edge with that flat cliff top (owner's slope "discontinuity"); stay flat and let the cliff's
		# skirt span the drop. An inner-corner pocket also stays flat (its cliff piece spans the drop).
		var s_here := int(region.storey_at(cx, cz))
		var arm_x_level := int(region.storey_at(cx + dx_sign, cz)) == s_here
		var arm_z_level := int(region.storey_at(cx, cz + dz_sign)) == s_here
		if arm_x_level and arm_z_level and not _is_inner_corner(region, cx, cz, Vector2i(dx_sign, dz_sign)):
			drop = d_d * (a * b)
	return h - drop

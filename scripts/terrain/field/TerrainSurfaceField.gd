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

# Does cell (cx,cz) have a strictly-lower cardinal neighbour? Such a cell already slopes DOWN
# somewhere, so it must NOT also ramp UP to a higher cliff (that would funnel it across >1 storey
# — the inner-corner spike). Instead the cliff walls down to it (a clean terraced step).
static func _has_lower_neighbour(region, cx: int, cz: int) -> bool:
	var s: int = region.storey_at(cx, cz)
	for d in _CARDINALS:
		if int(region.storey_at(cx + d.x, cz + d.y)) < s:
			return true
	return false

# Whether the edge of cliff top (cx,cz) toward `d` carries a rock wall + grass lip. A cliff top
# walls a ≥2-storey drop; and a 1-storey drop is a wall when the lower cell can't simply ramp up
# to meet the top — i.e. the lower cell is itself a cliff top, or it already slopes down elsewhere
# (so ramping up would funnel it). A 1-storey drop to a pure low SHELF stays a walkable slope.
static func _is_wall_edge(region, cx: int, cz: int, d: Vector2i) -> bool:
	if not _is_cliff_top(region, cx, cz):
		return false
	var drop := int(region.storey_at(cx, cz)) - int(region.storey_at(cx + d.x, cz + d.y))
	if drop >= 2:
		return true
	if drop != 1:
		return false
	return _is_cliff_top(region, cx + d.x, cz + d.y) or _has_lower_neighbour(region, cx + d.x, cz + d.y)

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

static func surface_y(region, x: float, z: float) -> float:
	var cx := _cell_of(x)
	var cz := _cell_of(z)
	var h: float = region.surface_height(cx, cz)
	# A cliff top is FLAT (its lip needs flat backing); the KayKit tile draws its edges.
	if _is_cliff_top(region, cx, cz):
		return h
	var s := int(region.storey_at(cx, cz))
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
	var drop := 0.0
	if d_x > 0.0 or d_z > 0.0:
		var wx := a if d_x > 0.0 else 0.0
		var wz := b if d_z > 0.0 else 0.0
		var delta := maxf(d_x, d_z)
		drop = delta * (wx + wz - wx * wz)
	elif d_d > 0.0:
		# A lower diagonal normally pulls the corner down (concave slope). But if it's an inner-corner
		# pocket, keep this corner FLAT — the inner-corner cliff piece + rock face span the drop.
		if not _is_inner_corner(region, cx, cz, Vector2i(dx_sign, dz_sign)):
			drop = d_d * (a * b)
	# And ramp UP to MEET a facing cliff top exactly one storey higher: a 1-storey drop to a flat
	# cliff top is a walkable slope ON THIS cell, not a wall — so the cliff edge there reads as a
	# slope joining the top, not a spurious walled corner. BUT only for a pure low SHELF: if this
	# cell ALSO drops away somewhere, ramping up would funnel it across >1 storey into a thin spike
	# at the inner corner. Such a cell stays flat (the cliff walls down to it — _is_wall_edge).
	if _has_lower_neighbour(region, cx, cz):
		return h - drop
	var rise := 0.0
	if int(region.storey_at(cx + dx_sign, cz)) == s + 1 and _is_cliff_top(region, cx + dx_sign, cz):
		rise = maxf(rise, (region.surface_height(cx + dx_sign, cz) - h) * a)
	if int(region.storey_at(cx, cz + dz_sign)) == s + 1 and _is_cliff_top(region, cx, cz + dz_sign):
		rise = maxf(rise, (region.surface_height(cx, cz + dz_sign) - h) * b)
	if int(region.storey_at(cx + dx_sign, cz + dz_sign)) == s + 1 and _is_cliff_top(region, cx + dx_sign, cz + dz_sign):
		rise = maxf(rise, (region.surface_height(cx + dx_sign, cz + dz_sign) - h) * a * b)
	return h - drop + rise

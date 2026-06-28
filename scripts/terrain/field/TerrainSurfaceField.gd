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

# Whether the edge of cliff top (cx,cz) toward `d` carries a rock wall + grass lip. A cliff
# top walls a ≥2-storey drop, and ALSO a 1-storey drop to ANOTHER cliff top (two flat tiles a
# storey apart can't be joined by a ramp, so the step is a wall). A 1-storey drop to a NON-cliff
# cell is a walkable SLOPE — that cell ramps up to meet the flat top — so it gets no wall/corner
# (a wall there would spawn a spurious corner on a side that should just be a slope).
static func _is_wall_edge(region, cx: int, cz: int, d: Vector2i) -> bool:
	if not _is_cliff_top(region, cx, cz):
		return false
	var drop := int(region.storey_at(cx, cz)) - int(region.storey_at(cx + d.x, cz + d.y))
	if drop >= 2:
		return true
	return drop == 1 and _is_cliff_top(region, cx + d.x, cz + d.y)

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
		drop = d_d * (a * b)
	# And ramp UP to MEET a facing cliff top exactly one storey higher: a 1-storey drop to a flat
	# cliff top is a walkable slope ON THIS cell, not a wall — so the cliff edge there reads as a
	# slope joining the top, not a spurious walled corner.
	var rise := 0.0
	if int(region.storey_at(cx + dx_sign, cz)) == s + 1 and _is_cliff_top(region, cx + dx_sign, cz):
		rise = maxf(rise, (region.surface_height(cx + dx_sign, cz) - h) * a)
	if int(region.storey_at(cx, cz + dz_sign)) == s + 1 and _is_cliff_top(region, cx, cz + dz_sign):
		rise = maxf(rise, (region.surface_height(cx, cz + dz_sign) - h) * b)
	if int(region.storey_at(cx + dx_sign, cz + dz_sign)) == s + 1 and _is_cliff_top(region, cx + dx_sign, cz + dz_sign):
		rise = maxf(rise, (region.surface_height(cx + dx_sign, cz + dz_sign) - h) * a * b)
	return h - drop + rise

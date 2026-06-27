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

# Ramp band occupies the OUTER half of the cell (matching SlopeProfile's 50% slope
# band): weight 0 across the inner half (off <= HALF*0.5, cell stays flat), rising via
# smootherstep to 1 at the cell edge (off == HALF) so it reaches the neighbour height
# exactly at the shared seam. `off_along_dir` runs 0 (centre) .. HALF (edge); the
# opposite half of the cell yields off < 0 → weight 0 (flat).
const _BAND := HALF * 0.5   # inner half flat, outer half ramps
static func _edge_weight(off_along_dir: float) -> float:
	return SlopeProfile.smootherstep(clampf((off_along_dir - _BAND) / _BAND, 0.0, 1.0))

const _DIAGONALS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

# A cell is a cliff TOP if any cardinal neighbour sits ≥2 storeys below it. Such a cell
# is a plateau: flat across its whole top so the generated rock wall + grass lip align
# with it, and the 4m slope to a 1-storey-lower neighbour lives on that neighbour.
static func _is_cliff_top(region, cx: int, cz: int) -> bool:
	var s: int = region.storey_at(cx, cz)
	for d in _CARDINALS:
		if s - int(region.storey_at(cx + d.x, cz + d.y)) >= 2:
			return true
	return false

static func surface_y(region, x: float, z: float) -> float:
	var cx := _cell_of(x)
	var cz := _cell_of(z)
	var h: float = region.surface_height(cx, cz)
	# A cliff cell takes the WHOLE drop: its top is flat (the KayKit tile draws it). The
	# field mesh only draws non-cliff cells; here we keep returning h for continuity at
	# the boundary (the non-cliff neighbour ramps up to this flat height).
	if _is_cliff_top(region, cx, cz):
		return h
	var s: int = region.storey_at(cx, cz)
	var lx := x - float(cx) * TILE
	var lz := z - float(cz) * TILE
	var dx_sign := 1 if lx >= 0.0 else -1
	var dz_sign := 1 if lz >= 0.0 else -1
	var a := _edge_weight(lx * float(dx_sign))                 # weight toward facing x-edge
	var b := _edge_weight(lz * float(dz_sign))                 # weight toward facing z-edge
	# A non-cliff cell only has ≤1-storey drops; ramp toward each lower neighbour.
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
	# Up-ramp to meet a facing 1-storey-higher cliff edge (the slope lives on this cell).
	var rise := 0.0
	if int(region.storey_at(cx + dx_sign, cz)) == s + 1 and _is_cliff_top(region, cx + dx_sign, cz):
		rise = maxf(rise, (region.surface_height(cx + dx_sign, cz) - h) * a)
	if int(region.storey_at(cx, cz + dz_sign)) == s + 1 and _is_cliff_top(region, cx, cz + dz_sign):
		rise = maxf(rise, (region.surface_height(cx, cz + dz_sign) - h) * b)
	return h - drop + rise

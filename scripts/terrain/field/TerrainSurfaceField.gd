# scripts/terrain/field/TerrainSurfaceField.gd
# Pure, continuous walkable-surface height reconstructed from a HeightfieldRegion.
# Flat on cell interiors; ramps toward lower neighbours (added in later tasks).
# Single-valued everywhere ⇒ when sampled on a shared grid, adjacent cells/chunks
# share identical boundary vertices ⇒ the mesh is gap-free by construction.
class_name TerrainSurfaceField
extends RefCounted

const TILE := 24.0
const HALF := TILE * 0.5   # 12.0

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

static func surface_y(region, x: float, z: float) -> float:
	var cx := _cell_of(x)
	var cz := _cell_of(z)
	var h: float = region.surface_height(cx, cz)
	var lx := x - float(cx) * TILE   # [-HALF, HALF]
	var lz := z - float(cz) * TILE
	var drop := 0.0
	for dir in _CARDINALS:
		var nh: float = region.surface_height(cx + dir.x, cz + dir.y)
		var delta := h - nh
		if delta <= 0.0:
			continue   # neighbour is not lower → this side stays flat
		# offset toward this neighbour: +x uses +lx, -x uses -lx, etc.
		var off := lx * float(dir.x) + lz * float(dir.y)
		drop = maxf(drop, delta * _edge_weight(off))
	return h - drop

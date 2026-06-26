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

const _DIAGONALS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

static func surface_y(region, x: float, z: float) -> float:
	var cx := _cell_of(x)
	var cz := _cell_of(z)
	var h: float = region.surface_height(cx, cz)
	var lx := x - float(cx) * TILE
	var lz := z - float(cz) * TILE
	# Per-direction lower-deltas (0 if neighbour not lower).
	var dx_sign := 1 if lx >= 0.0 else -1
	var dz_sign := 1 if lz >= 0.0 else -1
	var a := _edge_weight(lx * float(dx_sign))                 # weight toward facing x-edge
	var b := _edge_weight(lz * float(dz_sign))                 # weight toward facing z-edge
	var d_x: float = maxf(0.0, h - region.surface_height(cx + dx_sign, cz))
	var d_z: float = maxf(0.0, h - region.surface_height(cx, cz + dz_sign))
	var d_d: float = maxf(0.0, h - region.surface_height(cx + dx_sign, cz + dz_sign))
	var drop := 0.0
	if d_x > 0.0 or d_z > 0.0:
		# Convex corner (at least one cardinal drops). Gate each facing edge weight by
		# whether THAT cardinal actually drops, so a direction with an equal-height
		# neighbour contributes no ramp: the blend a+b-ab then reduces to the plain
		# single-edge ramp beside an equal neighbour (matches SlopeProfile.outer_corner,
		# where f(a,0)=a and f(0,b)=b — each edge seam stays the plain edge profile).
		var wx := a if d_x > 0.0 else 0.0
		var wz := b if d_z > 0.0 else 0.0
		var delta := maxf(d_x, d_z)
		drop = delta * (wx + wz - wx * wz)
	elif d_d > 0.0:
		# Concave corner (only the diagonal drops): a*b so just the far vertex dips.
		drop = d_d * (a * b)
	return h - drop

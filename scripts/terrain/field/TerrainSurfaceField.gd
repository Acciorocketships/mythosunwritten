# scripts/terrain/field/TerrainSurfaceField.gd
# Pure, continuous walkable-surface height reconstructed from a HeightfieldRegion.
# Flat on cell interiors; ramps toward lower neighbours (added in later tasks).
# Single-valued everywhere ⇒ when sampled on a shared grid, adjacent cells/chunks
# share identical boundary vertices ⇒ the mesh is gap-free by construction.
class_name TerrainSurfaceField
extends RefCounted

const TILE := 24.0
const HALF := TILE * 0.5   # 12.0

static func _cell_of(v: float) -> int:
	return int(roundf(v / TILE))

static func surface_y(region, x: float, z: float) -> float:
	var cx := _cell_of(x)
	var cz := _cell_of(z)
	return region.surface_height(cx, cz)

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

# Whether the drop across the edge from cell (cx,cz) toward `d` is a CLIFF (vertical rock
# wall) rather than a walkable slope. Decided PER EDGE, not per cell, so a plateau can have
# a cliff on one side and a ramp on another:
#   • a ≥2-storey drop is always a cliff;
#   • a 1-storey drop is a cliff when it is COLLINEAR with a ≥2 cliff (the neighbour one step
#     along the edge has a ≥2 drop in the same direction). This extends a cliff's straight run
#     down its tapering end, so a ramp rising beside a cliff keeps a clean walled edge on that
#     side instead of the slope "melting" into the pit. A 1-storey drop with no ≥2 cliff in
#     line stays a gentle walkable slope.
static func _is_cliff_edge(region, cx: int, cz: int, d: Vector2i) -> bool:
	var drop := int(region.storey_at(cx, cz)) - int(region.storey_at(cx + d.x, cz + d.y))
	if drop >= 2:
		return true
	if drop == 1:
		var p := Vector2i(d.y, d.x)   # perpendicular (along the edge)
		if int(region.storey_at(cx + p.x, cz + p.y)) - int(region.storey_at(cx + p.x + d.x, cz + p.y + d.y)) >= 2:
			return true
		if int(region.storey_at(cx - p.x, cz - p.y)) - int(region.storey_at(cx - p.x + d.x, cz - p.y + d.y)) >= 2:
			return true
	return false

static func surface_y(region, x: float, z: float) -> float:
	var cx := _cell_of(x)
	var cz := _cell_of(z)
	var h: float = region.surface_height(cx, cz)
	var lx := x - float(cx) * TILE
	var lz := z - float(cz) * TILE
	var dx_sign := 1 if lx >= 0.0 else -1
	var dz_sign := 1 if lz >= 0.0 else -1
	var a := _edge_weight(lx * float(dx_sign))                 # weight toward facing x-edge
	var b := _edge_weight(lz * float(dz_sign))                 # weight toward facing z-edge
	# Ramp toward a lower neighbour ONLY across a walkable SLOPE edge. A cliff edge stays flat
	# (the rock wall takes the whole drop); this makes a cell flat on its cliff sides and
	# sloped on its slope sides — no melt, no climbing the cliff.
	var d_x := 0.0
	if not _is_cliff_edge(region, cx, cz, Vector2i(dx_sign, 0)):
		d_x = maxf(0.0, h - region.surface_height(cx + dx_sign, cz))
	var d_z := 0.0
	if not _is_cliff_edge(region, cx, cz, Vector2i(0, dz_sign)):
		d_z = maxf(0.0, h - region.surface_height(cx, cz + dz_sign))
	# Diagonal: ramp into a concave (≤1) corner; a ≥2 diagonal is an inner-corner cliff (flat).
	var d_d := 0.0
	if int(region.storey_at(cx, cz)) - int(region.storey_at(cx + dx_sign, cz + dz_sign)) < 2:
		d_d = maxf(0.0, h - region.surface_height(cx + dx_sign, cz + dz_sign))
	var drop := 0.0
	if d_x > 0.0 or d_z > 0.0:
		var wx := a if d_x > 0.0 else 0.0
		var wz := b if d_z > 0.0 else 0.0
		var delta := maxf(d_x, d_z)
		drop = delta * (wx + wz - wx * wz)
	elif d_d > 0.0:
		drop = d_d * (a * b)
	return h - drop

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

# Whether the edge of cell (cx,cz) toward `d` carries a rock wall + grass lip (a CLIFF EDGE)
# rather than a walkable slope. A ≥2 drop is always a cliff. A 1-storey drop is a cliff only when
# it is COLLINEAR with a ≥2 cliff — i.e. walking the cliff LINE (perpendicular to `d`) reaches a
# ≥2 drop before the drop tapers to 0. This lets a cliff continue as ONE edge down its tapering
# 1-storey end (owner: "continue the cliff edge … until the slope merges with the flat surface")
# while a lone 1-storey drop, not in line with any cliff, stays a slope.
static func _is_wall_edge(region, cx: int, cz: int, d: Vector2i) -> bool:
	var drop := int(region.storey_at(cx, cz)) - int(region.storey_at(cx + d.x, cz + d.y))
	if drop >= 2:
		return true
	if drop != 1:
		return false
	var p := Vector2i(d.y, d.x)   # along the cliff line (perpendicular to the drop)
	for step: Vector2i in [p, -p]:
		var k := 1
		while k < 12:
			var ax: int = cx + step.x * k
			var az: int = cz + step.y * k
			var dd := int(region.storey_at(ax, az)) - int(region.storey_at(ax + d.x, az + d.y))
			if dd <= 0:
				break          # the cliff line ended (flat) on this side
			if dd >= 2:
				return true     # reached the ≥2 cliff → this 1-storey step is part of it
			k += 1
	return false

static func surface_y(region, x: float, z: float) -> float:
	var cx := _cell_of(x)
	var cz := _cell_of(z)
	var h: float = region.surface_height(cx, cz)
	var s := int(region.storey_at(cx, cz))
	var lx := x - float(cx) * TILE
	var lz := z - float(cz) * TILE
	var dx_sign := 1 if lx >= 0.0 else -1
	var dz_sign := 1 if lz >= 0.0 else -1
	var a := _edge_weight(lx * float(dx_sign))                 # weight toward facing x-edge
	var b := _edge_weight(lz * float(dz_sign))                 # weight toward facing z-edge
	# Ramp DOWN toward a lower neighbour ONLY across a walkable SLOPE edge; a CLIFF edge stays
	# flat (the rock wall takes the whole drop). This makes a cell flat on its cliff sides and
	# sloped on its slope sides — so a cliff edge can run on while the perpendicular side slopes.
	var d_x := 0.0
	if not _is_wall_edge(region, cx, cz, Vector2i(dx_sign, 0)):
		d_x = maxf(0.0, h - region.surface_height(cx + dx_sign, cz))
	var d_z := 0.0
	if not _is_wall_edge(region, cx, cz, Vector2i(0, dz_sign)):
		d_z = maxf(0.0, h - region.surface_height(cx, cz + dz_sign))
	# Diagonal: ramp into a concave (≤1) corner; a ≥2 diagonal is an inner-corner cliff (flat).
	var d_d := 0.0
	if s - int(region.storey_at(cx + dx_sign, cz + dz_sign)) < 2:
		d_d = maxf(0.0, h - region.surface_height(cx + dx_sign, cz + dz_sign))
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

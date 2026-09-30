# scripts/terrain/field/TerrainSurfaceField.gd
# TEMPORARY forwarding facade over TerrainTileField (dual-grid terrain tiles,
# docs/superpowers/specs/2026-09-30-dual-grid-terrain-tiles-design.md). It keeps
# the function names the rest of the codebase calls, with POINT semantics: the
# region's integer coordinates are 12 m lattice points, and "cell" parameters
# below name the point whose 12 m dual cell is meant. No kernel math lives here;
# this class is deleted once the callers are renamed.
#
# NOT the 24 m route/settlement lattice: road, settlement and village code uses
# HeightfieldPlan.CELL (24 m) for that; TILE/HALF here are the terrain kernel's
# 12 m tile and its half.
class_name TerrainSurfaceField
extends RefCounted

const TILE := 12.0
const HALF := TILE * 0.5   # 6.0
const STOREY := 4.0
## A neighbour surface this far below a point's flat top exposes the boundary.
const EXPOSE_EPS := 0.25


static func tile_size(region = null) -> float:
	## A region may expose another deterministic lattice (village benches) through
	## terrain_tile_size(); the kernel owns that lookup.
	return TerrainTileField.spacing(region)


## Index of the lattice point whose dual cell contains coordinate v.
static func _cell_of(v: float, region = null) -> int:
	return TerrainTileField.point_of(v, region)


## One physical transition profile for natural slopes and sealed ground edits:
## a smootherstep over `width`, by default one whole tile (12 m).
static func transition_weight(distance: float, width: float = TILE) -> float:
	return SlopeProfile.smootherstep(clampf(distance / width, 0.0, 1.0))


# --- edges -----------------------------------------------------------------------

static func is_cliff_edge(region, cx: int, cz: int, d: Vector2i) -> bool:
	return TerrainTileField.is_cliff_edge(region, Vector2i(cx, cz), d)


## The HIGH side of a cliff edge: the edges that carry a vertical rock face.
static func is_wall_edge(region, cx: int, cz: int, d: Vector2i) -> bool:
	return TerrainTileField.is_wall_edge(region, Vector2i(cx, cz), d)


## Walkability of a lattice edge is exactly "not a cliff edge".
static func is_walkable_edge(region, point: Vector2i, d: Vector2i) -> bool:
	return TerrainTileField.is_walkable_edge(region, point, d)


# --- sampling -------------------------------------------------------------------------

static func surface_y(region, x: float, z: float) -> float:
	return TerrainTileField.surface_y(region, x, z)


## Height at (x, z) as seen from lattice point (cx, cz): a wall on its dual
## cell's border resolves to that point's side.
static func surface_y_in_cell(region, x: float, z: float, cx: int, cz: int) -> float:
	return TerrainTileField.surface_y_on_side(region, x, z, Vector2i(cx, cz))


static func _apply_grade(region, x: float, z: float, height: float) -> float:
	return TerrainTileField._apply_grade(region, x, z, height)


static func bake_cell(region, cx: int, cz: int) -> PackedFloat32Array:
	return TerrainTileField.bake_point(region, Vector2i(cx, cz))


static func sample_baked(baked: PackedFloat32Array, cx: int, cz: int,
		x: float, z: float, region = null) -> float:
	return TerrainTileField.sample_baked(baked, Vector2i(cx, cz), x, z, region)


# --- bounds -------------------------------------------------------------------------------

## Conservative extrema over a world rectangle (kernel proof; exact on flat,
## slope-only and pure-cliff tiles).
static func height_bounds(region, footprint: Rect2) -> Vector2:
	return TerrainTileField.height_bounds(region, footprint)


## One-sided support at a deliberately multi-valued cliff boundary. `owner` is a
## lattice POINT; its dual cell is the 12 m square centred on it, and the
## footprint must lie inside that square. A neighbouring wall contributes no
## second top: the kernel evaluates the owner's four quadrant tiles on the
## owner's side (exact on flat, slope-only and pure-cliff tiles, conservative
## over a mixed cliff/slope layer).
static func height_bounds_in_cell(region, footprint: Rect2, owner: Vector2i) -> Vector2:
	return TerrainTileField.height_bounds_on_side(region, footprint, owner)


# --- dual-cell border profiles (village turf rims, cliff skirts) -----------------------

## The NEIGHBOUR's surface sampled along the shared border of point (cx, cz)
## toward d: samples+1 heights ordered along pdir=(d.y,d.x) from the -pdir end
## to the +pdir end (the same along-edge axis the mesher grid uses).
static func edge_profile(region, cx: int, cz: int, d: Vector2i, samples: int) -> PackedFloat32Array:
	return _border_profile(region, cx, cz, d, samples, Vector2i(cx + d.x, cz + d.y))


## The point's OWN surface along the same border (same ordering as edge_profile).
## Where the two differ the border is a wall: the face spans from this profile
## down to the neighbour's.
static func own_edge_profile(region, cx: int, cz: int, d: Vector2i, samples: int) -> PackedFloat32Array:
	return _border_profile(region, cx, cz, d, samples, Vector2i(cx, cz))


static func _border_profile(region, cx: int, cz: int, d: Vector2i, samples: int,
		owner: Vector2i) -> PackedFloat32Array:
	var span := tile_size(region)
	var half := span * 0.5
	var bx := float(cx) * span + float(d.x) * half
	var bz := float(cz) * span + float(d.y) * half
	var out := PackedFloat32Array()
	for i in samples + 1:
		var t := (float(i) / float(samples)) * 2.0 - 1.0
		out.append(surface_y_in_cell(region, bx + float(d.y) * half * t, bz + float(d.x) * half * t, owner.x, owner.y))
	return out


## The border of point (cx, cz) toward d is EXPOSED: its own surface is flat at
## the point's height along the whole border while the neighbour's falls at
## least EXPOSE_EPS below it somewhere. The dressable subset of the wall borders.
static func is_exposed_edge(region, cx: int, cz: int, d: Vector2i) -> bool:
	var h: float = region.surface_height(cx, cz)
	for f in own_edge_profile(region, cx, cz, d, 8):
		if f < h - 0.01:
			return false
	for f in edge_profile(region, cx, cz, d, 8):
		if f < h - EXPOSE_EPS:
			return true
	return false

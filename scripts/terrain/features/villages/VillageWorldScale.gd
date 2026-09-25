class_name VillageWorldScale
extends RefCounted

## One explicit conversion between the authored warren lattice and the world.
## The procedural proof plans on the 1.5 m authored lattice (fine cells and
## bands). The production frame maps it to the world with the METRIC OF THE
## ACTIVE BUILDING KIT: one fine cell holds one kit wall module and one storey
## (two bands) holds one kit storey. For the Suntail kit at 1.5x (2 m x 3 m
## native modules) that is 3 m horizontally and 2.25 m per band, so the frame
## is anisotropic. Two fine cells remain one warren macro cell, so every 6 m
## macro cell divides the terrain's canonical 24 m field cell exactly. Render,
## collision, occupancy, supports and terrain sampling all consume this frame;
## callers ask for the axis they mean (`scale_of` is horizontal,
## `vertical_scale_of` vertical). Rigid catalog assets that are not kit pieces
## keep a uniform look through `rigid_compensation`.
const AUTHORED_FINE_CELL_M := FabricRecipe.CELL_SIZE
const AUTHORED_MACRO_CELL_M := WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M
const AUTHORED_BAND_M := WarrenVolumePlan.VERTICAL_BAND_SIZE_M
## World metres per native metre of the active kit (Suntail).
const KIT_WORLD_SCALE := 1.5
## Kit module 2 m x 1.5 / 1.5 m fine cell.
const HORIZONTAL_SCALE := 2.0
## Kit band 1.5 m x 1.5 / 1.5 m band.
const VERTICAL_SCALE := 1.5
## Legacy name, now the horizontal lattice scale.
const PRODUCTION_UNIFORM_SCALE := HORIZONTAL_SCALE
## Structural surfaces sit above the finished ground by this world-space guard.
## A stair's first riser must include that approach difference in its budget.
const GROUND_DATUM_GUARD := 0.08
const WORLD_FINE_CELL_M := AUTHORED_FINE_CELL_M * HORIZONTAL_SCALE
const WORLD_MACRO_CELL_M := AUTHORED_MACRO_CELL_M * HORIZONTAL_SCALE
const WORLD_BAND_M := AUTHORED_BAND_M * VERTICAL_SCALE
const TERRAIN_FIELD_CELL_M := HeightfieldPlan.TILE


static func validate() -> bool:
	return is_equal_approx(AUTHORED_MACRO_CELL_M,
		AUTHORED_FINE_CELL_M * 2.0) \
		and is_equal_approx(WORLD_FINE_CELL_M, 3.0) \
		and is_equal_approx(WORLD_MACRO_CELL_M, 6.0) \
		and is_zero_approx(fmod(TERRAIN_FIELD_CELL_M, WORLD_MACRO_CELL_M))


## True when the frame constants realize `kit` at KIT_WORLD_SCALE.
static func matches_kit(kit: BuildingKit) -> bool:
	return is_equal_approx(kit.module_width * KIT_WORLD_SCALE, WORLD_FINE_CELL_M) \
		and is_equal_approx(kit.band_height() * KIT_WORLD_SCALE, WORLD_BAND_M)


static func frame_scale() -> Vector3:
	return Vector3(HORIZONTAL_SCALE, VERTICAL_SCALE, HORIZONTAL_SCALE)


static func production_basis(yaw: float) -> Basis:
	assert(validate())
	return Basis(Vector3.UP, yaw).scaled(frame_scale())


## Horizontal world metres per authored metre.
static func scale_of(world_frame: Transform3D) -> float:
	var scale := world_frame.basis.get_scale()
	assert(is_equal_approx(scale.x, scale.z))
	return scale.x


## Vertical world metres per authored metre.
static func vertical_scale_of(world_frame: Transform3D) -> float:
	return world_frame.basis.get_scale().y


## Authored-space correction that keeps a rigid (non-kit) catalog asset at a
## uniform HORIZONTAL_SCALE look once the anisotropic frame is applied. Valid
## for yaw-only authored placements; apply on the right of the local basis.
static func rigid_compensation() -> Basis:
	return Basis.from_scale(Vector3(1.0, HORIZONTAL_SCALE / VERTICAL_SCALE, 1.0))

class_name VillageWorldScale
extends RefCounted

## One explicit conversion between the authored warren lattice and the world.
## The procedural proof plans on the 1.5 m authored lattice (fine cells and
## bands). The production frame maps it to the world with the METRIC OF THE
## ACTIVE BUILDING KIT: one fine cell holds one kit wall module and one storey
## (two bands) holds one kit storey. For the Suntail kit at 2x (2 m x 3 m
## native modules) that is 4 m horizontally and 3 m per band, so the frame is
## anisotropic (x8/3 horizontal, x2 vertical). Two fine cells remain one warren
## macro cell, so every 8 m macro cell divides the terrain's canonical 24 m
## field cell exactly (three per field cell): the September 27 upscale is the
## only 25-50% enlargement that keeps that grid alignment. Render, collision,
## occupancy, supports and terrain sampling all consume this frame; callers
## ask for the axis they mean (`scale_of` is horizontal, `vertical_scale_of`
## vertical). Rigid catalog assets that are not kit pieces keep a uniform look
## through `rigid_compensation`.
const AUTHORED_FINE_CELL_M := FabricRecipe.CELL_SIZE
const AUTHORED_MACRO_CELL_M := WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M
const AUTHORED_BAND_M := WarrenVolumePlan.VERTICAL_BAND_SIZE_M
## World metres per native metre of the active kit (Suntail).
const KIT_WORLD_SCALE := 2.0
## Native Suntail module width and band height (see `SuntailBuildingKit`).
const KIT_MODULE_M := 2.0
const KIT_BAND_M := 1.5
## Kit module 2 m x 2 / 1.5 m fine cell = 8/3.
const HORIZONTAL_SCALE := KIT_MODULE_M * KIT_WORLD_SCALE / AUTHORED_FINE_CELL_M
## Kit band 1.5 m x 2 / 1.5 m band = 2.
const VERTICAL_SCALE := KIT_BAND_M * KIT_WORLD_SCALE / AUTHORED_BAND_M
## Legacy name, now the horizontal lattice scale.
const PRODUCTION_UNIFORM_SCALE := HORIZONTAL_SCALE
## Structural surfaces sit above the finished ground by this world-space guard.
## A stair's first riser must include that approach difference in its budget.
const GROUND_DATUM_GUARD := 0.08
const WORLD_FINE_CELL_M := AUTHORED_FINE_CELL_M * HORIZONTAL_SCALE
const WORLD_MACRO_CELL_M := AUTHORED_MACRO_CELL_M * HORIZONTAL_SCALE
const WORLD_BAND_M := AUTHORED_BAND_M * VERTICAL_SCALE
const TERRAIN_FIELD_CELL_M := HeightfieldPlan.CELL


static func validate() -> bool:
	return is_equal_approx(AUTHORED_MACRO_CELL_M,
		AUTHORED_FINE_CELL_M * 2.0) \
		and is_equal_approx(WORLD_FINE_CELL_M, 4.0) \
		and is_equal_approx(WORLD_MACRO_CELL_M, 8.0) \
		and is_equal_approx(WORLD_BAND_M, 3.0) \
		and is_equal_approx(TERRAIN_FIELD_CELL_M / WORLD_MACRO_CELL_M,
			roundf(TERRAIN_FIELD_CELL_M / WORLD_MACRO_CELL_M))


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


## Human-scale props (barrels, crates, buckets, bags, benches, chairs,
## lanterns, potted plants, flowers) serve the player, whose size never
## changed. They keep the world size they had before the September 27 frame
## upscale: legacy catalog props at the old 2x, kit props at the old 1.5x.
## Architecture and civic features (stalls, wells, fires, planters) scale
## with the town.
const HUMAN_PROP_WORLD_SCALE := 2.0
const KIT_HUMAN_PROP_WORLD_SCALE := 1.5


## Native scale applied to a kit human prop inside a kit-frame placement.
static func kit_human_prop_scale() -> float:
	return KIT_HUMAN_PROP_WORLD_SCALE / KIT_WORLD_SCALE


## Authored-space correction for a rigid legacy human prop: uniform at
## HUMAN_PROP_WORLD_SCALE once the anisotropic frame is applied. Its catalog
## pivot is at its base, so it shrinks toward its ground contact.
static func human_prop_compensation() -> Basis:
	var k := HUMAN_PROP_WORLD_SCALE / HORIZONTAL_SCALE
	return rigid_compensation().scaled(Vector3.ONE * k)


## Authored-space correction that keeps a rigid (non-kit) catalog asset at a
## uniform HORIZONTAL_SCALE look once the anisotropic frame is applied. Valid
## for yaw-only authored placements; apply on the right of the local basis.
static func rigid_compensation() -> Basis:
	return Basis.from_scale(Vector3(1.0, HORIZONTAL_SCALE / VERTICAL_SCALE, 1.0))

class_name VillageWorldScale
extends RefCounted

## One explicit conversion between the authored warren lattice and the world.
## The procedural proof continues to use the measured 1.5 m asset lattice; the
## production frame maps it to the 3 m world fine lattice. Two fine cells remain
## one warren macro cell, so every 6 m macro cell divides the terrain's canonical
## 24 m field cell exactly. Render, collision, occupancy, supports, and terrain
## sampling all consume this same transform.
const AUTHORED_FINE_CELL_M := FabricRecipe.CELL_SIZE
const AUTHORED_MACRO_CELL_M := WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M
const PRODUCTION_UNIFORM_SCALE := 2.0
const WORLD_FINE_CELL_M := AUTHORED_FINE_CELL_M * PRODUCTION_UNIFORM_SCALE
const WORLD_MACRO_CELL_M := AUTHORED_MACRO_CELL_M * PRODUCTION_UNIFORM_SCALE
const TERRAIN_FIELD_CELL_M := HeightfieldPlan.TILE


static func validate() -> bool:
	return is_equal_approx(AUTHORED_MACRO_CELL_M,
		AUTHORED_FINE_CELL_M * 2.0) \
		and is_equal_approx(WORLD_FINE_CELL_M, 3.0) \
		and is_equal_approx(WORLD_MACRO_CELL_M, 6.0) \
		and is_zero_approx(fmod(TERRAIN_FIELD_CELL_M, WORLD_MACRO_CELL_M))


static func production_basis(yaw: float) -> Basis:
	assert(validate())
	return Basis(Vector3.UP, yaw).scaled(
		Vector3.ONE * PRODUCTION_UNIFORM_SCALE)


static func scale_of(world_frame: Transform3D) -> float:
	var scale := world_frame.basis.get_scale()
	assert(is_equal_approx(scale.x, scale.y)
		and is_equal_approx(scale.x, scale.z))
	return scale.x

# Pure, reusable force laws for bodies interacting with the continuous water
# field.  Nothing here knows about CharacterBody3D, input, scene nodes, or the
# terrain streamer: future props can sample the same WaterSampler and apply
# these accelerations through their own integration adapter.
class_name WaterForces
extends RefCounted


## Fraction of a vertical body column below the local dynamic surface.
static func submerged_fraction(surface_y: float, body_bottom_y: float,
		body_height: float) -> float:
	if body_height <= 0.0:
		return 0.0
	return clampf((surface_y - body_bottom_y) / body_height, 0.0, 1.0)


## Archimedes-style acceleration opposite gravity, proportional to displaced
## body fraction. max_acceleration is the full-submersion lift supplied by a
## body's volume-to-mass ratio; it must exceed gravity for that body to float.
static func buoyancy_acceleration(gravity: Vector3, max_acceleration: float,
		submerged: float) -> Vector3:
	if gravity.is_zero_approx() or max_acceleration <= 0.0:
		return Vector3.ZERO
	return -gravity.normalized() * max_acceleration * clampf(submerged, 0.0, 1.0)


## Linear hydrodynamic drag toward the local horizontal water velocity.  It is
## zero for a body already travelling with the current and therefore cannot
## invent speed independently of the shared WaterSampler field.
static func current_acceleration(current: Vector2, body_velocity: Vector2,
		drag: float) -> Vector2:
	return (current - body_velocity) * maxf(drag, 0.0)


## Linear drag against vertical motion; kept separate because the current
## field is horizontal today while surface entry/plunge still needs damping.
static func vertical_drag_acceleration(vertical_velocity: float,
		drag: float) -> float:
	return -vertical_velocity * maxf(drag, 0.0)

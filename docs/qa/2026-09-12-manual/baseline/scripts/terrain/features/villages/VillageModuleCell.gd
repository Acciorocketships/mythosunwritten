class_name VillageModuleCell
extends RefCounted

## One exact cell in a reviewed fixed-module oriented rectangle. Structural
## planners share this fact so cores, skirts, platforms, and later railings do
## not each invent subtly different grid math.
var coordinate: Vector2i
var centre: Vector2
var half_extents: Vector2
var yaw: float


func _init(p_coordinate: Vector2i, p_centre: Vector2,
		p_half_extents: Vector2, p_yaw: float) -> void:
	assert(p_centre.is_finite() and p_half_extents.is_finite())
	assert(p_half_extents.x > 0.0 and p_half_extents.y > 0.0)
	assert(is_finite(p_yaw))
	coordinate = p_coordinate
	centre = p_centre
	half_extents = p_half_extents
	yaw = p_yaw


func shape() -> FeatureGroundShape:
	return FeatureGroundShape.oriented_rect(centre, half_extents, yaw)


func corners() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for local: Vector2 in [
			Vector2(-half_extents.x, -half_extents.y),
			Vector2(half_extents.x, -half_extents.y),
			Vector2(half_extents.x, half_extents.y),
			Vector2(-half_extents.x, half_extents.y)]:
		out.append(centre + local.rotated(yaw))
	return out

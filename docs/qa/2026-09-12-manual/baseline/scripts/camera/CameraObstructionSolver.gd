class_name CameraObstructionSolver
extends RefCounted

## General camera-space collision adapter. A single swept sphere resolves both
## ceiling-constrained framing and the third-person boom, so buildings, cliffs,
## decks, and future interiors share exactly the same obstruction semantics.
var collision_mask: int
var query_margin: float
var skin: float
var _shape: SphereShape3D

func _init(radius: float = 0.28, p_collision_mask: int = 1,
		p_query_margin: float = 0.02, p_skin: float = 0.05) -> void:
	assert(is_finite(radius) and radius > 0.0)
	assert(p_collision_mask > 0)
	assert(is_finite(p_query_margin) and p_query_margin >= 0.0)
	assert(is_finite(p_skin) and p_skin >= 0.0)
	collision_mask = p_collision_mask
	query_margin = p_query_margin
	skin = p_skin
	_shape = SphereShape3D.new()
	_shape.radius = radius

func resolve_ceiling(space: PhysicsDirectSpaceState3D, target: Vector3,
		minimum_height: float, desired_height: float,
		exclude: Array[RID] = []) -> Vector3:
	assert(space != null)
	assert(is_finite(minimum_height) and is_finite(desired_height))
	assert(minimum_height >= 0.0 and desired_height >= minimum_height)
	var start := target + Vector3.UP * minimum_height
	var desired := target + Vector3.UP * desired_height
	return _resolve_motion(space, start, desired, exclude)

func resolve_boom(space: PhysicsDirectSpaceState3D, pivot: Vector3,
		desired_camera: Vector3, exclude: Array[RID] = []) -> Vector3:
	assert(space != null)
	return _resolve_motion(space, pivot, desired_camera, exclude)

func radius() -> float:
	return _shape.radius

func _resolve_motion(space: PhysicsDirectSpaceState3D, start: Vector3,
		desired: Vector3, exclude: Array[RID]) -> Vector3:
	var motion := desired - start
	var length := motion.length()
	if length <= 0.000001:
		return start
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = Transform3D(Basis.IDENTITY, start)
	query.motion = motion
	query.margin = query_margin
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = exclude
	var result := space.cast_motion(query)
	var safe_fraction := clampf(float(result[0]), 0.0, 1.0) \
		if not result.is_empty() else 1.0
	if safe_fraction >= 1.0:
		return desired
	var skin_fraction := skin / length
	return start + motion * maxf(0.0, safe_fraction - skin_fraction)

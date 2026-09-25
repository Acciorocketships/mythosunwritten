class_name VillageStreetSpec
extends RefCounted

## One immutable segment in the village-local orthogonal street graph.
## Streets, frontage lots, props, and elevated districts all consume this
## shared coordinate frame; no caller reconstructs a radial layout.
var stable_key: StringName
var local_start: Vector2
var local_end: Vector2


static func compile(data: Dictionary) -> VillageStreetSpec:
	var spec := VillageStreetSpec.new()
	spec.stable_key = StringName(data.get("key", ""))
	spec.local_start = _vector2(data.get("start", null))
	spec.local_end = _vector2(data.get("end", null))
	var delta := spec.local_end - spec.local_start
	if spec.stable_key.is_empty() or not spec.local_start.is_finite() \
			or not spec.local_end.is_finite() or delta.length() < 3.0 \
			or (not is_zero_approx(delta.x) and not is_zero_approx(delta.y)) \
			or not _module_aligned(spec.local_start) \
			or not _module_aligned(spec.local_end):
		push_error("Village streets must be finite, module-aligned orthogonal segments")
		return null
	if maxf(spec.local_start.length(), spec.local_end.length()) \
			> VillageProgram.MAX_ANCHOR_RADIUS:
		push_error("Village street exceeds the compiled anchor radius")
		return null
	return spec


func length() -> float:
	return local_start.distance_to(local_end)


func local_tangent() -> Vector2:
	return (local_end - local_start).normalized()


func local_point(distance: float) -> Vector2:
	assert(distance >= 0.0 and distance <= length())
	return local_start + local_tangent() * distance


func world_segment(centre: Vector2, x_axis: Vector2) -> Dictionary:
	assert(x_axis.is_normalized())
	var z_axis := Vector2(-x_axis.y, x_axis.x)
	return {
		"start": centre + x_axis * local_start.x + z_axis * local_start.y,
		"end": centre + x_axis * local_end.x + z_axis * local_end.y,
	}


func world_point(centre: Vector2, x_axis: Vector2,
		distance: float) -> Vector2:
	var local := local_point(distance)
	var z_axis := Vector2(-x_axis.y, x_axis.x)
	return centre + x_axis * local.x + z_axis * local.y


func world_tangent(x_axis: Vector2) -> Vector2:
	var local := local_tangent()
	var z_axis := Vector2(-x_axis.y, x_axis.x)
	return (x_axis * local.x + z_axis * local.y).normalized()


static func _vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(INF, INF)


static func _module_aligned(point: Vector2) -> bool:
	return absf(point.x / VillageProgram.MODULE \
		- roundf(point.x / VillageProgram.MODULE)) <= 0.001 \
		and absf(point.y / VillageProgram.MODULE \
		- roundf(point.y / VillageProgram.MODULE)) <= 0.001

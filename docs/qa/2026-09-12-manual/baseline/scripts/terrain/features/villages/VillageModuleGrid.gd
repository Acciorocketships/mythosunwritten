class_name VillageModuleGrid
extends RefCounted

## Deterministic tiling and proof samples for fixed-module oriented rectangles.
const EPS := 0.001


static func cells(rect: Dictionary, module_size: float
		) -> Array[VillageModuleCell]:
	assert(module_size > 0.0)
	var half: Vector2 = rect.half_extents
	var x_count := roundi(half.x * 2.0 / module_size)
	var z_count := roundi(half.y * 2.0 / module_size)
	if x_count <= 0 or z_count <= 0 \
			or absf(float(x_count) * module_size - half.x * 2.0) > EPS \
			or absf(float(z_count) * module_size - half.y * 2.0) > EPS:
		return []
	var yaw := float(rect.angle)
	var axis_x := Vector2.RIGHT.rotated(yaw)
	var axis_z := Vector2.DOWN.rotated(yaw)
	var out: Array[VillageModuleCell] = []
	for z in z_count:
		for x in x_count:
			var local := Vector2(
				(float(x) + 0.5) * module_size - half.x,
				(float(z) + 0.5) * module_size - half.y)
			out.append(VillageModuleCell.new(Vector2i(x, z),
				rect.centre + axis_x * local.x + axis_z * local.y,
				Vector2.ONE * module_size * 0.5, yaw))
	return out


static func proof_samples(rect: Dictionary,
		maximum_spacing: float) -> Array[Vector2]:
	assert(maximum_spacing > 0.0)
	var half: Vector2 = rect.half_extents
	var x_steps := maxi(1, ceili(half.x * 2.0 / maximum_spacing))
	var z_steps := maxi(1, ceili(half.y * 2.0 / maximum_spacing))
	var yaw := float(rect.angle)
	var axis_x := Vector2.RIGHT.rotated(yaw)
	var axis_z := Vector2.DOWN.rotated(yaw)
	var out: Array[Vector2] = []
	for z in z_steps + 1:
		for x in x_steps + 1:
			var local := Vector2(
				lerpf(-half.x, half.x, float(x) / float(x_steps)),
				lerpf(-half.y, half.y, float(z) / float(z_steps)))
			out.append(rect.centre + axis_x * local.x + axis_z * local.y)
	return out

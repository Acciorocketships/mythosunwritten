# Pure finite-support current projection for the unified water surface.
#
# The hydraulic network supplies a desired downstream tangent and speed. This
# class only applies local, continuous constraints: dry samples are zero and a
# signed wet-depth gradient removes velocity entering a bank. Because every
# retained sample depends on one immediate world-aligned neighbourhood, a
# two-cell caller halo is sufficient for bit-identical chunk borders.
class_name WaterCurrentField
extends Object

const BANK_BAND := 4.5
const SDF_RADIUS := 2


## Finite-support signed distance to the wet/dry boundary. Positive values
## are wet, negative values are dry, and the magnitude is capped at the
## two-cell support radius. Callers solve with the same two-cell halo, so a
## retained border sample is identical regardless of which chunk owns it.
static func signed_distance(wet: PackedByteArray, nx: int, nz: int,
		step: float) -> PackedFloat32Array:
	assert(wet.size() == nx * nz)
	var out := PackedFloat32Array()
	out.resize(nx * nz)
	var far: float = (float(SDF_RADIUS) + 0.5) * step
	for j in nz:
		for i in nx:
			var k: int = j * nx + i
			var is_wet: bool = wet[k] != 0
			var nearest: float = far
			for dz in range(-SDF_RADIUS, SDF_RADIUS + 1):
				for dx in range(-SDF_RADIUS, SDF_RADIUS + 1):
					var x: int = i + dx
					var z: int = j + dz
					if x < 0 or z < 0 or x >= nx or z >= nz:
						continue
					if (wet[z * nx + x] != 0) == is_wet:
						continue
					nearest = minf(nearest, Vector2(dx, dz).length() * step)
			out[k] = nearest if is_wet else -nearest
	return out


## A readable current exists on every traced reach. Grade adds urgency; it is
## never a presence gate. Values are world metres per second.
static func trace_speed(depth: float, half_width: float, grade: float) -> float:
	if depth <= 0.0 or half_width <= 0.0:
		return 0.0
	var depth_term: float = sqrt(clampf(depth / 3.0, 0.0, 1.5))
	var width_term: float = sqrt(clampf(half_width / 12.0, 0.0, 1.5))
	var grade_term: float = sqrt(maxf(grade, 0.0))
	return clampf(1.8 + depth_term * 0.35 + width_term * 0.30
		+ grade_term * 2.8, 1.4, 6.5)


## desired and signed_depth are row-major nx*nz arrays. Positive signed depth
## means water; negative means bank/dry ground. Returned diagnostics are paired
## with the velocity and are visual-generation fields, not another water mask.
static func solve_local(desired: PackedVector2Array,
		signed_depth: PackedFloat32Array, nx: int, nz: int,
		step: float) -> Dictionary:
	assert(nx > 0 and nz > 0 and step > 0.0)
	assert(desired.size() == nx * nz)
	assert(signed_depth.size() == nx * nz)
	var velocity := PackedVector2Array()
	velocity.resize(nx * nz)
	for k in nx * nz:
		velocity[k] = desired[k] if signed_depth[k] > 0.0 else Vector2.ZERO
	_project_banks(velocity, signed_depth, nx, nz, step)
	var diagnostics: Dictionary = _diagnostics(velocity, signed_depth, nx, nz, step)
	return {
		"velocity": velocity,
		"vorticity": diagnostics.vorticity,
		"compression": diagnostics.compression,
	}


static func _project_banks(velocity: PackedVector2Array,
		signed_depth: PackedFloat32Array, nx: int, nz: int,
		step: float) -> void:
	for j in nz:
		for i in nx:
			var k: int = j * nx + i
			if signed_depth[k] <= 0.0:
				velocity[k] = Vector2.ZERO
				continue
			if signed_depth[k] >= BANK_BAND:
				continue
			var inward: Vector2 = _gradient(signed_depth, nx, nz, i, j, step)
			if inward.length_squared() <= 0.000001:
				continue
			inward = inward.normalized()
			var entering_bank: float = velocity[k].dot(inward)
			if entering_bank < 0.0:
				velocity[k] -= inward * entering_bank


static func _gradient(values: PackedFloat32Array, nx: int, nz: int,
		i: int, j: int, step: float) -> Vector2:
	var center: float = values[j * nx + i]
	var left: float = _sample_scalar(values, nx, nz, i - 1, j, center)
	var right: float = _sample_scalar(values, nx, nz, i + 1, j, center)
	var down: float = _sample_scalar(values, nx, nz, i, j - 1, center)
	var up: float = _sample_scalar(values, nx, nz, i, j + 1, center)
	return Vector2(right - left, up - down) / (2.0 * step)


static func _diagnostics(velocity: PackedVector2Array,
		signed_depth: PackedFloat32Array, nx: int, nz: int,
		step: float) -> Dictionary:
	var vorticity := PackedFloat32Array()
	var compression := PackedFloat32Array()
	vorticity.resize(nx * nz)
	compression.resize(nx * nz)
	for j in nz:
		for i in nx:
			var k: int = j * nx + i
			if signed_depth[k] <= 0.0:
				continue
			var center: Vector2 = velocity[k]
			var left: Vector2 = _sample_velocity(velocity, signed_depth,
				nx, nz, i - 1, j, center)
			var right: Vector2 = _sample_velocity(velocity, signed_depth,
				nx, nz, i + 1, j, center)
			var down: Vector2 = _sample_velocity(velocity, signed_depth,
				nx, nz, i, j - 1, center)
			var up: Vector2 = _sample_velocity(velocity, signed_depth,
				nx, nz, i, j + 1, center)
			var du_dx: float = (right.x - left.x) / (2.0 * step)
			var du_dz: float = (up.x - down.x) / (2.0 * step)
			var dv_dx: float = (right.y - left.y) / (2.0 * step)
			var dv_dz: float = (up.y - down.y) / (2.0 * step)
			vorticity[k] = dv_dx - du_dz
			compression[k] = maxf(0.0, -(du_dx + dv_dz))
	return {"vorticity": vorticity, "compression": compression}


static func _sample_scalar(values: PackedFloat32Array, nx: int, nz: int,
		i: int, j: int, fallback: float) -> float:
	if i < 0 or j < 0 or i >= nx or j >= nz:
		return fallback
	return values[j * nx + i]


static func _sample_velocity(values: PackedVector2Array,
		signed_depth: PackedFloat32Array, nx: int, nz: int,
		i: int, j: int, fallback: Vector2) -> Vector2:
	if i < 0 or j < 0 or i >= nx or j >= nz:
		return fallback
	var k: int = j * nx + i
	return values[k] if signed_depth[k] > 0.0 else fallback

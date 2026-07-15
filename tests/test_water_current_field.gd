extends GutTest


func test_flat_reach_has_a_readable_base_current() -> void:
	var speed: float = WaterCurrentField.trace_speed(2.0, 8.0, 0.0)
	assert_true(speed >= 2.0,
		"flat traced water visibly travels downstream (%.3fm/s >= 2.0m/s)" % speed)


func test_signed_distance_is_continuous_across_a_bank() -> void:
	var wet := PackedByteArray([0, 0, 1, 1, 1])
	var sdf: PackedFloat32Array = WaterCurrentField.signed_distance(wet, 5, 1, 1.0)
	assert_true(sdf[1] < 0.0 and sdf[2] > 0.0,
		"the bank field changes sign at the wet boundary")
	assert_almost_eq(absf(sdf[1]), absf(sdf[2]), 0.001,
		"the boundary has symmetric finite support")


func test_dry_samples_are_zero_and_bank_entering_velocity_is_removed() -> void:
	var nx := 5
	var nz := 3
	var desired := PackedVector2Array()
	var sdf := PackedFloat32Array()
	desired.resize(nx * nz)
	sdf.resize(nx * nz)
	for j in nz:
		for i in nx:
			var k: int = j * nx + i
			desired[k] = Vector2(-1.0, 0.0)
			sdf[k] = -1.0 if i == 0 else float(i)
	var solved: Dictionary = WaterCurrentField.solve_local(desired, sdf, nx, nz, 1.0)
	assert_eq(solved.velocity[1 * nx], Vector2.ZERO, "dry bank velocity is zero")
	assert_true(solved.velocity[1 * nx + 1].x >= -0.001,
		"wet velocity cannot enter the adjacent dry bank")


func test_diagnostics_report_a_bending_current() -> void:
	var nx := 5
	var nz := 5
	var desired := PackedVector2Array()
	var sdf := PackedFloat32Array()
	desired.resize(nx * nz)
	sdf.resize(nx * nz)
	for j in nz:
		for i in nx:
			var k: int = j * nx + i
			var p := Vector2(float(i - 2), float(j - 2))
			desired[k] = Vector2(-p.y, p.x).normalized()
			sdf[k] = 3.0
	var solved: Dictionary = WaterCurrentField.solve_local(desired, sdf, nx, nz, 1.0)
	assert_true(absf(solved.vorticity[2 * nx + 2]) > 0.1,
		"a turning field exposes vorticity for wave/foam shaping")

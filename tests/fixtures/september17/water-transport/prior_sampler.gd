extends WaterSampler
const PriorCurrent = preload("res://tests/fixtures/september17/water-transport/current_before.gd")
func velocity_at(p: Vector2) -> Vector2:
	var v := Vector2.ZERO
	for corner: Array in _corners(p):
		v += _velocity[corner[1]*_nx+corner[0]]*corner[2]
	return PriorCurrent.sample_surface_current(v,p,_current_surface_level_at)

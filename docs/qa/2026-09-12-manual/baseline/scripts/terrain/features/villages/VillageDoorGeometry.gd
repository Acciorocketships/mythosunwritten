class_name VillageDoorGeometry
extends RefCounted

## Shared facade-exit arithmetic for platforms and optional walkways. The
## reviewed doorway axis is extended only far enough to clear the conservative
## building solid plus one half construction module.


static func clear_departure(placement: VillageMassingPlacement,
		half_width: float) -> float:
	return solid_exit_distance(placement, half_width) \
		+ VillageProgram.MODULE * 0.5 + 0.001


static func solid_exit_distance(placement: VillageMassingPlacement,
		half_width: float) -> float:
	var local_start := (placement.entrance - placement.solid_centre).rotated(
		-placement.solid_angle)
	var local_direction := placement.entrance_outward.rotated(
		-placement.solid_angle)
	var half := placement.solid_half_extents + Vector2.ONE * (
		half_width + VillageMassingProgram.ACCESS_CLEARANCE)
	var exit_distance := INF
	for axis in 2:
		var direction := local_direction[axis]
		if absf(direction) <= 0.000001:
			continue
		var boundary := half[axis] if direction > 0.0 else -half[axis]
		var distance := (boundary - local_start[axis]) / direction
		if distance >= -0.0001:
			exit_distance = minf(exit_distance, distance)
	if not is_finite(exit_distance):
		exit_distance = 0.0
	return maxf(0.0, exit_distance)

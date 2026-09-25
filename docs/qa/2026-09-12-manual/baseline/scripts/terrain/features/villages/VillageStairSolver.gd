class_name VillageStairSolver
extends RefCounted

## One canonical fixed-stair arithmetic contract shared by every route family.
## Routers decide where a transition belongs; this solver decides whether the
## authored stair vocabulary can express its rise without illegal landings.


static func transition(rise: float, vocabulary: VillageElevatedProgram,
		maximum_count: int) -> Dictionary:
	assert(is_finite(rise) and rise >= 0.0)
	assert(vocabulary != null and maximum_count >= 0)
	if TraversalEnvelope.step_is_legal(rise):
		return {"count": 0, "residual": rise}
	var best: Dictionary = {}
	for count in range(1, maximum_count + 1):
		var residual := (rise \
			- float(count) * vocabulary.stair_aabb.size.y) * 0.5
		if not TraversalEnvelope.step_is_legal(residual):
			continue
		if best.is_empty() or absf(residual) < absf(float(best.residual)) \
				or (is_equal_approx(absf(residual),
					absf(float(best.residual))) and count < int(best.count)):
			best = {"count": count, "residual": residual}
	return best

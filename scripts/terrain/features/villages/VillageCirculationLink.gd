class_name VillageCirculationLink
extends RefCounted

## One traversable edge. Control points preserve the intended street/curve
## composition; dense samples are the conservative validation geometry.
enum Kind {
	ENTRANCE,
	GROUND_STREET,
	GROUND_STAIR,
	AERIAL_WALKWAY,
	SHARED_PLATFORM,
}

var stable_key: StringName
var kind: Kind
var from_key: StringName
var to_key: StringName
var control_points: Array[Vector3] = []
var samples: Array[Vector3] = []
var length: float = 0.0
var stair_count: int = 0
var residual_step: float = 0.0
var stair_transitions: Array[VillageStairTransition] = []
## Exact route-arclength runs proved by the route planner. Ground links carry
## one per terrain transition; a stepped aerial link carries its single flight.
## Materialization consumes these rather than trying to find room later.
var stair_intervals: Array[Vector2] = []


func _init(p_stable_key: StringName, p_kind: Kind,
		p_from_key: StringName, p_to_key: StringName) -> void:
	stable_key = p_stable_key
	kind = p_kind
	from_key = p_from_key
	to_key = p_to_key


func is_aerial() -> bool:
	return kind == Kind.AERIAL_WALKWAY or kind == Kind.SHARED_PLATFORM


func is_valid() -> bool:
	if stable_key.is_empty() or from_key.is_empty() or to_key.is_empty() \
			or from_key == to_key or control_points.size() < 2 \
			or samples.size() < 2 or not is_finite(length) or length <= 0.0 \
			or stair_count < 0 or not is_finite(residual_step) \
			or not TraversalEnvelope.step_is_legal(residual_step):
		return false
	for point: Vector3 in control_points:
		if not point.is_finite():
			return false
	for point: Vector3 in samples:
		if not point.is_finite():
			return false
	var transition_stairs := 0
	for transition: VillageStairTransition in stair_transitions:
		if not transition.is_valid(samples.size()):
			return false
		transition_stairs += transition.stair_count
	if not stair_transitions.is_empty() and transition_stairs != stair_count:
		return false
	if kind == Kind.GROUND_STAIR:
		if stair_intervals.size() != stair_transitions.size():
			return false
		var prior_end := -INF
		for interval: Vector2 in stair_intervals:
			if not interval.is_finite() or interval.x < -0.001 \
					or interval.y <= interval.x \
					or interval.x < prior_end \
						- VillageRouteGeometry.STAIR_RUN_SEAM_TOLERANCE:
				return false
			prior_end = interval.y
	elif is_aerial() and stair_count > 0:
		if stair_intervals.size() != 1:
			return false
		var interval := stair_intervals[0]
		if not interval.is_finite() or interval.x < -0.001 \
				or interval.y <= interval.x or interval.y > length + 0.001:
			return false
	elif not stair_intervals.is_empty():
		return false
	return true

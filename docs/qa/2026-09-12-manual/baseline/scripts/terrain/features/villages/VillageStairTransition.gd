class_name VillageStairTransition
extends RefCounted

## One fixed-module stair composition replacing a discontinuity between two
## adjacent validated route samples. Materialization never has to rediscover
## where a route changes height or how its residual landings were solved.
var segment_index: int
var stair_count: int
var signed_rise: float
var residual_step: float


func _init(p_segment_index: int, p_stair_count: int,
		p_signed_rise: float, p_residual_step: float) -> void:
	segment_index = p_segment_index
	stair_count = p_stair_count
	signed_rise = p_signed_rise
	residual_step = p_residual_step


func is_valid(sample_count: int) -> bool:
	return segment_index > 0 and segment_index < sample_count \
		and stair_count > 0 and is_finite(signed_rise) \
		and absf(signed_rise) > TraversalEnvelope.MAX_PLANNED_STEP \
		and TraversalEnvelope.step_is_legal(residual_step)


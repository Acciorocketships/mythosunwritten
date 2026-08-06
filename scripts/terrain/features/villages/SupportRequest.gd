class_name SupportRequest
extends RefCounted

## One atomic support group. Either every anchor obtains a legal fixed stack
## and all occupancy commits, or the solver returns no placements.
enum GroundReference {
	HIGHEST,
	LOWEST,
}

var stable_id: StringName
var anchors: Array[Vector2] = []
var target_y: float
var angle: float
var modules: Array[SupportModule] = []
var base_radius: float
var max_ground_span: float
var max_bottom_burial: float
var max_modules_per_stack: int
var ground_reference: GroundReference
var owner_id: StringName

func _init(p_stable_id: StringName, p_anchors: Array[Vector2],
		p_target_y: float, p_angle: float, p_modules: Array[SupportModule],
		p_base_radius: float, p_max_ground_span: float,
		p_max_bottom_burial: float, p_max_modules_per_stack: int = 8,
		p_ground_reference: GroundReference = GroundReference.HIGHEST,
		p_owner_id: StringName = &"") -> void:
	assert(not p_stable_id.is_empty() and not p_anchors.is_empty())
	assert(is_finite(p_target_y) and is_finite(p_angle))
	assert(not p_modules.is_empty() and p_base_radius > 0.0)
	assert(p_max_ground_span >= 0.0 and p_max_bottom_burial >= 0.0)
	assert(p_max_modules_per_stack > 0)
	assert(p_ground_reference >= GroundReference.HIGHEST \
		and p_ground_reference <= GroundReference.LOWEST)
	stable_id = p_stable_id
	anchors.assign(p_anchors)
	target_y = p_target_y
	angle = p_angle
	modules.assign(p_modules)
	base_radius = p_base_radius
	max_ground_span = p_max_ground_span
	max_bottom_burial = p_max_bottom_burial
	max_modules_per_stack = p_max_modules_per_stack
	ground_reference = p_ground_reference
	owner_id = p_owner_id

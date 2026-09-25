class_name FoundationRequest
extends RefCounted

## Resource-free authored metrics for one enterable ground-bearing structure.
## Dimensions are fixed-module compatible; the solver never rescales collision.
var stable_id: StringName
var centre: Vector2
var half_extents: Vector2
var angle: float
var interior_centre: Vector2
var interior_half_extents: Vector2
var interior_angle: float
var doorway_inside: Vector2
var doorway_outside: Vector2
var max_covered_depth: float
var module_id: StringName
var module_width: float
var module_depth: float
var module_height: float
var max_bottom_burial: float
var floor_guard: float
var opening_width: float
var module_axis: Vector2
var module_local_bottom_y: float
## Optional frozen finished-floor elevation. Legacy ground placement leaves
## this as NAN and lets the terrain bound choose the floor; terrain-led massing
## passes its already accepted elevation so support cannot silently move a
## building during materialization.
var target_floor_y: float

func _init(p_stable_id: StringName, p_centre: Vector2,
		p_half_extents: Vector2, p_angle: float,
		p_interior_centre: Vector2, p_interior_half_extents: Vector2,
		p_interior_angle: float, p_doorway_inside: Vector2,
		p_doorway_outside: Vector2, p_max_covered_depth: float,
		p_module_id: StringName, p_module_width: float,
		p_module_depth: float, p_module_height: float,
		p_max_bottom_burial: float = 1.0,
		p_floor_guard: float = 0.05,
		p_opening_width: float = TraversalEnvelope.MIN_APERTURE_WIDTH,
		p_module_axis: Vector2 = Vector2.RIGHT,
		p_module_local_bottom_y: float = 0.0,
		p_target_floor_y: float = NAN) -> void:
	assert(not p_stable_id.is_empty() and not p_module_id.is_empty())
	assert(p_half_extents.x > 0.0 and p_half_extents.y > 0.0)
	assert(p_interior_half_extents.x > 0.0 \
		and p_interior_half_extents.y > 0.0)
	assert(is_finite(p_angle) and is_finite(p_interior_angle) \
		and p_max_covered_depth > 0.0)
	assert(p_module_width > 0.0 and p_module_depth > 0.0 \
		and p_module_height > 0.0)
	assert(p_max_bottom_burial >= 0.0 and p_floor_guard > 0.0)
	assert(p_opening_width >= TraversalEnvelope.MIN_APERTURE_WIDTH)
	assert(p_module_axis.is_finite() \
		and is_equal_approx(p_module_axis.length(), 1.0))
	assert(is_finite(p_module_local_bottom_y))
	assert(is_finite(p_target_floor_y) or is_nan(p_target_floor_y))
	stable_id = p_stable_id
	centre = p_centre
	half_extents = p_half_extents
	angle = p_angle
	interior_centre = p_interior_centre
	interior_half_extents = p_interior_half_extents
	interior_angle = p_interior_angle
	doorway_inside = p_doorway_inside
	doorway_outside = p_doorway_outside
	max_covered_depth = p_max_covered_depth
	module_id = p_module_id
	module_width = p_module_width
	module_depth = p_module_depth
	module_height = p_module_height
	max_bottom_burial = p_max_bottom_burial
	floor_guard = p_floor_guard
	opening_width = p_opening_width
	module_axis = p_module_axis
	module_local_bottom_y = p_module_local_bottom_y
	target_floor_y = p_target_floor_y

func bounds_xz() -> Rect2:
	var cosine := absf(cos(interior_angle))
	var sine := absf(sin(interior_angle))
	var extent := Vector2(
		cosine * interior_half_extents.x \
			+ sine * interior_half_extents.y,
		sine * interior_half_extents.x \
			+ cosine * interior_half_extents.y)
	return Rect2(interior_centre - extent, extent * 2.0)

func corners() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for local: Vector2 in [
			Vector2(-half_extents.x, -half_extents.y),
			Vector2(half_extents.x, -half_extents.y),
			Vector2(half_extents.x, half_extents.y),
			Vector2(-half_extents.x, half_extents.y)]:
		out.append(centre + local.rotated(angle))
	return out

class_name VillageOccupancyVolume
extends RefCounted

## Immutable oriented prism used only by deterministic village layout. Runtime
## physics is compiled later from accepted assets; this is the planning truth.
var role: int
var centre: Vector2
var half_extents: Vector2
var angle: float
var y_range: Vector2
var stable_id: StringName
## Volumes emitted by one semantic structure may describe complementary
## fabric and access space. Ownership is explicit so a doorway can pass
## through its own building envelope without weakening conflicts globally.
var owner_id: StringName
## Walk surfaces can change structural owner at a doorway while remaining one
## connected public floor. A separate network identity admits only walk/walk
## overlap inside that declared union; it never weakens solid or headroom
## conflicts and therefore does not turn ownership into a global exception.
var walk_network_id: StringName

func _init(p_role: int, p_centre: Vector2, p_half_extents: Vector2,
		p_angle: float, y_min: float, y_max: float,
		p_stable_id: StringName, p_owner_id: StringName = &"",
		p_walk_network_id: StringName = &"") -> void:
	assert(p_half_extents.x > 0.0 and p_half_extents.y > 0.0)
	assert(is_finite(p_centre.x) and is_finite(p_centre.y))
	assert(is_finite(p_half_extents.x) and is_finite(p_half_extents.y))
	assert(is_finite(p_angle) and is_finite(y_min) and is_finite(y_max))
	assert(y_max > y_min)
	assert(not p_stable_id.is_empty())
	role = p_role
	centre = p_centre
	half_extents = p_half_extents
	angle = p_angle
	y_range = Vector2(y_min, y_max)
	stable_id = p_stable_id
	owner_id = p_owner_id
	walk_network_id = p_walk_network_id

func bounds_xz() -> Rect2:
	var cosine := absf(cos(angle))
	var sine := absf(sin(angle))
	var extent := Vector2(cosine * half_extents.x + sine * half_extents.y,
		sine * half_extents.x + cosine * half_extents.y)
	return Rect2(centre - extent, extent * 2.0)

func overlaps(other: VillageOccupancyVolume) -> bool:
	# World-space Vector2 values are float32. At streamed-world coordinates,
	# two module contacts authored from the same length can differ by several
	# tenths of a millimetre after rotation/translation. Treat a 1 mm seam as
	# contact, not an overlap; larger penetrations remain conflicts.
	const CONTACT_EPS := 0.001
	if maxf(y_range.x, other.y_range.x) \
			>= minf(y_range.y, other.y_range.y) - CONTACT_EPS:
		return false
	var own_x := Vector2.RIGHT.rotated(angle)
	var own_z := Vector2.DOWN.rotated(angle)
	var other_x := Vector2.RIGHT.rotated(other.angle)
	var other_z := Vector2.DOWN.rotated(other.angle)
	var delta := other.centre - centre
	for axis: Vector2 in [own_x, own_z, other_x, other_z]:
		var own_radius := absf(axis.dot(own_x)) * half_extents.x \
			+ absf(axis.dot(own_z)) * half_extents.y
		var other_radius := absf(axis.dot(other_x)) * other.half_extents.x \
			+ absf(axis.dot(other_z)) * other.half_extents.y
		if absf(delta.dot(axis)) >= own_radius + other_radius - CONTACT_EPS:
			return false
	return true

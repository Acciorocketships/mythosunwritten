class_name FeatureGroundShape
extends RefCounted

## Immutable-by-convention 2D primitive shared by feature surface and clearance
## fields. Keeping the primitive set closed makes projection, bucketing, and
## signed-distance queries exact without teaching consumers about feature types.
enum Kind {
	CIRCLE,
	CAPSULE,
	ORIENTED_RECT,
}

var kind: Kind
var surface_id: int
var priority: int
var stable_id: StringName

var _a: Vector2
var _b: Vector2
var _radius: float
var _half_extents: Vector2
var _angle: float

func _init(p_kind: Kind, p_a: Vector2, p_b: Vector2, p_radius: float,
		p_half_extents: Vector2, p_angle: float, p_surface_id: int,
		p_priority: int, p_stable_id: StringName) -> void:
	assert(_finite_vector(p_a) and _finite_vector(p_b))
	assert(is_finite(p_radius) and p_radius >= 0.0)
	assert(_finite_vector(p_half_extents))
	assert(p_half_extents.x >= 0.0 and p_half_extents.y >= 0.0)
	assert(is_finite(p_angle))
	kind = p_kind
	_a = p_a
	_b = p_b
	_radius = p_radius
	_half_extents = p_half_extents
	_angle = p_angle
	surface_id = p_surface_id
	priority = p_priority
	stable_id = p_stable_id

static func circle(centre: Vector2, radius: float, p_surface_id: int = 0,
		p_priority: int = 0, p_stable_id: StringName = &"") -> FeatureGroundShape:
	assert(radius > 0.0)
	return FeatureGroundShape.new(Kind.CIRCLE, centre, centre, radius,
		Vector2.ZERO, 0.0, p_surface_id, p_priority, p_stable_id)

static func capsule(a: Vector2, b: Vector2, radius: float,
		p_surface_id: int = 0, p_priority: int = 0,
		p_stable_id: StringName = &"") -> FeatureGroundShape:
	assert(radius > 0.0)
	return FeatureGroundShape.new(Kind.CAPSULE, a, b, radius,
		Vector2.ZERO, 0.0, p_surface_id, p_priority, p_stable_id)

static func oriented_rect(centre: Vector2, half_extents: Vector2, angle: float,
		p_surface_id: int = 0, p_priority: int = 0,
		p_stable_id: StringName = &"") -> FeatureGroundShape:
	assert(half_extents.x > 0.0 and half_extents.y > 0.0)
	return FeatureGroundShape.new(Kind.ORIENTED_RECT, centre, centre, 0.0,
		half_extents, angle, p_surface_id, p_priority, p_stable_id)

static func axis_rect(rect: Rect2, p_surface_id: int = 0,
		p_priority: int = 0,
		p_stable_id: StringName = &"") -> FeatureGroundShape:
	assert(rect.size.x > 0.0 and rect.size.y > 0.0)
	return oriented_rect(rect.get_center(), rect.size * 0.5, 0.0,
		p_surface_id, p_priority, p_stable_id)

func contains(point: Vector2) -> bool:
	return signed_distance(point) <= 0.0


## Exact overlap for the closed primitive vocabulary. Feature planners use this
## against canonical reservations before they materialize payloads, avoiding
## point-sample holes as larger or rotated structures are added later.
func intersects(other: FeatureGroundShape, margin: float = 0.0) -> bool:
	assert(other != null)
	assert(is_finite(margin) and margin >= 0.0)
	match kind:
		Kind.CIRCLE:
			return _circle_intersects(other, margin)
		Kind.CAPSULE:
			return _capsule_intersects(other, margin)
		Kind.ORIENTED_RECT:
			match other.kind:
				Kind.CIRCLE:
					return other._circle_intersects(self, margin)
				Kind.CAPSULE:
					return other._capsule_intersects(self, margin)
				Kind.ORIENTED_RECT:
					return _rect_intersects_rect(other, margin)
	return false


func signed_distance(point: Vector2) -> float:
	match kind:
		Kind.CIRCLE:
			return point.distance_to(_a) - _radius
		Kind.CAPSULE:
			var segment := _b - _a
			var length_squared := segment.length_squared()
			var t := 0.0 if length_squared <= 0.000001 else clampf(
				(point - _a).dot(segment) / length_squared, 0.0, 1.0)
			return point.distance_to(_a + segment * t) - _radius
		Kind.ORIENTED_RECT:
			var local := (point - _a).rotated(-_angle)
			var q := Vector2(absf(local.x), absf(local.y)) - _half_extents
			var outside := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length()
			return outside + minf(maxf(q.x, q.y), 0.0)
	return INF

func bounds() -> Rect2:
	match kind:
		Kind.CIRCLE:
			return Rect2(_a - Vector2.ONE * _radius,
				Vector2.ONE * _radius * 2.0)
		Kind.CAPSULE:
			var lo := Vector2(minf(_a.x, _b.x), minf(_a.y, _b.y)) \
				- Vector2.ONE * _radius
			var hi := Vector2(maxf(_a.x, _b.x), maxf(_a.y, _b.y)) \
				+ Vector2.ONE * _radius
			return Rect2(lo, hi - lo)
		Kind.ORIENTED_RECT:
			var cosine := absf(cos(_angle))
			var sine := absf(sin(_angle))
			var extent := Vector2(cosine * _half_extents.x + sine * _half_extents.y,
				sine * _half_extents.x + cosine * _half_extents.y)
			return Rect2(_a - extent, extent * 2.0)
	return Rect2()


func _circle_intersects(other: FeatureGroundShape, margin: float) -> bool:
	match other.kind:
		Kind.CIRCLE:
			return _a.distance_squared_to(other._a) <= pow(
				_radius + other._radius + margin, 2.0)
		Kind.CAPSULE:
			return _point_segment_distance_squared(_a, other._a, other._b) \
				<= pow(_radius + other._radius + margin, 2.0)
		Kind.ORIENTED_RECT:
			return other.signed_distance(_a) <= _radius + margin
	return false


func _capsule_intersects(other: FeatureGroundShape, margin: float) -> bool:
	match other.kind:
		Kind.CIRCLE:
			return other._circle_intersects(self, margin)
		Kind.CAPSULE:
			return _segment_distance_squared(_a, _b, other._a, other._b) \
				<= pow(_radius + other._radius + margin, 2.0)
		Kind.ORIENTED_RECT:
			return _segment_rect_distance_squared(_a, _b, other) \
				<= pow(_radius + margin, 2.0)
	return false


func _rect_intersects_rect(other: FeatureGroundShape, margin: float) -> bool:
	var axes: Array[Vector2] = [
		Vector2.RIGHT.rotated(_angle), Vector2.DOWN.rotated(_angle),
		Vector2.RIGHT.rotated(other._angle), Vector2.DOWN.rotated(other._angle),
	]
	var delta := other._a - _a
	for axis: Vector2 in axes:
		var own_radius := absf(axis.dot(Vector2.RIGHT.rotated(_angle))) \
			* _half_extents.x + absf(axis.dot(Vector2.DOWN.rotated(_angle))) \
			* _half_extents.y
		var other_radius := absf(axis.dot(Vector2.RIGHT.rotated(other._angle))) \
			* other._half_extents.x \
			+ absf(axis.dot(Vector2.DOWN.rotated(other._angle))) \
			* other._half_extents.y
		if absf(delta.dot(axis)) > own_radius + other_radius + margin:
			return false
	return true


static func _segment_rect_distance_squared(a: Vector2, b: Vector2,
		rect: FeatureGroundShape) -> float:
	var local_a := (a - rect._a).rotated(-rect._angle)
	var local_b := (b - rect._a).rotated(-rect._angle)
	var half := rect._half_extents
	if _inside_axis_rect(local_a, half) or _inside_axis_rect(local_b, half):
		return 0.0
	var corners: Array[Vector2] = [
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	]
	var best := INF
	for index in corners.size():
		best = minf(best, _segment_distance_squared(local_a, local_b,
			corners[index], corners[(index + 1) % corners.size()]))
	return best


static func _inside_axis_rect(point: Vector2, half: Vector2) -> bool:
	return absf(point.x) <= half.x and absf(point.y) <= half.y


static func _point_segment_distance_squared(point: Vector2, a: Vector2,
		b: Vector2) -> float:
	var segment := b - a
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_squared_to(a)
	var t := clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(a + segment * t)


static func _segment_distance_squared(a0: Vector2, a1: Vector2,
		b0: Vector2, b1: Vector2) -> float:
	if _segments_intersect(a0, a1, b0, b1):
		return 0.0
	return minf(minf(_point_segment_distance_squared(a0, b0, b1),
		_point_segment_distance_squared(a1, b0, b1)),
		minf(_point_segment_distance_squared(b0, a0, a1),
			_point_segment_distance_squared(b1, a0, a1)))


static func _segments_intersect(a0: Vector2, a1: Vector2,
		b0: Vector2, b1: Vector2) -> bool:
	var a_side_0 := (a1 - a0).cross(b0 - a0)
	var a_side_1 := (a1 - a0).cross(b1 - a0)
	var b_side_0 := (b1 - b0).cross(a0 - b0)
	var b_side_1 := (b1 - b0).cross(a1 - b0)
	const EPS := 0.000001
	if ((a_side_0 > EPS and a_side_1 < -EPS) \
			or (a_side_0 < -EPS and a_side_1 > EPS)) \
			and ((b_side_0 > EPS and b_side_1 < -EPS) \
			or (b_side_0 < -EPS and b_side_1 > EPS)):
		return true
	if absf(a_side_0) <= EPS and _point_on_segment(b0, a0, a1, EPS):
		return true
	if absf(a_side_1) <= EPS and _point_on_segment(b1, a0, a1, EPS):
		return true
	if absf(b_side_0) <= EPS and _point_on_segment(a0, b0, b1, EPS):
		return true
	return absf(b_side_1) <= EPS and _point_on_segment(a1, b0, b1, EPS)


static func _point_on_segment(point: Vector2, a: Vector2, b: Vector2,
		epsilon: float) -> bool:
	return point.x >= minf(a.x, b.x) - epsilon \
		and point.x <= maxf(a.x, b.x) + epsilon \
		and point.y >= minf(a.y, b.y) - epsilon \
		and point.y <= maxf(a.y, b.y) + epsilon

static func _finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)

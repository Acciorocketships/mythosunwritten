class_name WaterFieldContext
extends RefCounted

## Typed, immutable view over one production WaterField fill. It preserves the
## existing field's exact level semantics while giving every pure consumer one
## shared dry/NAN and signed-shore contract.
var _ctx: Dictionary
var _region: HeightfieldRegion
var _coverage: Rect2
var _shore_limit: float
var _shore_curves: Array = []
var _shore_curves_ready := false

static func build(water: WaterPlan, query_rect: Rect2, region: HeightfieldRegion,
		shore_distance_limit: float) -> WaterFieldContext:
	assert(water != null and region != null)
	assert(query_rect.size.x > 0.0 and query_rect.size.y > 0.0)
	assert(is_finite(shore_distance_limit) and shore_distance_limit >= 0.0)
	var span := WaterField.TILE * 8.0
	var centre := query_rect.get_center()
	var chunk := Vector2i(int(floor(centre.x / span)), int(floor(centre.y / span)))
	var raw := WaterField.ctx(water, chunk, region)
	var fill_rect := Rect2(raw.fill_base, Vector2.ONE * (WaterField.FILL_M * WaterField.FILL_STEP))
	var contour_rect := query_rect.grow(shore_distance_limit)
	assert(fill_rect.encloses(contour_rect.grow(WaterContour.MARGIN)),
		"WaterFieldContext query and shore contour exceed the canonical fill window")
	var result := WaterFieldContext.new()
	result._ctx = raw
	result._region = region
	result._coverage = query_rect
	result._shore_limit = shore_distance_limit
	if not result.has_sources():
		result._shore_curves_ready = true
	elif shore_distance_limit > 0.0:
		# Include contours just outside the declared query window: they can still
		# be the nearest shore to a point inside it. WaterContour grows this rect
		# by its own fixed sampling margin before clipping back to it.
		result._shore_curves = WaterContour.curves(raw, contour_rect)
		result._shore_curves_ready = true
	return result

func covers(point: Vector2) -> bool:
	return point.x >= _coverage.position.x and point.y >= _coverage.position.y \
		and point.x <= _coverage.end.x and point.y <= _coverage.end.y

func coverage() -> Rect2:
	return _coverage

func has_sources() -> bool:
	return not _ctx.ponds.is_empty() or not _ctx.rivers.is_empty()

func is_wet(point: Vector2) -> bool:
	_require_coverage(point)
	return WaterField.wet(_ctx, _region, point)

func level_at(point: Vector2) -> float:
	_require_coverage(point)
	if not WaterField.wet(_ctx, _region, point):
		return NAN
	return WaterField.level_at(_ctx, point)

func signed_depth_at(point: Vector2) -> float:
	_require_coverage(point)
	var level := WaterField.level_at(_ctx, point)
	if level == -INF:
		return -WaterField.SHORE_DRY_DEPTH
	return level - TerrainSurfaceField.surface_y(_region, point.x, point.y)

## Sorted, disjoint exact-field wet intervals along a->b, expressed as t in
## [0,1]. The shared shoreline curves supply every possible transition; the
## field's authoritative wet predicate classifies the open spans between.
func wet_intervals(a: Vector2, b: Vector2) -> Array[Vector2]:
	_require_coverage(a)
	_require_coverage(b)
	var delta := b - a
	var length := delta.length()
	assert(length <= WaterPlan.PATH_QUERY_MAX,
		"Exact water segment exceeds the supported %.1fm look-ahead" % WaterPlan.PATH_QUERY_MAX)
	if length <= 0.000001:
		return [Vector2.ZERO] if is_wet(a) else []
	_ensure_shore_curves()
	var splits: Array[float] = [0.0, 1.0]
	for curve: Dictionary in _shore_curves:
		var points: PackedVector2Array = curve.pts
		for i in points.size() - 1:
			_append_curve_crossings(splits, a, b, points[i], points[i + 1])
		if bool(curve.closed) and points.size() > 2:
			_append_curve_crossings(splits, a, b, points[-1], points[0])
	splits.sort()
	var ordered: Array[float] = []
	for t: float in splits:
		if ordered.is_empty() or absf(t - ordered[-1]) > 0.000001:
			ordered.append(t)

	var candidates: Array[Vector2] = []
	if is_wet(a):
		candidates.append(Vector2.ZERO)
	for i in ordered.size() - 1:
		var lo := ordered[i]
		var hi := ordered[i + 1]
		if hi - lo > 0.000001 and is_wet(a + delta * ((lo + hi) * 0.5)):
			candidates.append(Vector2(lo, hi))
	if is_wet(b):
		candidates.append(Vector2.ONE)
	var intervals: Array[Vector2] = []
	for interval: Vector2 in candidates:
		if not intervals.is_empty() and interval.x <= intervals[-1].y + 0.000001:
			intervals[-1] = Vector2(intervals[-1].x, maxf(intervals[-1].y, interval.y))
		else:
			intervals.append(interval)
	return intervals

## Negative on wet water, positive on dry land, saturated at the requested
## finite limit. Distance is measured to WaterContour's shared smooth field
## contour, not to an independent channel approximation.
func shore_distance_at(point: Vector2) -> float:
	_require_coverage(point)
	if _shore_limit <= 0.0:
		return 0.0
	var best := _shore_limit
	for curve: Dictionary in _shore_curves:
		var points: PackedVector2Array = curve.pts
		for i in points.size() - 1:
			best = minf(best, _point_segment_distance(point, points[i], points[i + 1]))
		if bool(curve.closed) and points.size() > 2:
			best = minf(best, _point_segment_distance(point, points[-1], points[0]))
	return -best if WaterField.wet(_ctx, _region, point) else best

func raw_context() -> Dictionary:
	return _ctx

func _ensure_shore_curves() -> void:
	if _shore_curves_ready:
		return
	# Path callers need crossings even when no shore-distance consumer asked
	# for a non-zero saturation limit. Cache the same WaterContour result on
	# first demand rather than constructing another shoreline approximation.
	_shore_curves = WaterContour.curves(_ctx, _coverage.grow(_shore_limit))
	_shore_curves_ready = true

func _require_coverage(point: Vector2) -> void:
	assert(covers(point), "WaterFieldContext query outside declared coverage: %s" % point)

static func _point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var delta := b - a
	if delta.length_squared() <= 0.0000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point.distance_to(a + delta * t)

static func _append_curve_crossings(out: Array[float], a: Vector2, b: Vector2,
		c: Vector2, d: Vector2) -> void:
	var ab := b - a
	var cd := d - c
	var denominator := ab.cross(cd)
	var offset := c - a
	if absf(denominator) > 0.000001:
		var t := offset.cross(cd) / denominator
		var u := offset.cross(ab) / denominator
		if t >= -0.000001 and t <= 1.000001 and u >= -0.000001 and u <= 1.000001:
			out.append(clampf(t, 0.0, 1.0))
		return
	if absf(offset.cross(ab)) > 0.000001:
		return
	var length_squared := ab.length_squared()
	if length_squared <= 0.000001:
		return
	var t0 := (c - a).dot(ab) / length_squared
	var t1 := (d - a).dot(ab) / length_squared
	var lo := maxf(0.0, minf(t0, t1))
	var hi := minf(1.0, maxf(t0, t1))
	if lo <= hi + 0.000001:
		out.append(clampf(lo, 0.0, 1.0))
		out.append(clampf(hi, 0.0, 1.0))

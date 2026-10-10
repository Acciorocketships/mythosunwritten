class_name GrassSamplingContext
extends RefCounted

## Private sampling state for the grass worker. Completed field arrays retain
## exact values, but no canonical plan or mutable grade/water memo is shared.
class WaterSamples extends WaterFieldContext:
	var source_present := false
	# Immutable after detachment. Grass asks for a saturated distance (usually
	# centimetres), not every shoreline segment across the whole 192 m chunk.
	const SHORE_CELL := 12.0
	var shore_cells: Dictionary = {}
	func has_sources() -> bool:
		return source_present
	func index_shores() -> void:
		shore_cells.clear()
		if _shore_limit <= 0.0: return
		for curve: Dictionary in _shore_curves:
			var points: PackedVector2Array = curve.pts
			var count := points.size() - 1
			if bool(curve.closed) and points.size() > 2: count += 1
			for i in count:
				var a := points[i]
				var b := points[(i + 1) % points.size()]
				var lo := Vector2i(((a.min(b) - Vector2.ONE * _shore_limit) / SHORE_CELL).floor())
				var hi := Vector2i(((a.max(b) + Vector2.ONE * _shore_limit) / SHORE_CELL).floor())
				for z in range(lo.y, hi.y + 1):
					for x in range(lo.x, hi.x + 1):
						var key := Vector2i(x, z)
						if not shore_cells.has(key): shore_cells[key] = PackedVector2Array()
						var ends: PackedVector2Array = shore_cells[key]
						ends.append(a)
						ends.append(b)
						shore_cells[key] = ends
	func shore_distance_at(point: Vector2) -> float:
		_require_coverage(point)
		if _shore_limit <= 0.0: return 0.0
		var best := _shore_limit
		var ends: PackedVector2Array = shore_cells.get(Vector2i((point / SHORE_CELL).floor()), PackedVector2Array())
		for i in range(0, ends.size(), 2):
			best = minf(best, _point_segment_distance(point, ends[i], ends[i + 1]))
		return -best if WaterField.wet(_ctx, _region, point) else best

var region: HeightfieldRegion
var water: WaterFieldContext
var features: FeatureContext
var supports: Array[Dictionary] = []

static func detached(source_region: HeightfieldRegion, source_water: WaterFieldContext,
		source_features: FeatureContext = null, source_supports: Array = []) -> GrassSamplingContext:
	var result := GrassSamplingContext.new()
	result.supports.assign(source_supports.duplicate(true))
	if source_features != null:
		result.supports.append_array(source_features.garden_grass_supports().duplicate(true))
	var grades: Dictionary = {}
	result.region = _copy_region(source_region,grades)
	result.water = WaterSamples.new()
	(result.water as WaterSamples).source_present = source_water.has_sources()
	# Ungraded chunks use the same ground for grass and water. Keep one private
	# copy, rather than duplicating its three point dictionaries a second time.
	result.water._region = result.region if source_water._region == source_region \
		else _copy_region(source_water._region,grades)
	result.water._coverage = source_water._coverage
	result.water._shore_limit = source_water._shore_limit
	result.water._shore_curves = source_water._shore_curves.duplicate(true)
	result.water._shore_curves_ready = source_water._shore_curves_ready
	(result.water as WaterSamples).index_shores()
	# Grass only queries the completed fill inside its declared coverage.
	# Do not retain source traces, profiles, plans or lazy dry-ground memo state.
	result.water._ctx = {"ponds":[],"rivers":[],"buckets":{},"region":result.water._region}
	if source_water._ctx.has("fill"):
		result.water._ctx["fill"] = source_water._ctx.fill.duplicate(true)
		result.water._ctx["fill_base"] = source_water._ctx.fill_base
		result.water._ctx["fill_size"] = source_water._ctx.get("fill_size",WaterField.FILL_M+1)
		# The rect is sized with FILL_M * FILL_STEP while the window base moved by
		# WaterField.FILL_OFFSET; the enclosure still holds because that margin is
		# kept on both sides of the coverage.
		var fill_rect := Rect2(source_water._ctx.fill_base,
			Vector2.ONE*WaterField.FILL_M*WaterField.FILL_STEP)
		assert(fill_rect.encloses(source_water.coverage()))
	else:
		assert(not source_water.has_sources(),"a populated grass sampler requires a completed water fill")
	if source_features != null:
		# FeatureGroundField and its shapes are sealed immutable query data;
		# omit the unrelated instance payload and full feature-plan ownership.
		result.features = FeatureContext.new(source_features.coverage(),
			source_features.ground_field(),EnvironmentInstancePayload.new())
	return result

static func _copy_region(source: HeightfieldRegion, grades: Dictionary) -> HeightfieldRegion:
	var result := HeightfieldRegion.new(source._storeys.duplicate(),
		source._levels.duplicate(),source._carved.duplicate())
	result.native_control_heights = source.native_control_heights.duplicate()
	for grade: TerrainGradePatch in source.terrain_grades:
		result.terrain_grades.append(_copy_grade(grade,grades))
	return result

static func _copy_grade(source: TerrainGradePatch, grades: Dictionary) -> TerrainGradePatch:
	var id := source.get_instance_id()
	if grades.has(id): return grades[id]
	var result := TerrainGradePatch.new(source.stable_id,source._claims.duplicate(),
		source._origin,source._targets.pitch)
	grades[id] = result
	result._continuous_cells = source._continuous_cells.duplicate()
	result._continuous_datum = source._continuous_datum
	result.road_masks = source.road_masks.duplicate()
	if source._continuous_source != null:
		result._continuous_source = _copy_grade(source._continuous_source,grades)
	return result

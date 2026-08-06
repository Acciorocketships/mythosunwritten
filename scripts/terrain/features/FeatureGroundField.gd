class_name FeatureGroundField
extends RefCounted

## One deterministic query surface for every authored world feature. The field
## combines the canonical road lattice with exact geometric primitives, so
## terrain, grass, and dressing cannot disagree or silently ignore one layer.
const NATURAL := 0
const WORN_PATH := 1
const PATH_PRIORITY := 100
const BUCKET_SIZE := TerrainSurfaceField.TILE

var _surface_shapes: Array[FeatureGroundShape] = []
var _clearance_shapes: Array[FeatureGroundShape] = []
var _surface_buckets: Dictionary = {}
var _clearance_buckets: Dictionary = {}
var _clearance_limit: float
var _connection_masks: Dictionary
var _node_cells: Dictionary
var _path_priority: int
var _surface_priorities: Dictionary

func _init(surface_shapes: Array[FeatureGroundShape],
		clearance_shapes: Array[FeatureGroundShape], clearance_limit: float,
		connection_masks: Dictionary = {}, node_cells: Dictionary = {},
		surface_priorities: Dictionary = {}) -> void:
	assert(is_finite(clearance_limit) and clearance_limit >= 0.0)
	_surface_shapes.assign(surface_shapes)
	_clearance_shapes.assign(clearance_shapes)
	_clearance_limit = clearance_limit
	_connection_masks = connection_masks.duplicate()
	_node_cells = node_cells.duplicate()
	_surface_priorities = surface_priorities.duplicate()
	_path_priority = int(surface_priorities.get(WORN_PATH, PATH_PRIORITY))
	for shape: FeatureGroundShape in _surface_shapes:
		_insert_shape(_surface_buckets, shape, shape.bounds())
	for shape: FeatureGroundShape in _clearance_shapes:
		_insert_shape(_clearance_buckets, shape,
			shape.bounds().grow(_clearance_limit))

func surface_at(world_xz: Vector2) -> int:
	var cell := Vector2i(int(roundf(world_xz.x / TerrainSurfaceField.TILE)),
		int(roundf(world_xz.y / TerrainSurfaceField.TILE)))
	return surface_at_cell(world_xz, cell)

## Fast form for lattice consumers that already know the nearest terrain cell.
func surface_at_cell(world_xz: Vector2, cell: Vector2i) -> int:
	var best_surface := NATURAL
	var best_priority := -2147483648
	if _path_at_cell(world_xz, cell):
		best_surface = WORN_PATH
		best_priority = _path_priority
	for shape: FeatureGroundShape in _surface_buckets.get(_bucket_of(world_xz), []):
		if not shape.contains(world_xz):
			continue
		if shape.priority > best_priority \
				or (shape.priority == best_priority and shape.surface_id > best_surface):
			best_surface = shape.surface_id
			best_priority = shape.priority
	return best_surface

func has_modified_surface() -> bool:
	return not _connection_masks.is_empty() or not _node_cells.is_empty() \
		or not _surface_shapes.is_empty()

func clearance_at(world_xz: Vector2) -> float:
	var best := _clearance_limit
	for shape: FeatureGroundShape in _clearance_buckets.get(
			_bucket_of(world_xz), []):
		best = minf(best, shape.signed_distance(world_xz))
	return clampf(best, -_clearance_limit, _clearance_limit)

## Exact reservation overlap, bucketed by the candidate's complete bounds.
## Layout producers call this before accepting a solid lot; point consumers
## continue using clearance_at for their inexpensive distance mask.
func overlaps_clearance(shape: FeatureGroundShape,
		margin: float = 0.0) -> bool:
	assert(shape != null)
	assert(is_finite(margin) and margin >= 0.0)
	var query := shape.bounds().grow(margin)
	var lo := _bucket_of(query.position)
	var hi := _bucket_of(query.end)
	var seen: Dictionary = {}
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			for candidate: FeatureGroundShape in _clearance_buckets.get(
					Vector2i(x, z), []):
				var instance_id := candidate.get_instance_id()
				if seen.has(instance_id):
					continue
				seen[instance_id] = true
				if shape.intersects(candidate, margin):
					return true
	return false

func extended(surface_shapes: Array[FeatureGroundShape],
		clearance_shapes: Array[FeatureGroundShape]) -> FeatureGroundField:
	var surfaces := _surface_shapes.duplicate()
	surfaces.append_array(surface_shapes)
	var clearances := _clearance_shapes.duplicate()
	clearances.append_array(clearance_shapes)
	return FeatureGroundField.new(surfaces, clearances, _clearance_limit,
		_connection_masks, _node_cells, _surface_priorities)

func _path_at_cell(world_xz: Vector2, cell: Vector2i) -> bool:
	var local := world_xz - Vector2(cell) * TerrainSurfaceField.TILE
	if _node_cells.has(cell) \
			and local.length_squared() <= PathProgram.PLAZA_RADIUS * PathProgram.PLAZA_RADIUS:
		return true
	var mask: int = _connection_masks.get(cell, 0)
	if (mask & 1) != 0 and (mask & 4) != 0 \
			and _rounded_corner_at(local, Vector2(1.0, 1.0)):
		return true
	if (mask & 1) != 0 and (mask & 8) != 0 \
			and _rounded_corner_at(local, Vector2(1.0, -1.0)):
		return true
	if (mask & 2) != 0 and (mask & 4) != 0 \
			and _rounded_corner_at(local, Vector2(-1.0, 1.0)):
		return true
	if (mask & 2) != 0 and (mask & 8) != 0 \
			and _rounded_corner_at(local, Vector2(-1.0, -1.0)):
		return true
	var arm_start := PathProgram.CORNER_RADIUS if _is_simple_turn(mask) else 0.0
	if absf(local.y) <= PathProgram.PATH_WIDTH * 0.5:
		if local.x >= arm_start and local.x <= TerrainSurfaceField.HALF \
				and (mask & 1) != 0:
			return true
		if local.x <= -arm_start and local.x >= -TerrainSurfaceField.HALF \
				and (mask & 2) != 0:
			return true
	if absf(local.x) <= PathProgram.PATH_WIDTH * 0.5:
		if local.y >= arm_start and local.y <= TerrainSurfaceField.HALF \
				and (mask & 4) != 0:
			return true
		if local.y <= -arm_start and local.y >= -TerrainSurfaceField.HALF \
				and (mask & 8) != 0:
			return true
	return false

static func path_mask_has_join(mask: int) -> bool:
	# One arm and the two opposing straight masks need no corner reservation.
	return mask != 0 and mask != 1 and mask != 2 and mask != 3 \
		and mask != 4 and mask != 8 and mask != 12

static func _is_simple_turn(mask: int) -> bool:
	return mask == 5 or mask == 6 or mask == 9 or mask == 10

static func _rounded_corner_at(local: Vector2, diagonal: Vector2) -> bool:
	var centre := diagonal * PathProgram.CORNER_RADIUS
	var delta := local - centre
	if delta.x * diagonal.x > 0.0 or delta.y * diagonal.y > 0.0:
		return false
	var distance_squared := delta.length_squared()
	return distance_squared >= PathProgram.CORNER_INNER_RADIUS \
			* PathProgram.CORNER_INNER_RADIUS \
		and distance_squared <= PathProgram.CORNER_OUTER_RADIUS \
			* PathProgram.CORNER_OUTER_RADIUS

static func _bucket_of(point: Vector2) -> Vector2i:
	return Vector2i(int(floor(point.x / BUCKET_SIZE)),
		int(floor(point.y / BUCKET_SIZE)))

static func _insert_shape(buckets: Dictionary, shape: FeatureGroundShape,
		query_bounds: Rect2) -> void:
	var lo := _bucket_of(query_bounds.position)
	var hi := _bucket_of(query_bounds.end)
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var key := Vector2i(x, z)
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(shape)

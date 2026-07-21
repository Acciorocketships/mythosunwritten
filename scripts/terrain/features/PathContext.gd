class_name PathContext
extends RefCounted

## Immutable worker-side projection of the canonical network around one block.
## Connection masks are the terrain-paint source (including round joins), while
## rectangles are the one signed-distance representation for dressing clearance;
## there is no parallel raster or seam bookkeeping.
var _coverage: Rect2
var _corridors: Array[Rect2]
var _reservations: Array[Rect2]
var _payload: EnvironmentInstancePayload
var _clearance_limit: float
var _reservation_buckets: Dictionary = {}
var connection_masks: Dictionary
var node_cells: Dictionary
var bridge_cells: Dictionary

func _init(p_coverage: Rect2, corridor_rects: Array[Rect2],
		reservation_rects: Array[Rect2],
		p_payload: EnvironmentInstancePayload, clearance_limit: float,
		masks: Dictionary = {}, nodes: Dictionary = {}, bridges: Dictionary = {}) -> void:
	_coverage = p_coverage
	_corridors = corridor_rects.duplicate()
	_reservations = reservation_rects.duplicate()
	_payload = p_payload
	_clearance_limit = clearance_limit
	connection_masks = masks.duplicate()
	node_cells = nodes.duplicate()
	bridge_cells = bridges.duplicate()
	for rect: Rect2 in _reservations:
		var grown := rect.grow(_clearance_limit)
		var lo := Vector2i(int(floor(grown.position.x / TerrainSurfaceField.TILE)),
			int(floor(grown.position.y / TerrainSurfaceField.TILE)))
		var hi := Vector2i(int(floor(grown.end.x / TerrainSurfaceField.TILE)),
			int(floor(grown.end.y / TerrainSurfaceField.TILE)))
		for z in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var key := Vector2i(x, z)
				if not _reservation_buckets.has(key):
					_reservation_buckets[key] = []
				_reservation_buckets[key].append(rect)

func corridor_at(world_xz: Vector2) -> bool:
	if not connection_masks.is_empty():
		var cell := Vector2i(int(roundf(world_xz.x / TerrainSurfaceField.TILE)),
			int(roundf(world_xz.y / TerrainSurfaceField.TILE)))
		return corridor_at_cell(world_xz, cell)
	for rect: Rect2 in _corridors:
		if _contains_closed(rect, world_xz):
			return true
	return false

# Same classifier when a lattice consumer already knows the nearest terrain
# cell. Terrain meshing calls this for every 2m quad, avoiding two divisions and
# rounds per sample without introducing a second path representation.
func corridor_at_cell(world_xz: Vector2, cell: Vector2i) -> bool:
	if not connection_masks.is_empty() or not node_cells.is_empty():
		var local := world_xz - Vector2(cell) * TerrainSurfaceField.TILE
		if node_cells.has(cell) \
				and local.length_squared() <= PathProgram.PLAZA_RADIUS * PathProgram.PLAZA_RADIUS:
			return true
		var mask: int = connection_masks.get(cell, 0)
		# Each perpendicular arm pair contributes a quarter-annulus. This is a
		# genuine constant-width elbow: its inner and outer boundaries are both
		# arcs, unlike the previous circle stamped over two straight strips.
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
	for rect: Rect2 in _corridors:
		if _contains_closed(rect, world_xz):
			return true
	return false

func clearance_at(world_xz: Vector2) -> float:
	var best := _clearance_limit
	var key := Vector2i(int(floor(world_xz.x / TerrainSurfaceField.TILE)),
		int(floor(world_xz.y / TerrainSurfaceField.TILE)))
	for rect: Rect2 in _reservation_buckets.get(key, []):
		best = minf(best, _signed_rect_distance(rect, world_xz))
	return clampf(best, -_clearance_limit, _clearance_limit)

func placements() -> EnvironmentInstancePayload:
	return _payload

func coverage() -> Rect2:
	return _coverage

static func _contains_closed(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.y >= rect.position.y \
		and point.x <= rect.end.x and point.y <= rect.end.y

static func _has_join(mask: int) -> bool:
	# One arm and the two opposing straight masks need no corner reservation.
	# Every other connected mask contains at least one perpendicular arm pair.
	return mask != 0 and mask != 1 and mask != 2 and mask != 3 \
		and mask != 4 and mask != 8 and mask != 12

static func _is_simple_turn(mask: int) -> bool:
	return mask == 5 or mask == 6 or mask == 9 or mask == 10

static func _rounded_corner_at(local: Vector2, diagonal: Vector2) -> bool:
	var centre := diagonal * PathProgram.CORNER_RADIUS
	var delta := local - centre
	# Keep only the quadrant facing back toward the junction. The other three
	# quarters would make a ring/blob instead of a tangent elbow.
	if delta.x * diagonal.x > 0.0 or delta.y * diagonal.y > 0.0:
		return false
	var distance_squared := delta.length_squared()
	return distance_squared >= PathProgram.CORNER_INNER_RADIUS \
			* PathProgram.CORNER_INNER_RADIUS \
		and distance_squared <= PathProgram.CORNER_OUTER_RADIUS \
			* PathProgram.CORNER_OUTER_RADIUS

static func _signed_rect_distance(rect: Rect2, point: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dz := maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	if dx > 0.0 or dz > 0.0:
		return Vector2(dx, dz).length()
	return -minf(minf(point.x - rect.position.x, rect.end.x - point.x),
		minf(point.y - rect.position.y, rect.end.y - point.y))

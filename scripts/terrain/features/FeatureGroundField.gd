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

## Exact point sampler restricted to a known closed domain. Mesh clipping
## queries many points in the same small rectangle; collect its possible shape
## owners once instead of rescanning the entire 24 m bucket for every crossing.
func surface_sampler_in(area: Rect2) -> Callable:
	area = _conservative_query_bounds(area)
	var selected: Array[FeatureGroundShape] = []
	var seen: Dictionary = {}
	var lo := _bucket_of(area.position)
	var hi := _bucket_of(area.end)
	for z in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			for shape: FeatureGroundShape in _surface_buckets.get(Vector2i(x,z),[]):
				var id := shape.get_instance_id()
				if seen.has(id): continue
				seen[id]=true
				if shape.bounds().intersects(area,true): selected.append(shape)
	return func(point: Vector2) -> int:
		var cell := Vector2i(roundi(point.x/TerrainSurfaceField.TILE),
			roundi(point.y/TerrainSurfaceField.TILE))
		var best_surface := WORN_PATH if _path_at_cell(point,cell) else NATURAL
		var best_priority := _path_priority if best_surface == WORN_PATH else -2147483648
		for shape: FeatureGroundShape in selected:
			if shape.priority < best_priority: continue
			if shape.priority == best_priority and shape.surface_id <= best_surface: continue
			if not shape.contains(point): continue
			best_surface=shape.surface_id
			best_priority=shape.priority
		return best_surface

## Conservative broad phase for surface meshing. False certifies that no
## point in the closed rectangle can be a path; true still needs exact queries.
func may_have_path_in(area: Rect2) -> bool:
	area = _conservative_query_bounds(area)
	var tile := TerrainSurfaceField.TILE
	var cell_lo := Vector2i(floori(area.position.x / tile - 0.5),
		floori(area.position.y / tile - 0.5))
	var cell_hi := Vector2i(ceili(area.end.x / tile + 0.5),
		ceili(area.end.y / tile + 0.5))
	for z in range(cell_lo.y, cell_hi.y + 1):
		for x in range(cell_lo.x, cell_hi.x + 1):
			var cell := Vector2i(x,z)
			if not _connection_masks.has(cell) and not _node_cells.has(cell):
				continue
			if Rect2(Vector2(cell)*tile-Vector2.ONE*tile*0.5,
					Vector2.ONE*tile).intersects(area,true):
				return true
	var lo := _bucket_of(area.position)
	var hi := _bucket_of(area.end)
	for z in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			for shape: FeatureGroundShape in _surface_buckets.get(Vector2i(x,z),[]):
				if shape.surface_id == WORN_PATH and shape.bounds().intersects(area,true):
					return true
	return false

static func _conservative_query_bounds(area: Rect2) -> Rect2:
	# Vector2 stores float32 coordinates. Allow several rounding units when
	# transformed shape bounds meet a query, including far from world origin.
	var scale := maxf(maxf(absf(area.position.x),absf(area.position.y)),
		maxf(absf(area.end.x),absf(area.end.y)))
	return area.grow(0.00001+scale*0.000001)

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
	# A settlement node is a built junction: its square and every arm meet at
	# right angles, so the town's street and handoff ramp butt against straight
	# edges. The rounded fillet belongs to open-country bends only.
	var is_node := _node_cells.has(cell)
	if is_node \
			and absf(local.x) <= PathProgram.NODE_JUNCTION_HALF_WIDTH \
			and absf(local.y) <= PathProgram.NODE_JUNCTION_HALF_WIDTH:
		return true
	var mask: int = _connection_masks.get(cell, 0)
	if not is_node:
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
	var arm_start := PathProgram.CORNER_RADIUS \
		if _is_simple_turn(mask) and not is_node else 0.0
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


func construction_clearance_bounds() -> Array[Rect2]:
	## Finite conservative domains for construction beside this field. Roads
	## stored in the lattice layer own clearance just like explicit primitives.
	## Consumers must not inspect only _clearance_shapes and lose world roads.
	var out: Array[Rect2] = []
	for shape: FeatureGroundShape in _clearance_shapes: out.append(shape.bounds())
	var half := PathProgram.PATH_HALF_WIDTH
	for cell: Vector2i in _node_cells:
		out.append(Rect2(Vector2(cell)*TerrainSurfaceField.TILE-Vector2.ONE*half,
			Vector2.ONE*half*2.0))
	for cell: Vector2i in _connection_masks:
		var centre := Vector2(cell)*TerrainSurfaceField.TILE
		var mask := int(_connection_masks[cell])
		var directions: Array[Vector2] = []
		for item: Array in [[1,Vector2.RIGHT],[2,Vector2.LEFT],[4,Vector2.DOWN],[8,Vector2.UP]]:
			if (mask & int(item[0]))==0: continue
			var direction: Vector2 = item[1]
			directions.append(direction)
			var end := centre+direction*TerrainSurfaceField.HALF
			out.append(FeatureGroundShape.oriented_rect((centre+end)*0.5,
				Vector2(TerrainSurfaceField.HALF*0.5,half),direction.angle()).bounds())
		if _node_cells.has(cell): continue
		for i in directions.size():
			for j in range(i+1,directions.size()):
				if absf(directions[i].dot(directions[j]))>0.001: continue
				var far := centre+(directions[i]+directions[j])*PathProgram.CORNER_OUTER_RADIUS
				out.append(Rect2(centre.min(far),(far-centre).abs()))
	return out

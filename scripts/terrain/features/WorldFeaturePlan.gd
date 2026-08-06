class_name WorldFeaturePlan
extends RefCounted

## Canonical worker-confined owner of authored world features. PathPlan remains
## an independent deterministic producer; villages and later feature families
## join here so streaming consumers never acquire producer-specific branches.
var _paths: PathPlan
var _settlements: SettlementPlan
var _fields: WorldFieldBlockCache
var _program: FeatureProgram
var _village_program: VillageProgram
var _villages: VillagePlan
var _frames: Dictionary = {}
var _contexts: Dictionary = {}
var _context_margin: float
const FRAME_CACHE_CAP := 64
const CONTEXT_CACHE_CAP := 96

func _init(world_seed: int, water: WaterPlan, fields: WorldFieldBlockCache,
		program: FeatureProgram, settlements: SettlementPlan,
		context_margin: float = -1.0) -> void:
	assert(program != null and program.paths != null and program.villages != null)
	_settlements = settlements
	_fields = fields
	_program = program
	_context_margin = program.query_margin if context_margin < 0.0 else context_margin
	assert(is_finite(_context_margin) and _context_margin >= program.query_margin)
	_village_program = program.villages
	_villages = VillagePlan.new(world_seed, program.villages, fields)
	_paths = PathPlan.new(world_seed, water, fields, program.paths,
		_context_margin, settlements, program.surface_priorities)

func context_for(block: Vector2i) -> FeatureContext:
	if _contexts.has(block):
		return _contexts[block]
	if _contexts.size() >= CONTEXT_CACHE_CAP:
		_contexts.clear()
	var path_context := _paths.context_for(block)
	var core := Rect2(Vector2(block) * TerrainChunkMesher.CHUNK_WORLD,
		Vector2.ONE * TerrainChunkMesher.CHUNK_WORLD)
	var surface_shapes: Array[FeatureGroundShape] = []
	var clearance_shapes: Array[FeatureGroundShape] = []
	var village_payload := EnvironmentInstancePayload.new()
	# Dressing may carry a broad canopy into this block from an anchor outside
	# it. Discover records over the same complete context used by reservation
	# queries so those intersections cannot disappear at block seams.
	for record: VillageRecord in _records_affecting(path_context.coverage()):
		for shape: FeatureGroundShape in record.surface_shapes:
			if shape.bounds().intersects(path_context.coverage(), true):
				surface_shapes.append(shape)
		for shape: FeatureGroundShape in record.clearance_shapes:
			if shape.bounds().grow(_program.maximum_clearance).intersects(
					path_context.coverage(), true):
				clearance_shapes.append(shape)
		village_payload.append_from(record.payload)
	var context := path_context.extended(surface_shapes, clearance_shapes,
		village_payload, core)
	_contexts[block] = context
	return context

func set_progress_callback(callback: Callable) -> void:
	_paths.set_progress_callback(callback)

func set_planning_progress_callback(callback: Callable) -> void:
	_paths.set_planning_progress_callback(callback)

func stats() -> Dictionary:
	return {"paths": _paths.stats(), "villages": _villages.stats(),
		"frame_cache": _frames.size(), "context_cache": _contexts.size()}

func program() -> FeatureProgram:
	return _program

func frame_for(super_cell: Vector2i) -> VillageFrame:
	if _frames.has(super_cell):
		return _frames[super_cell]
	if _frames.size() >= FRAME_CACHE_CAP:
		# Output-pure cache: clearing changes cost only, never frame identity.
		_frames.clear()
	var site := _settlements.site_for(super_cell)
	if site.is_empty():
		_frames[super_cell] = null
		return null
	var node := _paths.node_for(super_cell)
	if node.is_empty():
		_frames[super_cell] = null
		return null
	var point := Vector2(node.cell) * TerrainSurfaceField.TILE
	var block := WorldFieldBlockCache.key_of(point)
	var frame := VillageFrame.build(node, _paths.context_for(block),
		_fields.region(block), _fields.water(block),
		_paths.accepted_mask_for_node(super_cell))
	_frames[super_cell] = frame
	return frame

func path_plan() -> PathPlan:
	return _paths

func village_plan() -> VillagePlan:
	return _villages

func _records_affecting(core: Rect2) -> Array[VillageRecord]:
	var query := core.grow(_program.record_discovery_radius)
	var lo := Vector2i(floori(query.position.x / SettlementPlan.SUPER_WORLD),
		floori(query.position.y / SettlementPlan.SUPER_WORLD))
	var hi := Vector2i(floori(query.end.x / SettlementPlan.SUPER_WORLD),
		floori(query.end.y / SettlementPlan.SUPER_WORLD))
	var out: Array[VillageRecord] = []
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var super_cell := Vector2i(x, z)
			var site := _settlements.site_for(super_cell)
			if site.is_empty():
				continue
			var site_centre := Vector2(site.cell) * TerrainSurfaceField.TILE
			var layout_bound := Rect2(site_centre - Vector2.ONE \
				* _village_program.layout_record_radius,
				Vector2.ONE * _village_program.layout_record_radius * 2.0)
			if not layout_bound.intersects(core.grow(
					_program.maximum_clearance), true):
				continue
			var frame := frame_for(super_cell)
			if frame == null or frame.is_dormant():
				continue
			var conservative := _village_program.record_bound(frame.centre)
			if not conservative.intersects(core.grow(
					_program.maximum_clearance), true):
				continue
			var record := _villages.record_for(frame)
			if record != null and record.bounds.intersects(core.grow(
					_program.maximum_clearance), true):
				out.append(record)
	out.sort_custom(func(a: VillageRecord, b: VillageRecord) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	return out

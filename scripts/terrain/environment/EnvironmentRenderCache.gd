class_name EnvironmentRenderCache
extends RefCounted

## Main-thread-only owner of heavy environment visuals. Workers traffic only
## in asset IDs; commits resolve those IDs through this cache.
var _catalog: EnvironmentCatalog
var _visuals: Dictionary = {}

func _init(catalog: EnvironmentCatalog) -> void:
	_catalog = catalog

func prepare(asset_ids: Array[StringName]) -> bool:
	_assert_main_thread()
	var unique: Dictionary = {}
	for asset_id: StringName in asset_ids:
		unique[asset_id] = true
	var ordered: Array[StringName] = []
	ordered.assign(unique.keys())
	ordered.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for asset_id: StringName in ordered:
		if visual(asset_id) == null:
			return false
	return true

func visual(asset_id: StringName) -> EnvironmentVisual:
	_assert_main_thread()
	var cached := _visuals.get(asset_id) as EnvironmentVisual
	if cached != null:
		return cached
	if _catalog == null:
		push_error("EnvironmentRenderCache requires a catalogue")
		return null
	var descriptor_value := _catalog.descriptor(asset_id)
	if descriptor_value == null:
		push_error("Unknown environment asset ID: %s" % String(asset_id))
		return null
	var loaded := load(descriptor_value.visual_path) as EnvironmentVisual
	if not _validate_visual(asset_id, loaded):
		return null
	_visuals[asset_id] = loaded
	return loaded

func is_prepared(asset_id: StringName) -> bool:
	return _visuals.has(asset_id)

func prepared_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_visuals.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out

func clear() -> void:
	_assert_main_thread()
	_visuals.clear()

func _validate_visual(asset_id: StringName, visual_value: EnvironmentVisual) -> bool:
	if visual_value == null or visual_value.pieces.is_empty():
		push_error("Environment visual %s has no pieces" % String(asset_id))
		return false
	for piece: EnvironmentVisualPiece in visual_value.pieces:
		if piece == null or piece.mesh == null:
			push_error("Environment visual %s contains an invalid piece" % String(asset_id))
			return false
		if not piece.local_transform.is_finite():
			push_error("Environment visual %s contains a non-finite transform" % String(asset_id))
			return false
	for collision: EnvironmentCollisionPiece in visual_value.collisions:
		if collision == null or collision.shape == null:
			push_error("Environment visual %s contains an invalid collision piece" % String(asset_id))
			return false
		if not collision.local_transform.is_finite():
			push_error("Environment visual %s contains a non-finite collision transform" % String(asset_id))
			return false
	var descriptor := _catalog.descriptor(asset_id)
	if descriptor.collision_piece_count != visual_value.collisions.size():
		push_error("Environment visual %s collision count disagrees with its descriptor" % String(asset_id))
		return false
	return true

func _assert_main_thread() -> void:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id(),
		"EnvironmentRenderCache may only load or mutate resources on the main thread")

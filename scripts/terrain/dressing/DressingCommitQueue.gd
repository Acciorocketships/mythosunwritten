class_name DressingCommitQueue
extends RefCounted

## Focused main-thread queue: each item creates exactly one
## (asset_id, visual_piece) MultiMesh batch. Terrain readiness never waits on
## this render-only work.
var _render_cache: EnvironmentRenderCache
var _items: Array[Dictionary] = []
var _current_generation: Dictionary = {}

func _init(render_cache: EnvironmentRenderCache) -> void:
	_render_cache = render_cache

func register_chunk(chunk: Vector2i, generation: int) -> void:
	_current_generation[chunk] = generation

func invalidate_chunk(chunk: Vector2i) -> void:
	_current_generation.erase(chunk)

func enqueue(chunk: Vector2i, generation: int, parent: Node3D,
		payload: DressingPayload) -> void:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	if payload == null or payload.instance_count == 0:
		return
	for asset_id: StringName in payload.asset_ids():
		var visual := _render_cache.visual(asset_id)
		assert(visual != null)
		var batch: Dictionary = payload.batches[asset_id]
		for piece_index in visual.pieces.size():
			_items.append({
				"chunk": chunk,
				"generation": generation,
				"parent": weakref(parent),
				"asset_id": asset_id,
				"piece_index": piece_index,
				"transforms": batch.transforms,
				"colors": batch.colors,
			})

func drain(max_batches: int) -> int:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	var committed := 0
	while committed < max_batches and not _items.is_empty():
		var item: Dictionary = _items.pop_front()
		if int(_current_generation.get(item.chunk, -1)) != item.generation:
			continue
		var parent := (item.parent as WeakRef).get_ref() as Node3D
		if parent == null or not is_instance_valid(parent):
			continue
		_commit_batch(parent, item)
		committed += 1
	return committed

func pending_count() -> int:
	return _items.size()

func clear() -> void:
	_items.clear()
	_current_generation.clear()

static func compose_transforms(transforms: Array,
		piece: EnvironmentVisualPiece) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for transform: Transform3D in transforms:
		out.append(transform * piece.local_transform)
	return out

func _commit_batch(parent: Node3D, item: Dictionary) -> void:
	var visual := _render_cache.visual(item.asset_id)
	var piece: EnvironmentVisualPiece = visual.pieces[item.piece_index]
	var transforms: Array = item.transforms
	var colors: Array = item.colors
	assert(transforms.size() == colors.size())
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = piece.mesh
	multimesh.instance_count = transforms.size()
	var composed := compose_transforms(transforms, piece)
	for index in composed.size():
		multimesh.set_instance_transform(index, composed[index])
		multimesh.set_instance_color(index, colors[index])
	var container := parent.get_node_or_null("Dressing") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = "Dressing"
		parent.add_child(container)
	var instance := MultiMeshInstance3D.new()
	instance.name = "%s_%02d" % [String(item.asset_id).replace(".", "_"), item.piece_index]
	instance.multimesh = multimesh
	container.add_child(instance)

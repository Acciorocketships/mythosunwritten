class_name EnvironmentCommitQueue
extends RefCounted

## Main-thread visual queue. Each item creates one (asset, visual-piece)
## MultiMesh batch; generation checks discard stale work.
const LANTERN_LIGHTS := preload("res://scripts/terrain/environment/EnvironmentLanternLights.gd")

var _render_cache: EnvironmentRenderCache
var _container_name: StringName
var _items: Array[Dictionary] = []
var _current_generation: Dictionary = {}

func _init(render_cache: EnvironmentRenderCache, container_name: StringName) -> void:
	_render_cache = render_cache
	_container_name = container_name

func register_chunk(chunk: Vector2i, generation: int) -> void:
	_current_generation[chunk] = generation

func invalidate_chunk(chunk: Vector2i) -> void:
	_current_generation.erase(chunk)

func enqueue(chunk: Vector2i, generation: int, parent: Node3D,
		payload: EnvironmentInstancePayload) -> void:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	assert(payload != null and payload.validate())
	if payload.instance_count == 0:
		return
	for asset_id: StringName in payload.asset_ids():
		var visual := _render_cache.visual(asset_id)
		assert(visual != null)
		var tags := _render_cache.descriptor(asset_id).tags
		var batches: Array = [payload.batches[asset_id]]
		if &"tree" in tags or &"bush" in tags or &"nature" in tags or &"foliage" in tags:
			batches = tile_batch(payload.batches[asset_id])
		for batch: Dictionary in batches:
			for piece_index in visual.pieces.size():
				_items.append({
					"chunk": chunk,
					"generation": generation,
					"parent": weakref(parent),
					"asset_id": asset_id,
					"piece_index": piece_index,
					"transforms": batch.transforms,
					"colors": batch.colors,
					"visibility_owners": batch.get("visibility_owners", []),
				})

## Nature dressing (trees and bushes first) is batched per FOLIAGE_TILE world
## square, not per chunk:
## the renderer culls and picks mesh LODs per MultiMesh, and a chunk-wide
## batch always touched the camera, so every crown in it drew all its leaf
## cards (October 6 dense forest: frame time doubled).
const FOLIAGE_TILE := 48.0

static func tile_batch(batch: Dictionary) -> Array:
	var tiles: Dictionary = {}
	var transforms: Array = batch.transforms
	var owners: Array = batch.get("visibility_owners", [])
	for index in transforms.size():
		var origin := (transforms[index] as Transform3D).origin
		var key := Vector2i(floori(origin.x / FOLIAGE_TILE), floori(origin.z / FOLIAGE_TILE))
		if not tiles.has(key):
			tiles[key] = {"transforms": [], "colors": [], "visibility_owners": []}
		tiles[key].transforms.append(transforms[index])
		tiles[key].colors.append(batch.colors[index])
		if index < owners.size():
			tiles[key].visibility_owners.append(owners[index])
	var keys: Array = tiles.keys()
	keys.sort()
	var out: Array = []
	for key: Vector2i in keys:
		out.append(tiles[key])
	return out

func drain(max_batches: int, max_usec: int = 0) -> int:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	assert(max_batches >= 0 and max_usec >= 0)
	var started := Time.get_ticks_usec()
	var committed := 0
	while committed < max_batches and not _items.is_empty() \
			and (max_usec <= 0 or Time.get_ticks_usec() - started < max_usec):
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

## Small nature stops drawing where it is a few pixels: per tag, the content
## distance plus the half diagonal of its FOLIAGE_TILE batch (the renderer
## measures to the batch's centre). Trees, bushes and everything man-made keep
## no range (0). A batch beyond range costs no draw call, culling or shadow.
const VISIBILITY_MARGIN := 8.0
const _TILE_HALF_DIAGONAL := FOLIAGE_TILE * 0.7071
static func visibility_range(tags: Array, bounds: AABB) -> float:
	if &"tree" in tags or &"bush" in tags or not (&"nature" in tags or &"foliage" in tags):
		return 0.0
	var content := 0.0
	if &"grass" in tags or &"flower" in tags:
		content = 90.0
	elif &"plant" in tags or &"mushroom" in tags or &"reed" in tags or &"foliage" in tags:
		content = 140.0
	elif &"deadwood" in tags or &"rock" in tags:
		content = 180.0 if bounds.get_longest_axis_size() < 1.5 else 380.0
	else:
		return 0.0
	return content + _TILE_HALF_DIAGONAL

func _commit_batch(parent: Node3D, item: Dictionary) -> void:
	var visual := _render_cache.visual(item.asset_id)
	var piece: EnvironmentVisualPiece = visual.pieces[item.piece_index]
	var transforms: Array = item.transforms
	var colors: Array = item.colors
	assert(transforms.size() == colors.size())
	var multimesh := MultiMesh.new()
	var tags := _render_cache.descriptor(item.asset_id).tags
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = piece.use_instance_color
	multimesh.use_custom_data = true
	multimesh.mesh = piece.mesh
	multimesh.instance_count = transforms.size()
	var composed := compose_transforms(transforms, piece)
	# Complete prefab assets own all native pieces. Modular assets instead
	# carry the room envelope assigned by their construction plan.
	var native_bounds := AABB()
	for native_piece: EnvironmentVisualPiece in visual.pieces:
		var box := native_piece.local_transform * native_piece.mesh.get_aabb()
		native_bounds = native_bounds.merge(box) if native_bounds.has_volume() else box
	var owners: Array = item.get("visibility_owners", [])
	for index in composed.size():
		multimesh.set_instance_transform(index, composed[index])
		if piece.use_instance_color:
			multimesh.set_instance_color(index, colors[index])
		var owner: AABB = owners[index] if index < owners.size() else AABB()
		if not owner.has_volume(): owner = (transforms[index] as Transform3D) * native_bounds
		multimesh.set_instance_custom_data(index, Color(owner.position.x,owner.position.z,owner.end.x,owner.end.z))
	var container := parent.get_node_or_null(String(_container_name)) as Node3D
	if container == null:
		container = Node3D.new()
		container.name = _container_name
		parent.add_child(container)
	var instance := MultiMeshInstance3D.new()
	instance.name = "%s_%02d" % [String(item.asset_id).replace(".", "_"), item.piece_index]
	instance.multimesh = multimesh
	instance.set_meta("tactical_owner_footprints", true)
	if &"deck" in tags:
		instance.add_to_group("tactical_deck_surface", true)
	if &"building" in tags or &"deck" in tags:
		instance.add_to_group("tactical_closed_shell", true)
	if &"cliff" in tags:
		instance.add_to_group("tactical_solid_earth", true)
	instance.material_override = LANTERN_LIGHTS.glass_material(item.asset_id, piece)
	var view_range := visibility_range(tags, native_bounds)
	if view_range > 0.0:
		instance.visibility_range_end = view_range
		instance.visibility_range_end_margin = VISIBILITY_MARGIN
	container.add_child(instance)
	if piece.shadow_mesh != null:
		_attach_shadow_proxy(instance, piece.shadow_mesh)
	preload("res://scripts/terrain/biome/CanopyShadows.gd").attach(instance)
	if int(item.piece_index) == 0:
		LANTERN_LIGHTS.attach(container,item.asset_id,transforms)

## Painted-leaf trees cast their sun shadow from a baked stand-in (an eighth
## of the leaf cards, coarsest bark) with the batch's instances.
static func _attach_shadow_proxy(instance: MultiMeshInstance3D, shadow_mesh: Mesh) -> void:
	var source := instance.multimesh
	var multimesh := MultiMesh.new()
	multimesh.transform_format = source.transform_format
	multimesh.use_colors = source.use_colors
	multimesh.use_custom_data = source.use_custom_data
	multimesh.mesh = shadow_mesh
	multimesh.instance_count = source.instance_count
	for index in source.instance_count:
		multimesh.set_instance_transform(index, source.get_instance_transform(index))
		if source.use_colors:
			multimesh.set_instance_color(index, source.get_instance_color(index))
		if source.use_custom_data:
			multimesh.set_instance_custom_data(index, source.get_instance_custom_data(index))
	var proxy := MultiMeshInstance3D.new()
	proxy.name = "LeafShadow"
	proxy.multimesh = multimesh
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	proxy.layers = instance.layers
	# Shadow-only geometry cannot obstruct the camera (CanopyShadows).
	proxy.add_to_group("tactical_preserve_surface", true)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_child(proxy)

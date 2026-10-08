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
		content = GrassStreamer.GRASS_RADIUS + 6.0
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
	var footprints: Array[Color] = []
	for index in composed.size():
		multimesh.set_instance_transform(index, composed[index])
		if piece.use_instance_color:
			multimesh.set_instance_color(index, colors[index])
		var owner: AABB = owners[index] if index < owners.size() else AABB()
		if not owner.has_volume(): owner = (transforms[index] as Transform3D) * native_bounds
		var footprint := Color(owner.position.x,owner.position.z,owner.end.x,owner.end.z)
		multimesh.set_instance_custom_data(index, footprint)
		footprints.append(footprint)
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
	if visual.imposter != null:
		instance.visibility_range_end = imposter_range_end()
	container.add_child(instance)
	if visual.imposter != null and int(item.piece_index) == 0:
		_attach_imposter(instance, visual.imposter, transforms,
			colors if piece.use_instance_color else [], footprints)
	if piece.shadow_mesh != null:
		_attach_shadow_proxy(instance, piece.shadow_mesh)
	preload("res://scripts/terrain/biome/CanopyShadows.gd").attach(instance)
	if int(item.piece_index) == 0:
		LANTERN_LIGHTS.attach(container,item.asset_id,transforms)

## Trees hand over to their baked imposter (EnvironmentImposter, one camera-
## facing card per tree) at IMPOSTER_DISTANCE from the camera to each tree,
## dithering over IMPOSTER_DISTANCE +- IMPOSTER_FADE. The crossfade is per
## instance and per pixel, in the shaders: the tree's leaves
## (painted_leaf.gdshader) and bark (tree_bark.gdshader, crossfade_material)
## keep exactly the interleaved-gradient cells the card (tree_imposter.gdshader)
## drops, so everything stays in the opaque pipeline. (GeometryInstance3D's
## FADE_SELF draws the batch in the alpha pass at every distance once a range
## is set: unsorted leaves, no trunks.) The node ranges only cull: the near
## batch past every tree's fade band, the cards before it. Measured in
## docs/qa/2026-10-07-tree-imposters/result.md (imposter_review.gd).
static var IMPOSTER_DISTANCE := 100.0
const IMPOSTER_FADE := 12.0

## Moves the switch (shader global; harnesses use 0 = always cards and 1e6 =
## never). Node ranges follow on the next commit.
static func set_imposter_distance(distance: float) -> void:
	IMPOSTER_DISTANCE = distance
	RenderingServer.global_shader_parameter_set(&"tree_imposter_fade",
		Vector2(IMPOSTER_DISTANCE, IMPOSTER_FADE))

static func imposter_range_end() -> float:
	return IMPOSTER_DISTANCE + IMPOSTER_FADE + _TILE_HALF_DIAGONAL + VISIBILITY_MARGIN

static func imposter_range_begin() -> float:
	return maxf(IMPOSTER_DISTANCE - IMPOSTER_FADE - _TILE_HALF_DIAGONAL - VISIBILITY_MARGIN, 0.0)

## Painted-leaf cards and the bake's StandardMaterial3D (bark, Farmlands
## cutouts) can crossfade; the legacy LPFV/KayKit canopy shader cannot, so
## those trees keep no imposter.
static func can_crossfade(material: Material) -> bool:
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		return standard.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED,
			BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR] and standard.metallic == 0.0 \
			and standard.roughness_texture == null and not standard.emission_enabled
	return material is ShaderMaterial and (material as ShaderMaterial).shader != null \
		and (material as ShaderMaterial).shader.resource_path.ends_with("painted_leaf.gdshader")

## The tree's own surface material, fading out where its imposter fades in
## (EnvironmentRenderCache gives it to the visible mesh only; the shadow proxy
## keeps the original). Requires can_crossfade.
static func crossfade_material(material: Material) -> Material:
	assert(can_crossfade(material))
	if material is ShaderMaterial:
		var leaf := material.duplicate() as ShaderMaterial
		leaf.set_shader_parameter("imposter_crossfade", true)
		return leaf
	var source := material as StandardMaterial3D
	var cutout := source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var bark := ShaderMaterial.new()
	bark.resource_name = source.resource_name
	bark.shader = _bark_cutout_shader() if cutout \
		else preload("res://terrain/environment/materials/tree_bark.gdshader")
	var colour := source.albedo_color
	if not source.vertex_color_use_as_albedo:
		push_warning("tree bark %s ignores vertex colour; the crossfade copy uses it" % source.resource_name)
	bark.set_shader_parameter("albedo_color", colour)
	bark.set_shader_parameter("albedo_texture", source.albedo_texture)
	if source.normal_enabled and source.normal_texture != null:
		bark.set_shader_parameter("normal_texture", source.normal_texture)
		bark.set_shader_parameter("normal_scale", source.normal_scale)
	if source.ao_enabled and source.ao_texture != null:
		assert(source.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED)
		bark.set_shader_parameter("use_ao", true)
		bark.set_shader_parameter("ao_texture", source.ao_texture)
	bark.set_shader_parameter("roughness", source.roughness)
	bark.set_shader_parameter("alpha_scissor", source.alpha_scissor_threshold)
	return bark

static var _bark_cutout: Shader

## tree_bark.gdshader, alpha-tested and double-sided (Farmlands leaf cutouts).
static func _bark_cutout_shader() -> Shader:
	if _bark_cutout == null:
		var source := preload("res://terrain/environment/materials/tree_bark.gdshader")
		_bark_cutout = Shader.new()
		_bark_cutout.code = source.code.replace("render_mode cull_back;", "render_mode cull_disabled;") \
			.replace("	// CUTOUT", "	ALPHA = albedo.a;\n	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;\n	// CUTOUT")
		assert(_bark_cutout.code.contains("ALPHA_SCISSOR_THRESHOLD") and _bark_cutout.code.contains("cull_disabled"))
	return _bark_cutout

static var _imposter_quad: QuadMesh
static var _imposter_materials: Dictionary = {}

static func imposter_quad() -> QuadMesh:
	if _imposter_quad == null:
		_imposter_quad = QuadMesh.new()
		_imposter_quad.size = Vector2.ONE
	return _imposter_quad

## One shared material per baked imposter.
static func imposter_material(imposter: EnvironmentImposter) -> ShaderMaterial:
	var material := _imposter_materials.get(imposter) as ShaderMaterial
	if material != null:
		return material
	material = ShaderMaterial.new()
	material.shader = preload("res://terrain/environment/materials/tree_imposter.gdshader")
	material.set_shader_parameter("albedo_atlas", imposter.albedo)
	material.set_shader_parameter("normal_atlas", imposter.normal)
	material.set_shader_parameter("frames", imposter.frames)
	material.set_shader_parameter("frame_size", imposter.size)
	material.set_shader_parameter("pivot_height", imposter.pivot_height)
	_imposter_materials[imposter] = material
	return material

## The imposter cards take the placements themselves (the atlas was captured
## in asset space, piece transforms included), the batch's tints and custom
## data. Their quad is not a shadow caster: the shader would turn it to the sun.
static func _attach_imposter(instance: MultiMeshInstance3D, imposter: EnvironmentImposter,
		placements: Array, colors: Array, footprints: Array[Color]) -> MultiMeshInstance3D:
	var count := placements.size()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = imposter_quad()
	multimesh.instance_count = count
	# One buffer upload (3x4 row-major transform, colour, custom per instance).
	var buffer := PackedFloat32Array()
	buffer.resize(count * 20)
	var max_scale := 0.0
	for index in count:
		var t: Transform3D = placements[index]
		var c: Color = colors[index] if index < colors.size() else Color.WHITE
		var f := footprints[index]
		var o := index * 20
		buffer[o] = t.basis.x.x; buffer[o + 1] = t.basis.y.x; buffer[o + 2] = t.basis.z.x; buffer[o + 3] = t.origin.x
		buffer[o + 4] = t.basis.x.y; buffer[o + 5] = t.basis.y.y; buffer[o + 6] = t.basis.z.y; buffer[o + 7] = t.origin.y
		buffer[o + 8] = t.basis.x.z; buffer[o + 9] = t.basis.y.z; buffer[o + 10] = t.basis.z.z; buffer[o + 11] = t.origin.z
		buffer[o + 12] = c.r; buffer[o + 13] = c.g; buffer[o + 14] = c.b; buffer[o + 15] = c.a
		buffer[o + 16] = f.r; buffer[o + 17] = f.g; buffer[o + 18] = f.b; buffer[o + 19] = f.a
		max_scale = maxf(max_scale, t.basis.x.length())
	multimesh.buffer = buffer
	var imposter_node := MultiMeshInstance3D.new()
	imposter_node.name = "Imposter"
	imposter_node.multimesh = multimesh
	imposter_node.material_override = imposter_material(imposter)
	imposter_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	imposter_node.layers = instance.layers
	# The near batch's bounds grown evenly (same centre, so the same range
	# distance) by the card's reach on every side.
	imposter_node.custom_aabb = instance.multimesh.get_aabb().grow(imposter.size.x * max_scale)
	imposter_node.visibility_range_begin = imposter_range_begin()
	imposter_node.set_meta("tactical_owner_footprints", true)
	# Distant cards are never between the camera and the player.
	imposter_node.add_to_group("tactical_preserve_surface", true)
	instance.add_child(imposter_node)
	return imposter_node

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

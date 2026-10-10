class_name EnvironmentRenderCache
extends RefCounted

## Main-thread-only owner of heavy environment visuals. Workers traffic only
## in asset IDs; commits resolve those IDs through this cache.
var _catalog: EnvironmentCatalog
var _visuals: Dictionary = {}
# Keep duplicate source atlases only during a load batch. Otherwise replacing a
# material could free its source and make the next visual decode it again.
var retain_texture_sources := false
var _texture_sources: Dictionary = {}

func _init(catalog: EnvironmentCatalog) -> void:
	_catalog = catalog

func prepare(asset_ids: Array[StringName]) -> bool:
	_assert_main_thread()
	var was_retaining := retain_texture_sources
	retain_texture_sources = true
	var unique: Dictionary = {}
	for asset_id: StringName in asset_ids:
		unique[asset_id] = true
	var ordered: Array[StringName] = []
	ordered.assign(unique.keys())
	ordered.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for asset_id: StringName in ordered:
		if visual(asset_id) == null:
			retain_texture_sources = was_retaining
			if not was_retaining: release_texture_sources()
			return false
	retain_texture_sources = was_retaining
	if not was_retaining: release_texture_sources()
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
	preload("res://scripts/terrain/environment/EnvironmentTextureSharing.gd").prepare(loaded,
		_texture_sources if retain_texture_sources else {})
	var finish := descriptor_value.material_tints.duplicate()
	# Warm lime plaster across every Suntail wall, gable, dormer and bay.
	# Keep the authored plaster grain/normal maps and all wood/stone finishes.
	if String(asset_id).begins_with("suntail."):
		finish["Wall"] = Color(.92, .86, .76) * (finish.get("Wall", Color.WHITE) as Color)
	if not finish.is_empty():
		loaded = _tinted_visual(loaded, finish)
	# Ambient stone shares the cliff stone palette; source geometry, UV detail
	# and collision remain authored. Duplicate only the prepared visual wrapper.
	if String(asset_id).begins_with("kaykit.rock.") or String(asset_id).begins_with("lpfv.rock.") or String(asset_id).begins_with("lpfv.big_rock."):
		loaded = loaded.duplicate(true)
		for piece: EnvironmentVisualPiece in loaded.pieces:
			piece.mesh = piece.mesh.duplicate()
			for surface in piece.mesh.get_surface_count():
				var source := piece.mesh.surface_get_material(surface) as StandardMaterial3D
				if source == null: continue
				var stone := ShaderMaterial.new()
				stone.shader = load("res://terrain/materials/field_rock.gdshader")
				stone.set_shader_parameter("albedo_texture", source.albedo_texture)
				stone.set_shader_parameter("source_color_value", source.albedo_color)
				piece.mesh.surface_set_material(surface, stone)
	# Meadow rocks' grass tops are the cliff moss (meadow_rock.gdshader): they
	# take the current moss choice, not the one their bake happened to copy.
	if String(asset_id).begins_with("meadow.rock."):
		loaded = loaded.duplicate(true)
		for piece: EnvironmentVisualPiece in loaded.pieces:
			if piece.material_override is ShaderMaterial:
				piece.material_override = piece.material_override.duplicate()
				load("res://scripts/terrain/field/CliffRockCrags.gd").apply_moss(piece.material_override)
	# Trees crossfade to their baked imposter in their own surface shaders.
	# A tree whose materials cannot keeps no imposter.
	if loaded.imposter != null and not _crossfade_tree(loaded):
		loaded = loaded.duplicate()
		loaded.imposter = null
	_visuals[asset_id] = loaded
	return loaded

## Gives the visible meshes of a tree with an imposter their crossfade copies
## (EnvironmentCommitQueue.crossfade_material), once per mesh surface for the
## whole process: the meshes are ResourceLoader-shared, so a second cache (one
## per town) finds the copies already in place (meta `imposter_crossfade`,
## original in `baked_material`). The shadow proxy keeps the baked materials.
## False, changing nothing, when any surface cannot crossfade.
static func _crossfade_tree(visual_value: EnvironmentVisual) -> bool:
	for piece: EnvironmentVisualPiece in visual_value.pieces:
		for surface in piece.mesh.get_surface_count():
			var material := piece.mesh.surface_get_material(surface)
			if material == null or not (material.has_meta(&"imposter_crossfade")
					or EnvironmentCommitQueue.can_crossfade(material)):
				return false
	for piece: EnvironmentVisualPiece in visual_value.pieces:
		# The fade is measured from the placement origin, not the piece's.
		var offset := piece.local_transform.affine_inverse().origin
		for surface in piece.mesh.get_surface_count():
			var source := piece.mesh.surface_get_material(surface)
			if source.has_meta(&"imposter_crossfade"):
				assert((source as ShaderMaterial).get_shader_parameter("imposter_origin_offset") == offset,
					"one mesh shared by pieces with different origins")
				continue
			var faded := EnvironmentCommitQueue.crossfade_material(source, offset)
			faded.set_meta(&"imposter_crossfade", true)
			faded.set_meta(&"baked_material", source)
			piece.mesh.surface_set_material(surface, faded)
	return true

func is_prepared(asset_id: StringName) -> bool:
	return _visuals.has(asset_id)

func descriptor(asset_id: StringName) -> EnvironmentAssetDescriptor:
	return _catalog.descriptor(asset_id)

func prepared_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_visuals.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out

func release_texture_sources() -> void:
	_assert_main_thread()
	_texture_sources.clear()

func clear() -> void:
	_assert_main_thread()
	_visuals.clear()
	release_texture_sources()

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


static func _tinted_visual(source: EnvironmentVisual, tints: Dictionary) -> EnvironmentVisual:
	var result := EnvironmentVisual.new()
	result.collisions.assign(source.collisions)
	result.imposter = source.imposter
	for original: EnvironmentVisualPiece in source.pieces:
		var piece := original.duplicate() as EnvironmentVisualPiece
		piece.mesh = original.mesh.duplicate()
		for surface in piece.mesh.get_surface_count():
			var material := original.mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null or not tints.has(material.resource_name): continue
			var variant := material.duplicate() as StandardMaterial3D
			variant.albedo_color *= tints[material.resource_name] as Color
			piece.mesh.surface_set_material(surface, variant)
		result.pieces.append(piece)
	return result

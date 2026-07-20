class_name EnvironmentCatalog
extends RefCounted

const DEFAULT_INDEX_PATH := "res://terrain/environment/catalog/index.tres"

var _by_id: Dictionary = {}
var _ids: Array[StringName] = []

static func load_default() -> EnvironmentCatalog:
	var index := load(DEFAULT_INDEX_PATH) as EnvironmentCatalogIndex
	if index == null:
		push_error("Environment catalogue index is missing or invalid: %s" % DEFAULT_INDEX_PATH)
		return null
	return from_index(index)

static func from_index(index: EnvironmentCatalogIndex) -> EnvironmentCatalog:
	if index == null:
		push_error("Environment catalogue index cannot be null")
		return null
	var catalog := EnvironmentCatalog.new()
	if not catalog._build(index):
		return null
	return catalog

func descriptor(asset_id: StringName) -> EnvironmentAssetDescriptor:
	return _by_id.get(asset_id) as EnvironmentAssetDescriptor

func has(asset_id: StringName) -> bool:
	return _by_id.has(asset_id)

func ids() -> Array[StringName]:
	return _ids.duplicate()

func size() -> int:
	return _ids.size()

func _build(index: EnvironmentCatalogIndex) -> bool:
	var previous := ""
	for descriptor_value: EnvironmentAssetDescriptor in index.descriptors:
		if descriptor_value == null:
			push_error("Environment catalogue contains a null descriptor")
			return false
		var key := String(descriptor_value.id)
		if key.is_empty():
			push_error("Environment descriptor ID cannot be empty")
			return false
		if _by_id.has(descriptor_value.id):
			push_error("Duplicate environment descriptor ID: %s" % key)
			return false
		if not previous.is_empty() and key <= previous:
			push_error("Environment catalogue must be strictly sorted by ID: %s follows %s" % [key, previous])
			return false
		if descriptor_value.visual_path.is_empty() \
				or not descriptor_value.visual_path.begins_with("res://terrain/environment/visuals/"):
			push_error("Environment descriptor %s has an invalid runtime visual path" % key)
			return false
		if not ResourceLoader.exists(descriptor_value.visual_path):
			push_error("Environment descriptor %s points to a missing visual: %s" % [key, descriptor_value.visual_path])
			return false
		_by_id[descriptor_value.id] = descriptor_value
		_ids.append(descriptor_value.id)
		previous = key
	return true

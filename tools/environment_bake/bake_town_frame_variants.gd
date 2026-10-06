extends SceneTree
## Lightweight palette descriptors reuse native visuals, textures and physics.
## No source or baked geometry is modified.
const PALETTE := preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd")


func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var index := EnvironmentCatalogIndex.new()
	var descriptors := {}
	for id: StringName in catalog.ids():
		descriptors[id] = catalog.descriptor(id)
	for source_id: StringName in PALETTE.source_ids():
		for finish: StringName in [&"walnut", &"oak"]:
			var descriptor := (
				catalog.descriptor(source_id).duplicate() as EnvironmentAssetDescriptor
			)
			descriptor.id = PALETTE.variant_id(source_id, finish)
			descriptor.material_tints = PALETTE.tints(finish)
			descriptor.provenance_id = StringName(
				"%s/frame/%s" % [descriptor.provenance_id, finish]
			)
			var path := (
				"res://terrain/environment/catalog/descriptors/%s.tres"
				% String(descriptor.id).replace(".", "_")
			)
			assert(ResourceSaver.save(descriptor, path) == OK)
			descriptors[descriptor.id] = load(path)
	var ids := descriptors.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		index.descriptors.append(descriptors[id])
	assert(ResourceSaver.save(index, EnvironmentCatalog.DEFAULT_INDEX_PATH) == OK)
	print("FRAME_VARIANTS ", PALETTE.asset_ids().size())
	quit()

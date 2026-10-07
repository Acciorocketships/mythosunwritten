extends SceneTree
## Dark-wood lamp variants (owner, October 7: lamp posts match the town's timber).
## Each source lamp's single atlas material is tinted brown by a lightweight
## descriptor; meshes, textures and collision are shared. Usage:
##   Godot --headless --path . -s res://tools/environment_bake/bake_lamp_finish.gd
## New `.dark_wood` descriptors (the kit's garden/plaza lamp is a substitution target).
const VARIANTS := {
	&"suntail.prop.lamp_1": {"Lamp_1": Color(0.62, 0.42, 0.28)},
}
## Existing descriptors retinted in place: the path pole's id is referenced by
## lights, path planning and payloads, so it keeps its id and gains the tint.
const IN_PLACE := {
	&"sfv.light_pole.001": {"SFV_MAIN_MATERIAL": Color(0.48, 0.37, 0.29)},
}


func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var index := EnvironmentCatalogIndex.new()
	var descriptors := {}
	for id: StringName in catalog.ids():
		descriptors[id] = catalog.descriptor(id)
	for source_id: StringName in VARIANTS:
		var descriptor := catalog.descriptor(source_id).duplicate() as EnvironmentAssetDescriptor
		descriptor.id = StringName("%s.dark_wood" % source_id)
		descriptor.material_tints = VARIANTS[source_id]
		descriptor.provenance_id = StringName("%s/dark_wood" % descriptor.provenance_id)
		var path := (
			"res://terrain/environment/catalog/descriptors/%s.tres"
			% String(descriptor.id).replace(".", "_")
		)
		assert(ResourceSaver.save(descriptor, path) == OK)
		descriptors[descriptor.id] = load(path)
	for id: StringName in IN_PLACE:
		var descriptor := descriptors[id] as EnvironmentAssetDescriptor
		descriptor.material_tints = IN_PLACE[id]
		assert(ResourceSaver.save(descriptor, descriptor.resource_path) == OK)
	var ids := descriptors.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		index.descriptors.append(descriptors[id])
	assert(ResourceSaver.save(index, EnvironmentCatalog.DEFAULT_INDEX_PATH) == OK)
	print("LAMP_VARIANTS ", VARIANTS.size())
	quit()

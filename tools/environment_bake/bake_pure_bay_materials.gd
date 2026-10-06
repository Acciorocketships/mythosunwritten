extends SceneTree
## Mixed-kit bays keep the Suntail geometry, glass, roof and collision while
## their infill uses the exact plaster material of the Pure Village host.
func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var donor := load(catalog.descriptor(&"pure_village.wall.plaster.plain").visual_path) as EnvironmentVisual
	var plaster: Material
	for piece: EnvironmentVisualPiece in donor.pieces:
		for surface in piece.mesh.get_surface_count():
			var material := piece.mesh.surface_get_material(surface)
			if material.resource_name == "Plaster": plaster = material
	assert(plaster != null)
	var descriptors := {}
	for id: StringName in catalog.ids(): descriptors[id] = catalog.descriptor(id)
	for colour: String in ["red","blue"]:
		var source_id := StringName("suntail.frame.frame_extension_"+colour)
		var source := load(catalog.descriptor(source_id).visual_path) as EnvironmentVisual
		var visual := EnvironmentVisual.new()
		visual.collisions.assign(source.collisions)
		var changed := 0
		for original: EnvironmentVisualPiece in source.pieces:
			var piece := original.duplicate() as EnvironmentVisualPiece
			piece.mesh = original.mesh.duplicate()
			for surface in piece.mesh.get_surface_count():
				if piece.mesh.surface_get_material(surface).resource_name == "Wall":
					piece.mesh.surface_set_material(surface,plaster)
					changed += 1
			visual.pieces.append(piece)
		assert(changed == 1)
		var id := StringName("pure_village.bay.frame_"+colour)
		var visual_path := "res://terrain/environment/visuals/pure_village_kit/bay_frame_%s.tres"%colour
		assert(ResourceSaver.save(visual,visual_path)==OK)
		for finish: StringName in [&"native",&"oak",&"walnut"]:
			var descriptor := catalog.descriptor(source_id).duplicate() as EnvironmentAssetDescriptor
			descriptor.id = preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd").variant_id(id,finish)
			descriptor.visual_path = visual_path
			descriptor.material_tints = preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd").tints(finish)
			descriptor.provenance_id = StringName("pure_bay_materials:%s/%s"%[source_id,finish])
			var path := "res://terrain/environment/catalog/descriptors/%s.tres"%String(descriptor.id).replace(".","_")
			assert(ResourceSaver.save(descriptor,path)==OK)
			descriptors[descriptor.id] = load(path)
	var index := EnvironmentCatalogIndex.new()
	var ids := descriptors.keys()
	ids.sort_custom(func(a,b):return String(a)<String(b))
	for id in ids:index.descriptors.append(descriptors[id])
	assert(ResourceSaver.save(index,EnvironmentCatalog.DEFAULT_INDEX_PATH)==OK)
	print("PURE_BAY_MATERIALS 2 visuals / 6 descriptors")
	quit()

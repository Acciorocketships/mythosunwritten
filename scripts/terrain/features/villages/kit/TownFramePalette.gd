extends RefCounted
## Native wood finishes. Multipliers retain the source grain and normal maps;
## plaster, stone, roof tiles, glass and metal are deliberately separate.
const FINISHES := {
	&"walnut": Color(.48, .37, .29),
	&"oak": Color(.9, .74, .53),
	&"native": Color.WHITE,
}
## Assets carrying their own fixed dark-wood finish (lamp posts).
const DARK_WOOD_SUFFIX := ".dark_wood"
const WOOD_MATERIALS := [
	"Wood_1",
	"Wood_2",
	"Wood_3",
	"Wood",
	"Wooden_Planks",
	"Planks_Full",
	"Planks",
	"DoorShutter",
	"DoorShutters",
]


static func tints(finish: StringName) -> Dictionary:
	assert(FINISHES.has(finish))
	var result := {}
	if finish == &"native":
		return result
	for name: String in WOOD_MATERIALS:
		result[name] = FINISHES[finish]
	return result


## A controlled render comparison, using copied descriptors. Production catalog
## resources remain untouched. Production selection must use distinct variant IDs.
static func study_catalog(catalog: EnvironmentCatalog, finish: StringName) -> EnvironmentCatalog:
	var index := EnvironmentCatalogIndex.new()
	for id: StringName in catalog.ids():
		var descriptor := catalog.descriptor(id).duplicate() as EnvironmentAssetDescriptor
		if String(id).begins_with("pure_village.") or String(id).begins_with("suntail."):
			descriptor.material_tints = tints(finish)
		index.descriptors.append(descriptor)
	return EnvironmentCatalog.from_index(index)


static func variant_id(id: StringName, finish: StringName) -> StringName:
	var base := String(id).get_slice(".finish_", 0)
	return StringName(base if finish == &"native" else "%s.finish_%s" % [base, finish])


static func apply(kit: BuildingKit, finish: StringName) -> void:
	assert(FINISHES.has(finish) and kit.frame_palette == &"native")
	kit.frame_palette = finish
	if finish == &"native":
		return
	for role: StringName in kit.roles:
		var replacements: Array[StringName] = []
		for id: StringName in kit.roles[role]:
			if String(id).ends_with(DARK_WOOD_SUFFIX):
				# Already finished (lamp posts): no frame-finish variant exists.
				replacements.append(id)
				continue
			var variant := variant_id(id, finish)
			replacements.append(variant)
			kit.geometry_aliases[variant] = id
			if kit.asset_anchors.has(id):
				kit.asset_anchors[variant] = kit.asset_anchors[id]
			if kit.roof_cap_x_bounds.has(id):
				kit.roof_cap_x_bounds[variant] = kit.roof_cap_x_bounds[id]
		kit.roles[role] = replacements


static func source_ids() -> Array[StringName]:
	var unique := {}
	var pure := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
	var roofs := preload("res://scripts/terrain/features/villages/kit/TownRoofPalette.gd")
	for style in [0, 1]:
		for family: StringName in roofs.FAMILIES:
			var kit := pure.roof_study(style)
			roofs.apply(kit, family)
			for id: StringName in kit.all_asset_ids():
				if not String(id).ends_with(DARK_WOOD_SUFFIX):
					unique[id] = true
	for id: StringName in (
		preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd").asset_ids()
	):
		unique[id] = true
	var result: Array[StringName] = []
	result.assign(unique.keys())
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


static func asset_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in source_ids():
		for finish: StringName in [&"walnut", &"oak"]:
			result.append(variant_id(id, finish))
	return result
